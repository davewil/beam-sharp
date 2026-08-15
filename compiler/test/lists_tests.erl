-module(lists_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% Lists
%%%
%%% `[]` and `[h, ..t]` partition list<T>, which is what lets a list function be
%%% exhaustive with no catch-all. Ticket 08 settled prefix-plus-rest only.
%%% ---------------------------------------------------------------------------

series_src() ->
    %% Not `Fib`: the reload test defines its own scalar `Fib` module and the two
    %% would clobber one another's .beam and loaded code.
    "module FibL\n"
    "list<int> Fib(int n)\n"
    "Fib(n) when n <= 0 -> []\n"
    "Fib(n) when n > 0  -> Series(n, 0, 1, [])\n"
    "list<int> Series(int n, int a, int b, list<int> acc)\n"
    "Series(n, a, b, acc) when n <= 0 -> Reverse(acc, [])\n"
    "Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])\n"
    "list<int> Reverse(list<int> xs, list<int> acc)\n"
    "Reverse([], acc)          -> acc\n"
    "Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])\n".

a_list_function_computes_test() ->
    M = build_and_load(series_src(), 'FibL'),
    ?assertEqual([], M:'Fib'(0)),
    ?assertEqual([0], M:'Fib'(1)),
    ?assertEqual([0, 1, 1, 2, 3], M:'Fib'(5)),
    ?assertEqual([0, 1, 1, 2, 3, 5, 8, 13, 21, 34], M:'Fib'(10)).

%% The pair is exhaustive: no catch-all clause, and no diagnostic.
nil_and_cons_partition_a_list_test() ->
    {ok, _} = compile(series_src()),
    {ok, Toks, _} = bs_lexer:string(series_src()),
    {ok, Decls} = bs_parser:parse(Toks),
    {ok, _, Diags} = bs_check:check(Decls),
    ?assertEqual([], [D || D <- Diags, element(1, D) =:= error]).

%% Drop `Reverse([], acc)` and the residual must name the empty list.
missing_nil_clause_is_caught_test() ->
    Src = "module L\nlist<int> Rev(list<int> xs, list<int> acc)\n"
          "Rev([x, ..rest], acc) -> Rev(rest, [x, ..acc])\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    {error, Diags} = bs_check:check(Decls),
    [{error, _, 'Rev', {inexhaustive, Residual}}] =
        [D || D <- Diags, element(1, D) =:= error],
    ?assert(string:find(bs_types:to_string(Residual), "[]") =/= nomatch).

%% Every self-call is a BEAM tail call — `call_only`, not `call` plus a frame.
%% Asserted on the emitted bytecode rather than on the source's shape.
recursion_is_a_tail_call_test() ->
    {ok, _} = compile(series_src()),
    {beam_file, _, _, _, _, Fns} = beam_disasm:file(?OUT ++ "/FibL.beam"),
    Bad = [{Name, Op}
           || {function, Name, _A, _E, Is} <- Fns,
              Name =/= module_info,
              {Op} <- [{element(1, I)} || I <- Is, is_tuple(I)],
              Op =:= call orelse Op =:= call_ext],
    ?assertEqual([], Bad).

%% Flat stack at a depth that would blow a body-recursive version.
tail_calls_do_not_grow_the_stack_test() ->
    M = build_and_load(series_src(), 'FibL'),
    Self = self(),
    Pid = spawn(fun() ->
                    _ = M:'Fib'(50000),
                    {stack_size, S} = erlang:process_info(self(), stack_size),
                    Self ! {stack, S}
                end),
    receive {stack, S} -> ?assert(S < 100)
    after 60000 -> exit({timeout, Pid}) end.

