IO.puts("Elixir " <> System.version() <> " Macro.underscore/1 (Elixir's own PascalCase->snake_case):")
for f <- ~w(GetHTTPServer ParseURL ParseUrl ABC Abc Get2D Get_Value GetValue Get_value F1 F_1 HTTP Http ModuleInfo ABc ABTest XMLHttpRequest IOError V8Engine HTMLElement) do
  IO.puts("  " <> String.pad_trailing(f, 14) <> Macro.underscore(f))
end
by = Enum.group_by(~w(ABC Abc Get_Value GetValue ParseURL ParseUrl), &Macro.underscore/1) |> Enum.filter(fn {_, v} -> length(v) > 1 end)
IO.inspect(by, label: "Macro.underscore collisions")
