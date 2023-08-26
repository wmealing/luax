#!/bin/bash

set -e

ZIG_VERSION="0.11.0"
ZIG="$1"

OS=$(tools/os.sh)
ARCH=$(tools/arch.sh)

ZIG_ARCHIVE="zig-$OS-$ARCH-$ZIG_VERSION.tar.xz"
ZIG_URL="https://ziglang.org/download/$ZIG_VERSION/$ZIG_ARCHIVE"

mkdir -p "$(dirname "$ZIG")"
wget "$ZIG_URL" -O "$(dirname "$ZIG")/$ZIG_ARCHIVE"

tar xJf "$(dirname "$ZIG")/$ZIG_ARCHIVE" -C "$(dirname "$ZIG")" --strip-components 1
touch "$ZIG"
