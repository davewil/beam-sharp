defmodule Weird do
  def unquote(:New)(x), do: {:new, x}
  def unquote(:"weird name")(x), do: {:weird, x}
  def unquote(:"GetById")(x), do: {:get, x}
  # Elixir-side callers of its own capitalised function:
  def selfcall, do: __MODULE__."New"(1)
end
