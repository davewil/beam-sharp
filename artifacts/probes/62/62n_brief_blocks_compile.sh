#!/usr/bin/env bash
# PROBE 62n — every B# block in the decision brief is compiled by the real bsc.
# Blocks are EXTRACTED from the brief (fenced ```csharp whose first line is `// probe: ok NAME` or `// probe: refused NAME`),
# so the brief cannot drift from what was compiled. `ok` must compile; `refused` must be refused.
# CONTROLS (inline below, must be REFUSED): the record-literal form `{ Id: id, Total: 0 }` (an earlier draft of the brief
# used it and it does not compile), and a signature with no record declared for its return type.
# With ALIASBSC set (prototype, 62d): the `derived_alias_source` block's exports are listed, and `collision_source` must be
# refused by the unguarded derived rule while compiling under the real compiler.
set -uo pipefail
: "${BSC:?source env.sh first}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIEF="$HERE/../../62-outbound-abi-function-casing-decision-brief.md"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fail=0
compile() { # name compiler-binary mode -> sets RES, MSG
  local n="$1" bin="$2" mode="$3"; rm -rf "$W/$n/out_$mode"; mkdir -p "$W/$n/out_$mode"
  if BS_ALIAS=$mode "$bin" --src-root "$W/$n" -o "$W/$n/out_$mode" "$W/$n/Shop" >"$W/$n/log_$mode" 2>&1 && [ -f "$W/$n/out_$mode/Shop.beam" ]; then RES=compiles; MSG=""
  else RES=refused; MSG="$(grep -m1 . "$W/$n/log_$mode" | cut -c1-100)"; fi
}
check() { # name expect
  compile "$1" "$BSC" off
  local ok=PASS; [ "$RES" = "$2" ] || { ok=FAIL; fail=1; }
  printf '%-4s %-28s expected %-9s got %-9s %s\n' "$ok" "$1" "$2" "$RES" "$MSG"
}
# --- extract
python3 -I - "$BRIEF" "$W" <<'PY'
import re,sys,os
brief,w=sys.argv[1:3]
txt=open(brief,encoding="utf8").read()
n=0
for m in re.finditer(r'^[ ]*```csharp\n[ ]*// probe: (ok|refused) (\w+)\n(.*?)^[ ]*```', txt, re.S | re.M):
    kind,name,body=m.groups()
    d=os.path.join(w,name,"Shop"); os.makedirs(d)
    # dedent (blocks inside list items are indented)
    lines=body.split("\n"); ind=min((len(l)-len(l.lstrip()) for l in lines if l.strip()),default=0)
    open(os.path.join(d,"shop.bs"),"w").write("\n".join(l[ind:] for l in lines))
    open(os.path.join(w,name,"expect"),"w").write(kind)
    n+=1
print("extracted",n,"blocks from the brief")
sys.exit(0 if n==4 else 1)
PY
[ $? -eq 0 ] || { echo "FAIL: expected 4 marked blocks in the brief"; exit 1; }
for d in "$W"/*/; do n=$(basename "$d"); e=$(cat "$d/expect"); [ "$e" = ok ] && e=compiles; check "$n" "$e"; done
# --- controls
mkdir -p "$W/ctl_old_record_literal/Shop" "$W/ctl_no_record_decl/Shop"
printf 'module Shop\n\nrecord Order { Id: int, Total: int }\n\npublic Order New(int id)\n\nNew(id) -> { Id: id, Total: 0 }\n' > "$W/ctl_old_record_literal/Shop/shop.bs"
printf 'module Shop\n\npublic Order New(int id)\n\nNew(id) -> Order{ Id = id, Total = 0 }\n' > "$W/ctl_no_record_decl/Shop/shop.bs"
check ctl_old_record_literal refused
check ctl_no_record_decl refused
# --- prototype-compiler checks
if [ -n "${ALIASBSC:-}" ]; then
  compile derived_alias_source "$ALIASBSC" deleg
  echo "derived_alias_source under prototype: $RES"
  erl -noshell -pa "$W/derived_alias_source/out_deleg" -eval 'io:format("  exports: ~p~n", [[E || {N,_}=E <- '"'"'Shop'"'"':module_info(exports), N =/= module_info, N =/= '"'"'bs@type_atoms'"'"']]), halt().'
  compile collision_source "$ALIASBSC" deleg
  ok=PASS; [ "$RES" = refused ] || { ok=FAIL; fail=1; }
  printf '%-4s collision_source under derived rule: expected refused got %s  %s\n' "$ok" "$RES" "$MSG"
fi
exit $fail
