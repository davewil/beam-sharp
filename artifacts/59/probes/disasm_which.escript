#!/usr/bin/env escript
%% disasm_which.escript DIR -- name each LOCAL function whose bytecode still has an is_integer test.
main([Dir]) ->
    [begin
        {ok, {_, [{abstract_code, {raw_abstract_v1, Forms}}]}} = beam_lib:chunks(B, [abstract_code]),
        Ex = lists:append([E || {attribute, _, export, E} <- Forms]),
        Esc = lists:usort(esc(Forms)),
        {beam_file, M, _, _, _, Fs} = beam_disasm:file(B),
        [io:format("  ~s:~s/~p  escapes-as-fun=~p~n", [M, N, A, lists:member({N, A}, Esc)])
         || {function, N, A, _, Is} <- Fs, N =/= module_info, not lists:member({N, A}, Ex),
            lists:any(fun({test, is_integer, _, _}) -> true; (_) -> false end, Is)]
     end || B <- filelib:wildcard(filename:join(Dir, "**/*.beam"))], ok.
esc(T) when is_tuple(T) ->
    case T of {'fun', _, {function, N, A}} when is_atom(N), is_integer(A) -> [{N, A}];
              _ -> lists:append([esc(E) || E <- tuple_to_list(T)]) end;
esc(L) when is_list(L) -> lists:append([esc(E) || E <- L]);
esc(_) -> [].
