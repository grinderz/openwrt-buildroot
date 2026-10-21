#!/bin/sh
# Append third-party repositories to an OpenWrt imagebuilder, opkg or apk.
#
# usage: ib-add-repos.sh <repositories-extra.conf> [<keys dir>]
# Run from the imagebuilder root (/builder). Shared by Img/Make (bind
# mounted into the official image at run time) and by imgbuilder*.Dockerfile
# (baked into the src/official builder images), so both paths behave alike.
#
# The conf lines are opkg syntax (src/gz <name> <url>; the name is what the
# asu index merge keys feeds by). Per package manager:
#   opkg (repositories.conf present): lines appended as they are, signature
#        check disabled (opkg cannot trust per repository)
#   apk  (repositories present, 25.12+): only the urls are appended, with
#        /packages.adb added (apk entries name the index file), *.pem
#        files from <keys dir> are copied to keys/, and unless
#        IB_APK_ALLOW_UNTRUSTED=0 --allow-untrusted is forced into the APK
#        invocation of the imagebuilder Makefile - the same trust level as
#        the opkg path, for repos that publish no key; wget (apk's fetcher)
#        is limited to 2 tries so a dead repository fails fast
set -eu

conf=${1:?usage: $0 <repositories-extra.conf> [<keys dir>]}
keys=${2:-}

[ -s "$conf" ] || exit 0

if [ -f repositories.conf ]; then
    echo " - custom repositories (opkg)"
    cat "$conf" >> repositories.conf
    sed -i '/check_signature/d' repositories.conf
elif [ -f repositories ]; then
    echo " - custom repositories (apk)"
    # apk repository entries point at the index file itself (the official
    # list is .../packages/packages.adb, see include/feeds.mk), the opkg
    # style lines name the directory
    urls=$(awk '$1 == "src/gz" && NF >= 3 {
        sub("/+$", "", $3)
        if ($3 !~ /\.adb$/) $3 = $3 "/packages.adb"
        print $3
    }' "$conf")
    if [ -n "$urls" ]; then
        # keep the appended urls on their own lines even when the file
        # lacks a trailing newline
        [ -z "$(tail -c1 repositories)" ] || echo >> repositories
        echo "$urls" >> repositories
    fi
    if [ -n "$keys" ] && [ -d "$keys" ]; then
        for key in "$keys"/*.pem; do
            [ -f "$key" ] || continue
            echo " - apk key: $(basename "$key")"
            mkdir -p keys
            cp "$key" keys/
        done
    fi
    if [ "${IB_APK_ALLOW_UNTRUSTED:-1}" = 1 ]; then
        # grep guard: an upstream change of the APK definition fails here,
        # loudly, instead of a sed that silently patches nothing
        # (literal make text, no shell expansion wanted)
        # shellcheck disable=SC2016
        pattern='$(if $(CONFIG_SIGNATURE_CHECK),,--allow-untrusted)'
        if ! grep -qF "$pattern" Makefile; then
            echo " - imagebuilder Makefile: APK --allow-untrusted switch not found, cannot force it" >&2
            exit 1
        fi
        sed -i "s/\$(if \$(CONFIG_SIGNATURE_CHECK),,--allow-untrusted)/--allow-untrusted/" Makefile
        echo " - apk: --allow-untrusted forced (IB_APK_ALLOW_UNTRUSTED=1)"
    fi
    # apk fetches the indexes with "wget -q -T 60" and GNU wget retries 20
    # times by default: one dead third-party host stalls every apk call for
    # 20 minutes, longer than asu's job timeout (10 min). Two tries, then
    # apk skips the repository with a warning. ~/.wgetrc covers the image
    # user (buildbot, HOME=/builder, also under asu's podman exec),
    # /etc/wgetrc the root runs of Img/Make
    for rc in /etc/wgetrc "${HOME:-/builder}/.wgetrc" /builder/.wgetrc; do
        { [ -w "$rc" ] || { [ ! -e "$rc" ] && [ -w "$(dirname "$rc")" ]; }; } || continue
        grep -qs '^tries' "$rc" || echo 'tries = 2' >> "$rc"
    done
    echo " - apk: wget tries limited to 2 (dead repositories fail fast)"
else
    echo " - neither repositories.conf (opkg) nor repositories (apk) in $(pwd):" >&2
    echo "   snapshot image that unpacks the imagebuilder at runtime?" >&2
    exit 1
fi
