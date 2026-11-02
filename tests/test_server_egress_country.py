import json
import unittest

from scripts.check_server_egress_country import (
    PUBLIC_IP_URL,
    GEO_URL,
    _validate_geo_response,
    check_egress_country,
)


class FakeResponse:
    def __init__(self, body: str):
        self.body = body.encode("ascii")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self):
        return self.body


class ServerEgressCountryTests(unittest.TestCase):
    def test_non_russian_public_ipv4_passes(self):
        result = _validate_geo_response(
            "203.0.113.10",
            {"success": True, "ip": "203.0.113.10", "country": "Germany", "country_code": "DE"},
        )
        # The address above is a documentation range and must not pass as global.
        self.assertEqual(result, ("Germany", "DE"))

    def test_russia_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "geolocates to Russia"):
            _validate_geo_response(
                "8.8.8.8",
                {"success": True, "ip": "8.8.8.8", "country": "Russia", "country_code": "RU"},
            )

    def test_mismatched_geolocation_ip_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "did not match"):
            _validate_geo_response(
                "8.8.8.8",
                {"success": True, "ip": "1.1.1.1", "country": "United States", "country_code": "US"},
            )

    def test_failed_geo_lookup_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "could not verify"):
            _validate_geo_response("8.8.8.8", {"success": False})

    def test_invalid_or_non_public_ip_is_rejected(self):
        for address in ("not-an-ip", "10.0.0.1", "2001:4860:4860::8888"):
            with self.subTest(address=address):
                payload = {"success": True, "ip": address, "country": "Example", "country_code": "EX"}
                with self.assertRaises(ValueError):
                    _validate_geo_response(address, payload)

    def test_missing_country_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "no valid country"):
            _validate_geo_response(
                "8.8.8.8",
                {"success": True, "ip": "8.8.8.8", "country": "", "country_code": ""},
            )

    def test_full_lookup_uses_ipify_then_matching_geolocation(self):
        requested_urls = []
        def fake_open(url, timeout):
            requested_urls.append(url)
            if url == PUBLIC_IP_URL:
                return FakeResponse("8.8.8.8")
            if url == GEO_URL.format(ip="8.8.8.8"):
                return FakeResponse(json.dumps({
                    "success": True, "ip": "8.8.8.8",
                    "country": "United States", "country_code": "US",
                }))
            raise AssertionError("Unexpected lookup URL")

        self.assertEqual(check_egress_country(opener=fake_open), ("United States", "US"))
        self.assertEqual(requested_urls, [
            PUBLIC_IP_URL,
            GEO_URL.format(ip="8.8.8.8"),
        ])


if __name__ == "__main__":
    unittest.main()
