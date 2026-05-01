"""System stats — CPU, RAM, network, uptime, LAN IP, internet connectivity.

Backs the sidebar System Status block, the bottom status bar, and the Dashboard
sparklines. Exposed via REST (`GET /api/v1/info/stats`) and pushed via WebSocket
(`{"type": "stats", "data": ...}` on `/api/v1/ws/stats`).
"""

from __future__ import annotations

import asyncio
import logging
import socket
import time
from typing import TypedDict

import aiosqlite
import psutil

logger = logging.getLogger(__name__)


_PROCESS = psutil.Process()
_INTERNET_PROBE_HOST = "1.1.1.1"
_INTERNET_PROBE_PORT = 80
_INTERNET_PROBE_TIMEOUT_SEC = 1.5
_INTERNET_PROBE_TTL_SEC = 30.0


class StatsPayload(TypedDict):
    uptime_seconds: int
    lan_ip: str | None
    public_address: str | None
    internet_connected: bool
    cpu_percent: float
    ram_percent: float
    ram_used_bytes: int
    ram_total_bytes: int
    network_in_mbps: float
    network_out_mbps: float
    active_streams: int


class _NetSample(TypedDict):
    bytes_sent: int
    bytes_recv: int
    timestamp: float


class SystemStatsService:
    """Single shared instance — see module-level `system_stats` below.

    Holds the network-counter delta state and the cached internet-probe result
    so consecutive calls compute rates and don't re-probe on every tick.
    """

    def __init__(self) -> None:
        self._last_net: _NetSample | None = None
        self._cached_internet: tuple[bool, float] | None = None  # (result, ts)

    async def collect(self, db: aiosqlite.Connection) -> StatsPayload:
        cpu = psutil.cpu_percent(interval=None)  # non-blocking; uses last interval
        vm = psutil.virtual_memory()
        net_in, net_out = self._network_rate_mbps()
        active = await self._active_stream_count(db)
        internet = await self._internet_connected()

        return {
            "uptime_seconds": int(time.time() - _PROCESS.create_time()),
            "lan_ip": self._lan_ip(),
            "public_address": None,  # filled in by a dedicated PR — needs STUN
            "internet_connected": internet,
            "cpu_percent": round(cpu, 1),
            "ram_percent": round(vm.percent, 1),
            "ram_used_bytes": int(vm.used),
            "ram_total_bytes": int(vm.total),
            "network_in_mbps": round(net_in, 2),
            "network_out_mbps": round(net_out, 2),
            "active_streams": active,
        }

    # ── internals ────────────────────────────────────────────────────────

    def _network_rate_mbps(self) -> tuple[float, float]:
        """Compute receive / transmit rate in Mbps since the last call.

        Excludes loopback. First call returns (0, 0) because there is no
        baseline to diff against yet.
        """
        per_nic = psutil.net_io_counters(pernic=True)
        bytes_sent = 0
        bytes_recv = 0
        for nic, counters in per_nic.items():
            if "loopback" in nic.lower() or nic.lower() == "lo":
                continue
            bytes_sent += counters.bytes_sent
            bytes_recv += counters.bytes_recv

        now = time.monotonic()
        if self._last_net is None:
            self._last_net = {
                "bytes_sent": bytes_sent,
                "bytes_recv": bytes_recv,
                "timestamp": now,
            }
            return 0.0, 0.0

        elapsed = now - self._last_net["timestamp"]
        if elapsed <= 0:
            return 0.0, 0.0

        delta_recv = max(0, bytes_recv - self._last_net["bytes_recv"])
        delta_sent = max(0, bytes_sent - self._last_net["bytes_sent"])
        self._last_net = {
            "bytes_sent": bytes_sent,
            "bytes_recv": bytes_recv,
            "timestamp": now,
        }

        # bytes/sec → Mbps (× 8 for bits, ÷ 1_000_000 for mega)
        return (
            (delta_recv * 8) / (elapsed * 1_000_000),
            (delta_sent * 8) / (elapsed * 1_000_000),
        )

    @staticmethod
    async def _active_stream_count(db: aiosqlite.Connection) -> int:
        async with db.execute(
            "SELECT COUNT(*) FROM stream_sessions WHERE ended_at IS NULL"
        ) as cur:
            row = await cur.fetchone()
        return int(row[0]) if row else 0

    @staticmethod
    def _lan_ip() -> str | None:
        """Best-effort LAN IPv4 detection.

        Opens a UDP socket to a non-routable destination — the kernel selects
        the local interface that would be used to reach it, no packet is sent.
        Returns None if the host has no usable interface (rare; air-gapped).
        """
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("10.255.255.255", 1))
            return s.getsockname()[0]
        except OSError:
            return None
        finally:
            s.close()

    async def _internet_connected(self) -> bool:
        """TCP probe to a stable host. Cached for `_INTERNET_PROBE_TTL_SEC`."""
        now = time.monotonic()
        if self._cached_internet is not None:
            result, ts = self._cached_internet
            if now - ts < _INTERNET_PROBE_TTL_SEC:
                return result

        result = await self._probe_internet()
        self._cached_internet = (result, now)
        return result

    @staticmethod
    async def _probe_internet() -> bool:
        try:
            fut = asyncio.open_connection(_INTERNET_PROBE_HOST, _INTERNET_PROBE_PORT)
            reader, writer = await asyncio.wait_for(
                fut, timeout=_INTERNET_PROBE_TIMEOUT_SEC
            )
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass
            return True
        except (TimeoutError, OSError):
            return False


system_stats = SystemStatsService()
