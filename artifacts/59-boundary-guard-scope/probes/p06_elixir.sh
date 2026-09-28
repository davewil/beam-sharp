#!/bin/sh
# p06_elixir -- how Elixir 1.14 treats a struct pattern / is_integer guard in def vs defp.
# LABEL: MEASURED (real Elixir 1.14.0 on OTP 25; compiled with elixirc, forms read back from the beam debug_info).
# CAVEAT: Elixir compiled with OTP 24 running on 25 (see versions.out); the abstract forms are what matter here.
# PREDICTIONS (before the first run):
#   E1. `def e(%Order{} = o)` and `defp p(%Order{} = o)` lower to the SAME guard on the head
#       (an is_map + map_get('__struct__') =:= 'Elixir.Order' test), because the struct pattern is written
#       by the author and the compiler treats def and defp alike. Elixir has no def/defp scope rule for it.
#   E2. A forged bare map #{__struct__ => 'Elixir.Order'} passes the pattern (and @enforce_keys does not
#       run at all: it is checked only when the %Order{} literal is BUILT).
#   E3. `defp q(n) when is_integer(n)` behind a `def r(n) when is_integer(n)` loses the private test in the
#       BEAM (same erlc passes), i.e. Elixir inherits the same elision as the Erlang probes.
cd "$(dirname "$0")" || exit 1
mkdir -p work/ex && cd work/ex || exit 1
cat > order.ex <<'EX'
defmodule Order do
  @enforce_keys [:total]
  defstruct [:total, status: :draft]

  # exported, struct pattern in the head
  def e(%Order{} = o), do: p(o)
  # private, the author wrote the SAME pattern
  defp p(%Order{total: t}), do: t
  # nested: exported takes a wrapper and hands the field on
  def w(%{order: o}), do: p(o)
  # escape: private function returned as a value
  def esc, do: &p/1

  def r(n) when is_integer(n), do: q(n)
  defp q(n) when is_integer(n), do: n * 2
end
EX
elixirc order.ex 2>&1
echo "== forms of Elixir.Order:e/1, p/1, q/1 as the erlang abstract format (heads only) =="
elixir -pa . -e '
  {:ok, {_, [abstract_code: {_, forms}]}} = :beam_lib.chunks(~c"Elixir.Order.beam", [:abstract_code])
  for {:function, _, n, _, _} = f <- forms, n in [:e, :p, :q, :r], do: IO.puts(:erl_pp.form(f))
' 2>&1 | grep -v "^$"
echo
echo "== running: forged terms against def e/1, defp p/1 (via nested, escaped fun) and the int pair =="
elixir -pa . -e '
  forged = %{__struct__: Order, total: 99}
  IO.inspect(Order.e(forged), label: "e(forged, has :total)")
  IO.inspect(Order.w(%{order: forged}), label: "w(nested forged Order)")
  IO.inspect((try do Order.w(%{order: %{total: 7}}) rescue e -> {:error, e.__struct__} end), label: "w(nested non-struct map)")
  IO.inspect((try do Order.esc().(%{total: 7}) rescue e -> {:error, e.__struct__} end), label: "esc().(non-struct map)")
  IO.inspect((try do Order.e(%{__struct__: Order}) rescue e -> {:error, e.__struct__} end), label: "e(struct tag, no :total)")
  IO.inspect((try do struct!(Order, []) rescue e -> {:error, e.__struct__} end), label: "struct!(Order, []) [@enforce_keys at construction]")
  IO.inspect(Order.r(4), label: "r(4)")
  IO.inspect((try do Order.r(1.5) rescue e -> {:error, e.__struct__} end), label: "r(1.5)")
'  2>&1
