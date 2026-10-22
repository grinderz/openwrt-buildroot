#!/usr/bin/env bash
# Stale dated artifacts, for `make artifacts.prune`.
#
# usage: artifacts-prune.sh <artifacts dir> [keep]
#
# Dated products of the src and img pipelines end in -<YYYY-MM-DD>.tar.zst:
#   src/<ver>/openwrt-<ver>-<target>-<subtarget>-<date>.tar.zst
#   img/<ver>/openwrt-<ver>-<target>-<subtarget>-<profile>[-<device>]-<b|s|o>-<date>.tar.zst
# Files with the same name up to the date form a group; this prints every
# file beyond the <keep> (default 1) newest of its group, one path per line,
# oldest first. Undated files (imagebuilder, sdk, profile zips) are rewritten
# in place by every build and never listed. Nothing is deleted here.
set -o errexit -o nounset -o pipefail

dir=${1:?usage: $0 <artifacts dir> [keep]}
keep=${2:-1}

case "${keep}" in
    ''|*[!0-9]*) echo "keep must be a number: ${keep}" >&2; exit 1 ;;
esac

[ -d "${dir}" ] || exit 0

find "${dir}/src" "${dir}/img" -type f \
    -name '*-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].tar.zst' 2>/dev/null \
    | awk '{
        key = $0
        sub(/-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\.tar\.zst$/, "", key)
        print key "\t" $0
    }' \
    | sort -t "$(printf '\t')" -k1,1 -k2,2r \
    | awk -F '\t' -v keep="${keep}" '
        $1 != prev { prev = $1; n = 0 }
        ++n > keep { print $2 }
    ' \
    | sort
