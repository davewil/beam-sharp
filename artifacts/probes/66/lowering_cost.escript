#!/usr/bin/env escript
%% ticket 66: three ways to lower `Handle(C c)` where C = M1 | ... | Mn, measured on OTP 28.
%%   dup    - one clause per member, body repeated (what exemplar 4 makes an author write today)
%%   guard  - ONE clause, tag test as a guard disjunction, c bound to the whole value
%%   shared - one head per member, each calling one compiler-made local body function
main(_) ->
    Body = "begin X1 = map_get('Id', C) * 3 + 1, X2 = map_get('Total', C) - X1, "
           "case X2 > 10 of true -> {big, X2 rem 7, X1}; false -> {small, X1 bsr 1, X2} end end",
    Dir = "lowering_tmp", ok = filelib:ensure_dir(Dir ++ "/x"),
    io:format("~-4s ~-7s ~8s ~12s~n", ["N","form","beam B","ns/call(last)"]),
    [begin
         Tags = [list_to_atom("T.M" ++ integer_to_list(I)) || I <- lists:seq(1, N)],
         [begin
              Mod = list_to_atom("l_" ++ atom_to_list(F) ++ "_" ++ integer_to_list(N)),
              Src = gen(F, Mod, Tags, Body),
              File = filename:join(Dir, atom_to_list(Mod) ++ ".erl"),
              ok = file:write_file(File, Src),
              {ok, Mod, Bin} = compile:file(File, [binary, return_errors]),
              {module, Mod} = code:load_binary(Mod, File, Bin),
              Arg = #{'Kind' => lists:last(Tags), 'Id' => 5, 'Total' => 30},
              T = bench(Mod, Arg, 2000000),
              io:format("~-4w ~-7w ~8w ~12.1f~n", [N, F, byte_size(Bin), T])
          end || F <- [dup, guard, shared]]
     end || N <- [2, 5, 20]].

gen(dup, M, Tags, B) ->
    H = io_lib:format("-module(~w).~n-export(['Handle'/1]).~n", [M]),
    Cl = [io_lib:format("'Handle'(C = #{'Kind' := ~p}) -> ~s;~n", [T, B]) || T <- Tags],
    [H, Cl, "'Handle'(none) -> none.\n"];
gen(guard, M, Tags, B) ->
    Gs = lists:join(" orelse ", [io_lib:format("map_get('Kind', C) =:= ~p", [T]) || T <- Tags]),
    [io_lib:format("-module(~w).~n-export(['Handle'/1]).~n", [M]),
     io_lib:format("'Handle'(C) when ~s -> ~s;~n'Handle'(none) -> none.~n", [Gs, B])];
gen(shared, M, Tags, B) ->
    Cl = [io_lib:format("'Handle'(C = #{'Kind' := ~p}) -> body(C);~n", [T]) || T <- Tags],
    [io_lib:format("-module(~w).~n-export(['Handle'/1]).~n", [M]), Cl,
     "'Handle'(none) -> none.\n", io_lib:format("body(C) -> ~s.~n", [B])].

bench(M, Arg, N) ->
    M:'Handle'(Arg),
    {US, _} = timer:tc(fun() -> loop(M, Arg, N) end),
    US * 1000 / N.
loop(_, _, 0) -> ok;
loop(M, A, N) -> M:'Handle'(A), loop(M, A, N - 1).
