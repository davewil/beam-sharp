#!/usr/bin/env bash
# Ticket 59. Who gets a boundary guard, and what slips through when they do not?
# Three emitter builds: base; G1 = record tag test only on EXPORTED functions; G2 = int kind test on private functions too.
# Each program is forged from outside (Erlang calling the exported entry with a value B# would never construct).
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); mkdir -p $W/src/G
cat > $W/src/G/g.bs <<'X'
module G

record Customer { Credit: int }
record Order    { Id: int, Buyer: Customer }

type Byte = int where value >= 0 and value <= 255

// RECORD: the exported entry checks Order's tag; the Buyer inside is only a field. Private Inner(Customer) is where a
// forged Buyer would be noticed, if anything notices.
private int Inner(Customer c)
Inner(c) -> c.Credit

public int RunOrder(Order o)
RunOrder(o) -> Inner(o.Buyer)

// INT KIND: Classify is private and answers from a parameter published as 0..255.
private atom Classify(Byte b)
Classify(b) when b >= 100 -> :big
Classify(b)               -> :small

public atom RunBytes(list<Byte> bs)
RunBytes([b, .._]) -> Classify(b)
RunBytes([])       -> :none

// The same Classify, exported: the control that the kind guard does exist at an exported boundary.
public atom ClassifyPublic(Byte b)
ClassifyPublic(b) when b >= 100 -> :big
ClassifyPublic(b)               -> :small
X
call() { erl -noshell -pa $W/$1 -eval 'R = (catch '"$2"'), io:format("~p~n", [case R of {'"'"'EXIT'"'"', {E, [{M,F,A,_}|_]}} -> {crash, E, M, F}; V -> V end]), halt().'; }
for v in base G1 G2; do
  e=$SCRATCH/ebin; [ $v = G1 ] && e=$SCRATCH/v59/G1/ebin; [ $v = G2 ] && e=$SCRATCH/v59/G2/ebin
  BSC_EBIN=$e bsc -o $W/$v $W/src/G > $W/$v.log 2>&1 || { echo "$v: compile failed"; cat $W/$v.log; continue; }
  echo "== $v"
  printf '  valid Order                      -> '; call $v "'G':'RunOrder'(#{'Kind'=>'G.Order','Id'=>1,'Buyer'=>#{'Kind'=>'G.Customer','Credit'=>7}})"
  printf '  forged top-level tag             -> '; call $v "'G':'RunOrder'(#{'Kind'=>'G.Customer','Id'=>1,'Buyer'=>#{'Kind'=>'G.Customer','Credit'=>7}})"
  printf '  forged NESTED Buyer tag          -> '; call $v "'G':'RunOrder'(#{'Kind'=>'G.Order','Id'=>1,'Buyer'=>#{'Kind'=>'G.Other','Credit'=>7}})"
  printf '  forged NESTED Buyer, no Credit   -> '; call $v "'G':'RunOrder'(#{'Kind'=>'G.Order','Id'=>1,'Buyer'=>#{'Kind'=>'G.Other'}})"
  printf '  RunBytes([100.5])  float element -> '; call $v "'G':'RunBytes'([100.5])"
  printf '  RunBytes([7])      valid         -> '; call $v "'G':'RunBytes'([7])"
  printf '  ClassifyPublic(100.5) exported   -> '; call $v "'G':'ClassifyPublic'(100.5)"
done
