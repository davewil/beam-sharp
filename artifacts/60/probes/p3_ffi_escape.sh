#!/usr/bin/env bash
# P3: a rule enforced at `using` is a compile-time check on B# callers only.
# (Attempt 1, kept as p3_ffi_escape.attempt1-failed.out, declared
#  `using :'Shop.Ledger' { int Round(int cents) }`: refused by the GRAMMAR, because a
#  foreign_sig name is a lident and a B# function name is a uident. So a typed FFI
#  block cannot name a B# function at all. This attempt tries the untyped door.)
cd "$(dirname "$0")"; export BSC_EBIN=${BSC_EBIN:-/tmp/bsc-build-60/ebin}
rm -rf /tmp/p3out; mkdir -p /tmp/p3out
echo '--- compile Shop.Ledger (the helper module)'
./_bsc.sh --src-root fx -o /tmp/p3out fx/Shop/Ledger; echo "exit=$?"
echo '--- compile Web.Ffi: :erlang.apply(:Shop.Ledger, :Round, [cents]), no using of Shop.Ledger'
./_bsc.sh --src-root fx -o /tmp/p3out fx/Web/Ffi; echo "exit=$?"
echo '--- run it on the BEAM with both beams loaded: Total(103)'
erl -noshell -pa /tmp/p3out -eval "io:format(\"~p~n\", ['Web.Ffi':'Total'(103)]), halt()."
