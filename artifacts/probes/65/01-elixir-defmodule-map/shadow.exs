# Ticket 48 Q9 / 65: "defmodule Map warns, clobbers the standard module, then crashes
# Elixir's own type checker (Module.Types.local_handler, measured on 1.19.5)".
# This script re-measures on whatever Elixir is on PATH. It prints what it sees.
IO.puts("elixir #{System.version()} otp #{:erlang.system_info(:otp_release)}")

defmodule Map do
  def get(_m, _k), do: :mine_not_stdlibs
end

IO.puts("Map.get(%{a: 1}, :a)           => #{inspect(Map.get(%{a: 1}, :a))}")

# Which stdlib functions of the clobbered module are still there?
for {f, a} <- [{:put, 3}, {:update!, 3}, {:new, 0}, {:keys, 1}, {:fetch, 2}, {:merge, 2}] do
  IO.puts("function_exported?(Map, #{f}, #{a}) => #{function_exported?(Map, f, a)}")
end

# Does the rest of the standard library still work? Each call goes through a
# try so one crash does not hide the others.
probes = [
  {"Enum.into([a: 1], %{})", fn -> Enum.into([a: 1], %{}) end},
  {"Map.new([a: 1])", fn -> Map.new(a: 1) end},
  {"struct(URI, host: \"x\")", fn -> struct(URI, host: "x") end},
  {"Keyword.get([a: 1], :a)", fn -> Keyword.get([a: 1], :a) end},
  {"URI.parse(\"http://x/y\")", fn -> URI.parse("http://x/y") end},
  {"Registry via Map.put (Mix-free)", fn -> Map.put(%{}, :a, 1) end},
  {"inspect(%{a: 1})", fn -> inspect(%{a: 1}) end},
  {"Access.get(%{a: 1}, :a)", fn -> Access.get(%{a: 1}, :a) end},
  {"Kernel.update_in(%{a: 1}, [:a], & &1)", fn -> update_in(%{a: 1}, [:a], & &1) end},
  {"Enum.group_by([1,2], & &1)", fn -> Enum.group_by([1, 2], & &1) end}
]

for {label, f} <- probes do
  r = try do
    "ok #{inspect(f.())}"
  rescue
    e -> "RAISED #{inspect(e.__struct__)}: #{Exception.message(e)}"
  end
  IO.puts("#{String.pad_trailing(label, 40)} #{r}")
end
