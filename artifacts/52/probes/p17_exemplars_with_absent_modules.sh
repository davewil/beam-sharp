#!/usr/bin/env bash
# p17: the repo's own exemplar 25f names `:json` (OTP 27+) and 25d names `:epgsql` (third party).  This machine is OTP 25,
# so `code:which(json)` is non_existing.  Does 25f compile today?  (It is built the way 25f_surface_probe.sh builds it:
# copied into Support/Triage so the module line matches the directory.)  An error-severity presence check would turn this
# compile red on any machine lacking the module; a warning would not.
W=$(mktemp -d); E=$(mktemp -d)
mkdir -p $W/Support/Triage && cp /home/user/beam-sharp/compiler/examples/exemplars/25f-llm-evaluation-client/*.bs $W/Support/Triage/
grep -n "^using :" $W/Support/Triage/*.bs | sed "s|$W/||"
env -u ERL_LIBS /home/user/beam-sharp/artifacts/52/probes/bsc.sh -o $E --src-root $W $W/Support/Triage 2>&1 | head -5; echo "bsc exit=${PIPESTATUS[0]}"
env -u ERL_LIBS erl -noshell -eval 'io:format("OTP ~s: code:which(json)=~p code:which(epgsql)=~p~n",[erlang:system_info(otp_release),code:which(json),code:which(epgsql)]),halt().'
