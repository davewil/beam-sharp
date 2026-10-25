#!/usr/bin/env bash
# P5: OTP 29 erlc. A user -type named like a built-in type, with/without nowarn.
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8
D=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/65/p5; rm -rf $D; mkdir -p $D; cd $D
erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
t(){ n=$1; shift; echo "=== $n: erlc $*"; erlc "$@" $n.erl; echo "exit=$?"; }
cat > t_list.erl <<'X'
-module(t_list).
-export([f/1]).
-type list() :: {my, list}.
-spec f(list()) -> ok.
f({my, list}) -> ok.
X
cat > t_atom.erl <<'X'
-module(t_atom).
-export([f/1]).
-type atom() :: integer().
-spec f(atom()) -> ok.
f(1) -> ok.
X
cat > t_atom_nowarn.erl <<'X'
-module(t_atom_nowarn).
-export([f/1]).
-compile(nowarn_shadow_vars).
-type atom() :: integer().
-spec f(atom()) -> ok.
f(1) -> ok.
X
cat > t_mine.erl <<'X'
-module(t_mine).
-export([f/1]).
-type mylist() :: {my, list}.
-spec f(mylist()) -> ok.
f({my, list}) -> ok.
X
cat > t_int_nowarn.erl <<'X'
-module(t_int_nowarn).
-export([f/1]).
-compile(nowarn_redefined_builtin_type).
-type integer() :: atom().
-spec f(integer()) -> ok.
f(a) -> ok.
X
cat > t_int_warn.erl <<'X'
-module(t_int_warn).
-export([f/1]).
-type integer() :: atom().
-spec f(integer()) -> ok.
f(a) -> ok.
X
t t_list; t t_atom; t t_atom_nowarn; t t_mine; t t_int_warn; t t_int_nowarn
echo "=== does the shadow take effect? (t_int_warn spec uses integer() = atom(); dialyzer-free check via abstract code)"
erlc +debug_info t_int_warn.erl 2>/dev/null; erl -noshell -eval '{ok,{_,[{abstract_code,{_,A}}]}}=beam_lib:chunks("t_int_warn.beam",[abstract_code]), [io:format("~p~n",[X])||X<-A, element(1,X)=:=attribute, element(3,X)=:=type orelse element(3,X)=:=spec],halt().'
