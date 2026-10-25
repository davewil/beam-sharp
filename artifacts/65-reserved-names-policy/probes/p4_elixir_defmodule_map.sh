#!/usr/bin/env bash
# P4: ticket 48/65 claim: `defmodule Map` warns, clobbers stdlib Map, then crashes Elixir's type checker (Map.update!/3). Re-run on Elixir 1.20.4.
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"
D=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/65/p4; rm -rf $D; mkdir -p $D; cd $D
elixir --version 2>&1 | tail -2
cat > a_ticket_repro.exs <<'X'
defmodule Map do
  def get(_m, _k), do: :mine_not_stdlibs
end
IO.inspect(Map.get(%{a: 1}, :a), label: "Map.get after redefinition")
IO.inspect(Map.new([{1, 2}]) , label: "Map.new (stdlib fn) after redefinition")
X
echo "=== A: ticket's repro, as a script (elixir a_ticket_repro.exs)"; elixir a_ticket_repro.exs; echo "exit=$?"
cat > b_compiled.ex <<'X'
defmodule Map do
  def get(_m, _k), do: :mine
end
defmodule User do
  def run(m), do: Map.update!(m, :a, &(&1 + 1))
end
X
echo "=== B: same via elixirc (a file that also calls Map.update!/3 elsewhere)"; mkdir -p ebin; elixirc -o ebin b_compiled.ex; echo "exit=$?"
echo "=== C: control, a module that is NOT stdlib-named"
cat > c_control.exs <<'X'
defmodule MyMap do
  def get(_m, _k), do: :mine
end
IO.inspect(MyMap.get(%{a: 1}, :a), label: "control")
IO.inspect(Map.get(%{a: 1}, :a), label: "stdlib Map.get intact")
X
elixir c_control.exs; echo "exit=$?"
echo "=== D: code server view after A"
cat > d_which.exs <<'X'
defmodule Map do
  def get(_m, _k), do: :mine
end
IO.inspect(:code.which(Map), label: "code.which(Map)")
IO.inspect(Map.module_info(:exports) |> length(), label: "exports now")
IO.inspect(Map.__info__(:functions) |> length(), label: "functions now")
X
elixir d_which.exs; echo "exit=$?"
