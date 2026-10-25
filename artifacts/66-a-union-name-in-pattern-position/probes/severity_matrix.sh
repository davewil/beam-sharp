#!/usr/bin/env bash
# Exit code of exemplar 5 (named-type vacuity, ex/E5) and a structural vacuity (ex/E6, the Rust/F# `(:some, x)` shape)
# under: stock | 3b promote every vacuous_clause | 3c promote only when the head names a type.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
cd "$(dirname "$0")"
for e in E5 E6; do
  printf '%-3s' $e
  for c in $S/bsc $S/66/bsc_promo $S/66/bsc_promonamed; do
    $c --src-root ex ex/$e >/dev/null 2>&1; rc=$?; printf '  %-14s rc=%s' "$(basename $c)" $rc
  done; echo
done
