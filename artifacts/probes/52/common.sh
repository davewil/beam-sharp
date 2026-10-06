# sourced by every probe. Never run from inside compiler/ (a stray C.beam shadows stdlib's c).
ENVSH=/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
source "$ENVSH"
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
PROBES="$ROOT/artifacts/probes/52"
cd "$ROOT"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
FAILS=0
# expect <label> <expected-substring> <actual>   -> prints ok/!! ; a probe that cannot fail is not a probe
expect () { if printf '%s' "$3" | grep -qF -- "$2"; then echo "ok  $1"; else echo "!!  $1   (wanted: $2)"; echo "    got: $3"; FAILS=$((FAILS+1)); fi; }
expect_empty () { if [ -z "$2" ]; then echo "ok  $1"; else echo "!!  $1   (wanted empty output)"; echo "    got: $2"; FAILS=$((FAILS+1)); fi; }
# beams_equal <a.beam> <b.beam>: beam_lib:cmp ignores the compile_info chunk (which embeds the -o path)
beams_equal () { erl -noshell -eval 'R=beam_lib:cmp(hd(init:get_plain_arguments()), hd(tl(init:get_plain_arguments()))), io:format("~p~n",[R]), halt().' -extra "$1" "$2"; }
expect_not () { if printf '%s' "$3" | grep -qF -- "$2"; then echo "!!  $1   (must NOT contain: $2)"; echo "    got: $3"; FAILS=$((FAILS+1)); else echo "ok  $1"; fi; }
# fixture: an OTP application `fakelib` (module fakelib_mod:hello/0 -> 42) under $WORK/libs, as ERL_LIBS expects it
mk_fakelib () {
  mkdir -p "$WORK/libs/fakelib-1.0/ebin" "$WORK/erl"
  cat > "$WORK/erl/fakelib_mod.erl" <<'EOT'
-module(fakelib_mod).
-export([hello/0]).
hello() -> 42.
EOT
  erlc -o "$WORK/libs/fakelib-1.0/ebin" "$WORK/erl/fakelib_mod.erl"
  cat > "$WORK/libs/fakelib-1.0/ebin/fakelib.app" <<'EOT'
{application,fakelib,[{description,"x"},{vsn,"1.0"},{modules,[fakelib_mod]},{registered,[]},{applications,[kernel,stdlib]}]}.
EOT
}
# bs_module <name> <body...>: writes $WORK/src/<name>/<name>.bs (one directory = one module)
bs_module () { local n=$1; shift; mkdir -p "$WORK/src/$n"; printf 'module %s\n%s\n' "$n" "$*" > "$WORK/src/$n/$n.bs"; }
finish () { echo; if [ "$FAILS" = 0 ]; then echo "ALL CLAIMS HELD"; else echo "$FAILS CLAIM(S) FAILED"; exit 1; fi; }
