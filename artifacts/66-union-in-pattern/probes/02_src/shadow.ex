defmodule Shadow do
  def f(%{kind: :a}), do: :a
  def f(%{kind: :a}), do: :a2
  def f(%{kind: :b}), do: :b
end
