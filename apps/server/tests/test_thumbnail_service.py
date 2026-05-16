"""Unit tests for ``services/thumbnail_service.py``.

Uses FFmpeg's ``lavfi`` synthetic inputs where possible so the tests
don't require checked-in binary fixtures.  PDF tests render small
fixtures on the fly via PyMuPDF.

These tests exercise the four extractor paths + the dispatcher's
defensive branches (missing file, unknown kind, output-dir creation).
Each test cleans up after itself by writing into ``tmp_path``.
"""

from __future__ import annotations

import asyncio
import shutil
import struct
from pathlib import Path

import pytest

from services.thumbnail_service import (
    ThumbnailResult,
    _build_video_filter_chain,
    extract_thumbnail,
    kind_for_extension,
)


# ── kind dispatch table ────────────────────────────────────────────────────


def test_kind_for_extension_video():
    assert kind_for_extension(".mkv") == "video"
    assert kind_for_extension(".MP4") == "video"  # case-insensitive
    assert kind_for_extension(".ts") == "video"


def test_kind_for_extension_image():
    assert kind_for_extension(".jpg") == "image"
    assert kind_for_extension(".png") == "image"
    assert kind_for_extension(".heic") == "image"


def test_kind_for_extension_audio():
    assert kind_for_extension(".mp3") == "audio"
    assert kind_for_extension(".flac") == "audio"


def test_kind_for_extension_pdf():
    assert kind_for_extension(".pdf") == "pdf"


def test_kind_for_extension_unknown():
    assert kind_for_extension(".txt") is None
    assert kind_for_extension(".docx") is None
    assert kind_for_extension("") is None


# ── Dispatcher defensive branches ──────────────────────────────────────────


async def test_extract_thumbnail_missing_source(tmp_path: Path):
    result = await extract_thumbnail(
        tmp_path / "does-not-exist.mp4",
        tmp_path / "out.jpg",
        kind="video",
    )
    assert result.success is False
    assert result.skipped is False
    assert "not found" in (result.error or "").lower()


async def test_extract_thumbnail_unknown_kind(tmp_path: Path):
    src = tmp_path / "anything.bin"
    src.write_bytes(b"\x00")
    result = await extract_thumbnail(
        src, tmp_path / "out.jpg", kind="docx"
    )
    assert result.success is False
    assert result.skipped is True
    assert "unsupported" in (result.error or "").lower()


async def test_extract_thumbnail_creates_output_dir(tmp_path: Path):
    """Dispatcher should mkdir -p the output's parent directory."""
    src = tmp_path / "anything.bin"
    src.write_bytes(b"\x00")
    out = tmp_path / "deep" / "nested" / "out.jpg"
    # unknown kind so we exit early after the mkdir
    result = await extract_thumbnail(src, out, kind="docx")
    assert out.parent.is_dir()
    assert result.skipped is True  # confirms mkdir didn't crash


# ── Video extractor (real FFmpeg via lavfi testsrc) ────────────────────────
#
# `lavfi` is FFmpeg's synthetic-source virtual demuxer.  `testsrc=...` paints
# a colour-bar pattern; we feed it directly as `-i lavfi=...`.  Since our
# extractor expects a real file path, we first render a short clip to disk,
# then run the extractor against it.


def _ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None


@pytest.fixture
def synthetic_video(tmp_path: Path) -> Path:
    """Render a 5-second 320x240 SDR test pattern via FFmpeg."""
    if not _ffmpeg_available():
        pytest.skip("ffmpeg not on PATH")
    out = tmp_path / "synthetic.mp4"
    cmd = [
        "ffmpeg",
        "-y",
        "-f",
        "lavfi",
        "-i",
        "testsrc=duration=5:size=320x240:rate=10",
        "-pix_fmt",
        "yuv420p",
        "-c:v",
        "libx264",
        "-preset",
        "ultrafast",
        "-loglevel",
        "error",
        str(out),
    ]
    import subprocess

    rc = subprocess.run(cmd, capture_output=True).returncode
    if rc != 0 or not out.exists():
        pytest.skip("ffmpeg lavfi unavailable")
    return out


async def test_extract_video_sdr_path(synthetic_video: Path, tmp_path: Path):
    out = tmp_path / "thumb.jpg"
    result = await extract_thumbnail(
        synthetic_video,
        out,
        kind="video",
        width=160,
        duration_sec=5.0,
        hdr_format=None,
    )
    assert result.success is True, f"expected success, got {result}"
    assert out.exists() and out.stat().st_size > 0
    # JPEG SOI marker
    assert out.read_bytes()[:2] == b"\xff\xd8"


def test_video_filter_chain_sdr():
    """SDR path: scale + format=yuv420p in one pass."""
    vf = _build_video_filter_chain(width=320, hdr=False)
    assert "scale=320:-2:flags=lanczos" in vf
    assert "format=yuv420p" in vf
    # SDR path must NOT include the tonemap operator
    assert "tonemap=" not in vf
    assert "zscale=" not in vf


def test_video_filter_chain_hdr_includes_tonemap():
    """HDR path: zscale -> tonemap=hable -> SDR transfer -> scale."""
    vf = _build_video_filter_chain(width=320, hdr=True)
    # The Hable tonemap operator is what plan 17's stream path uses too.
    assert "tonemap=tonemap=hable" in vf
    # PQ linearisation + SDR primary/transfer/matrix steps.
    assert "zscale=t=linear:npl=100" in vf
    assert "zscale=p=bt709" in vf
    assert "zscale=t=bt709:m=bt709" in vf
    # Final downscale runs AFTER the tonemap so resize works on SDR pixels.
    assert vf.endswith(f"scale=320:-2:flags=lanczos")
    # Width is plumbed correctly.
    vf_640 = _build_video_filter_chain(width=640, hdr=True)
    assert "scale=640:-2:flags=lanczos" in vf_640


# Note: there's no end-to-end HDR pipeline test here.  An accurate test
# would need a real HDR-encoded fixture (BT.2020 + PQ + x264 with proper
# VUI tagging) — synthetic-PQ via FFmpeg's `color` filter trips zscale's
# "no path between colorspaces" guard because libx264's lavfi shape
# doesn't carry the stream-level colorspace VUI flags zscale needs.
# The HDR filter chain itself is byte-identical to the production
# stream-side tonemap (`services/ffmpeg_service._HDR_TO_SDR_VF`) which
# is operator-verified on real HDR content (plan 17).  The `_build_
# video_filter_chain` unit test above proves the right chain is wired
# up when `hdr_format` is set.


async def test_extract_video_short_clip(tmp_path: Path):
    """Clips shorter than 3 s use the 1.0-second floor for the seek time."""
    if not _ffmpeg_available():
        pytest.skip("ffmpeg not on PATH")
    src = tmp_path / "short.mp4"
    import subprocess

    rc = subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=2:size=160x120:rate=10",
            "-pix_fmt",
            "yuv420p",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-loglevel",
            "error",
            str(src),
        ],
        capture_output=True,
    ).returncode
    if rc != 0:
        pytest.skip("ffmpeg lavfi unavailable")

    out = tmp_path / "short_thumb.jpg"
    result = await extract_thumbnail(
        src, out, kind="video", width=160, duration_sec=2.0
    )
    assert result.success is True


async def test_extract_video_corrupt_file(tmp_path: Path):
    """A file with the right extension but corrupt bytes fails (not skipped)."""
    if not _ffmpeg_available():
        pytest.skip("ffmpeg not on PATH")
    src = tmp_path / "fake.mp4"
    src.write_bytes(b"not a real mp4")
    out = tmp_path / "out.jpg"
    result = await extract_thumbnail(src, out, kind="video", width=160)
    assert result.success is False
    assert result.skipped is False
    # error message should mention ffmpeg's exit code
    assert "ffmpeg" in (result.error or "").lower()


# ── Image extractor ────────────────────────────────────────────────────────


def _write_minimal_png(path: Path, *, width: int = 4, height: int = 4) -> None:
    """Write a valid (if tiny) PNG without depending on Pillow."""
    import zlib

    def _chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    # raw scanlines: filter byte 0 + 3 bytes per pixel (RGB) per row
    raw = b"".join(b"\x00" + b"\xff\x00\x00" * width for _ in range(height))
    idat = zlib.compress(raw)
    blob = sig + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", idat) + _chunk(b"IEND", b"")
    path.write_bytes(blob)


async def test_extract_image_png(tmp_path: Path):
    if not _ffmpeg_available():
        pytest.skip("ffmpeg not on PATH")
    src = tmp_path / "tiny.png"
    _write_minimal_png(src, width=8, height=8)
    out = tmp_path / "img_thumb.jpg"

    result = await extract_thumbnail(src, out, kind="image", width=160)
    assert result.success is True, f"expected success, got {result}"
    assert out.exists() and out.stat().st_size > 0
    assert out.read_bytes()[:2] == b"\xff\xd8"


# ── Audio extractor — skip on no embedded art ──────────────────────────────


async def test_extract_audio_no_picture_is_skipped(tmp_path: Path):
    """Synthetic audio (no APIC) yields ThumbnailResult(skipped=True)."""
    if not _ffmpeg_available():
        pytest.skip("ffmpeg not on PATH")
    src = tmp_path / "synthetic.mp3"
    import subprocess

    rc = subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "lavfi",
            "-i",
            "anullsrc=channel_layout=stereo:sample_rate=44100",
            "-t",
            "1",
            "-c:a",
            "libmp3lame",
            "-b:a",
            "64k",
            "-loglevel",
            "error",
            str(src),
        ],
        capture_output=True,
    ).returncode
    if rc != 0:
        pytest.skip("libmp3lame unavailable")

    out = tmp_path / "audio_thumb.jpg"
    result = await extract_thumbnail(src, out, kind="audio", width=160)
    assert result.success is False
    assert result.skipped is True
    assert "embedded album art" in (result.error or "").lower()


# ── PDF extractor (PyMuPDF) ────────────────────────────────────────────────


def _pymupdf_available() -> bool:
    try:
        import fitz  # noqa: F401

        return True
    except ImportError:
        return False


def _make_simple_pdf(path: Path) -> None:
    """Render a one-page PDF using PyMuPDF (tests are skipped if not installed)."""
    import fitz

    doc = fitz.open()
    page = doc.new_page(width=200, height=300)
    page.insert_text((20, 50), "Hello", fontsize=24)
    doc.save(str(path))
    doc.close()


async def test_extract_pdf_first_page(tmp_path: Path):
    if not _pymupdf_available():
        pytest.skip("pymupdf not installed")
    src = tmp_path / "tiny.pdf"
    _make_simple_pdf(src)
    out = tmp_path / "pdf_thumb.jpg"

    result = await extract_thumbnail(src, out, kind="pdf", width=200)
    assert result.success is True, f"expected success, got {result}"
    assert out.exists() and out.stat().st_size > 0
    assert out.read_bytes()[:2] == b"\xff\xd8"


async def test_extract_pdf_corrupt_is_failed(tmp_path: Path):
    """A file with the .pdf extension but garbage bytes is failed, not skipped."""
    if not _pymupdf_available():
        pytest.skip("pymupdf not installed")
    src = tmp_path / "broken.pdf"
    src.write_bytes(b"not a real pdf")
    out = tmp_path / "out.jpg"

    result = await extract_thumbnail(src, out, kind="pdf", width=200)
    assert result.success is False
    assert result.skipped is False  # transient — retry-able
    assert "pymupdf failed" in (result.error or "").lower()


async def test_extract_pdf_encrypted_is_skipped(tmp_path: Path):
    """Password-protected PDFs return skipped=True (no v1 password handling)."""
    if not _pymupdf_available():
        pytest.skip("pymupdf not installed")
    import fitz

    src = tmp_path / "encrypted.pdf"
    doc = fitz.open()
    page = doc.new_page(width=200, height=300)
    page.insert_text((20, 50), "Secret", fontsize=24)
    perm = int(
        fitz.PDF_PERM_ACCESSIBILITY  # type: ignore[attr-defined]
        | fitz.PDF_PERM_PRINT  # type: ignore[attr-defined]
    )
    doc.save(
        str(src),
        encryption=fitz.PDF_ENCRYPT_AES_256,  # type: ignore[attr-defined]
        owner_pw="owner",
        user_pw="user",
        permissions=perm,
    )
    doc.close()

    out = tmp_path / "out.jpg"
    result = await extract_thumbnail(src, out, kind="pdf", width=200)
    assert result.success is False
    assert result.skipped is True
    assert "encrypted" in (result.error or "").lower()


# ── Width clamping ─────────────────────────────────────────────────────────


async def test_extract_image_width_clamped_above_max(tmp_path: Path):
    """Width above the safety cap is silently clamped, not rejected."""
    if not _ffmpeg_available():
        pytest.skip("ffmpeg not on PATH")
    src = tmp_path / "tiny.png"
    _write_minimal_png(src, width=8, height=8)
    out = tmp_path / "huge.jpg"

    # Width 999999 should clamp to 2048; FFmpeg should still produce output.
    result = await extract_thumbnail(src, out, kind="image", width=999999)
    assert result.success is True


async def test_extract_image_width_clamped_below_min(tmp_path: Path):
    if not _ffmpeg_available():
        pytest.skip("ffmpeg not on PATH")
    src = tmp_path / "tiny.png"
    _write_minimal_png(src, width=8, height=8)
    out = tmp_path / "tiny.jpg"

    result = await extract_thumbnail(src, out, kind="image", width=1)
    assert result.success is True


# ── Concurrency / timeout (smoke) ──────────────────────────────────────────


async def test_concurrent_extractions(tmp_path: Path):
    """Two extractions running in parallel both succeed."""
    if not _ffmpeg_available():
        pytest.skip("ffmpeg not on PATH")
    src1 = tmp_path / "a.png"
    src2 = tmp_path / "b.png"
    _write_minimal_png(src1)
    _write_minimal_png(src2)
    out1 = tmp_path / "out1.jpg"
    out2 = tmp_path / "out2.jpg"

    results = await asyncio.gather(
        extract_thumbnail(src1, out1, kind="image", width=160),
        extract_thumbnail(src2, out2, kind="image", width=160),
    )
    assert all(r.success for r in results), f"got {results}"
    assert out1.exists() and out2.exists()
