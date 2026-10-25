#!/usr/bin/env bash
# P15: MODIFIED COMPILER (scratch copy, repo untouched): two rows added to declared_rows() (delta_rows.diff).
#  Map.Get  -> maps:get/2   "V Get<K,V>(map<K,V> m, K k)"                     (crashes on absence)
#  Map.Fetch-> maps:find/2  "(:ok, V) | :error Fetch<K,V>(map<K,V> m, K k)"  (tagged, zero emitter work)
# Question answered: does a one-line tagged row work at V=term, with no new emitter code, and is the caller exhaustiveness-checked?
. "$(dirname "$0")/lib.sh"
D=$S/64/delta/bsc
mk Fx <<'SRC'
module Fx

public map<string, term> Sample()
Sample() -> Map.FromList([("user_id", 42), ("flag", :nothing)])

public atom Kind(string k)
Kind(k) -> Map.Fetch(Sample(), k) switch { (:ok, :nothing) => :stored_nothing, (:ok, v) => :present, :error => :absent }

public term Strict(string k)
Strict(k) -> Map.Get(Sample(), k)

public (:ok, term) | :error Raw(string k)
Raw(k) -> Map.Fetch(Sample(), k)
SRC
echo "--- stock compiler (control: must refuse)"; $BSC "$W/Fx" 2>&1 | head -3 | sed "s#$W/##"
echo "--- delta compiler"; $D "$W/Fx" --api 2>&1 | head
for k in '"user_id"' '"flag"' '"nope"'; do printf 'Kind %s -> ' $k; $D "$W/Fx" Kind $k 2>&1 | tail -1; done
printf 'Strict "nope" -> '; $D "$W/Fx" Strict '"nope"' 2>&1 | tail -1
mk Fy <<'SRC'
module Fy
public atom Kind(map<string, term> m, string k)
Kind(m, k) -> Map.Fetch(m, k) switch { (:ok, v) => :present }
SRC
echo "--- negative: non-exhaustive caller refused"; $D "$W/Fy" 2>&1 | head -4 | sed "s#$W/##"
mk Fz <<'SRC'
module Fz
public atom Kind(map<string, int> m)
Kind(m) -> Map.Fetch(m, "a") switch { (:ok, v) => :present, :error => :absent }
public atom Wrong(map<string, int> m)
Wrong(m) -> Map.Fetch(m, :a) switch { (:ok, v) => :present, :error => :absent }
SRC
echo "--- a key of the wrong type is refused by the existing row machinery"; $D "$W/Fz" 2>&1 | head -4 | sed "s#$W/##"
