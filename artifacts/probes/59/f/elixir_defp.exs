# Elixir 1.20.4 / OTP 29: does a defp head with a struct pattern check the tag? does anything check types in defp?
[{Probe, bin} | _] = Enum.filter(Code.compile_file("elixir_defp_mod.ex"), fn {m, _} -> m == Probe end)
{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(bin, [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, Probe, data, [])
for {:function, _, n, _, _} = f <- forms, n in [:amount, :amount_raw, :via_cart],
    do: IO.puts(:erl_pp.function(f))

inv  = %{__struct__: Probe.Invoice, id: 1, total: 999}
cart = struct(Probe.Cart, item: inv)
for {name, f} <- [
  {"via_cart(%Cart{item: %Invoice{}})  -> defp amount(%Order{})", fn -> Probe.via_cart(cart) end},
  {"via_cart_raw(%Cart{item: %Invoice{}}) -> defp amount_raw(o)", fn -> Probe.via_cart_raw(cart) end}
] do
  r = try do {:returned, f.()} rescue e -> {:raised, e.__struct__} end
  IO.puts("  #{String.pad_trailing(name, 66)} => #{inspect(r)}")
end
# @enforce_keys guards construction only; a map literal bypasses it
r = try do struct!(Probe.Order, []) rescue e -> e.__struct__ end
IO.puts("  struct!(Order, [])  (no :id)                    => #{inspect(r)}")
IO.puts("  forged %{__struct__: Order} (no :id) through via_cart => #{inspect(Probe.via_cart(struct(Probe.Cart, item: %{__struct__: Probe.Order, total: 7})))}")
