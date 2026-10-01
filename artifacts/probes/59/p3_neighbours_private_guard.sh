#!/usr/bin/env bash
# Ticket 59 survey: does a neighbour language emit a runtime type/tag test on a LOCAL (non-exported) function
# for a value that arrived through an exported one? Measured by feeding a forged value through the public door.
export PATH=/tmp/tools:$PATH
W=$(mktemp -d); cd "$W"
echo "== Elixir: defp with a struct pattern, forged map arrives nested in a list through def"
cat > s.ex <<'EOF'
defmodule Shop do
  defstruct [:id, :total]
  def sum_all(os), do: Enum.sum(Enum.map(os, &one/1))
  defp one(%Shop{total: t}), do: t          # struct pattern = tag test (__struct__ key)
  defp one_untagged(o), do: o.total          # projection only
  def sum_untagged(os), do: Enum.sum(Enum.map(os, &one_untagged/1))
end
EOF
elixirc s.ex 2>&1 | head -2
elixir -pa . -e '
  forged = %{__struct__: Other, id: 1, total: 100}
  try do IO.inspect(Shop.sum_all([forged])) rescue e -> IO.puts("sum_all (struct pattern in defp): " <> inspect(e.__struct__)) end
  IO.puts("sum_untagged (projection only): " <> inspect(Shop.sum_untagged([forged])))'
echo "== Gleam: no run-time test exists to ask -- types are erased and nothing guards a pub fn either"
mkdir -p g/src && cd g && printf 'name = "g"\nversion = "1.0.0"\ntarget = "erlang"\n' > gleam.toml
cat > src/g.gleam <<'EOF'
pub type Order { Order(id: Int, total: Int) }
pub fn sum_all(os: List(Order)) -> Int { one(os) }
fn one(os: List(Order)) -> Int {
  case os { [Order(_, t), ..] -> t  [] -> 0 }
}
EOF
gleam build 2>&1 | tail -1
erl -noshell -pa build/dev/erlang/g/ebin -eval 'io:format("pub fn sum_all fed a forged 2-tuple of a different tag: ~p~n",[try g:sum_all([{invoice, 1, 100}]) catch C:R -> {C,R} end]), io:format("pub fn sum_all fed a 3-tuple: ~p~n",[try g:sum_all([{order, 1, 2, 3}]) catch C2:R2 -> {C2,R2} end]), halt().'
