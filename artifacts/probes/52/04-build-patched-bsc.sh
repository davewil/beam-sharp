#!/usr/bin/env bash
# Builds a COPY of the repo's compiler with compiler-prototype.patch applied (the repo is never touched).
# CLAIM (mine): the grammar cost of `[app: X] using ...` / `[app: X] module ...` is two productions and
# adds no yecc conflict.   REFUTED IF: yecc reports more than the baseline conflict count, or the patch does
# not apply to the repo's current compiler/src, or the build fails.
. "$(dirname "$0")/lib.sh"
P=$WORK/patched; rm -rf "$P"; mkdir -p "$P/compiler"
( cd /home/user/beam-sharp/compiler && tar cf - --exclude=_build . ) | tar xf - -C "$P/compiler"
cd "$P/compiler"
echo "### baseline yecc conflicts (repo grammar)"
erl -noshell -eval 'yecc:file("src/bs_parser.yrl",[{verbose,false},{report,true},{parserfile,"'$P'/base_parser.erl"}]),halt().' 2>&1 | grep -i conflicts
echo "### apply patch"; patch -p1 -d "$P/compiler" < "$ROOT/compiler-prototype.patch" 2>&1 | sed 's/^/  /'
# the patch paths are a/src/... b/src/...; -p1 strips the first component
echo "### patched yecc conflicts"
erl -noshell -eval 'yecc:file("src/bs_parser.yrl",[{verbose,false},{report,true},{parserfile,"'$P'/patched_parser.erl"}]),halt().' 2>&1 | grep -i conflicts
echo "### patch size (added/removed lines per file)"
for f in bs_parser.yrl bs_check.erl bs_emit.erl bs_diag.erl; do
  awk -v f="$f" '/^\+\+\+ /{cur=$2} /^\+[^+]/{a[cur]++} /^-[^-]/{r[cur]++} END{for(k in a) if (k ~ f) printf "%-22s +%d -%d\n", f, a[k], r[k]+0}' "$ROOT/compiler-prototype.patch"
done
echo "### build"; T0=$(date +%s.%N); rebar3 escriptize 2>&1 | grep -v "^\s*\"" | tail -4; echo "build wall: $(echo "$(date +%s.%N) - $T0" | bc)s"
ls -l "$PBSC"
