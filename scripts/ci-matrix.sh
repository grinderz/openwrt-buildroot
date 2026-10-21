#!/usr/bin/env bash
# Build matrix for .github/workflows/build.yml.
#
# usage: ci-matrix.sh <versions> <targets>
#   versions  space-separated OWRT_RELEASE names (versions/<name>.mk)
#   targets   "all" or space-separated target/subtarget pairs
#
# Prints one JSON object:
#   src  every srcbuilder/<ver>/targets/<t>/<s> of the selected versions
#        (filtered by <targets>): one src build job each
#   img  every imagebuilder/<ver>/profiles/<name> whose target is in src:
#        img.src.profile.<name> runs after that target's src build. Devices
#        (imagebuilder/<ver>/devices) stay out of CI: their custom packages
#        come from private hosts, they are built locally from the artifacts
#        (profiles with private repositories only get opkg/apk warnings).
set -o errexit -o nounset -o pipefail

versions=${1:?usage: $0 <versions> <targets>}
targets=${2:-all}

src_json='[]'
img_json='[]'

for version in $versions; do
    [ -f "versions/${version}.mk" ] || { echo "unknown version: ${version}" >&2; exit 1; }
    for dir in srcbuilder/"${version}"/targets/*/*/; do
        [ -d "${dir}" ] || continue
        subtarget=$(basename "${dir}")
        target=$(basename "$(dirname "${dir}")")
        if [ "${targets}" != all ]; then
            case " ${targets} " in
                *" ${target}/${subtarget} "*) ;;
                *) continue ;;
            esac
        fi
        src_json=$(jq -c --arg v "${version}" --arg t "${target}" --arg s "${subtarget}" \
            '. + [{version: $v, target: $t, subtarget: $s}]' <<< "${src_json}")
    done

    for cfg in imagebuilder/"${version}"/profiles/*/config.mk; do
        [ -f "${cfg}" ] || continue
        name=$(basename "$(dirname "${cfg}")")
        target=$(awk '$1 == "CONFIG_TARGET" {print $3}' "${cfg}")
        subtarget=$(awk '$1 == "CONFIG_SUBTARGET" {print $3}' "${cfg}")
        if [ -z "${target}" ] || [ -z "${subtarget}" ]; then
            echo "skip ${cfg}: no CONFIG_TARGET/CONFIG_SUBTARGET" >&2
            continue
        fi
        in_src=$(jq -r --arg v "${version}" --arg t "${target}" --arg s "${subtarget}" \
            'any(.[]; .version == $v and .target == $t and .subtarget == $s)' <<< "${src_json}")
        [ "${in_src}" = true ] || continue
        img_json=$(jq -c --arg v "${version}" --arg n "${name}" --arg t "${target}" --arg s "${subtarget}" \
            '. + [{version: $v, name: $n, target: $t, subtarget: $s}]' <<< "${img_json}")
    done
done

if [ "${src_json}" = '[]' ]; then
    echo "no src targets for versions '${versions}' and targets '${targets}'" >&2
    exit 1
fi
jq -c -n --argjson src "${src_json}" --argjson img "${img_json}" '{src: $src, img: $img}'
