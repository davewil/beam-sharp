#!/usr/bin/env bash
# Ticket 52 probes, rerun from a clean scratch directory.
#   usage:  SCRATCH=/some/empty/dir ./run.sh        (default: a fresh mktemp -d)
#   needs:  source /tmp/claude-0/env.sh equivalent -- erl/erlc OTP 28, rebar3, elixir/mix, gleam, elm on PATH.
#   FULL=1 additionally runs the prototype's eunit suite and the two touched gates (about 15+ minutes).
# Nothing under the repo is modified; the prototype is built in a copy under $SCRATCH.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
[ -f /tmp/claude-0/env.sh ] && source /tmp/claude-0/env.sh
SCRATCH="${SCRATCH:-$(mktemp -d)}"; mkdir -p "$SCRATCH"; W="$SCRATCH"; export WORK="$W"
BSC="${BSC:-$REPO/compiler/_build/default/bin/bsc}"
ELX="$(dirname "$(dirname "$(command -v elixir)")")/lib/elixir/lib"
[ -d "$ELX" ] || ELX=/tmp/claude-0/mm/root/envs/beam/lib/elixir/lib
sec() { printf '\n\n######## %s\n' "$*"; }

sec "tool versions"
erl -noshell -eval 'io:format("OTP ~s erts ~s~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().'
elixir --version 2>&1 | tail -1; rebar3 --version 2>&1 | tail -1; gleam --version; echo "elm $(elm --version 2>&1)"
uname -srm; echo "repo HEAD $(git -C "$REPO" rev-parse --short HEAD)"; echo "scratch $W"

sec "0. fixtures: a real mix app (Elixir-style .app) and a real rebar3 app, built locally"
( cd "$W" && mix new fakeel --sup >/dev/null 2>&1 \
  && printf 'defmodule Fakeel do\n  def greet(n), do: "hello " <> n\nend\n' > fakeel/lib/fakeel.ex \
  && cd fakeel && mix compile 2>&1 | tail -1 && cat _build/dev/lib/fakeel/ebin/fakeel.app; echo )
mkdir -p "$W/fakeerl/src"
printf '{erl_opts, [debug_info]}.\n' > "$W/fakeerl/rebar.config"
printf '{application, fakeerl, [{description,"fake"},{vsn,"0.2.0"},{registered,[]},{applications,[kernel,stdlib]},{modules,[]}]}.\n' > "$W/fakeerl/src/fakeerl.app.src"
printf -- '-module(fakeerl_lib).\n-export([twice/1]).\ntwice(N) -> N*2.\n' > "$W/fakeerl/src/fakeerl_lib.erl"
( cd "$W/fakeerl" && rebar3 compile 2>&1 | grep -v proxy | tail -1; cat _build/default/lib/fakeerl/ebin/fakeerl.app )
EL="$W/fakeel/_build/dev/lib"; ER="$W/fakeerl/_build/default/lib"

sec "1. THE TICKET'S CLAIM: compile succeeds with nothing promised; a different ERL_LIBS gives run-time error:undef"
cd "$HERE/bs"
run() { echo "--- $1"; shift; "$@" > "$W/.run.out" 2>&1; local rc=$?; head -4 "$W/.run.out"; echo "exit=$rc"; }
run "UseEl, ERL_LIBS = elixir + fakeel            (control: reachable)" env ERL_LIBS=$ELX:$EL $BSC -o $W/o1 UseEl Hi '"bob"'
run "UseEl, ERL_LIBS = elixir only                (the ticket's case)"  env ERL_LIBS=$ELX $BSC -o $W/o2 UseEl Hi '"bob"'
run "UseEl, compile only, ERL_LIBS unset          (see exit=)"  env -u ERL_LIBS $BSC -o $W/o2b UseEl
run "UseErl, ERL_LIBS = fakeerl                   (control)"            env ERL_LIBS=$ER $BSC -o $W/o3 UseErl Dbl 4
run "UseErl, ERL_LIBS unset"                                            env -u ERL_LIBS $BSC -o $W/o4 UseErl Dbl 4
run "UseMissing: a module that exists nowhere, compile only"            env -u ERL_LIBS $BSC -o $W/o5 UseMissing
run "UseCrypto: an OTP module, ERL_LIBS unset     (control: needs no dependency)" env -u ERL_LIBS $BSC -o $W/o6 UseCrypto Len 8
echo "--- what the spec says about ERL_LIBS / the code path (count of lines mentioning it):"
for f in LANGUAGE.md README.md compiler/README.md; do printf '%s: ' $f; grep -c 'ERL_LIBS' "$REPO/$f"; done
echo "--- does bsc emit an .app (anything naming an application)? files written for UseEl:"; ls "$W/o1"

sec "2. what each cheap check says (checks.escript), three code paths"
cd "$HERE"
echo "== ERL_LIBS unset";            env -u ERL_LIBS escript checks.escript
echo; echo "== ERL_LIBS = elixir + fakeel + fakeerl"; ERL_LIBS=$ELX:$EL:$ER escript checks.escript

sec "3. does a module name determine its application? (module_app.escript; corpus = OTP + Elixir distribution + the 2 fakes)"
ERL_LIBS=$ELX:$EL:$ER escript module_app.escript
echo; echo "--- app named by directory name vs by the .app beside the beam, incl. a loose -pa dir"
mkdir -p "$W/loose2"; printf -- '-module(loose_mod).\n-export([f/0]).\nf()->ok.\n' > "$W/loose2/loose_mod.erl"; erlc -o "$W/loose2" "$W/loose2/loose_mod.erl"
ERL_LIBS=$ER escript owner.escript "$W/loose2"

sec "4. what the checks cost (cost_one.escript x 15 fresh VMs; microseconds; 200 warm calls each)"
for i in $(seq 1 15); do ERL_LIBS=$ELX:$EL:$ER escript cost_one.escript; done > "$W/cost_raw.txt"
head -1 "$W/cost_raw.txt"; escript cost_agg.escript < "$W/cost_raw.txt"

sec "5. what this repo's own B# text names (repo_foreign.sh; bare OTP path)"
env -u ERL_LIBS "$HERE/repo_foreign.sh" "$REPO"
echo; echo "--- per file: which application owns each foreign block's module"; env -u ERL_LIBS "$HERE/per_file_apps.sh" "$REPO"

sec "6a. Gleam: gleam build, @external to a module in no dependency; undeclared transitive import; absent path dependency; .app produced"
G="$W/gl"; rm -rf "$G"; mkdir -p "$G/proj/src" "$G/lib1/src" "$G/lib2/src" "$G/p2/src"
printf 'name = "proj"\nversion = "1.0.0"\ntarget = "erlang"\n\n[dependencies]\n' > "$G/proj/gleam.toml"
printf '@external(erlang, "no_such_mod", "f")\npub fn f(x: Int) -> Int\n\npub fn main() {\n  f(1)\n}\n' > "$G/proj/src/proj.gleam"
( cd "$G/proj"; echo "--- @external(erlang, \"no_such_mod\", ...) with no dependencies"; gleam build 2>&1 | tail -3; echo "build exit=${PIPESTATUS[0]}"; gleam run 2>&1 | head -6 )
printf 'name = "lib2"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\n' > "$G/lib2/gleam.toml"; printf 'pub fn two() -> Int { 2 }\n' > "$G/lib2/src/lib2.gleam"
printf 'name = "lib1"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\nlib2 = { path = "../lib2" }\n' > "$G/lib1/gleam.toml"; printf 'import lib2\npub fn one() -> Int { lib2.two() - 1 }\n' > "$G/lib1/src/lib1.gleam"
printf 'name = "p2"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\nlib1 = { path = "../lib1" }\n' > "$G/p2/gleam.toml"
( cd "$G/p2"; printf 'import lib2\npub fn main() { lib2.two() }\n' > src/p2.gleam
  echo "--- GLEAM import of a module whose package is only transitive"; gleam build 2>&1 | grep -E "is being imported|not a direct|may become|gleam add|Compiled"
  printf 'import lib1\npub fn main() { lib1.one() }\n' > src/p2.gleam; gleam build 2>&1 | tail -1
  echo "--- GLEAM's emitted p2.app (applications come from gleam.toml):"; cat build/dev/erlang/p2/ebin/p2.app )
printf 'name = "proj"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\nghost = { path = "../ghost" }\n' > "$G/proj/gleam.toml"
( cd "$G/proj"; echo "--- GLEAM dependency declared, absent"; gleam build 2>&1 | head -6 )
printf 'name = "proj"\nversion = "1.0.0"\ntarget = "erlang"\n[dependencies]\ngleam_stdlib = ">= 0.44.0 and < 2.0.0"\n' > "$G/proj/gleam.toml"
( cd "$G/proj"; echo "--- GLEAM hex dependency (network blocked here)"; timeout 60 gleam build 2>&1 | head -5 )

sec "6b. Elixir: mix compile of a consumer that calls Fakeel (a) with it only on ERL_LIBS, (b) declared as a dep"
rm -rf "$W/cons"; ( cd "$W" && mix new cons >/dev/null 2>&1 )
printf 'defmodule Cons do\n  def go, do: Fakeel.greet("x")\n  def ghost, do: NoSuch.Mod.f(1)\nend\n' > "$W/cons/lib/cons.ex"
( cd "$W/cons"; echo "--- (a) ERL_LIBS has fakeel, mix.exs does not"; ERL_LIBS=$EL mix compile 2>&1 | grep -E "warning|Generated"
  sed -i 's|^      # {:dep_from_hexpm.*|      {:fakeel, path: "../fakeel"}|' mix.exs
  echo "--- (b) fakeel declared: path dep, ERL_LIBS unset"; env -u ERL_LIBS mix compile --force 2>&1 | grep -E "warning|Generated"
  echo "--- the application list mix wrote from the declaration:"; cat _build/dev/lib/cons/ebin/cons.app; echo )

sec "6c. Erlang: erlc -behaviour on an absent module; rebar3 xref with/without the dep on the path; systools on a declared-but-absent app"
mkdir -p "$W/bh"; printf -- '-module(bh).\n-behaviour(no_such_behaviour).\n-export([f/0]).\nf() -> ok.\n' > "$W/bh/bh.erl"
( cd "$W" && erlc -o bh bh/bh.erl 2>&1 | head -2; echo "erlc exit=${PIPESTATUS[0]}" )
rm -rf "$W/ercons"; mkdir -p "$W/ercons/src"; ( cd "$W/ercons"
  printf '{erl_opts, [debug_info]}.\n{xref_checks, [undefined_function_calls]}.\n' > rebar.config
  printf '{application, ercons, [{description,"c"},{vsn,"0.1.0"},{registered,[]},{applications,[kernel,stdlib]},{modules,[]}]}.\n' > src/ercons.app.src
  printf -- '-module(ercons).\n-export([go/0]).\ngo() -> fakeerl_lib:twice(2).\n' > src/ercons.erl
  echo "--- rebar3 xref, fakeerl on ERL_LIBS (not in applications, not in deps)"; echo "xref warnings: $(ERL_LIBS=$ER rebar3 xref 2>&1 | grep -c 'Warning')"
  echo "--- rebar3 xref, ERL_LIBS unset"; env -u ERL_LIBS rebar3 xref 2>&1 | grep -E "Warning" )
mkdir -p "$W/dep2/ebin"; printf '{application,dep2,[{description,"d"},{vsn,"1"},{modules,[]},{registered,[]},{applications,[kernel,stdlib,ghostapp]}]}.\n' > "$W/dep2/ebin/dep2.app"
KV=$(erl -noshell -eval 'application:load(kernel),application:load(stdlib),{ok,K}=application:get_key(kernel,vsn),{ok,S}=application:get_key(stdlib,vsn),io:format("~s ~s",[K,S]),halt().'); set -- $KV
printf '{release,{"y","1"},{erts,"16.4"},[{kernel,"%s"},{stdlib,"%s"},{dep2,"1"}]}.\n' $1 $2 > "$W/y.rel"
cat > "$W/mk.escript" <<EOS
#!/usr/bin/env escript
main([Rel,P]) -> io:format("~p~n",[systools:make_script(Rel,[{path,[P]},silent,local,{outdir,"$W"}])]).
EOS
echo "--- systools:make_script, an app whose .app 'applications' names an absent app"; escript "$W/mk.escript" "$W/y" "$W/dep2/ebin"
echo "--- the OTP sources read (line numbers are in the brief)"; K=$(erl -noshell -eval 'io:format("~s",[code:lib_dir(stdlib)]),halt().'); grep -n "undefined_behaviour, B" "$K/src/erl_lint.erl"

sec "6d. Elm: elm make (package registry is blocked here; reports honestly how far it gets)"
export ELM_HOME="$W/elmhome"; mkdir -p "$W/elmp/src"
printf '{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",\n  "dependencies": { "direct": { "elm/core": "1.0.5" }, "indirect": {} },\n  "test-dependencies": { "direct": {}, "indirect": {} } }\n' > "$W/elmp/elm.json"
printf 'module Main exposing (x)\nimport Http\nx = 1\n' > "$W/elmp/src/Main.elm"
( cd "$W/elmp"; timeout 90 elm make src/Main.elm --output=/dev/null 2>&1 | head -4; echo "..."
  printf '{ "type": "application", "source-directories": ["src"], "elm-version": "0.19.1",\n  "dependencies": { "direct": { "elm/core": "1.0.5", "elm/json": "1.1.3" }, "indirect": {} },\n  "test-dependencies": { "direct": {}, "indirect": {} } }\n' > elm.json
  timeout 90 elm make src/Main.elm --output=/dev/null 2>&1 | head -9 )
unset ELM_HOME

sec "7. PROTOTYPE: build a copy of the repo with proto-v1.diff (module must load) then proto-v2.diff (adds 'in :app')"
PR="$W/proto"; rm -rf "$PR"; mkdir -p "$PR"; ( cd "$REPO" && git ls-files -z | xargs -0 -I{} cp --parents {} "$PR" 2>/dev/null )
( cd "$PR" && git init -q . && git add -A >/dev/null 2>&1 && git -c user.email=a@b -c user.name=x commit -qm base >/dev/null 2>&1 && true )
yc() { erl -noshell -eval "R=yecc:file(\"$1\",[{parserfile,\"$W/yc_$2.erl\"},{verbose,false},{report,true}]),io:format(\"~p~n\",[R]),halt()." 2>&1 | tail -2; }
echo "--- yecc conflicts, base grammar:"; yc "$REPO/compiler/src/bs_parser.yrl" base
build_and_try() { # $1 label, $2 diff
  ( cd "$PR" && git checkout -q . && git apply "$2" && cd compiler && rm -rf _build && rebar3 escriptize 2>&1 | grep -iE "conflict|rror" )
  P="$PR/compiler/_build/default/bin/bsc"; echo "=== $1  (diff: $(grep -c '^+[^+]' $2) added / $(grep -c '^-[^-]' $2) removed lines)"; cd "$HERE/bs"
  for m in UseEl UseErl UseMissing UseCrypto; do echo "--- $m  ERL_LIBS unset"; env -u ERL_LIBS $P -o $W/p-$m $m 2>&1 | head -3; echo "exit=${PIPESTATUS[0]}"; done
  echo "--- --api (reports a module's signatures, builds nothing), dependency absent:  HEAD vs this build"
  env -u ERL_LIBS $BSC --api UseMissing 2>&1 | head -3; echo "HEAD exit=${PIPESTATUS[0]}"
  env -u ERL_LIBS $P --api UseMissing 2>&1 | head -3; echo "prototype exit=${PIPESTATUS[0]}"
  echo "--- controls: present"; ERL_LIBS=$ELX:$EL $P -o $W/pc1 UseEl Hi '"bob"'; ERL_LIBS=$ER $P -o $W/pc2 UseErl Dbl 4
}
build_and_try "V1: module must be loadable" "$HERE/proto-v1.diff"
echo; echo "--- V1 spelled with an app: must be a syntax error (control: grammar not yet changed)"; cd "$HERE/bs2"; ERL_LIBS=$ELX:$EL:$ER "$PR/compiler/_build/default/bin/bsc" -o $W/pv1x AppOk 2>&1 | head -2
build_and_try "V2: V1 + 'using :M in :app'" "$HERE/proto-v2.diff"
P="$PR/compiler/_build/default/bin/bsc"; cd "$HERE/bs2"
echo "--- yecc conflicts, prototype grammar:"; yc "$PR/compiler/src/bs_parser.yrl" proto
for m in AppOk AppWrong AppAbsent AppTypo OtpOk OtpWrong; do echo "--- $m"; ERL_LIBS=$ELX:$EL:$ER $P -o $W/p2-$m $m 2>&1 | head -4; echo "exit=${PIPESTATUS[0]}"; done
mkdir -p "$W/loose"; cp "$ER/fakeerl/ebin/fakeerl_lib.beam" "$W/loose/"
echo "--- a module in a loose -pa dir with no .app (owner unverifiable): accepted, and it runs"; env -u ERL_LIBS ERL_FLAGS="-pa $W/loose" $P -o $W/p2-loose LooseOk Dbl 4 2>&1 | head -3

sec "8. compile-time cost of the prototype checks (CPU ms per bsc run, 25 runs each; ERL_LIBS has the deps)"
cd "$HERE/bs"
# CPU time (user+sys) rather than wall: the box is shared and wall time moves with other people's load.
t() { local out=() TIMEFORMAT='%3U %3S'; for i in $(seq 1 25); do
        ms=$( { time "$@" >/dev/null 2>&1; } 2>&1 | awk '{printf "%d", ($1+$2)*1000}' ); out+=($ms); done
      printf '%s\n' "${out[@]}" | sort -n | awk '{a[NR]=$1} END{printf "cpu ms: min %d  median %d  max %d  (n=%d)\n",a[1],a[int((NR+1)/2)],a[NR],NR}'; }
export ERL_LIBS=$ELX:$EL:$ER
echo -n "HEAD bsc          UseEl: "; t $BSC -o $W/t1 UseEl
echo -n "HEAD bsc          UseEl again (noise floor of the line above): "; t $BSC -o $W/t1 UseEl
echo -n "V2 prototype bsc  UseEl: "; t "$PR/compiler/_build/default/bin/bsc" -o $W/t2 UseEl
echo -n "HEAD bsc          Interop (3 foreign blocks): "; t $BSC -o $W/t3 "$REPO/compiler/examples/Interop"
echo -n "V2 prototype bsc  Interop (3 foreign blocks): "; t "$PR/compiler/_build/default/bin/bsc" -o $W/t4 "$REPO/compiler/examples/Interop"
unset ERL_LIBS

if [ "${FULL:-0}" = 1 ]; then
  sec "9. FULL: prototype V2 against the existing suite (per module, retrying eunit's 5 s load timeouts) and the gates that read the touched files"
  ( cd "$PR/compiler" && rebar3 eunit --module=cli_tests >/dev/null 2>&1; "$HERE/eunit_by_module.sh" "$PR/compiler" | tail -8 )
  "$HERE/gates.sh" "$PR/compiler"
  echo "(for the HEAD comparison, run gates.sh in your own copy of the repo; gates_output_head.txt is ours)"
fi
echo; echo "done"
