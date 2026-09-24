-module(ffi_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1,
                          escript/0, run_cli/1, with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% Calling Erlang

interop_src() ->
    "module Interop\n"
    "using :lists {\n"
    "    int sum(list<int> xs)\n"
    %% A foreign return guard can check the list, but not every element.
    "    list<term> reverse(list<term> xs)\n"
    "}\n"
    "public int Total(list<int> xs)\n"
    "Total(xs) -> :lists.sum(xs)\n"
    "public list<term> Backwards(list<term> xs)\n"
    "Backwards(xs) -> :lists.reverse(xs)\n".

a_foreign_call_runs_test() ->
    M = build_and_load(interop_src(), 'Interop'),
    ?assertEqual(10, M:'Total'([1, 2, 3, 4])),
    ?assertEqual([3, 2, 1], M:'Backwards'([1, 2, 3])).

%% A foreign declaration needs no local clauses.
a_foreign_block_is_not_a_stub_test() ->
    ?assertMatch({ok, _, []}, check_only(interop_src())).

%% Walk nested forms because the remote call sits inside a boundary guard.
a_foreign_call_is_a_remote_call_test() ->
    {ok, _} = compile(interop_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Interop.beam", [abstract_code]),
    Remotes = remotes(Forms),
    ?assert(lists:member({lists, sum}, Remotes)),
    ?assert(lists:member({lists, reverse}, Remotes)).

remotes({call, _, {remote, _, {atom, _, M}, {atom, _, F}}, As}) ->
    [{M, F} | remotes(As)];
remotes(T) when is_tuple(T) -> remotes(tuple_to_list(T));
remotes(L) when is_list(L)  -> lists:append([remotes(E) || E <- L]);
remotes(_)                  -> [].

%%% No statement terminator

no_semicolon_is_needed_test() ->
    Src = "module T\npublic int F(int n)\nF(n) when n > 0 -> n\nF(n) when n <= 0 -> 0\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

a_stray_semicolon_says_what_to_do_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            Src = "module T\npublic int F(int n)\nF(n) when n > 0 -> n;\nF(n) when n <= 0 -> 0\n",
            with_src("semi.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path),
                ?assert(string:find(R, "rc:1") =/= nomatch),
                ?assert(string:find(R, "beam-sharp has no `;`") =/= nomatch)
            end)
    end.
