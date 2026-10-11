#!/usr/bin/env bash
# Builds the tiny local "apps" every probe uses. No network. Output: $1 (default ./_fx)
# libA/exdep    : mix-built Elixir app (module Elixir.ExDep, app name exdep, .app with modules list)
# libA/erldep   : erlc-built Erlang app (module erldep, hand-written .app)
# libA/bareapp  : an app dir whose .app has `modules` = [] (hand-written) but beam present
# libA/modless  : ebin with .app listing a module whose beam is absent
# libB          : empty ERL_LIBS root (the "different machine")
# orphan/ebin   : a loose beam (module orphanmod) in NO application
# noapp/mixedlib/ebin : beam but no .app file (lib_dir sees the dir? measured in p2)
set -e
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
FX="${1:-$HERE/_fx}"
rm -rf "$FX"; mkdir -p "$FX"
# --- Elixir app via mix
mkdir -p "$FX/src" && cp -r "$HERE/exdep" "$FX/src/exdep"
( cd "$FX/src/exdep" && MIX_ENV=prod mix compile >/dev/null 2>&1 )
mkdir -p "$FX/libA/exdep"
cp -r "$FX/src/exdep/_build/prod/lib/exdep/ebin" "$FX/libA/exdep/ebin"
# --- Erlang app via erlc
mkdir -p "$FX/libA/erldep/ebin"
erlc -o "$FX/libA/erldep/ebin" "$HERE/erldep.erl"
cat > "$FX/libA/erldep/ebin/erldep.app" <<'APP'
{application,erldep,[{description,"erldep"},{vsn,"1.2.3"},{modules,[erldep]},{registered,[]},{applications,[kernel,stdlib]}]}.
APP
# --- app with empty modules key but beam present
mkdir -p "$FX/libA/bareapp/ebin"
erlc -o "$FX/libA/bareapp/ebin" "$HERE/bareapp.erl"
cat > "$FX/libA/bareapp/ebin/bareapp.app" <<'APP'
{application,bareapp,[{description,"bareapp"},{vsn,"0.0.1"},{modules,[]},{registered,[]},{applications,[kernel,stdlib]}]}.
APP
# --- app whose .app lists a module whose beam is absent
mkdir -p "$FX/libA/ghostapp/ebin"
cat > "$FX/libA/ghostapp/ebin/ghostapp.app" <<'APP'
{application,ghostapp,[{description,"ghostapp"},{vsn,"0.0.1"},{modules,[ghostmod]},{registered,[]},{applications,[kernel,stdlib]}]}.
APP
# --- empty ERL_LIBS root
mkdir -p "$FX/libB"
# --- orphan beam, no app anywhere
mkdir -p "$FX/orphan/ebin"
erlc -o "$FX/orphan/ebin" "$HERE/orphanmod.erl"
# --- directory shaped like an app (name-version/ebin) but with NO .app file
mkdir -p "$FX/libA/noappfile/ebin"
erlc -o "$FX/libA/noappfile/ebin" "$HERE/noappmod.erl"
echo "fixtures built in $FX"
# --- dir name != app name: libA/dirname_mismatch/ebin holds app `realname`
mkdir -p "$FX/libA/dirname_mismatch/ebin"
erlc -o "$FX/libA/dirname_mismatch/ebin" "$HERE/realname.erl"
cat > "$FX/libA/dirname_mismatch/ebin/realname.app" <<'APP'
{application,realname,[{description,"realname"},{vsn,"0.0.1"},{modules,[realname]},{registered,[]},{applications,[kernel,stdlib]}]}.
APP
echo "extra fixtures built"
