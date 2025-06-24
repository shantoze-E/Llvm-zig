#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

filter_mfloat_abi() {
    result=""
    for arg in "$@"; do
        case "$arg" in
            -mfloat-abi=hard)
                echo "[ZIG-WRAPPER] ⚠️  Removing unsupported flag: $arg" >&2
                ;;
            *-mfloat-abi=hard*)
                echo "[ZIG-WRAPPER] ⚠️  Removing unsupported embedded flag: $arg" >&2
                ;;
            *)
                result="$result '$arg'"
                ;;
        esac
    done
    eval "set -- $result"
    echo "$@"
}

case "${PROGRAM}" in
ar | *-ar)
    exec "${ZIG_EXE}" ar "$@"
    ;;
ld | *-ld | ld.lld | *-ld.lld)
    exec "${ZIG_EXE}" ld.lld "$@"
    ;;
strip | *-strip)
    tmpfile="$(mktemp .strip.XXXXXX)"
    "${ZIG_EXE}" objcopy --strip-all "$1" "${tmpfile}"
    mv "${tmpfile}" "$1"
    exit 0
    ;;
objcopy | *-objcopy)
    exec "${ZIG_EXE}" objcopy "$@"
    ;;
*cc | *c++)
    if [ -z "${ZIG_TARGET+x}" ]; then
        ZIG_TARGET="$(echo "$PROGRAM" | sed -E 's/(.+)(-cc|-c\+\+)//')"
    fi
    compiler="cc"
    [ "${PROGRAM#*c++}" != "$PROGRAM" ] && compiler="c++"

    # Filter argumen
    eval "set -- $(filter_mfloat_abi "$@")"

    exec "${ZIG_EXE}" "${compiler}" "--target=${ZIG_TARGET}" "$@"
    ;;
*)
    if test -h "$0"; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac