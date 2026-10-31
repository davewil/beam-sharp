defmodule Vacuous do
  @type c :: %{kind: :a} | %{kind: :b}
  @spec bad(c) :: atom
  def bad(%{kind: :a}), do: :a
  def bad(%{kind: :b}), do: :b
  def bad(%{kind: :e}), do: :e
end
