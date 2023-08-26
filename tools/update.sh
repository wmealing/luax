#!/bin/bash

set -e

TMP="$1"

update_all()
{
    update_lua          5.4.6
    update_lcomplex     100
    update_limath       104
    update_lqmath       105
    update_lmathx
    update_luasocket    3.1.0
    update_lpeg         1.1.0
    update_argparse     master
    update_inspect      master
    update_serpent      master
    update_lz4          release
}

update_lua()
{
    local LUA_VERSION="$1"
    local LUA_ARCHIVE="lua-$LUA_VERSION.tar.gz"
    local LUA_URL="https://www.lua.org/ftp/$LUA_ARCHIVE"

    mkdir -p "$TMP"
    wget "$LUA_URL" -O "$TMP/$LUA_ARCHIVE"

    rm -rf ext/lua
    mkdir -p ext/lua
    tar -xzf "$TMP/$LUA_ARCHIVE" -C ext/lua --exclude=Makefile --strip-components=2 "lua-$LUA_VERSION/src"
}

update_lcomplex()
{
    local LCOMPLEX_VERSION="$1"
    local LCOMPLEX_ARCHIVE="lcomplex-$LCOMPLEX_VERSION.tar.gz"
    local LCOMPLEX_URL="https://web.tecgraf.puc-rio.br/~lhf/ftp/lua/ar/$LCOMPLEX_ARCHIVE"

    mkdir -p "$TMP"
    wget "$LCOMPLEX_URL" -O "$TMP/$LCOMPLEX_ARCHIVE"

    rm -rf ext/lcomplex
    tar -xzf "$TMP/$LCOMPLEX_ARCHIVE" -C ext --exclude=Makefile --exclude=test.lua
    mv "ext/lcomplex-$LCOMPLEX_VERSION" ext/lcomplex
}

update_limath()
{
    local LIMATH_VERSION="$1"
    local LIMATH_ARCHIVE="limath-$LIMATH_VERSION.tar.gz"
    local LIMATH_URL="https://web.tecgraf.puc-rio.br/~lhf/ftp/lua/ar/$LIMATH_ARCHIVE"

    mkdir -p "$TMP"
    wget "$LIMATH_URL" -O "$TMP/$LIMATH_ARCHIVE"

    rm -rf ext/limath
    tar -xzf "$TMP/$LIMATH_ARCHIVE" -C ext --exclude=Makefile --exclude=test.lua
    mv "ext/limath-$LIMATH_VERSION" ext/limath
    sed -i 's@"imath.h"@"src/imath.h"@' ext/limath/limath.c
}

update_lqmath()
{
    local LQMATH_VERSION="$1"
    local LQMATH_ARCHIVE="lqmath-$LQMATH_VERSION.tar.gz"
    local LQMATH_URL="https://web.tecgraf.puc-rio.br/~lhf/ftp/lua/ar/$LQMATH_ARCHIVE"

    mkdir -p "$TMP"
    wget "$LQMATH_URL" -O "$TMP/$LQMATH_ARCHIVE"

    rm -rf ext/lqmath
    tar -xzf "$TMP/$LQMATH_ARCHIVE" -C ext --exclude=Makefile --exclude=test.lua
    mv "ext/lqmath-$LQMATH_VERSION" ext/lqmath
    sed -i 's@"imrat.h"@"src/imrat.h"@' ext/lqmath/lqmath.c
}

update_lmathx()
{
    local LMATHX_ARCHIVE=lmathx.tar.gz
    local LMATHX_URL="https://web.tecgraf.puc-rio.br/~lhf/ftp/lua/5.3/$LMATHX_ARCHIVE"

    mkdir -p "$TMP"
    wget "$LMATHX_URL" -O "$TMP/$LMATHX_ARCHIVE"

    rm -rf ext/mathx
    tar -xzf "$TMP/$LMATHX_ARCHIVE" -C ext --exclude=Makefile --exclude=test.lua
}

update_luasocket()
{
    local LUASOCKET_VERSION="$1"
    local LUASOCKET_ARCHIVE="luasocket-$LUASOCKET_VERSION.zip"
    local LUASOCKET_URL="https://github.com/lunarmodules/luasocket/archive/refs/tags/v$LUASOCKET_VERSION.zip"

    mkdir -p "$TMP"
    wget "$LUASOCKET_URL" -O "$TMP/$LUASOCKET_ARCHIVE"

    rm -rf ext/luasocket
    mkdir ext/luasocket
    unzip -j "$TMP/$LUASOCKET_ARCHIVE" "luasocket-$LUASOCKET_VERSION/src/*" -d ext/luasocket
    echo "--@LIB=socket.ftp"     >> ext/luasocket/ftp.lua
    echo "--@LIB=socket.headers" >> ext/luasocket/headers.lua
    echo "--@LIB=socket.http"    >> ext/luasocket/http.lua
    echo "--@LIB=socket.smtp"    >> ext/luasocket/smtp.lua
    echo "--@LIB=socket.tp"      >> ext/luasocket/tp.lua
    echo "--@LIB=socket.url"     >> ext/luasocket/url.lua
}

update_lpeg()
{
    local LPEG_VERSION="$1"
    local LPEG_ARCHIVE="lpeg-$LPEG_VERSION.tar.gz"
    local LPEG_URL="http://www.inf.puc-rio.br/~roberto/lpeg/$LPEG_ARCHIVE"

    mkdir -p "$TMP"
    wget "$LPEG_URL" -O "$TMP/$LPEG_ARCHIVE"

    rm -rf ext/lpeg
    tar xzf "$TMP/$LPEG_ARCHIVE" -C ext --exclude=HISTORY --exclude=*.gif --exclude=*.html --exclude=makefile --exclude=test.lua
    mv "ext/lpeg-$LPEG_VERSION" ext/lpeg
    echo "--@LIB" >> ext/lpeg/re.lua
}

update_argparse()
{
    local ARGPARSE_VERSION="$1"
    local ARGPARSE_ARCHIVE="argparse-$ARGPARSE_VERSION.zip"
    local ARGPARSE_URL="https://github.com/luarocks/argparse/archive/refs/heads/$ARGPARSE_VERSION.zip"

    mkdir -p "$TMP"
    wget "$ARGPARSE_URL" -O "$TMP/$ARGPARSE_ARCHIVE"

    rm -f ext/argparse/argparse.lua
    unzip -j -o "$TMP/$ARGPARSE_ARCHIVE" '*/argparse.lua' -d ext/argparse
}

update_inspect()
{
    local INSPECT_VERSION="$1"
    local INSPECT_ARCHIVE="inspect-$INSPECT_VERSION.zip"
    local INSPECT_URL="https://github.com/kikito/inspect.lua/archive/refs/heads/$INSPECT_VERSION.zip"

    mkdir -p "$TMP"
    wget "$INSPECT_URL" -O "$TMP/$INSPECT_ARCHIVE"

    rm -f ext/inspect/inspect.lua
    unzip -j "$TMP/$INSPECT_ARCHIVE" '*/inspect.lua' -d ext/inspect
    echo "--@LIB" >> ext/inspect/inspect.lua
}

update_serpent()
{
    local SERPENT_VERSION="$1"
    local SERPENT_ARCHIVE="serpent-$SERPENT_VERSION.zip"
    local SERPENT_URL="https://github.com/pkulchenko/serpent/archive/refs/heads/$SERPENT_VERSION.zip"

    mkdir -p "$TMP"
    wget "$SERPENT_URL" -O "$TMP/$SERPENT_ARCHIVE"

    rm -f ext/serpent/serpent.lua
    unzip -j "$TMP/$SERPENT_ARCHIVE" '*/serpent.lua' -d ext/serpent
    sed -i -e 's/(loadstring or load)/load/g'                   \
           -e '/^ *if setfenv then setfenv(f, env) end *$$/d'   \
           ext/serpent/serpent.lua
    echo "--@LIB" >> ext/serpent/serpent.lua
}

update_lz4()
{
    local LZ4_VERSION="$1"
    local LZ4_ARCHIVE="lz4-$LZ4_VERSION.zip"
    local LZ4_URL="https://github.com/lz4/lz4/archive/refs/heads/$LZ4_VERSION.zip"

    mkdir -p "$TMP"
    wget "$LZ4_URL" -O "$TMP/$LZ4_ARCHIVE"

    rm -rf ext/lz4
    mkdir ext/lz4
    unzip -j "$TMP/$LZ4_ARCHIVE" '*/lib/*.[ch]' '*/lib/LICENSE' -d ext/lz4
}

update_all
