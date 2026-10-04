#!/usr/bin/env bash
# bs_emit:kind_expr/2 (bs_emit.erl:700-711) says it MIRRORS the two shapes bs_check:comparison/1 reads, so the
# emitter adds an is_integer test wherever the checker credits an int range. In Erlang term order an atom > any number,
# so a bare `A >= -5` is TRUE for an atom. Does a NEGATIVE literal guard get the kind test?
source "$(dirname "$0")/lib.sh"
probe PosLit '
public atom F(int | atom n)
F(n) when n >= 5 -> :hi
F(_) -> :other' F :x
probe NegLit '
public atom F(int | atom n)
F(n) when n >= -5 -> :hi
F(_) -> :other' F :x
probe NegLitCredited '
public atom F(int | atom n)
F(n) when n >= -5 -> :int_hi
F(n) when n < -5  -> :int_lo
F(:a) -> :a
F(_) -> :other' F :a
