#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

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
    _target_set_by_wrapper="false"

    # Deteksi target triple dari ZIG_TARGET atau nama symlink
    if [ -z "${ZIG_TARGET+x}" ]; then
        case "${PROGRAM}" in
            cc | c++) ZIG_TARGET="$(uname -m)-linux-musl" ;;
            *) ZIG_TARGET="$(echo "$PROGRAM" | sed -E 's/(.+)(-cc|-c\+\+)//')" ;;
        esac
        _target_set_by_wrapper="true"
    fi

    # Inisialisasi argumen baru
    _new_args=""

    case "${PROGRAM}" in
        *cc) _new_args="cc --target=${ZIG_TARGET}" ;;
        *c++) _new_args="c++ --target=${ZIG_TARGET}" ;;
    esac

    while [ "$#" -gt 0 ]; do
        _arg="$1"

        case "$_arg" in
            --target=*)
                # Jangan tambahkan kalau sudah dari wrapper
                if [ "${_target_set_by_wrapper}" = "true" ]; then
                    :
                else
                    _new_args="${_new_args} '$_arg'"
                fi
                ;;

            -mfloat-abi=*)
                # ❗️ Skip semua varian `-mfloat-abi` karena Zig tidak mendukung untuk Android
                ;;

            -Wp,-MD,*) # Ubah jadi -MD -MF <file>
                _mf_file="$(echo "$_arg" | sed 's/^-Wp,-MD,//')"
                _new_args="${_new_args} -MD -MF '$_mf_file'"
                ;;

            -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
                # Skip linker warning flags
                ;;

            *)
                _new_args="${_new_args} '$_arg'"
                ;;
        esac
        shift
    done

    eval "set -- $_new_args"
    exec "${ZIG_EXE}" "$@"
    ;;

*)
    # Fallback symlink support
    if test -h "$0"; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac