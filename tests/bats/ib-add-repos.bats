#!/usr/bin/env bats

# scripts/ib-add-repos.sh against fake imagebuilder trees. The apk path has
# no public third-party repository to build with in CI (every 25.12 apk feed
# of this project lives on private hosts), so the transformations are checked
# here, without network or docker.

bats_require_minimum_version 1.5.0

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/ib-add-repos.sh"
    WS="${BATS_TEST_TMPDIR}/ws"
    IB="${WS}/ib"
    mkdir -p "${IB}" "${WS}/keys" "${WS}/home"
    # wget settings land in ~/.wgetrc of the image user
    export HOME="${WS}/home"
    cat > "${WS}/extra.conf" <<'EOF'
# comment
src/gz r_dir http://repo.example/feed/
src/gz r_adb http://repo.example/other/packages.adb
option foo bar
EOF
    echo pem > "${WS}/keys/ci.pem"
    cd "${IB}" || return
}

opkg_tree() {
    printf 'src/gz openwrt_core http://downloads/core\noption check_signature\n' > repositories.conf
}

apk_tree() {
    # the official list ships without a trailing newline
    printf 'https://downloads/base/packages.adb' > repositories
    # shellcheck disable=SC2016  # literal make text
    printf 'APK:=$(call apk,$(TARGET_DIR)) $(if $(CONFIG_SIGNATURE_CHECK),,--allow-untrusted)\n' > Makefile
}

@test "opkg: lines appended, signature check dropped, no keys dir" {
    opkg_tree

    run "${SCRIPT}" "${WS}/extra.conf" "${WS}/keys"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"custom repositories (opkg)"* ]]
    grep -qF 'src/gz openwrt_core http://downloads/core' repositories.conf
    grep -qF 'src/gz r_dir http://repo.example/feed/' repositories.conf
    grep -qF 'src/gz r_adb http://repo.example/other/packages.adb' repositories.conf
    [ ! -e keys ]
    run ! grep -q check_signature repositories.conf
}

@test "apk: urls get /packages.adb on their own lines" {
    apk_tree

    run "${SCRIPT}" "${WS}/extra.conf"

    [ "${status}" -eq 0 ]
    expected=$'https://downloads/base/packages.adb\nhttp://repo.example/feed/packages.adb\nhttp://repo.example/other/packages.adb'
    [ "$(cat repositories)" = "${expected}" ]
}

@test "apk: lines other than src/gz <name> <url> warned about and skipped" {
    apk_tree
    cat >> "${WS}/extra.conf" <<'EOF'
http://repo.example/bare/packages.adb
src/gz r_two http://repo.example/a http://repo.example/b
EOF

    run --separate-stderr "${SCRIPT}" "${WS}/extra.conf"

    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"skip it: option foo bar"* ]]
    [[ "${stderr}" == *"skip it: http://repo.example/bare/packages.adb"* ]]
    [[ "${stderr}" == *"skip it: src/gz r_two"* ]]
    [[ "${stderr}" != *"r_dir"* ]]
    [[ "${stderr}" != *"# comment"* ]]
    run ! grep -q -e bare -e 'example/a' repositories
}

@test "apk: keys copied, --allow-untrusted forced, wget tries limited" {
    apk_tree

    run "${SCRIPT}" "${WS}/extra.conf" "${WS}/keys"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"apk key: ci.pem"* ]]
    [[ "${output}" == *"allow-untrusted forced"* ]]
    [ -f keys/ci.pem ]
    grep -qF 'APK:=$(call apk,$(TARGET_DIR)) --allow-untrusted' Makefile
    grep -qx 'tries = 2' "${HOME}/.wgetrc"
    run ! grep -q CONFIG_SIGNATURE_CHECK Makefile
}

@test "apk: IB_APK_ALLOW_UNTRUSTED=0 leaves the Makefile alone" {
    apk_tree

    IB_APK_ALLOW_UNTRUSTED=0 run "${SCRIPT}" "${WS}/extra.conf"

    [ "${status}" -eq 0 ]
    grep -qF 'CONFIG_SIGNATURE_CHECK' Makefile
    grep -qF 'http://repo.example/feed/packages.adb' repositories
}

@test "apk: a changed upstream APK definition fails loudly" {
    apk_tree
    printf 'APK:=something else\n' > Makefile

    run "${SCRIPT}" "${WS}/extra.conf"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"--allow-untrusted switch not found"* ]]
}

@test "empty conf changes nothing" {
    opkg_tree
    : > "${WS}/empty.conf"

    run "${SCRIPT}" "${WS}/empty.conf"

    [ "${status}" -eq 0 ]
    [ "$(cat repositories.conf)" = $'src/gz openwrt_core http://downloads/core\noption check_signature' ]
}

@test "neither repositories.conf nor repositories fails" {
    run "${SCRIPT}" "${WS}/extra.conf"

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"neither repositories.conf"* ]]
}
