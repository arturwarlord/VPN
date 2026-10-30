#!/usr/bin/env python3
"""Read-only monitor for public Uzbekistan VPN directory availability.

This script checks directory metadata only. It never contacts listed VPN/proxy
endpoints, downloads profiles, or sends user traffic through third parties.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import html
import json
import os
import re
import sys
from typing import Callable
from urllib.error import URLError
from urllib.request import Request, urlopen

SOURCES = {
    "huntvpn_uz": "https://huntvpn.dev/vpn/uzbekistan",
    "vpngate_api": "https://www.vpngate.net/api/iphone/",
    "publicvpnlist_countries": "https://publicvpnlist.com/countries/",
    "proxyfreeonly_uz": "https://proxyfreeonly.com/ru/free-vpn-list/uzbekistan",
    "freevpnnode_uz": "https://www.freevpnnode.com/free-vpn-for-uzbekistan/",
}


def fetch_text(url: str, timeout: int = 20) -> str:
    request = Request(
        url,
        headers={
            "User-Agent": "FreeRoutePublicSourceMonitor/1.0 (+https://github.com/arturwarlord/VPN)",
            "Accept": "text/html,text/plain;q=0.9,*/*;q=0.8",
        },
    )
    with urlopen(request, timeout=timeout) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def plain_text(value: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]*>", " ", value)))


def parse_huntvpn_uz(page: str) -> dict:
    text = plain_text(page)
    match = re.search(r"(\d+)\s+alive\s+of\s+(\d+)\s+tracked here", text, re.I)
    if not match:
        raise ValueError("Could not find the live 'alive of tracked' count")
    alive, tracked = map(int, match.groups())
    return {
        "status": "candidate" if alive > 0 else "none",
        "alive": alive,
        "tracked": tracked,
        "source_url": SOURCES["huntvpn_uz"],
    }


def parse_vpngate_api(data: str) -> dict:
    lines = [line for line in data.splitlines() if line.strip()]
    header_index = next((i for i, line in enumerate(lines) if line.startswith("#HostName,")), None)
    if header_index is None:
        raise ValueError("VPN Gate CSV header was not found")
    reader = csv.DictReader(lines[header_index:])
    count = 0
    examples = []
    for row in reader:
        country = (row.get("CountryShort") or "").strip().upper()
        if country == "UZ":
            count += 1
            ip = (row.get("IP") or "").strip()
            if ip and ip not in examples and len(examples) < 5:
                examples.append(ip)
    return {
        "status": "candidate" if count else "none",
        "live_rows": count,
        "sample_ips": examples,
        "source_url": SOURCES["vpngate_api"],
    }


def parse_publicvpnlist_countries(page: str) -> dict:
    text = plain_text(page)
    found = bool(re.search(r"\bUzbekistan\b", text, re.I))
    return {
        "status": "candidate" if found else "none",
        "country_present": found,
        "source_url": SOURCES["publicvpnlist_countries"],
    }


def parse_unverified_directory(page: str, source_key: str) -> dict:
    text = plain_text(page)
    hosts = sorted(set(re.findall(r"vpn[0-9]+\.opengw\.net", text, re.I)))
    if source_key == "proxyfreeonly_uz":
        match = re.search(r"(?:ВПН онлайн|VPN online)\s*(\d+)", text, re.I)
        listed_count = int(match.group(1)) if match else None
    else:
        listed_count = len(hosts)
    return {
        "status": "unverified",
        "listed_count": listed_count,
        "sample_hosts": hosts[:5],
        "note": "Directory listing only; not proof of a live OpenVPN endpoint.",
        "source_url": SOURCES[source_key],
    }


def check_source(key: str, parser: Callable[[str], dict]) -> dict:
    try:
        return parser(fetch_text(SOURCES[key]))
    except (URLError, TimeoutError, OSError, ValueError) as exc:
        return {
            "status": "unknown",
            "error": f"{type(exc).__name__}: {exc}",
            "source_url": SOURCES[key],
        }


def build_report() -> dict:
    results = {
        "huntvpn_uz": check_source("huntvpn_uz", parse_huntvpn_uz),
        "vpngate_api": check_source("vpngate_api", parse_vpngate_api),
        "publicvpnlist_countries": check_source(
            "publicvpnlist_countries", parse_publicvpnlist_countries
        ),
        "proxyfreeonly_uz": check_source(
            "proxyfreeonly_uz",
            lambda page: parse_unverified_directory(page, "proxyfreeonly_uz"),
        ),
        "freevpnnode_uz": check_source(
            "freevpnnode_uz",
            lambda page: parse_unverified_directory(page, "freevpnnode_uz"),
        ),
    }
    verified_candidates = [
        key
        for key in ("huntvpn_uz", "vpngate_api", "publicvpnlist_countries")
        if results[key].get("status") == "candidate"
    ]
    return {
        "checked_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "scope": "directory metadata only; no VPN/proxy endpoint is contacted",
        "potential_uz_openvpn_candidate": bool(verified_candidates),
        "candidate_sources": verified_candidates,
        "sources": results,
    }


def render_summary(report: dict) -> str:
    rows = [
        "## FreeRoute — public Uzbekistan VPN source check",
        "",
        f"Checked (UTC): {report['checked_at_utc']}",
        "",
        "| Source | Result |",
        "|---|---|",
    ]
    for key, result in report["sources"].items():
        status = result.get("status", "unknown")
        if key == "huntvpn_uz":
            detail = f"{result.get('alive', '?')} alive / {result.get('tracked', '?')} tracked"
        elif key == "vpngate_api":
            detail = f"{result.get('live_rows', '?')} Uzbekistan rows"
        elif key == "publicvpnlist_countries":
            detail = "country present" if result.get("country_present") else "country absent"
        else:
            detail = f"{result.get('listed_count', '?')} unverified rows"
        rows.append(f"| {key} | {status} — {detail} |")
    rows += [
        "",
        "**Candidate signal:** "
        + ("yes — manual review required" if report["potential_uz_openvpn_candidate"] else "no confirmed signal"),
        "",
        "This check does not download profiles, probe VPN endpoints, or route traffic through third parties.",
    ]
    return "\n".join(rows) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="public-vpn-source-report.json")
    args = parser.parse_args()

    report = build_report()
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write(encoded)

    summary = render_summary(report)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write(summary)

    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path:
        with open(output_path, "a", encoding="utf-8") as handle:
            handle.write(
                "candidate_detected="
                + ("true" if report["potential_uz_openvpn_candidate"] else "false")
                + "\n"
            )

    print(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
