# P7b: Elixir 1.14 -- def vs defp at the BEAM boundary, and a private function captured as a value.
defmodule Probe59 do
  def rule, do: &keep/1
  defp keep(n), do: n
  def out_int(n) when is_integer(n), do: keep(n)
end
IO.inspect(Probe59.rule().(1.5), label: "Probe59.rule().(1.5)")
IO.inspect((try do Probe59.out_int(1.5) rescue e -> e.__struct__ end), label: "out_int(1.5) (hand-written guard)") 
IO.inspect(:erlang.fun_info(Probe59.rule(), :type), label: "fun type")
IO.inspect(Enum.sort(Probe59.module_info(:exports)), label: "exports")
# Elixir library SOURCE is not installed (only ebin/), so no file:line is cited for Kernel.def/defp.
