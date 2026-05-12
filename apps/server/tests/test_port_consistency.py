"""Port-consistency guard.

The Fluxora server's HTTP port has ONE canonical source of truth:
`config.Settings.fluxora_port` (defaults to 8000).  Several files
outside Python need to reference the same value:

  - apps/server/Dockerfile       EXPOSE + uvicorn --port
  - apps/server/env.example      FLUXORA_PORT default in the .env
                                 template
  - apps/desktop/lib/core/di/injector.dart
                                 _defaultServerUrl when no URL is
                                 stored in secure storage
  - apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart
                                 SettingsCubit._defaultUrl (the value
                                 SettingsCubit emits when secure
                                 storage is empty; if this drifts
                                 from injector.dart the first save
                                 silently overwrites the correct URL)
  - apps/mobile/lib/features/connect/presentation/screens/connect_screen.dart
                                 manual-entry port field default +
                                 the `?? <port>` fallback when parse
                                 fails

These caused a multi-week drift when the canonical port changed from
8080 to 8000 -- only some sites were updated, leaving fresh installs
broken.  This test re-reads each file on every test run and asserts
the canonical port appears in the expected position.  When the
canonical port changes, every site listed here must move together or
this test fails.

When adding a new file that hardcodes the port, add a test case here
too so it joins the lockstep.
"""

from pathlib import Path

import pytest

from config import settings

REPO_ROOT = Path(__file__).resolve().parents[3]


@pytest.fixture(scope="module")
def canonical_port() -> int:
    return settings.fluxora_port


def _read(rel_path: str) -> str:
    return (REPO_ROOT / rel_path).read_text(encoding="utf-8")


def test_dockerfile_uses_canonical_port(canonical_port: int) -> None:
    text = _read("apps/server/Dockerfile")
    assert f"EXPOSE {canonical_port}" in text, (
        f"apps/server/Dockerfile must contain `EXPOSE {canonical_port}`. "
        f"Update it whenever Settings.fluxora_port changes."
    )
    assert f'"--port", "{canonical_port}"' in text, (
        f"apps/server/Dockerfile uvicorn CMD must use --port " f"{canonical_port}."
    )


def test_env_example_uses_canonical_port(canonical_port: int) -> None:
    text = _read("apps/server/env.example")
    assert f"FLUXORA_PORT={canonical_port}" in text, (
        f"apps/server/env.example must document "
        f"FLUXORA_PORT={canonical_port} so fresh installs match the "
        f"server's actual default."
    )


def test_desktop_injector_default_url_uses_canonical_port(
    canonical_port: int,
) -> None:
    text = _read("apps/desktop/lib/core/di/injector.dart")
    assert f"'http://localhost:{canonical_port}'" in text, (
        f"apps/desktop/lib/core/di/injector.dart _defaultServerUrl "
        f"must be 'http://localhost:{canonical_port}'."
    )


def test_desktop_settings_cubit_default_url_uses_canonical_port(
    canonical_port: int,
) -> None:
    text = _read(
        "apps/desktop/lib/features/settings/presentation/cubit/" "settings_cubit.dart"
    )
    assert f"'http://localhost:{canonical_port}'" in text, (
        f"SettingsCubit._defaultUrl must be "
        f"'http://localhost:{canonical_port}' -- this is the value "
        f"persisted to secure storage on the first save when the user "
        f"hasn't changed the URL.  Drift from injector.dart's default "
        f"silently breaks fresh installs."
    )


def test_mobile_connect_screen_uses_canonical_port(canonical_port: int) -> None:
    text = _read(
        "apps/mobile/lib/features/connect/presentation/screens/" "connect_screen.dart"
    )
    assert f"text: '{canonical_port}'" in text, (
        f"apps/mobile/.../connect_screen.dart _portController must "
        f"default to text: '{canonical_port}'."
    )
    assert f"?? {canonical_port}" in text, (
        f"apps/mobile/.../connect_screen.dart manual-entry fallback "
        f"must be `?? {canonical_port}`."
    )
