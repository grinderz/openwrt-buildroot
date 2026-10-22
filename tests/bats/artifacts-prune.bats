#!/usr/bin/env bats

# scripts/artifacts-prune.sh: stale dated src/img archives of `make
# artifacts.prune`, against a fixture artifacts tree.

bats_require_minimum_version 1.5.0

setup() {
    REPO="${BATS_TEST_DIRNAME}/../.."
    SCRIPT="${REPO}/scripts/artifacts-prune.sh"
    A="${BATS_TEST_TMPDIR}/artifacts"
    mkdir -p "${A}/src/1.0" "${A}/img/1.0" "${A}/img/2.0/tmp" "${A}/logs"
    # three src builds of one target, one of another
    touch "${A}/src/1.0/openwrt-1.0-ramips-mt7621-2026-01-01.tar.zst" \
        "${A}/src/1.0/openwrt-1.0-ramips-mt7621-2026-01-03.tar.zst" \
        "${A}/src/1.0/openwrt-1.0-ramips-mt7621-2026-01-02.tar.zst" \
        "${A}/src/1.0/openwrt-1.0-x86-64-2026-01-01.tar.zst"
    # undated products: never listed
    touch "${A}/src/1.0/openwrt-1.0-ramips-mt7621-securifi_almond-3s.zip" \
        "${A}/src/1.0/openwrt-imagebuilder-1.0-ramips-mt7621.Linux-x86_64.tar.zst" \
        "${A}/src/1.0/openwrt-sdk-1.0-ramips-mt7621_gcc-14.3.0_musl.Linux-x86_64.tar.zst"
    # profile, device and official-cycle images are separate groups
    touch "${A}/img/1.0/openwrt-1.0-ramips-mt7621-securifi_almond-3s-s-2026-01-01.tar.zst" \
        "${A}/img/1.0/openwrt-1.0-ramips-mt7621-securifi_almond-3s-s-2026-01-02.tar.zst" \
        "${A}/img/1.0/openwrt-1.0-ramips-mt7621-securifi_almond-3s-rtr3-s-2026-01-01.tar.zst" \
        "${A}/img/1.0/openwrt-1.0-ramips-mt7621-securifi_almond-3s-rtr3-o-2026-01-01.tar.zst" \
        "${A}/img/1.0/openwrt-1.0-ramips-mt7621-securifi_almond-3s-rtr3-s-2026-01-02.tar.zst"
    touch "${A}/img/2.0/tmp/not-an-archive-2026-01-01.txt" \
        "${A}/logs/src-1.0-ramips-mt7621-2026-01-01.tar.zst"
}

@test "keep 1: everything but the newest of each name, oldest first" {
    run "${SCRIPT}" "${A}"

    [ "${status}" -eq 0 ]
    [ "${output}" = "${A}/img/1.0/openwrt-1.0-ramips-mt7621-securifi_almond-3s-rtr3-s-2026-01-01.tar.zst
${A}/img/1.0/openwrt-1.0-ramips-mt7621-securifi_almond-3s-s-2026-01-01.tar.zst
${A}/src/1.0/openwrt-1.0-ramips-mt7621-2026-01-01.tar.zst
${A}/src/1.0/openwrt-1.0-ramips-mt7621-2026-01-02.tar.zst" ]
}

@test "keep 2" {
    run "${SCRIPT}" "${A}" 2

    [ "${status}" -eq 0 ]
    [ "${output}" = "${A}/src/1.0/openwrt-1.0-ramips-mt7621-2026-01-01.tar.zst" ]
}

@test "keep 0 lists every dated archive" {
    run "${SCRIPT}" "${A}" 0

    [ "${status}" -eq 0 ]
    [ "${#lines[@]}" -eq 9 ]
    run grep -c -e '\.zip$' -e 'openwrt-imagebuilder-' -e 'openwrt-sdk-' -e '/logs/' -e '/img/2.0/tmp/' <<< "${output}"
    [ "${output}" = 0 ]
}

@test "missing dir and bad keep" {
    run "${SCRIPT}" "${BATS_TEST_TMPDIR}/none"
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]

    run "${SCRIPT}" "${A}" two
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"keep must be a number"* ]]
}
