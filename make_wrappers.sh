#!/bin/sh
set -eu

ROOTDIR=$(dirname "$(realpath "$0")")

mkdir -p "${ROOTDIR}/bin"
if [ $# -gt 0 ]; then
    target="$1"
    while [ $# -gt 0 ]; do
        target="$1"
        shift

        for tool in ar c++ cc ld objcopy strip; do
            ln -snf ../zig_wrapper.sh "${ROOTDIR}/bin/${target}-${tool}"
        done
    done
else
    for tool in ar c++ cc dlltool ld.lld lib objcopy ranlib rc; do
        ln -snf ../zig_wrapper.sh "${ROOTDIR}/bin/${tool}"
    done
fi
