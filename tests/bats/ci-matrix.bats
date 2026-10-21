#!/usr/bin/env bats

# scripts/ci-matrix.sh: the src/img matrix of .github/workflows/build.yml,
# against a fixture tree (deterministic) and the real tree (invariants).

bats_require_minimum_version 1.5.0

setup() {
    REPO="${BATS_TEST_DIRNAME}/../.."
    SCRIPT="${REPO}/scripts/ci-matrix.sh"
    WS="${BATS_TEST_TMPDIR}/ws"
    mkdir -p "${WS}/versions" \
        "${WS}/srcbuilder/1.0/targets/ramips/mt7621" \
        "${WS}/srcbuilder/1.0/targets/x86/64" \
        "${WS}/imagebuilder/1.0/profiles/alpha" \
        "${WS}/imagebuilder/1.0/profiles/beta" \
        "${WS}/imagebuilder/1.0/profiles/orphan" \
        "${WS}/imagebuilder/1.0/devices/dev1"
    : > "${WS}/versions/1.0.mk"
    printf 'CONFIG_TARGET := ramips\nCONFIG_SUBTARGET := mt7621\nCONFIG_PROFILE := alpha\n' \
        > "${WS}/imagebuilder/1.0/profiles/alpha/config.mk"
    printf 'CONFIG_TARGET := x86\nCONFIG_SUBTARGET := 64\nCONFIG_PROFILE := beta\n' \
        > "${WS}/imagebuilder/1.0/profiles/beta/config.mk"
    # profile of a target without a src config: no src build, no image
    printf 'CONFIG_TARGET := sunxi\nCONFIG_SUBTARGET := cortexa53\nCONFIG_PROFILE := orphan\n' \
        > "${WS}/imagebuilder/1.0/profiles/orphan/config.mk"
    printf 'CONFIG_TARGET := ramips\nCONFIG_SUBTARGET := mt7621\nCONFIG_PROFILE := alpha\nCONFIG_DEVICE := dev1\n' \
        > "${WS}/imagebuilder/1.0/devices/dev1/config.mk"
    cd "${WS}" || return
}

@test "fixture: every src target, profiles of built targets only, no devices" {
    run "${SCRIPT}" "1.0" all

    [ "${status}" -eq 0 ]
    [ "$(jq -c '.src' <<< "${output}")" = '[{"version":"1.0","target":"ramips","subtarget":"mt7621"},{"version":"1.0","target":"x86","subtarget":"64"}]' ]
    [ "$(jq -r '[.img[].name] | join(" ")' <<< "${output}")" = "alpha beta" ]
    [ "$(jq -r '.img[0].target + "/" + .img[0].subtarget' <<< "${output}")" = "ramips/mt7621" ]
}

@test "fixture: targets filter narrows src and img" {
    run "${SCRIPT}" "1.0" "x86/64"

    [ "${status}" -eq 0 ]
    [ "$(jq -r '[.src[] | .target] | join(" ")' <<< "${output}")" = "x86" ]
    [ "$(jq -r '[.img[].name] | join(" ")' <<< "${output}")" = "beta" ]
}

@test "targets filter matching nothing fails" {
    run "${SCRIPT}" "1.0" "sunxi/cortexa53"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"no src targets"* ]]
}

@test "unknown version fails" {
    run "${SCRIPT}" "9.9" all

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"unknown version: 9.9"* ]]
}

@test "real tree: 24.10.8 has 8 src targets and the x86 generic profile" {
    cd "${REPO}" || return

    run "${SCRIPT}" "24.10.8" all

    [ "${status}" -eq 0 ]
    [ "$(jq '.src | length' <<< "${output}")" -eq 8 ]
    [ "$(jq -r '.img[] | select(.name == "generic") | .target + "/" + .subtarget' <<< "${output}")" = "x86/64" ]
    [ "$(jq '[.img[].name] | index("demo-lec-7233")' <<< "${output}")" = "null" ]
}
