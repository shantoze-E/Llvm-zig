#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

# Auto detect compiler type
case "$PROGRAM" in
    *++ | c++) COMPILER=c++ ;;
    *) COMPILER=cc ;;
esac

# Target default
if [ -z "${ZIG_TARGET+x}" ]; then
    ZIG_TARGET="$(echo "$PROGRAM" | sed -E 's/(.+)(-cc|-c\+\+)//')"
fi

# Strip -mfloat-abi=hard and similar variants
filter_flags() {
    filtered=""
    for arg in "$@"; do
        case "$arg" in
            -mfloat-abi=hard | *-mfloat-abi=hard*)
                echo "[ZIG-WRAPPER] ⚠️ Removing unsupported flag: $arg" >&2
                ;;
            *)
                filtered="$filtered '$arg'"
                ;;
        esac
    done
    eval "set -- $filtered"
    echo "$@"
}

case "$PROGRAM" in
    ar | *-ar)
        exec "$ZIG_EXE" ar "$@"
        ;;
    objcopy | *-objcopy)
        exec "$ZIG_EXE" objcopy "$@"
        ;;
    strip | *-strip)
        tmpfile="$(mktemp .strip.XXXXXX)"
        "$ZIG_EXE" objcopy --strip-all "$1" "$tmpfile"
        mv "$tmpfile" "$1"
        exit 0
        ;;
    ld | *-ld | ld.lld | *-ld.lld)
        exec "$ZIG_EXE" ld.lld "$@"
        ;;
    *cc | *c++)
        eval "set -- $(filter_flags "$@")"
        exec "$ZIG_EXE" "$COMPILER" "--target=${ZIG_TARGET}" -mfloat-abi=softfp "$@"
        ;;
    *)
        if test -h "$0"; then
            exec "$(dirname "$0")/$(readlink "$0")" "$@"
        fi
        ;;
esac