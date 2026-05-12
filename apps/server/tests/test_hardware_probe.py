"""Tests for services/hardware_probe.py + /api/v1/transcoding/devices."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from services import hardware_probe


@pytest.fixture(autouse=True)
def _reset_probe_cache():
    hardware_probe.reset_cache()
    yield
    hardware_probe.reset_cache()


# ── _vendor_from_pci_or_name ────────────────────────────────────────────────


def test_vendor_from_pci_recognises_nvidia_variants():
    f = hardware_probe._vendor_from_pci_or_name
    assert f("NVIDIA Corporation GeForce RTX 4070") == "nvidia"
    assert f("NVIDIA GeForce GTX 1080") == "nvidia"
    assert f("Quadro P2000") == "nvidia"


def test_vendor_from_pci_recognises_intel_variants():
    f = hardware_probe._vendor_from_pci_or_name
    assert f("Intel(R) Iris Xe Graphics") == "intel"
    assert f("Intel UHD Graphics 770") == "intel"


def test_vendor_from_pci_recognises_amd_variants():
    f = hardware_probe._vendor_from_pci_or_name
    assert f("Advanced Micro Devices, Inc. [AMD/ATI] Navi 31") == "amd"
    assert f("AMD Radeon RX 7900 XTX") == "amd"


def test_vendor_from_pci_unknown_returns_unknown():
    f = hardware_probe._vendor_from_pci_or_name
    assert f("Some random GPU we don't know about") == "unknown"


# ── _encoder_support_for_vendor ─────────────────────────────────────────────


def test_encoder_support_for_software_vendor_includes_libx264_and_libx265():
    """Software encoders are platform-universal — both should be present."""
    support = hardware_probe._encoder_support_for_vendor("software")
    assert "libx264" in support
    assert "libx265" in support


def test_encoder_support_for_unknown_vendor_returns_empty():
    assert hardware_probe._encoder_support_for_vendor("unknown") == []


# ── NVIDIA probe ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_probe_nvidia_parses_smi_output():
    smi_out = "GeForce RTX 4070, 12288, 535.171.04\n"
    with patch.object(hardware_probe, "_run", AsyncMock(return_value=smi_out)):
        gpus = await hardware_probe._probe_nvidia_gpus()
    assert len(gpus) == 1
    assert gpus[0]["vendor"] == "nvidia"
    assert gpus[0]["model"] == "GeForce RTX 4070"
    assert gpus[0]["vram_mb"] == 12288
    assert gpus[0]["driver_version"] == "535.171.04"
    assert "h264_nvenc" in gpus[0]["encoder_support"]
    assert "hevc_nvenc" in gpus[0]["encoder_support"]


@pytest.mark.asyncio
async def test_probe_nvidia_returns_empty_when_smi_missing():
    with patch.object(hardware_probe, "_run", AsyncMock(return_value=None)):
        gpus = await hardware_probe._probe_nvidia_gpus()
    assert gpus == []


@pytest.mark.asyncio
async def test_probe_nvidia_handles_multi_gpu_setup():
    smi_out = "GeForce RTX 4070, 12288, 535.171.04\n" "Quadro P2000, 5120, 535.171.04\n"
    with patch.object(hardware_probe, "_run", AsyncMock(return_value=smi_out)):
        gpus = await hardware_probe._probe_nvidia_gpus()
    assert len(gpus) == 2
    assert gpus[0]["model"] == "GeForce RTX 4070"
    assert gpus[1]["model"] == "Quadro P2000"
    assert gpus[1]["vram_mb"] == 5120


# ── Windows wmic GPU probe ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_probe_gpus_windows_parses_wmic_csv():
    wmic_out = (
        "Node,AdapterRAM,DriverVersion,Name\r\n"
        "DESKTOP-PC,4293918720,32.0.15.5594,NVIDIA GeForce RTX 4070\r\n"
        "DESKTOP-PC,1073741824,31.0.101.4502,Intel(R) UHD Graphics 770\r\n"
    )
    # nvidia-smi supplements: returns the same NVIDIA card with full VRAM.
    smi_out = "GeForce RTX 4070, 12288, 535.171.04\n"
    runs = [wmic_out, smi_out]
    mock = AsyncMock(side_effect=runs)
    with patch.object(hardware_probe, "_run", mock):
        gpus = await hardware_probe._probe_gpus_windows()
    # Two distinct cards detected.
    assert len(gpus) == 2
    nvidia = next(g for g in gpus if g["vendor"] == "nvidia")
    intel = next(g for g in gpus if g["vendor"] == "intel")
    # NVIDIA row's VRAM was upgraded by nvidia-smi (wmic caps at ~4 GB).
    assert nvidia["vram_mb"] == 12288
    assert nvidia["driver_version"] == "535.171.04"
    # Intel row keeps its wmic-reported metadata.
    assert "Intel" in intel["model"]
    assert intel["vram_mb"] == 1024  # 1 GB


@pytest.mark.asyncio
async def test_probe_gpus_windows_handles_wmic_unavailable():
    with patch.object(hardware_probe, "_run", AsyncMock(return_value=None)):
        gpus = await hardware_probe._probe_gpus_windows()
    assert gpus == []


# ── detect_hardware caching ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_detect_hardware_caches_result():
    """A second call must not re-invoke any probe."""
    probe = AsyncMock(
        return_value=[
            {
                "vendor": "nvidia",
                "model": "x",
                "vram_mb": None,
                "driver_version": None,
                "dev_path": None,
                "encoder_support": [],
            }
        ]
    )
    cpu_probe = AsyncMock(
        return_value=[{"vendor": "Intel", "model": "x", "threads": 16}]
    )
    with (
        patch.object(hardware_probe, "_probe_gpus_windows", probe),
        patch.object(hardware_probe, "_probe_cpu_windows", cpu_probe),
        patch("sys.platform", "win32"),
    ):
        out1 = await hardware_probe.detect_hardware()
        out2 = await hardware_probe.detect_hardware()
    assert out1 is out2  # identical object — cached
    assert probe.call_count == 1
    assert cpu_probe.call_count == 1


@pytest.mark.asyncio
async def test_detect_hardware_unsupported_platform_returns_empty():
    with patch("sys.platform", "freebsd"):
        out = await hardware_probe.detect_hardware()
    assert out == {"cpus": [], "gpus": []}


# ── /api/v1/transcoding/devices endpoint ────────────────────────────────────


@pytest.mark.asyncio
async def test_devices_endpoint_returns_probe_result(client: AsyncClient):
    fake = {
        "cpus": [{"vendor": "Intel", "model": "i7", "threads": 16}],
        "gpus": [
            {
                "vendor": "nvidia",
                "model": "GeForce RTX 4070",
                "vram_mb": 12288,
                "driver_version": "535.171.04",
                "dev_path": None,
                "encoder_support": ["h264_nvenc", "hevc_nvenc"],
            }
        ],
    }
    with patch.object(hardware_probe, "detect_hardware", AsyncMock(return_value=fake)):
        resp = await client.get("/api/v1/transcoding/devices")
    assert resp.status_code == 200
    body = resp.json()
    assert body["cpus"][0]["vendor"] == "Intel"
    assert body["gpus"][0]["model"] == "GeForce RTX 4070"
    assert body["gpus"][0]["vram_mb"] == 12288
    assert "h264_nvenc" in body["gpus"][0]["encoder_support"]


@pytest.mark.asyncio
async def test_devices_endpoint_handles_empty_probe(client: AsyncClient):
    """Probe failure → empty lists, but endpoint still returns 200."""
    with patch.object(
        hardware_probe,
        "detect_hardware",
        AsyncMock(return_value={"cpus": [], "gpus": []}),
    ):
        resp = await client.get("/api/v1/transcoding/devices")
    assert resp.status_code == 200
    assert resp.json() == {"cpus": [], "gpus": []}
