-module(sizes).
-export([main/1, ops/1]).
main([A, B]) -> io:format("~s ~p raw / ~p stripped / ~p Code chunk~n", [A, filesize(B), stripped(B), code(B)]), halt().
filesize(F) -> {ok, I} = file:read_file_info(F), element(2, I).
stripped(F) -> {ok, Bin} = file:read_file(F), {ok, {_, B}} = beam_lib:strip(Bin), byte_size(B).
code(F) -> {ok,{_,[{"Code",C}]}} = beam_lib:chunks(F, ["Code"]), byte_size(C).
%% count selected instructions in the disassembly
ops(F) ->
    {beam_file, _, _, _, _, Fs} = beam_disasm:file(F),
    All = lists:append([Is || {function,_,_,_,Is} <- Fs]),
    T = fun(Name) -> length([I || I <- All, is_tuple(I), tuple_size(I) > 1, element(1,I) =:= test, element(2,I) =:= Name]) end,
    G = fun(Name) -> length([I || I <- All, is_tuple(I), tuple_size(I) > 1, element(1,I) =:= Name]) end,
    #{is_integer => T(is_integer), is_float => T(is_float), is_eq_exact => T(is_eq_exact),
      get_map_elements => G(get_map_elements), instructions => length(All)}.
