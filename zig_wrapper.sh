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
rc) exec ${ZIG_EXE} rc "$@" ;;
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

    _original_args_list="$@"
    set --

    case "${PROGRAM}" in
    *cc) set -- "$@" cc "--target=${ZIG_TARGET}" ;;
    *c++) set -- "$@" c++ "--target=${ZIG_TARGET}" ;;
    esac

    _temp_list=""
    for _arg in $_original_args_list; do
        case "$_arg" in
        -Wp,-MD,*)
            _temp_list="${_temp_list} -MD -MF $(echo "$_arg" | sed 's/^-Wp,-MD,//')"
            ;;
        -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
            ;;
        --target=*)
            if [ -z "${ZIG_TARGET}" ]; then
                _temp_list="${_temp_list} \"$_arg\""
            fi
            ;;
        -mfloat-abi=hard)
            ;;
        *)
            _temp_list="${_temp_list} \"$_arg\""
            ;;
        esac
    done

    eval "set -- $@ $_temp_list"
    exec ${ZIG_EXE} "$@"
    ;;
*)
    if test -h "$0"; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac