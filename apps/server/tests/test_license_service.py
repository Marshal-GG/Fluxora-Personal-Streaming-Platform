"""Tests for services.license_service — key generation and validation."""

from __future__ import annotations

import hashlib
import hmac
from datetime import date, timedelta

import pytest

# We need a known secret for deterministic tests.
_TEST_SECRET = "testsecretdeadbeefdeadbeefdeadbeef"
_TEST_NONCE = "CAFE"


def _make_key(
    tier_code: str, expiry: str, secret: str = _TEST_SECRET, nonce: str = _TEST_NONCE
) -> str:
    payload = f"{tier_code}:{expiry}:{nonce}".encode()
    mac = hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()
    sig = mac[:8].upper()
    return f"FLUXORA-{tier_code}-{expiry}-{nonce}-{sig}"


# ---------------------------------------------------------------------------
# Import the service and patch settings for every test
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def patch_secret(monkeypatch):
    """Inject a known license secret into the settings singleton."""
    import config

    monkeypatch.setattr(config.settings, "fluxora_license_secret", _TEST_SECRET)


from services.license_service import generate_key, validate_key  # noqa: E402

# ---------------------------------------------------------------------------
# validate_key — happy paths
# ---------------------------------------------------------------------------


class TestValidateKeyHappy:
    def test_valid_lifetime_key(self):
        key = _make_key("PLUS", "99991231")
        result = validate_key(key)
        assert result.valid is True
        assert result.tier == "plus"
        assert result.expires == "99991231"
        assert result.reason == ""

    def test_valid_future_expiry(self):
        expiry = (date.today() + timedelta(days=30)).strftime("%Y%m%d")
        key = _make_key("PRO", expiry)
        result = validate_key(key)
        assert result.valid is True
        assert result.tier == "pro"

    def test_all_tiers(self):
        tiers = [
            ("FREE", "free"),
            ("PLUS", "plus"),
            ("PRO", "pro"),
            ("ULTI", "ultimate"),
        ]
        for code, tier in tiers:
            key = _make_key(code, "99991231")
            result = validate_key(key)
            assert result.valid is True, f"Expected valid for {code}"
            assert result.tier == tier

    def test_whitespace_trimmed(self):
        key = "  " + _make_key("PLUS", "99991231") + "  "
        result = validate_key(key)
        assert result.valid is True

    def test_lowercase_key_accepted(self):
        key = _make_key("PLUS", "99991231").lower()
        result = validate_key(key)
        assert result.valid is True


# ---------------------------------------------------------------------------
# validate_key — failure paths
# ---------------------------------------------------------------------------


class TestValidateKeyFailures:
    def test_none_returns_empty(self):
        result = validate_key(None)
        assert result.valid is False
        assert result.reason == "empty"

    def test_empty_string(self):
        result = validate_key("")
        assert result.valid is False
        assert result.reason == "empty"

    def test_wrong_prefix(self):
        result = validate_key("BADKEY-PLUS-99991231-CAFE-ABCD1234")
        assert result.valid is False
        assert result.reason == "malformed"

    def test_too_few_segments(self):
        result = validate_key("FLUXORA-PLUS-99991231")
        assert result.valid is False
        assert result.reason == "malformed"

    def test_four_part_key_rejected(self):
        # 4-part (legacy) format is no longer accepted
        result = validate_key("FLUXORA-PLUS-99991231-ABCD1234")
        assert result.valid is False
        assert result.reason == "malformed"

    def test_unknown_tier(self):
        key = _make_key("GOLD", "99991231")
        result = validate_key(key)
        assert result.valid is False
        assert result.reason == "unknown_tier"

    def test_expired_key(self):
        expiry = (date.today() - timedelta(days=1)).strftime("%Y%m%d")
        key = _make_key("PLUS", expiry)
        result = validate_key(key)
        assert result.valid is False
        assert result.reason == "expired"
        assert result.tier == "plus"

    def test_bad_signature(self):
        expiry = "99991231"
        key = f"FLUXORA-PLUS-{expiry}-CAFE-DEADBEEF"
        result = validate_key(key)
        assert result.valid is False
        assert result.reason == "invalid_signature"

    def test_no_secret_advisory_mode(self, monkeypatch):
        import config

        monkeypatch.setattr(config.settings, "fluxora_license_secret", "")
        key = _make_key("PLUS", "99991231")
        result = validate_key(key)
        assert result.valid is False
        assert result.reason == "no_secret"
        assert result.tier == "plus"  # structure was still decoded

    def test_malformed_expiry_non_digits(self):
        result = validate_key("FLUXORA-PLUS-BADEXPIRY-CAFE-ABCD1234")
        assert result.valid is False
        assert result.reason == "malformed_expiry"

    def test_malformed_expiry_invalid_date(self):
        # 8 digits but not a valid calendar date
        key = _make_key("PLUS", "20251399")  # month 13
        result = validate_key(key)
        assert result.valid is False
        assert result.reason == "malformed_expiry"


# ---------------------------------------------------------------------------
# generate_key
# ---------------------------------------------------------------------------


class TestGenerateKey:
    def test_generates_valid_key(self):
        key = generate_key("plus")
        result = validate_key(key)
        assert result.valid is True
        assert result.tier == "plus"

    def test_generates_five_part_key(self):
        key = generate_key("plus")
        assert len(key.split("-")) == 5

    def test_lifetime_key(self):
        key = generate_key("pro", days=None)
        assert "99991231" in key
        assert validate_key(key).valid is True

    def test_expiry_key(self):
        key = generate_key("ultimate", days=90)
        result = validate_key(key)
        assert result.valid is True
        expected = (date.today() + timedelta(days=90)).strftime("%Y%m%d")
        assert expected in key

    def test_unknown_tier_raises(self):
        with pytest.raises(ValueError, match="Unknown tier"):
            generate_key("gold")

    def test_no_secret_raises(self, monkeypatch):
        import config

        monkeypatch.setattr(config.settings, "fluxora_license_secret", "")
        with pytest.raises(ValueError, match="FLUXORA_LICENSE_SECRET"):
            generate_key("plus")
