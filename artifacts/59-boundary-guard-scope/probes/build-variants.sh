#!/usr/bin/env bash
# Builds three scratch compilers from a COPY of compiler/src (never edits it):
#   base    : unmodified
#   notag   : the record tag test is dropped on PRIVATE functions (narrowing)
#   widen   : the int/float kind test is emitted on PRIVATE functions too (widening)
# Output: $W/{base,notag,widen}/ebin
set -euo pipefail
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
SRC=/home/user/beam-sharp/compiler/src
W=${W:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/variants}
mkdir -p "$W"
for v in base notag widen; do
  rm -rf "$W/$v"; mkdir -p "$W/$v/src" "$W/$v/ebin"
  cp "$SRC"/* "$W/$v/src/"
done
# notag: tag test only when Public
python3 -I - "$W" <<'PY'
import sys,re
W=sys.argv[1]
p=W+'/notag/src/bs_emit.erl'
s=open(p).read()
old="""            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false ->
                    {Var, Pat1} = ensure_var(Pat, I, Line),
                    {Pat1, [tag_test(Var, Tag, Line)]}
            end;"""
new="""            case constrains_kind(Pat) orelse not Public of
                true  -> {Pat, []};
                false ->
                    {Var, Pat1} = ensure_var(Pat, I, Line),
                    {Pat1, [tag_test(Var, Tag, Line)]}
            end;"""
assert old in s
open(p,'w').write(s.replace(old,new))
p=W+'/widen/src/bs_emit.erl'
s=open(p).read()
old="        none when Public ->\n            case kind_only"
assert old in s
open(p,'w').write(s.replace(old,"        none ->\n            case kind_only"))
PY
for v in base notag widen; do
  ( cd "$W/$v/src"
    erl -noshell -eval '{ok,_}=leex:file("bs_lexer.xrl",[{error_location,column}]), {ok,_}=yecc:file("bs_parser.yrl",[{verbose,false}]), halt().' 
    erlc +debug_info -o ../ebin *.erl 2>&1 | grep -v "^$" | head -5 || true
    cp bsc.app.src ../ebin/bsc.app )
  echo "built $v: $(ls $W/$v/ebin/*.beam | wc -l) beams"
done
