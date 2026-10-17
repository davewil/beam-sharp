#!/usr/bin/env escript
%% usage: disasm.escript FILE.S ...
%% For each compile:file(..., 'S') listing, prints per hot function (wrap, hit,
%% spin, case-insensitive): instruction count (line/label/var_info comments
%% excluded), count of `{tr,_,Type}` operand annotations, the set of types, and
%% a digest of the opcode+operand shape with labels and names normalised, so two
%% listings can be compared for IDENTITY rather than by eye.
main(Files) ->
    [show(F) || F <- Files], ok.

show(File) ->
    {ok, Terms} = file:consult(File),
    io:format("~s~n", [File]),
    [report(F) || F <- split(Terms, [])],
    ok.

%% A .S listing is a flat list of terms; `{function,Name,Arity,Entry}` opens one.
split([], Acc) -> lists:reverse(Acc);
split([{function, N, A, _} | T], Acc) ->
    {Body, Rest} = lists:splitwith(fun(X) -> not is_tuple(X) orelse element(1, X) =/= function end, T),
    split(Rest, [{N, A, Body} | Acc]);
split([_ | T], Acc) -> split(T, Acc).

report({Name, _A, Is}) ->
    L = string:lowercase(atom_to_list(Name)),
    case lists:member(L, ["wrap", "spin", "hit"]) of
        false -> ok;
        true ->
            Real = [I || I <- Is, not skip(I)],
            Trs = collect_tr(Real),
            io:format("  ~-5s insns=~-3w tr_annotations=~-2w types=~w digest=~w~n",
                      [L, length(Real), length(Trs), lists:usort(Trs), erlang:phash2(norm(Real), 1 bsl 32)])
    end.

skip({line, _}) -> true;
skip({label, _}) -> true;
skip({func_info, _, _, _}) -> true;
skip({'%', _}) -> true;
skip(_) -> false.

collect_tr(T) when is_tuple(T), element(1, T) =:= tr -> [element(3, T)];
collect_tr(T) when is_tuple(T) -> lists:append([collect_tr(X) || X <- tuple_to_list(T)]);
collect_tr(L) when is_list(L) -> lists:append([collect_tr(X) || X <- L]);
collect_tr(_) -> [].

%% Names and label numbers differ between listings by construction; erase them.
norm({f, _}) -> f;
norm({atom, _}) -> atom;
norm({call, N, {f, _}}) -> {call, N};
norm({call_last, N, {f, _}, D}) -> {call_last, N, D};
norm({call_only, N, {f, _}}) -> {call_only, N};
norm(T) when is_tuple(T) -> list_to_tuple([norm(X) || X <- tuple_to_list(T)]);
norm(L) when is_list(L) -> [norm(X) || X <- L];
norm(X) -> X.
