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
PASS=0; FAIL=0
v() { # label file wanted-exit required-output-regex
  local out; out="$(elixir "$2" 2>&1)"; local rc=$?
  local lab="$1" f="$2" want="$3"; shift 3; local ok=1 re
  for re in "$@"; do printf '%s' "$out" | grep -Eq "$re" || ok=0; done
  set -- "$lab" "$f" "$want" "$*"
  if [ "$rc" = "$3" ] && [ "$ok" = 1 ]; then PASS=$((PASS+1)); m="[ok]"; else FAIL=$((FAIL+1)); m="[FAILED: wanted exit $3 and output matching $4]"; fi
  printf '== %s (exit %s) %s\n' "$1" "$rc" "$m"
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
v "a. defmodule Map; call the user's Map.hi"                       a.exs 1 'redefining module Map' ':user_map' 'Map.update!/3 is undefined or private' 'lib/module/types.ex:291'
v "b. defmodule Map; call the STANDARD Map.new (clobbered?)"       b.exs 1 'redefining module Map' 'Map.new/0 is undefined or private'
v "c. defmodule Map; then define an unrelated module"              c.exs 1 'redefining module Map' 'Map.get/2 is undefined or private' 'lexical_tracker.ex:159'
v "d. CONTROL: Shop.Map (dotted), stdlib Map.update! still works"  d.exs 0 ':user_map' '%\{a: 2\}'
echo "source of the type-checker call site:"
echo "   (put_in/2 on a struct-less path expands to Map.update!/3, which is the frame above)"
sed -n 291p "$S"/elixir/lib/elixir/lib/module/types.ex | sed "s#^#   lib/elixir/lib/module/types.ex:291:#"
grep -n 'Map.get(cache, key)' "$S"/elixir/lib/elixir/lib/kernel/lexical_tracker.ex | sed "s#^#   lib/elixir/lib/kernel/lexical_tracker.ex:#"
echo "--- tally: $PASS as expected, $FAIL failed"
[ "$FAIL" = 0 ]
