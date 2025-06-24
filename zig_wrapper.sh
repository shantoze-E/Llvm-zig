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

    case "${PROGRAM}" in
    *cc) set -- cc --target="${ZIG_TARGET}" "$@" ;;
    *c++) set -- c++ --target="${ZIG_TARGET}" "$@" ;;
    esac

    # Filter arguments in a POSIX-compliant way
    # Save original arguments
    _original_args_count=$#
    _original_args_idx=1
    _new_args=""

    while [ "$_original_args_count" -gt 0 ]; do
        eval "current_arg=\"\$$((_original_args_idx))\"" # Get current argument safely

        case "${current_arg}" in
        -Wp,-MD,*)
            _new_args="${_new_args} -MD -MF $(echo "${current_arg}" | sed 's/^-Wp,-MD,//')"
            ;;
        -Wl,--warn-common | -Wl,--verbose | -Wl,-Map,*)
            # Ignore these flags
            ;;
        --target=*)
            # Only ignore if the target matches the one we already set/intend to use
            # This is to prevent conflicts if CMake tries to override the target
            # For simplicity, we'll generally ignore explicit --target if ZIG_TARGET is set
            if [ -n "${ZIG_TARGET}" ] && echo "${current_arg}" | grep -q -- "--target=${ZIG_TARGET}"; then
                # Ignore this specific target flag if it matches our ZIG_TARGET
                ;;
            # If it's a different --target, we might want to keep it or handle it differently
            # For now, let's just assume we want to ignore *any* explicit --target if we are managing ZIG_TARGET
            elif [ -n "${ZIG_TARGET}" ]; then
                ;; # Ignore any --target if we're explicitly setting ZIG_TARGET
            else
                _new_args="${_new_args} \"${current_arg}\""
            fi
            ;;
        -mfloat-abi=hard)
            # Ignore this flag
            ;;
        *)
            _new_args="${_new_args} \"${current_arg}\""
            ;;
        esac

        _original_args_idx=$((_original_args_idx + 1))
        _original_args_count=$((_original_args_count - 1))
    done

    # Set the filtered arguments back to $@
    # Use eval to handle quoted arguments correctly
    eval "set -- $_new_args"

    exec ${ZIG_EXE} "${@}"
    ;;
*)
    if test -h "$0"; then
        exec "$(dirname "$0")/$(readlink "$0")" "$@"
    fi
    ;;
esac