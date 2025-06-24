#!/bin/sh
set -eu

PROGRAM="$(basename "$0")"
ZIG_EXE=zig

case "$PROGRAM" in
ar | *-ar) exec ${ZIG_EXE} ar "$@" ;;
dlltool | *-dlltool) exec ${ZIG_EXE} dlltool "$@" ;;
lib | *-lib) exec ${ZIG_EXE} lib "$@" ;;
ranlib | *-ranlib) exec ${ZIG_EXE} ranlib "$@" ;;
objcopy | *-objcopy) exec ${ZIG_EXE} objcopy "$@" ;;
ld.lld | *ld.lld | ld | *-ld) exec ${ZIG_EXE} ld.lld "$@" ;;
rc) exec ${ZIG_EXE} rc "$@" ;;
strip | *-strip)
    tmpfile="$1$(mktemp -d --dry-run .strip.XXXX)"
    ${ZIG_EXE} objcopy --strip-all "$1" "${tmpfile}"
    exec mv "${tmpfile}" "$1"
    ;;

*cc | *c++)
    # Deteksi target dari nama file jika belum ditentukan
    if [ -z "${ZIG_TARGET+x}" ]; then
        case "$PROGRAM" in
            armeabi-v7a-cc | armeabi-v7a-c++) ZIG_TARGET="arm-linux-android" ;;
            arm64-v8a-cc | arm64-v8a-c++) ZIG_TARGET="aarch64-linux-android" ;;
            cc | c++) ZIG_TARGET="$(uname -m)-linux-musl" ;;
            *) ZIG_TARGET="$(echo "$PROGRAM" | sed -E 's/(.+)(-cc|-c\+\+|-gcc|-g\+\+)/\1/')" ;;
        esac
    fi

    # Pilih perintah dasar Zig: cc atau c++
    case "$PROGRAM" in
        *cc) ZIG_CMD="cc" ;;
        *c++) ZIG_CMD="c++" ;;
    esac

    # Bangun ulang argumen dengan filter
    ARGS=""
    for arg in "$@"; do
        case "$arg" in
            -Wp,-MD,*)
                file=$(echo "$arg" | sed 's/^-Wp,-MD,//')
                ARGS="$ARGS -MD -MF \"$file\""
                ;;
            -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
                # skip
                ;;
            --target=*)
                # abaikan kalau ZIG_TARGET sudah dipakai
                ;;
            -mfloat-abi=hard)
                # drop this, Zig nggak terima
                ;;
            *)
                ARGS="$ARGS \"$arg\""
                ;;
        esac
    done

    # Jalankan Zig compiler dengan target
    eval "exec ${ZIG_EXE} ${ZIG_CMD} --target=${ZIG_TARGET} ${ARGS}"
    ;;
*)
    # Fallback kalau symlink
    if [ -h "$0" ]; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac