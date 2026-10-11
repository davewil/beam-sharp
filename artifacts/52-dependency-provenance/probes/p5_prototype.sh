#!/usr/bin/env bash
# The three options, run through a PROTOTYPE bsc (../prototype: a patched COPY of compiler/src).
#   A: [external: K, app: App] using :M { .. }      per block
#   B: [app: A, app: B] module M                    once per module
#   C: nothing in the source; project file lists deps (modelled by bsc's module-only warning)
# Run: ./p5_prototype.sh
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
[ -d "$H/fixtures/_proto/ebin" ] || "$H/../prototype/build.sh" >/dev/null
ELIXLIB=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/mm/root/envs/tc/lib/elixir/lib
export BSC_EBIN="$H/fixtures/_proto/ebin"
run() { # label libs dir fn arg
  L="${2//$FX/FX}"; L="${L//$ELIXLIB/ELIXIR_LIB}"
  echo "--- [$1] ERL_LIBS=$L  bsc bs/$3 ${4:-}"
  ERL_LIBS="$2" "$H/bsc.sh" --src-root "$H/bs" "$H/bs/$3" $4 $5 2>&1 | sed "s#$FX#FX#g; s#$ELIXLIB#ELIXIR_LIB#g; s/^/    /"; echo "    exit=${PIPESTATUS[0]}"
}
M1="$FX/libA:$ELIXLIB"; M2="$FX/libB:$ELIXLIB"
echo "######## C: no declaration (today's source + the module-only warning)"
run C-machine1 "$M1" Dep ViaExDep '<<"hi">>'
run C-machine2 "$M2" Dep ViaExDep '<<"hi">>'
echo; echo "######## A: per-using declaration"
run A-machine1 "$M1" DeclA ViaExDep '<<"hi">>'
run A-machine2 "$M2" DeclA ViaExDep '<<"hi">>'
run A-machine2-pure-fn "$M2" DeclA Pure 41
run A-wrong-app-name "$M1" WrongApp ViaExDep '<<"hi">>'
run A-wrong-owner "$M1" WrongOwner ViaExDep '<<"hi">>'
run A-wrong-kind "$M1" WrongKind Up '<<"hi">>'
echo; echo "######## B: once per module"
run B-machine1 "$M1" DeclB ViaExDep '<<"hi">>'
run B-machine2 "$M2" DeclB ViaExDep '<<"hi">>'
echo "-- B with a using whose app the module forgot to list (negative control for B: must be refused)"
mkdir -p "$H/bs/DeclBforgot"; sed 's/DeclB/DeclBforgot/; s/\[app: exdep, app: erldep, app: elixir\]/[app: erldep, app: elixir]/' "$H/bs/DeclB/declb.bs" > "$H/bs/DeclBforgot/declbforgot.bs"
run B-forgot-exdep "$M1" DeclBforgot ViaErl 21
echo; echo "######## what lands in the beam (A and B both write one deduped attribute)"
for m in DeclA DeclB; do
  ERL_LIBS="$M1" "$H/bsc.sh" -o "$FX/proto-$m" --src-root "$H/bs" "$H/bs/$m" >/dev/null 2>&1
  B="$FX/proto-$m/$m.beam" erl -noshell -eval '{ok,{_,[{attributes,A}]}}=beam_lib:chunks(os:getenv("B"),[attributes]), io:format("    '$m': ~p~n",[[X||{K,_}=X<-A,K=:=bs_deps]]), halt().' 2>&1 
done 
