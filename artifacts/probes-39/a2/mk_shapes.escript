#!/usr/bin/env escript
-mode(compile).
%% Builds four stand-ins for the abstract forms bsc would hand to compile:file(..,[from_abstr,debug_info]) for
%% aoc/bench/Day01/bench_bs.bs, by rewriting the parsed forms of an Erlang source (rem is an Erlang keyword, so a
%% remote call erlang:rem(..) cannot be written in source; it must be built as a form, as bs_emit does).
%%   sh_op     : operators (`rem` as {op,..}); B#'s clause shapes (sign/size with guards), no spec
%%   sh_remote : every `rem` becomes {call,{remote,erlang,rem}}  (bs_emit.erl:1133 e_foreign_call, unguarded)
%%   sh_spec   : sh_remote + widened integer() specs for all 7 functions (ticket 13 s6, bs_emit.erl:8-11)
%%   sh_guard  : sh_spec + each remote rem wrapped in  case Call of V when is_integer(V) -> V end  (return_guard/3,
%%               bs_emit.erl:1259-1266, F42 2026-09-11)
main([Dir]) ->
    Src = src(""), SpecSrc = src(specs()),
    Op = forms("sh_op", Src),
    mk(Dir, sh_op, Op),
    Rem = rewrite(forms("sh_remote", Src), fun remote/1),
    mk(Dir, sh_remote, Rem),
    Spec = rewrite(forms("sh_spec", SpecSrc), fun remote/1),
    mk(Dir, sh_spec, Spec),
    Guard = rewrite(forms("sh_guard", SpecSrc), fun(E) -> guarded(remote(E)) end),
    mk(Dir, sh_guard, Guard).

specs() ->
 "-spec wrap(integer()) -> integer().\n-spec hit(integer()) -> integer().\n"
 "-spec spin(integer(), integer(), integer(), integer()) -> {integer(), integer()}.\n"
 "-spec sign(integer()) -> integer().\n-spec size_(integer()) -> integer().\n"
 "-spec clicks([integer()], integer(), integer()) -> integer().\n-spec part_two([integer()]) -> integer().\n".
src(Specs) ->
 "-module(M). -export([part_two/1]).\n" ++ Specs ++
 "wrap(N) -> ((N rem 100) + 100) rem 100.\n"
 "hit(0) -> 1;\nhit(_N) -> 0.\n"
 "spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};\n"
 "spin(Pos, Step, Left, Zeros) ->\n    Next = wrap(Pos + Step),\n    spin(Next, Step, Left - 1, Zeros + hit(Next)).\n"
 "sign(D) when D < 0 -> -1;\nsign(D) when D >= 0 -> 1.\n"
 "size_(D) when D < 0 -> -D;\nsize_(D) when D >= 0 -> D.\n"
 "clicks([], _Pos, Zeros) -> Zeros;\n"
 "clicks([D | Rest], Pos, Zeros) ->\n    {Next, Hits} = spin(Pos, sign(D), size_(D), Zeros),\n    clicks(Rest, Next, Hits).\n"
 "part_two(Rs) -> clicks(Rs, 50, 0).\n".
forms(ModName, Text0) ->
    Text = re:replace(Text0, "-module\\(M\\)", "-module(" ++ ModName ++ ")", [{return, list}]),
    {ok, Toks, _} = erl_scan:string(Text),
    Chunks = split(Toks, [], []),
    [begin {ok, F} = erl_parse:parse_form(C), F end || C <- Chunks].
split([], [], Acc) -> lists:reverse(Acc);
split([{dot,_}=D | T], Cur, Acc) -> split(T, [], [lists:reverse([D | Cur]) | Acc]);
split([H | T], Cur, Acc) -> split(T, [H | Cur], Acc).

rewrite(Forms, Fun) -> [rw(F, Fun) || F <- Forms].
rw({function, L, N, A, Cs}, Fun) -> {function, L, N, A, [rw(C, Fun) || C <- Cs]};
rw(T, Fun) when is_tuple(T) ->
    T1 = list_to_tuple([rw(E, Fun) || E <- tuple_to_list(T)]),
    case T1 of {op, _, 'rem', _, _} -> Fun(T1); _ -> T1 end;
rw(L, Fun) when is_list(L) -> [rw(E, Fun) || E <- L];
rw(T, _) -> T.
remote({op, L, 'rem', A, B}) -> {call, L, {remote, L, {atom, L, erlang}, {atom, L, 'rem'}}, [A, B]}.
guarded({call, L, _, _} = C) ->
    V = {var, L, list_to_atom("RV" ++ integer_to_list(erlang:unique_integer([positive])))},
    {'case', L, C, [{clause, L, [V], [[{call, L, {atom, L, is_integer}, [V]}]], [V]}]}.

mk(Dir, Mod, Forms) ->
    {ok, Mod, Beam} = compile:forms(Forms, [debug_info, return_errors]),
    ok = file:write_file(filename:join(Dir, atom_to_list(Mod) ++ ".beam"), Beam).
