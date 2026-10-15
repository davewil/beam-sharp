# 59_elixir.exs -- Elixir survey for ticket 59.
# Claim: Elixir inserts NO guard of its own on any function, public (def) or private (defp). A
# struct pattern `%S{}` is a user-written, visibility-blind tag test (map + __struct__ == S) that
# does not look at fields; @spec is not enforced; @enforce_keys acts at construction only.
# REFUTED if: a def/defp WITHOUT a pattern raises on a wrong argument; or `%Order{}` rejects a
# map that has the right __struct__ and wrong field types; or @enforce_keys blocks a map update
# or a hand-built %{__struct__: Order}.
defmodule Order do
  @enforce_keys [:id]
  defstruct [:id, :total]
end

defmodule Invoice do
  defstruct [:id, :total]
end

defmodule Wrapper do
  defstruct [:inner]
end

defmodule M do
  @spec nopattern(Order.t()) :: term   # spec is not a guard
  def nopattern(o), do: o

  def pub(%Order{} = o), do: priv_tagged(o)          # tag test written by the author
  def pub_untagged(o), do: priv_plain(o)             # no pattern anywhere
  def via_nested(%Wrapper{inner: i}), do: priv_tagged(i)    # nested, tag test lives in the defp
  def via_nested_plain(%Wrapper{inner: i}), do: priv_plain(i)

  defp priv_tagged(%Order{total: t}), do: t
  defp priv_plain(o), do: o
end

defmodule Runner do
  def go do
    forged_invoice = %{__struct__: Invoice, id: 1, total: 5}
    forged_order_bad_payload = %{__struct__: Order, id: 1, total: "str"}
    valid = %Order{id: 1, total: 5}

    run = fn label, f ->
      r = try do {:ok, f.()} rescue e -> {:raised, e.__struct__} catch k, v -> {k, v} end
      IO.puts(String.pad_trailing(label, 56) <> inspect(r))
    end

    run.("def nopattern(Invoice-tagged)  [@spec Order.t()]", fn -> M.nopattern(forged_invoice) end)
    run.("def pub(%Order{})  valid", fn -> M.pub(valid) end)
    run.("def pub(%Order{})  Invoice-tagged", fn -> M.pub(forged_invoice) end)
    run.("def pub(%Order{})  Order tag, total: \"str\"", fn -> M.pub(forged_order_bad_payload) end)
    run.("pub_untagged(Invoice-tagged) -> defp priv_plain", fn -> M.pub_untagged(forged_invoice) end)
    run.("via_nested(%Wrapper{inner: Invoice-tagged}) -> defp priv_tagged", fn -> M.via_nested(%Wrapper{inner: forged_invoice}) end)
    run.("via_nested_plain(... Invoice-tagged) -> defp priv_plain", fn -> M.via_nested_plain(%Wrapper{inner: forged_invoice}) end)
    run.("@enforce_keys: %Order{total: 1} (no :id)", fn -> Code.eval_string("%Order{total: 1}") end)
    run.("@enforce_keys: %{valid | id: nil}  (update)", fn -> %{valid | id: nil} end)
    run.("@enforce_keys: struct!(Order, total: 1)", fn -> struct!(Order, total: 1) end)
    run.("@enforce_keys: hand-built %{__struct__: Order}", fn -> %{__struct__: Order, total: 1} end)
  end
end

Runner.go()
