"""Per-file thumbnail extraction.

Pure functions — no DB access, no state.  Owns the FFmpeg argv shapes
and the PyMuPDF call.  Consumed by ``services/thumbnail_worker.py`` which
handles the queue lifecycle, status updates, and concurrency control.

Four extractor paths:

* ``video``  → FFmpeg single-frame extract at ``min(10s, duration/3)``.
              When ``hdr_format`` is set, the video filter chain switches
              to the Hable HDR→SDR tonemap chain (matches the stream-side
              tonemap from the streaming pipeline plan).
* ``image``  → FFmpeg `-vf scale=W:-2:flags=lanczos`.
* ``audio``  → FFmpeg `-an -vcodec copy` extracts the embedded APIC frame.
              Files without embedded art produce ``ThumbnailResult(skipped=True)``
              so the worker writes status='skipped' (permanent, no retry).
* ``pdf``    → PyMuPDF renders the first page to a pixmap at the target
              width and saves directly to JPEG.  Encrypted PDFs are
              treated as ``skipped``; corrupt PDFs as ``failed``.

The output is always a JPEG written to ``output_path``.  Callers are
responsible for picking the output path (typically ``<data_dir>/
thumbnails/<file_id>.jpg``) and for the surrounding DB state machine.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from pathlib import Path

from services.ffmpeg_service import _ffmpeg_bin

logger = logging.getLogger(__name__)

# Hard timeouts on the underlying subprocess / blocking call.  Stops a
# pathological input file (corrupt header, huge runtime DRM check) from
# parking a worker slot indefinitely.
_VIDEO_TIMEOUT_SEC = 30.0
_IMAGE_TIMEOUT_SEC = 15.0
_AUDIO_TIMEOUT_SEC = 15.0
_PDF_TIMEOUT_SEC = 15.0

# Width clamp.  The worker passes operator-configured width through;
# this is a final defensive clamp so a bad config can't produce 0-px
# JPEGs or 50000-px memory bombs.
_MIN_WIDTH = 32
_MAX_WIDTH = 2048

# Extension dispatch table — kind for each known suffix.  Anything not
# in the table is treated as ``skipped`` by the worker (the dispatcher
# is in the worker, not here, because the worker also wants this
# mapping for stats / observability).
_VIDEO_EXTENSIONS = frozenset({
    ".mp4", ".mkv", ".mov", ".avi", ".webm", ".wmv", ".flv", ".m4v",
    ".ts", ".mpg", ".mpeg", ".3gp",
})
_IMAGE_EXTENSIONS = frozenset({
    ".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".gif", ".bmp",
    ".tiff", ".tif", ".ico",
    # JXR (JPEG XR / HD Photo) — Windows-only, extracted via WIC.
    # NVIDIA GeForce Experience saves HDR screenshots in this format;
    # FFmpeg has no decoder, so the extractor dispatches to GDI+ via
    # PowerShell on Windows and reports `skipped` elsewhere.
    ".jxr",
})

# Extensions FFmpeg can't decode but Windows Imaging Component (WIC)
# handles natively.  Routed through the PowerShell + GDI+ fallback
# extractor `_extract_image_wic`.  No-op on non-Windows platforms —
# the file is reported `skipped` there.
_WIC_ONLY_EXTENSIONS = frozenset({".jxr"})
_AUDIO_EXTENSIONS = frozenset(
    {".mp3", ".m4a", ".flac", ".ogg", ".opus", ".wav", ".aac"}
)
_PDF_EXTENSIONS = frozenset({".pdf"})


def kind_for_extension(extension: str) -> str | None:
    """Return 'video' / 'image' / 'audio' / 'pdf' for a known extension,
    None otherwise.  Caller treats None as ``skipped`` (no thumb possible)."""
    ext = extension.lower()
    if ext in _VIDEO_EXTENSIONS:
        return "video"
    if ext in _IMAGE_EXTENSIONS:
        return "image"
    if ext in _AUDIO_EXTENSIONS:
        return "audio"
    if ext in _PDF_EXTENSIONS:
        return "pdf"
    return None


@dataclass(frozen=True)
class ThumbnailResult:
    """Outcome of one extraction attempt.

    Exactly one of ``success`` / ``skipped`` is True; ``error`` is set
    on the ``skipped`` and failure paths to describe why.  The worker
    maps:

      success=True              → status='ready'
      skipped=True              → status='skipped' (permanent, no retry)
      success=False & skipped=False → status='failed' (transient, retried up to max_attempts)
    """

    success: bool
    skipped: bool = False
    error: str | None = None


# ── Audio-skip signature recognition ────────────────────────────────────────
# When `-vcodec copy` runs against a file with no embedded picture stream
# FFmpeg exits non-zero with one of these strings on stderr.  We detect
# the signature and translate to skipped rather than failed so the worker
# doesn't keep retrying a fundamentally-unfixable file.
_AUDIO_NO_PICTURE_MARKERS = (
    "does not contain any stream",
    "output file is empty",
    "no streams to mux",
)


# ── HDR → SDR tonemap chain ─────────────────────────────────────────────────
# Same Hable-operator chain the stream-side tonemap uses (plan 17 +
# streaming-pipeline plan §16 audio-fix).  Linearise PQ/HLG → primary
# convert → tonemap → SDR transfer + matrix → final yuv420p for JPEG.
# Applied before the scale filter so the resize works on already-SDR
# pixels (cheaper than tonemapping after a downscale).
_HDR_TO_SDR_VF = (
    "zscale=t=linear:npl=100,"
    "format=gbrpf32le,"
    "zscale=p=bt709,"
    "tonemap=tonemap=hable:desat=0,"
    "zscale=t=bt709:m=bt709:r=tv,"
    "format=yuv420p"
)


def _clamp_width(width: int) -> int:
    if width < _MIN_WIDTH:
        return _MIN_WIDTH
    if width > _MAX_WIDTH:
        return _MAX_WIDTH
    return width


def _pick_seek_seconds(duration_sec: float | None) -> float:
    """Choose a representative timestamp for the video frame grab.

    ``min(10, duration/3)`` skips title cards on normal-length content
    but stays in-bounds for short clips.  Floor of 1.0 s prevents a
    near-zero seek on pathological inputs that report 0 / negative
    duration; FFmpeg would still seek to 0 in that case but having a
    consistent fallback avoids edge-case argv variation.
    """
    if duration_sec is None or duration_sec <= 0:
        return 1.0
    return max(1.0, min(10.0, duration_sec / 3.0))


async def _run_subprocess(
    argv: list[str], *, timeout: float
) -> tuple[int, bytes]:
    """Spawn a subprocess with bounded stderr capture + hard timeout.

    Returns ``(returncode, stderr_bytes)``.  On timeout the process is
    killed and a non-zero returncode is returned along with a marker
    error message in the stderr buffer.  Other failures (FileNotFound,
    OSError) propagate to the caller.
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            *argv,
            stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE,
        )
    except (OSError, FileNotFoundError):
        raise

    try:
        _, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        return proc.returncode or 0, stderr or b""
    except asyncio.TimeoutError:
        try:
            proc.kill()
        except ProcessLookupError:
            pass
        try:
            await asyncio.wait_for(proc.wait(), timeout=2.0)
        except asyncio.TimeoutError:
            pass
        return 137, b"timeout"


def _stderr_tail(stderr: bytes, max_bytes: int = 8192) -> str:
    """Return a UTF-8 decoded tail of stderr, capped so we don't store
    multi-MB error messages in the DB."""
    if not stderr:
        return ""
    if len(stderr) > max_bytes:
        stderr = stderr[-max_bytes:]
    try:
        return stderr.decode("utf-8", errors="replace").strip()
    except Exception:
        return ""


async def _extract_video(
    file_path: Path,
    output_path: Path,
    *,
    width: int,
    duration_sec: float | None,
    hdr_format: str | None,
) -> ThumbnailResult:
    """Extract a single video frame at min(10s, duration/3) to JPEG.

    HDR sources (HDR10 / HLG / DolbyVision) run through the Hable
    tonemap chain so the JPEG isn't washed out / blown out on an SDR
    display.

    SDR path uses `-hwaccel auto` to let FFmpeg pick GPU decode when
    supported (cuda / qsv / videotoolbox / vaapi), with an automatic
    software-fallback retry if the hwaccel attempt fails — covers
    drivers that report a hwaccel as available but error on specific
    codecs.  HDR path stays CPU-only since `zscale` doesn't accept
    hardware-side frame formats without an explicit `hwdownload`
    step, and HDR libraries are rare enough that the extra complexity
    isn't worth the speed-up there.
    """
    ffmpeg = _ffmpeg_bin()
    seek_sec = _pick_seek_seconds(duration_sec)
    is_hdr = bool(hdr_format)
    vf_chain = _build_video_filter_chain(width=width, hdr=is_hdr)

    # Input-side seek (`-ss` before `-i`) is fast but slightly imprecise;
    # we don't need frame-accurate timing for a thumbnail.
    def _build_argv(use_hwaccel: bool) -> list[str]:
        argv = [ffmpeg, "-y"]
        if use_hwaccel:
            # `auto` lets FFmpeg pick the available hwaccel per platform
            # (cuda, qsv, videotoolbox, vaapi, d3d11va, …).  Modern FFmpeg
            # gracefully falls back to software when the chosen accel
            # can't decode the codec; older builds occasionally error
            # out, which is why we have the second-attempt fallback
            # below.
            argv += ["-hwaccel", "auto"]
        argv += [
            "-ss",
            f"{seek_sec:.3f}",
            "-i",
            str(file_path),
            "-vframes",
            "1",
            "-vf",
            vf_chain,
            "-q:v",
            "8",
            "-loglevel",
            "error",
            str(output_path),
        ]
        return argv

    # First attempt: hwaccel auto on SDR; software on HDR (zscale isn't
    # hwaccel-friendly without an extra hwdownload step).
    try:
        returncode, stderr = await _run_subprocess(
            _build_argv(use_hwaccel=not is_hdr),
            timeout=_VIDEO_TIMEOUT_SEC,
        )
    except (OSError, FileNotFoundError) as e:
        return ThumbnailResult(success=False, error=f"ffmpeg spawn failed: {e}")

    if returncode == 0 and output_path.exists() and output_path.stat().st_size > 0:
        return ThumbnailResult(success=True)

    # SDR + hwaccel failure → retry without hwaccel.  HDR already
    # software-only on the first try, so no retry.
    if not is_hdr:
        try:
            # Clean any partial output before the second attempt so the
            # success check below doesn't see a stale 0-byte file.
            if output_path.exists():
                output_path.unlink()
        except OSError:
            pass
        try:
            returncode, stderr = await _run_subprocess(
                _build_argv(use_hwaccel=False),
                timeout=_VIDEO_TIMEOUT_SEC,
            )
        except (OSError, FileNotFoundError) as e:
            return ThumbnailResult(success=False, error=f"ffmpeg spawn failed: {e}")
        if returncode == 0 and output_path.exists() and output_path.stat().st_size > 0:
            return ThumbnailResult(success=True)

    tail = _stderr_tail(stderr)
    return ThumbnailResult(
        success=False,
        error=f"ffmpeg exit={returncode} {tail}".strip(),
    )


def _build_video_filter_chain(*, width: int, hdr: bool) -> str:
    """Compose the `-vf` chain.  Scale is the last step so it operates
    on yuv420p frames in both SDR and HDR-tonemapped paths.

    Uses `bilinear` (post-ship 2026-05-16, was `lanczos`) — ~30 % faster
    and visually indistinguishable at the 320 px default thumbnail size.
    """
    if hdr:
        return f"{_HDR_TO_SDR_VF},scale={width}:-2:flags=bilinear"
    return f"scale={width}:-2:flags=bilinear,format=yuv420p"


async def _extract_image(
    file_path: Path,
    output_path: Path,
    *,
    width: int,
) -> ThumbnailResult:
    """Re-encode an existing image to a width-bounded JPEG.

    Works for any FFmpeg-decodable format (JPEG, PNG, WEBP, HEIC, BMP,
    TIFF, GIF first frame).  Output is always JPEG for consistency.

    JXR (JPEG XR / HD Photo) is dispatched to the Windows-native WIC
    path instead — FFmpeg has no decoder, but Windows Imaging
    Component does (via GDI+ / .NET `System.Drawing`).  On non-
    Windows platforms the call falls through to FFmpeg which fails
    cleanly, marking the row as `failed`.
    """
    ext = file_path.suffix.lower()
    if ext in _WIC_ONLY_EXTENSIONS:
        return await _extract_image_wic(file_path, output_path, width=width)

    ffmpeg = _ffmpeg_bin()
    argv = [
        ffmpeg,
        "-y",
        "-i",
        str(file_path),
        "-vf",
        f"scale={width}:-2:flags=bilinear",
        "-q:v",
        "8",
        "-loglevel",
        "error",
        str(output_path),
    ]

    try:
        returncode, stderr = await _run_subprocess(argv, timeout=_IMAGE_TIMEOUT_SEC)
    except (OSError, FileNotFoundError) as e:
        return ThumbnailResult(success=False, error=f"ffmpeg spawn failed: {e}")

    if returncode == 0 and output_path.exists() and output_path.stat().st_size > 0:
        return ThumbnailResult(success=True)
    tail = _stderr_tail(stderr)
    return ThumbnailResult(
        success=False,
        error=f"ffmpeg exit={returncode} {tail}".strip(),
    )


async def _extract_image_wic(
    file_path: Path,
    output_path: Path,
    *,
    width: int,
) -> ThumbnailResult:
    """Render a width-bounded JPEG via Windows Imaging Component.

    Shells out to PowerShell with `System.Windows.Media.Imaging`
    (PresentationCore / WindowsBase) which talks directly to WIC and
    has built-in decoders for JPEG XR and other Windows-native
    formats that FFmpeg ships without.  Slower than the FFmpeg path
    (~300-500ms per file vs. ~50ms) but the only viable option for
    JXR without adding a new pip dep.
    Note: `System.Drawing` / GDI+ does NOT use WIC and can't decode
    JXR (throws "Out of memory" on `FromFile`) — must go through the
    WPF imaging stack instead.
    Returns `skipped` on non-Windows platforms.
    """
    import sys
    if sys.platform != "win32":
        return ThumbnailResult(
            skipped=True,
            error="WIC path is Windows-only",
        )

    # Single-quoted PowerShell strings so paths with special chars
    # don't get interpolated.  TransformedBitmap with a ScaleTransform
    # is the WIC-native resize path — quality matches `BitmapScaling-
    # Mode.HighQuality` (Lanczos-like).
    src = str(file_path).replace("'", "''")
    dst = str(output_path).replace("'", "''")
    # The pipeline: decode → tonemap (HDR-aware) → scale → encode.
    #
    # NVIDIA HDR JXR captures store pixel data in scRGB / HDR10 with
    # luminance values well above 1.0.  WIC's `FormatConvertedBitmap`
    # to `Bgra32` applies sRGB gamma but CLIPS values > 1.0 to white,
    # which is the overexposure we were seeing.  Doing a manual
    # Reinhard tonemap (`out = in / (1 + in)`) on the float pixel
    # data first compresses the highlights into the [0,1] range
    # cleanly before the gamma + 8-bit conversion.  Slower than a
    # plain decode but produces a balanced thumbnail that matches
    # what Windows Photos / Explorer show.
    script = (
        "Add-Type -AssemblyName PresentationCore;"
        "Add-Type -AssemblyName WindowsBase;"
        "Add-Type -AssemblyName System.Xaml;"
        f"$srcPath = '{src}';"
        f"$dstPath = '{dst}';"
        f"$w = {width};"
        "$stream = New-Object System.IO.FileStream("
        "  $srcPath,"
        "  [System.IO.FileMode]::Open,"
        "  [System.IO.FileAccess]::Read,"
        "  [System.IO.FileShare]::Read);"
        "try {"
        "  $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create("
        "    $stream,"
        "    [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,"
        "    [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad);"
        "  $frame = $decoder.Frames[0];"
        # Convert to 128-bit float RGBA so HDR pixel values aren't
        # clipped by WIC's default 8-bit conversion.
        "  $rgbaFloat = [System.Windows.Media.PixelFormats]::Rgba128Float;"
        "  $f32 = New-Object "
        "    System.Windows.Media.Imaging.FormatConvertedBitmap("
        "    $frame, $rgbaFloat, $null, 0.0);"
        # Scale BEFORE tonemap so the PowerShell pixel loop runs over
        # the small thumbnail buffer (~57k pixels at 320px) instead
        # of the full ~3.7M-pixel source — keeps total runtime well
        # under the 15s subprocess timeout.
        "  $scale = $w / $f32.PixelWidth;"
        "  $xform = New-Object "
        "    System.Windows.Media.ScaleTransform $scale, $scale;"
        "  $scaledFloat = New-Object "
        "    System.Windows.Media.Imaging.TransformedBitmap $f32, $xform;"
        "  $pw = $scaledFloat.PixelWidth;"
        "  $ph = $scaledFloat.PixelHeight;"
        "  $stride = $pw * 16;"  # 4 channels × 4 bytes
        "  $buf = New-Object byte[] ($stride * $ph);"
        "  $scaledFloat.CopyPixels($buf, $stride, 0);"
        "  $floats = New-Object single[] ($buf.Length / 4);"
        "  [System.Buffer]::BlockCopy($buf, 0, $floats, 0, $buf.Length);"
        # Reinhard tonemap on RGB channels, leave alpha alone.
        "  for ($i = 0; $i -lt $floats.Length; $i += 4) {"
        "    $r = $floats[$i];     if ($r -lt 0) { $r = 0 };"
        "    $g = $floats[$i + 1]; if ($g -lt 0) { $g = 0 };"
        "    $b = $floats[$i + 2]; if ($b -lt 0) { $b = 0 };"
        "    $floats[$i]     = $r / (1.0 + $r);"
        "    $floats[$i + 1] = $g / (1.0 + $g);"
        "    $floats[$i + 2] = $b / (1.0 + $b);"
        "  }"
        "  [System.Buffer]::BlockCopy($floats, 0, $buf, 0, $buf.Length);"
        "  $tonemapped = "
        "    [System.Windows.Media.Imaging.BitmapSource]::Create("
        "      $pw, $ph, 96, 96, $rgbaFloat, $null, $buf, $stride);"
        # Float → 8-bit sRGB; gamma is applied correctly now that
        # all values sit inside [0,1].
        "  $bgra = [System.Windows.Media.PixelFormats]::Bgra32;"
        "  $sdr = New-Object "
        "    System.Windows.Media.Imaging.FormatConvertedBitmap("
        "    $tonemapped, $bgra, $null, 0.0);"
        "  $encoder = New-Object "
        "    System.Windows.Media.Imaging.JpegBitmapEncoder;"
        "  $encoder.QualityLevel = 85;"
        "  $encoder.Frames.Add("
        "    [System.Windows.Media.Imaging.BitmapFrame]::Create($sdr));"
        "  $outStream = New-Object System.IO.FileStream("
        "    $dstPath,"
        "    [System.IO.FileMode]::Create,"
        "    [System.IO.FileAccess]::Write);"
        "  try { $encoder.Save($outStream); }"
        "  finally { $outStream.Dispose(); }"
        "} finally { $stream.Dispose(); }"
    )
    argv = [
        "powershell",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        script,
    ]

    try:
        returncode, stderr = await _run_subprocess(
            argv, timeout=_IMAGE_TIMEOUT_SEC
        )
    except (OSError, FileNotFoundError) as e:
        return ThumbnailResult(
            success=False, error=f"powershell spawn failed: {e}"
        )

    if returncode == 0 and output_path.exists() and output_path.stat().st_size > 0:
        return ThumbnailResult(success=True)
    tail = _stderr_tail(stderr)
    return ThumbnailResult(
        success=False,
        error=f"WIC powershell exit={returncode} {tail}".strip(),
    )


async def _extract_audio(
    file_path: Path,
    output_path: Path,
) -> ThumbnailResult:
    """Extract embedded album art (APIC / ID3v2 attached picture) as JPEG.

    No resize — embedded covers are typically 300–600 px already, and
    `vcodec copy` preserves the bytes verbatim.  Files without embedded
    art are mapped to ``skipped`` so the worker doesn't keep retrying.
    """
    ffmpeg = _ffmpeg_bin()
    argv = [
        ffmpeg,
        "-y",
        "-i",
        str(file_path),
        "-an",
        "-vcodec",
        "copy",
        "-loglevel",
        "error",
        str(output_path),
    ]

    try:
        returncode, stderr = await _run_subprocess(argv, timeout=_AUDIO_TIMEOUT_SEC)
    except (OSError, FileNotFoundError) as e:
        return ThumbnailResult(success=False, error=f"ffmpeg spawn failed: {e}")

    if returncode == 0 and output_path.exists() and output_path.stat().st_size > 0:
        return ThumbnailResult(success=True)

    tail = _stderr_tail(stderr).lower()
    if any(marker in tail for marker in _AUDIO_NO_PICTURE_MARKERS):
        return ThumbnailResult(
            success=False,
            skipped=True,
            error="no embedded album art",
        )
    return ThumbnailResult(
        success=False,
        error=f"ffmpeg exit={returncode} {_stderr_tail(stderr)}".strip(),
    )


def _render_pdf_first_page_sync(
    file_path: Path,
    output_path: Path,
    width: int,
) -> ThumbnailResult:
    """Synchronous PyMuPDF render.  Called from `_extract_pdf` via
    `asyncio.to_thread` so the worker's event loop isn't blocked.

    Imports PyMuPDF lazily so a missing wheel on a fringe platform
    surfaces as a per-file skip rather than a startup crash.
    """
    try:
        import fitz  # type: ignore[import-untyped]
    except Exception as e:
        return ThumbnailResult(
            success=False,
            skipped=True,
            error=f"pymupdf not available: {e}",
        )

    try:
        with fitz.open(str(file_path)) as doc:
            if getattr(doc, "is_encrypted", False) and doc.needs_pass:
                return ThumbnailResult(
                    success=False,
                    skipped=True,
                    error="encrypted PDF",
                )
            if doc.page_count == 0:
                return ThumbnailResult(
                    success=False,
                    skipped=True,
                    error="empty PDF (no pages)",
                )
            page = doc[0]
            page_width = float(page.rect.width)
            if page_width <= 0:
                return ThumbnailResult(
                    success=False,
                    skipped=True,
                    error="zero-width page",
                )
            zoom = width / page_width
            matrix = fitz.Matrix(zoom, zoom)
            pix = page.get_pixmap(matrix=matrix, alpha=False)
            pix.save(str(output_path), jpg_quality=85)
    except Exception as e:
        return ThumbnailResult(
            success=False,
            error=f"pymupdf failed: {e}",
        )

    if output_path.exists() and output_path.stat().st_size > 0:
        return ThumbnailResult(success=True)
    return ThumbnailResult(success=False, error="pymupdf produced empty output")


async def _extract_pdf(
    file_path: Path,
    output_path: Path,
    *,
    width: int,
) -> ThumbnailResult:
    """Render the first page of a PDF to JPEG using PyMuPDF.

    PyMuPDF is synchronous; wrapped in `asyncio.to_thread` so the
    worker's event loop stays free for the other slot.  Bounded by
    ``_PDF_TIMEOUT_SEC`` to prevent a malformed PDF from hanging.
    """
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(
                _render_pdf_first_page_sync, file_path, output_path, width
            ),
            timeout=_PDF_TIMEOUT_SEC,
        )
    except asyncio.TimeoutError:
        return ThumbnailResult(success=False, error="pymupdf timeout")


async def extract_thumbnail(
    file_path: Path,
    output_path: Path,
    *,
    kind: str,
    width: int = 320,
    duration_sec: float | None = None,
    hdr_format: str | None = None,
) -> ThumbnailResult:
    """Dispatch by ``kind`` and run the appropriate extractor.

    Caller is responsible for:
      * deciding the kind (typically ``kind_for_extension(extension)``)
      * picking the output path
      * cleaning up the output file on failure (this function makes
        no attempt to delete a partial file — the worker does that
        in its retry path)

    Returns a ``ThumbnailResult`` with ``success`` / ``skipped`` / ``error``.
    Never raises.  The worker treats:
      * ``success=True``                → status='ready'
      * ``skipped=True``                → status='skipped' (permanent)
      * ``success=False, skipped=False`` → status='failed' (retry)
    """
    width = _clamp_width(width)

    # Defensive: ensure output dir exists.  Worker should already have
    # created it but the cost is one stat call and keeps this function
    # standalone-testable.
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        return ThumbnailResult(success=False, error=f"mkdir failed: {e}")

    if not file_path.exists():
        return ThumbnailResult(success=False, error="source file not found")

    if kind == "video":
        return await _extract_video(
            file_path,
            output_path,
            width=width,
            duration_sec=duration_sec,
            hdr_format=hdr_format,
        )
    if kind == "image":
        return await _extract_image(file_path, output_path, width=width)
    if kind == "audio":
        return await _extract_audio(file_path, output_path)
    if kind == "pdf":
        return await _extract_pdf(file_path, output_path, width=width)

    return ThumbnailResult(
        success=False,
        skipped=True,
        error=f"unsupported kind: {kind}",
    )
