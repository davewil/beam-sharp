{:ok, _} = Application.ensure_all_started(:ex_unit)
# Probe 2: does the quoted form survive real compilation, defdelegate, the
# formatter, and Macro.to_string?  Fails (exit 1) on any observed mismatch.
# Run: elixir p2_elixir_compiled_and_format.exs ebin ex/caller.ex
[ebin, file] = System.argv()
Code.prepend_path(ebin)
{out, warnings} = ExUnit.CaptureIO.capture_io(:stderr, fn ->
  send(self(), {:mods, Code.compile_file(file)})
end) |> then(fn w -> receive do {:mods, m} -> {m, w} end end)
IO.puts("compiled modules: #{inspect Enum.map(out, &elem(&1,0))}")
IO.puts("compiler warnings: #{inspect warnings}")
a = Caller.make(1); b = Caller.piped(2); c = Caller.cap().(3); d = Caller.new(4); e = Caller.alias_make(5)
IO.inspect([a,b,c,d,e], label: "results")
IO.puts("")
fmt = fn s -> Code.format_string!(s) |> IO.iodata_to_binary() end
for s <- [~S|:Shop."New"(1)|, ~S|:Shop.New(1)|] do
  r = try do fmt.(s) rescue e -> "RAISED " <> inspect(e.__struct__) end
  IO.puts("format #{s}  ->  #{r}")
end
q = Code.string_to_quoted!(~S|:Shop."New"(1)|)
IO.puts("Macro.to_string(quoted) -> #{Macro.to_string(q)}")
IO.puts("quoted AST            -> #{inspect q}")
ok = [
  a == %{Kind: :"Shop.Order", Id: 1, Total: 0},
  b[:Total] == 500 and b[:Id] == 2,   # piped result observed via Pay
  c[:Id] == 3, d[:Id] == 4, e[:Id] == 5,
  warnings == ""
]
IO.puts("\nassertions: #{inspect ok}")
System.halt(if Enum.all?(ok), do: 0, else: 1)
