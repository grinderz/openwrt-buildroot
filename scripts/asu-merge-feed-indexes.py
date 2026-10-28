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
into the imagebuilder image) are mirrored the same way: their index.json
(apk repositories, 25.12+) or Packages file (opkg) is converted to an
index.json feed and registered in feeds.conf, so owut's version checks see
them too.

Usage: asu-merge-feed-indexes.py <meta_version_dir> <official_version_url> \
           [repositories-extra.conf ...] [--self-url <public metadata url>]
  e.g. asu-merge-feed-indexes.py asu/metadata/releases/24.10.8 \
           https://downloads.openwrt.org/releases/24.10.8 \
           imagebuilder/24.10.8/repositories-extra.conf
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# the publish log is usually a redirected file: with block buffering the
# retry/timeout lines show up only at exit, minutes after they happened
sys.stdout.reconfigure(line_buffering=True)

FETCH_TRIES = 3
FETCH_RETRY_DELAY = 2

# url -> body; every arch dir sees every repositories-extra.conf line, so
# without the cache each extra Packages file is downloaded once per arch.
# failures are cached too (None): a dead url is not retried per arch
_fetch_cache: dict[str, bytes | None] = {}
# urls that stayed unreachable after all tries. Official feed indexes: a
# merge that silently kept a sparse local index would make owut report
# every official package as missing, so main() turns these into a non-zero
# exit. Third-party repositories: a warning only — a flaky host must not
# block publishing every target, the previously mirrored index (if any)
# stays in place
fetch_failures: list[str] = []
extra_failures: list[str] = []
# (repositories-extra.conf, line) already warned about as malformed
_bad_lines: set[tuple[str, str]] = set()

# repositories-extra.conf spelling of this host's asu metadata server, the
# Makefile renders it to ASU_UPSTREAM_CUSTOM for the imagebuilder
SELF_URL_PLACEHOLDER = "@ASU_UPSTREAM_CUSTOM@"


def fetch(
    url: str, quiet_404: bool = False, failures: list[str] | None = None
) -> bytes | None:
    if failures is None:
        failures = fetch_failures
    if url in _fetch_cache:
        return _fetch_cache[url]
    body = None
    for attempt in range(1, FETCH_TRIES + 1):
        try:
            with urllib.request.urlopen(url, timeout=30) as res:
                body = res.read()
            break
        except urllib.error.HTTPError as e:
            # 404 is a definite answer (feed absent upstream), no retry;
            # silent for probes that have a fallback (index.json before
            # Packages)
            if e.code == 404:
                if not quiet_404:
                    print(f"   ! {url}: {e}")
                break
            print(f"   ! {url}: {e}")
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            print(f"   ! {url}: {e}")
        if attempt < FETCH_TRIES:
            time.sleep(FETCH_RETRY_DELAY)
    else:
        failures.append(url)
    _fetch_cache[url] = body
    return body


def write_atomic(path: Path, text: str) -> None:
    """nginx serves the metadata tree live: never expose a half-written file."""
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def fetch_index(
    url: str, quiet_404: bool = False, failures: list[str] | None = None
) -> dict | None:
    raw = fetch(url, quiet_404, failures)
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
    imagebuilder actually installs. [epoch:]upstream[-revision] are compared
    part by part like dpkg (1.2a-1 > 1.2-1, "-" is a separator, not a char).
    """

    def split(v: str) -> tuple[str, str, str]:
        epoch, sep, rest = v.partition(":")
        if not sep:
            epoch, rest = "0", v
        upstream, sep, revision = rest.rpartition("-")
        if not sep:
            upstream, revision = rest, ""
        return epoch, upstream, revision

    for pa, pb in zip(split(a), split(b), strict=True):
        if r := _vercmp_fragment(pa, pb):
            return r
    return 0


def _vercmp_fragment(a: str, b: str) -> int:
    """dpkg comparison of one version part (digit runs numeric, ~ lowest)."""

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


def merge_packages(official: dict[str, str], local: dict[str, str]) -> dict[str, str]:
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
        if (
            name
            and version
            and (arch is None or pkg_arch is None or pkg_arch in (arch, "all"))
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


def fetch_extra_packages(url: str, arch: str) -> dict[str, str] | None:
    """{name: version} of an extra repository, filtered to one architecture.

    index.json first: apk repositories (25.12+) ship it next to the binary
    packages.adb, and buildbot-style opkg repositories next to Packages.
    Plain opkg repositories only have Packages, parsed as a fallback.
    None when neither could be fetched. Every arch dir sees every
    repositories-extra.conf line, so entries built for a different
    architecture are dropped.
    """
    index = fetch_index(f"{url}/index.json", quiet_404=True, failures=extra_failures)
    if index is not None:
        index_arch = index.get("architecture")
        if index_arch and index_arch not in (arch, "all"):
            return {}
        return dict(index.get("packages", {}))
    raw = fetch(f"{url}/Packages", failures=extra_failures)
    if raw is None:
        return None
    return parse_packages(raw.decode(), arch)


def mirror_extra_repos(
    arch_dir: Path, repo_files: list[str], self_urls: list[str]
) -> None:
    feeds_conf = arch_dir / "feeds.conf"
    feeds_text = feeds_conf.read_text() if feeds_conf.is_file() else ""
    # feeds written during this run: the first write replaces whatever a
    # previous run left (dropping packages meanwhile removed upstream),
    # later same-named writes merge (see below)
    written: set[str] = set()

    for repo_file in repo_files:
        for line in Path(repo_file).read_text().splitlines():
            fields = line.split()
            if not fields or fields[0].startswith("#"):
                continue
            if len(fields) != 3 or fields[0] != "src/gz":
                # a bare apk url (.../packages.adb) has no feed name to key
                # the index by; every arch dir sees the line, warn once
                if (repo_file, line) not in _bad_lines:
                    _bad_lines.add((repo_file, line))
                    print(
                        f" - WARNING {repo_file}: not 'src/gz <name> <url>', "
                        f"skipped: {line}"
                    )
                continue
            _, feed, url = fields
            # the imagebuilder side (ib-add-repos.sh) accepts an apk style
            # url naming the index file; the indexes here sit next to it
            url = url.rstrip("/").removesuffix("/packages.adb")

            # repositories served by this very metadata tree (local_core on
            # the asu metadata server, written as @ASU_UPSTREAM_CUSTOM@): their
            # packages are published here directly, and the server is not up
            # yet while publishing
            if url.startswith(SELF_URL_PLACEHOLDER) or any(
                url.startswith(s) for s in self_urls
            ):
                print(f" - extra {feed}: served by this metadata tree, skipped")
                continue

            packages = fetch_extra_packages(url, arch_dir.name)
            if packages is None:
                kept = (arch_dir / feed / "index.json").is_file()
                print(
                    f" - extra {feed}: no index.json / Packages fetched, "
                    + ("previous index kept" if kept else "skipped")
                )
                continue
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
            write_atomic(
                index_file,
                json.dumps({"architecture": arch_dir.name, "packages": packages}),
            )
            if f"src/gz {feed} " not in feeds_text:
                feeds_text += f"src/gz {feed} {url}\n"
            print(f" - extra {arch_dir.name}/{feed}: {len(packages)} packages")

    write_atomic(feeds_conf, feeds_text)


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
        write_atomic(index_file, json.dumps(data))
    if removed:
        print(f" - {arch_dir.name}: dropped {removed} lower-version duplicates")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Merge official OpenWrt feed indexes into asu metadata"
    )
    parser.add_argument("meta_dir", type=Path)
    parser.add_argument("official_url")
    parser.add_argument("extra_repo_files", nargs="*")
    parser.add_argument(
        "--self-url",
        action="append",
        default=[],
        metavar="URL",
        help="public url prefix of this metadata server; extra repositories "
        "under it are skipped (served from the published tree itself)",
    )
    args = parser.parse_args()
    self_urls = [u.rstrip("/") + "/" for u in args.self_url if u]

    meta_dir = args.meta_dir
    official_url = args.official_url.rstrip("/")
    extra_repo_files = [f for f in args.extra_repo_files if Path(f).is_file()]

    # target packages (openwrt_core): toolchain runtime libs like libatomic
    # exist upstream but are absent from a src build unless selected
    for target_index in sorted((meta_dir / "targets").glob("*/*/packages/index.json")):
        target = "/".join(target_index.parts[-4:-2])
        official = fetch_index(f"{official_url}/targets/{target}/packages/index.json")
        if official is None:
            print(f" - targets/{target}: no official index, keeping local as-is")
            continue
        local = json.loads(target_index.read_text())
        local_packages = local.get("packages", {})
        merged = merge_packages(official.get("packages", {}), local_packages)
        local["packages"] = merged
        write_atomic(target_index, json.dumps(local))
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
            mirror_extra_repos(arch_dir, extra_repo_files, self_urls)
        for feed_dir in sorted(p for p in arch_dir.iterdir() if p.is_dir()):
            feed = f"{arch_dir.name}/{feed_dir.name}"
            # third-party feed dirs (mirrored above) have no official
            # counterpart: a 404 here is expected, not worth a line
            official = fetch_index(
                f"{official_url}/packages/{feed}/index.json", quiet_404=True
            )
            if official is None:
                print(f" - {feed}: no official index, keeping local as-is")
                continue

            local_file = feed_dir / "index.json"
            # a feed the src build did not touch starts as a copy of the
            # official header (architecture, version: v2 marks ABI-free names)
            local = (
                json.loads(local_file.read_text())
                if local_file.is_file()
                else {k: v for k, v in official.items() if k != "packages"}
                | {"packages": {}}
            )

            local_packages = local.get("packages", {})
            merged = merge_packages(official.get("packages", {}), local_packages)
            local["packages"] = merged
            write_atomic(local_file, json.dumps(local))
            print(
                f" - {feed}: local {len(local_packages)}"
                f" + official {len(official.get('packages', {}))}"
                f" -> {len(merged)}"
            )

        dedupe_feed_indexes(arch_dir)

    if extra_failures:
        print(
            f"warning: {len(extra_failures)} third-party url(s) unreachable"
            f" after {FETCH_TRIES} tries (previous indexes kept where present):"
        )
        for url in extra_failures:
            print(f"   ! {url}")
    if fetch_failures:
        print(
            f"{len(fetch_failures)} official url(s) unreachable"
            f" after {FETCH_TRIES} tries:"
        )
        for url in fetch_failures:
            print(f"   ! {url}")
        print("published indexes may be incomplete, re-run the publish")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
