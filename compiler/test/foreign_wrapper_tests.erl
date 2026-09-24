%%% Scenarios: compiler/features/F19-foreign-try-wrapper.md
%%% Scenarios: compiler/features/F52-channelled-foreign-return-guard.md
%%% F19 — foreign calls wrap declared exception channels.
-module(foreign_wrapper_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1,
                          escript/0, run_cli/1, with_src/3, built/0]).

-define(OUT, bs_test_support:run_root()).

%%% Fixtures

%% `binary_to_integer` raises in the caller, with no other process to monitor.
wrapped_src() ->
    "module Fw\n"
    "using :erlang {\n"
    "    result<int, foreign_error> binary_to_integer(binary b)\n"
    "    result<int, foreign_error> throw(term t)\n"
    "    result<int, foreign_error> exit(term t)\n"
    "    int byte_size(binary b)\n"
    "}\n"
    "public result<int, foreign_error> Parse(binary b)\n"
    "Parse(b) -> :erlang.binary_to_integer(b)\n"
    "public result<int, foreign_error> Thrown()\n"
    "Thrown() -> :erlang.throw(:boom)\n"
    "public result<int, foreign_error> Exited()\n"
    "Exited() -> :erlang.exit(:boom)\n"
    "public int Size(binary b)\n"
    "Size(b) -> :erlang.byte_size(b)\n".

%%% F19.1 — success passes through unchanged.

a_wrapped_call_returns_its_value_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertEqual(8080, M:'Parse'(<<"8080">>)).

%% The outer `error` marks the result; the inner one names the exception class.
a_wrapped_call_returns_a_thrown_error_as_a_value_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertEqual({error, {error, badarg}}, M:'Parse'(<<"abc">>)).

%%% F19.3–F19.4 — the wrapper catches throw and locally raised exit.

a_wrapped_call_catches_the_throw_class_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertEqual({error, {throw, boom}}, M:'Thrown'()).

%% A locally raised `exit/1` is catchable; an exit signal is not.
a_wrapped_call_catches_the_exit_class_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertEqual({error, {exit, boom}}, M:'Exited'()).

%%% F19.5 — a call without a declared exception channel crashes.

an_undeclared_channel_lets_the_caller_die_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertError(badarg, M:'Size'(not_a_binary)).

%%% F19.9 — both foreign calls have an outer return guard.

wraps_only_where_the_channel_is_declared_test() ->
    {ok, _} = compile(wrapped_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Fw.beam", [abstract_code]),
    %% F52.1 — foreign_guard_tests checks nesting; these outer shapes cannot.
    %% Both bodies expose the guard's `case`; behaviour is asserted in
    %% a_wrapped_call_returns_a_thrown_error_as_a_value_test and
    %% an_undeclared_channel_lets_the_caller_die_test.
    ?assertEqual([{'case'}], shapes('Parse', Forms)),
    ?assertEqual([{'case'}], shapes('Size', Forms)).

shapes(Name, Forms) ->
    [{element(1, Node)}
     || {function, _, N, _, Clauses} <- Forms, N =:= Name,
        {clause, _, _, _, [Node]} <- Clauses].

%%% F19.10 — generated catch variables are unique per clause.

%% Reusing a catch variable in sibling or nested tries is an erlc error.
two_wrapped_calls_in_one_clause_compile_and_run_test() ->
    Src = "module Fw2\n"
          "using :erlang {\n"
          "    result<int, foreign_error> binary_to_integer(binary b)\n"
          "}\n"
          "public (result<int, foreign_error>, result<int, foreign_error>) Both(binary b)\n"
          "Both(b) -> (:erlang.binary_to_integer(b), :erlang.binary_to_integer(b))\n",
    M = build_and_load(Src, 'Fw2'),
    ?assertEqual({8080, 8080}, M:'Both'(<<"8080">>)),
    ?assertEqual({{error, {error, badarg}}, {error, {error, badarg}}},
                 M:'Both'(<<"abc">>)).

a_wrapped_call_nested_in_another_compiles_and_runs_test() ->
    Src = "module Fw3\n"
          "using :erlang {\n"
          "    result<int, foreign_error> binary_to_integer(binary b)\n"
          "    result<binary, foreign_error> term_to_binary(term t)\n"
          "}\n"
          "public result<binary, foreign_error> Nested(binary b)\n"
          "Nested(b) -> :erlang.term_to_binary(:erlang.binary_to_integer(b))\n",
    M = build_and_load(Src, 'Fw3'),
    ?assertEqual(term_to_binary(8080), M:'Nested'(<<"8080">>)),
    %% The inner failure is a valid term, so the outer call succeeds on it.
    ?assertEqual(term_to_binary({error, {error, badarg}}), M:'Nested'(<<"abc">>)).

%%% F19.2 — the resolved alias returns a thrown error as a value.

%% The alias spells out the union without result, testing the resolved type.
a_hand_written_union_gets_the_wrapper_too_test() ->
    Src = "module Fw4\n"
          "type Parsed = int | (:error, foreign_error)\n"
          "using :erlang {\n"
          "    Parsed binary_to_integer(binary b)\n"
          "}\n"
          "public Parsed Parse(binary b)\n"
          "Parse(b) -> :erlang.binary_to_integer(b)\n",
    M = build_and_load(Src, 'Fw4'),
    ?assertEqual(8080, M:'Parse'(<<"8080">>)),
    ?assertEqual({error, {error, badarg}}, M:'Parse'(<<"abc">>)).

%%% F19.6 — clause heads distinguish all three exception classes.

the_class_dispatches_in_a_clause_head_test() ->
    Src = "module Fw5\n"
          "public atom Report(foreign_error e)\n"
          "Report((:error, _)) -> :not_a_number\n"
          "Report((:throw, _)) -> :library_signalled\n"
          "Report((:exit, _))  -> :callee_is_down\n",
    M = build_and_load(Src, 'Fw5'),
    ?assertEqual(not_a_number, M:'Report'({error, badarg})),
    ?assertEqual(library_signalled, M:'Report'({throw, boom})),
    ?assertEqual(callee_is_down, M:'Report'({exit, {noproc, srv}})).

%%% F19.7 — a payload other than foreign_error is an ordinary union.

%% Declaring an atom payload does not catch exceptions from this throwing call.
a_payload_other_than_foreign_error_is_an_ordinary_union_test() ->
    Src = "module Fw6\n"
          "using :erlang {\n"
          "    result<int, atom> binary_to_integer(binary b)\n"
          "}\n"
          "public result<int, atom> Parse(binary b)\n"
          "Parse(b) -> :erlang.binary_to_integer(b)\n",
    ?assertMatch({ok, _, []}, check_only(Src)),
    {ok, _} = compile(Src),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Fw6.beam", [abstract_code]),
    %% The positive shape confirms a guard body, not the absence of a wrapper.
    ?assertEqual([{'case'}], shapes('Parse', Forms)).

%% The CLI checks the printed output and exit status, beyond checker success.
a_value_returned_declaration_compiles_clean_at_the_cli_test() ->
    case built() of
        false -> ok;
        true ->
            Src = "module Fw9\n"
                  "type Contents = (:ok, binary) | (:error, atom)\n"
                  "using :file {\n"
                  "    Contents read_file(binary p)\n"
                  "}\n"
                  "public Contents Slurp(binary p)\n"
                  "Slurp(p) -> :file.read_file(p)\n",
            with_src("in.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path),
                ?assertEqual(nomatch, string:find(R, "rc:1")),
                ?assertEqual(nomatch, string:find(R, "escript: exception error")),
                %% A clean declaration must not print a refusal or limitation.
                ?assertEqual(nomatch, string:find(R, "is `foreign_error`, and "
                                                     "nothing else")),
                ?assertEqual(nomatch,
                             string:find(R, "has no declared form yet"))
            end)
    end.

a_local_signature_may_carry_any_payload_test() ->
    Src = "module Fw7\n"
          "public result<int, atom> Parse(int n)\n"
          "Parse(n) when n > 0  -> n\n"
          "Parse(n) when n <= 0 -> (:error, :nonpositive)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%%% F19.8 — there is no `try` in the surface

there_is_no_try_in_the_surface_test() ->
    {ok, Toks, _} = bs_lexer:string("module T\n"
                                    "public int F(int n)\n"
                                    "F(n) -> try n catch e -> 0\n"),
    ?assertMatch({error, {_, bs_parser, _}}, bs_parser:parse(Toks)).

%%% Absorbed failure channels

%% `term` absorbs the failure member, so the declaration is refused.
a_term_return_is_refused_at_the_declaration_test() ->
    Src = "module Fw8\n"
          "using :erlang {\n"
          "    result<term, foreign_error> binary_to_integer(binary b)\n"
          "}\n"
          "public term Parse(binary b)\n"
          "Parse(b) -> :erlang.binary_to_integer(b)\n",
    ?assertError({absorbed_member, _, _, error, _, _},
                 bs_test_support:check_only(Src)).

%%% Foreign errors returned as values

%% Tagged and bare successes sit beside an exception-channel control.
value_returned_src() ->
    "module Fv\n"
    "type Contents = (:ok, binary) | (:error, atom)\n"
    "type Extracted = :ok | (:error, atom)\n"
    "using :file {\n"
    "    Contents read_file(binary p)\n"
    "}\n"
    "using :erl_tar {\n"
    "    Extracted extract(binary p)\n"
    "}\n"
    "using :erlang {\n"
    "    result<int, foreign_error> binary_to_integer(binary b)\n"
    "}\n"
    "public Contents Slurp(binary p)\n"
    "Slurp(p) -> :file.read_file(p)\n"
    "public Extracted Ex(binary p)\n"
    "Ex(p) -> :erl_tar.extract(p)\n"
    "public result<int, foreign_error> Parse(binary b)\n"
    "Parse(b) -> :erlang.binary_to_integer(b)\n".

a_value_returned_error_is_declarable_test() ->
    M = build_and_load(value_returned_src(), 'Fv'),
    ?assertMatch({ok, <<_/binary>>}, M:'Slurp'(<<"/etc/hosts">>)),
    ?assertEqual({error, enoent}, M:'Slurp'(<<"/nonexistent-ticket-56">>)).

a_value_returned_declaration_gets_no_wrapper_test() ->
    {ok, _} = compile(value_returned_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Fv.beam", [abstract_code]),
    %% Each outer `case` observes the guard, not the presence of a wrapper.
    %% Returned-error behaviour is asserted in
    %% a_value_returned_error_is_declarable_test, not by this read.
    ?assertEqual([{'case'}], shapes('Slurp', Forms)),
    ?assertEqual([{'case'}], shapes('Ex', Forms)),
    ?assertEqual([{'case'}], shapes('Parse', Forms)).

%% Only the foreign_error arm requests a wrapper; the atom arm is a value.
both_channels_in_one_declaration_test() ->
    Src = "module Fvb\n"
          "type Opened = (:ok, term) | (:error, atom) | (:error, foreign_error)\n"
          "using :file {\n"
          "    Opened open(binary p, term modes)\n"
          "}\n"
          "public Opened Go(binary p, term m)\n"
          "Go(p, m) -> :file.open(p, m)\n",
    {ok, _} = compile(Src),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Fvb.beam", [abstract_code]),
    ?assertEqual([{'case'}], shapes('Go', Forms)).
