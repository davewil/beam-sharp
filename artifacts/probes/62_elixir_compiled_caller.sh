#!/usr/bin/env bash
# PROBE 62_elixir_compiled_caller (ticket 62)
# CLAIM: an Elixir MODULE (compiled by elixirc, not eval'd) can call a B#
# PascalCase export as `:Shop."New"(1)` with NO compiler warning and with the
# remote-call checker (which reads the callee's exports) happy; and it can
# pattern match and pipe on the result. Control: a call to a non-export
# (`:Shop."Nope"(1)`) must produce an "undefined or private" warning, proving
# the checker looked at the .beam. REFUTED if the `New` call warns, or if the
# `Nope` control stays silent.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
export ELIXIR_ERL_OPTIONS="+fnu"
W="$(bs_scratch)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/ebin" "$W/out"
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop" >/dev/null || exit 2
cat > "$W/caller.ex" <<'EX'
defmodule Caller do
  def ok(id), do: :Shop."New"(id)
  def piped(id), do: id |> :Shop."New"() |> :Shop."Pay"() |> :Shop."Amount"()
  def cap, do: Enum.map([1, 2], &:Shop."New"/1)
  def bad(id), do: :Shop."Nope"(id)
end
EX
echo "--- elixirc output (warnings are the point) ---"
(cd "$W" && elixirc -pa "$W/ebin" -o "$W/out" caller.ex) 2>&1
echo "--- run ---"
elixir -pa "$W/ebin" -pa "$W/out" -e 'IO.inspect(Caller.ok(1)); IO.inspect(Caller.piped(1)); IO.inspect(Caller.cap())' 2>&1
echo "--- defdelegate (Elixir-side shim, one line per function) ---"
cat > "$W/shim.ex" <<'EX'
defmodule ShopEx do
  defdelegate new(id), to: :Shop, as: :New
  defdelegate pay(o), to: :Shop, as: :Pay
  defdelegate amount(o), to: :Shop, as: :Amount
end
EX
(cd "$W" && elixirc -pa "$W/ebin" -o "$W/out" shim.ex) 2>&1
elixir -pa "$W/ebin" -pa "$W/out" -e 'IO.inspect(1 |> ShopEx.new() |> ShopEx.pay() |> ShopEx.amount())' 2>&1
