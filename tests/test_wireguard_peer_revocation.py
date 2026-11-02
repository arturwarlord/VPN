import importlib.util
import sys
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "revoke_wireguard_peer.py"
SPEC = importlib.util.spec_from_file_location("revoke_wireguard_peer", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)

REGISTRATION_TESTS = Path(__file__).resolve().parent / "test_wireguard_peer_registration.py"
REG_SPEC = importlib.util.spec_from_file_location("registration_test_helpers", REGISTRATION_TESTS)
REG_MODULE = importlib.util.module_from_spec(REG_SPEC)
assert REG_SPEC.loader is not None
REG_SPEC.loader.exec_module(REG_MODULE)

CONFIG = REG_MODULE.CONFIG
PUBLIC_KEY = REG_MODULE.public_key


class WireGuardPeerRevocationTests(unittest.TestCase):
    def config_with_registered_devices(self):
        with_second, _, _ = REG_MODULE.MODULE.build_updated_config(CONFIG, "poco-x4", PUBLIC_KEY(120))
        with_third, _, _ = REG_MODULE.MODULE.build_updated_config(with_second, "tablet", PUBLIC_KEY(140))
        return with_third

    def test_removes_only_requested_device_and_preserves_other_peers(self):
        original = self.config_with_registered_devices()
        updated, public_key, allowed_ips = MODULE.build_revoked_config(original, "poco-x4")

        self.assertEqual(public_key, PUBLIC_KEY(120))
        self.assertEqual(allowed_ips, ["10.77.0.5/32", "fd4b:8d2c:6a91::5/128"])
        self.assertNotIn("# freeroute-device: poco-x4", updated)
        self.assertIn("# freeroute-device: tablet", updated)
        self.assertIn(f"PublicKey = {PUBLIC_KEY(140)}", updated)
        self.assertIn("# windows", updated)
        self.assertIn("# android", updated)
        self.assertIn("# iphone", updated)

    def test_allows_other_registered_devices_to_remain(self):
        original = self.config_with_registered_devices()
        updated, _, _ = MODULE.build_revoked_config(original, "tablet")
        self.assertIn("# freeroute-device: poco-x4", updated)
        self.assertNotIn("# freeroute-device: tablet", updated)

    def test_refuses_unknown_device(self):
        with self.assertRaisesRegex(ValueError, "No registered"):
            MODULE.build_revoked_config(CONFIG, "not-registered")

    def test_rejects_duplicate_target_marker(self):
        original = self.config_with_registered_devices()
        duplicated = original + (
            "\n[Peer]\n# freeroute-device: poco-x4\n"
            f"PublicKey = {PUBLIC_KEY(160)}\n"
            "AllowedIPs = 10.77.0.90/32\n"
        )
        with self.assertRaisesRegex(ValueError, "duplicate"):
            MODULE.build_revoked_config(duplicated, "poco-x4")

    def test_refuses_malformed_target_peer(self):
        original = self.config_with_registered_devices()
        malformed = original.replace(
            f"PublicKey = {PUBLIC_KEY(120)}",
            "PublicKey = " + PUBLIC_KEY(120) + "\nPublicKey = " + PUBLIC_KEY(121),
        )
        with self.assertRaisesRegex(ValueError, "exactly one PublicKey"):
            MODULE.build_revoked_config(malformed, "poco-x4")

    def test_refuses_legacy_peer_names(self):
        for name in ("windows", "android", "iphone"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "reserved"):
                MODULE.build_revoked_config(CONFIG, name)

    def test_refuses_unmanaged_config(self):
        unmanaged = CONFIG.replace(MODULE.MANAGED_MARKER, "Unmanaged config")
        with self.assertRaisesRegex(ValueError, "not a single FreeRoute-managed"):
            MODULE.build_revoked_config(unmanaged, "poco-x4")

    def test_validates_device_labels(self):
        for name in ("", "Bad Name", "../phone", "-bad", "bad-", "a" * 33):
            with self.subTest(name=name), self.assertRaises(ValueError):
                MODULE.validate_device_name(name)


if __name__ == "__main__":
    unittest.main()
