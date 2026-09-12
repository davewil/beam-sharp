%%% F46 — a function as a value (ticket 75, ENG-365).
%%%
%%% The arrow `fn(T) -> U` is a type of the language, a lambda `(a, b) => e`
%%% is an expression in C#'s spelling, a name in value position is that
%%% function, and a call through a bound name is a call form. All four are
%%% observable at the boundary: a program using them compiles and runs, or is
%%% refused with the diagnostic the ticket owes. Nothing here reads the
%%% checker's tables.

-module(function_value_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, run_cli/1]).

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

has(Out, S)   -> ?assert(string:find(Out, S) =/= nomatch).
ok_rc(Out)    -> has(Out, "rc:0").
bad_rc(Out)   -> has(Out, "rc:1").

%% The errors a source provokes, empty when it checks clean.
errors(Src) ->
    Diags = case check_only(Src) of
                {ok, _, Ds}  -> Ds;
                {error, Ds}  -> Ds
            end,
    [D || D <- Diags, element(1, D) =:= error].

tags(Src) ->
    [case D of
         {error, _, _, T} when is_tuple(T) -> element(1, T);
         {error, _, _, T}                  -> T
     end || D <- errors(Src)].

in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

%% Ticket 75's program B: an arrow in a signature, lambdas and a name as
%% clause bodies, a call through a bound name.
pricing_src() ->
    "module Pricing\n"
    "public fn(int) -> int Rule(atom tier)\n"
    "Rule(:standard) -> (cents) => cents\n"
    "Rule(:member)   -> (cents) => cents - 100\n"
    "Rule(:staff)    -> Free\n"
    "Rule(_)         -> (cents) => cents\n"
    "public int Charge(fn(int) -> int rule, int cents)\n"
    "Charge(rule, cents) -> rule(cents)\n"
    "private int Free(int cents)\n"
    "Free(_) -> 0\n"
    "public int Sum(list<(atom, int)> pairs)\n"
    "Sum(pairs) -> pairs |> List.Fold(0, (acc, (_, n)) => acc + n)\n".

%% Ticket 75's program A: the three traverses, a name bare and written with
%% its arity, and the two spellings of a lambda.
reports_src() ->
    "module Reports\n"
    "public int Double(int n)\n"
    "Double(n) -> n * 2\n"
    "public list<int> Twice(list<int> xs)\n"
    "Twice(xs) -> List.Map(xs, Double)\n"
    "public list<int> Written(list<int> xs)\n"
    "Written(xs) -> List.Map(xs, Double/1)\n"
    "public list<int> Thrice(list<int> xs)\n"
    "Thrice(xs) -> List.Map(xs, (n) => n * 3)\n"
    "public list<int> Bare(list<int> xs)\n"
    "Bare(xs) -> List.Map(xs, n => n + 1)\n"
    "public list<int> Evens(list<int> xs)\n"
    "Evens(xs) -> xs |> List.Filter((n) => n % 2 == 0)\n"
    "public int Total(list<int> xs)\n"
    "Total(xs) -> xs |> List.Fold(0, (acc, n) => acc + n)\n".

%% `LANGUAGE.md` §9's `Map<T, U>`, the program the arrow was owed for.
map_src() ->
    "module Mapping\n"
    "public list<U> Map<T, U>(list<T> xs, fn(T) -> U f)\n"
    "Map([], _)        -> []\n"
    "Map([h, ..t], f)  -> [f(h), ..Map(t, f)]\n"
    "public list<int> Doubled(list<int> xs)\n"
    "Doubled(xs) -> Map(xs, (n) => n * 2)\n"
    "public list<atom> Tagged(list<int> xs)\n"
    "Tagged(xs) -> Map(xs, (n) => n switch { 0 => :zero, _ => :some })\n".

%%% ---------------------------------------------------------------------------
%%% F46.1 — the ticket's program: an arrow declared, returned as a lambda and
%%% as a name, bound to a parameter and called through it
%%% ---------------------------------------------------------------------------

a_lambda_is_a_clause_body_and_a_name_is_too_test() ->
    M = build_and_load(pricing_src(), 'Pricing'),
    Standard = M:'Rule'(standard),
    ?assert(is_function(Standard, 1)),
    ?assertEqual(250, M:'Charge'(Standard, 250)),
    ?assertEqual(150, M:'Charge'(M:'Rule'(member), 250)),
    ?assertEqual(0, M:'Charge'(M:'Rule'(staff), 250)).

a_lambda_parameter_is_a_pattern_test() ->
    M = build_and_load(pricing_src(), 'Pricing'),
    ?assertEqual(7, M:'Sum'([{a, 3}, {b, 4}])).

%%% ---------------------------------------------------------------------------
%%% F46.2 — a name in value position: bare where the site fixes the arity,
%%% `Double/1` anywhere; both spellings of the lambda
%%% ---------------------------------------------------------------------------

a_name_and_a_lambda_are_the_same_arrow_test() ->
    M = build_and_load(reports_src(), 'Reports'),
    ?assertEqual([2, 4], M:'Twice'([1, 2])),
    ?assertEqual([2, 4], M:'Written'([1, 2])),
    ?assertEqual([3, 6], M:'Thrice'([1, 2])),
    ?assertEqual([2, 3], M:'Bare'([1, 2])),
    ?assertEqual([2, 4], M:'Evens'([1, 2, 3, 4])),
    ?assertEqual(10, M:'Total'([1, 2, 3, 4])).

%%% ---------------------------------------------------------------------------
%%% F46.3 — `Map<T, U>`: an arrow in a polymorphic signature, solved from a
%%% lambda's own result at two types
%%% ---------------------------------------------------------------------------

a_polymorphic_arrow_is_solved_from_the_lambda_test() ->
    M = build_and_load(map_src(), 'Mapping'),
    ?assertEqual([2, 4], M:'Doubled'([1, 2])),
    ?assertEqual([zero, some], M:'Tagged'([0, 5])).

%% The control: declare `Tagged` narrower than the lambda's result and it is
%% refused, so the green above is the solve of `U` and not `term`.
a_polymorphic_arrow_declared_narrower_is_refused_test() ->
    Src = "module Mapping\n"
          "public list<U> Map<T, U>(list<T> xs, fn(T) -> U f)\n"
          "Map([], _)        -> []\n"
          "Map([h, ..t], f)  -> [f(h), ..Map(t, f)]\n"
          "public list<int> Tagged(list<int> xs)\n"
          "Tagged(xs) -> Map(xs, (n) => :some)\n",
    ?assertEqual([return_not_declared], tags(Src)).

%%% ---------------------------------------------------------------------------
%%% F46.4 — the four refusals ticket 75 owes
%%% ---------------------------------------------------------------------------

%% A lambda where no arrow is expected: a binding fixes nothing.
a_lambda_with_no_expected_arrow_is_refused_test() ->
    Src = "module Later\n"
          "public int Later(int n)\n"
          "Later(n) -> var twice = (k) => k * 2\n"
          "            twice(n)\n",
    ?assertMatch([{error, _, 'Later', lambda_without_expectation}], errors(Src)).

%% A bare name whose arity nothing fixes, beside two arities.
a_bare_name_between_two_arities_is_refused_test() ->
    Src = "module Two\n"
          "public int Double(int n)\n"
          "Double(n) -> n * 2\n"
          "public int Double(int n, int k)\n"
          "Double(n, k) -> n * k\n"
          "public int Later(int n)\n"
          "Later(n) -> var f = Double\n"
          "            f(n)\n",
    ?assertMatch([{error, _, 'Later', {name_arity_unfixed, 'Double', [1, 2]}}],
                 errors(Src)).

%% The control: one arity, and the bare name needs no expectation.
a_bare_name_with_one_arity_needs_no_expectation_test() ->
    Src = "module One\n"
          "public int Double(int n)\n"
          "Double(n) -> n * 2\n"
          "public int Later(int n)\n"
          "Later(n) -> var f = Double\n"
          "            f(n)\n",
    ?assertEqual([], errors(Src)),
    M = build_and_load(Src, 'One'),
    ?assertEqual(8, M:'Later'(4)).

%% A lambda parameter refuted by the domain: the residual is the refusal, as
%% the destructuring bind prints it.
a_lambda_parameter_refuted_by_the_domain_is_refused_test() ->
    Src = "module Oks\n"
          "public int Oks(list<result<int, string>> rs)\n"
          "Oks(rs) -> rs |> List.Fold(0, (acc, (:ok, n)) => acc + n)\n",
    ?assertMatch([{error, _, 'Oks', {lambda_param_refuted, 2, _}}], errors(Src)).

%% A call through a name whose type is not an arrow of that arity.
a_call_through_a_non_arrow_is_refused_test() ->
    Src = "module Bad\n"
          "public int Charge(int rule, int cents)\n"
          "Charge(rule, cents) -> rule(cents)\n",
    ?assertMatch([{error, _, 'Charge', {not_callable, rule, 1, _}}], errors(Src)),
    Src2 = "module Bad\n"
           "public int Charge(fn(int, int) -> int rule, int cents)\n"
           "Charge(rule, cents) -> rule(cents)\n",
    ?assertMatch([{error, _, 'Charge', {not_callable, rule, 1, _}}], errors(Src2)).

%%% ---------------------------------------------------------------------------
%%% F46.5 — the arrow is contained like any type: domain contravariant,
%%% codomain covariant, and a non-arrow is refused where one is declared
%%% ---------------------------------------------------------------------------

%% The must-refuse: a forgotten seventh part in the algebra's emptiness test
%% would report an arrow-only type empty and let this through.
an_int_where_an_arrow_is_declared_is_refused_test() ->
    Src = pricing_src() ++
          "public int Wrong()\n"
          "Wrong() -> Charge(3, 4)\n",
    ?assertMatch([{error, _, 'Wrong', {arg_not_accepted, 'Charge', 1, _, _}}],
                 errors(Src)).

a_wider_domain_is_accepted_and_a_narrower_one_refused_test() ->
    Wider = "module Var\n"
            "public int Apply(fn(int) -> int f, int n)\n"
            "Apply(f, n) -> f(n)\n"
            "public int Any(term x)\n"
            "Any(_) -> 1\n"
            "public int Run(int n)\n"
            "Run(n) -> Apply(Any, n)\n",
    ?assertEqual([], errors(Wider)),
    Narrower = "module Var\n"
               "public int Apply(fn(term) -> int f, term n)\n"
               "Apply(f, n) -> f(n)\n"
               "public int OnlyInt(int x)\n"
               "OnlyInt(_) -> 1\n"
               "public int Run(int n)\n"
               "Run(n) -> Apply(OnlyInt, n)\n",
    ?assertMatch([{error, _, 'Run', {arg_not_accepted, 'Apply', 1, _, _}}],
                 errors(Narrower)).

a_lambda_returning_outside_the_codomain_is_refused_test() ->
    Src = "module Cod\n"
          "public list<int> Bad(list<int> xs)\n"
          "Bad(xs) -> List.Map(xs, (n) => :atom)\n",
    ?assertEqual([return_not_declared], tags(Src)).

a_filter_predicate_must_return_bool_test() ->
    Src = "module Pred\n"
          "public list<int> Bad(list<int> xs)\n"
          "Bad(xs) -> List.Filter(xs, (n) => n)\n",
    ?assertMatch([{error, _, 'Bad', {arg_not_accepted, 'List.Filter', 2, _, _}}],
                 errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F46.6 — the corrected signature and `--api` spell an arrow as the author
%%% does
%%% ---------------------------------------------------------------------------

the_corrected_signature_prints_an_arrow_test() ->
    Src = "module Pick\n"
          "private int Free(int cents)\n"
          "Free(_) -> 0\n"
          "public int Pick()\n"
          "Pick() -> Free\n",
    {Root, Main} = in_dir([{"Pick.bs", Src}]),
    Out = run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main),
    bad_rc(Out),
    has(Out, "public int | fn(int) -> int Pick()").

api_prints_the_arrow_test() ->
    {Root, Main} = in_dir([{"Pricing.bs", pricing_src()}]),
    Out = run_cli("--src-root " ++ Root ++ " --api " ++ Main),
    ok_rc(Out),
    has(Out, "fn(int) -> int Rule(atom)\n"),
    has(Out, "int Charge(fn(int) -> int, int)\n").

%%% ---------------------------------------------------------------------------
%%% F46.7 — scope: a lambda closes over the clause and its parameters bind
%%% under ticket 34, no shadowing
%%% ---------------------------------------------------------------------------

a_lambda_closes_over_the_clause_test() ->
    Src = "module Close\n"
          "public list<int> Shift(list<int> xs, int by)\n"
          "Shift(xs, by) -> List.Map(xs, (n) => n + by)\n",
    M = build_and_load(Src, 'Close'),
    ?assertEqual([11, 12], M:'Shift'([1, 2], 10)).

a_lambda_parameter_may_not_reuse_an_enclosing_name_test() ->
    Src = "module Shadow\n"
          "public list<int> Shift(list<int> xs, int n)\n"
          "Shift(xs, n) -> List.Map(xs, (n) => n + 1)\n",
    ?assertMatch([{error, _, 'Shift', {rebinding, n}}], errors(Src)).

a_lambda_body_reading_an_unbound_name_is_refused_test() ->
    Src = "module Unb\n"
          "public list<int> Shift(list<int> xs)\n"
          "Shift(xs) -> List.Map(xs, (n) => n + by)\n",
    ?assertMatch([{error, _, 'Shift', {unbound_variable, by}}], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F46.8 — the pipe does not move: `xs |> Sum` stays a syntax error, and a
%%% call through a bound name is a call the pipe rewrites
%%% ---------------------------------------------------------------------------

the_pipe_into_a_bare_name_is_still_a_syntax_error_test() ->
    Src = "module Pipe\n"
          "public int Sum(list<int> xs)\n"
          "Sum(xs) -> List.Sum(xs)\n"
          "public int Total(list<int> xs)\n"
          "Total(xs) -> xs |> Sum\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    ?assertMatch({error, _}, bs_parser:parse(Toks)).

the_pipe_into_an_applied_name_is_a_call_test() ->
    Src = "module Pipe\n"
          "public int Apply(fn(int) -> int f, int n)\n"
          "Apply(f, n) -> n |> f()\n",
    M = build_and_load(Src, 'Pipe'),
    ?assertEqual(5, M:'Apply'(fun(X) -> X + 1 end, 4)).

%%% ---------------------------------------------------------------------------
%%% F46.9 — a switch arm's body takes the clause's expected arrow; the
%%% codomain runs as far as the type expression does
%%% ---------------------------------------------------------------------------

a_switch_arm_hands_the_clause_expectation_to_its_lambda_test() ->
    Src = "module Arms\n"
          "public fn(int) -> int Rule(atom tier)\n"
          "Rule(tier) -> tier switch {\n"
          "    :member => (c) => c - 100,\n"
          "    _       => (c) => c\n"
          "}\n",
    M = build_and_load(Src, 'Arms'),
    ?assertEqual(150, (M:'Rule'(member))(250)).

the_codomain_absorbs_a_union_test() ->
    Src = "module Look\n"
          "type Lookup = fn(atom) -> int | :nothing\n"
          "public Lookup Table()\n"
          "Table() -> (k) => k switch { :a => 1, _ => :nothing }\n",
    M = build_and_load(Src, 'Look'),
    ?assertEqual(1, (M:'Table'())(a)),
    ?assertEqual(nothing, (M:'Table'())(b)).

%%% ---------------------------------------------------------------------------
%%% F46.10 — what was fixed earlier and must hold: `ValidateAs<T>` refuses an
%%% arrow (ticket 11), a foreign return may not promise one (ticket 18 §2),
%%% two arrows of one arity in a bare union are indiscriminable (ticket 70)
%%% and two of different arity are not
%%% ---------------------------------------------------------------------------

validate_as_over_an_arrow_is_refused_test() ->
    Src = "module Val\n"
          "public result<fn(int) -> int, ValidationError> Check(term x)\n"
          "Check(x) -> ValidateAs<fn(int) -> int>(x)\n",
    ?assertMatch([{error, _, 'Check', {validate_over_arrow, _}}], errors(Src)).

%% A declaration refusal is raised, as F40's and F36's are, and the CLI turns
%% it into the diagnostic; here it is observed as raised.
a_foreign_return_may_not_promise_an_arrow_test() ->
    Src = "module For\n"
          "using :m {\n"
          "  fn(int) -> int get()\n"
          "}\n"
          "public int Run(int n)\n"
          "Run(n) -> n\n",
    ?assertError({foreign_ret_beyond_one_guard, _, _, _, _, arrow, _, _, _},
                 check_only(Src)).

%% Spelled through named arrows, because the codomain runs as far as the
%% type expression does: `fn(int) -> int | fn(atom) -> int` is ONE arrow
%% returning `int | fn(atom) -> int` (ticket 75 Q6).
two_arrows_of_one_arity_are_indiscriminable_test() ->
    Src = "module Same\n"
          "type A = fn(int) -> int\n"
          "type B = fn(atom) -> int\n"
          "public int Run(A | B f)\n"
          "Run(f) -> 1\n",
    ?assertError({indiscriminable_union, _, _, _, _}, check_only(Src)).

the_codomain_takes_the_union_test() ->
    Src = "module Cod\n"
          "public fn(int) -> int | :nothing Pick()\n"
          "Pick() -> (n) => n switch { 0 => :nothing, _ => n }\n",
    M = build_and_load(Src, 'Cod'),
    ?assertEqual(nothing, (M:'Pick'())(0)),
    ?assertEqual(3, (M:'Pick'())(3)).

two_arrows_of_different_arity_are_discriminable_test() ->
    Src = "module Diff\n"
          "type Rule = fn(int) -> int\n"
          "type Pair = fn(int, int) -> int\n"
          "public int Run(Rule | Pair f)\n"
          "Run(f) -> 1\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F46.11 — the corpus program compiles and runs through the CLI, so an edit
%%% there cannot silently drop the arrow
%%% ---------------------------------------------------------------------------

the_corpus_program_runs_test() ->
    Root = bs_test_support:project_root() ++ "/examples",
    File = Root ++ "/Shop/Pricing/Pricing.bs",
    Out = run_cli("--src-root " ++ Root ++ " " ++ File ++ " Charged :member 250"),
    ok_rc(Out),
    has(Out, "150\n"),
    Out2 = run_cli("--src-root " ++ Root ++ " " ++ File
                   ++ " Owed \"[(:a, 3), (:b, 4)]\""),
    ok_rc(Out2),
    has(Out2, "7\n").
