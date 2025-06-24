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
    _target_set_by_wrapper="false" # Flag untuk menunjukkan apakah target disetel oleh wrapper ini
    if ! test "${ZIG_TARGET+1}"; then
        case "${PROGRAM}" in
        cc | c++) ZIG_TARGET="$(uname -m)-linux-musl" ;;
        armeabi-v7a-cc | armeabi-v7a-c++) ZIG_TARGET="arm-linux-android" ;;
        arm64-v8a-cc | arm64-v8a-c++) ZIG_TARGET="aarch64-linux-android" ;;
        *) ZIG_TARGET=$(echo "${PROGRAM}" | sed -E 's/(.+)(-cc|-c\+\+|-gcc|-g\+\+)/\1/') ;;
        esac
        _target_set_by_wrapper="true"
    fi

    # Inisialisasi daftar argumen baru dalam bentuk string yang akan dievaluasi.
    # Argumen pertama selalu 'cc' atau 'c++' dan '--target'.
    _new_args_eval_string=""
    case "${PROGRAM}" in
    *cc) _new_args_eval_string="cc --target=${ZIG_TARGET}" ;;
    *c++) _new_args_eval_string="c++ --target=${ZIG_TARGET}" ;;
    esac

    # Proses argumen asli menggunakan loop while dan shift.
    # Ini adalah cara paling aman di POSIX untuk mengiterasi argumen.
    while [ "$#" -gt 0 ]; do
        _arg="$1"
        case "$_arg" in
        -Wp,-MD,*)
            # Tambahkan -MD -MF <file>
            # Kutip argumen dengan hati-hati untuk `eval`
            _new_args_eval_string="${_new_args_eval_string} -MD -MF '$(echo "${_arg}" | sed 's/^-Wp,-MD,//' | sed "s/'/'\\\''/g")'"
            ;;
        -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
            # Abaikan flag ini
            ;;
        --target=*)
            # Abaikan --target jika ZIG_TARGET sudah disetel oleh wrapper
            if [ "${_target_set_by_wrapper}" = "true" ]; then
                
            else
                # Tambahkan argumen, dikutuk dengan hati-hati
                _new_args_eval_string="${_new_args_eval_string} '$(printf '%s' "${_arg}" | sed "s/'/'\\\''/g")'"
            fi
            ;;
        -mfloat-abi=hard)
            # Filter flag ini
            ;;
        *)
            # Tambahkan argumen lain, dikutuk dengan hati-hati
            _new_args_eval_string="${_new_args_eval_string} '$(printf '%s' "${_arg}" | sed "s/'/'\\\''/g")'"
            ;;
        esac
        shift # Pindah ke argumen berikutnya
    done

    # Akhirnya, evaluasi string yang telah dibangun untuk mengatur parameter posisi baru ($@)
    eval "set -- ${_new_args_eval_string}"

    exec ${ZIG_EXE} "${@}"
    ;;
*)
    if test -h "$0"; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac