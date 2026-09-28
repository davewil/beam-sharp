%%% Scenarios: compiler/features/F63-clause-block.md
-module(clause_block_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [run_cli/1, with_src/3]).

%%% F63 — a function's clauses in braces after its signature (ticket 110).

%% One module, written twice. It dispatches on records, guards, takes two
%% parameters, and holds one name at two arities.
preamble() ->
    "module Twin\n"
    "record Hello { Id: int }\n"
    "record Task { Id: int }\n"
    "type Message = Hello | Task\n".

named() ->
    preamble() ++
    "public atom Direction(Message m)\n"
    "Direction(Hello h) -> :hands\n"
    "Direction(Task t)  -> :brain\n"
    "public int Band(int n)\n"
    "Band(n) when n > 10 -> 2\n"
    "Band(0)             -> 0\n"
    "Band(n)             -> 1\n"
    "public int Sub(int a, int b)\n"
    "Sub(0, b) -> b\n"
    "Sub(a, 0) -> a\n"
    "Sub(a, b) -> a - b\n"
    "private int Length(list<int> xs, int acc)\n"
    "Length([], acc)          -> acc\n"
    "Length([x, ..rest], acc) -> Length(rest, acc + 1)\n"
    "public int Length(list<int> xs)\n"
    "Length(xs) -> Length(xs, 0)\n".

block() ->
    preamble() ++
    "public atom Direction(Message m) {\n"
    "    (Hello h) -> :hands,\n"
    "    (Task t)  -> :brain\n"
    "}\n"
    "public int Band(int n) {\n"
    "    (n) when n > 10 -> 2,\n"
    "    (0)             -> 0,\n"
    "    (n)             -> 1\n"
    "}\n"
    "public int Sub(int a, int b) {\n"
    "    (0, b) -> b,\n"
    "    (a, 0) -> a,\n"
    "    (a, b) -> a - b\n"
    "}\n"
    "private int Length(list<int> xs, int acc) {\n"
    "    ([], acc)          -> acc,\n"
    "    ([x, ..rest], acc) -> Length(rest, acc + 1)\n"
    "}\n"
    "public int Length(list<int> xs) {\n"
    "    (xs) -> Length(xs, 0)\n"
    "}\n".

%% Compile through the CLI into a fresh directory and hand back its outputs.
built(Src, Fun) ->
    with_src("twin.bs", Src,
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     ?assert(string:find(Got, "rc:0") =/= nomatch),
                     Fun(Path, Out)
             end).

%% Positions differ by construction; a `file` attribute names the fixture path.
forms(Out) ->
    {ok, Forms} = file:consult(filename:join(Out, "Twin.abstr")),
    [erl_parse:map_anno(fun(_) -> 0 end, F)
     || F <- Forms, element(3, F) =/= file].

%% F63.1 — the two spellings are one module.
the_block_form_emits_the_named_form_test() ->
    Named = built(named(), fun(_, Out) -> forms(Out) end),
    Block = built(block(), fun(_, Out) -> forms(Out) end),
    %% The five written functions are there: an empty comparison proves nothing.
    Defined = [{N, A} || {function, _, N, A, _} <- Named],
    ?assertEqual([], [{'Direction', 1}, {'Band', 1}, {'Sub', 2}, {'Length', 1},
                      {'Length', 2}] -- Defined),
    ?assertEqual(Named, Block),
    Exports = fun(Fs) -> [E || {attribute, _, export, E} <- Fs] end,
    ?assertEqual(Exports(Named), Exports(Block)).

the_block_form_runs_the_same_test() ->
    built(block(),
          fun(_, Out) ->
                  code:add_patha(Out),
                  code:purge('Twin'),
                  {module, 'Twin'} = code:load_abs(filename:join(Out, "Twin")),
                  ?assertEqual(hands, 'Twin':'Direction'(#{'Kind' => 'Twin.Hello', 'Id' => 1})),
                  ?assertEqual(brain, 'Twin':'Direction'(#{'Kind' => 'Twin.Task', 'Id' => 1})),
                  ?assertEqual([2, 0, 1], [ 'Twin':'Band'(N) || N <- [11, 0, 5]]),
                  ?assertEqual([4, 3, 2], ['Twin':'Sub'(A, B) || {A, B} <- [{0, 4}, {3, 0}, {5, 3}]]),
                  ?assertEqual(3, 'Twin':'Length'([7, 8, 9])),
                  code:purge('Twin'),
                  code:delete('Twin')
          end).

%% Compile through the CLI and hand back what it printed, with its exit code.
cli(Name, Src) ->
    with_src(Name, Src, fun(Path, Out) -> run_cli("-o " ++ Out ++ " " ++ Path) end).

%% F63.2 — the public API cannot tell them apart.
api(Src) ->
    with_src("twin.bs", Src,
             fun(Path, _Out) ->
                     Root = filename:dirname(filename:dirname(Path)),
                     run_cli("--src-root " ++ Root ++ " --api " ++ Path)
             end).

the_block_form_has_the_named_forms_api_test() ->
    Named = api(named()),
    ?assert(string:find(Named, "rc:0") =/= nomatch),
    ?assertEqual(Named, api(block())).

%% F63.3 — without a comma, a body ending in a bound name calls the next head.
%% Each arm binds its own names: a signature's parameter names bind nothing.
pick(Sep) ->
    "module Pick\n"
    "public int Pick(int k, int n) {\n"
    "    (0, n) -> n" ++ Sep ++ "\n"
    "    (1, n) -> 2" ++ Sep ++ "\n"
    "    (k, n) -> k\n"
    "}\n".

a_block_needs_a_comma_between_clauses_test() ->
    Without = cli("pick.bs", pick("")),
    ?assert(string:find(Without, "pick.bs:4:") =/= nomatch),
    ?assert(string:find(Without, "syntax error before: '->'") =/= nomatch),
    ?assert(string:find(Without, "rc:1") =/= nomatch),
    %% The same clauses with the comma compile and run: the comma is the
    %% difference, and `n` stays a value rather than a call.
    With = with_src("pick.bs", pick(","),
                    fun(Path, Out) ->
                            run_cli("-o " ++ Out ++ " " ++ Path ++ " Pick 0 42")
                    end),
    ?assert(string:find(With, "42\nrc:0") =/= nomatch).

%% F63.4 — a missing case prints as the arm to paste, with no name.
directions() ->
    "module Signal\n"
    "record Hello { Id: int }\n"
    "record Task { Id: int }\n"
    "record Stop { Id: int }\n"
    "type Message = Hello | Task | Stop\n".

a_missing_case_prints_as_an_arm_test() ->
    Src = directions() ++
          "public atom Direction(Message m) {\n"
          "    (Hello h) -> :hands,\n"
          "    (Task t)  -> :brain\n"
          "}\n",
    with_src("signal.bs", Src,
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     ?assert(string:find(Got, "Direction is not exhaustive") =/= nomatch),
                     ?assert(string:find(Got, "    (Stop s) -> ...") =/= nomatch),
                     ?assertEqual(nomatch, string:find(Got, "Direction(Stop")),
                     ?assert(string:find(Got, "rc:1") =/= nomatch)
             end).

%% F63.7 — the arms the compiler prints are read back out of its output and
%% pasted before the `}`, after a comma on the arm above, as a switch arm is
%% pasted by check-residual-pasteable.sh. The pasted program compiles.
the_printed_arm_pastes_into_the_block_test() ->
    Arms = "public atom Direction(Message m) {\n"
           "    (Hello h) -> :hands",
    Src = directions() ++ Arms ++ "\n}\n",
    with_src("signal.bs", Src,
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     Printed = [string:trim(string:replace(L, "-> ...", "-> :pasted"))
                                || L <- string:split(Got, "\n", all),
                                   lists:suffix("-> ...", L)],
                     %% The residual's order, not the declaration's.
                     ?assertEqual(["(Stop s) -> :pasted", "(Task t) -> :pasted"],
                                  lists:sort([lists:flatten(P) || P <- Printed])),
                     Pasted = directions() ++ Arms
                              ++ lists:append([",\n    " ++ lists:flatten(P)
                                               || P <- Printed])
                              ++ "\n}\n",
                     ok = file:write_file(Path, Pasted),
                     Again = run_cli("-o " ++ Out ++ " " ++ Path),
                     ?assert(string:find(Again, "rc:0") =/= nomatch)
             end).

%% F63.5 — a block is the whole of its function. The refusal points at the
%% stray clause's own line, and it is the only thing reported.
a_named_clause_beside_a_block_is_refused_test() ->
    Got = cli("signal.bs", directions() ++
                  "public atom Direction(Message m) {\n"
                  "    (Hello h) -> :hands,\n"
                  "    (Task t)  -> :brain\n"
                  "}\n"
                  "Direction(Stop s) -> :brain\n"),
    ?assert(string:find(Got, "signal.bs:10:1: error: Direction is written as a clause block, "
                             "so this clause is outside it") =/= nomatch),
    ?assert(string:find(Got, "Move the clause inside the braces") =/= nomatch),
    ?assertEqual(1, length(string:split(Got, "error:", all)) - 1),
    ?assert(string:find(Got, "rc:1") =/= nomatch).

%% F63.6 — another arity is another function, and each keeps its own form.
another_arity_beside_a_block_compiles_test() ->
    Src = directions() ++
          "public atom Direction(Message m) {\n"
          "    (Hello h) -> :hands,\n"
          "    (Task t)  -> :brain,\n"
          "    (Stop s)  -> :brain\n"
          "}\n"
          "public atom Direction(Message m, atom fallback)\n"
          "Direction(m, fallback) -> fallback\n",
    with_src("signal.bs", Src,
             fun(Path, Out) ->
                     One = run_cli("-o " ++ Out ++ " " ++ Path ++ " Direction "
                                   "\"#{'Kind' => 'Signal.Stop', 'Id' => 1}\""),
                     ?assert(string:find(One, ":brain\nrc:0") =/= nomatch),
                     Two = run_cli("-o " ++ Out ++ " " ++ Path ++ " Direction "
                                   "\"#{'Kind' => 'Signal.Stop', 'Id' => 1}\" :spare"),
                     ?assert(string:find(Two, ":spare\nrc:0") =/= nomatch)
             end).

%% F63.8 — an inexhaustive function is refused alike in both forms, naming the
%% same missing case, as a head or as an arm.
an_inexhaustive_function_is_refused_alike_in_both_forms_test() ->
    Named = cli("signal.bs", directions() ++
                    "public atom Direction(Message m)\n"
                    "Direction(Hello h) -> :hands\n"
                    "Direction(Task t)  -> :brain\n"),
    Block = cli("signal.bs", directions() ++
                    "public atom Direction(Message m) {\n"
                    "    (Hello h) -> :hands,\n"
                    "    (Task t)  -> :brain\n"
                    "}\n"),
    Missing = fun(Got) ->
                      [string:trim(L) || L <- string:split(Got, "\n", all),
                                         lists:suffix("-> ...", L)]
              end,
    ?assertEqual(["Direction(Stop s) -> ..."], Missing(Named)),
    ?assertEqual(["(Stop s) -> ..."], Missing(Block)),
    [?assert(string:find(G, "Direction is not exhaustive") =/= nomatch) || G <- [Named, Block]].

%% F63.4 — the other diagnostics that print a clause to paste print arms too.

a_catch_all_in_a_block_names_the_arms_it_hides_test() ->
    Got = cli("signal.bs", directions() ++
                  "public atom Direction(Message m) {\n"
                  "    (Hello h) -> :hands,\n"
                  "    (_)       -> :brain\n"
                  "}\n"),
    ?assert(string:find(Got, "Direction discards cases the compiler can name") =/= nomatch),
    ?assert(string:find(Got, "    (Task t) -> ...") =/= nomatch),
    ?assert(string:find(Got, "    (Stop s) -> ...") =/= nomatch),
    ?assertEqual(nomatch, string:find(Got, "Direction(")).

a_rejected_argument_in_a_block_offers_an_arm_test() ->
    Got = cli("calls.bs",
              "module Calls\n"
              "type Two = :a | :b\n"
              "type Three = :a | :b | :c\n"
              "private atom Pick(Two x)\n"
              "Pick(:a) -> :one\n"
              "Pick(:b) -> :two\n"
              "public atom Go(Three y) {\n"
              "    (y) -> Pick(y)\n"
              "}\n"),
    ?assert(string:find(Got, "Go hands Pick an argument it does not accept") =/= nomatch),
    ?assert(string:find(Got, "    (:c) -> ...") =/= nomatch),
    ?assertEqual(nomatch, string:find(Got, "Go(:c)")).

a_numeric_union_in_a_block_advises_arms_test() ->
    Got = cli("pence.bs",
              "module Pence\n"
              "public int Owed(int | float amount) {\n"
              "    (a) -> a * 100\n"
              "}\n"),
    ?assert(string:find(Got, "    (int amount) -> ...") =/= nomatch),
    ?assert(string:find(Got, "    (float amount) -> ...") =/= nomatch),
    ?assertEqual(nomatch, string:find(Got, "Owed(int")).

%% F63.3 — the comma closes a body whatever it ends in: a lambda's body runs as
%% far right as it can, and a switch carries commas of its own.
a_comma_closes_a_lambda_or_a_switch_body_test() ->
    Src = "module Bodies\n"
          "private int Apply(fn(int) -> int f, int v)\n"
          "Apply(f, v) -> f(v)\n"
          "public int Go(int n) {\n"
          "    (0)            -> Apply((x) => x + 1, 0),\n"
          "    (k) when k < 5 -> k switch { 1 => 10, _ => 20 },\n"
          "    (m)            -> m\n"
          "}\n",
    %% Each arm answers for itself, so none swallowed the next.
    with_src("bodies.bs", Src,
             fun(Path, Out) ->
                     [?assert(string:find(run_cli("-o " ++ Out ++ " " ++ Path ++ " Go " ++ N),
                                          Want ++ "\nrc:0") =/= nomatch)
                      || {N, Want} <- [{"0", "1"}, {"1", "10"}, {"3", "20"}, {"7", "7"}]]
             end).
