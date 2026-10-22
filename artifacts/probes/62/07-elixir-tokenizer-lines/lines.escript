#!/usr/bin/env escript
main([Beam]) ->
  {ok,{_,[{abstract_code,{_,AC}}]}} = beam_lib:chunks(Beam,[abstract_code]),
  Has = fun(C, S) -> string:find(lists:flatten(io_lib:format("~p",[C])), S) =/= nomatch end,
  [[io:format("elixir_tokenizer.erl:~p  clause of handle_dot/6 for `. \"quoted\"` calls; ~s~n",
        [element(1,element(2,C)), case Has(C,"unnecessary_quote") of true -> "it warns \"found quoted call ... quotes are not required\" for plain names"; _ -> "" end])
    || C <- element(5,F), Has(C,"found quoted call")] || F={function,_,handle_dot,6,_} <- AC],
  [[io:format("elixir_tokenizer.erl:~p  clause of handle_terminator/6 containing the \"unexpected ( after alias\" error (what `:Shop.New(1)` hits)~n",
        [element(1,element(2,C))]) || C <- element(5,F), Has(C,"after alias")] || F={function,_,handle_terminator,6,_} <- AC].
