defmodule Mixproj do
  def a(id), do: :Shop."New"(id)
  def pipe(id), do: id |> :Shop."New"() |> :Shop."Pay"() |> :Shop."Amount"()
  def cap, do: Enum.map([1, 2], &:Shop."New"/1)

  def m(id) do
    case :Shop."New"(id) do
      %{Kind: :"Shop.Order", Id: i} -> {:order, i}
    end
  end
end

defmodule Mixproj.Shim do
  @moduledoc "snake_case facade"
  @doc "make an order"
  defdelegate new(id), to: :Shop, as: :New
  defdelegate pay(o), to: :Shop, as: :Pay
  defdelegate amount(o), to: :Shop, as: :Amount
end
