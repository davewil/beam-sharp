# Probe 10: Elixir's own acronym-aware PascalCase->snake rule on the same names; shows where rule choice
# changes the answer and where two distinct B# names collapse.
names = ~w(ToJson HTTPGet IOError Take2 GetID GetId Foo A AB URLs Ver1Beta Ver_1_Beta ParseURL ParseUrl Get_Id ModuleInfo HandleCall Length)
for n <- names, do: IO.puts(String.pad_trailing(n, 12) <> Macro.underscore(n))
IO.puts("--- collisions under Macro.underscore")
names |> Enum.group_by(&Macro.underscore/1) |> Enum.filter(fn {_, v} -> length(v) > 1 end) |> Enum.each(&IO.inspect/1)
