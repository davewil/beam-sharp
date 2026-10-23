#!/usr/bin/env bash
# PROBE 65d — what does "user names win" cost in Elixir, on the installed 1.19.5?
#
# Ticket 65 says: "Elixir ... `defmodule Map` warns, clobbers the standard module, and then
# crashes Elixir's own type checker, which was calling `Map.update!/3`." The claim is from an
# older Elixir. This runs it on the one installed here and says whether it still holds.
# CONTROL: the same program with `Shop.Map` (a dotted path) — the escape B# already gives
# (67 Q6) — runs clean. A probe that crashed on both would show nothing about `Map`.
#
#   source env.sh; bash artifacts/probes/65/65d_elixir_defmodule_map.sh
set -uo pipefail
: "${S:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
echo "elixir: $(elixir --version 2>/dev/null | tail -1)"
v() { # label file
  local out; out="$(elixir "$2" 2>&1)"; local rc=$?
  printf '== %s (exit %s)\n' "$1" "$rc"
  printf '%s\n' "$out" | grep -E 'redefining module|UndefinedFunctionError|^:user_map|^%\{|^:ok|lib/(module/types|kernel/lexical_tracker)\.ex:[0-9]+' | sed -E "s#$S/elixir/#<elixir>/#; s/\(current version loaded from.*//" | head -5 | sed 's/^/   /'
}
cat > a.exs <<'X'
defmodule Map do
  def hi, do: :user_map
end
IO.inspect(Map.hi())
X
cat > b.exs <<'X'
defmodule Map do
  def hi, do: :user_map
end
IO.inspect(Map.new())
X
cat > c.exs <<'X'
defmodule Map do
  def hi, do: :user_map
end
defmodule Other do
  def f, do: :ok
end
IO.inspect(Other.f())
X
cat > d.exs <<'X'
defmodule Shop.Map do
  def hi, do: :user_map
end
IO.inspect(Shop.Map.hi())
defmodule Other do
  def f(m), do: Map.update!(m, :a, &(&1 + 1))
end
IO.inspect(Other.f(%{a: 1}))
X
v "a. defmodule Map; call the user's Map.hi"                       a.exs
v "b. defmodule Map; call the STANDARD Map.new (clobbered?)"       b.exs
v "c. defmodule Map; then define an unrelated module"              c.exs
v "d. CONTROL: Shop.Map (dotted), stdlib Map.update! still works"  d.exs
echo "source of the type-checker call site:"
echo "   (put_in/2 on a struct-less path expands to Map.update!/3, which is the frame above)"
sed -n 291p "$S"/elixir/lib/elixir/lib/module/types.ex | sed "s#^#   lib/elixir/lib/module/types.ex:291:#"
grep -n 'Map.get(cache, key)' "$S"/elixir/lib/elixir/lib/kernel/lexical_tracker.ex | sed "s#^#   lib/elixir/lib/kernel/lexical_tracker.ex:#"
