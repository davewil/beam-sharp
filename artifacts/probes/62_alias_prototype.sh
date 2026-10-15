#!/usr/bin/env bash
# PROBE 62_alias_prototype (ticket 62, option 2: snake_case alias exports)
# Builds a PATCHED COPY of the compiler (62_alias_exports.patch; the repo's
# compiler/ is never touched), then measures:
#  A. the derived names on awkward identifiers and the collisions reported
#  B. who can call what: Elixir (`:Awk.new`, `:Awk.to_json`), Erlang (PascalCase
#     still works), B#->B# (Shop.Reports under the patched compiler)
#  C. beam size / export count over every top-level compiler/examples module
#  D. compile time, n=7, stock vs patched
#  E. call-time (62_alias_bench.erl): direct vs alias wrapper vs duplicated clauses
# REFUTES "aliases are cheap/safe" if: a collision is NOT reported for
# GetUrl/GetURL/Get_Url/ModuleInfo (control), or Awk's alias set is wrong, or
# `:Awk.new(1)` fails, or PascalCase `'Awk':'New'(1)` stops working, or the
# beam grows by more than the table says, or alias call-time is >10% over direct.
# Controls: stock bsc beside patched bsc on every row; `empty` loop in the bench.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
export ELIXIR_ERL_OPTIONS="+fnu"
W="$(bs_scratch)"; trap 'rm -rf "$W"' EXIT
cp -r "$REPO/compiler" "$W/compiler"; rm -rf "$W/compiler/_build"
( cd "$W" && patch -p1 < "$HERE/62_alias_exports.patch" >/dev/null ) || { echo "patch failed"; exit 2; }
( cd "$W/compiler" && rebar3 escriptize >/dev/null 2>&1 ) || { echo "build failed"; exit 2; }
PBSC="$W/compiler/_build/default/bin/bsc"; SBSC="$BSC"
FX="$HERE/62_fixtures"; EX="$REPO/compiler/examples"
mkdir -p "$W/stock" "$W/proto"

echo "=== A. derived names and collisions (patched compiler) ==="
"$PBSC" --src-root "$FX" -o "$W/proto" "$FX/Awk"  2>&1 | sed 's/^/  Awk  stderr: /'
"$PBSC" --src-root "$FX" -o "$W/proto" "$FX/Coll" 2>&1 | sed 's/^/  Coll stderr: /'
erl -noshell -pa "$W/proto" -eval "
  P = fun(M) -> lists:sort([E || {N,_}=E <- M:module_info(exports), N =/= module_info, N =/= bs@type_atoms]) end,
  io:format(\"  Awk exports : ~p~n  Coll exports: ~p~n\", [P('Awk'), P('Coll')]), halt()."
echo "  stock compiler on Lower (lowercase fn name written in B#):"
"$SBSC" --src-root "$FX" -o "$W/stock" "$FX/Lower" 2>&1 | sed 's/^/    /'

echo; echo "=== B. callers ==="
cat > "$W/c.exs" <<'XX'
Code.prepend_path(System.get_env("EB"))
IO.puts("  elixir :Awk.new(1)          -> #{inspect(:Awk.new(1))}")
IO.puts("  elixir :Awk.to_json(1)      -> #{inspect(:Awk.to_json(1))}")
IO.puts("  elixir :Awk.http_get(1)     -> #{inspect(:Awk.http_get(1))}")
IO.puts("  elixir :Awk.x2_y(1)         -> #{inspect(:Awk.x2_y(1))}")
IO.puts("  elixir :Awk.get_url2(1)     -> #{inspect(:Awk.get_url2(1))}")
IO.puts("  elixir :Awk.get_order(1,2)  -> #{inspect(:Awk.get_order(1, 2))}")
IO.puts("  elixir :Awk.\"New\"(1) quoted form still works -> " <> inspect(:Awk."New"(1)))
IO.puts("  elixir pipe 1 |> :Awk.new() |> :Awk.to_json() -> #{inspect(1 |> :Awk.new() |> :Awk.to_json())}")
IO.puts("  CONTROL elixir :Awk.nope(1) -> " <> (try do :Awk.nope(1) rescue e -> inspect(e.__struct__) end))
XX
EB="$W/proto" elixir "$W/c.exs" 2>&1 | grep -v "^warning: the VM"
erl -noshell -pa "$W/proto" -eval "io:format(\"  erlang 'Awk':'New'(1) -> ~p ; 'Awk':new(1) -> ~p~n\", ['Awk':'New'(1), 'Awk':new(1)]), halt()."
"$PBSC" --src-root "$EX" -o "$W/proto" "$EX/Shop" >/dev/null 2>&1; "$PBSC" --src-root "$EX" -o "$W/proto" "$EX/Shop/Reports" >/dev/null 2>&1
erl -noshell -pa "$W/proto" -eval "io:format(\"  B#->B# under patch: 'Shop.Reports':'Restate'(3) -> ~p ; snake alias restate(3) -> ~p~n\", ['Shop.Reports':'Restate'(3), 'Shop.Reports':restate(3)]), halt()."
echo "  bsc run of Shop.Reports Restate 3 via patched bsc:"; "$PBSC" --src-root "$EX" "$EX/Shop/Reports" Restate 3 2>&1 | sed 's/^/    /'

echo; echo "=== C. beam size and export count over compiler/examples/* (top-level modules) ==="
rm -rf "$W/stock" "$W/proto"; mkdir -p "$W/stock" "$W/proto"
ok=0
for d in "$EX"/*/; do
  n=$(basename "$d"); [ "$n" = exemplars ] && continue
  if "$SBSC" --src-root "$EX" -o "$W/stock/$n" "$d" >/dev/null 2>&1 && "$PBSC" --src-root "$EX" -o "$W/proto/$n" "$d" >/dev/null 2>&1; then ok=$((ok+1)); else echo "  (skipped $n: does not compile standalone)"; fi
done
erl -noshell -eval '
  Sz = fun(D) -> L = filelib:wildcard(D ++ "/*/*.beam"), {length(L), lists:sum([filelib:file_size(F) || F <- L])} end,
  Ex = fun(D) -> L = filelib:wildcard(D ++ "/*/*.beam"),
        lists:sum([length([x || {N,_} <- (begin {ok,{_,[{exports,E}]}} = beam_lib:chunks(F,[exports]), E end), N =/= module_info]) || F <- L]) end,
  {NS, BS} = Sz("'$W'/stock"), {NP, BP} = Sz("'$W'/proto"),
  io:format("  modules: stock=~p proto=~p ; bytes: stock=~p proto=~p delta=~p (~.1f%) ; exports (excl module_info): stock=~p proto=~p~n",
     [NS, NP, BS, BP, BP-BS, (BP-BS)*100/BS, Ex("'$W'/stock"), Ex("'$W'/proto")]),
  halt().'
"$SBSC" --src-root "$FX" -o "$W/o1" "$FX/Awk" >/dev/null; "$PBSC" --src-root "$FX" -o "$W/o2" "$FX/Awk" >/dev/null
echo "  Awk.beam (toy, 7 public fns, 7 aliases): stock=$(wc -c < "$W/o1/Awk.beam") proto=$(wc -c < "$W/o2/Awk.beam") bytes"

echo; echo "=== D. compile time, wall ms, n=7 (bsc on Shop; includes escript VM start) ==="
for which in stock proto; do
  B="$SBSC"; [ $which = proto ] && B="$PBSC"
  ts=(); for i in 1 2 3 4 5 6 7; do s=$(date +%s%N); "$B" --src-root "$EX" -o "$W/t" "$EX/Shop" >/dev/null 2>&1; e=$(date +%s%N); ts+=($(( (e-s)/1000000 ))); done
  sorted=($(printf '%s\n' "${ts[@]}" | sort -n)); echo "  $which: min=${sorted[0]} median=${sorted[3]} max=${sorted[6]} ms  (all: ${ts[*]})"
done

echo; echo "=== E. call-time ==="
"$PBSC" --src-root "$FX" -o "$W/o3" "$FX/Awk" >/dev/null 2>&1
"$SBSC" --src-root "$FX" -o "$W/o4" "$FX/Awk" >/dev/null 2>&1
erlc -o "$W" "$HERE/62_alias_bench.erl" && erl -noshell -pa "$W" -eval "'62_alias_bench':run([\"$W/o3\", \"$W/o4/Awk.abstr\"])."
