#!/usr/bin/env bash
# Reruns every probe for ticket 59 from a clean scratch dir.
#   SCRATCH=dir   where to work (default: a fresh mktemp dir)
#   TIMING=0      skip the ~5 minute timing run
#   TESTS=0       skip `rebar3 eunit` on the prototype compilers
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
source /tmp/claude-0/env.sh
SCRATCH="${SCRATCH:-$(mktemp -d /tmp/claude-0/run59.XXXXXX)}"
mkdir -p "$SCRATCH"; cd "$SCRATCH" || exit 1
H() { printf '\n######## %s\n' "$*"; }

H "tool versions"
erl -noshell -eval 'io:format("OTP ~s, erts ~s~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().'
rebar3 version; elixir --version 2>&1 | tail -1; gleam --version; echo "elm $(elm --version)"
echo "repo HEAD: $(git -C "$REPO" rev-parse --short HEAD)"; uname -srm; nproc | sed 's/^/cores: /'

H "build four compilers from a clean copy of compiler/ (base, exported-only, guard-all, field-depth)"
for v in base exported-only guard-all field-depth; do
  mkdir -p "src-$v"; (cd "$REPO" && tar --exclude=_build -cf - compiler) | tar -xf - -C "src-$v"
  if [ "$v" != base ]; then (cd "src-$v" && patch -s -p1 < "$HERE/patches/$v.patch") || echo "PATCH FAILED $v"; fi
  (cd "src-$v/compiler" && rebar3 escriptize >/dev/null 2>&1) || echo "BUILD FAILED $v"
  cp "src-$v/compiler/_build/default/bin/bsc" "bsc.$v"
  printf '%-14s patch LOC (added+removed lines): ' "$v"
  if [ "$v" = base ]; then echo 0; else grep -c '^[+-][^+-]' "$HERE/patches/$v.patch"; fi
done
REPOBSC="$REPO/compiler/_build/default/bin/bsc"
BSC=./bsc.base

H "sanity: rebuilt base emits byte-identical .abstr to the repo's built bsc"
for p in p1_shape/Guard p2_forge/Forge p3_leak/Leak; do
  rm -rf cmpa cmpb; mkdir cmpa cmpb; m=$(basename $p)
  "$REPOBSC" -o cmpa "$HERE/$p" >/dev/null 2>&1; "$BSC" -o cmpb "$HERE/$p" >/dev/null 2>&1
  cmp "cmpa/$m.abstr" "cmpb/$m.abstr" && echo "$m: identical"
done

build() { # build VARIANT SRCDIR OUTDIR
  mkdir -p "$3"; "./bsc.$1" -o "$3" "$2" >/dev/null 2>"$3/stderr.txt" || { echo "BSC FAILED $1 $2"; cat "$3/stderr.txt"; }
}

H "1. SHAPE: which functions carry which guard (p1_shape/Guard)"
for v in base exported-only guard-all field-depth; do
  build $v "$HERE/p1_shape/Guard" o1_$v
  echo "---- $v"; escript "$HERE/pp.escript" o1_$v/Guard.abstr PubRec PrivRec PubInt PrivInt PubOct PrivOct | grep -v '^$' | tr -s ' \n' ' ' | sed "s/\. /.\n/g"
  echo
done

H "2. FORGERY from Erlang into p2_forge/Forge (each variant)"
erlc -o . "$HERE/p2_forge/drive_forge.erl"
for v in base exported-only guard-all field-depth; do
  build $v "$HERE/p2_forge/Forge" o2_$v
  echo "---- compiler: $v"; erl -noshell -pa o2_$v -pa . -eval "drive_forge:run('Forge'),halt()."
done
echo; echo "---- disassembly of the private Cents (base vs exported-only)"
for v in base exported-only; do echo "== $v"; escript "$HERE/p4_cost/dis.escript" o2_$v/Forge.beam Cents; done

H "3. THE SAME FOR int: p3_leak/Leak"
erlc -o . "$HERE/p3_leak/drive_leak.erl"
for v in base exported-only guard-all field-depth; do
  build $v "$HERE/p3_leak/Leak" o3_$v
  echo "---- compiler: $v"; erl -noshell -pa o3_$v -pa . -eval "drive_leak:run(),halt()."
done
echo; echo "---- does erlc delete the private is_integer? Bump in Leak (a projection feeds it) vs Inc in Bench (every caller proves integer)"
for v in base guard-all; do echo "== Leak.Bump, $v"; escript "$HERE/p4_cost/dis.escript" o3_$v/Leak.beam Bump; done
for v in base guard-all; do build $v "$HERE/p4_cost/Bench" o4_$v; echo "== Bench.Inc, $v"; escript "$HERE/p4_cost/dis.escript" o4_$v/Bench.beam Inc; done

H "4a. BYTES: .beam size, Code chunk and stripped file, private fns with a record param (K) and an int param (K)"
for v in exported-only field-depth; do build $v "$HERE/p4_cost/Bench" o4_$v; done
cat > bytes.escript <<'EOS'
#!/usr/bin/env escript
main(Files) -> [begin
    {ok,Bin} = file:read_file(F), {ok,_,Cs} = beam_lib:all_chunks(Bin), {ok,{_,Stripped}} = beam_lib:strip(Bin),
    io:format("~-34s file=~p stripped=~p Code=~p~n", [F, byte_size(Bin), byte_size(Stripped), byte_size(proplists:get_value("Code",Cs))]) end || F <- Files].
EOS
echo "Bench (1 private record fn + 1 private int fn + twins)"; escript bytes.escript o4_base/Bench.beam o4_exported-only/Bench.beam o4_guard-all/Bench.beam
for cfg in "1 3" "10 3" "10 8" "40 3"; do set -- $cfg
  python3 "$HERE/p4_cost/gen.py" $1 $2 gen_$1_$2; echo "Many: K=$1 private record fns + K private int fns, record has $2 fields"
  for v in base exported-only guard-all; do build $v gen_$1_$2/Many o5_$1_$2_$v; done
  escript bytes.escript o5_$1_$2_base/Many.beam o5_$1_$2_exported-only/Many.beam o5_$1_$2_guard-all/Many.beam
done

if [ "${TIMING:-1}" = 1 ]; then
H "4b. TIME per call (see p4_cost/tbench.erl): 25 runs x 2M entries (8 guarded calls each), round-robin over variants; base1 and base2 are the SAME code in two modules = the noise floor"
cp "$HERE/p4_cost/tbench.erl" .; erlc tbench.erl
A=o4_base/Bench.abstr
erl -noshell +S 1 -pa . -eval "tbench:main([\"timing.txt\",\"base1:plain:$A\",\"base2:plain:$A\",\"eo:plain:o4_exported-only/Bench.abstr\",\"ga:plain:o4_guard-all/Bench.abstr\",\"base1:inline:$A\",\"base2:inline:$A\",\"eo:inline:o4_exported-only/Bench.abstr\",\"ga:inline:o4_guard-all/Bench.abstr\"])."
cat timing.txt
echo; echo "(inlined variant: does Step survive as a call in RunRec? disassembly of RunRec compiled with {inline,[{'Step',1}]})"
erl -noshell -eval '{ok,F}=file:consult("o4_base/Bench.abstr"), {ok,_,B}=compile:forms(F,[{inline,[{'"'"'Step'"'"',1}]},binary,return_errors]), file:write_file("inl.beam",B),halt().'
escript "$HERE/p4_cost/dis.escript" inl.beam RunRec
fi

H "5. SURVEY: Gleam (pub vs private, opaque), Elixir (def vs defp)"
mkdir -p gleam && cp -r "$HERE/survey/gleam/." gleam/ && (cd gleam && gleam build 2>&1 | tail -2
  erl -noshell -eval '{ok,{_,[{abstract_code,{_,AC}}]}}=beam_lib:chunks("build/dev/erlang/probe/ebin/probe.beam",[abstract_code]), [io:format("~s",[erl_pp:form(X)]) || X<-AC, element(1,X)=:=function],halt().' | grep -v '^$'
  erl -noshell -pa build/dev/erlang/probe/ebin -eval '
F=fun(L,Th)-> R=try {returned,Th()} catch C:E:_ -> {raised,C,E} end, io:format("~-40s ~w~n",[L,R]) end,
F("pub_cents({order,1,7})", fun()->probe:pub_cents({order,1,7}) end),
F("pub_cents({other,1,7}) forged tag", fun()->probe:pub_cents({other,1,7}) end),
F("via_priv({other,1,7}) forged tag", fun()->probe:via_priv({other,1,7}) end),
F("pub_inc(1.5)", fun()->probe:pub_inc(1.5) end),
F("run_inc(1.5)  (via private)", fun()->probe:run_inc(1.5) end),
F("money_cents({whatever,3}) opaque", fun()->probe:money_cents({whatever,3}) end), halt().')
mkdir -p elixir && cp "$HERE/survey/elixir/"* elixir/ && (cd elixir && elixirc -o ebin probe.ex 2>&1 | tail -3; escript drive.escript
  erl -noshell -eval '{ok,{_,[{"ExCk",B}]}}=beam_lib:chunks("ebin/Elixir.Probe.beam",["ExCk"]), {_,M}=binary_to_term(B), E=maps:get(exports,M), io:format("ExCk exports (no private fn is listed): ~p~n",[[K||{K,_}<-E]]), {_,S}=lists:keyfind({struct_via,1},1,E), io:format("struct_via/1 signature inferred THROUGH the defp: ~P~n",[S,12]),halt().')
echo "Elm: UNMEASURED here -- elm make cannot fetch package.elm-lang.org:"; (mkdir -p elm/src && cd elm && cp "$HERE/survey/elm/elm.json" . && cp "$HERE/survey/elm/Main.elm" src/ && timeout 60 elm make src/Main.elm --output=/dev/null 2>&1 | sed -n 1,8p)

if [ "${TESTS:-1}" = 1 ]; then
H "6. EXISTING TESTS (tests.sh): rebar3 eunit on each compiler; failing tests by name"
bash "$HERE/tests.sh" "$SCRATCH"
fi
echo; echo "DONE"
