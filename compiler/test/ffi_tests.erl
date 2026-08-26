-module(ffi_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1,
                          escript/0, run_cli/1, with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% Calling Erlang
%%%
%%% The module is an atom, so the call site is Elixir's and nothing is renamed.
%%% ---------------------------------------------------------------------------

interop_src() ->
    "module Interop\n"
    "using :lists {\n"
    "    int sum(list<int> xs)\n"
    "    list<int> reverse(list<int> xs)\n"
    "}\n"
    "public int Total(list<int> xs)\n"
    "Total(xs) -> :lists.sum(xs)\n"
    "public list<int> Backwards(list<int> xs)\n"
    "Backwards(xs) -> :lists.reverse(xs)\n".

a_foreign_call_runs_test() ->
    M = build_and_load(interop_src(), 'Interop'),
    ?assertEqual(10, M:'Total'([1, 2, 3, 4])),
    ?assertEqual([3, 2, 1], M:'Backwards'([1, 2, 3])).

%% A `using` block is a declaration, not an unfinished function: it must not be
%% reported as a signature with no clauses.
a_foreign_block_is_not_a_stub_test() ->
    ?assertMatch({ok, _, []}, check_only(interop_src())).

%% It emits an ordinary BEAM remote call.
a_foreign_call_is_a_remote_call_test() ->
    {ok, _} = compile(interop_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Interop.beam", [abstract_code]),
    Remotes = [{M, F} || {function, _, _, _, Cs} <- Forms,
                         {clause, _, _, _, Body} <- Cs,
                         {call, _, {remote, _, {atom, _, M}, {atom, _, F}}, _} <- Body],
    ?assert(lists:member({lists, sum}, Remotes)),
    ?assert(lists:member({lists, reverse}, Remotes)).

%%% ---------------------------------------------------------------------------
%%% No statement terminator
%%%
%%% Both audiences type `;` from habit, so it is the likeliest error in the
%%% language and owes the sharpest message.
%%% ---------------------------------------------------------------------------

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
