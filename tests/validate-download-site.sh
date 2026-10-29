#!/usr/bin/env bash
set -Eeuo pipefail

python3 - <<'PY'
from html.parser import HTMLParser
from pathlib import Path

class PageCheck(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.in_title = False
        self.title = ""
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a":
            self.links.append(attrs.get("href", ""))
        if tag == "title":
            self.in_title = True
    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False
    def handle_data(self, data):
        if self.in_title:
            self.title += data

page = Path("index.html")
assert page.is_file() and page.stat().st_size > 10000, "Download site is missing or unexpectedly small"
source = page.read_text(encoding="utf-8")
parser = PageCheck()
parser.feed(source)
assert "FreeRoute — центр загрузок" in parser.title, "Page title is missing"
for element in (
    "downloads", "android-download", "windows-download", "ios-download",
    "updates", "release-list", "latest-version", "release-page"
):
    assert element in parser.ids, f"Missing required page element id={element}"
for platform in ("android-client.yml", "windows-client.yml", "ios-client.yml"):
    assert any(platform in link for link in parser.links), f"Missing build fallback link for {platform}"
assert "https://api.github.com/repos/arturwarlord/VPN/releases?per_page=8" in source, "Live releases API is not configured"
assert "freeroute-android-debug.apk" in source
assert "freeroute-windows-x64.zip" in source
assert "freeroute-ios-unsigned.zip" in source
assert "Не подписан" in source or "не подписан" in source, "iOS signing limitation must be explicit"
assert "VPN-сервер ещё не запущен" in source, "Live-server status must be honest"
assert "textContent" in source, "Release API text should be rendered without injecting HTML"
assert "id=\"viewport\"" not in source, "Viewport should be declared via meta name=viewport"
assert "name=\"viewport\"" in source, "Mobile viewport meta is required"
assert "@media (max-width: 640px)" in source, "Mobile layout is missing"
print("Download-site tests: passed (platform links, release updater, safe text rendering, iOS status, responsive layout).")
PY
