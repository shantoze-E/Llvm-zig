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

    
    _current_args=()
    case "${PROGRAM}" in
    *cc) _current_args=("cc" "--target=${ZIG_TARGET}") ;;
    *c++) _current_args=("c++" "--target=${ZIG_TARGET}") ;;
    esac

    
    _filtered_args_file=$(mktemp)

    while [ "$#" -gt 0 ]; do
        case "$1" in
        -Wp,-MD,*)
            printf '%s\n' "-MD" >> "${_filtered_args_file}"
            printf '%s\n' "-MF" >> "${_filtered_args_file}"
            printf '%s\n' "$(echo "$1" | sed 's/^-Wp,-MD,//')" >> "${_filtered_args_file}"
            ;;
        -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
            
            ;;
        --target=*)
            # Abaikan --target jika kita sudah memiliki ZIG_TARGET yang disetel
            if [ -n "${ZIG_TARGET}" ]; then
                
                ;;
            else
                printf '%s\n' "$1" >> "${_filtered_args_file}"
            fi
            ;;
        -mfloat-abi=hard)
            
            ;;
        *)
            printf '%s\n' "$1" >> "${_filtered_args_file}"
            ;;
        esac
        shift # Pindah ke argumen berikutnya
    done

    
    while IFS= read -r arg; do
        _current_args+=("$arg")
    done < "${_filtered_args_file}"

    
    rm -f "${_filtered_args_file}"

    
    set -- "${_current_args[@]}"

    exec ${ZIG_EXE} "${@}"
    ;;
*)
    if test -h "$0"; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac