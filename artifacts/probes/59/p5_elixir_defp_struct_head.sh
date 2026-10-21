#!/bin/sh
# 59 / probe 5 — Elixir: does a PRIVATE function (defp) with a struct pattern in its head still test the tag?
set -u
elixir --version | tail -1
elixir -e '
{m, bin} = Code.compile_string("""
defmodule Probe do
  defstruct [:id, :total]
  def pub(%Probe{} = o), do: priv(o)
  defp priv(%Probe{} = o), do: o.total
  def pub_plain(o), do: priv_plain(o)
  defp priv_plain(o), do: o.total
end
""") |> hd()
{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(bin, [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, m, data, [])
for {:function, _, name, _, clauses} <- forms, name in [:pub, :priv, :pub_plain, :priv_plain] do
  IO.puts(:erl_pp.form({:function, 0, name, 1, clauses}))
end' 2>&1 | grep -v '^$' | head -30
