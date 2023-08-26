#!/usr/bin/env luax

local fs = require "fs"
local F = require "F"
local sh = require "sh"

local function parse_args()
    local parser = require "argparse"()
        : name "LuaX Ninja file generator"
    parser : option "-k"
        : description "LuaX crypt key"
        : argname "key"
        : target "crypt_key"
    parser : flag "-u"
        : description "Update third-party dependencies"
        : target "update_modules"
    return F.merge {
        { crypt_key = "LuaX" },
        parser:parse(arg),
    }
end

local args = parse_args()

var "builddir" ".build_with_ninja"
F"bin lib tmp test doc":words():foreach(function(d)
    var(d)(fs.join(vars.builddir, d))
end)

var "zig"       (fs.join(vars.builddir, "zig", "zig"))

local targets = F{
    -- Linux
    "x86_64-linux-musl",
    "x86_64-linux-gnu",
    "x86-linux-musl",
    "x86-linux-gnu",
    "aarch64-linux-musl",
    "aarch64-linux-gnu",

    -- Windows
    "x86_64-windows-gnu",
    "x86-windows-gnu",

    -- MacOS
    "x86_64-macos-none",
    "aarch64-macos-none",
}

var "cflags" {
    "-std=gnu2x",
    "-O3",
    "-fPIC",
    "-I.",
    "-Isrc",
    "-Iext/lua",
}

var "ldflags" {
    --"-fPIC",
}

var "cflags-luax" {
    "-Werror",
    "-Wall",
    "-Wextra",
    "-Weverything",
    "-Wno-padded",
    --"-Wno-reserved-identifier",
    "-Wno-reserved-macro-identifier",
    "-Wno-disabled-macro-expansion",
    "-Wno-used-but-marked-unused",
    --"-Wno-documentation",
    "-Wno-documentation-unknown-command",
    "-Wno-declaration-after-statement",
    "-Wno-unsafe-buffer-usage",
}

var "cflags-ext" {
    "-Werror",
    --"-Wall",
    --"-Wno-padded",
    --"-Wno-reserved-identifier",
    --"-Wno-disabled-macro-expansion",
    --"-Wno-used-but-marked-unused",
    --"-Wno-documentation",
    --"-Wno-documentation-unknown-command",
    --"-Wno-declaration-after-statement",
    --"-Wno-unsafe-buffer-usage",
    --"-Wno-unused-but-set-variable",
    "-Wno-constant-logical-operand",
    "-Wno-#warnings",
}

var "ldflags-luax" {
    "-Wl,--strip-all",
}

local compile = {}
local test = {}
local doc = {}

---------------------------------------------------------------------
-- Zig compiler
---------------------------------------------------------------------

section "Zig compiler"

rule "install_zig" {
    command = "tools/install_zig.sh $out",
}

build "$zig" { "install_zig",
    implicit_in = "tools/install_zig.sh",
}

---------------------------------------------------------------------
-- Dependencies
---------------------------------------------------------------------

if args.update_modules then
    assert(sh.run("tools/update.sh", vars.tmp))
end

---------------------------------------------------------------------
-- LuaX configuration
---------------------------------------------------------------------

local function hash(key)
    local crypt = require "crypt"
    local function h(s) return crypt.sha1(s)..crypt.hash(s) end
    return h(key) : gsub("..", "\\x%0")
end

local magic_id = "LuaX"

local luax_config_table = F.I {
    VERSION = sh.read "git describe --tags" : trim(),                               ---@diagnostic disable-line: undefined-field
    DATE = sh.read "git show -s --format=%cd --date=format:'%Y-%m-%d'" : trim(),    ---@diagnostic disable-line: undefined-field
    CRYPT_KEY = hash(args.crypt_key),
    MAGIC_ID = magic_id,
    TARGETS = targets:show(),
}

file "src/luax_config.h"
: write(luax_config_table[[
#pragma once
#define LUAX_VERSION "$(VERSION)"
#define LUAX_DATE "$(DATE)"
#define LUAX_CRYPT_KEY "$(CRYPT_KEY)"
#define LUAX_MAGIC_ID "$(MAGIC_ID)"
]])

file "src/luax_config.lua"
: write(luax_config_table[[
--@LIB
return {
    magic_id = "$(MAGIC_ID)",
    targets = $(TARGETS),
}
]])

---------------------------------------------------------------------
-- Native Lua interpreter
---------------------------------------------------------------------

section "Native Lua interpreter"

var "cflags-native" {
    "-DLUAX_ARCH='\"undefined\"'",
    "-DLUAX_OS='\"undefined\"'",
    "-DLUAX_ABI='\"undefined\"'",
}

var "ldflags-native" {
}

rule "cc-native" {
    command = "$zig cc -c $cflags $cflags-ext $cflags-native -MD -MF $out.d $in -o $out",
    depfile = "$out.d",
}

rule "cc-luax-native" {
    command = "$zig cc -c $cflags $cflags-luax $cflags-native -MD -MF $out.d $in -o $out",
    depfile = "$out.d",
}

rule "ar-native" {
    command = "$zig ar -crs $out $in",
}

rule "ld-native" {
    command = "$zig cc $ldflags $ldflags-native $in -o $out",
}

rule "ld-luax-native" {
    command = "$zig cc $ldflags $ldflags-luax $ldflags-native $in -o $out",
}

local lua_main_c_files = F{"ext/lua/lua.c"}

local lua_c_files = ls "ext/lua/*.c"
    : difference(lua_main_c_files)
    : filter(function(source) return not fs.basename(source) : match "^luac?%.c$" end)

do
    local objects = (lua_c_files .. lua_main_c_files)
        : map(function(source)
            local object = fs.join("$tmp/native", fs.splitext(source)..".o")
            build(object) { "cc-native", source, implicit_in="$zig" }
            return object
        end)
    build "$tmp/lua" { "ld-native", objects, implicit_in="$zig" }
end

---------------------------------------------------------------------
-- Native LuaX0 interpreter (C runtime only)
---------------------------------------------------------------------

section "Native LuaX0 interpreter (C runtime only)"

var "cflags-luax0" {
    "-DRUNTIME=0",
}

rule "cc-luax0-native" {
    command = "$zig cc -c $cflags $cflags-luax $cflags-luax0 $cflags-native -MD -MF $out.d $in -o $out",
    depfile = "$out.d",
}


local luax_main_c_files = F{"src/main.c"}

local luax_c_files = ls "src/**.c" : difference(luax_main_c_files)

local luax_ext_linux_c_files = F{
    "ext/luasocket/serial.c",
    "ext/luasocket/unixdgram.c",
    "ext/luasocket/unixstream.c",
    "ext/luasocket/usocket.c",
    "ext/luasocket/unix.c",
}

local luax_ext_windows_c_files = F{
    "ext/luasocket/wsocket.c",
}

local luax_ext_c_files = ls "ext/**.c"
    : filter(function(name) return not name:match "^ext/lua/" end)
    : difference{"ext/lqmath/src/imath.c"}
    : difference(luax_ext_linux_c_files)
    : difference(luax_ext_windows_c_files)

do
    local lua_objects = lua_c_files
        : map(function(source)
            local object = fs.join("$tmp/native", fs.splitext(source)..".o")
            -- already compiled for lua
            return object
        end)
    local luax_objects = (luax_c_files .. luax_main_c_files)
        : map(function(source)
            local object = fs.join("$tmp/native", fs.splitext(source)..".o")
            build(object) { "cc-luax0-native", source, implicit_in="$zig src/luax_config.h" }
            return object
        end)
    local ext_objects = (luax_ext_c_files .. luax_ext_linux_c_files)
        : map(function(source)
            local object = fs.join("$tmp/native", fs.splitext(source)..".o")
            build(object) { "cc-native", source, implicit_in="$zig" }
            return object
        end)
    build "$tmp/luax0" { "ld-native", lua_objects, luax_objects, ext_objects }
end

---------------------------------------------------------------------
-- Lua runtime
---------------------------------------------------------------------

local luax_runtime = ls "src/**.lua" .. ls "ext/**.lua"

rule "bundle_runtime" {
    command = {
        "LUA_PATH=src/?.lua",
        "$tmp/luax0 tools/bundle.lua -lib -ascii $in > $out.tmp && mv $out.tmp $out"
    },
}

build "$tmp/lua_runtime_bundle.dat" { "bundle_runtime", "src/luax_config.lua", luax_runtime,
    implicit_in = {
        "tools/bundle.lua",
        "$tmp/luax0",
    },
}

---------------------------------------------------------------------
-- LuaX runtimes (one per interpreter)
---------------------------------------------------------------------

;(targets..{"host"}) : foreach(function(target)

    section("LuaX runtime for "..target)

    local ARCH, OS, ABI = target:split"%-":unpack()

    local dynamic = ABI ~= "musl"

    var("cflags-luax1-"..target) {
        OS ~= "macos" and "-flto" or {},
        "-DRUNTIME=1",
        "-I"..vars.tmp,
        F"-DLUAX_ARCH='\"%s\"'":format(ARCH),
        F"-DLUAX_OS='\"%s\"'":format(OS),
        F"-DLUAX_ABI='\"%s\"'":format(ABI),
        F"-DLUA_LIB",
    }
    var("cflags-lua-"..target) {
        OS ~= "macos" and "-flto" or {},
        OS == "linux" and "-DLUA_USE_LINUX" or {},
        OS == "macos" and "-DLUA_USE_MACOSX" or {},
    }

    var("ldflags-"..target) {
        OS ~= "macos" and "-flto" or {},
    }

    local target_flag = ARCH ~= "host" and {"-target", target} or {}

    rule("cc-lua-"..target) {
        command = {"$zig cc -c", target_flag, "$cflags $cflags-ext $cflags-lua $cflags-lua-"..target.." -MD -MF $out.d $in -o $out"},
        depfile = "$out.d",
    }

    rule("cc-luax-"..target) {
        command = {"$zig cc -c", target_flag, "$cflags $cflags-luax $cflags-luax1-"..target.." -MD -MF $out.d $in -o $out"},
        depfile = "$out.d",
    }

    local oslibs = OS=="windows" and {"-lws2_32"} or {}

    rule("ld-"..target) {
        command = {"$zig cc", target_flag, "$ldflags $ldflags-luax $ldflags-"..target, "$in -o $out", oslibs},
    }

    local shared_ext = ({linux=".so", macos=".dylib", windows=".dll"})[OS]

    if dynamic and shared_ext then
        rule("ld-shared-"..target) {
            command = {"$zig cc -shared", target_flag, "$ldflags $ldflags-luax $ldflags-"..target, "$in -o $out", oslibs},
        }
    end

    local lua_objects = lua_c_files
        : map(function(source)
            local object = fs.join("$tmp", target, fs.splitext(source)..".o")
            build(object) { "cc-lua-"..target, source, implicit_in="$zig" }
            return object
        end)
    local luax_objects = (luax_c_files .. luax_main_c_files)
        : map(function(source)
            local object = fs.join("$tmp", target, fs.splitext(source)..".o")
            build(object) { "cc-luax-"..target, source,
                implicit_in = {
                    "$zig",
                    "src/luax_config.h",
                    fs.basename(source) == "libluax.c" and "$tmp/lua_runtime_bundle.dat" or {},
                }
            }
            return object
        end)
    local ext_objects = (luax_ext_c_files .. (OS=="windows" and luax_ext_windows_c_files or luax_ext_linux_c_files))
        : map(function(source)
            local object = fs.join("$tmp", target, fs.splitext(source)..".o")
            build(object) { "cc-lua-"..target, source, implicit_in="$zig" }
            return object
        end)
    build("$tmp/luaxruntime-"..target) { "ld-"..target,
        lua_objects,
        luax_objects,
        ext_objects,
    }
    if dynamic and shared_ext then
        build("$lib/libluax-"..target..shared_ext) { "ld-shared-"..target,
            lua_objects,
            luax_objects:filter(function(name) return fs.basename(name) ~= "main.o" end),
            ext_objects,
        }
        compile[#compile+1] = "$lib/libluax-"..target..shared_ext
    end

end)

---------------------------------------------------------------------
-- LuaX interpreters (one per interpreter)
---------------------------------------------------------------------

section "LuaX bundle"

local luax_packages = ls "tools/*.lua"

;(targets..{"host"}) : foreach(function(target)

    section("LuaX interpreter for "..target)

    rule("bundle_luax-"..target) {
        command = {
            "cp $tmp/luaxruntime-"..target, "$out.tmp",
            "&&",
            "LUA_PATH=src/?.lua",
            "$tmp/luax0 tools/bundle.lua -binary $in >> $out.tmp",
            "&&",
            "mv $out.tmp $out"
        },
    }

    local final_name = target == "host" and "$tmp/luax" or ("$bin/luax-"..target)

    build(final_name) { "bundle_luax-"..target, "src/luax_config.lua", luax_packages,
        implicit_in = {"$tmp/luaxruntime-"..target},
    }

    compile[#compile+1] = final_name

end)

---------------------------------------------------------------------
-- Phony rules
---------------------------------------------------------------------

section "Shortcuts"

phony "compile" (compile)
phony "test" (test)
phony "doc" (doc)

default "compile"
