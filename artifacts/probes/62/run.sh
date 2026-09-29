#!/usr/bin/env bash
# Ticket 62 probes. usage: artifacts/probes/62/run.sh   (from anywhere; ~2 minutes)
# Requires: OTP 25, Elixir 1.14, gleam at /tmp/claude-0/tools/gleam, the reference compiler wrapper.
# Every probe's EXPECTED result is stated in its own file header; this script only compares.
set -u
SP=${SP:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad}
REPO=${REPO:-/home/user/beam-sharp}
GLEAM=${GLEAM:-/tmp/claude-0/tools/gleam}
P=$(cd "$(dirname "$0")" && pwd)
W=$SP/work/62; OUT=$P/out; mkdir -p "$W" "$OUT"; cd "$W"
RES=()
note() { RES+=("$1"); echo "$1"; }
pick() { note "$(grep -E "^(PASS|FAIL) $1" "$2" | tail -1)"; [ -n "$(grep -E "^(PASS|FAIL) $1" "$2")" ] || note "FAIL $1 (no verdict line)"; }
filter() { grep -v "^warning\|^  (elixir\|^  [A-Za-z_0-9./]*\.exs" ; }

echo "## setup: B# modules with the reference compiler"
rm -rf out out_alias gen b_plain b_ctrl b_alias coll; mkdir -p out out_alias
"$SP/bsc.sh" -o out "$P/src/Api/api.bs" >/dev/null 2>&1

echo "## setup: experimental compiler copy (alias.patch applied to a COPY of compiler/src)"
rm -rf compiler-copy alias-bsc; mkdir -p compiler-copy; cp -r "$REPO/compiler/src" compiler-copy/src
patch -s compiler-copy/src/bs_emit.erl < "$P/alias.patch" || echo "PATCH FAILED (repo HEAD moved?)"
sh "$P/build_compiler.sh" compiler-copy/src alias-bsc >/dev/null 2>&1
BS_ALIAS=wrapper "$P/bsc-with.sh" alias-bsc/ebin -o out_alias "$P/src/Api/api.bs" >/dev/null 2>&1
python3 "$P/gen_modules.py" gen
for n in 1 10 100 1000; do
  mkdir -p b_ctrl/$n b_alias/$n
  "$P/bsc-with.sh" alias-bsc/ebin -o b_ctrl/$n gen/N$n/n$n.bs >/dev/null 2>&1
  BS_ALIAS=wrapper "$P/bsc-with.sh" alias-bsc/ebin -o b_alias/$n gen/N$n/n$n.bs >/dev/null 2>&1
done

echo "## p1  Elixir spellings"
BS_EBIN=$W/out elixir "$P/p1_elixir_parse.exs" 2>&1 | filter > "$OUT/p1.txt"
ok=1; while IFS= read -r line; do
  c=${line%% | *}; rest=${line#* | }; want_p=${rest%% | *}; want_r=${rest#* | }
  got=$(grep -F -- "$c | " "$OUT/p1.txt" | head -1)
  case "$got" in "$c | $want_p | $want_r"*) ;; *) ok=0; echo "  MISMATCH: want [$line] got [$got]";; esac
done < "$P/expected_p1.txt"
[ $ok = 1 ] && note "PASS p1" || note "FAIL p1"
grep -q "elixir 1.14.0 otp 25" "$OUT/p1.txt" || echo "  (toolchain line missing)"

echo "## p1b Elixir tooling"
BS_EBIN=$W/out elixir "$P/p1b_elixir_in_module.exs" > "$OUT/p1b.txt" 2>"$OUT/p1b.err"
if grep -qF 'def direct(i), do: :Api."New"(i)' "$OUT/p1b.txt" && grep -q "^direct: %{" "$OUT/p1b.txt" \
   && grep -q "^piped: %{" "$OUT/p1b.txt" && grep -q "^captured: %{" "$OUT/p1b.txt" && ! grep -qi "^warning" "$OUT/p1b.err"; then note "PASS p1b"; else note "FAIL p1b"; fi

echo "## p1c Elixir alias + snake aliases"
BS_EBIN=$W/out elixir "$P/p1c_elixir_alias_and_snake.exs" 2>&1 | filter > "$OUT/p1c_plain.txt"
BS_EBIN=$W/out_alias elixir "$P/p1c_elixir_alias_and_snake.exs" 2>&1 | filter > "$OUT/p1c_alias.txt"
if grep -q 'Api."New"(1): %{' "$OUT/p1c_plain.txt" && grep -q ':Api.get_x(1) *raised UndefinedFunctionError' "$OUT/p1c_plain.txt" \
   && grep -q ':Api.get_x(1) *2$' "$OUT/p1c_alias.txt" && grep -q ':Api.h_t_t_p_get(1) *3$' "$OUT/p1c_alias.txt" \
   && grep -q ':Api.parse2_ints(1) *5$' "$OUT/p1c_alias.txt" && grep -q ':Api.get__x(1) *4$' "$OUT/p1c_alias.txt" \
   && grep -q ':Api.http_get(1) *raised UndefinedFunctionError' "$OUT/p1c_alias.txt"; then note "PASS p1c"; else note "FAIL p1c"; fi

echo "## p2  Erlang call into a real B# module"
escript "$P/p2_erlang_call.escript" "$W/out" > "$OUT/p2.txt" 2>&1; pick p2 "$OUT/p2.txt"

echo "## p3  alias cost (patched copy of the compiler)"
escript "$P/p3_measure_alias.escript" "$W/b_ctrl" "$W/b_alias" 2>&1 | grep -v Warning > "$OUT/p3.txt"; grep -E "^E[0-9]|^(PASS|FAIL) p3" "$OUT/p3.txt" | sed 's/^/  /'
pick p3 "$OUT/p3.txt"
echo "## p3b second export label (beam rewrite)"
escript "$P/p3b_label_alias.escript" "$W/b_ctrl/10/N10.beam" > "$OUT/p3b.txt" 2>&1; pick p3b "$OUT/p3b.txt"
echo "## p3c stack traces and call tracing"
escript "$P/p3c_trace_stack.escript" "$W/b_alias/10/N10.beam" > "$OUT/p3c.txt" 2>&1; pick p3c "$OUT/p3c.txt"

echo "## p4  Gleam 1.12: names it emits"
rm -rf "$P/gleam_names/build" "$P/gleam_bad/build" "$P/gleam_ext/build"
( cd "$P/gleam_names" && "$GLEAM" build --target erlang >/dev/null 2>&1 )
cp "$P/gleam_names/build/dev/erlang/gnames/_gleam_artefacts/gnames.erl" "$OUT/gnames.erl"
( cd "$P/gleam_bad" && "$GLEAM" build --target erlang > "$OUT/gleam_bad.txt" 2>&1 )
if grep -q "^-export(\[get_x/1, http_get/1, all/0\])" "$OUT/gnames.erl" && grep -q "h_t_t_p_get2" "$OUT/gnames.erl" \
   && grep -q "{my_variant, integer()}" "$OUT/gnames.erl" && grep -q "I'm expecting a lowercase name here" "$OUT/gleam_bad.txt"; then note "PASS p4"; else note "FAIL p4"; fi

echo "## p6  derivation rule vs Gleam's real output; collision census"
escript "$P/p6_rule.escript" "$REPO" "$P/gleam_names/src/gnames.gleam" "$OUT/gnames.erl" > "$OUT/p6.txt" 2>&1; sed -n '/^corpus/,$p' "$OUT/p6.txt" | sed 's/^/  /'
pick p6 "$OUT/p6.txt"
echo "## p6b real compile of colliding names"
"$P/p6b_collision.sh" "$SP/bsc.sh" "$W/alias-bsc/ebin" "$W/coll" > "$OUT/p6b.txt" 2>&1; pick p6b "$OUT/p6b.txt"

echo "## p8  different emission (snake_case only), Shop.Billing calls Shop"
"$P/p8_rename_emission.sh" "$REPO" "$W/alias-bsc/ebin" "$W/rename" > "$OUT/p8.txt" 2>&1; pick p8 "$OUT/p8.txt"

echo "## p5  Elixir def naming"
elixir "$P/p5_elixir_def_names.exs" 2>&1 | filter > "$OUT/p5.txt"
if grep -qF 'exports: [New: 1, fetch!: 1, get_x: 1, valid?: 1]' "$OUT/p5.txt" && grep -qF 'Naming."New"(1): 1' "$OUT/p5.txt" \
   && grep -qF 'def New(x) bare: {:error, SyntaxError}' "$OUT/p5.txt"; then note "PASS p5"; else note "FAIL p5"; fi

echo "## p7  Gleam calls 'Api':'New' for real"
( cd "$P/gleam_ext" && "$GLEAM" build --target erlang >/dev/null 2>&1; mkdir -p "$W/erllibs/apilib/ebin"; cp "$W/out/Api.beam" "$W/erllibs/apilib/ebin/"
  ERL_LIBS="$W/erllibs" "$GLEAM" run --target erlang > "$OUT/p7.txt" 2>&1 )
if grep -qF "new: #{'Id' => 1,'Kind' => 'Api.Order','Total' => 0}" "$OUT/p7.txt" && grep -q "^get_x_pascal: 4" "$OUT/p7.txt"; then note "PASS p7"; else note "FAIL p7"; fi
rm -rf "$P/gleam_names/build" "$P/gleam_bad/build" "$P/gleam_ext/build"

echo; echo "== SUMMARY"; printf '%s\n' "${RES[@]}"
