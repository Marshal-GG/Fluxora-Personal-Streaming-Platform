"""Tests for Sentry initialisation in main.lifespan.

The live test suite never wants Sentry to actually fire — these tests
just verify the conditional skip / init plumbing is correct. We don't
exercise the real `sentry_sdk.init` against a Sentry server.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest


def test_init_sentry_skips_when_dsn_empty(monkeypatch):
    import config
    import main

    monkeypatch.setattr(config.settings, "sentry_dsn", "")

    with patch("sentry_sdk.init") as mock_init:
        main._init_sentry()

    mock_init.assert_not_called()


def test_init_sentry_calls_init_when_dsn_set(monkeypatch):
    import config
    import main

    monkeypatch.setattr(
        config.settings, "sentry_dsn", "https://example@sentry.example.com/123"
    )
    monkeypatch.setattr(config.settings, "fluxora_env", "prod")
    monkeypatch.setattr(config.settings, "sentry_traces_sample_rate", 0.0)

    with patch("sentry_sdk.init") as mock_init:
        main._init_sentry()

    assert mock_init.called
    kwargs = mock_init.call_args.kwargs
    assert kwargs["dsn"] == "https://example@sentry.example.com/123"
    assert kwargs["environment"] == "prod"
    assert kwargs["traces_sample_rate"] == 0.0
    assert kwargs["send_default_pii"] is False
    assert callable(kwargs["before_send"])


def test_before_send_drops_http_exceptions(monkeypatch):
    """HTTPException is expected (4xx returns). Sentry should ignore them."""
    import config
    import main

    monkeypatch.setattr(
        config.settings, "sentry_dsn", "https://example@sentry.example.com/123"
    )

    with patch("sentry_sdk.init") as mock_init:
        main._init_sentry()

    before_send = mock_init.call_args.kwargs["before_send"]

    class FakeHTTPError(Exception):
        pass

    FakeHTTPError.__name__ = "HTTPException"
    event = {"message": "test"}
    hint = {"exc_info": (FakeHTTPError, FakeHTTPError(), None)}
    assert before_send(event, hint) is None


def test_before_send_drops_validation_errors(monkeypatch):
    """RequestValidationError is expected (Pydantic 422). Sentry should ignore."""
    import config
    import main

    monkeypatch.setattr(
        config.settings, "sentry_dsn", "https://example@sentry.example.com/123"
    )

    with patch("sentry_sdk.init") as mock_init:
        main._init_sentry()

    before_send = mock_init.call_args.kwargs["before_send"]

    class FakeValidationError(Exception):
        pass

    FakeValidationError.__name__ = "RequestValidationError"
    event = {"message": "test"}
    hint = {"exc_info": (FakeValidationError, FakeValidationError(), None)}
    assert before_send(event, hint) is None


def test_before_send_passes_unknown_exception(monkeypatch):
    """A genuine bug should reach Sentry, not get dropped by the filter."""
    import config
    import main

    monkeypatch.setattr(
        config.settings, "sentry_dsn", "https://example@sentry.example.com/123"
    )

    with patch("sentry_sdk.init") as mock_init:
        main._init_sentry()

    before_send = mock_init.call_args.kwargs["before_send"]

    event = {"message": "kaboom"}
    hint = {"exc_info": (RuntimeError, RuntimeError("kaboom"), None)}
    assert before_send(event, hint) == event


@pytest.mark.parametrize("hint", [None, {}, {"exc_info": None}])
def test_before_send_passes_when_no_exc_info(hint, monkeypatch):
    """Defensive: if hint is missing/empty, pass the event through unchanged."""
    import config
    import main

    monkeypatch.setattr(
        config.settings, "sentry_dsn", "https://example@sentry.example.com/123"
    )

    with patch("sentry_sdk.init") as mock_init:
        main._init_sentry()

    before_send = mock_init.call_args.kwargs["before_send"]

    event = {"message": "no exc"}
    assert before_send(event, hint) == event
