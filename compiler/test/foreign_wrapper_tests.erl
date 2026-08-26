%%% F19 — the compiler-emitted foreign `try` wrapper (ticket 15 §4, §5).
%%%
%%% ASSERTED AT THE BOUNDARY: source text in, a loaded `.beam` called, and the
%%% VALUE it returns compared. The wrapper is codegen with no surface of its own,
%%% so the only honest question to ask it is what a compiled program does when
%%% the foreign call succeeds and when it throws — everything else would pin an
%%% implementation rather than a behaviour.
%%%
%%% Two tests deliberately do not: `wraps_only_where_the_channel_is_declared`
%%% reads the emitted abstract code, because "no wrapper" has no observable
%%% value to compare against beyond the crash, and the sibling assertion that
%%% one call has a `try` and its neighbour does not is what makes the asymmetry
%%% visible in one place. `ffi_tests:a_foreign_call_is_a_remote_call_test` set
%%% that precedent for the same reason.

-module(foreign_wrapper_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1,
                          escript/0, run_cli/1, with_src/3, built/0]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% Fixtures
%%% ---------------------------------------------------------------------------

%% `binary_to_integer` is the canonical case from ticket 15 §4: it throws
%% `error:badarg` IN THIS PROCESS, which is the one gap `monitor` + `receive`
%% cannot close because there is no other process to observe the failure across.
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

%%% ---------------------------------------------------------------------------
%%% F19.1, F19.2 — the value, and the failure as a value
%%% ---------------------------------------------------------------------------

%% The happy path is unchanged: a wrapper that altered the success value would
%% make the declared type a lie in the other direction.
a_wrapped_call_returns_its_value_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertEqual(8080, M:'Parse'(<<"8080">>)).

%% THE WHOLE FEATURE, IN ONE ASSERTION. Without the wrapper this call kills the
%% test process; with it the failure is an ordinary term the caller can match.
%%
%% The doubled `error` is not a typo and the exact shape is what is asserted:
%% the outer one is `result<T, E>`'s own tag and the inner one is the exception
%% CLASS, which ticket 15 §5 kept precisely so `(:exit, (:noproc, _))` stays
%% legible as "the callee is dead" rather than as a value the callee returned.
a_wrapped_call_returns_a_thrown_error_as_a_value_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertEqual({error, {error, badarg}}, M:'Parse'(<<"abc">>)).

%%% ---------------------------------------------------------------------------
%%% F19.3, F19.4 — all three classes, which 15d measured rather than assumed
%%% ---------------------------------------------------------------------------

%% `throw` is the BEAM's catchable non-local-return class. It has no spelling in
%% beam-sharp — ticket 12 §5 ruled it a false friend — but foreign code raises
%% it, so the wrapper has to recognise it.
a_wrapped_call_catches_the_throw_class_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertEqual({error, {throw, boom}}, M:'Thrown'()).

%% A LOCALLY RAISED `exit/1` IS CATCHABLE AND AN EXIT SIGNAL IS NOT — two
%% mechanisms sharing a keyword, measured in 15d cases 3 and 5-7. So catching
%% this class cannot swallow a supervisor's shutdown, and narrowing the wrapper
%% to `error:` would instead miss `exit({noproc, ...})`, which is what a call to
%% a dead `gen_server` raises in the caller's own process.
a_wrapped_call_catches_the_exit_class_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertEqual({error, {exit, boom}}, M:'Exited'()).

%%% ---------------------------------------------------------------------------
%%% F19.5 — the asymmetry, which is ticket 12's decision and not an omission
%%% ---------------------------------------------------------------------------

%% A foreign signature that declares no failure channel gets NO wrapper and the
%% throw propagates: fail through the channel your signature declares, crash
%% where it declares none. This cannot live in `examples/`, because every example
%% must run — a program whose point is that it dies has no place there.
an_undeclared_channel_lets_the_caller_die_test() ->
    M = build_and_load(wrapped_src(), 'Fw'),
    ?assertError(badarg, M:'Size'(not_a_binary)).

%%% ---------------------------------------------------------------------------
%%% F19.9 — the two sides in one module, read off the emitted code
%%% ---------------------------------------------------------------------------

wraps_only_where_the_channel_is_declared_test() ->
    {ok, _} = compile(wrapped_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Fw.beam", [abstract_code]),
    ?assertEqual([{'try'}], shapes('Parse', Forms)),
    ?assertEqual([{call}], shapes('Size', Forms)).

%% The outermost node of a function's single-clause body, as a one-element tag.
shapes(Name, Forms) ->
    [{element(1, Node)}
     || {function, _, N, _, Clauses} <- Forms, N =:= Name,
        {clause, _, _, _, [Node]} <- Clauses].

%%% ---------------------------------------------------------------------------
%%% F19.10 — the synthesised names, which MUST be unique per clause
%%% ---------------------------------------------------------------------------

%% Measured with `erlc` before this feature was written: a second `catch C:R` in
%% one clause is `variable 'C' unsafe in 'try'` — a COMPILE ERROR, not a silent
%% match — and a nested one is the same. So both shapes are pinned, and either
%% would fail loudly at `erlc` rather than subtly at run time.
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
    %% The inner failure is a perfectly good term, so the OUTER call succeeds on
    %% it. That is the design working rather than a hole: `term_to_binary` was
    %% declared to accept a `term`, and `(:error, (:error, :badarg))` is one.
    ?assertEqual(term_to_binary({error, {error, badarg}}), M:'Nested'(<<"abc">>)).

%%% ---------------------------------------------------------------------------
%%% F19.1 — the trigger is the TYPE, not the spelling
%%% ---------------------------------------------------------------------------

%% Ticket 09 §4: a name never enters the algebra, so `result<int, foreign_error>`
%% and the union written out are the SAME TYPE and must behave identically. A
%% wrapper keyed on the token `result` would make two spellings of one type
%% differ, which is the exact thing that rule exists to prevent.
%%
%% Written through an alias because `foreign_sig` takes a `type_prim` and a bare
%% union is not one — so the union has to be NAMED to reach a foreign return
%% position at all. That is not a weaker test: `Parsed` is a user type the
%% compiler has never heard of, it mentions no `result`, and the wrapper fires
%% on it because of what it resolves to.
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

%%% ---------------------------------------------------------------------------
%%% F19.6 — the class is then an ordinary clause head (ticket 15 §5)
%%% ---------------------------------------------------------------------------

%% Exhaustive with NO catch-all over the failure member: the three classes are
%% discriminable by their literal atom tags, which is why 15 §1's collapse check
%% never fires on `foreign_error`.
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

%%% ---------------------------------------------------------------------------
%%% F19.7 — `E` is fixed at `foreign_error`
%%% ---------------------------------------------------------------------------

%% TICKET 56 REVERSED THIS. It was `a_payload_other_than_foreign_error_is_
%% refused_test`, asserting the error term F19 §2 raised. The rule it pinned —
%% "`E` is fixed for foreign calls" — assumed that a type mentioning `(:error, R)`
%% belongs to a function that THROWS, and most of OTP's IO surface disproves it.
%%
%% THE COST OF THE REVERSAL IS WHAT THIS TEST NOW PINS, deliberately. A payload
%% that is not `foreign_error` no longer refuses, so a MIS-declared channel over a
%% genuinely throwing function compiles and the program dies at runtime. That is
%% the trade ticket 56 made with its eyes open, and it is asserted here so that
%% the next person to read it finds a decision rather than an omission. The
%% boundary guard (ticket 18) is what is owed against it.
a_payload_other_than_foreign_error_is_an_ordinary_union_test() ->
    Src = "module Fw6\n"
          "using :erlang {\n"
          "    result<int, atom> binary_to_integer(binary b)\n"
          "}\n"
          "public result<int, atom> Parse(binary b)\n"
          "Parse(b) -> :erlang.binary_to_integer(b)\n",
    %% `[]` and not `_`: a clean compile, with nothing merely downgraded to a
    %% warning in place of the refusal that was removed.
    ?assertMatch({ok, _, []}, check_only(Src)),
    {ok, _} = compile(Src),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Fw6.beam", [abstract_code]),
    %% No wrapper: `atom` names no exception class, so there is nothing to catch
    %% ON THE AUTHOR'S BEHALF. Asserted as the positive shape `{call}` rather than
    %% as the absence of a `try`, because an absence goes green over a module that
    %% never compiled.
    ?assertEqual([{call}], shapes('Parse', Forms)).

%% ...AND THE AUTHOR IS NOT STOPPED AT THE DECLARATION. This was
%% `the_refusal_reaches_the_author_as_prose_test`, which asserted that the refusal
%% reached the author as a sentence rather than an escript stack trace. There is
%% no refusal left to render, so the assertion inverts: the shape that used to be
%% rejected now compiles clean at the channel an author actually reads.
%%
%% Still driven through the CLI, for the reason the old test named — a checker
%% that returns `{ok, _}` proves nothing about what `bsc` prints or exits with.
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
                %% The retired refusal, by the two phrases that carried it. The
                %% second is F19's recorded debt sentence, which this ticket is
                %% the one licensed to delete.
                ?assertEqual(nomatch, string:find(R, "is `foreign_error`, and "
                                                     "nothing else")),
                ?assertEqual(nomatch,
                             string:find(R, "has no declared form yet"))
            end)
    end.

%% The refusal is about the FOREIGN boundary only. A local function may carry
%% any `E` it likes — that is `result<T, E>`'s whole point, and ticket 15 §2
%% named the reason for the payload rather than restricting it.
a_local_signature_may_carry_any_payload_test() ->
    Src = "module Fw7\n"
          "public result<int, atom> Parse(int n)\n"
          "Parse(n) when n > 0  -> n\n"
          "Parse(n) when n <= 0 -> (:error, :nonpositive)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%%% ---------------------------------------------------------------------------
%%% F19.8 — there is no `try` in the surface
%%% ---------------------------------------------------------------------------

%% Ticket 15 §4 refused a general `try`/`catch` as surface syntax: it is the
%% tier-1 borrow both audiences read on sight, and it was refused because it is a
%% GENERAL escape hatch that invites exceptions-as-control-flow. The wrapper is
%% the only `try` this language has, and nobody can type it.
there_is_no_try_in_the_surface_test() ->
    {ok, Toks, _} = bs_lexer:string("module T\n"
                                    "public int F(int n)\n"
                                    "F(n) -> try n catch e -> 0\n"),
    ?assertMatch({error, {_, bs_parser, _}}, bs_parser:parse(Toks)).

%%% ---------------------------------------------------------------------------
%%% The edge the tuple top puts in the way
%%% ---------------------------------------------------------------------------

%% `result<term, E>` IS `term` — ticket 15 §2 measured exactly this row, "only
%% the top absorbs everything" — so there is no failure member left to find and
%% no wrapper is emitted. Recorded as a test rather than left to be rediscovered:
%% it looks like the wrapper failing to fire and it is the declaration being
%% degenerate, which is what 15 §1's collapse check exists to refuse at the
%% declaration. That check is not built, so this is the shape it will catch.
a_term_return_is_not_a_declared_channel_test() ->
    Src = "module Fw8\n"
          "using :erlang {\n"
          "    result<term, foreign_error> binary_to_integer(binary b)\n"
          "}\n"
          "public term Parse(binary b)\n"
          "Parse(b) -> :erlang.binary_to_integer(b)\n",
    M = build_and_load(Src, 'Fw8'),
    ?assertEqual(8080, M:'Parse'(<<"8080">>)),
    ?assertError(badarg, M:'Parse'(<<"abc">>)).

%%% ---------------------------------------------------------------------------
%%% Ticket 56 — a foreign error that arrives as a VALUE
%%%
%%% `file:read_file/1` returns `{ok, Binary} | {error, Reason}` and never throws,
%%% which is most of OTP's IO surface. F19 §2 refused it, because it read any
%%% `(:error, _)` member as a request for the wrapper. The trigger is now the
%%% payload `foreign_error` and nothing else: NAMING the type the wrapper
%%% produces is what asks for the wrapper, and every other union is ordinary.
%%% ---------------------------------------------------------------------------

%% Three shapes in one module, on purpose. `Slurp` is the tagged pair OTP writes
%% most; `Ex` is the bare-`:ok` variant `erl_tar` writes and which the ticket's
%% own title does not cover; `Parse` is the wrapper, present as the control that
%% keeps the assertions below from passing vacuously.
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

%% THE TICKET, IN ONE ASSERTION. Both arms arrive as ordinary values and both
%% inhabit the declared type — which is what F19 could not say.
a_value_returned_error_is_declarable_test() ->
    M = build_and_load(value_returned_src(), 'Fv'),
    ?assertMatch({ok, <<_/binary>>}, M:'Slurp'(<<"/etc/hosts">>)),
    ?assertEqual({error, enoent}, M:'Slurp'(<<"/nonexistent-ticket-56">>)).

%% A call that never throws must not be wrapped in a `try` that catches nothing.
%% `Parse` is asserted in the same module and the same breath: an absence proved
%% on its own would go green over a module that failed to compile, which is this
%% repo's most-repeated gate defect.
a_value_returned_declaration_gets_no_wrapper_test() ->
    {ok, _} = compile(value_returned_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Fv.beam", [abstract_code]),
    ?assertEqual([{call}], shapes('Slurp', Forms)),
    ?assertEqual([{call}], shapes('Ex', Forms)),
    ?assertEqual([{'try'}], shapes('Parse', Forms)).

%% BOTH CHANNELS AT ONCE, which had no form at all before this ticket: a call
%% that returns `{error, Reason}` as a value AND can throw. The algebra keeps the
%% two `(:error, _)` products apart, so naming `foreign_error` in one of them
%% asks for the wrapper while the other stays an ordinary value arm.
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
    ?assertEqual([{'try'}], shapes('Go', Forms)).
