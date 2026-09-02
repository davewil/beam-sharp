#!/usr/bin/env bash
#
# 47b — What do the two BEAM languages actually do about import aliasing?
#
# Ticket 47's owed item 1 says survey all three tiers and take the most accurate
# word rather than the highest tier that fits. Ticket 41 recorded that a survey
# for "imports, -import, aliasing, shadowing or resolution order returns nothing
# measured", so this runs it.
#
# Elixir is the closest prior art anywhere: same VM, and its bare `alias` binds
# the last path segment, which is EXACTLY B#'s namespace tier. `alias ..., as:`
# is precisely the delta ticket 47 weighs.
#
#   ./47b_alias_prior_art.sh
#
set -uo pipefail

WORK="${TMPDIR:-/tmp}/bs47b.$$"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK"
cd "$WORK" || exit 1

command -v elixir >/dev/null || { echo "SKIP: no elixir"; exit 0; }
command -v erlc   >/dev/null || { echo "SKIP: no erlc";   exit 0; }

cat > defs.ex <<'EOF'
defmodule A.Coll.List do
  def sum(xs), do: Enum.sum(xs)
end
defmodule B.Coll.List do
  def sum(xs), do: Enum.sum(xs) * 10
end
defmodule Solo do
  def sum(xs), do: Enum.sum(xs) * 100
end
EOF

run() { elixir -r defs.ex "$1" 2>&1; }

echo "=== E1 — does a BARE alias bind the last segment, as B#'s namespace tier does? ==="
cat > e1.exs <<'EOF'
defmodule E1 do
  alias A.Coll.List
  def go, do: List.sum([1, 2, 3])
end
IO.inspect E1.go()
EOF
run e1.exs | tail -3
echo "    6 => yes. Identical rule to B#: the short name is DERIVED, never chosen."

echo
echo '=== E2 — does `as:` give a chosen name, and does it defuse a collision? ==='
cat > e2.exs <<'EOF'
defmodule E2 do
  alias A.Coll.List, as: AL
  alias B.Coll.List, as: BL
  def go, do: {AL.sum([1, 2, 3]), BL.sum([1, 2, 3])}
end
IO.inspect E2.go()
EOF
run e2.exs | tail -3
echo "    {6, 60} => yes to both."

echo
echo "=== E3 — two colliding BARE aliases: error, warning, or silent shadow? ==="
cat > e3.exs <<'EOF'
defmodule E3 do
  alias A.Coll.List
  alias B.Coll.List
  def go, do: List.sum([1, 2, 3])
end
IO.inspect E3.go()
EOF
run e3.exs | tail -6
echo "    60, no diagnostic => SILENT SHADOW, last alias wins."
echo "    B# refuses this outright. B# is the stricter language here, not the looser."

echo
echo "=== E4 — is a fully-qualified call legal with NO alias at all? ==="
cat > e4.exs <<'EOF'
defmodule E4 do
  def go, do: {A.Coll.List.sum([1, 2, 3]), Solo.sum([1, 2, 3])}
end
IO.inspect E4.go()
EOF
run e4.exs | tail -3
cat <<'EOF'
    {6, 600} => YES. This is the divergence that matters: in Elixir the
    alias is pure convenience BECAUSE qualification never needs it. B#
    41 §1 made `using` the dependency list, so qualification DOES need it.
EOF

echo
echo "=== E5 — does a local sum/1 clash with an aliased module's sum/1? ==="
cat > e5.exs <<'EOF'
defmodule E5 do
  alias A.Coll.List
  def sum(_xs), do: 0
  def go, do: {List.sum([1, 2, 3]), sum([1, 2, 3])}
end
IO.inspect E5.go()
EOF
run e5.exs | tail -3
cat <<'EOF'
    {6, 0} => no clash. Elixir's `alias` writes MODULE names and its
    `import` writes FUNCTION names — two constructs. B#'s one `using`
    does both, and which one it does is chosen by the callee's directory
    layout rather than by the caller.
EOF

echo
echo "=== E6 — Erlang: -import/2 of a name the module also defines ==="
cat > erl6.erl <<'EOF'
-module(erl6).
-export([go/0, sum/1]).
-import(lists, [sum/1]).
sum(_) -> 0.
go() -> sum([1, 2, 3]).
EOF
erlc -o . erl6.erl 2>&1 | tail -4
echo "    hard error. This WAS the same rule as B#'s import_shadows_local;"
echo "    since 2026-09-02 (ENG-270) B# diverges here and accepts the shape,"
echo "    resolving the bare name to the local by 41 §2's 'local, then imports'."
echo "    Erlang can afford the refusal because -import is optional sugar for a"
echo "    call it can always spell as lists:sum/1; in B# the using line IS the"
echo "    dependency list (41 §1), so refusing it left the callee unreachable."
echo "    Erlang has NO module renaming at all; -import names functions only."

echo
cat <<'SUMMARY'
--- the survey, and the one column B# is alone in ---

                 chosen-name   what it     two short names    qualified call
                 alias?        aliases     that collide       needs the import?
  C#             yes           namespace   error              no
  Elixir         yes (`as:`)   module      silent shadow      no
  TypeScript     yes (`as`)    binding     error              n/a
  Erlang         NO            —           hard error         no
  B# today       no            —           error              YES

Three of four have the alias, so the borrow heuristic supplies it cheaply. But
the last column is the finding: B# is the only language measured where naming a
module in full still requires its `using` line. That is 41 §1 on purpose — the
`using` lines are the file's dependency list — and it is what turns B#'s
shadow rule into a lockout that none of these four languages can reach.
SUMMARY
