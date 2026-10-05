#!/usr/bin/env bash
# P15: the Elixir-side facade avenue (no B# compiler change): can Elixir callers get snake_case names themselves?
# CLAIM: `defdelegate new(id), to: :Shop, as: :New` compiles and runs against the UNMODIFIED compiler's beams.
# REFUTED IF elixirc rejects it or the call fails. Also counts the lines a facade for a whole module costs.
. "$(dirname "$0")/lib.sh"
W="$SCRATCH/p15"; rm -rf "$W"; mkdir -p "$W/ebin" "$W/c"
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
cat > "$W/c/facade.ex" <<'EXEOF'
defmodule MyApp.Shop do
  defdelegate new(id), to: :Shop, as: :New
  defdelegate which(doc), to: :Shop, as: :Which
  defdelegate pay(order), to: :Shop, as: :Pay
end
EXEOF
(cd "$W/c" && elixirc -pa "$W/ebin" -o "$W/c" facade.ex 2>&1 | head -5; echo "elixirc exit=${PIPESTATUS[0]}")
elixir -pa "$W/ebin" -pa "$W/c" -e '
  o = MyApp.Shop.new(4)
  IO.inspect(o, label: "MyApp.Shop.new(4)")
  IO.inspect(MyApp.Shop.which(o), label: "MyApp.Shop.which(o)")
  IO.inspect(MyApp.Shop.pay(o), label: "MyApp.Shop.pay(o)")'
echo "--- the typo case at compile time (does the xref check see through defdelegate?)"
cat > "$W/c/typo.ex" <<'EXEOF'
defmodule MyApp.ShopTypo do
  defdelegate new(id), to: :Shop, as: :Nwe
end
EXEOF
(cd "$W/c" && elixirc -pa "$W/ebin" -o "$W/c" typo.ex 2>&1 | head -6)
