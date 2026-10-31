defmodule Caller do
  # quoted-function call syntax against a PascalCase export, in compiled code
  def make(id), do: :Shop."New"(id)
  def piped(id), do: id |> :Shop."New"() |> :Shop."Pay"()
  def cap, do: &:Shop."New"/1
  # an Elixir-side wrapper: the idiomatic adoption shim
  defdelegate new(id), to: :Shop, as: :New
  # the snake_case alias route
  def alias_make(id), do: :Shop.new(id)
end
