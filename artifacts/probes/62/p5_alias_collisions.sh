#!/usr/bin/env bash
# Ticket 62, candidate 2 ("a rule for deriving the name"): apply Elixir's Macro.underscore to every PascalCase
# function name the corpus declares and count (a) distinct derivations that collide, (b) names whose derivation
# disagrees with Gleam-style word splitting on acronym runs.
here=$(cd "$(dirname "$0")" && pwd); ex=$here/../../../compiler/examples
grep -rhoE '^(public )?[a-z_<>(), .0-9A-Z]+ [A-Z][A-Za-z0-9_]*\(' "$ex" --include=*.bs | grep -oE '[A-Z][A-Za-z0-9_]*\($' | tr -d '(' | sort -u > /tmp/fnames.txt
echo "distinct PascalCase function names in the corpus: $(wc -l < /tmp/fnames.txt)"
elixir -e '
names = File.read!("/tmp/fnames.txt") |> String.split("\n", trim: true)
by = Enum.group_by(names, &Macro.underscore/1)
coll = for {k, v} <- by, length(v) > 1, do: {k, v}
IO.puts("collisions under Macro.underscore: #{inspect(coll)}")
IO.puts("sample: #{inspect(Enum.take(Enum.map(names, &{&1, Macro.underscore(&1)}), 6))}")
tricky = ["ToJSON", "HTTPGet", "ParseURL", "IPv4Addr", "Get1", "F2", "OAuth", "Total_X"]
IO.puts("acronym/digit cases (Macro.underscore): #{inspect(Enum.map(tricky, &{&1, Macro.underscore(&1)}))}")
'
