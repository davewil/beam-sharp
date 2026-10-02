#!/usr/bin/env bash
# P4 - Elixir: are defp clause heads checked at runtime identically to def heads?
set -eu
W="${1:-$(mktemp -d)}/p4"; rm -rf "$W"; mkdir -p "$W"; cd "$W"
cat > probe.exs <<'X'
defmodule Shop.Customer, do: defstruct [:email]
defmodule Shop.Vendor,   do: defstruct [:email]

defmodule Shop do
  # public entry: a %Order{}-style check only on the top-level param
  def ship(%{customer: c}) when is_map(c), do: notify(c)
  def ship_pub(c), do: notify_pub(c)
  # defp with a %Struct{} head: checked at runtime exactly like def
  defp notify(%Shop.Customer{} = c), do: c.email
  # public counterpart with the same head
  def notify_pub(%Shop.Customer{} = c), do: c.email
  # defp with an integer guard
  def bump(x), do: inc(x)
  defp inc(x) when is_integer(x), do: x + 1
end

try_it = fn label, f ->
  r = try do {:ok, f.()} rescue e -> {:error, e.__struct__} end
  IO.puts(String.pad_trailing(label, 52) <> inspect(r))
end
try_it.("def  head %Customer{}  <- %Customer{}", fn -> Shop.notify_pub(struct(Shop.Customer, email: "a")) end)
try_it.("def  head %Customer{}  <- %Vendor{}", fn -> Shop.notify_pub(struct(Shop.Vendor, email: "v")) end)
try_it.("defp head via def ship <- %Vendor{} (forged sub-term)", fn -> Shop.ship(%{customer: struct(Shop.Vendor, email: "v")}) end)
try_it.("defp is_integer guard via def bump <- 1.5", fn -> Shop.bump(1.5) end)
X
elixir probe.exs | tee out.txt
grep -q 'forged sub-term).*{:error, FunctionClauseError}' out.txt
grep -q 'via def bump <- 1.5 .*{:error, FunctionClauseError}' out.txt
echo "ASSERT ok: defp heads raise FunctionClauseError for a forged sub-term, same as def"
