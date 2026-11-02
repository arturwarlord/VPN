import base64
import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "register_wireguard_peer.py"
SPEC = importlib.util.spec_from_file_location("register_wireguard_peer", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def public_key(seed: int) -> str:
    return base64.b64encode(bytes((seed + index) % 256 for index in range(32))).decode("ascii")


CONFIG = """# FreeRoute managed WireGuard configuration
[Interface]
Address = 10.77.0.1/24, fd4b:8d2c:6a91::1/64
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY

[Peer]
# windows
PublicKey = {windows}
AllowedIPs = 10.77.0.2/32, fd4b:8d2c:6a91::2/128

[Peer]
# android
PublicKey = {android}
AllowedIPs = 10.77.0.3/32, fd4b:8d2c:6a91::3/128

[Peer]
# iphone
PublicKey = {iphone}
AllowedIPs = 10.77.0.4/32, fd4b:8d2c:6a91::4/128
""".format(windows=public_key(1), android=public_key(40), iphone=public_key(80))


class WireGuardPeerRegistrationTests(unittest.TestCase):
    def test_allocates_first_free_ipv4_and_ipv6_addresses(self):
        updated, ipv4, ipv6 = MODULE.build_updated_config(CONFIG, "poco-x4", public_key(120))
        self.assertEqual(ipv4, "10.77.0.5")
        self.assertEqual(ipv6, "fd4b:8d2c:6a91::5")
        self.assertIn("# freeroute-device: poco-x4", updated)
        self.assertIn(f"PublicKey = {public_key(120)}", updated)
        self.assertIn("AllowedIPs = 10.77.0.5/32, fd4b:8d2c:6a91::5/128", updated)
        self.assertEqual(updated.count("PrivateKey ="), 1)

    def test_skips_addresses_already_covered_by_existing_networks(self):
        expanded = CONFIG + (
            "\n[Peer]\n# already-used-range\n"
            f"PublicKey = {public_key(121)}\n"
            "AllowedIPs = 10.77.0.5/32, fd4b:8d2c:6a91::5/128\n"
        )
        _, ipv4, ipv6 = MODULE.build_updated_config(expanded, "second-device", public_key(122))
        self.assertEqual(ipv4, "10.77.0.6")
        self.assertEqual(ipv6, "fd4b:8d2c:6a91::6")

    def test_rejects_duplicate_device_name(self):
        with self.assertRaisesRegex(ValueError, "already registered"):
            MODULE.build_updated_config(CONFIG + "\n[Peer]\n# freeroute-device: poco-x4\n", "poco-x4", public_key(123))

    def test_rejects_duplicate_public_key(self):
        with self.assertRaisesRegex(ValueError, "already registered"):
            MODULE.build_updated_config(CONFIG, "new-phone", public_key(1))

    def test_rejects_legacy_reserved_names(self):
        for name in ("windows", "android", "iphone"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "reserved"):
                MODULE.build_updated_config(CONFIG, name, public_key(124))

    def test_rejects_invalid_device_labels(self):
        for name in ("", "My Phone", "../android", "-bad", "bad-", "a" * 33):
            with self.subTest(name=name), self.assertRaises(ValueError):
                MODULE.validate_device_name(name)

    def test_rejects_invalid_or_zero_public_keys(self):
        for key in ("not-a-key", "A" * 44, base64.b64encode(bytes(32)).decode("ascii")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                MODULE.validate_public_key(key)

    def test_refuses_unmanaged_configuration(self):
        unmanaged = CONFIG.replace(MODULE.MANAGED_MARKER, "Unmanaged config")
        with self.assertRaisesRegex(ValueError, "not a single FreeRoute-managed"):
            MODULE.build_updated_config(unmanaged, "new-phone", public_key(125))

    def test_refuses_malformed_existing_allowed_ips(self):
        malformed = CONFIG.replace("10.77.0.2/32, fd4b:8d2c:6a91::2/128", "not-a-network")
        with self.assertRaisesRegex(ValueError, "invalid AllowedIPs"):
            MODULE.build_updated_config(malformed, "new-phone", public_key(126))

    def test_refuses_when_address_pool_is_occupied(self):
        full_pool = CONFIG + (
            "\n[Peer]\n# full-pool\n"
            f"PublicKey = {public_key(127)}\n"
            "AllowedIPs = 10.77.0.0/24, fd4b:8d2c:6a91::/64\n"
        )
        with self.assertRaisesRegex(ValueError, "pool is exhausted"):
            MODULE.build_updated_config(full_pool, "new-phone", public_key(128))


if __name__ == "__main__":
    unittest.main()
