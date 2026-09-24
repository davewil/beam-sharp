%%% Scenarios: compiler/features/F51-float.md
-module(float_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, errors/1, run_cli/1]).

%%% F51 — floats remain distinct from integers.

stats() ->
    "module Stats\n\n"
    "public float Mean(list<int> samples)\n\n"
    "Mean([]) -> 0.0\n"
    "Mean(xs) -> Float.FromInt(List.Sum(xs)) / Float.FromInt(List.Length(xs))\n\n"
    "public atom Verdict(float mean)\n\n"
    "Verdict(0.0) -> :empty\n"
    "Verdict(_)   -> :some\n\n"
    "public atom Check(list<int> xs)\n\n"
    "Check(xs) -> Verdict(Mean(xs))\n\n"
    "public int Slash(int a, int b)\n\n"
    "Slash(a, b) -> a / b\n".

%%% F51.1 — integer samples produce a float mean.

mean_of_ints_is_a_float_test() ->
    M = build_and_load(stats(), 'Stats'),
    ?assertEqual(3.0, M:'Mean'([2, 4])),
    ?assertEqual(0.0, M:'Mean'([])),
    ?assertEqual(2.5, M:'Mean'([2, 3])).

%% Both division kinds share a module; integer division must still truncate.
int_division_still_truncates_beside_float_division_test() ->
    M = build_and_load(stats(), 'Stats'),
    ?assertEqual(-3, M:'Slash'(-7, 2)),
    ?assertEqual(3, M:'Slash'(7, 2)).

verdict_of_the_empty_mean_is_empty_test() ->
    M = build_and_load(stats(), 'Stats'),
    ?assertEqual(empty, M:'Check'([])),
    ?assertEqual(some, M:'Check'([2, 4])).

%%% F51.2 — float literals and unary minus retain their meaning.

float_literals_lex_in_every_spelling_test() ->
    Src = "module Lits\n\n"
          "public list<float> All()\n\n"
          "All() -> [1.5, 0.0, 1.0e20, 2.5e-3, 10.25E+2]\n",
    M = build_and_load(Src, 'Lits'),
    ?assertEqual([1.5, 0.0, 1.0e20, 2.5e-3, 1025.0], M:'All'()).

%% Test the lexer directly: no source form accepts `1..5`, but residuals use it.
one_dot_dot_five_is_not_a_float_test() ->
    {ok, Toks, _} = bs_lexer:string("1..5"),
    ?assertMatch([{integer, _, 1}, {'..', _}, {integer, _, 5}], Toks),
    {ok, Toks2, _} = bs_lexer:string("1.5"),
    ?assertMatch([{float, _, 1.5}], Toks2).

%% Lowering unary minus as `0 - x` would introduce a mixed numeric pair.
negation_is_the_beams_test() ->
    Src = "module Neg\n\n"
          "public float Flip(float x)\n\n"
          "Flip(x) -> -x\n\n"
          "public atom Sign(float x)\n\n"
          "Sign(-1.5) -> :minus_one_and_a_half\n"
          "Sign(_)    -> :other\n\n"
          "public float MinusOne()\n\n"
          "MinusOne() -> -1.0\n",
    M = build_and_load(Src, 'Neg'),
    ?assertEqual(-1.5, M:'Flip'(1.5)),
    ?assertEqual(2.0, M:'Flip'(-2.0)),
    ?assertEqual(minus_one_and_a_half, M:'Sign'(-1.5)),
    ?assertEqual(other, M:'Sign'(1.5)),
    ?assertEqual(-1.0, M:'MinusOne'()).

%%% F51.3 — float heads distinguish signed zero without warnings.

%% OTP 27+ distinguishes signed zero; erlc warns on a bare `0.0` pattern.
%% Emitting `+0.0` makes the positive-zero match explicit.
the_float_zero_head_matches_positive_zero_alone_test() ->
    M = build_and_load(stats(), 'Stats'),
    ?assertEqual(empty, M:'Verdict'(0.0)),
    ?assertEqual(some, M:'Verdict'(-0.0)),
    ?assertEqual(some, M:'Verdict'(1.5)).

%% The CLI forwards erlc warnings, exposing a bare-zero pattern here.
the_float_zero_head_draws_no_warning_test() ->
    bs_test_support:with_src(
      "Stats.bs", stats(),
      fun(Path, _Root) ->
              Out = run_cli(Path ++ " Verdict 0.0"),
              ?assertEqual(nomatch, string:find(Out, "0.0 will no longer")),
              ?assertEqual(nomatch, string:find(Out, "Warning")),
              ?assertEqual(":empty\nrc:0\n", Out)
      end).

a_negative_zero_head_is_its_own_case_test() ->
    Src = "module Zeros\n\n"
          "public atom Which(float x)\n\n"
          "Which(0.0)  -> :positive_zero\n"
          "Which(-0.0) -> :negative_zero\n"
          "Which(_)    -> :other\n",
    M = build_and_load(Src, 'Zeros'),
    ?assertEqual(positive_zero, M:'Which'(0.0)),
    ?assertEqual(negative_zero, M:'Which'(-0.0)),
    ?assertEqual(other, M:'Which'(2.0)).

%%% F51.4 — integers and floats require explicit conversion.

an_int_returned_where_a_float_is_declared_is_refused_test() ->
    Src = "module Bad\n\n"
          "public float Mean(list<int> samples)\n\n"
          "Mean([]) -> 0\n"
          "Mean(xs) -> Float.FromInt(List.Sum(xs)) / Float.FromInt(List.Length(xs))\n",
    [D | _] = errors(Src),
    ?assertMatch({return_not_declared, _, _}, element(4, D)),
    {return_not_declared, Residual, _} = element(4, D),
    ?assertEqual("0", bs_types:to_string(Residual)),
    %% The CLI must name the float literal as well as report the residual.
    bs_test_support:with_src(
      "Bad.bs", Src,
      fun(Path, _Root) ->
              Out = run_cli(Path),
              ?assertNotEqual(nomatch, string:find(Out, "`0` is an `int`; the float is `0.0`"))
      end).

%% BEAM remainder accepts integers; a float operand raises badarith.
a_remainder_over_two_floats_is_refused_test() ->
    Src = "module Rem\n\n"
          "public int Mod(float x)\n\n"
          "Mod(x) -> x % 2.0\n",
    [D | _] = errors(Src),
    ?assertEqual(float_remainder, element(4, D)),
    Ints = "module Rem\n\n"
           "public int Mod(int x)\n\n"
           "Mod(x) -> x % 2\n",
    ?assertMatch({ok, _}, compile(Ints)).

a_mixed_pair_at_an_operator_is_refused_test() ->
    Src = "module Mixed\n\n"
          "public float Mean(list<int> samples)\n\n"
          "Mean([]) -> 0.0\n"
          "Mean(xs) -> Float.FromInt(List.Sum(xs)) / List.Length(xs)\n",
    [D | _] = errors(Src),
    ?assertEqual({mixed_operands, '/', float, int, none}, element(4, D)).

every_operator_refuses_the_mixed_pair_test() ->
    [begin
         Src = "module Mixed\n\n"
               "public term Go(int n, float f)\n\n"
               "Go(n, f) -> " ++ Left ++ " " ++ Op ++ " " ++ Right ++ "\n",
         [D | _] = errors(Src),
         ?assertMatch({mixed_operands, _, _, _, _}, element(4, D))
     end || Op <- ["+", "-", "*", "/", "<", "<=", ">", ">=", "==", "!="],
            {Left, Right} <- [{"n", "f"}, {"f", "n"}, {"f", "1"}, {"1.5", "n"}]].

the_mixed_pair_message_names_the_conversion_test() ->
    Src = "module Mixed\n\n"
          "public float Half(float x, int n)\n\n"
          "Half(x, n) -> x / n\n",
    bs_test_support:with_src(
      "Mixed.bs", Src,
      fun(Path, _Root) ->
              Out = run_cli(Path),
              ?assertNotEqual(nomatch, string:find(Out, "`/` in Half has a `float` on its left and an `int` on its right")),
              ?assertNotEqual(nomatch, string:find(Out, "Float.FromInt(n)"))
      end),
    Src2 = "module Mixed\n\n"
           "public float Half(float x)\n\n"
           "Half(x) -> x / 2\n",
    bs_test_support:with_src(
      "Mixed.bs", Src2,
      fun(Path, _Root) ->
              Out = run_cli(Path),
              ?assertNotEqual(nomatch, string:find(Out, "write `2.0`"))
      end).

%% The refusal must distinguish mixed operands from valid same-kind pairs.
two_floats_or_two_ints_at_an_operator_compile_test() ->
    Src = "module Fine\n\n"
          "public float Area(float w, float h)\n\n"
          "Area(w, h) -> w * h + 0.5\n\n"
          "public bool Wider(float w, float h)\n\n"
          "Wider(w, h) -> w > h\n\n"
          "public int Twice(int n)\n\n"
          "Twice(n) -> n * 2\n",
    M = build_and_load(Src, 'Fine'),
    ?assertEqual(6.5, M:'Area'(2.0, 3.0)),
    ?assertEqual(true, M:'Wider'(3.0, 2.0)),
    ?assertEqual(4, M:'Twice'(2)).

%% A refused operand has bottom type; it must not cause a mixed-pair error.
an_already_refused_operand_reports_once_test() ->
    Src = "module Once\n\n"
          "public float Go(float f)\n\n"
          "Go(f) -> f + nope\n",
    Ds = errors(Src),
    ?assertEqual(1, length(Ds)),
    ?assertNotMatch({mixed_operands, _, _, _, _}, element(4, hd(Ds))).

a_float_compared_with_an_int_literal_in_a_guard_is_refused_test() ->
    Src = "module Guarded\n\n"
          "public atom Sign(float x)\n\n"
          "Sign(x) when x < 0 -> :negative\n"
          "Sign(_)            -> :other\n",
    [D | _] = errors(Src),
    ?assertEqual({mixed_operands, '<', float, int, "0.0"}, element(4, D)),
    %% A dead-guard warning would give advice conflicting with the error.
    {error, All} = bs_test_support:check_only(Src),
    ?assertEqual(1, length(All)).

%% Float guards select values but earn no interval coverage.
a_float_guard_selects_but_credits_nothing_test() ->
    Src = "module Guarded\n\n"
          "public atom Sign(float x)\n\n"
          "Sign(x) when x < 0.0 -> :negative\n"
          "Sign(_)              -> :other\n",
    M = build_and_load(Src, 'Guarded'),
    ?assertEqual(negative, M:'Sign'(-1.5)),
    ?assertEqual(other, M:'Sign'(1.5)),
    Uncovered = "module Guarded\n\n"
                "public atom Sign(float x)\n\n"
                "Sign(x) when x < 0.0  -> :negative\n"
                "Sign(x) when x >= 0.0 -> :other\n",
    [D | _] = errors(Uncovered),
    ?assertEqual(inexhaustive, element(1, element(4, D))).

%%% F51.5 — Float.FromInt is an inlined, reserved operation.

%% The import table distinguishes inlining from a call to a Float module.
float_from_int_is_inlined_test() ->
    Root = bs_test_support:fixture_root(),
    Path = bs_test_support:place(Root, "Stats.bs", stats()),
    Out = run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Path),
    ?assertNotEqual(nomatch, string:find(Out, "rc:0")),
    {ok, {'Stats', [{imports, Imports}]}} =
        beam_lib:chunks(Root ++ "/out/Stats.beam", [imports]),
    ?assertEqual([], [I || {'Float', _, _} = I <- Imports]),
    ?assertNotEqual([], [I || {erlang, float, 1} = I <- Imports]).

float_from_int_refuses_a_float_test() ->
    Src = "module Conv\n\n"
          "public float Twice(float x)\n\n"
          "Twice(x) -> Float.FromInt(x) * 2.0\n",
    [D | _] = errors(Src),
    ?assertEqual(arg_not_accepted, element(1, element(4, D))).

float_of_is_not_an_operation_test() ->
    Src = "module Conv\n\n"
          "public float Go(int n)\n\n"
          "Go(n) -> Float.Of(n)\n",
    [D | _] = errors(Src),
    ?assertMatch({unknown_reserved_operation, 'Float', 'Of', 1, []}, element(4, D)).

a_module_named_float_is_refused_test() ->
    Root = bs_test_support:fixture_root(),
    Src = "module Float\n\n"
          "public int Go(int n)\n\n"
          "Go(n) -> n\n",
    %% Reserved names are refused before path checks, regardless of directory.
    Path = bs_test_support:place(Root, "Float.bs", Src),
    Out = run_cli("--src-root " ++ Root ++ " " ++ Path ++ " Go 1"),
    ?assertNotEqual(nomatch, string:find(Out, "rc:1")),
    ?assertNotEqual(nomatch, string:find(Out, "reserved")).

%%% F51.6 — floats compose with the other types.

term_holds_the_float_test() ->
    Src = "module Top\n\n"
          "public term Id(float f)\n\n"
          "Id(f) -> f\n",
    M = build_and_load(Src, 'Top'),
    ?assertEqual(1.5, M:'Id'(1.5)),
    Down = "module Top\n\n"
           "public float Down(term t)\n\n"
           "Down(t) -> t\n",
    [D | _] = errors(Down),
    ?assertMatch({return_not_declared, _, _}, element(4, D)).

int_or_float_is_discriminable_test() ->
    Src = "module Num\n\n"
          "type Num = int | float\n\n"
          "public atom Kind(Num n)\n\n"
          "Kind(0)   -> :zero\n"
          "Kind(0.0) -> :float_zero\n"
          "Kind(_)   -> :other\n",
    M = build_and_load(Src, 'Num'),
    ?assertEqual(zero, M:'Kind'(0)),
    ?assertEqual(float_zero, M:'Kind'(0.0)),
    ?assertEqual(other, M:'Kind'(1)),
    ?assertEqual(other, M:'Kind'(1.5)).

a_float_literal_alone_is_not_exhaustive_test() ->
    Src = "module Only\n\n"
          "public atom Verdict(float mean)\n\n"
          "Verdict(0.0) -> :empty\n",
    [D | _] = errors(Src),
    ?assertEqual(inexhaustive, element(1, element(4, D))),
    %% The residual is the clause product, one component here.
    Residual = element(2, element(4, D)),
    ?assertEqual("(float \\ (0.0))", bs_types:to_string(Residual)).

float_prints_as_float_test() ->
    bs_test_support:with_src(
      "Stats.bs", stats(),
      fun(Path, _Root) ->
              Out = run_cli("--api " ++ Path),
              ?assertNotEqual(nomatch, string:find(Out, "float"))
      end).

a_float_inside_a_list_and_a_tuple_test() ->
    Src = "module Nested\n\n"
          "public float First(list<float> xs)\n\n"
          "First([])       -> 0.0\n"
          "First([x, ..])  -> x\n\n"
          "public (float, int) Pair(float f, int n)\n\n"
          "Pair(f, n) -> (f, n)\n",
    M = build_and_load(Src, 'Nested'),
    ?assertEqual(1.5, M:'First'([1.5, 2.5])),
    ?assertEqual({1.5, 2}, M:'Pair'(1.5, 2)).

%%% F51.7 — public and foreign boundaries enforce float types.

a_public_float_parameter_is_guarded_test() ->
    Src = "module Bound\n\n"
          "public float Twice(float x)\n\n"
          "Twice(x) -> x * 2.0\n",
    M = build_and_load(Src, 'Bound'),
    ?assertEqual(3.0, M:'Twice'(1.5)),
    ?assertError(function_clause, M:'Twice'(1)),
    ?assertError(function_clause, M:'Twice'(one)).

a_float_still_does_not_reach_an_int_parameter_test() ->
    Src = "module Bump\n\n"
          "public int Bump(int n)\n\n"
          "Bump(n) -> n + 1\n",
    M = build_and_load(Src, 'Bump'),
    ?assertEqual(2, M:'Bump'(1)),
    ?assertError(function_clause, M:'Bump'(1.5)).

a_float_literal_head_needs_no_kind_test_test() ->
    Src = "module Pinned\n\n"
          "public atom Is(float x)\n\n"
          "Is(1.5) -> :yes\n"
          "Is(_)   -> :no\n",
    M = build_and_load(Src, 'Pinned'),
    ?assertEqual(yes, M:'Is'(1.5)),
    ?assertEqual(no, M:'Is'(2.5)),
    ?assertError(function_clause, M:'Is'(1)).

%% Read the published spec from the compiled beam's abstract code.
the_spec_publishes_float_test() ->
    Root = bs_test_support:fixture_root(),
    Path = bs_test_support:place(Root, "Stats.bs", stats()),
    _ = run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Path),
    {ok, {'Stats', [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(Root ++ "/out/Stats.beam", [abstract_code]),
    Specs = [S || {attribute, _, spec, {{'Mean', 1}, S}} <- Forms],
    ?assertMatch([[{type, _, 'fun', [_, {type, _, float, []}]}]], Specs).

a_foreign_float_return_is_guarded_test() ->
    Src = "module Ffi\n\n"
          "using :erlang {\n"
          "    float float(int x)\n"
          "    float abs(int x)\n"
          "}\n\n"
          "public float Up(int n)\n\n"
          "Up(n) -> :erlang.float(n)\n\n"
          "public float Lie(int n)\n\n"
          "Lie(n) -> :erlang.abs(n)\n",
    M = build_and_load(Src, 'Ffi'),
    ?assertEqual(3.0, M:'Up'(3)),
    ?assertError({case_clause, 3}, M:'Lie'(3)).

%%% F51.8 — validation and JSON support floats.

the_obligations_carry_the_part_test() ->
    Src = "module Obl\n\n"
          "public result<float, ValidationError> Check(term t)\n\n"
          "Check(t) -> ValidateAs<float>(t)\n\n"
          "public result<list<float>, ValidationError> Many(term t)\n\n"
          "Many(t) -> ValidateAs<list<float>>(t)\n\n"
          "public string Wire(float f)\n\n"
          "Wire(f) -> ToJson<float>(f)\n",
    M = build_and_load(Src, 'Obl'),
    ?assertEqual(1.5, M:'Check'(1.5)),
    ?assertEqual(bs_test_support:validation_error([], <<"float">>),
                 M:'Check'(1)),
    ?assertEqual([1.5, 2.5], M:'Many'([1.5, 2.5])),
    ?assertEqual(bs_test_support:validation_error([<<"[1]">>], <<"float">>),
                 M:'Many'([1.5, 2])),
    ?assertEqual(<<"1.5">>, M:'Wire'(1.5)),
    ?assertEqual(<<"1.0e20">>, M:'Wire'(1.0e20)).

%%% F51.9 — only provably zero float divisors are refused.

a_provably_zero_float_divisor_is_refused_test() ->
    Src = "module Zero\n\n"
          "public float Go(float x)\n\n"
          "Go(x) -> x / 0.0\n",
    [D | _] = errors(Src),
    ?assertMatch({divide_by_zero, '/'}, element(4, D)),
    Fine = "module Zero\n\n"
           "public float Go(float x, float y)\n\n"
           "Go(x, y) -> x / y\n",
    ?assertMatch({ok, _}, compile(Fine)).

a_mixed_pair_in_a_switch_arm_guard_is_refused_test() ->
    Src = "module Sw\n\n"
          "public atom Kind(float x)\n\n"
          "Kind(x) -> x switch {\n"
          "    m when m < 0 => :negative,\n"
          "    _            => :other\n"
          "}\n",
    {error, All} = bs_test_support:check_only(Src),
    ?assertEqual([{mixed_operands, '<', float, int, "0.0"}],
                 [element(4, D) || D <- All]),
    Fine = "module Sw\n\n"
           "public atom Kind(float x)\n\n"
           "Kind(x) -> x switch {\n"
           "    m when m < 0.0 => :negative,\n"
           "    _              => :other\n"
           "}\n",
    M = build_and_load(Fine, 'Sw'),
    ?assertEqual(negative, M:'Kind'(-1.5)),
    ?assertEqual(other, M:'Kind'(1.5)).

%%% F51.10 — float literal switch arms select values.

a_float_literal_in_a_switch_arm_test() ->
    Src = "module Sw\n\n"
          "public atom Kind(float x)\n\n"
          "Kind(x) -> x switch {\n"
          "    0.0 => :zero,\n"
          "    _   => :other\n"
          "}\n",
    M = build_and_load(Src, 'Sw'),
    ?assertEqual(zero, M:'Kind'(0.0)),
    ?assertEqual(other, M:'Kind'(2.0)).
