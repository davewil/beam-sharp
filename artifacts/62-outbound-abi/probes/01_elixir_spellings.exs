# Probe 01 -- EVERY Elixir spelling of a call to a PascalCase B# export.
# Run: ./01_elixir_spellings.sh   (compiles Shop with bsc, then runs this file)
# Each case reports  parse / compile+run  separately, with the exact error text.
Code.prepend_path(System.get_env("BS_EBIN"))
{:module, :Shop} = Code.ensure_loaded(:Shop)

row = fn label, src ->
  parse = case Code.string_to_quoted(src) do
    {:ok, _} -> "parses"
    {:error, {_, msg, _tok}} -> "PARSE ERROR: #{inspect(String.slice(String.replace(to_string(msg), ~r/\s+/, " "), 0, 60))}"
  end
  run = try do
    {v, _} = Code.eval_string(src)
    "runs -> #{inspect(v)}"
  rescue
    e -> "RAISES #{inspect(e.__struct__)}: #{String.replace(Exception.message(e), ~r/\s+/, " ") |> String.slice(0, 70)}"
  end
  IO.puts(String.pad_trailing(label, 22) <> String.pad_trailing(src, 62) <> parse <> "  |  " <> run)
end

for line <- File.read!(Path.join(__DIR__, "01_cases.tsv")) |> String.split("\n", trim: true) do
  case String.split(line, "\t", parts: 2) do
    ["##", title] -> IO.puts("--- " <> title)
    [label, src] -> row.(label, src)
  end
end

IO.puts("\n--- formatter: does `mix format` preserve / rewrite the quoted call?")
for src <- [~S|:Shop."New"(1)|, ~S|:Shop."New"(1)|] |> Enum.uniq() do
  IO.puts("  Code.format_string!(" <> src <> ") -> " <> IO.iodata_to_binary(Code.format_string!(src)))
end
IO.puts("\n--- F. compiled (not eval'd) forms, with compiler warnings visible")
src = ~S'''
defmodule Caller do
  # F1: defdelegate as the one-off adapter an Elixir team would write
  defdelegate new(id), to: :Shop, as: :New
  # F2: quoted dot call inside a function body
  def new2(id), do: :Shop."New"(id)
  # F3: capture in a pipeline
  def many(ids), do: Enum.map(ids, &:Shop."New"/1)
  # F4: macro generating the adapters from a list of PascalCase names (unquote)
  defmacro __using__(names) do
    for {n, ar} <- names do
      fname = n |> Atom.to_string() |> Macro.underscore() |> String.to_atom()
      args = Macro.generate_arguments(ar, __MODULE__)
      quote do
        def unquote(fname)(unquote_splicing(args)),
          do: :Shop.unquote(n)(unquote_splicing(args))
      end
    end
  end
end
defmodule Gen do
  use Caller, [New: 1, Amount: 1, Pay: 1]
end
'''
Code.compile_string(src)
IO.puts("F1 Caller.new(1)       -> " <> inspect(Caller.new(1)))
IO.puts("F2 Caller.new2(2)      -> " <> inspect(Caller.new2(2)))
IO.puts("F3 Caller.many([3,4])  -> " <> inspect(Caller.many([3,4])))
IO.puts("F4 Gen.new(5)          -> " <> inspect(Gen.new(5)))
IO.puts("F4 Gen.amount(Gen.pay(Gen.new(6))) -> " <> inspect(Gen.amount(Gen.pay(Gen.new(6)))))
IO.puts("F4 Gen exports         -> " <> inspect(Gen.__info__(:functions)))

IO.puts("\n--- the full error text Elixir gives for the natural spelling (does it point at the quoted call?)")
{:error, {_, msg, tok}} = Code.string_to_quoted(":Shop.New(1)")
IO.puts(msg <> tok)
IO.puts("mentions quoting the function name? " <> inspect(String.contains?(msg, "quote") and String.contains?(msg, "New\"")))
