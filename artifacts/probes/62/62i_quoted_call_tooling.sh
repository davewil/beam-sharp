#!/usr/bin/env bash
# PROBE 62i — is `:Shop."New"(1)` a first-class call for Elixir tooling, or only something eval accepts?
#   (1) the Elixir formatter leaves it alone (idempotent);
#   (2) it parses and runs on Elixir 1.14.0 / OTP 25 (the distro one, an old floor) as well as 1.19.5 / OTP 28;
#   (3) COMPILED Elixir (elixirc) cross-checks the call against the real export table: a wrong arity and a wrong name
#       must produce a compile-time warning (control), the right call must produce none.
# The module under test is a real bsc-emitted beam (Shop) for 1.19.5; the OTP 25 run uses a hand-written 'Shop'
# with the same export ('New'/1) because an OTP 28 beam does not load on OTP 25. That substitution is the limit of (2).
set -uo pipefail
: "${BSC:?source env.sh}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir "$W/ebin" "$W/old"
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
echo "== (1) formatter"
elixir -e 'src = ~S[x = :Shop."New"(1) |> then(&:Shop."Which"/1)]; f = Code.format_string!(src) |> IO.iodata_to_binary(); IO.puts(f); IO.puts("idempotent: #{Code.format_string!(f) |> IO.iodata_to_binary() == f}")' 2>&1 | grep -v warning
echo "== (3) compiled Elixir, xref-style checks (Elixir 1.19.5 against the real bsc beam)"
cat > "$W/ok.ex" <<'X'
defmodule Caller do
  def right, do: :Shop."New"(1)
end
X
cat > "$W/bad_arity.ex" <<'X'
defmodule CallerArity do
  def wrong, do: :Shop."New"(1, 2)
end
X
cat > "$W/bad_name.ex" <<'X'
defmodule CallerName do
  def wrong, do: :Shop."Nope"(1)
end
X
# CONTROL for "no warning": a lowercase name in quotes IS warned about by the Elixir tokenizer (elixir_tokenizer.erl:960),
# so silence on "New" is evidence the tokenizer treats the quotes as required here, not that warnings are suppressed.
cat > "$W/quoted_lower.ex" <<'X'
defmodule CallerLower do
  def r, do: :Shop."new"(1)
end
X
for f in ok bad_arity bad_name quoted_lower; do
  out=$(cd "$W" && elixirc -pa "$W/ebin" -o "$W" "$f.ex" 2>&1 | grep -i -A1 'warning\|undefined' | head -3 | tr '\n' ' ')
  printf '  %-14s %s\n' "$f" "${out:-<no warning>}"
done
echo "== (2) Elixir 1.14.0 / OTP 25 (distro)"
cat > "$W/old/Shop.erl" <<'X'
-module('Shop').
-export(['New'/1]).
'New'(X) -> {new, X}.
X
env -i PATH=/usr/bin:/bin /usr/bin/erlc -o "$W/old" "$W/old/Shop.erl"
env -i PATH=/usr/bin:/bin LANG=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu" HOME="$W" /usr/bin/elixir --version 2>&1 | tail -2
env -i PATH=/usr/bin:/bin LANG=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu" HOME="$W" /usr/bin/elixir -pa "$W/old" -e 'IO.inspect(:Shop."New"(1)); IO.inspect(Enum.map([1,2], &:Shop."New"/1)); IO.inspect(1 |> :Shop."New"())' 2>&1 | grep -v warning
