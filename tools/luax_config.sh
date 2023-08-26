#!/bin/bash

set -e

FILE_H="$1"
FILE_LUA="$2"
MAGIC_ID="$3"
CRYPT_KEY="$4"
TARGETS="$5"

VERSION=$(git describe --tags || echo undefined)
DATE=$(git show -s --format=%cd --date=format:'%Y-%m-%d' || echo undefined)

cat <<EOF > "$FILE_H.tmp"
#pragma once
#define LUAX_VERSION "$VERSION"
#define LUAX_DATE "$DATE"
#define LUAX_CRYPT_KEY "$CRYPT_KEY"
#define LUAX_MAGIC_ID "$MAGIC_ID"
EOF

cat <<EOF > "$FILE_LUA.tmp"
--@LIB
return {
    magic_id = "$MAGIC_ID",
    targets = $TARGETS,"
}
EOF

mv "$FILE_H.tmp" "$FILE_H"
mv "$FILE_LUA.tmp" "$FILE_LUA"
