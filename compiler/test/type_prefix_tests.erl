-module(type_prefix_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, errors/1, check_only/1]).

%%% ---------------------------------------------------------------------------
%%% F53 — the numeric-union mixed pair and the type-prefix pattern. Tickets 83
%%% and 84; ENG-394.
%%%
%%% TWO DECISIONS THAT SHIP TOGETHER, AND THE COUPLING IS THE FEATURE.
%%%
%%%   83  a union whose parts are all numeric is the mixed pair wherever one
%%%       part would be, so `a * 100` and `a < 0` over an `int | float` are
%%%       refused — today they compile, type as `int`, and return `-250.0`
%%%       from a function declared `int`.
%%%   84  a clause head dispatches the parts with the type prefix,
%%%       `Post(float a)`: ticket 55's `Frame f` extended from a record to a
%%%       part, legal wherever ONE test decides membership in the type named.
%%%
%%% THE ORDER OF THIS FILE IS THE ORDER OF THE ARGUMENT. The refusal's only
%%% correct advice is "dispatch the parts", so the first test is the program
%%% that advice produces — compiled, loaded and CALLED against ticket 83's own
%%% table. A refusal whose advice does not compile is the defect it exists to
%%% prevent (F19 shipped exactly that), and no assertion about the refusal is
%%% worth anything until the advised form runs.
%%% ---------------------------------------------------------------------------

%% Ticket 83's ledger posting rule, written the way F53 says to write it. An
%% amount off the wire is an `int` when JSON gave a whole number and a `float`
%% when it gave a fractional one (ticket 77), so the parameter is both parts
%% and a negative amount is money going back to the customer.
ledger() ->
    "module Ledger\n\n"
    "type Side = :debit | :credit\n\n"
    "public Side Post(int | float amount)\n\n"
    "Post(int a)   when a < 0   -> :credit\n"
    "Post(int a)                -> :debit\n"
    "Post(float f) when f < 0.0 -> :credit\n"
    "Post(float f)              -> :debit\n".

%%% --- F53.1 — the advised program runs ---------------------------------------

%% Ticket 83's table, with the row that was wrong put right. Measured at
%% `44ca20c` the union escaped the refusal, `a < 0` emitted
%% `is_integer(A) andalso A < 0`, and a £2.50 refund posted as a DEBIT.
the_advised_dispatch_posts_both_parts_test() ->
    M = build_and_load(ledger(), 'Ledger'),
    ?assertEqual(credit, M:'Post'(-250)),
    ?assertEqual(credit, M:'Post'(-2.50)),
    ?assertEqual(debit, M:'Post'(250)),
    ?assertEqual(debit, M:'Post'(2.50)),
    %% The boundaries of each part, since the guard is what the old emission
    %% got wrong: zero is a debit in both spellings.
    ?assertEqual(debit, M:'Post'(0)),
    ?assertEqual(debit, M:'Post'(0.0)).

%% THE ANTI-F19 ASSERTION. `f < 0.0` inside a `float` clause must NOT be the
%% mixed pair: the prefix has already narrowed the binding to one part, so the
%% literal stands beside its own kind. If this goes red the advice F53 prints
%% is advice that does not compile, which is the defect the refusal exists to
%% prevent — so it is asserted on its own and not left to the table above.
%%
%% Both directions, because the narrowing has to reach the OTHER part too:
%% `a < 0` in the `int` clause is equally the pair if the prefix narrowed
%% nothing.
the_prefix_narrows_the_binding_for_the_guard_test() ->
    ?assertEqual([], diags(ledger())).

%%% --- F53.2 — the pattern is credited for exhaustiveness ---------------------

%% The reason the type prefix beats both guard spellings, on the language's own
%% terms: a pattern is credited and a guard is not, so the clause set closes
%% with NO catch-all. `Post` above has four clauses and no `_`.
%%
%% The control is the same program with the float clauses dropped: it must
%% report inexhaustive, or the exhaustiveness above is being credited to
%% something other than the prefix.
dropping_a_part_reports_inexhaustive_test() ->
    Src = "module Half\n\n"
          "public atom Post(int | float amount)\n\n"
          "Post(int a) -> :debit\n",
    [D | _] = errors(Src),
    ?assertEqual(inexhaustive, element(1, element(4, D))),
    Residual = element(2, element(4, D)),
    %% The clause product, one component here — the residual of a one-argument
    %% function prints in the brackets a head would put round it.
    ?assertEqual("(float)", bs_types:to_string(Residual)).

%%% --- F53.3 — ticket 84's Q2, the reach --------------------------------------

%% (a) — a part that a BEAM guard separates. `atom | int` is legal for the
%% other half of ticket 09 §4's criterion, and the prefix reaches both parts.
a_non_numeric_pair_dispatches_too_test() ->
    Src = "module Norm\n\n"
          "public int Norm(atom | int x)\n\n"
          "Norm(atom a) -> 0\n"
          "Norm(int n)  -> n\n",
    M = build_and_load(Src, 'Norm'),
    ?assertEqual(0, M:'Norm'(missing)),
    ?assertEqual(7, M:'Norm'(7)).

%% (b) — a member no single test decides. `is_list` is true of both members,
%% which is the shape `map<K, V>` is refused for today, and the refusal is
%% `map<K, V>`'s in `map<K, V>`'s words: declarable, passable, returnable, and
%% not matchable. Temporary by construction — the day a pattern form reaches
%% inside a list the member becomes decidable and this lifts on its own terms.
a_member_no_single_test_decides_is_refused_test() ->
    Src = "module Counts\n\n"
          "type Xs = list<int> | list<binary>\n\n"
          "public int Count(Xs xs)\n\n"
          "Count(list<int> ns)    -> 1\n"
          "Count(list<binary> bs) -> 0\n",
    D = refusal(Src),
    ?assertMatch({type_prefix_undecidable, _, _, {narrower, is_list}}, D),
    Prose = prose(D),
    ?assert(string:find(Prose, "list<int>") =/= nomatch),
    %% The reason is the true one: the test exists and does not DECIDE. A
    %% message asserting that NO test decides it would be false of `term` two
    %% tests down, which is why the reason travels with the refusal.
    ?assert(string:find(Prose, "is_list") =/= nomatch),
    %% Said to be temporary, as `map<K, V>`'s is.
    ?assert(string:find(Prose, "not built") =/= nomatch).

%% A refinement is decided by one test — `is_integer(M) andalso M >= 0`, which
%% ticket 46 already emits at a boundary — so the letter of ticket 84's rule
%% admits it, and ticket 84 deliberately did not decide whether it should.
%%
%% IT CANNOT BE SPELLED, AND THAT IS WHY THE QUESTION STAYS OPEN. A refinement
%% is a NAMED type and type names are PascalCase, so `Meters m` is a `uident`
%% prefix and goes down ticket 55's record path, where only a minted tag is
%% accepted. The part prefix this feature adds is lowercase-only and reaches
%% no named type at all. So F53 widens nothing here by construction rather
%% than by a refusal it had to write, and the ticket it raises asks the
%% question the grammar now poses: may a NAME wear the prefix, and which ones.
a_refinement_in_prefix_position_is_refused_test() ->
    Src = "module Trip\n\n"
          "type Meters = int where value >= 0\n\n"
          "public int Far(Meters | float d)\n\n"
          "Far(Meters m) -> m\n"
          "Far(float f)  -> 0\n",
    ?assertMatch({not_a_record, _, 'Meters'}, refusal(Src)).

%% `term` separates nothing, every value being one. Whether that is a legal
%% no-op or a refused vacuity is the same unasked question, and F53 refuses
%% rather than deciding it.
term_in_prefix_position_is_refused_test() ->
    Src = "module Any\n\n"
          "public int Go(int | float x)\n\n"
          "Go(term t) -> 0\n",
    D = refusal(Src),
    ?assertMatch({type_prefix_undecidable, _, "term", several_parts}, D),
    %% AND THE MESSAGE MUST NOT SAY NO TEST DECIDES IT, because every test
    %% does. `term` is refused for spanning the parts, not for being
    %% undecidable, and the sentence says so.
    ?assert(string:find(prose(D), "more than one part") =/= nomatch).

%% The uppercase spelling stays on the record path, where ticket 55 put it,
%% and its refusal now names the form that DOES reach a part — otherwise the
%% author who writes `Amount a` is told only what is wrong.
an_alias_to_a_union_is_still_refused_and_says_what_to_write_test() ->
    Src = "module Amounts\n\n"
          "type Amount = int | float\n\n"
          "public atom Post(Amount a)\n\n"
          "Post(Amount x) -> :debit\n",
    D = refusal(Src),
    ?assertMatch({not_a_record, _, 'Amount'}, D),
    %% The message was written when a type prefix could only name a record.
    %% It now has a second true thing to say — the part's own name reaches a
    %% part — and an author told only what is wrong is an author stuck.
    ?assert(string:find(prose(D), "part") =/= nomatch).

%%% --- F53.4 — the switch arm (F51's trap) ------------------------------------
%%%
%%% An arm is classified in `arms/10` and a clause head in `walk/6`. F51
%%% shipped a dead arm by wiring one site only, and a vacuous arm is a WARNING,
%%% so the program compiles with the dead arm in it. Both faces of the form
%%% are asserted at both sites: what an arm accepts, and what it refuses.

%% A settlement file's line amount, normalised to pence in the arm that knows
%% which part it holds.
the_arm_dispatches_the_parts_test() ->
    Src = "module Pence\n\n"
          "public int Owed(int | float amount)\n\n"
          "Owed(a) -> a switch {\n"
          "    int n   => n * 100,\n"
          "    float f => 0\n"
          "}\n",
    M = build_and_load(Src, 'Pence'),
    ?assertEqual(25000, M:'Owed'(250)),
    ?assertEqual(0, M:'Owed'(2.50)).

%% THE SAME REFUSAL AT THE ARM, AND THE POINT IS THAT NOTHING WIRED IT THERE.
%% `arms/10` and `walk/6` both ask `pattern_type/3` for a pattern's type, and
%% the refusal is raised inside it — so the arm is covered by construction
%% rather than by a second call site someone has to remember. F51 shipped a
%% dead arm by refusing at one of the two, and a vacuous arm is only a
%% warning, so that program COMPILED with the dead arm in it.
the_arm_refuses_what_the_head_refuses_test() ->
    Src = "module Sums\n\n"
          "type Xs = list<int> | list<binary>\n\n"
          "public int Count(Xs xs)\n\n"
          "Count(xs) -> xs switch {\n"
          "    list<int> ns    => 1,\n"
          "    list<binary> bs => 0\n"
          "}\n",
    ?assertMatch({type_prefix_undecidable, _, _, {narrower, is_list}},
                 refusal(Src)).

%%% --- F53.5 — ticket 83, the operator ----------------------------------------

%% The body face. `public int Owed(int | float amount)` with `Owed(a) -> a *
%% 100` compiled, published `int Owed(int | float)` through `--api`, and
%% returned `-250.0` — a float from a function declared `int`, which is what
%% §10's guarantee exists to rule out.
a_numeric_union_at_an_operator_is_refused_test() ->
    Src = "module Pence\n\n"
          "public int Owed(int | float amount)\n\n"
          "Owed(a) -> a * 100\n",
    [D | _] = errors(Src),
    ?assertEqual(numeric_union_operand, element(1, element(4, D))).

%% THE TWO-SITE TRAP. `mixed_guard_diags/3` keeps only the diagnostics
%% `keep_from_guard/1` lets out of a guard, and that reader is keyed on the
%% mixed pair by TAG. A new tag not added there means the body refuses and the
%% guard silently compiles — which is the exact defect ticket 83 opened on, one
%% tag over.
the_refusal_reaches_a_guard_too_test() ->
    Src = "module Ledger\n\n"
          "public atom Post(int | float amount)\n\n"
          "Post(a) when a < 0 -> :credit\n"
          "Post(_)            -> :debit\n",
    [D | _] = errors(Src),
    ?assertEqual(numeric_union_operand, element(1, element(4, D))).

%% The cost ticket 83 states plainly. `a < 0.0` over the union compiles today,
%% emits no kind test and answers correctly for both parts — and it goes,
%% because ticket 80's no-flow rule is symmetric: the `int` part of the union
%% stands beside a float literal.
the_float_literal_spelling_goes_too_test() ->
    Src = "module Ledger\n\n"
          "public atom Post(int | float amount)\n\n"
          "Post(a) when a < 0.0 -> :credit\n"
          "Post(_)              -> :debit\n",
    [D | _] = errors(Src),
    ?assertEqual(numeric_union_operand, element(1, element(4, D))).

%% The advice must name the dispatch, and must NOT print `mixed_operands`'
%% literal-spelling advice: "write `0.0`" is refused under ticket 83's own
%% answer, and a refusal whose advice does not compile is the defect.
the_advice_names_the_dispatch_and_not_the_literal_test() ->
    Src = "module Pence\n\n"
          "public int Owed(int | float amount)\n\n"
          "Owed(a) -> a * 100\n",
    [D | _] = errors(Src),
    Prose = prose(D),
    ?assertEqual(nomatch, string:find(Prose, "0.0")),
    ?assertEqual(nomatch, string:find(Prose, "Float.FromInt")),
    ?assert(string:find(Prose, "int | float") =/= nomatch),
    %% The form it sends the author to, spelled as they must write it.
    ?assert(string:find(Prose, "Owed(int") =/= nomatch),
    ?assert(string:find(Prose, "Owed(float") =/= nomatch).

%% The operator set is INHERITED from the existing `{int, float}` clause —
%% everything except `and`/`or` — rather than a new one named here.
every_operator_but_the_boolean_pair_refuses_test() ->
    Refused = fun(Op) ->
        Src = "module Ops\n\n"
              "public int Go(int | float x)\n\n"
              "Go(a) -> a " ++ Op ++ " 2\n",
        case errors(Src) of
            [D | _] -> element(1, element(4, D));
            []      -> none
        end
    end,
    [?assertEqual({Op, numeric_union_operand}, {Op, Refused(Op)})
     || Op <- ["+", "-", "*", "/", "%"]].

%% SCOPE, ASSERTED. Ticket 83 scoped its question to a union whose parts are
%% ALL numeric and said so: `int | float | :none` keeps today's `op_type/1`
%% fallthrough and today's defect with it. Seen, not missed — and a rule that
%% quietly reached it would be a wider language than the one decided.
a_union_with_a_non_numeric_part_is_unmoved_test() ->
    Src = "module Wide\n\n"
          "public int Go(int | float | :none x)\n\n"
          "Go(a) -> a * 100\n",
    ?assertEqual([], [D || D <- diags(Src),
                           element(1, element(4, D)) =:= numeric_union_operand]).

%% A single part at an operator is untouched: `int` beside `int` is `int`, and
%% the `int`-beside-`float` refusal keeps its own literal advice, which is
%% correct THERE because one side is one literal.
the_existing_mixed_pair_keeps_its_own_advice_test() ->
    Src = "module One\n\n"
          "public float Go(float x)\n\n"
          "Go(a) -> a * 2\n",
    [D | _] = errors(Src),
    ?assertEqual(mixed_operands, element(1, element(4, D))),
    ?assert(string:find(prose(D), "2.0") =/= nomatch).

%%% --- helpers ----------------------------------------------------------------

%% The prose a diagnostic term renders to. `bs_diag` decides the words and the
%% checker decides nothing about them, so a test that wants the words asks the
%% renderer rather than the compiler's output.
prose(D) ->
    Desc = bs_diag:descriptor("m.bs", D),
    unicode:characters_to_list(bs_diag:format(Desc)).

%% `errors/1` destructures `{error, Diags}` and so CRASHES on a program that
%% compiles clean — which is the answer half the assertions here want. This one
%% answers `[]` instead, so "nothing was refused" is an assertion rather than a
%% different-shaped failure.
diags(Src) ->
    case check_only(Src) of
        {error, Ds} -> [D || D <- Ds, element(1, D) =:= error];
        _           -> []
    end.

%% A refusal the checker RAISES rather than returns, which is how the type
%% prefix family refuses: `not_a_record` has always worked this way, and F53's
%% own refusal joins it there so that a clause head and a switch arm cannot
%% disagree (both reach it through `pattern_type/3`). A raise stops the file,
%% so there is no second diagnostic to read and no dead arm to compile.
refusal(Src) ->
    try check_only(Src) of
        Other -> erlang:error({expected_a_refusal_but_got, Other})
    catch
        error:{expected_a_refusal_but_got, _} = E -> erlang:error(E);
        error:Reason                              -> Reason
    end.
