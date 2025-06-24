#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

case "${PROGRAM}" in
ar | *-ar)
    exec "${ZIG_EXE}" ar "$@"
    ;;

dlltool | *-dlltool)
    exec "${ZIG_EXE}" dlltool "$@"
    ;;

lib | *-lib)
    exec "${ZIG_EXE}" lib "$@"
    ;;

ranlib | *-ranlib)
    exec "${ZIG_EXE}" ranlib "$@"
    ;;

objcopy | *-objcopy)
    exec "${ZIG_EXE}" objcopy "$@"
    ;;

ld.lld | *ld.lld | ld | *-ld)
    exec "${ZIG_EXE}" ld.lld "$@"
    ;;

rc)
    exec "${ZIG_EXE}" rc "$@"
    ;;

strip | *-strip)
    tmpfile="$(mktemp .strip.XXXXXX)"
    "${ZIG_EXE}" objcopy --strip-all "$1" "${tmpfile}"
    exec mv "${tmpfile}" "$1"
    ;;

*cc | *c++)
    _target_set_by_wrapper="false"
    if [ -z "${ZIG_TARGET+x}" ]; then
        case "${PROGRAM}" in
        cc | c++) ZIG_TARGET="$(uname -m)-linux-musl" ;;
        armeabi-v7a-cc | armeabi-v7a-c++) ZIG_TARGET="arm-linux-android" ;;
        arm64-v8a-cc | arm64-v8a-c++) ZIG_TARGET="aarch64-linux-android" ;;
        *) ZIG_TARGET="$(echo "${PROGRAM}" | sed -E 's/(.+)(-cc|-c\+\+|-gcc|-g\+\+)/\1/')" ;;
        esac
        _target_set_by_wrapper="true"
    fi

    _new_args_eval_string=""
    case "${PROGRAM}" in
    *cc) _new_args_eval_string="cc --target=${ZIG_TARGET}" ;;
    *c++) _new_args_eval_string="c++ --target=${ZIG_TARGET}" ;;
    esac

    while [ "$#" -gt 0 ]; do
        _arg="$1"
        case "$_arg" in
        -Wp,-MD,*)
            _new_args_eval_string="${_new_args_eval_string} -MD -MF '$(echo "${_arg}" | sed 's/^-Wp,-MD,//' | sed "s/'/'\\\''/g")'"
            ;;
        -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
            # skip
            ;;
        --target=*)
            if [ "${_target_set_by_wrapper}" = "true" ]; then
                :
            else
                _new_args_eval_string="${_new_args_eval_string} '$(printf '%s' "${_arg}" | sed "s/'/'\\\''/g")'"
            fi
            ;;
        -mfloat-abi=hard)
            # skip
            ;;
        *)
            _new_args_eval_string="${_new_args_eval_string} '$(printf '%s' "${_arg}" | sed "s/'/'\\\''/g")'"
            ;;
        esac
        shift
    done

    eval "set -- ${_new_args_eval_string}"
    exec "${ZIG_EXE}" "$@"
    ;;

*)
    if [ -h "$0" ]; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac