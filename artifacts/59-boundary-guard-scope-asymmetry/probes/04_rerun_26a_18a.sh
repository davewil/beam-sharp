#!/bin/bash
# Probe 04 (c): re-run the tickets' OWN cost prototypes unmodified on this OTP 28 box, to say whether
# "+14 bytes flat in field count" (26a) and "+3-5 bytes per is_integer" (18a) reproduce.
# The prototypes are copied-by-reference (compiled from wayfinder/prototypes, not edited).
# Their timing sections are noisy and use a different machine; only the size tables are used here.
cd "$(dirname "$0")"; . ./lib.sh
P=/home/user/beam-sharp/wayfinder/prototypes
mkdir -p /tmp/p59/26a /tmp/p59/18a
erlc -o /tmp/p59/26a $P/26a_record_erasure_cost.erl && erlc -o /tmp/p59/18a $P/18a_guard_cost.erl
echo "################ 26a (record erasure) - size sections ################"
erl -noshell -pa /tmp/p59/26a -eval "'26a_record_erasure_cost':go(), halt()." 2>&1 
echo
echo "################ 18a (guard cost) - size sections ################"
erl -noshell -pa /tmp/p59/18a -eval "'18a_guard_cost':go(), halt()." 2>&1 
