#!/usr/bin/env bash
# P06: candidate spellings that compile TODAY, as a Plug-style assigns lookup over map<string, term>.
# attempt 1 (kept as .attempt1.*) forgot the `:maps.` qualifier on foreign calls; fix is the qualifier only.
#  C1 tagged: (:ok, V) | :absent via foreign maps:find   (Elixir/Erlang shape)
#  C2 Has + Get pair via Map.Has and foreign maps:get
#  C3 tagged via Map.ToList scan (no foreign)
#  Controls: stored :nothing / stored :absent value, absent key, wrong-type reader
. "$(dirname "$0")/lib.sh"
mk Assigns <<'SRC'
module Assigns

type Found = (:ok, term) | :error

using :maps {
    Found find(string k, map<string, term> m)
    term get(string k, map<string, term> m)
}

public map<string, term> Sample()
Sample() -> Map.FromList([("user_id", 42), ("flag", :nothing)])

// C1 -- tagged
public int C1(string k)
C1(k) -> :maps.find(k, Sample()) switch { (:ok, n) => 1, :error => 0 }

// the caller shape the tagged form demands: one clause per outcome, exhaustive
public atom C1Kind(string k)
C1Kind(k) -> :maps.find(k, Sample()) switch { (:ok, :nothing) => :stored_nothing, (:ok, v) => :present, :error => :absent }

// C2 -- Has + Get
public atom C2Kind(string k)
C2Kind(k) -> Map.Has(Sample(), k) switch { :true => (:maps.get(k, Sample()) switch { :nothing => :stored_nothing, v => :present }), :false => :absent }

// C2 misuse: Get alone, absent key
public term C2Raw(string k)
C2Raw(k) -> :maps.get(k, Sample())

// C3 -- scan the list view
private Found Scan(list<(string, term)> xs, string k)
Scan([], k) -> :error
Scan([(kk, v), ..rest], k) when kk == k -> (:ok, v)
Scan([_, ..rest], k) -> Scan(rest, k)

public atom C3Kind(string k)
C3Kind(k) -> Scan(Map.ToList(Sample()), k) switch { (:ok, :nothing) => :stored_nothing, (:ok, v) => :present, :error => :absent }

// negative: non-exhaustive tagged caller must be refused
public atom Bad(string k)
Bad(k) -> :maps.find(k, Sample()) switch { (:ok, v) => :present }
SRC
echo "--- compile (Bad must be refused)"; $BSC "$W/Assigns" 2>&1 | head -12
sed -i '/^\/\/ negative/,$d' "$W/Assigns/Assigns.bs"; cp "$W/Assigns/Assigns.bs" "$HERE/src_Assigns.bs"
echo "--- after removing Bad:"; $BSC "$W/Assigns" --api 2>&1 | head -12
for f in C1Kind C2Kind C3Kind; do for k in '"user_id"' '"flag"' '"nope"'; do printf '%s %s -> ' $f $k; $BSC "$W/Assigns" $f $k 2>&1 | tail -1 | cut -c1-160; done; done
printf 'C2Raw "nope" -> '; $BSC "$W/Assigns" C2Raw '"nope"' 2>&1 | tail -2 | cut -c1-200
