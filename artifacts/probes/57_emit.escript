#!/usr/bin/env escript
%%! -noshell
%% helper for 57_emit.sh: prints beam size, beam_lib:md5 (code chunks only), Lit's abstract form, results
main([Dir, File]) ->
    true = code:add_patha(Dir),
    {ok, {_, MD5}} = beam_lib:md5(File),
    {ok, {_, [{abstract_code, {_, AC}}]}} = beam_lib:chunks(File, [abstract_code]),
    Lit = [Cl || {function, _, 'Lit', _, Cl} <- AC],
    S = fun(T) -> lists:flatten(io_lib:format("~w", [strip(T)])) end,
    io:format("   size=~pB beam_lib:md5=~s~n   Lit abstract: ~s~n", [filelib:file_size(File), binary:encode_hex(MD5, lowercase) , S(Lit)]),
    io:format("   run: Lit=~w Sum(10)=~w Mix=~w Neg2=~w Mul=~w Div=~w Rem=~w Big=~w~n",
      [catch 'M':'Lit'(), catch 'M':'Sum'(10), catch 'M':'Mix'(), catch 'M':'Neg2'(), catch 'M':'Mul'(), catch 'M':'Div'(), catch 'M':'Rem'(), catch 'M':'Big'()]).
strip({L, C}) when is_integer(L), is_integer(C) -> l;
strip(T) when is_tuple(T) -> list_to_tuple([strip(X) || X <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(X) || X <- L];
strip(X) -> X.
