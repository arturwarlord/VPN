import unittest

from scripts.check_public_vpn_sources import (
    parse_huntvpn_uz,
    parse_publicvpnlist_countries,
    parse_unverified_directory,
    parse_vpngate_api,
)


class PublicVpnSourceParserTests(unittest.TestCase):
    def test_huntvpn_zero_live_is_not_a_candidate(self):
        result = parse_huntvpn_uz("<p>🇺🇿 Uzbekistan UZ · 0 alive of 1 tracked here</p>")
        self.assertEqual(result["status"], "none")
        self.assertEqual(result["alive"], 0)
        self.assertEqual(result["tracked"], 1)

    def test_huntvpn_positive_live_count_is_a_candidate(self):
        result = parse_huntvpn_uz("<p>🇦🇿 Azerbaijan AZ · 2 alive of 3 tracked here</p>")
        self.assertEqual(result["status"], "candidate")
        self.assertEqual(result["alive"], 2)

    def test_huntvpn_unexpected_markup_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_huntvpn_uz("<p>Maintenance</p>")

    def test_vpngate_csv_counts_only_uzbek_rows(self):
        data = (
            "*vpn_servers\n"
            "#HostName,IP,CountryLong,CountryShort,OpenVPN_ConfigData_Base64\n"
            "host-a,1.2.3.4,Uzbekistan,UZ,QUJD\n"
            "host-b,5.6.7.8,Japan,JP,REVG\n"
            "host-c,9.8.7.6,Uzbekistan,UZ,R0hJ\n"
        )
        result = parse_vpngate_api(data)
        self.assertEqual(result["live_rows"], 2)
        self.assertEqual(result["sample_ips"], ["1.2.3.4", "9.8.7.6"])

    def test_publicvpnlist_country_presence(self):
        self.assertFalse(parse_publicvpnlist_countries("<p>Armenia, Georgia</p>")["country_present"])
        self.assertTrue(parse_publicvpnlist_countries("<p>Uzbekistan</p>")["country_present"])

    def test_unverified_directory_is_not_promoted_to_live_candidate(self):
        result = parse_unverified_directory(
            "<p>vpn123456789.opengw.net vpn987654321.opengw.net</p>",
            "freevpnnode_uz",
        )
        self.assertEqual(result["status"], "unverified")
        self.assertEqual(result["listed_count"], 2)
        self.assertEqual(len(result["sample_hosts"]), 2)


if __name__ == "__main__":
    unittest.main()
