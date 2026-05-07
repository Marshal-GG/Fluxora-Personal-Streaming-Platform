"""Hardware-probe — per-OS CPU + GPU enumeration for the desktop's
"Detected Hardware" card and the VAAPI device-path picker.

All probes are **best-effort**: if a binary is missing or the parse fails,
we log at WARNING and return an empty list rather than raising.  The
result is cached for the lifetime of the server process — hardware
doesn't change at runtime, and probes can be slow (`wmic` cold start
costs ~500 ms on Windows; `nvidia-smi -L` ~200 ms).

The output shape is tight on purpose:

```python
{
    "cpus": [{"vendor": str, "model": str, "threads": int}],
    "gpus": [
        {
            "vendor": "nvidia" | "intel" | "amd" | "apple" | "unknown",
            "model": str,             # human-readable
            "vram_mb": int | None,    # total VRAM if known
            "driver_version": str | None,
            "dev_path": str | None,   # /dev/dri/renderD128 etc. (Linux VAAPI)
            "encoder_support": list[str],  # encoder names from registry
        }
    ],
}
```

``encoder_support`` is *derived* from the encoder registry's vendor + platform
metadata — not probed.  It tells the operator "FFmpeg with this GPU's vendor
on this OS *could* drive these encoders if the FFmpeg build includes them"
which is paired with `/transcoding/status`'s actual ``available_encoders``
to surface the truth.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import sys
from typing import Any

from services.encoder_registry import ENCODER_REGISTRY

logger = logging.getLogger(__name__)


# Cached probe result — populated on first call, never refreshed for the
# lifetime of the server process.  Hardware doesn't change at runtime.
_CACHE: dict[str, list[dict[str, Any]]] | None = None


# ── small process helpers ────────────────────────────────────────────────────


async def _run(args: list[str], timeout: float = 3.0) -> str | None:
    """Run a probe command and return stdout, or None on any failure.

    Probes are intentionally short-timeout — a hung `wmic` shouldn't
    block the desktop from rendering the rest of the Streaming tab.
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        out, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except (TimeoutError, OSError, FileNotFoundError):
        return None
    if proc.returncode != 0:
        return None
    return out.decode(errors="replace").strip()


def _vendor_from_pci_or_name(text: str) -> str:
    """Map a free-form vendor-or-model string to our canonical vendor enum.

    Used by every probe to harmonise outputs that range from `Intel(R)
    Corporation Iris Xe Graphics` to `NVIDIA GeForce RTX 4070` to
    `Advanced Micro Devices, Inc. [AMD/ATI] Navi 31`.
    """
    t = text.lower()
    if "nvidia" in t or "geforce" in t or "rtx" in t or "gtx" in t or "quadro" in t:
        return "nvidia"
    if "intel" in t or "iris" in t or "uhd graphics" in t:
        return "intel"
    if "amd" in t or "radeon" in t or "ati" in t or "navi" in t:
        return "amd"
    if "apple" in t or "metal" in t:
        return "apple"
    return "unknown"


def _encoder_support_for_vendor(vendor: str) -> list[str]:
    """Return registry encoder names whose vendor matches *and* whose
    platform set includes the current OS.

    Platform filtering keeps macOS hosts from advertising VAAPI support
    just because an AMD GPU is installed, etc.
    """
    return [
        name
        for name, meta in ENCODER_REGISTRY.items()
        if meta.vendor == vendor and meta.is_platform_supported()
    ]


# ── CPU probes ───────────────────────────────────────────────────────────────


async def _probe_cpu_linux() -> list[dict[str, Any]]:
    """Read `/proc/cpuinfo` for the CPU model + thread count."""
    try:
        with open("/proc/cpuinfo", encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return []
    model = "Unknown CPU"
    threads = os.cpu_count() or 0
    m = re.search(r"^model name\s*:\s*(.+)$", text, re.MULTILINE)
    if m:
        model = m.group(1).strip()
    vendor_id_match = re.search(r"^vendor_id\s*:\s*(.+)$", text, re.MULTILINE)
    vendor = vendor_id_match.group(1).strip() if vendor_id_match else ""
    if "Intel" in model or "GenuineIntel" in vendor:
        vendor_label = "Intel"
    elif "AMD" in model or "AuthenticAMD" in vendor:
        vendor_label = "AMD"
    else:
        vendor_label = vendor or "Unknown"
    return [{"vendor": vendor_label, "model": model, "threads": threads}]


async def _probe_cpu_windows() -> list[dict[str, Any]]:
    """`wmic cpu get Name,NumberOfLogicalProcessors /format:csv`."""
    out = await _run(
        [
            "wmic",
            "cpu",
            "get",
            "Name,NumberOfLogicalProcessors",
            "/format:csv",
        ],
        timeout=5.0,
    )
    if not out:
        return [
            {
                "vendor": "Unknown",
                "model": "Unknown CPU",
                "threads": os.cpu_count() or 0,
            }
        ]
    cpus: list[dict[str, Any]] = []
    # CSV header: Node,Name,NumberOfLogicalProcessors
    for line in out.splitlines():
        line = line.strip()
        if not line or line.startswith("Node"):
            continue
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 3:
            continue
        # parts[0] = node, parts[1] = name, parts[2] = threads
        model = parts[1]
        try:
            threads = int(parts[2])
        except ValueError:
            threads = os.cpu_count() or 0
        if not model:
            continue
        vendor = "Intel" if "Intel" in model else "AMD" if "AMD" in model else "Unknown"
        cpus.append({"vendor": vendor, "model": model, "threads": threads})
    if not cpus:
        cpus.append(
            {
                "vendor": "Unknown",
                "model": "Unknown CPU",
                "threads": os.cpu_count() or 0,
            }
        )
    return cpus


async def _probe_cpu_macos() -> list[dict[str, Any]]:
    out = await _run(["sysctl", "-n", "machdep.cpu.brand_string"], timeout=2.0)
    threads = os.cpu_count() or 0
    if not out:
        return [{"vendor": "Apple", "model": "Apple Silicon", "threads": threads}]
    model = out.strip()
    vendor = "Apple" if "Apple" in model else "Intel" if "Intel" in model else "Unknown"
    return [{"vendor": vendor, "model": model, "threads": threads}]


# ── GPU probes ───────────────────────────────────────────────────────────────


async def _probe_nvidia_gpus() -> list[dict[str, Any]]:
    """`nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,
    noheader`."""
    out = await _run(
        [
            "nvidia-smi",
            "--query-gpu=name,memory.total,driver_version",
            "--format=csv,noheader,nounits",
        ],
        timeout=3.0,
    )
    if not out:
        return []
    gpus: list[dict[str, Any]] = []
    for line in out.splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) < 3:
            continue
        model, vram_str, driver = parts[0], parts[1], parts[2]
        try:
            vram_mb = int(vram_str)
        except ValueError:
            vram_mb = None
        gpus.append(
            {
                "vendor": "nvidia",
                "model": model,
                "vram_mb": vram_mb,
                "driver_version": driver,
                "dev_path": None,
                "encoder_support": _encoder_support_for_vendor("nvidia"),
            }
        )
    return gpus


async def _probe_gpus_linux() -> list[dict[str, Any]]:
    """Walk `lspci` for VGA-class devices + nvidia-smi for richer NVIDIA
    detail + `/dev/dri/render*` enumeration for VAAPI device paths."""
    gpus: list[dict[str, Any]] = []

    nvidia = await _probe_nvidia_gpus()
    gpus.extend(nvidia)
    nvidia_seen = bool(nvidia)

    out = await _run(["lspci", "-nn", "-d", "::0300"], timeout=2.0)
    if out:
        for line in out.splitlines():
            line = line.strip()
            if not line:
                continue
            # Format: "01:00.0 VGA compatible controller [0300]: NVIDIA Corp. ..."
            after_class = line.split(":", 2)[-1].strip() if ":" in line else line
            vendor = _vendor_from_pci_or_name(after_class)
            # Skip NVIDIA if nvidia-smi already gave us better data.
            if vendor == "nvidia" and nvidia_seen:
                continue
            # Strip the trailing "[vendor:device]" annotation if present.
            model = re.sub(
                r"\s*\[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]\s*$", "", after_class
            ).strip()
            gpus.append(
                {
                    "vendor": vendor,
                    "model": model,
                    "vram_mb": None,
                    "driver_version": None,
                    "dev_path": None,
                    "encoder_support": _encoder_support_for_vendor(vendor)
                    if vendor != "unknown"
                    else [],
                }
            )

    # /dev/dri/render* — every render node is potentially a VAAPI device.
    # Map them onto AMD/Intel rows by best-effort ordering (first non-NVIDIA
    # GPU gets the first render node).  Operator can override via
    # `transcoding_hwaccel_device` setting.
    try:
        render_nodes = sorted(
            f"/dev/dri/{name}"
            for name in os.listdir("/dev/dri")
            if name.startswith("renderD")
        )
    except OSError:
        render_nodes = []
    rn_iter = iter(render_nodes)
    for gpu in gpus:
        if gpu["vendor"] in ("amd", "intel") and gpu["dev_path"] is None:
            gpu["dev_path"] = next(rn_iter, None)

    return gpus


async def _probe_gpus_windows() -> list[dict[str, Any]]:
    """`wmic path Win32_VideoController get Name,AdapterRAM,DriverVersion`.

    `wmic` is deprecated on Win11 23H2+ but ships with every Windows
    install we ship to.  AdapterRAM caps at ~4 GB on 32-bit `wmic`
    builds — we leave the value as-is and accept the cap as a known
    limitation; the headline use of this probe is the model name + the
    driver version, both of which are accurate.
    """
    out = await _run(
        [
            "wmic",
            "path",
            "Win32_VideoController",
            "get",
            "Name,AdapterRAM,DriverVersion",
            "/format:csv",
        ],
        timeout=5.0,
    )
    gpus: list[dict[str, Any]] = []
    if not out:
        return gpus
    # CSV header: Node,AdapterRAM,DriverVersion,Name
    header_indices: dict[str, int] | None = None
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(",")]
        if header_indices is None and "Name" in parts:
            header_indices = {h: i for i, h in enumerate(parts)}
            continue
        if header_indices is None:
            continue
        try:
            model = parts[header_indices["Name"]]
            ram_raw = (
                parts[header_indices.get("AdapterRAM", -1)]
                if "AdapterRAM" in header_indices
                else ""
            )
            driver = (
                parts[header_indices.get("DriverVersion", -1)]
                if "DriverVersion" in header_indices
                else ""
            )
        except (IndexError, KeyError):
            continue
        if not model:
            continue
        try:
            vram_mb = int(ram_raw) // (1024 * 1024) if ram_raw else None
        except ValueError:
            vram_mb = None
        vendor = _vendor_from_pci_or_name(model)
        gpus.append(
            {
                "vendor": vendor,
                "model": model,
                "vram_mb": vram_mb,
                "driver_version": driver or None,
                "dev_path": None,  # VAAPI doesn't apply on Windows
                "encoder_support": _encoder_support_for_vendor(vendor)
                if vendor != "unknown"
                else [],
            }
        )

    # Supplement NVIDIA rows with nvidia-smi for the accurate VRAM total
    # (wmic AdapterRAM caps at 4 GB) and driver_version.
    nvidia = await _probe_nvidia_gpus()
    for n in nvidia:
        for existing in gpus:
            if existing["vendor"] == "nvidia" and (
                existing["model"] == n["model"]
                or (existing["model"] and n["model"]
                    and existing["model"].split()[-1] == n["model"].split()[-1])
            ):
                if n["vram_mb"]:
                    existing["vram_mb"] = n["vram_mb"]
                if n["driver_version"]:
                    existing["driver_version"] = n["driver_version"]
                break
        else:
            # nvidia-smi reported a card wmic didn't — keep both, with the
            # nvidia-smi version winning.
            gpus.append(n)
    return gpus


async def _probe_gpus_macos() -> list[dict[str, Any]]:
    out = await _run(
        ["system_profiler", "SPDisplaysDataType", "-json"], timeout=4.0
    )
    if not out:
        return []
    try:
        data = json.loads(out)
    except ValueError:
        return []
    rows = data.get("SPDisplaysDataType", []) or []
    gpus: list[dict[str, Any]] = []
    for row in rows:
        model = row.get("sppci_model") or row.get("_name") or "Unknown GPU"
        vram = row.get("spdisplays_vram") or row.get("spdisplays_vram_shared") or ""
        vram_mb: int | None = None
        m = re.match(r"\s*([\d.]+)\s*(GB|MB)", str(vram), re.IGNORECASE)
        if m:
            amount = float(m.group(1))
            unit = m.group(2).upper()
            vram_mb = int(amount * 1024) if unit == "GB" else int(amount)
        vendor = _vendor_from_pci_or_name(str(model))
        gpus.append(
            {
                "vendor": vendor,
                "model": str(model),
                "vram_mb": vram_mb,
                "driver_version": None,
                "dev_path": None,
                "encoder_support": _encoder_support_for_vendor(vendor)
                if vendor != "unknown"
                else [],
            }
        )
    return gpus


# ── public API ───────────────────────────────────────────────────────────────


async def detect_hardware() -> dict[str, list[dict[str, Any]]]:
    """Return cached `{cpus: [...], gpus: [...]}`; probe on first call."""
    global _CACHE
    if _CACHE is not None:
        return _CACHE

    platform = sys.platform
    try:
        if platform == "linux":
            cpus = await _probe_cpu_linux()
            gpus = await _probe_gpus_linux()
        elif platform == "win32":
            cpus = await _probe_cpu_windows()
            gpus = await _probe_gpus_windows()
        elif platform == "darwin":
            cpus = await _probe_cpu_macos()
            gpus = await _probe_gpus_macos()
        else:
            logger.warning("Unsupported platform for hardware probe: %s", platform)
            cpus, gpus = [], []
    except Exception:
        logger.warning("Hardware probe failed", exc_info=True)
        cpus, gpus = [], []

    _CACHE = {"cpus": cpus, "gpus": gpus}
    logger.info(
        "Hardware probe: %d CPU(s), %d GPU(s) on %s",
        len(cpus),
        len(gpus),
        platform,
    )
    return _CACHE


def reset_cache() -> None:
    """Test hook — clear the cached probe so the next call re-runs."""
    global _CACHE
    _CACHE = None
