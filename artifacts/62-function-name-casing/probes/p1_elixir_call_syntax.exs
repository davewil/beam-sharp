# Probe 1: which Elixir 1.14 call spellings reach a PascalCase export?
# Run:  erlc -o ebin src/Shop.erl && elixir p1_elixir_call_syntax.exs ebin
# Exit status 1 if any internal consistency assertion fails.
[ebin] = System.argv()
Code.prepend_path(ebin)
{:module, :Shop} = Code.ensure_loaded(:Shop)

# classify(src): :syntax_error | {:ok, value} | {:raised, kind}
classify = fn src ->
  case Code.string_to_quoted(src) do
    {:error, _} -> :syntax_error
    {:ok, _} ->
      try do
        {v, _} = Code.eval_string(src)
        {:ok, v}
      rescue e -> {:raised, e.__struct__}
      catch k, _ -> {:raised, k}
      end
  end
end

cases = String.split(~S"""
:Shop.New(1)
:Shop."New"(1)
:Shop.'New'(1)
:"Shop"."New"(1)
1 |> :Shop."New"()
(&:Shop."New"/1).(1)
apply(:Shop, :New, [1])
Kernel.apply(:Shop, :New, [1])
:erlang.apply(:Shop, :New, [1])
:Shop.new(1)
:Shop.Which(%{Kind: :"Shop.Order"})
:Shop."Which"(%{Kind: :"Shop.Order"})
:Shop.NoSuch(1)
:Shop."NoSuch"(1)
""", "\n", trim: true)

results = for c <- cases, do: {c, classify.(c)}
for {c, r} <- results, do: IO.puts(String.pad_trailing(c, 52) <> inspect(r))

get = fn s -> {_, r} = List.keyfind(results, s, 0); r end
ref = get.(~S"apply(:Shop, :New, [1])")
IO.puts("\n--- assertions (observed vs observed; nothing hard-coded as a result) ---")
chk = fn ok, msg -> IO.puts((if ok, do: "PASS  ", else: "FAIL  ") <> msg); ok end
new_spellings = Enum.filter(results, fn {c, _} -> String.contains?(c, ":New") or String.contains?(c, ~S|"New"|) or String.contains?(c, ".new(") end)
oks = [
  chk.(match?({:ok, %{}}, ref), "reference apply/3 returns a map (harness sanity)"),
  chk.(not match?({:ok, _}, get.(~S":Shop.NoSuch(1)")), "control: nonexistent fn via dot syntax is NOT ok"),
  chk.(not match?({:ok, _}, get.(~S':Shop."NoSuch"(1)')), "control: nonexistent fn via quoted syntax is NOT ok"),
  chk.(Enum.all?(new_spellings, fn {_, {:ok, v}} -> v == elem(ref, 1); _ -> true end),
       "every New-spelling that returned ok returned the same map as apply/3")
]
IO.puts("\nOBSERVED :Shop.New(1)      -> #{inspect get.(~S":Shop.New(1)")}")
IO.puts("OBSERVED :Shop.\"New\"(1)  -> #{inspect get.(~S':Shop."New"(1)')}")
System.halt(if Enum.all?(oks), do: 0, else: 1)
