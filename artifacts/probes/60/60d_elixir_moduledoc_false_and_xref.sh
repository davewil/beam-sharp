#!/usr/bin/env bash
# PROBE 60d -- ticket 60 (ENG-242). Elixir 1.20.4, no network, no deps. Claims:
#   E1. `@moduledoc false` + `@doc false` are documentation switches only: another module calls
#       them with no warning and exit 0. Code.fetch_docs reports :hidden.
#   E2. CONTROL: a `defp` named from another module is flagged `undefined or private` (a warning,
#       compile exit 0 -- Elixir does not refuse) and raises UndefinedFunctionError at run time.
#   E3. `mix xref callers` is a QUERY over static call edges; `--fail-above N` turns it into a CI
#       gate. A literal call is found; a call through apply/3 with a run-time atom is NOT found.
#   E4. Boundary-style libraries (`use Boundary, deps: [...]`) are not installed: not probed.
set -uo pipefail
command -v mix >/dev/null || { echo "mix missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$W" && mix new lab --sup >/dev/null 2>&1 || { echo "mix new failed"; exit 2; }
cd lab && rm -f lib/lab.ex test/lab_test.exs
cat > lib/core.ex <<'E'
defmodule Lab.Core do
  @moduledoc false
  def sum(a, b), do: a + b
  @doc false
  def helper(n), do: n * 100
  defp hidden(n), do: n
  def uses_hidden(n), do: hidden(n)
end
E
cat > lib/stranger.ex <<'E'
defmodule Lab.Stranger do
  def direct(n), do: Lab.Core.sum(n, 1) + Lab.Core.helper(1)
  def dynamic(m, n), do: apply(m, :sum, [n, 2])
end
E
echo "--- E1 compile (expect exit 0, no warning lines)"
mix compile 2>&1 | grep -v -E '^Compiling|^Generated' ; echo "compile exit=${PIPESTATUS[0]}"
mix run -e '
  {:docs_v1, _, _, _, moduledoc, _, docs} = Code.fetch_docs(Lab.Core)
  IO.inspect(moduledoc, label: "moduledoc of Lab.Core")
  IO.inspect(for({{:function, n, a}, _, _, d, _} <- docs, do: {n, a, d}), label: "function docs")
  IO.inspect({Lab.Stranger.direct(1), Lab.Stranger.dynamic(Lab.Core, 1)}, label: "callers actually work")' 2>&1
echo "--- E3 mix xref callers Lab.Core (query; literal edges only)"
mix xref callers Lab.Core 2>&1
echo "--- E3 gate form: --fail-above 0"
mix xref callers Lab.Core --fail-above 0 >/dev/null 2>&1; echo "xref callers --fail-above 0 exit=$?"
echo "--- E3 only the dynamic caller present (remove direct): gate should NOT see it"
cat > lib/stranger.ex <<'E'
defmodule Lab.Stranger do
  def dynamic(m, n), do: apply(m, :sum, [n, 2])
end
E
mix compile >/dev/null 2>&1; mix xref callers Lab.Core --fail-above 0 2>&1 | tail -3; echo "xref callers --fail-above 0 exit=${PIPESTATUS[0]}  (0 = gate green although Stranger can call Core)"
echo "--- E2 CONTROL: defp across modules"
cat > lib/stranger.ex <<'E'
defmodule Lab.Stranger do
  def peek(n), do: Lab.Core.hidden(n)
end
E
mix compile 2>&1 | grep -E 'warning|error|undefined' | head -3; echo "compile exit=${PIPESTATUS[0]}"
mix run -e 'try do Lab.Stranger.peek(1) rescue e -> IO.puts("run: " <> Exception.message(e) |> String.slice(0,80)) end' 2>&1 | tail -1
