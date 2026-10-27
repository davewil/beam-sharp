#!/bin/bash
# H1: a call to a module absent from the code path compiles with NO diagnostic from erlc,
#     loads fine, and fails only when the call executes, as error:undef naming M:F/A.
# H2: a never-taken branch holding such a call is silent at load AND at run time.
# H3: Elixir renders the same BEAM error as UndefinedFunctionError "module Req is not available".
# Falsified if erlc warns, load fails, never() fails, or the error is not undef.
W=$(mktemp -d); cd $W
cat > foreign_call.erl <<'EOF'
-module(foreign_call).
-export([go/0, never/0]).
go() -> 'Elixir.Req':new([{url, <<"x">>}]).
never() -> case erlang:phash2(1) of 0 -> 'Elixir.Req':new([]); _ -> fine end.
EOF
echo "--- erlc output (expect empty):"; erlc foreign_call.erl; echo "erlc exit=$?"
cat > chk.escript <<'EOF'
#!/usr/bin/env escript
main(_) ->
  io:format("OTP ~s~n",[erlang:system_info(otp_release)]),
  io:format("load: ~p~n",[code:load_file(foreign_call)]),
  io:format("never(): ~p~n",[foreign_call:never()]),
  io:format("code:which('Elixir.Req'): ~p~n",[code:which('Elixir.Req')]),
  R = (catch foreign_call:go()),
  [{'EXIT',{undef,[Top|_]}}] = [R],
  io:format("top frame: ~p~n",[Top]),
  case Top of {'Elixir.Req',new,[_],[]} -> io:format("H1/H2 HOLD~n");
            _ -> io:format("H1/H2 FALSIFIED~n") end.
EOF
ERL_FLAGS="-pa $W" escript chk.escript
echo "--- Elixir $(elixir --version | tail -1):"
ELIXIR_ERL_OPTIONS="-pa $W" elixir -e 'try do :foreign_call.go() rescue e -> IO.puts(Exception.message(e)) end; try do Req.new() rescue e -> IO.puts(Exception.message(e)) end'
