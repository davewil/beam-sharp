#!/bin/bash
# P1: current behaviour (unpatched bsc). Callee B has public/private/unmarked fns; callers name each.
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d)
mk $R B 'module B

public int Pub(int n)
Pub(n) -> n + 1

private int Priv(int n)
Priv(n) -> n + 2

int Unmarked(int n)
Unmarked(n) -> n + 3'
caller() { mk $R "$1" "module $1
using B
public int Go(int n)
Go(n) -> $2"; }
caller A_pub 'Pub(n)'; caller A_priv 'Priv(n)'; caller A_unm 'Unmarked(n)'
caller A_qpriv 'B.Priv(n)'; caller A_qpub 'B.Pub(n)'
mk $R A_nousing 'module A_nousing
public int Go(int n)
Go(n) -> B.Pub(n)'
for m in A_pub A_priv A_unm A_qpriv A_qpub A_nousing; do
  echo "--- $m"; cc $R $m 5 | grep -v 'Warning: function' | head -6
done
rm -rf $R
