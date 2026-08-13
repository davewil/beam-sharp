# Measure: what does Elixir's exported name space contain that a mechanical
# snake_case -> PascalCase mapping cannot spell?
mods =
  :code.all_available()
  |> Enum.map(fn {m, _, _} -> to_string(m) end)
  |> Enum.filter(&String.starts_with?(&1, "Elixir."))
  |> Enum.map(&String.to_atom/1)

exports =
  for m <- mods,
      {f, a} <- (try do m.module_info(:exports) rescue _ -> [] end),
      f not in [:module_info, :__info__],
      do: {m, f, a}

names = exports |> Enum.map(fn {_, f, _} -> to_string(f) end) |> Enum.uniq()

plain? = &Regex.match?(~r/^[a-z][a-z0-9_]*$/, &1)
bang = Enum.filter(names, &String.ends_with?(&1, "!"))
quest = Enum.filter(names, &String.ends_with?(&1, "?"))
underscore = Enum.filter(names, &String.starts_with?(&1, "_"))
other = Enum.reject(names, &(plain?.(&1) or &1 in bang or &1 in quest or &1 in underscore))

IO.puts("Elixir modules loadable:     #{length(mods)}")
IO.puts("exported functions:          #{length(exports)}")
IO.puts("distinct function names:     #{length(names)}")
IO.puts("  plain [a-z][a-z0-9_]*:     #{Enum.count(names, plain?)}")
IO.puts("  ending in ! :              #{length(bang)}  e.g. #{inspect(Enum.take(bang, 6))}")
IO.puts("  ending in ? :              #{length(quest)}  e.g. #{inspect(Enum.take(quest, 6))}")
IO.puts("  leading underscore:        #{length(underscore)}  e.g. #{inspect(Enum.take(underscore, 6))}")
IO.puts("  everything else:           #{length(other)}  e.g. #{inspect(Enum.take(other, 20))}")

# Module atoms: what does a nested Elixir module actually look like?
IO.puts("\nmodule atom examples: #{inspect(Enum.take(Enum.filter(mods, &String.contains?(to_string(&1), ".Chars")), 3))}")

# Default-argument arity generation: does one source function export several arities?
{:ok, _} = Application.ensure_all_started(:elixir)
by_name = Enum.group_by(exports, fn {m, f, _} -> {m, f} end, fn {_, _, a} -> a end)
multi = Enum.filter(by_name, fn {_, as} -> length(as) > 1 end)
IO.puts("\nname/arity fan-out: #{length(multi)} of #{map_size(by_name)} pairs carry >1 arity " <>
        "(#{Float.round(100 * length(multi) / map_size(by_name), 1)}%)")
IO.puts("  e.g. #{inspect(Enum.take(multi, 5))}")

# Are the extra arities real functions, or do they delegate? Check one known default.
IO.puts("\nEnum.reduce arities: #{inspect(Enum.sort(for {_, :reduce, a} <- exports, do: a) |> Enum.uniq())}")
IO.puts("String.split arities: #{inspect(Enum.sort(for {String, :split, a} <- exports, do: a))}")
