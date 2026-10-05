#!/usr/bin/env bash
# Builds every fixture from scratch. No claim; later probes depend on it.
# REFUTED IF: a fixture fails to build (every later probe then says so).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
rm -rf "$WORK"; mkdir -p "$WORK/mixlib" "$WORK/erllibs/plainerl-1.2.0/ebin" "$WORK/erllibs/ghost-1.0.0/ebin" "$WORK/loose"
cp -r "$ROOT/fixtures/mylib" "$WORK/mixlib/mylib"
( cd "$WORK/mixlib/mylib" && mix compile 2>&1 | tail -3 )
echo "--- mix-built app layout (the shape ERL_LIBS means):"
( cd "$MYLIBS" && find . -maxdepth 3 -name '*.app' -o -maxdepth 3 -name 'Elixir.MyLib*.beam' | sort )
erlc -o "$WORK/erllibs/plainerl-1.2.0/ebin" "$ROOT/fixtures/erl/plainerl.erl"
cat > "$WORK/erllibs/plainerl-1.2.0/ebin/plainerl.app" <<'APP'
{application,plainerl,[{description,"plain"},{vsn,"1.2.0"},{modules,[plainerl]},{registered,[]},{applications,[kernel,stdlib]}]}.
APP
# An application only loadable via its .app file: the .app exists, no beam does.
cat > "$WORK/erllibs/ghost-1.0.0/ebin/ghost.app" <<'APP'
{application,ghost,[{description,"app file only"},{vsn,"1.0.0"},{modules,[ghost_mod]},{registered,[]},{applications,[kernel,stdlib]}]}.
APP
# A beam with no application around it, reachable only through -pa.
erlc -o "$WORK/loose" "$ROOT/fixtures/erl/loosemod.erl"
echo "--- erllibs:"; ( cd "$ERLLIBS" && find . -type f | sort )
