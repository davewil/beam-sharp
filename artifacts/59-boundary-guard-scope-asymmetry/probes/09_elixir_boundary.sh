#!/bin/bash
# Probe 09 (survey): Elixir 1.14.0 on OTP 25 (the installed Elixir cannot boot on OTP 28; tickets
# measured 1.19.5, which has a gradual type system this one lacks - the claims below are about
# 1.14 only). Question: does the compiler treat def and defp differently at the boundary, and
# what do @enforce_keys / %S{} / is_struct actually check?
cd "$(dirname "$0")"; export PATH=/usr/bin:/bin
W=$(mktemp -d); cd $W
cat > guard_probe.ex <<'EX'
defmodule Order do
  @enforce_keys [:id, :total]
  defstruct [:id, :total]
end
defmodule Probe do
  # same body, def vs defp: bare parameter
  def pub_bare(o), do: o.total
  defp priv_bare(o), do: o.total
  def via_bare(o), do: priv_bare(o)
  # same, with a struct pattern in the head
  def pub_pat(%Order{} = o), do: o.total
  defp priv_pat(%Order{} = o), do: o.total
  def via_pat(o), do: priv_pat(o)
  # nested: struct pattern at the top only
  def nested(%{item: item}), do: priv_pat(item)
  # guard form
  def pub_guard(o) when is_struct(o, Order), do: o.total
  # int
  def pub_int(n) when is_integer(n), do: priv_int(n)
  defp priv_int(n), do: n * 2
  def field_int(%{qty: q}), do: priv_int(q)
end
EX
elixirc guard_probe.ex >/dev/null 2>&1 || elixirc guard_probe.ex
echo "=== abstract code of Elixir.Probe (guards the compiler produced, def vs defp) ==="
erl -noshell -pa /usr/lib/elixir/lib/elixir/ebin -eval '{ok,{_,[{abstract_code,{_,F}}]}}=beam_lib:chunks("Elixir.Probe.beam",[abstract_code]), [io:format("~s~n",[erl_pp:function(X)]) || X={function,_,N,_,_}<-F, N=/=module_info], halt().'
echo "=== exports (defp is simply not exported; nothing else differs) ==="
erl -noshell -eval '{ok,{_,[{exports,E}]}}=beam_lib:chunks("Elixir.Probe.beam",[exports]), io:format("~p~n",[E]), halt().'
echo "=== runtime: struct patterns check only __struct__; @enforce_keys is construction-time only ==="
cat > run.exs <<'EX'
IO.inspect(Probe.pub_pat(%Order{id: 1, total: 7}), label: "pub_pat good")
r = fn l, f -> IO.inspect((try do {:ok, f.()} rescue e -> {:error, e.__struct__} catch k, v -> {k, v} end), label: l) end
r.("pub_bare(%{total: 1})  (no check at all)", fn -> Probe.pub_bare(%{total: 1}) end)
r.("pub_pat(%{total: 1})   (head pattern refuses)", fn -> Probe.pub_pat(%{total: 1}) end)
r.("via_pat(%{total: 1})   (def->defp: defp's own pattern refuses)", fn -> Probe.via_pat(%{total: 1}) end)
r.("via_bare(%{total: 1})  (def->defp bare: nothing refuses)", fn -> Probe.via_bare(%{total: 1}) end)
r.("nested(%{item: %{total: 1}}) (defp pattern is the only check)", fn -> Probe.nested(%{item: %{total: 1}}) end)
r.("pub_pat(%Order{id: 1}) via struct/2? bypass @enforce_keys:", fn -> Probe.pub_pat(struct(Order, id: 1)) end)
r.("pub_pat(%{__struct__: Order, total: 9}) forged map accepted", fn -> Probe.pub_pat(%{__struct__: Order, total: 9}) end)
r.("pub_int(1.5)", fn -> Probe.pub_int(1.5) end)
r.("field_int(%{qty: 1.5}) -> defp priv_int", fn -> Probe.field_int(%{qty: 1.5}) end)
EX
elixir -pa . run.exs 2>&1
echo "=== @enforce_keys at the literal: a compile-time check on the %Order{} construction expression only ==="
cat > enf.exs <<'EX'
try do
  Code.eval_string("%Order{id: 1}")
rescue e -> IO.puts("literal %Order{id: 1}: " <> inspect(e.__struct__) <> ": " <> Exception.message(e))
end
EX
elixir -pa . enf.exs 2>&1 | head -4
