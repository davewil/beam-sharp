#!/usr/bin/env escript
%% Elixir ships elixir_parser.beam only (no .yrl in the install), so read the
%% compiled parser's own abstract code for build_unary_op/2: does the PARSER fold `-5`?
main(_) ->
    {ok,{_,[{abstract_code,{_,AC}}]}} = beam_lib:chunks("/tmp/otp/lib/elixir/lib/elixir/ebin/elixir_parser.beam",[abstract_code]),
    [io:format("~s~n",[erl_pp:form(F)]) || F <- AC, element(1,F)==function, element(3,F) == build_unary_op].
