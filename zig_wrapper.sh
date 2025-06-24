#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

case "${PROGRAM}" in
ar | *-ar)
    exec ${ZIG_EXE} ar "$@"
    ;;
dlltool | *-dlltool)
    exec ${ZIG_EXE} dlltool "$@"
    ;;
lib | *-lib)
    exec ${ZIG_EXE} lib "$@"
    ;;
ranlib | *-ranlib)
    exec ${ZIG_EXE} ranlib "$@"
    ;;
objcopy | *-objcopy)
    exec ${ZIG_EXE} objcopy "$@"
    ;;
ld.lld | *ld.lld | ld | *-ld)
    exec ${ZIG_EXE} ld.lld "$@"
    ;;
rc)
    exec ${ZIG_EXE} rc "$@"
    ;;
strip | *-strip)
    tmpfile="$1$(mktemp -d --dry-run .strip.XXXX)"
    ${ZIG_EXE} objcopy --strip-all "$1" "${tmpfile}"
    exec mv "${tmpfile}" "$1"
    ;;
*cc | *c++)
    # Tentukan target berdasarkan nama program jika belum diset secara eksplisit
    if [ -z "${ZIG_TARGET+x}" ]; then
        case "${PROGRAM}" in
        cc | c++) ZIG_TARGET="$(uname -m)-linux-musl" ;;
        armeabi-v7a-cc | armeabi-v7a-c++) ZIG_TARGET="arm-linux-android" ;;
        arm64-v8a-cc | arm64-v8a-c++) ZIG_TARGET="aarch64-linux-android" ;;
        *) ZIG_TARGET="$(echo "${PROGRAM}" | sed -E 's/(.+)(-cc|-c\+\+|-gcc|-g\+\+)/\1/')" ;;
        esac
    fi

    # Bangun argumen dasar berdasarkan program
    case "${PROGRAM}" in
    *cc) ZIG_CMD="cc" ;;
    *c++) ZIG_CMD="c++" ;;
    esac

    # Proses semua argumen masuk
    NEW_ARGS=""
    for ARG in "$@"; do
        case "$ARG" in
        -Wp,-MD,*)
            # Ubah -Wp,-MD,file menjadi -MD -MF file
            FILE=$(echo "$ARG" | sed 's/^-Wp,-MD,//')
            NEW_ARGS="$NEW_ARGS -MD -MF \"$FILE\""
            ;;
        -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
            # Abaikan flag linker yang tidak kompatibel
            ;;
        --target=*)
            # Abaikan --target jika ZIG_TARGET sudah ditentukan
            ;;
        -mfloat-abi=hard)
            # Abaikan flag ini karena Zig bisa tidak mendukungnya
            ;;
        *)
            NEW_ARGS="$NEW_ARGS \"$ARG\""
            ;;
        esac
    done

    # Eksekusi dengan Zig
    eval "exec ${ZIG_EXE} ${ZIG_CMD} --target=${ZIG_TARGET} ${NEW_ARGS}"
    ;;
*)
    # Fallback: jalankan symlink yang menunjuk ke sesuatu
    if [ -h "$0" ]; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac