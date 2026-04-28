import logging
import socket

from zeroconf import ServiceInfo
from zeroconf.asyncio import AsyncZeroconf

logger = logging.getLogger(__name__)

_SERVICE_TYPE = "_fluxora._tcp.local."
_zeroconf: AsyncZeroconf | None = None
_service_info: ServiceInfo | None = None


def _local_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


async def start_discovery(server_name: str, port: int) -> None:
    global _zeroconf, _service_info

    ip = _local_ip()
    hostname = socket.gethostname()
    service_name = f"{server_name}.{_SERVICE_TYPE}"

    _service_info = ServiceInfo(
        _SERVICE_TYPE,
        service_name,
        addresses=[socket.inet_aton(ip)],
        port=port,
        properties={"version": "0.1.0", "name": server_name},
        server=f"{hostname}.local.",
    )

    _zeroconf = AsyncZeroconf()
    await _zeroconf.async_register_service(_service_info)
    logger.info("mDNS broadcasting '%s' on %s:%d", server_name, ip, port)


async def stop_discovery() -> None:
    global _zeroconf, _service_info

    if _zeroconf and _service_info:
        try:
            await _zeroconf.async_unregister_service(_service_info)
            await _zeroconf.async_close()
            logger.info("mDNS broadcast stopped")
        except Exception:
            logger.warning("Error stopping mDNS", exc_info=True)
        finally:
            _zeroconf = None
            _service_info = None
