#!/usr/bin/env bash
# CLAIM (neighbour survey): Elixir enforces only def/defp; `@moduledoc false` / `@doc false`
# hide from docs and do not stop another module calling the function. Boundary-style
# libraries are NOT installed, so nothing is claimed about them.
# No Elixir .ex sources are installed (beams only); this records what the 1.19.5 binary did.
# REFUTED IF: the outsider call to a `@doc false`/`@moduledoc false` function fails to compile
# or warns, OR a call to a defp from another module compiles.
. "$(dirname "$0")/lib.sh"
E="$WORK/elixir"; rm -rf "${E:?}"; mkdir -p "$E/ebin"; cd "$E" || exit 1
elixir --version | tail -1
cat > shop.ex <<'EOT'
defmodule Shop.Internal do
  @moduledoc false
  @doc false
  def recompute(xs), do: sum(xs, 0)
  defp sum([], acc), do: acc
  defp sum([x | r], acc), do: sum(r, acc + x)
end
defmodule Outsider do
  def peek(xs), do: Shop.Internal.recompute(xs)
end
EOT
echo '--- compile (warnings, if any, are printed here)'
elixirc -o ebin shop.ex 2>&1; echo "exit=$?"
echo '--- call from the unrelated module'
elixir -pa ebin -e 'IO.inspect(Outsider.peek([1,2,3]))' ; rc=$?
echo '--- docs chunk: what @moduledoc false / @doc false actually record'
elixir -pa ebin -e '{:docs_v1, _, _, _, moddoc, _, docs} = Code.fetch_docs(Shop.Internal); IO.inspect(moddoc, label: "moduledoc"); IO.inspect(Enum.map(docs, fn {k,_,_,d,_} -> {k, d} end), label: "per-function doc")'
echo '--- defp from another module (the shipped Elixir analogue of F12): compile error?'
cat > priv.ex <<'EOT'
defmodule Shop.Internal2 do
  defp sum(xs), do: Enum.sum(xs)
  def ok(xs), do: sum(xs)
end
defmodule Outsider2 do
  def peek(xs), do: Shop.Internal2.sum(xs)
end
EOT
elixirc -o ebin priv.ex 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}"
echo '--- mix help xref: the modes it offers (documentation text of the installed mix; no restriction mode is listed)'
mix help xref 2>&1 | grep -E '^## |^  \* ' | head -20
verdict "elixir-hides-from-docs-but-does-not-enforce" $rc
