#!/usr/bin/env python3
"""Fail-closed check of the server's real outbound IPv4 country.

The public IPv4 is sent to api.ipify.org and ipwho.is for lookup, but is never
printed or persisted by this script.
"""
from __future__ import annotations

import ipaddress
import json
import re
import sys
from typing import Callable
from urllib.request import urlopen

PUBLIC_IP_URL = "https://api.ipify.org"
GEO_URL = "https://ipwho.is/{ip}?fields=success,ip,country,country_code"
REQUEST_TIMEOUT_SECONDS = 10


def _read_text(url: str, opener: Callable = urlopen) -> str:
    with opener(url, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        return response.read().decode("utf-8").strip()


def _validate_geo_response(public_ip: str, payload: object) -> tuple[str, str]:
    try:
        requested = ipaddress.ip_address(public_ip)
    except ValueError as error:
        raise ValueError("The outbound IP service returned an invalid address.") from error

    if not isinstance(requested, ipaddress.IPv4Address) or not requested.is_global:
        raise ValueError("The server does not have a globally routable outbound IPv4 address.")

    if not isinstance(payload, dict) or payload.get("success") is not True:
        raise ValueError("The geolocation service could not verify the server's outbound IPv4 address.")

    try:
        returned = ipaddress.ip_address(str(payload.get("ip", "")))
    except ValueError as error:
        raise ValueError("The geolocation service returned an invalid address.") from error

    if returned != requested:
        raise ValueError("The geolocation response did not match the server's outbound IPv4 address.")

    country_code = str(payload.get("country_code", "")).upper()
    country = str(payload.get("country", "")).strip()
    if not re.fullmatch(r"[A-Z]{2}", country_code) or not country:
        raise ValueError("The geolocation service returned no valid country.")

    if country_code == "RU":
        raise ValueError("The server's actual outbound IPv4 address geolocates to Russia.")

    return country, country_code


def check_egress_country(opener: Callable = urlopen) -> tuple[str, str]:
    public_ip = _read_text(PUBLIC_IP_URL, opener=opener)
    try:
        parsed = ipaddress.ip_address(public_ip)
    except ValueError as error:
        raise ValueError("The outbound IP service returned an invalid address.") from error

    if not isinstance(parsed, ipaddress.IPv4Address) or not parsed.is_global:
        raise ValueError("The server does not have a globally routable outbound IPv4 address.")

    geo_url = GEO_URL.format(ip=public_ip)
    try:
        payload = json.loads(_read_text(geo_url, opener=opener))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError("The geolocation service returned an invalid response.") from error

    return _validate_geo_response(public_ip, payload)


def main() -> int:
    try:
        country, country_code = check_egress_country()
    except Exception as error:
        print(f"FAIL  Actual IPv4 egress country check: {error}", file=sys.stderr)
        return 1

    print(f"PASS  Actual IPv4 egress country: {country} ({country_code}); public IP not logged.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
