#!/usr/bin/env bash
# 57g: how do Erlang and Elixir represent a negative literal in expression / pattern / guard / type position?
# (No .yrl/.erl/.ex sources are installed for either - only ebin - so this is behavioural, not file:line.)
echo "=== Erlang (OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')) ==="
cat > /tmp/p57g.erl <<'ERL'
-module(p57g).
-export([f/1, g/1]).
-type delta() :: -100..100.
f(-5) -> a;
f(X) when X >= -5 -> b;
f(_) -> c.
g(X) -> -5 + X.
ERL
erl -noshell -eval '
{ok,Forms} = epp:parse_file("/tmp/p57g.erl", []),
[io:format("~p~n",[F]) || F <- Forms, element(1,F) =:= attribute andalso element(3,F) =:= type orelse element(1,F) =:= function],
io:format("erl_lint: ~p~n",[element(1, erl_lint:module(Forms))]),
halt().' 2>&1 | grep -v "^{attribute,[0-9]*,\(file\|module\|export\)"
echo
echo "=== Elixir $(elixir --version 2>&1 | tail -1) ==="
elixir -e '
for src <- ["-5", "x >= -5", "-x", "-(5)", "- -5", "-5..5", "2 + 3"] do
  IO.puts(String.pad_trailing(src, 10) <> inspect(Code.string_to_quoted!(src), limit: :infinity))
end
defmodule P57g do
  @type delta :: -100..100
  def f(-5), do: :a
  def f(x) when x >= -5, do: :b
  def f(_), do: :c
end
IO.inspect({P57g.f(-5), P57g.f(0), P57g.f(-9)}, label: "compiled and ran")'
