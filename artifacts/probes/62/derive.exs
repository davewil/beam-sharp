# Ticket 62 P3: how would a snake_case alias be DERIVED, and does it collide or look wrong on the real corpus?
root = System.argv() |> hd()
names =
  Path.wildcard(Path.join(root, "**/*.bs"))
  |> Enum.flat_map(fn f ->
    File.read!(f) |> String.split("\n")
    |> Enum.flat_map(fn l ->
      case Regex.run(~r/^public\s+.+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/, l) do
        [_, n] -> [{n, Path.dirname(f) |> Path.basename()}]
        _ -> []
      end
    end)
  end)
  |> Enum.uniq()

# Gleam's rule for constructor tags, as measured in probes/62/gl: every capital becomes _lower
gleam = fn n -> n |> String.replace(~r/([A-Z])/, "_\\1") |> String.downcase() |> String.trim_leading("_") end
elixir = &Macro.underscore/1

IO.puts("public functions in corpus: #{length(names)} (distinct names: #{names |> Enum.map(&elem(&1,0)) |> Enum.uniq() |> length})")
for {label, f} <- [{"gleam-naive", gleam}, {"Macro.underscore", elixir}] do
  groups = names |> Enum.group_by(fn {n, _} -> f.(n) end, fn {n, _} -> n end) |> Enum.map(fn {k, v} -> {k, Enum.uniq(v)} end)
  coll = Enum.filter(groups, fn {_, v} -> length(v) > 1 end)
  IO.puts("\n[#{label}] collisions between DISTINCT pascal names: #{length(coll)}")
  for {k, v} <- coll, do: IO.puts("   #{k} <- #{inspect(v)}")
  odd = names |> Enum.map(&elem(&1,0)) |> Enum.uniq() |> Enum.filter(&(String.match?(f.(&1), ~r/(^|_)[a-z](_|$)|__/)))
  IO.puts("   names with single-letter segments or double underscores: #{inspect(Enum.map(odd, &{&1, f.(&1)}))}")
end
IO.puts("\nsample (name -> gleam-naive | Macro.underscore):")
for {n,_} <- names |> Enum.take_random(0), do: n
for n <- ["HTTPServer", "ParseURL", "Utf8Decode", "ToJson", "FromJSON", "Sha256", "A", "IOList"], do:
  IO.puts("   #{String.pad_trailing(n, 12)} #{String.pad_trailing(gleam.(n), 16)} #{elixir.(n)}")
