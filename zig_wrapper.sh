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

    # Buat file sementara untuk menampung argumen baru
    _temp_args_file=$(mktemp)
    
    # Pastikan file sementara dihapus saat skrip berakhir
    trap "rm -f ${_temp_args_file}" EXIT

    # Tambahkan argumen awal ke file sementara
    case "${PROGRAM}" in
    *cc) printf '%s\n%s\n' "cc" "--target=${ZIG_TARGET}" >> "${_temp_args_file}" ;;
    *c++) printf '%s\n%s\n' "c++" "--target=${ZIG_TARGET}" >> "${_temp_args_file}" ;;
    esac

    # Filter argumen yang masuk dan tulis ke file sementara
    while [ "$#" -gt 0 ]; do
        case "$1" in
        -Wp,-MD,*)
            printf '%s\n' "-MD" >> "${_temp_args_file}"
            printf '%s\n' "-MF" >> "${_temp_args_file}"
            printf '%s\n' "$(echo "$1" | sed 's/^-Wp,-MD,//')" >> "${_temp_args_file}"
            ;;
        -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
            # Abaikan flag ini
            ;;
        --target=*)
            if [ -n "${ZIG_TARGET}" ]; then
                # Abaikan --target jika ZIG_TARGET sudah disetel
                ;;
            else
                printf '%s\n' "$1" >> "${_temp_args_file}"
            fi
            ;;
        -mfloat-abi=hard)
            # Abaikan flag ini
            ;;
        *)
            printf '%s\n' "$1" >> "${_temp_args_file}"
            ;;
        esac
        shift
    done

    # Baca argumen dari file sementara ke daftar argumen baru ($@)
    # Ini memerlukan shell yang mendukung array (Bash) untuk membuat argumen secara robust.
    # Namun, karena workflow GitHub Actions menggunakan '/usr/bin/bash', ini harusnya OK.
    _new_args=()
    while IFS= read -r arg_line; do
        _new_args+=("$arg_line")
    done < "${_temp_args_file}"

    # Setel ulang argumen $@ dengan argumen yang sudah difilter
    set -- "${_new_args[@]}"

    exec ${ZIG_EXE} "${@}"
    ;;
*)
    if test -h "$0"; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac