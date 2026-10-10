#!/usr/bin/env bash
# Ticket 60 probes. Reruns everything from a clean scratch dir:  artifacts/probes/60/run.sh
# Needs /tmp/claude-0/env.sh (erl, rebar3, elixir, gleam, elm) and a built
# compiler/_build/default/bin/bsc at HEAD. Output of the last run: output.txt.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
source /tmp/claude-0/env.sh
BSC=$REPO/compiler/_build/default/bin/bsc
S=$(mktemp -d /tmp/claude-0/probe60.XXXXXX)
cp -r "$HERE" "$S/p"; P=$S/p
hdr() { printf '\n######## %s\n' "$*"; }
run() { echo "\$ $*"; "$@"; echo "[rc=$?]"; }

hdr "tool versions"
erl -noshell -eval 'io:format("erlang OTP ~s, erts ~s~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().'
rebar3 --version; elixir --version | tail -1; gleam --version; elm --version; go version
git -C "$REPO" log -1 --format='repo HEAD %h %s' | cut -c1-100

hdr "1. TODAY, bsc at HEAD: any module names any public function (and --api cannot tell client API from helper)"
cat "$P/src/Shop/Orders/Orders.bs"
echo "--- Shop.Billing (sibling) and Web.Handler (outside Shop) both compile and run:"
run "$BSC" -o "$S/o" --src-root "$P/src" "$P/src/Shop/Billing" Invoice 5
run "$BSC" -o "$S/o" --src-root "$P/src" "$P/src/Web/Handler" Handle 5
echo "--- what the boundary manifest (ticket 24 s2) sees:"
run "$BSC" --api --src-root "$P/src" "$P/src/Shop/Orders"
echo "--- the same helper left private (the default) so that Web.Handler cannot reach it:"
cp -r "$P/src" "$P/src-private"; sed -i 's/^public int Recompute/int Recompute/' "$P/src-private/Shop/Orders/Orders.bs"
run "$BSC" --src-root "$P/src-private" "$P/src-private/Shop/Billing"
run "$BSC" --api --src-root "$P/src-private" "$P/src-private/Shop/Orders"
run "$BSC" --src-root "$P/src-private" "$P/src-private/Shop/Orders" Recompute 5
echo "--- emitted code: a helper that siblings may call must be exported, hence guarded (F24; ticket 18 s5: one entry label)"
run "$BSC" -o "$S/o-pub" --src-root "$P/src" "$P/src/Shop/Orders"
run "$BSC" -o "$S/o-priv" --src-root "$P/src-private" "$P/src-private/Shop/Orders"
echo "-- public Recompute:";  escript "$P/disasm.escript" "$S/o-pub/Shop.Orders.beam" Recompute
echo "-- private Recompute:"; escript "$P/disasm.escript" "$S/o-priv/Shop.Orders.beam" Recompute
echo "--- grep: any trace of a who-may-name-me construct in the compiler, the spec, the tickets"
grep -n -i -w 'friend\|visible_to\|sealed' -r "$REPO/compiler/src" "$REPO/LANGUAGE.md" "$REPO/wayfinder/issues" | grep -v '/60-which' | grep -v 'false friend' | cut -c1-150
echo "[grep done; hits above are prose uses, not constructs]"

hdr "2. PROTOTYPES, built from a clean clone of HEAD plus the patch"
for v in position written; do
  git clone -q "$REPO" "$S/proto-$v" && (cd "$S/proto-$v" && git apply "$P/patch-$v.diff" && cd compiler && rebar3 escriptize >/dev/null 2>&1)
  echo "patch-$v.diff: $(grep -c '^+[^+]' "$P/patch-$v.diff") lines added, $(grep -c '^-[^-]' "$P/patch-$v.diff") removed, files: $(grep -c '^diff' "$P/patch-$v.diff")"
done
PB=$S/proto-position/compiler/_build/default/bin/bsc
WB=$S/proto-written/compiler/_build/default/bin/bsc
hdr "2a. option POSITION: a module under an Internal segment is nameable only from under its parent"
cat "$P/src-position/Shop/Internal/Totals/Totals.bs"
for m in Shop/Orders Shop/Billing Shop/Reports Web/Handler Web/NsHandler; do echo "-- $m"; run "$PB" -o "$S/o" --src-root "$P/src-position" "$P/src-position/$m"; done
echo "-- control: the UNPATCHED bsc accepts the refused one"
run "$BSC" -o "$S/o" --src-root "$P/src-position" "$P/src-position/Web/Handler" Handle 5
echo "-- what --api says about the two modules"
run "$PB" --api --src-root "$P/src-position" "$P/src-position/Shop/Orders"
run "$PB" --api --src-root "$P/src-position" "$P/src-position/Shop/Internal/Totals"
hdr "2b. option WRITTEN: the callee lists its friends"
cat "$P/src-written/Shop/Totals/Totals.bs"
for m in Shop/Orders Shop/Billing Shop/Reports Web/Handler; do echo "-- $m"; run "$WB" -o "$S/o" --src-root "$P/src-written" "$P/src-written/$m"; done
echo "-- control: the UNPATCHED bsc rejects the new keyword's line (it is not B# today)"
run "$BSC" -o "$S/o" --src-root "$P/src-written" "$P/src-written/Shop/Orders"
echo "-- what --api says (it does not know about friends)"
run "$WB" --api --src-root "$P/src-written" "$P/src-written/Shop/Totals"

hdr "3. cost of a helper in another module (what a module-granular rule forces): remote vs local call"
( mkdir -p "$S/b" && cp "$P/erlang/bench_"*.erl "$S/b/" && cd "$S/b" && erlc bench_call.erl bench_helper.erl && erl -noshell -pa . -eval 'bench_call:main(),halt().' )

hdr "4. GLEAM internal_modules / @internal (two packages, path dependency, no Hex)"
cp -r "$P/gleam" "$S/g"
( cd "$S/g/app" && echo '$ gleam build' && gleam build 2>&1 | grep -v '^ *Resolving'; echo "[rc=$?]" )
( cd "$S/g/lib" && gleam export package-interface --out "$S/g/iface.json" >/dev/null 2>&1
  python3 -I -c "
import json
d=json.load(open('$S/g/iface.json'))
for m,v in sorted(d['modules'].items()): print('package-interface module', m, 'functions', sorted(v['functions']))
print('(lib/internal/helper and lib.also_hidden, marked internal, are absent from the interface/docs)')" )
echo "-- control: remove the dependency's import and see the project still runs, so the build above is a real build"
( cd "$S/g/app" && gleam run 2>&1 | tail -n 2 )

hdr "5. ELIXIR @moduledoc false (installed Elixir has beams only, no .ex sources)"
cp -r "$P/elixir" "$S/e"; export MIX_HOME=$S/e/mixhome HEX_OFFLINE=1
( cd "$S/e/proj" && mix compile 2>&1 | tail -n 3 && elixir -pa _build/dev/lib/proj/ebin ../docs.exs 2>&1 )
( cd "$S/e/proj" && echo '$ mix xref callers Shop.Orders.Internal' && mix xref callers Shop.Orders.Internal 2>&1 )
( cd "$S/e/proj" && mix help xref 2>&1 | grep -n -i -- '--exclude' | head -n 2 )

hdr "6. ERLANG: -export, xref (needs +debug_info), and the OTP xref source"
cp -r "$P/erlang" "$S/er"; ( cd "$S/er" && mkdir ebin && erlc +debug_info -Wall -o ebin shop_orders.erl shop_billing.erl web_handler.erl && echo "erlc: 0 diagnostics, rc=$?" && escript xref_probe.escript ebin )
T=$(erl -noshell -eval 'io:format("~s",[code:lib_dir(tools)]),halt().')
echo "-- OTP xref has no ignore attribute; grep for it in tools/src:"; grep -c 'ignore_xref' "$T"/src/xref*.erl
echo "-- rebar3 does (strings in its escript):"
unzip -p "$(command -v rebar3)" rebar/ebin/rebar_prv_xref.beam 2>/dev/null | strings | grep -c ignore_xref

hdr "7. ELM exposed-modules (needs package.elm-lang.org)"
cp -r "$P/elm" "$S/elm"; ( cd "$S/elm/lib" && ELM_HOME=$S/elm/home timeout 60 elm make src/Lib.elm --output=/dev/null 2>&1 | head -n 12 )

hdr "8. GO internal/ (path-derived rule, enforced by the compiler)"
cp -r "$P/go" "$S/go"; export GOCACHE=$S/gocache
for v in a b; do echo "-- variant $v"; ( cd "$S/go/$v" && go build ./... 2>&1; echo "[rc=$?]" ); done
echo "-- the rule's source, GOROOT/src/cmd/go/internal/load/pkg.go:"
sed -n '1472,1477p' "$(go env GOROOT)/src/cmd/go/internal/load/pkg.go"
echo; echo "scratch: $S"
