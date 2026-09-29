# PROBE 5 — how does Elixir 1.14 name functions it emits from `def`? (No Elixir source is
# installed under /usr/lib/elixir, only ebin, so behaviour is probed, never cited.)
#
# EXPECTED (before run):
#   exports of the module = [:valid?/1, :fetch!/1, :get_x/1, ...] i.e. atoms, snake_case by
#   convention, with ?/! as ordinary atom characters ('valid?', 'fetch!').
#   Elixir CAN define a PascalCase function only through unquote(:New): compiles, exports 'New'/1,
#   and calling it needs the quoted spelling. `def New(x)` (bare) is a compile error / alias misuse.
#   ==> Elixir's own ecosystem never produces a PascalCase export by default, so a B# PascalCase
#   export is the outlier a Elixir caller meets.
[{m, _}] = Code.compile_string(~S'''
defmodule Naming do
  def get_x(x), do: x
  def valid?(x), do: x
  def fetch!(x), do: x
  def unquote(:New)(x), do: x
end
''')
IO.inspect(m.__info__(:functions) |> Enum.sort(), label: "exports")
IO.inspect(Naming."New"(1), label: "Naming.\"New\"(1)")
bare = try do Code.compile_string("defmodule Bare do\n def New(x), do: x\nend"); :compiled rescue e -> {:error, e.__struct__} end
IO.inspect(bare, label: "def New(x) bare")
