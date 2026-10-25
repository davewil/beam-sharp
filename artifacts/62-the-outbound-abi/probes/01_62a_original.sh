#!/usr/bin/env bash
# PROTOTYPE 62a — what does a B# module look like from Elixir, Erlang and Gleam?
#
# Throwaway. Ticket 62. Raised by David 2026-08-25:
#   "B# modules called from elixir will presumably be FFI and require that
#    translation same way erlang or gleam do?"
#   ...and then: "Do you think a BSharp.Shop i.e with BSharp hidden prefix
#    inside B# would help or not needed if lowers to :Shop anyway?"
#
# Every measurement in this repo so far runs INBOUND — B# consuming Elixir.
# This is the other direction, which nothing in the map covered.
#
#   ./62a_from_the_outside.sh
#
# Requires: OTP 28, Elixir, a built bsc. The Gleam part needs `gleam` and
# self-skips without it. Run from the repo root.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

OUT="$WORK/ebin"; mkdir -p "$OUT"
"$BSC" --src-root "$COMPILER/examples" -o "$OUT" "$COMPILER/examples/Shop" >/dev/null 2>&1
"$BSC" --src-root "$COMPILER/examples" -o "$OUT" "$COMPILER/examples/Shop/Reports" >/dev/null 2>&1

echo "==============================================================="
echo "1. What does B# EMIT?"
echo "==============================================================="
echo "    module atoms, from the beam filenames:"
for f in "$OUT"/*.beam; do
    printf '        %s\n' "$(basename "$f" .beam)"
done
cat <<'EOF'

    So the module atom is the dotted path and nothing else -- `Shop`,
    `Shop.Reports`. No language-wide prefix. Compare:

        Erlang    shop                      (flat, lowercase)
        Elixir    Elixir.Shop               (prefixed)
        Gleam     deep@nested               (path, @-separated, no prefix)
        B#        Shop.Reports              (path, .-separated, no prefix)

EOF

echo "==============================================================="
echo "2. ERLANG — can it call in with ordinary syntax?"
echo "==============================================================="
erl -noshell -pa "$OUT" -eval "
  io:format(\"        'Shop':'New'(1)   -> ~p~n\", ['Shop':'New'(1)]),
  io:format(\"        'Shop':'Which'(_) -> ~p~n\",
            ['Shop':'Which'(#{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 2})]),
  halt(0)." 2>&1 | head -4
echo
echo "    Yes. Erlang quotes atoms freely, so PascalCase costs it nothing."

echo
echo "==============================================================="
echo "3. ELIXIR — and this is where it stops being symmetric"
echo "==============================================================="

cat > "$WORK/from_ex.exs" <<'EXEOF'
Code.prepend_path(System.get_env("BS_EBIN"))
p = fn l, v -> IO.puts("        " <> String.pad_trailing(l, 40) <> inspect(v)) end
syn = fn s -> case Code.string_to_quoted(s) do {:ok,_} -> :parses; _ -> :SYNTAX_ERROR end end
run = fn l, f ->
  r = try do f.() rescue e -> {:raised, e.__struct__} catch k, v -> {k, v} end
  IO.puts("        " <> String.pad_trailing(l, 40) <> inspect(r))
end

IO.puts("\n    (a) the exports are PascalCase:")
p.("exports", :Shop.module_info(:exports)
             |> Enum.reject(&(elem(&1,0) == :module_info)) |> Enum.sort())

IO.puts("\n    (b) can Elixir call them with dot syntax?")
p.(":Shop.New(1)", syn.(":Shop.New(1)"))
p.(":Shop.new(1)", syn.(":Shop.new(1)"))
p.("apply(:Shop, :New, [1])", syn.("apply(:Shop, :New, [1])"))

IO.puts("\n    ...and does a module PREFIX rescue it? (David's question)")
p.(~s|:"BSharp.Shop".New(1)|, syn.(~s|:"BSharp.Shop".New(1)|))
p.(~s|:"Shop.Reports".Totals(1)|, syn.(~s|:"Shop.Reports".Totals(1)|))
p.(~s|:"Elixir.Shop".New(1)|, syn.(~s|:"Elixir.Shop".New(1)|))
p.(~s|:"BSharp.Shop".new(1)|, syn.(~s|:"BSharp.Shop".new(1)|))

IO.puts("\n        No prefix helps -- not even Elixir's own. The blocker is")
IO.puts("        the capitalised FUNCTION name, and no module naming")
IO.puts("        scheme touches it.")

IO.puts("\n    (c) what does a B# record look like once it arrives?")
order = apply(:Shop, :New, [7])
p.("the value", order)
p.("is_struct?", is_struct(order))
p.("has :__struct__?", :maps.is_key(:__struct__, order))
p.("has :Kind?", :maps.is_key(:Kind, order))

IO.puts("\n    (d) can Elixir match it?")
m = case order do
      %{Kind: :"Shop.Order", Id: id} -> {:matched_as_a_map, id}
      _ -> :no
    end
p.("as a map pattern", m)
p.("as any struct (%_{})", (case order do %_{} -> :yes; _ -> :NOT_a_struct end))

IO.puts("\n    (e) can Elixir hand a value BACK that B# accepts?")
run.("right tag", fn -> apply(:Shop, :Which, [%{Kind: :"Shop.Order", Id: 9, Total: 5}]) end)
run.("wrong tag", fn -> apply(:Shop, :Which, [%{Kind: :"MyApp.Order", Id: 9, Total: 5}]) end)
run.("an Elixir struct, same fields",
     fn -> apply(:Shop, :Which, [%{__struct__: MyOrder, Id: 9, Total: 5}]) end)
EXEOF

BS_EBIN="$OUT" elixir "$WORK/from_ex.exs" 2>&1 | grep -v "^warning\|^  (elixir\|from_ex.exs:"

echo
echo "==============================================================="
echo "4. GLEAM — does it have the same trouble?"
echo "==============================================================="

if ! command -v gleam >/dev/null 2>&1; then
    echo "    SKIPPED — no gleam on PATH."
else
    G="$WORK/gl"; mkdir -p "$G"
    (cd "$G" && gleam new caller >/dev/null 2>&1)
    cat > "$G/caller/src/caller.gleam" <<'GLEOF'
import gleam/io

// Gleam names the foreign function as a STRING, so a PascalCase export is
// not a syntax problem the way it is in Elixir.
@external(erlang, "Shop", "New")
pub fn shop_new(id: Int) -> anything

pub fn main() {
  let _ = shop_new(3)
  io.println("called Shop:New/1 from gleam")
}
GLEOF
    echo "    building a gleam caller with @external(erlang, \"Shop\", \"New\")..."
    (cd "$G/caller" && ERL_LIBS="$OUT" gleam build 2>&1 | sed 's/^/        /' | head -12)
fi

cat <<'EOF'

===============================================================
VERDICT
===============================================================
    Calling INTO B# needs no declaration at all -- Erlang and Elixir
    are dynamic, so a B# module is just a .beam with exports. The FFI
    burden is entirely on the typed side, and it is NOT symmetric with
    B# calling out.

    But three frictions, and the first is Elixir's alone:

      1. Elixir cannot use dot syntax on a PascalCase export, and no
         module prefix fixes it. Callers are pushed to apply/3.
         Erlang is unaffected.

      2. A B# record arrives as a plain tagged map, not a struct. It
         can be matched as a map, but `%Order{}` is unavailable and it
         gets none of the struct machinery.

      3. The minted `Kind` tag is a REQUIRED part of the ABI. A caller
         must write it by hand to be accepted, and a wrong one is a
         FunctionClauseError. Ticket 26 calls `Kind` "the one key a
         construction may not name" -- inside B#. Outside it, everyone
         must name it. It is private and public at once.
done.
EOF
