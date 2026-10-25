#!/usr/bin/env bash
# P18 (ticket Q3): does result<T, E> need anything at E = term? Run it, with a correct body, and with the colliding controls.
. "$(dirname "$0")/lib.sh"
mk RE <<'SRC'
module RE

public result<int, term> Parse(binary b)
Parse(b) when b == "1" -> 1
Parse(b) -> (:error, (:bad, b))

public atom Show(binary b)
Show(b) -> Parse(b) switch { (:error, (:bad, x)) => :bad_input, (:error, e) => :other, n => :ok }

public result<int, term> Terms(binary b)
Terms(b) -> (:error, :boom)
SRC
$BSC "$W/RE" --api 2>&1 | sed "s#$W/##"
for a in '"1"' '"x"'; do printf 'Show %s -> ' "$a"; $BSC "$W/RE" Show "$a" 2>&1 | tail -1; done
echo "--- controls: E=term is fine; T that already holds an (:error, _) tuple still collides, whatever E is"
for spec in 'result<(:error, int), atom>' 'result<(atom, int), term>' 'result<(:ok, int), term>' 'result<list<term>, term>'; do
  n="RC_$(echo $spec | tr -c 'A-Za-z\n' _ | sed 's/__*/_/g')"
  mk $n <<SRC
module $n
public $spec F(int k)
F(k) -> (:error, :x)
SRC
  printf '%-34s ' "$spec"; $BSC "$W/$n" 2>&1 | grep -m1 'error:' | sed "s#$W/##; s#^[^ ]* ##" || true; $BSC "$W/$n" 2>&1 | grep -qm1 'error:' || echo accepted
done
