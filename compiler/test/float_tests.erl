-module(float_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, errors/1, run_cli/1]).

%%% ---------------------------------------------------------------------------
%%% F51 — `float`, the eighth part. Tickets 69, 80 and 81; ENG-378.
%%%
%%% THREE DECISIONS, EACH WITH THE PROGRAM THAT WOULD GO WRONG WITHOUT IT.
%%%
%%%   69  `float` is a type: the BEAM's float, a part of the lattice beside
%%%       `int` and NOT inside it. `/` lowers by its operand types — `div` on
%%%       two ints (38), the BEAM's `/` on two floats. The literal is C#'s.
%%%   80  nothing flows between the two parts: `0` where a `float` is declared
%%%       is refused, a `float` beside an `int` at an operator is refused, and
%%%       the emitter writes no conversion anywhere.
%%%   81  the conversion is written by the author as `Float.FromInt(n)`, a
%%%       compiler-known entry under a reserved qualifier, inlined as
%%%       `erlang:float/1`.
%%%
%%% THE VALUE ASSERTION IS THE EMISSION ASSERTION, as in `division_tests`: an
%%% emitter that lowered every `/` to the BEAM's `/` once floats existed would
%%% turn `-7 / 2` from `-3` into `-3.5`, and a test that asserts `-3` in a
%%% module that also divides floats is the one that sees it.
%%% ---------------------------------------------------------------------------

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

%%% --- F51.1 — the ticket's program -------------------------------------------

%% `bsc Stats.bs Mean '[2, 4]'` prints `3.0`. Refused four times over before
%% this feature: `float` was not a builtin type, `0.0` did not lex, `Float` was
%% not a reserved qualifier, and `/` lowered to `div` unconditionally.
mean_of_ints_is_a_float_test() ->
    M = build_and_load(stats(), 'Stats'),
    ?assertEqual(3.0, M:'Mean'([2, 4])),
    ?assertEqual(0.0, M:'Mean'([])),
    ?assertEqual(2.5, M:'Mean'([2, 3])).

%% `/` on two `int`s is still `div` in a module that also divides floats: the
%% over-informed emitter that lowers every `/` to the BEAM's `/` answers -3.5.
int_division_still_truncates_beside_float_division_test() ->
    M = build_and_load(stats(), 'Stats'),
    ?assertEqual(-3, M:'Slash'(-7, 2)),
    ?assertEqual(3, M:'Slash'(7, 2)).

%% `Verdict(Mean([]))` is `:empty`: the value that reaches the head is the
%% float `0.0` the author wrote, not an `int` the compiler converted.
verdict_of_the_empty_mean_is_empty_test() ->
    M = build_and_load(stats(), 'Stats'),
    ?assertEqual(empty, M:'Check'([])),
    ?assertEqual(some, M:'Check'([2, 4])).

%%% --- F51.2 — the literal -------------------------------------------------------

%% C#'s spelling: digits, a dot, digits, an optional exponent. The printed
%% form of every float is a literal the lexer reads back, since a residual
%% is pasted into source (ticket 23).
float_literals_lex_in_every_spelling_test() ->
    Src = "module Lits\n\n"
          "public list<float> All()\n\n"
          "All() -> [1.5, 0.0, 1.0e20, 2.5e-3, 10.25E+2]\n",
    M = build_and_load(Src, 'Lits'),
    ?assertEqual([1.5, 0.0, 1.0e20, 2.5e-3, 1025.0], M:'All'()).

%% `1..5` is two integers around a rest marker, never `1.` and `.5`: the float
%% rule needs a digit on both sides of the dot, so the lexer stays where
%% ticket 28 put it. Asked of the lexer directly, since no B# form puts a
%% digit before `..` — the residual printer does, and that text is read back
%% by a person, not the parser.
one_dot_dot_five_is_not_a_float_test() ->
    {ok, Toks, _} = bs_lexer:string("1..5"),
    ?assertMatch([{integer, _, 1}, {'..', _}, {integer, _, 5}], Toks),
    {ok, Toks2, _} = bs_lexer:string("1.5"),
    ?assertMatch([{float, _, 1.5}], Toks2).

%% A negative literal in a head and in a body, and unary minus on a float
%% variable, which is the BEAM's own negation and not `0 - x`: under ticket 80
%% `0 - x` is an `int` beside a `float`, refused.
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

%%% --- F51.3 — the float zero in a head ---------------------------------------

%% On OTP 27+ a `0.0` pattern matches `+0.0` alone and `erlc` warns on the
%% bare literal. The head lowers to `+0.0`, Gleam's spelling, so the corpus
%% gate sees no warning and the meaning is the one the platform has.
the_float_zero_head_matches_positive_zero_alone_test() ->
    M = build_and_load(stats(), 'Stats'),
    ?assertEqual(empty, M:'Verdict'(0.0)),
    ?assertEqual(some, M:'Verdict'(-0.0)),
    ?assertEqual(some, M:'Verdict'(1.5)).

%% The bare literal draws `match_float_zero` from `erlc`, and `bsc` reports
%% the platform's warnings on its own stream, so a compile whose output holds
%% the word is a compile that emitted the bare form.
the_float_zero_head_draws_no_warning_test() ->
    bs_test_support:with_src(
      "Stats.bs", stats(),
      fun(Path, _Root) ->
              Out = run_cli(Path ++ " Verdict 0.0"),
              ?assertEqual(nomatch, string:find(Out, "0.0 will no longer")),
              ?assertEqual(nomatch, string:find(Out, "Warning")),
              ?assertEqual(":empty\nrc:0\n", Out)
      end).

%% A negative zero literal in a head is its own value under `=:=`.
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

%%% --- F51.4 — ticket 80: nothing flows ----------------------------------------

%% `Mean([]) -> 0` under `public float Mean` is refused by the diagnostic the
%% checker already had; the residual is the `0` the author wrote.
an_int_returned_where_a_float_is_declared_is_refused_test() ->
    Src = "module Bad\n\n"
          "public float Mean(list<int> samples)\n\n"
          "Mean([]) -> 0\n"
          "Mean(xs) -> Float.FromInt(List.Sum(xs)) / Float.FromInt(List.Length(xs))\n",
    [D | _] = errors(Src),
    ?assertMatch({return_not_declared, _, _}, element(4, D)),
    {return_not_declared, Residual, _} = element(4, D),
    ?assertEqual("0", bs_types:to_string(Residual)).

%% A `float` beside an `int` at an operator is refused, naming the conversion.
%% One `Float.FromInt` dropped from the ticket's program is the case.
a_mixed_pair_at_an_operator_is_refused_test() ->
    Src = "module Mixed\n\n"
          "public float Mean(list<int> samples)\n\n"
          "Mean([]) -> 0.0\n"
          "Mean(xs) -> Float.FromInt(List.Sum(xs)) / List.Length(xs)\n",
    [D | _] = errors(Src),
    ?assertEqual({mixed_operands, '/', float, int, none}, element(4, D)).

%% Every arithmetic and ordering operator, both ways round.
every_operator_refuses_the_mixed_pair_test() ->
    [begin
         Src = "module Mixed\n\n"
               "public term Go(int n, float f)\n\n"
               "Go(n, f) -> " ++ Left ++ " " ++ Op ++ " " ++ Right ++ "\n",
         [D | _] = errors(Src),
         ?assertMatch({mixed_operands, _, _, _, _}, element(4, D))
     end || Op <- ["+", "-", "*", "/", "<", "<=", ">", ">=", "==", "!="],
            {Left, Right} <- [{"n", "f"}, {"f", "n"}, {"f", "1"}, {"1.5", "n"}]].

%% The prose names the conversion, and names the literal spelling where the
%% `int` side is a literal, since `Mean(xs) / 1.0` was the smuggling ticket
%% 81 refused.
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

%% CONTROL — the same operators over two floats, and over two ints, compile.
%% A rule that refused every operator with a float in it passes the two
%% tests above and is wrong.
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

%% An operand already refused is `none`, which is inside both parts; the
%% mixed-pair rule needs both operands INHABITED or a second error cascades
%% onto every already-refused operand.
an_already_refused_operand_reports_once_test() ->
    Src = "module Once\n\n"
          "public float Go(float f)\n\n"
          "Go(f) -> f + nope\n",
    Ds = errors(Src),
    ?assertEqual(1, length(Ds)),
    ?assertNotMatch({mixed_operands, _, _, _, _}, element(4, hd(Ds))).

%% Comparison across the two parts is refused as arithmetic is: `==` means
%% `=:=` (16), so `0 == 0.0` would be a comparison that is always false.
a_float_compared_with_an_int_literal_in_a_guard_is_refused_test() ->
    Src = "module Guarded\n\n"
          "public atom Sign(float x)\n\n"
          "Sign(x) when x < 0 -> :negative\n"
          "Sign(_)            -> :other\n",
    [D | _] = errors(Src),
    ?assertEqual({mixed_operands, '<', float, int, "0.0"}, element(4, D)).

%% A float guard against a float literal compiles and selects. It credits
%% nothing to exhaustiveness — the algebra carries no float intervals — so a
%% clause set over a float parameter closes with a catch-all, as over `atom`.
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

%%% --- F51.5 — ticket 81: the entry under the reserved `Float` -----------------

%% `Float.FromInt` is inlined: the beam's import table names no `Float`
%% module, as F32's gate asserts for `List`.
float_from_int_is_inlined_test() ->
    Root = bs_test_support:fixture_root(),
    Path = bs_test_support:place(Root, "Stats.bs", stats()),
    Out = run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Path),
    ?assertNotEqual(nomatch, string:find(Out, "rc:0")),
    {ok, {'Stats', [{imports, Imports}]}} =
        beam_lib:chunks(Root ++ "/out/Stats.beam", [imports]),
    ?assertEqual([], [I || {'Float', _, _} = I <- Imports]),
    ?assertNotEqual([], [I || {erlang, float, 1} = I <- Imports]).

%% The signature is `int -> float`: a `float` argument is refused, since
%% `Int.FromFloat` is deferred and a conversion that accepted its own result
%% would hide the missing one.
float_from_int_refuses_a_float_test() ->
    Src = "module Conv\n\n"
          "public float Twice(float x)\n\n"
          "Twice(x) -> Float.FromInt(x) * 2.0\n",
    [D | _] = errors(Src),
    ?assertEqual(arg_not_accepted, element(1, element(4, D))).

%% The name the survey rejected is unknown under the qualifier, and says so.
float_of_is_not_an_operation_test() ->
    Src = "module Conv\n\n"
          "public float Go(int n)\n\n"
          "Go(n) -> Float.Of(n)\n",
    [D | _] = errors(Src),
    ?assertMatch({unknown_reserved_operation, 'Float', 'Of', 1, []}, element(4, D)).

%% A user module named `Float` is refused as `module List` is (67 clause 2).
a_module_named_float_is_refused_test() ->
    Root = bs_test_support:fixture_root(),
    Src = "module Float\n\n"
          "public int Go(int n)\n\n"
          "Go(n) -> n\n",
    %% The reserved-name refusal runs before the path check (F32), so the
    %% file's directory does not have to be called `Float`.
    Path = bs_test_support:place(Root, "Float.bs", Src),
    Out = run_cli("--src-root " ++ Root ++ " " ++ Path ++ " Go 1"),
    ?assertNotEqual(nomatch, string:find(Out, "rc:1")),
    ?assertNotEqual(nomatch, string:find(Out, "reserved")).

%%% --- F51.6 — the part in the algebra ---------------------------------------

%% `term` contains the float again, so a float passes where `term` is declared
%% and is refused where `float` is declared from `term`: the top holds every
%% part, or every residual subtracted from it is wrong in the quiet direction.
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

%% `int | float` is discriminable: a literal head or `is_float/1` tells the
%% two apart, so the union is accepted as a parameter (09 §4) and a clause
%% set over it is checked.
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

%% A float literal alone leaves the rest of the part, which prints as the set
%% it is and, like `atom \ :ok`, has no head to paste.
a_float_literal_alone_is_not_exhaustive_test() ->
    Src = "module Only\n\n"
          "public atom Verdict(float mean)\n\n"
          "Verdict(0.0) -> :empty\n",
    [D | _] = errors(Src),
    ?assertEqual(inexhaustive, element(1, element(4, D))),
    %% The residual is the clause product, one component here.
    Residual = element(2, element(4, D)),
    ?assertEqual("(float \\ (0.0))", bs_types:to_string(Residual)).

%% The type prints as its name on every channel a signature reaches.
float_prints_as_float_test() ->
    bs_test_support:with_src(
      "Stats.bs", stats(),
      fun(Path, _Root) ->
              Out = run_cli("--api " ++ Path),
              ?assertNotEqual(nomatch, string:find(Out, "float"))
      end).

%% A `list<float>` and a tuple carrying a float: the part composes as every
%% other part does.
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

%%% --- F51.7 — the boundary -------------------------------------------------------

%% A public `float` parameter is guarded by `is_float/1`, so an `int` from
%% outside goes the way F24 sends an atom: `function_clause`, never a value.
a_public_float_parameter_is_guarded_test() ->
    Src = "module Bound\n\n"
          "public float Twice(float x)\n\n"
          "Twice(x) -> x * 2.0\n",
    M = build_and_load(Src, 'Bound'),
    ?assertEqual(3.0, M:'Twice'(1.5)),
    ?assertError(function_clause, M:'Twice'(1)),
    ?assertError(function_clause, M:'Twice'(one)).

%% The other direction still holds: F24's `is_integer` refuses a float at an
%% `int` parameter, which is where ticket 69 started.
a_float_still_does_not_reach_an_int_parameter_test() ->
    Src = "module Bump\n\n"
          "public int Bump(int n)\n\n"
          "Bump(n) -> n + 1\n",
    M = build_and_load(Src, 'Bump'),
    ?assertEqual(2, M:'Bump'(1)),
    ?assertError(function_clause, M:'Bump'(1.5)).

%% A float literal in the head pins the kind, so no test is added there.
a_float_literal_head_needs_no_kind_test_test() ->
    Src = "module Pinned\n\n"
          "public atom Is(float x)\n\n"
          "Is(1.5) -> :yes\n"
          "Is(_)   -> :no\n",
    M = build_and_load(Src, 'Pinned'),
    ?assertEqual(yes, M:'Is'(1.5)),
    ?assertEqual(no, M:'Is'(2.5)),
    ?assertError(function_clause, M:'Is'(1)).

%% The spec publishes `float()`, read back off the beam's abstract code.
the_spec_publishes_float_test() ->
    Root = bs_test_support:fixture_root(),
    Path = bs_test_support:place(Root, "Stats.bs", stats()),
    _ = run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Path),
    {ok, {'Stats', [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(Root ++ "/out/Stats.beam", [abstract_code]),
    Specs = [S || {attribute, _, spec, {{'Mean', 1}, S}} <- Forms],
    ?assertMatch([[{type, _, 'fun', [_, {type, _, float, []}]}]], Specs).

%% A foreign return declared `float` is guarded by `is_float/1`, one guard
%% (18 §2): the truthful declaration passes and the lying one crashes at the
%% call, never silently.
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

%%% --- F51.8 — the obligations ------------------------------------------------

%% `ValidateAs<float>` accepts a float and refuses an int, naming the type;
%% `ToJson<float>` writes ticket 77's number.
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

%%% --- F51.9 — the divisor rule reaches the new part ---------------------------

%% 38 §2 over floats: a divisor the compiler proves is zero is refused, and
%% one that might be is not.
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

%%% --- F51.10 — a switch arm ----------------------------------------------------

%% A float literal arm, and the same catch-all obligation a clause set has.
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
