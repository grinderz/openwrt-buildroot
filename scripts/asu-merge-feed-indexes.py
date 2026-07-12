#!/usr/bin/env python3
"""Merge official OpenWrt feed indexes into locally published asu metadata.

The src build only produces packages selected in its config, but routers
also install packages from the official feeds via opkg. owut/asu compare
installed packages against the indexes served by the metadata server, so
sparse local indexes make every officially-installed package look missing.

For each packages/<arch>/<feed>/ under the metadata version dir, download
the official index.json and merge it with the local one. On a name
collision the highest version wins (dpkg/opkg comparison) — the same rule
opkg applies across repositories, so the served indexes always show what
the imagebuilder actually installs.

Third-party repositories from repositories-extra.conf files (the ones baked
into the imagebuilder image) are mirrored the same way: their Packages files
are converted to index.json feeds and registered in feeds.conf, so owut's
version checks see them too.

Usage: asu-merge-feed-indexes.py <meta_version_dir> <official_version_url> \
           [repositories-extra.conf ...]
  e.g. asu-merge-feed-indexes.py asu/metadata/releases/24.10.7 \
           https://downloads.openwrt.org/releases/24.10.7 \
           imagebuilder/24.10.7/repositories-extra.conf
"""

import argparse
import json
import urllib.error
import urllib.request
from pathlib import Path


def fetch(url: str) -> bytes | None:
    try:
        with urllib.request.urlopen(url, timeout=30) as res:
            return res.read()
    except (urllib.error.URLError, TimeoutError) as e:
        print(f"   ! {url}: {e}")
        return None


def fetch_index(url: str) -> dict | None:
    raw = fetch(url)
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"   ! {url}: {e}")
        return None


def dpkg_vercmp(a: str, b: str) -> int:
    """dpkg/opkg version comparison: <0 if a<b, 0 if equal, >0 if a>b.

    opkg picks the highest version across repositories, so index merging
    must do the same or the served versions diverge from what the
    imagebuilder actually installs.
    """

    def order(c: str) -> int:
        if c == "~":
            return -1
        if c.isdigit():
            return 0
        if c.isalpha():
            return ord(c)
        return ord(c) + 256

    ia = ib = 0
    while ia < len(a) or ib < len(b):
        while (ia < len(a) and not a[ia].isdigit()) or (
            ib < len(b) and not b[ib].isdigit()
        ):
            ac = order(a[ia]) if ia < len(a) else 0
            bc = order(b[ib]) if ib < len(b) else 0
            if ac != bc:
                return ac - bc
            ia += 1
            ib += 1
        while ia < len(a) and a[ia] == "0":
            ia += 1
        while ib < len(b) and b[ib] == "0":
            ib += 1
        sa = ia
        while ia < len(a) and a[ia].isdigit():
            ia += 1
        sb = ib
        while ib < len(b) and b[ib].isdigit():
            ib += 1
        da, db = a[sa:ia], b[sb:ib]
        if len(da) != len(db):
            return len(da) - len(db)
        if da != db:
            return 1 if da > db else -1
    return 0


def merge_packages(
    official: dict[str, str], local: dict[str, str]
) -> dict[str, str]:
    """Union of both, highest version wins (matching opkg repo behavior)."""
    merged = dict(official)
    for name, version in local.items():
        if name not in merged or dpkg_vercmp(version, merged[name]) > 0:
            merged[name] = version
    return merged


def parse_packages(raw: str, arch: str | None = None) -> dict[str, str]:
    """opkg Packages file -> {name: version}, optionally filtered by arch.

    Mixed feeds carry entries for several architectures ('all' plus a
    native one), so filtering has to happen per entry, not per feed.
    """
    packages: dict[str, str] = {}
    entry: dict[str, str] = {}

    def flush() -> None:
        name, version = entry.get("Package"), entry.get("Version")
        pkg_arch = entry.get("Architecture")
        if name and version and (
            arch is None or pkg_arch is None or pkg_arch in (arch, "all")
        ):
            packages[name] = version

    for line in raw.splitlines():
        if not line.strip():
            flush()
            entry = {}
        elif not line.startswith(" ") and ": " in line:
            key, value = line.split(": ", 1)
            entry[key] = value.strip()
    flush()
    return packages


def mirror_extra_repos(arch_dir: Path, repo_files: list[str]) -> None:
    feeds_conf = arch_dir / "feeds.conf"
    feeds_text = feeds_conf.read_text() if feeds_conf.is_file() else ""
    # feeds written during this run: the first write replaces whatever a
    # previous run left (dropping packages meanwhile removed upstream),
    # later same-named writes merge (see below)
    written: set[str] = set()

    for repo_file in repo_files:
        for line in Path(repo_file).read_text().splitlines():
            fields = line.split()
            if len(fields) != 3 or fields[0].startswith("#"):
                continue
            _, feed, url = fields

            raw = fetch(f"{url.rstrip('/')}/Packages")
            if raw is None:
                print(f" - extra {feed}: Packages not fetched, skipped")
                continue

            # every arch dir sees every repositories-extra.conf line, so
            # entries built for a different architecture are dropped
            packages = parse_packages(raw.decode(), arch_dir.name)
            if not packages:
                print(f" - extra {feed}: no {arch_dir.name} packages, skipped")
                continue
            feed_dir = arch_dir / feed
            feed_dir.mkdir(exist_ok=True)
            index_file = feed_dir / "index.json"
            # profiles for different archs may reuse a feed name with
            # different urls ("modemfeed") — merge same-run duplicates
            # instead of overwriting, or the last url's arch-filtered
            # subset wins; cross-run state is replaced, not merged
            if feed in written and index_file.is_file():
                existing = json.loads(index_file.read_text()).get("packages", {})
                packages = merge_packages(existing, packages)
            written.add(feed)
            index_file.write_text(
                json.dumps({"architecture": arch_dir.name, "packages": packages})
            )
            if f"src/gz {feed} " not in feeds_text:
                feeds_text += f"src/gz {feed} {url}\n"
            print(f" - extra {arch_dir.name}/{feed}: {len(packages)} packages")

    feeds_conf.write_text(feeds_text)


def dedupe_feed_indexes(arch_dir: Path) -> None:
    """Keep only the highest version of a package across all feed indexes.

    The asu server builds its merged arch index by updating a dict feed by
    feed, so for duplicate names the last feed wins regardless of version.
    opkg in the imagebuilder picks the highest version instead — drop the
    lower-version duplicates so the served index matches what gets built.
    """
    indexes: dict[Path, dict] = {}
    best: dict[str, str] = {}
    for index_file in sorted(arch_dir.glob("*/index.json")):
        data = json.loads(index_file.read_text())
        indexes[index_file] = data
        for name, version in data.get("packages", {}).items():
            if name not in best or dpkg_vercmp(version, best[name]) > 0:
                best[name] = version

    removed = 0
    for index_file, data in indexes.items():
        packages = data.get("packages", {})
        drop = [n for n, v in packages.items() if v != best[n]]
        for name in drop:
            del packages[name]
        removed += len(drop)
        index_file.write_text(json.dumps(data))
    if removed:
        print(f" - {arch_dir.name}: dropped {removed} lower-version duplicates")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Merge official OpenWrt feed indexes into asu metadata"
    )
    parser.add_argument("meta_dir", type=Path)
    parser.add_argument("official_url")
    parser.add_argument("extra_repo_files", nargs="*")
    args = parser.parse_args()

    meta_dir = args.meta_dir
    official_url = args.official_url.rstrip("/")
    extra_repo_files = [f for f in args.extra_repo_files if Path(f).is_file()]

    # target packages (openwrt_core): toolchain runtime libs like libatomic
    # exist upstream but are absent from a src build unless selected
    for target_index in sorted(
        (meta_dir / "targets").glob("*/*/packages/index.json")
    ):
        target = "/".join(target_index.parts[-4:-2])
        official = fetch_index(
            f"{official_url}/targets/{target}/packages/index.json"
        )
        if official is None:
            print(f" - targets/{target}: no official index, keeping local as-is")
            continue
        local = json.loads(target_index.read_text())
        local_packages = local.get("packages", {})
        merged = merge_packages(official.get("packages", {}), local_packages)
        local["packages"] = merged
        target_index.write_text(json.dumps(local))
        print(
            f" - targets/{target}: local {len(local_packages)}"
            f" + official {len(official.get('packages', {}))} -> {len(merged)}"
        )

    packages_dir = meta_dir / "packages"
    if not packages_dir.is_dir():
        print(f"no packages dir: {packages_dir}")
        return 1

    for arch_dir in sorted(p for p in packages_dir.iterdir() if p.is_dir()):
        if extra_repo_files:
            mirror_extra_repos(arch_dir, extra_repo_files)
        for feed_dir in sorted(p for p in arch_dir.iterdir() if p.is_dir()):
            feed = f"{arch_dir.name}/{feed_dir.name}"
            official = fetch_index(
                f"{official_url}/packages/{feed}/index.json"
            )
            if official is None:
                print(f" - {feed}: no official index, keeping local as-is")
                continue

            local_file = feed_dir / "index.json"
            local = (
                json.loads(local_file.read_text())
                if local_file.is_file()
                else {"architecture": official.get("architecture"), "packages": {}}
            )

            local_packages = local.get("packages", {})
            merged = merge_packages(official.get("packages", {}), local_packages)
            local["packages"] = merged
            local_file.write_text(json.dumps(local))
            print(
                f" - {feed}: local {len(local_packages)}"
                f" + official {len(official.get('packages', {}))}"
                f" -> {len(merged)}"
            )

        dedupe_feed_indexes(arch_dir)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
