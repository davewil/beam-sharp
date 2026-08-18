-module(pipe_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1,
                          escript/0, run_cli/1, with_src/3]).

%%% ---------------------------------------------------------------------------
%%% F14 — the pipe and the valve, ticket 17 §1 and §4
%%%
%%% Two operators built in two different places, and the tests below are mostly
%%% about that difference rather than about either operator:
%%%
%%%   `|>`  is a REWRITE the parser performs. Nothing downstream learns it
%%%         exists, so there is very little to assert about the pipe that is not
%%%         already an assertion about ordinary calls — which is the claim, and
%%%         the reason the pipe's tests are short.
%%%
%%%   `|?>` BRANCHES, so it lowers to the two-armed `switch` F7 built. Its tests
%%%         are longer because the interesting properties are all about the
%%%         GENERATED code: that its arms are typed, that its binder cannot
%%%         collide, and that the checker never advises the author about arms
%%%         `bs_lower` wrote.
%%%
%%% TWO OF THE ELEVEN SCENARIOS CAN ONLY LIVE HERE. F14.4 and F14.9 are
%%% refusals, and `examples/` must compile by construction — so the corpus can
%%% never carry them. That is the split the features README names, and F12
%%% recorded the same debt when four of its five behaviours turned out to be
%%% refusals.
%%% ---------------------------------------------------------------------------

%% Drive the real escript over a real file, because both refusals below are
%% about what the AUTHOR is told — an exit code and a sentence — and neither is
%% observable from a diagnostic term. Guarded on the escript existing through
%% `bs_test_support:built/0`, which ANNOUNCES the skip.
%%
%% This comment used to cite "the house convention in `cli_tests`", and that
%% convention had been deleted before this file was written: `cli_tests` removed
%% its silent guard precisely because it made a test green and empty. A citation
%% stands in for a claim, and nobody re-reads a claim they can defer.
cli(Src, Assert) ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("in.bs", Src,
                     fun(Path, Root) ->
                             Assert(run_cli("--src-root " ++ Root ++ " " ++ Path))
                     end)
    end.

res_src() ->
    "module Res\n"
    "type Res = int | (:error, atom)\n"
    "public Res Start(int n)\n"
    "Start(n) when n > 0  -> n\n"
    "Start(n) when n <= 0 -> (:error, :bad)\n".

%%% --- the pipe ---------------------------------------------------------------

%% F14.1. The piped value is the FIRST argument, which is the whole of ticket 17
%% §1's mechanism.
the_piped_value_becomes_the_first_argument_test() ->
    Src = "module P\n"
          "public int Add(int a, int b)\n"
          "Add(a, b) -> a + b\n"
          "public int Double(int n)\n"
          "Double(n) -> n |> Add(n)\n",
    M = build_and_load(Src, 'P'),
    ?assertEqual(8, M:'Double'(4)).

%% F14.2. A chain is left-associative, so it runs in the order it reads. Asserted
%% against a NON-COMMUTATIVE callee, because `Twice` composed with itself would
%% give the same answer under either association and prove nothing.
a_chain_is_left_associative_test() ->
    Src = "module C\n"
          "public int Sub(int a, int b)\n"
          "Sub(a, b) -> a - b\n"
          "public int Run(int n)\n"
          "Run(n) -> n |> Sub(1) |> Sub(2) |> Sub(3)\n",
    M = build_and_load(Src, 'C'),
    %% ((100-1)-2)-3. Right-associative would be 100 - (1 - (2 - 3)) = 102.
    ?assertEqual(94, M:'Run'(100)).

%% F14.5. Both bounds of the precedence window, which the feature file records as
%% the one mechanism its scenarios do not pin on their own.
the_pipe_is_looser_than_arithmetic_test() ->
    Src = "module A\n"
          "public int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int a, int b)\n"
          "Run(a, b) -> a + b |> Twice()\n",
    M = build_and_load(Src, 'A'),
    %% (3 + 4) * 2. Tighter than `+` would be 3 + (4 * 2) = 11.
    ?assertEqual(14, M:'Run'(3, 4)).

the_pipe_is_tighter_than_a_binding_test() ->
    Src = "module B\n"
          "public int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int n)\n"
          "Run(n) ->\n"
          "  var d = n |> Twice()\n"
          "  d + 1\n",
    M = build_and_load(Src, 'B'),
    ?assertEqual(11, M:'Run'(5)).

%% F14.4. THE RIGHT OPERAND IS A CALL IN THE GRAMMAR. Ticket 17 §1 refuses to
%% spell *function as a value*, so this is a SYNTAX error and not a type error —
%% the layer is the assertion, which is why it is made against the CLI's exit
%% code and the word `syntax` rather than against a diagnostic term.
a_bare_name_after_the_pipe_is_a_syntax_error_test() ->
    Src = "module X\n"
          "public int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int n)\n"
          "Run(n) -> n |> Twice\n",
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, "syntax error") =/= nomatch),
                     ?assert(string:find(Out, "rc:1") =/= nomatch)
             end).

%%% --- the valve --------------------------------------------------------------

%% F14.6 and F14.7. The valve stops on the error member and returns it UNCHANGED,
%% and no later stage runs.
%%
%% "No later stage runs" is asserted by construction rather than by a counter:
%% both stages do arithmetic on their argument, so either one reached with
%% `(:error, :bad)` would raise `badarith`. Getting the tuple back IS the proof
%% that neither was entered.
a_valve_short_circuits_on_the_error_member_test() ->
    Src = res_src() ++
          "private Res Charge(int v)\n"
          "Charge(v) -> v * 2\n"
          "private Res Confirm(int v)\n"
          "Confirm(v) -> v + 6\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge() |?> Confirm()\n",
    M = build_and_load(Src, 'Res'),
    ?assertEqual(12, M:'Place'(3)),
    ?assertEqual({error, bad}, M:'Place'(-1)).

%% F14.8. The stage is declared over the NARROWED type, and this is the property
%% the whole lowering exists for: `Charge(int v)` above names `int`, not `Res`,
%% and it type-checks because the generated error arm has already subtracted the
%% error member before the value arm's body is reached. F7 built the construct,
%% F2 built the subtraction, F5 built the body check — F14 wrote no type code.
a_stage_declared_over_the_narrowed_type_is_accepted_test() ->
    Src = res_src() ++
          "private Res Charge(int v)\n"
          "Charge(v) -> v * 2\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge()\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).

%% The mirror, and it is the half that would rot silently. If the valve did NOT
%% narrow, the test above would still pass — a stage declared over the whole
%% union accepts everything. So a stage that accepts only the ERROR member must
%% be refused, which can only happen if the narrowing is real.
a_stage_that_accepts_only_the_error_member_is_refused_test() ->
    Src = res_src() ++
          "private Res Charge((:error, atom) v)\n"
          "Charge(v) -> (:error, :nope)\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge()\n",
    %% Pinned to the SHAPE, not merely to non-emptiness: what proves the
    %% narrowing is that the residual reaching argument 1 is `int` — the subject
    %% type with the error member already subtracted. A test that only asked for
    %% "some error" would pass if the valve narrowed to the wrong thing, or to
    %% nothing at all.
    [{error, _, 'Place', {arg_not_accepted, 'Charge', 1, Residual, _}}] =
        errors(Src),
    ?assertEqual("int", lists:flatten(bs_types:to_pattern(Residual))).

%% F14.9. A valve over a value that cannot fail. The generated error arm can
%% never match, and reporting `unreachable arm 1` would be a remark about code
%% the author never wrote — F7's costume for the third time. The message names
%% the operator to write instead, and that is the feature.
a_valve_over_a_value_that_cannot_fail_is_an_error_test() ->
    Src = "module W\n"
          "private int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int n)\n"
          "Run(n) -> n |?> Twice()\n",
    [{error, _, 'Run', {valve_on_infallible, _}}] = errors(Src),
    %% Asserted at the boundary too, because the diagnostic's TEXT is the whole
    %% of its usefulness: an author who is told the arm is unreachable learns
    %% nothing, and one who is told to write `|>` is done.
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, "cannot fail") =/= nomatch),
                     ?assert(string:find(Out, "Write |> instead") =/= nomatch),
                     ?assert(string:find(Out, "rc:1") =/= nomatch)
             end).

%% AND NO WARNING LEAKS FROM THE ARMS THE COMPILER WROTE. Two would otherwise:
%% `unreachable_arm` above, and ticket 12 §2's rule against a catch-all over a
%% closed residual — which the value arm is, by construction, every single time.
%% This is why the lowered switch stays wrapped in a marker instead of being
%% emitted bare.
a_well_formed_valve_produces_no_diagnostics_at_all_test() ->
    Src = res_src() ++
          "private Res Charge(int v)\n"
          "Charge(v) -> v * 2\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge()\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).

%% The binder the lowering synthesises must be unique per stage. Erlang's scoping
%% is flat within a clause, so a repeated name stops being a fresh binding and
%% silently becomes a MATCH against the enclosing stage's value — a wrong program
%% with no diagnostic anywhere.
%%
%% The nesting here is the case a per-line or per-depth name would not survive:
%% the inner valve sits in the outer's ARGUMENT LIST, so it is lowered inside the
%% outer's own value arm.
a_valve_nested_in_an_argument_gets_its_own_binder_test() ->
    Src = res_src() ++
          "private Res Add(int v, Res other)\n"
          "Add(v, (:error, e)) -> (:error, e)\n"
          "Add(v, o) when o > 0  -> v + o\n"
          "Add(v, o) when o <= 0 -> v + o\n"
          "public Res Nested(int a, int b)\n"
          "Nested(a, b) -> Start(a) |?> Add(Start(b) |?> Add(0))\n",
    M = build_and_load(Src, 'Res'),
    ?assertEqual(7, M:'Nested'(3, 4)),
    ?assertEqual({error, bad}, M:'Nested'(3, -1)),
    ?assertEqual({error, bad}, M:'Nested'(-1, 4)).

%% A name read only inside a valve stage is still a USE of that name. Without the
%% `used_vars/2` clause the parameter would look unused, lower to `_B` in the
%% clause head, and then be referenced by the emitted `case` — a compile error in
%% a file the author did not write. Same shape as F1's spurious-warning finding.
a_parameter_read_only_inside_a_valve_stage_is_not_dropped_test() ->
    Src = res_src() ++
          "private Res Add(int v, int w)\n"
          "Add(v, w) -> v + w\n"
          "public Res Place(int n, int bonus)\n"
          "Place(n, bonus) -> Start(n) |?> Add(bonus)\n",
    M = build_and_load(Src, 'Res'),
    ?assertEqual(9, M:'Place'(4, 5)).

%%% --- the diagnosis ----------------------------------------------------------

%% F14.10. The cost of §2's rewrite is that an error inside `x |> F(a)` reports
%% against `F/2`. Ticket 40 §2 — *"the defect is the diagnosis, not the
%% outcome"* — so the rewritten node carries the PIPE's line rather than the
%% call's, and the source is written across two lines so the two differ.
a_diagnostic_inside_a_piped_call_names_the_pipes_line_test() ->
    Src = "module L\n"
          "private int Twice(int v, int w)\n"
          "Twice(v, w) -> v * w\n"
          "public int Run(int n)\n"
          "Run(n) -> n |>\n"
          "  Twice(:oops)\n",
    %% The pipe is on line 5 and `Twice(` is on line 6.
    [{error, 5, 'Run', _}] = errors(Src).
