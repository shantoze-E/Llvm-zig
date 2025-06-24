#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

case "${PROGRAM}" in
ar | *-ar) exec ${ZIG_EXE} ar "$@" ;;
dlltool | *-dlltool) exec ${ZIG_EXE} dlltool "$@" ;;
lib | *-lib) exec ${ZIG_EXE} lib "$@" ;;
ranlib | *-ranlib) exec ${ZIG_EXE} ranlib "$@" ;;
objcopy | *-objcopy) exec ${ZIG_EXE} objcopy "$@" ;;
ld.lld | *ld.lld | ld | *-ld) exec ${ZIG_EXE} ld.lld "$@" ;;
rc) exec $ZIG_EXE rc "$@" ;;
strip | *-strip)
    tmpfile="$1$(mktemp -d --dry-run .strip.XXXX)"
    zig objcopy --strip-all "$1" "${tmpfile}"
    exec mv "${tmpfile}" "$1"
    ;;
*cc | *c++)
    if ! test "${ZIG_TARGET+1}"; then
        case "${PROGRAM}" in
        cc | c++) ZIG_TARGET="$(uname -m)-linux-musl" ;;
        armeabi-v7a-cc | armeabi-v7a-c++) ZIG_TARGET="arm-linux-android" ;;
        arm64-v8a-cc | arm64-v8a-c++) ZIG_TARGET="aarch64-linux-android" ;;
        *) ZIG_TARGET=$(echo "${PROGRAM}" | sed -E 's/(.+)(-cc|-c\+\+|-gcc|-g\+\+)/\1/') ;;
        esac
    fi

    # Prepended args
    set -- "dummy" # Placeholder to make shift work for first real arg
    case "${PROGRAM}" in
    *cc) set -- "$@" "cc" "--target=${ZIG_TARGET}" ;;
    *c++) set -- "$@" "c++" "--target=${ZIG_TARGET}" ;;
    esac
    shift # Remove the "dummy" placeholder

    # Filter arguments
    _filtered_args=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -Wp,-MD,*)
            _filtered_args="${_filtered_args} -MD -MF $(echo "$1" | sed 's/^-Wp,-MD,//')"
            ;;
        -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
            ;;
        --target=*)
            if [ -n "${ZIG_TARGET}" ]; then
                ;; # Ignore any --target if ZIG_TARGET is explicitly set
            else
                _filtered_args="${_filtered_args} \"$1\""
            fi
            ;;
        -mfloat-abi=hard)
            ;;
        *)
            _filtered_args="${_filtered_args} \"$1\""
            ;;
        esac
        shift
    done

    eval "set -- $_filtered_args"

    exec ${ZIG_EXE} "${@}"
    ;;
*)
    if test -h "$0"; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac