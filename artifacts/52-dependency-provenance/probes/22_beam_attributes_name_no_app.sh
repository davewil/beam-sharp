#!/bin/sh
# Does a compiled .beam say which application it belongs to? Attributes of beams from each toolchain.
. "$(dirname "$0")/env.sh"
erl -noshell -eval '
Show = fun(Label, F) ->
   {ok, {_, [{attributes, A}, {compile_info, CI}]}} = beam_lib:chunks(F, [attributes, compile_info]),
   io:format("~-34s attributes=~p~n~34s compile_info keys=~p~n", [Label, A, "", [K || {K,_} <- CI]]) end,
Show("mix (Elixir.Greeter)", "/tmp/p52/greeter_build/dev/lib/greeter/ebin/Elixir.Greeter.beam"),
Show("rebar3 (rlib)", "/tmp/p52/rlib_src/_build/default/lib/rlib/ebin/rlib.beam"),
Show("gleam (glib)", "/tmp/p52/glib_src/build/dev/erlang/glib/ebin/glib.beam"),
Show("bsc (Greet)", "/tmp/p52/greet/out/Greet.beam"),
Show("OTP (lists)", "/opt/otp28/lib/erlang/lib/stdlib-7.0/ebin/lists.beam"),
halt().'
