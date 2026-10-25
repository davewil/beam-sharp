#!/usr/bin/env bash
# attempt 1 (kept as .attempt1.*) picked controls that do NOT collide ((:error,atom) is not inside (:error,int)), so its 'accepted' column proved nothing; controls rewritten before re-run.
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
for spec in 'result<(:error, term), atom>' 'result<(atom, term), atom>' 'result<(atom, int), term>' 'result<(atom, int), atom>' 'result<list<term>, term>'; do
  n="RC_$(echo $spec | tr -c 'A-Za-z\n' _ | sed 's/__*/_/g')"
  mk $n <<SRC
module $n
public $spec F(int k)
F(k) -> (:error, :x)
SRC
  out=$($BSC "$W/$n" 2>&1 | grep -m1 'error:' | sed "s#$W/##; s#^[^ ]* ##")
  printf '%-34s %s\n' "$spec" "${out:-accepted}"
done
