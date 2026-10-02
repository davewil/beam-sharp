#!/usr/bin/env escript
%% usage: asm_count.escript File.S FunName Arity
%% prints the instruction listing of one function and, on the last line,
%%   COUNT is_integer=<n> tagtest=<n> is_map=<n> instrs=<n>
%% tagtest = a map_get/get_map_elements on the atom 'kind'/'Kind' followed by an
%% is_eq_exact against an atom, counted as the number of is_eq_exact-on-atom tests.
main([File, Name, Arity]) ->
    {ok, Terms} = file:consult(File),
    F = list_to_atom(Name), A = list_to_integer(Arity),
    Is = take_fn(Terms, F, A),
    lists:foreach(fun(I) -> io:format("    ~w~n", [I]) end, Is),
    Real = [I || I <- Is, not is_tuple(I) orelse element(1, I) =/= label,
                 not is_tuple(I) orelse element(1, I) =/= line,
                 not is_tuple(I) orelse element(1, I) =/= '%',
                 not is_tuple(I) orelse element(1, I) =/= func_info],
    IsInt = length([x || {test, is_integer, _, _} <- Real]),
    Tag = length([x || {test, is_eq_exact, _, [_, {atom, _}]} <- Real]),
    IsMap = length([x || {test, is_map, _, _} <- Real]),
    io:format("COUNT is_integer=~p tagtest=~p is_map=~p instrs=~p~n",
              [IsInt, Tag, IsMap, length(Real)]).

%% a .S file is a flat list of terms: {function,N,A,Entry}. then that function's
%% instructions, up to the next {function,...} term.
take_fn([{function, F, A, _} | T], F, A) -> until_next(T);
take_fn([_ | T], F, A) -> take_fn(T, F, A);
take_fn([], F, A) -> error({no_such_function, F, A}).
until_next([{function, _, _, _} | _]) -> [];
until_next([H | T]) -> [H | until_next(T)];
until_next([]) -> [].
