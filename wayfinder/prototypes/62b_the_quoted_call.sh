#!/usr/bin/env bash
# PROTOTYPE 62b — is apply/3 really the only way into a B# module from Elixir,
# and what would a lowercase second export cost?
#
# Throwaway. Ticket 62, round 1 (2026-11-10). 62a measured that
# `:Shop.New(1)` is a syntax error and concluded "callers are pushed to
# apply/3". It never tried Elixir's quoted remote call.
#
#   ./62b_the_quoted_call.sh
#
# Requires: OTP 28, Elixir, a built bsc. The Gleam part needs `gleam` and
# self-skips without it. Run from the repo root.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export ELIXIR_ERL_OPTIONS="+fnu"

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

OUT="$WORK/ebin"; mkdir -p "$OUT"
"$BSC" --src-root "$COMPILER/examples" -o "$OUT" "$COMPILER/examples/Shop" >/dev/null 2>&1

echo "==============================================================="
echo "1. ELIXIR — the quoted remote call, against today's Shop.beam"
echo "==============================================================="
cat > "$WORK/q.exs" <<'EXEOF'
Code.prepend_path(System.get_env("BS_EBIN"))
run = fn s ->
  r = try do
        {v, _} = Code.eval_string(s); v
      rescue e -> {:raised, e.__struct__} end
  IO.puts("    " <> String.pad_trailing(s, 42) <> inspect(r))
end
run.(~s|:Shop.New(1)|)
run.(~s|apply(:Shop, :New, [1])|)
run.(~s|:Shop."New"(1)|)
run.(~s/1 |> :Shop."New"() |> :Shop."Pay"()/)
run.(~s|(&:Shop."New"/1).(4)|)
run.(~s|s = :Shop; s."New"(1)|)
run.(~s|:Shop.new(1)|)
fmt = fn s -> s |> Code.format_string!() |> IO.iodata_to_binary() end
IO.puts("\n    the formatter keeps the quotes a capital needs, and drops the ones it does not:")
IO.puts("    " <> fmt.(~s/x = 1 |> :Shop."New"() |> :Shop."Pay"()/))
IO.puts("    " <> fmt.(~s|:lists."reverse"([1])|))
EXEOF
BS_EBIN="$OUT" elixir "$WORK/q.exs" 2>&1

echo
echo "==============================================================="
echo "2. ELIXIR — is a quoted call checked when a module is compiled?"
echo "==============================================================="
mkdir -p "$WORK/ex"
cat > "$WORK/ex/caller.ex" <<'EXEOF'
defmodule Caller do
  def ok(id), do: id |> :Shop."New"() |> :Shop."Pay"()
  def typo(id), do: :Shop."Nwe"(id)
  def arity(id), do: :Shop."New"(id, 2)
end
EXEOF
(cd "$WORK/ex" && elixirc -pa "$OUT" -o "$WORK/ex" caller.ex 2>&1 | grep 'warning' | sed 's/^ */    /')

echo
echo "==============================================================="
echo "3. THE SAME TAX, THE OTHER WAY — Erlang calling Elixir"
echo "==============================================================="
ELIXIR_EBIN="$(elixir -e 'IO.puts(:code.lib_dir(:elixir))' 2>/dev/null)/ebin"
erl -noshell -pa "$ELIXIR_EBIN" -eval "
  io:format(\"    'Elixir.String':upcase(<<\\\"a\\\">>) -> ~p~n\", ['Elixir.String':upcase(<<\"a\">>)]),
  halt(0)." 2>&1

echo
echo "==============================================================="
echo "4. GLEAM — 62a compiled the declaration; this runs the call"
echo "==============================================================="
if ! command -v gleam >/dev/null 2>&1; then
    echo "    SKIPPED — no gleam on PATH."
else
    G="$WORK/gl"; mkdir -p "$G"
    (cd "$G" && gleam new caller >/dev/null 2>&1)
    # No dependencies, so the build needs no network.
    printf 'name = "caller"\nversion = "1.0.0"\n[dependencies]\n[dev_dependencies]\n' > "$G/caller/gleam.toml"
    rm -rf "$G/caller/test"
    cat > "$G/caller/src/caller.gleam" <<'GLEOF'
pub type Order

@external(erlang, "Shop", "New")
pub fn shop_new(id: Int) -> Order

@external(erlang, "Shop", "Pay")
pub fn shop_pay(o: Order) -> Order

pub type Colour {
  DarkRed
}

pub fn paid_order(id: Int) -> Order {
  shop_pay(shop_new(id))
}
GLEOF
    (cd "$G/caller" && gleam build >/dev/null 2>&1)
    grep -n "'Shop'\|dark_red\|^-export" "$G/caller/build/dev/erlang/caller/_gleam_artefacts/caller.erl" | sed 's/^/    /'
    erl -noshell -pa "$OUT" -pa "$G/caller/build/dev/erlang/caller/ebin" -eval \
      "io:format(\"    caller:paid_order(5) -> ~p~n\", [caller:paid_order(5)]), halt(0)." 2>&1
fi

echo
echo "==============================================================="
echo "5. WHAT A LOWERCASE SECOND EXPORT WOULD BE — forwarders added by hand"
echo "==============================================================="
# Reads the abstract forms bsc wrote, adds `new(A1) -> 'New'(A1).` for every
# author export, and compiles both. The lowering here is first-letter only;
# which rule it should be is a question this probe does not answer.
cat > "$WORK/fwd.escript" <<'ESEOF'
#!/usr/bin/env escript
main([Abstr, Out]) ->
    {ok, Forms} = file:consult(Abstr),
    [M | Rest0] = Forms,
    {value, {attribute, A, export, Ex}, Rest} = lists:keytake(export, 3, Rest0),
    Author = [E || {N, _} = E <- Ex, N =/= 'bs@type_atoms'],
    Lower = fun(N) -> [H | T] = atom_to_list(N), list_to_atom([string:to_lower(H) | T]) end,
    Vars = fun(Ar) -> [{var, 0, list_to_atom("A" ++ integer_to_list(I))} || I <- lists:seq(1, Ar)] end,
    Fwd = [{function, 0, Lower(N), Ar,
            [{clause, 0, Vars(Ar), [], [{call, 0, {atom, 0, N}, Vars(Ar)}]}]}
           || {N, Ar} <- Author],
    New = [M, {attribute, A, export, Ex ++ [{Lower(N), Ar} || {N, Ar} <- Author]} | Rest] ++ Fwd,
    {ok, _, Bin0} = compile:forms(Forms, [return_errors]),
    {ok, Mod, Bin} = compile:forms(New, [return_errors]),
    ok = file:write_file(filename:join(Out, atom_to_list(Mod) ++ ".beam"), Bin),
    D = byte_size(Bin) - byte_size(Bin0),
    io:format("    ~p author exports; beam ~p -> ~p bytes (+~p, ~p per function)~n",
              [length(Author), byte_size(Bin0), byte_size(Bin), D, D div length(Author)]).
ESEOF
mkdir -p "$WORK/ebin2"
escript "$WORK/fwd.escript" "$OUT/Shop.abstr" "$WORK/ebin2"
cat > "$WORK/q2.exs" <<'EXEOF'
Code.prepend_path(System.get_env("BS_EBIN"))
IO.puts("    1 |> :Shop.new() |> :Shop.pay()         " <> inspect(1 |> :Shop.new() |> :Shop.pay()))
IO.puts("    and a crash reached through :Shop.band(:x) is reported as:")
try do
  :Shop.band(:x)
rescue
  e -> Exception.format(:error, e, __STACKTRACE__) |> String.split("\n") |> Enum.take(2)
       |> Enum.each(&IO.puts("    " <> &1))
end
EXEOF
BS_EBIN="$WORK/ebin2" elixir "$WORK/q2.exs" 2>&1 | sed "s|$COMPILER/||"

echo
echo "==============================================================="
echo "6. CENSUS — public names in compiler/examples"
echo "==============================================================="
grep -rhoE '^public [^(]*[ >]([A-Z][A-Za-z0-9]*)\(' "$COMPILER/examples" --include='*.bs' \
  | sed -E 's/.*[ >]([A-Z][A-Za-z0-9]*)\($/\1/' > "$WORK/names.txt"
printf '    %s public declarations, %s distinct names, %s of them a single word\n' \
  "$(wc -l < "$WORK/names.txt" | tr -d ' ')" \
  "$(sort -u "$WORK/names.txt" | wc -l | tr -d ' ')" \
  "$(sort -u "$WORK/names.txt" | grep -cE '^[A-Z][a-z0-9]*$')"
echo "done."
