#!/usr/bin/env bash
# V1b: G_RES control with a non-error present value (should print 1); V2: Elixir ambiguity of Map.get/3 sentinel + descr for result<T,E> at T=term/E=term
. /home/user/beam-sharp/artifacts/probes/env.sh
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/G" "$W/o"; cat > "$W/G/m.bs" <<'E'
module G

public result<T, atom> Wrap<T>(T x)
Wrap(x) -> x

public int Use(term t)
Use(t) -> Wrap(t) switch { (:error, e) => 0, v => 1 }
E
echo "G_RES Use(5) [expect 1]:"; $BSC -o "$W/o" "$W/G" Use 5 2>&1 | tail -1
echo "G_RES Use((:error,:x)) [collapse => 0]:"; $BSC -o "$W/o" "$W/G" Use "(:error, :x)" 2>&1 | tail -1
cat > "$W/t.exs" <<'X'
alias Module.Types.Descr
err = Descr.tuple([Descr.atom([:error]), Descr.term()])
IO.puts("result<int, term>  int | {:error, term} == int?        " <> to_string(Descr.equal?(Descr.union(Descr.integer(), err), Descr.integer())))
IO.puts("result<term, term> term | {:error, term} == term?      " <> to_string(Descr.equal?(Descr.union(Descr.term(), err), Descr.term())))
IO.puts("Map.get(%{a: nil}, :a) == Map.get(%{}, :a)?            " <> to_string(Map.get(%{a: nil}, :a) == Map.get(%{}, :a)))
IO.puts("Map.fetch distinguishes: " <> inspect({Map.fetch(%{a: nil}, :a), Map.fetch(%{}, :a)}))
X
ELIXIR_ERL_OPTIONS=+fnu elixir "$W/t.exs"
