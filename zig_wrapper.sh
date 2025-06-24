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
        # Tambahan eksplisit untuk target Android yang umum.
        # Catatan: `armv7a` diganti dengan `arm` karena `armv7a` tidak dikenali langsung oleh Zig sebagai arsitektur.
        armeabi-v7a-cc | armeabi-v7a-c++) ZIG_TARGET="arm-linux-android" ;;
        arm64-v8a-cc | arm64-v8a-c++) ZIG_TARGET="aarch64-linux-android" ;;
		*) ZIG_TARGET=$(echo "${PROGRAM}" | sed -E 's/(.+)(-cc|-c\+\+|-gcc|-g\+\+)/\1/') ;;
		esac
	fi

	case "${PROGRAM}" in
	*cc) set -- cc --target="${ZIG_TARGET}" "$@" ;;
	*c++) set -- c++ --target="${ZIG_TARGET}" "$@" ;;
	esac

	## Zig doesn't properly handle these flags so we have to rewrite/ignore.
	## None of these affect the actual compilation target.
	## https://github.com/ziglang/zig/issues/9948

    # Simpan argumen asli sebelum memodifikasinya
    original_args=("$@")
    # Reset argumen untuk membangun kembali yang baru
    set --

	for argv in "${original_args[@]}"; do
		case "${argv}" in
		-Wp,-MD,*) set -- "$@" "-MD" "-MF" "$(echo "${argv}" | sed 's/^-Wp,-MD,//')" ;;
		-Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*) ;;
		--target=aarch64-unknown-linux-musl) ;; # Abaikan jika sudah disetel secara eksplisit
        -mfloat-abi=hard) ;; # <-- Tambahan untuk mengabaikan flag ini
		*) set -- "$@" "${argv}" ;;
		esac
	done

	exec ${ZIG_EXE} "${@}"
	;;
*)
	if test -h "$0"; then
		exec "$(dirname "$0")/$(readlink "$0")" "$@"
	fi
	;;
esac