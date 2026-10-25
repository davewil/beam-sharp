# Probe 11: COST of candidate 2 ("snake_case aliases alongside"), measured on real bsc output.
# Reads the .abstr files bsc writes (the exact input of compile:file(from_abstr), bsc.erl:826-843),
# adds a derived alias per public function (export + a tail-calling definition + a copied -spec),
# recompiles with the same options, and compares .beam size, export count, compile time.
# This is a MODEL of the compiler delta (a pass over the forms at bs_emit.erl:75-77), not the delta itself;
# bs_emit.erl is NOT modified.
# Usage: elixir 11_alias_inject.exs <dir-with-.abstr> <rule: macro|gleam> <call: local|remote>

defmodule Alias do
  # Rule A: Elixir's acronym-aware Macro.underscore (HTTPGet -> http_get)
  def snake(:macro, n), do: Macro.underscore(n)
  # Rule B: gleam 1.19.1's observed rule (probe 09): every upper-case letter -> "_" <> lower, except first
  def snake(:gleam, <<c, rest::binary>>) do
    low = fn <<x>> when x in ?A..?Z -> <<x + 32>>; o -> o end
    tail = for <<x <- rest>>, into: "", do: (if x in ?A..?Z, do: "_" <> low.(<<x>>), else: <<x>>)
    low.(<<c>>) <> tail
  end

  def run(dir, rule, call) do
    for f <- Path.wildcard(Path.join(dir, "*.abstr")) |> Enum.sort() do
      {:ok, forms} = :file.consult(String.to_charlist(f))
      mod = Enum.find_value(forms, fn {:attribute, _, :module, m} -> m; _ -> nil end)
      exports = Enum.flat_map(forms, fn {:attribute, _, :export, l} -> l; _ -> [] end)
      authors = Enum.reject(exports, fn {n, _} -> String.starts_with?(Atom.to_string(n), "bs@") end)
      defined = for {:function, _, n, a, _} <- forms, do: {n, a}
      derived = for {n, a} <- authors, do: {n, a, String.to_atom(snake(rule, Atom.to_string(n)))}
      # collisions: alias equal to another alias, or to a function the module already defines
      by_alias = Enum.group_by(derived, fn {_, a, s} -> {s, a} end)
      dup = for {k, v} <- by_alias, length(v) > 1, do: {k, Enum.map(v, &elem(&1, 0))}
      clash = for {n, a, s} <- derived, s != n, {s, a} in defined, do: {{s, a}, n}
      same = for {n, a, s} <- derived, s == n, do: {n, a}   # e.g. `A` -> `a` is distinct; this is "no-op" names
      keep = for {n, a, s} <- derived, s != n, not Enum.any?(dup, fn {k, _} -> k == {s, a} end), {s, a} not in defined, do: {n, a, s}
      aliases = for {n, a, s} <- keep do
        vars = for i <- 1..a//1, do: {:var, 1, String.to_atom("V#{i}")}
        callee = case call do
          :local -> {:call, 1, {:atom, 1, n}, vars}
          :remote -> {:call, 1, {:remote, 1, {:atom, 1, mod}, {:atom, 1, n}}, vars}
        end
        {:function, 1, s, a, [{:clause, 1, vars, [], [callee]}]}
      end
      specs = for {n, a, s} <- keep, {:attribute, l, :spec, {{^n, ^a}, t}} <- forms, do: {:attribute, l, :spec, {{s, a}, t}}
      new = Enum.flat_map(forms, fn
        {:attribute, l, :export, lst} = e ->
          if Enum.any?(lst, fn {n, _} -> not String.starts_with?(Atom.to_string(n), "bs@") end),
            do: [e, {:attribute, l, :export, for({_, a, s} <- keep, do: {s, a})}], else: [e]
        x -> [x]
      end) ++ specs ++ aliases
      {_t0, {:ok, _, b0}} = :timer.tc(fn -> :compile.forms(forms, [:debug_info, :return_errors]) end)
      {_t1, r1} = :timer.tc(fn -> :compile.forms(new, [:debug_info, :return_errors]) end)
      case r1 do
        {:ok, _, b1} ->
          if out = System.get_env("OUT"), do: (File.mkdir_p!(out); File.write!(Path.join(out, "#{mod}.beam"), b1))
          Process.put(:tot, {elem(Process.get(:tot, {0, 0, 0}), 0) + byte_size(b0), elem(Process.get(:tot, {0, 0, 0}), 1) + byte_size(b1), elem(Process.get(:tot, {0, 0, 0}), 2) + length(keep)})
          # timing spread: 7 runs each
          tm = fn fs -> for _ <- 1..7, do: elem(:timer.tc(fn -> :compile.forms(fs, [:debug_info]) end), 0) |> Kernel./(1000) |> Float.round(1) end
          t_old = tm.(forms) |> Enum.sort(); t_new = tm.(new) |> Enum.sort()
          IO.puts("#{mod}: public=#{length(authors)} aliases=#{length(keep)} beam #{byte_size(b0)} -> #{byte_size(b1)} (+#{byte_size(b1) - byte_size(b0)} B, #{Float.round((byte_size(b1)-byte_size(b0))*100/byte_size(b0), 1)}%) compile ms min/med/max #{hd(t_old)}/#{Enum.at(t_old, 3)}/#{List.last(t_old)} -> #{hd(t_new)}/#{Enum.at(t_new, 3)}/#{List.last(t_new)}")
        e -> IO.puts("#{mod}: ALIAS BUILD FAILED #{inspect(e, limit: :infinity)}")
      end
      for {k, v} <- dup, do: IO.puts("   COLLISION alias #{inspect(k)} <- #{inspect(v)}")
      for {k, n} <- clash, do: IO.puts("   CLASH alias #{inspect(k)} (from #{inspect(n)}) equals an existing function")
      for {n, a} <- same, do: IO.puts("   no-op #{inspect({n, a})}")
      if System.get_env("LIST"), do: (for {n, a, s} <- keep, do: IO.puts("   #{n}/#{a} -> #{s}"))
    end
    {a, b, n} = Process.get(:tot, {0, 0, 0})
    if a > 0, do: IO.puts("TOTAL beam #{a} -> #{b} (+#{b - a} B, #{Float.round((b - a) * 100 / a, 1)}%), #{n} aliases, #{Float.round((b - a) / max(n, 1), 1)} B per alias")
  end
end
[dir, rule, call] = System.argv()
Alias.run(dir, String.to_atom(rule), String.to_atom(call))
