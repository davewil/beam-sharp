# Shared by the ticket-59 probes. Source it; run from anywhere.
#   source env.sh first (erl, $BSC); set REPO to the repo root.
REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
PROBE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ebin of the real bsc, taken from the $BSC wrapper (it is `-pa <ebin>`)
BSC_EBIN="${BSC_EBIN:-$(grep -o -- '-pa [^ ]*' "$BSC" | head -1 | cut -d' ' -f2)}"
WORK="${WORK:-$(mktemp -d)}"

# build_variants: three bsc's that differ only in bs_emit:guard_one/8
#   cur    - the shipped compiler, byte-identical bs_emit
#   narrow - tag test only when Public            (option: private gets nothing)
#   widen  - int kind test on private fns as well (option: private gets both)
build_variants() {
  for v in cur narrow widen; do
    mkdir -p "$WORK/v/$v"; cp "$BSC_EBIN"/* "$WORK/v/$v/"
    cp "$REPO/compiler/src/bs_emit.erl" "$WORK/v/$v/bs_emit.erl"
  done
  # narrow: add one clause ahead of the tag clause
  python3 - "$WORK/v/narrow/bs_emit.erl" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
a="    case record_tag(TypeExpr, Ctx) of\n        {ok, Tag} ->\n"
assert s.count(a)==1, "guard_one shape changed"
s=s.replace(a,"    case record_tag(TypeExpr, Ctx) of\n        {ok, _Tag} when not Public -> {Pat, []};\n        {ok, Tag} ->\n")
open(p,'w').write(s)
PY
  # widen: the kind test no longer waits for Public
  sed -i 's/^        none when Public ->$/        none ->/' "$WORK/v/widen/bs_emit.erl"
  grep -q '^        none ->$' "$WORK/v/widen/bs_emit.erl" || { echo "widen patch missed"; exit 1; }
  for v in narrow widen; do
    (cd "$WORK/v/$v" && erlc -o . bs_emit.erl >/dev/null 2>&1) || { echo "variant $v failed to compile"; exit 1; }
  done
  cmp -s "$WORK/v/cur/bs_emit.beam" "$BSC_EBIN/bs_emit.beam" && echo "cur == shipped bs_emit.beam"
}
# bsc_v <variant> <srcroot> <outdir> <moduledir>
bsc_v() { local v=$1; shift; erl -noshell -pa "$WORK/v/$v" -eval 'bsc:main(init:get_plain_arguments())' -extra --src-root "$1" -o "$2" "$3" 2>&1 | grep -v 'is unused'; }
# show_fns <beam> <fn,fn,...>  — the abstract code B# emitted, as Erlang source
show_fns() { erl -noshell -eval '
  [Beam,Names]=init:get_plain_arguments(), Ns=[list_to_atom(N)||N<-string:tokens(Names,",")],
  {ok,{_,[{abstract_code,{_,AC}}]}}=beam_lib:chunks(Beam,[abstract_code]),
  [io:format("~s~n",[erl_pp:form(F)]) || F<-AC, element(1,F)==function, lists:member(element(3,F),Ns)], halt().' -extra "$1" "$2"; }
