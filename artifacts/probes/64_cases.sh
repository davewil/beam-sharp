#!/usr/bin/env bash
# 64_cases.sh -- the three motivating cases (ticket 48: Plug assigns, decoded jsonb, Req headers) under each answer.
# CLAIM: with option<term> refused, an author at map<_, term> still has a working, correct route today
#   (a foreign `(:ok, term) | :error find` declaration, as exemplars/25g does), and the tagged shapes distinguish
#   absent from present-as-an-atom where the sentinel/default shape (maps:get/3) cannot.
# EXPECTED GREEN (distinguishes 3 states): AssignsA, AssignsB, JsonA, JsonB, JsonDefault (JSON only: sentinel safe),
#   HeadersA, HeadersOpt (V=list<term>: untagged option works)
# EXPECTED RED: AssignsBRaw (declares the blessed `:absent` over OTP's `error`: crashes case_clause at run time),
#   HeadersOptTerm (option<term> refused at the signature)
# CONTROL showing the harm the refusal prevents: AssignsNaive returns the SAME answer for "no assign" and
#   "explicitly :nothing".
# REFUTED if: AssignsNaive prints two different answers, or any EXPECTED-GREEN prints crashed/error,
#   or HeadersOptTerm compiles.
. "$(dirname "$0")/env.sh"
P="$(cd "$(dirname "$0")" && pwd)/64_programs"
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
r() { printf '%-14s %-14s ' "$1" "$2"; $BSC -o "$W" "$P/$1" "$2" 2>&1 | tail -1 | sed "s#$P/##"; }
for f in RunAnon RunLoggedOut; do r AssignsA $f; r AssignsB $f; r AssignsBRaw $f; r AssignsNaive $f; done
for f in RunSet RunNull RunMissing; do r JsonA $f; r JsonB $f; r JsonDefault $f; done
r HeadersA Run
for f in RunPresent RunAbsent; do r HeadersOpt $f; done
echo "-- HeadersOptTerm (expected red):"; $BSC -o "$W" "$P/HeadersOptTerm" 2>&1 | head -3 | sed "s#$P/##"
echo "-- bare-success wins: same program, option<int> vs (:some,int)|:nothing (expect both 2; note the extra wrapper tokens)"
r BareWins Run; r TaggedOption Run
printf 'success-path wrapper expressions: bare=%s tagged=%s ; clause-head wrapper patterns: bare=%s tagged=%s\n' \
  "$(grep -c '(:some, v)' "$P/BareWins/barewins.bs")" "$(grep -c '(:some, v)' "$P/TaggedOption/taggedoption.bs")" \
  "$(grep -c '(:some, n)' "$P/BareWins/barewins.bs")" "$(grep -c '(:some, n)' "$P/TaggedOption/taggedoption.bs")"
