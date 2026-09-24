-module(corpus_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [project_root/0]).

%%% Example coverage

demonstrated_surface() ->
    [{"a module declaration",                    "^module "},
     {"a type alias",                            "^type [A-Z]"},
     {"a union in a type",                       "^type .*\\|"},
     {"a user-declared parametric alias",        "^type [A-Z][A-Za-z]*<"},
     {"a parametric type applied",               "<int"},
     {"a record declaration",                    "^record "},
     %% Declarations separate the name and brace; constructions join them.
     {"record construction",                     "[A-Za-z]\\{"},
     {"a width-preserving update",               " with \\{"},
     {"a field projection",                      "\\.[A-Z]"},
     {"a tag or property pattern",               "\\{ [A-Z][A-Za-z]*:"},
     {"a guard",                                 " when "},
     %% With comments stripped, the keyword and trailing space select a crash.
     {"a deliberate crash",                      "raise "},
     %% `when` excludes the pattern combinator with the same spelling.
     {"a conjunction in a guard",                "when .* and "},
     {"an empty-list pattern",                   "\\[\\]"},
     {"a list pattern with a rest",              "\\[[a-z]+, \\.\\."},
     {"a local binding",                         "^ +var [a-z]"},
     {"a destructuring bind",                    "^ +var \\([a-z]"},
     %% A bracket or comma puts `==` in pattern position.
     {"a match against a bound value",           "[\\[(,] *== [a-z]"},
     %% Any module satisfies the first probe; this one requires a nested path.
     {"a dotted module path",                    "^module [A-Z][A-Za-z]*\\."},
     %% A capital excludes foreign imports using the same keyword.
     {"a native module import",                  "^using [A-Z]"},
     {"a qualified call",                        "[A-Z][A-Za-z]*\\.[A-Z][A-Za-z]*\\("},
     %% Visibility and the parameter binder exclude qualified calls.
     {"a qualified type name in a signature",
      "^(public|private) .*\\([A-Z][A-Za-z]*\\.[A-Z][A-Za-z]* [a-z]"},
     %% The uppercase function name and following `(` exclude type arguments.
     {"a polymorphic signature",
      "^(public|private) .* [A-Z][A-Za-z]*<[A-Z][A-Za-z, ]*>\\("},
     %% A clause head starts at column one without a return type.
     {"a type prefix over a part",
      "^[A-Z][A-Za-z]*\\((int|float|atom|binary) [a-z]"},
     {"a foreign module declaration",            "^using :"},
     {"a foreign call",                          ":[a-z]+\\.[a-z_]+\\("},
     %% Indentation and the lowercase name select the foreign declaration
     %% that requests the wrapper, excluding native result signatures.
     {"a foreign declaration whose THROW is turned into a value",
      "^ +result<[a-z]+, foreign_error> [a-z]"},
     %% The declaration has no distinctive syntax; the call identifies
     %% a foreign function whose error is already a value.
     {"a foreign call whose error arrives as a value, unwrapped",
      ":file\\.read_file\\("},
     {"an OTP behaviour",                        "^behaviour "},
     %% A behaviour attribute alone does not demonstrate a callback.
     {"an OTP callback",                         "^HandleCast\\("},
     {"bool as a declared type",                 "^(public|private) bool "},
     %% Public declarations alone do not demonstrate a withheld function.
     {"a public function",                       "^public "},
     {"a private function",                      "^private "},
     {"an atom literal",                         ":[a-z]"},
     %% A switch alone does not demonstrate tuple subjects or guarded arms.
     {"a switch expression",                     " switch \\{"},
     {"a tuple subject in a switch",             "\\) switch \\{"},
     {"a guard on a switch arm",                 "when [^=]+ =>"},
     {"the keyword atoms true and false",        "[^:A-Za-z](true|false)[,)]"},
     %% A refinement alone does not demonstrate intervals in switch arms.
     {"a refined type declaration",              "^type .* where value"},
     %% The opening bracket excludes relational operators in guards.
     {"an interval pattern",                     "\\( *[<>]=? -?[0-9]"},
     {"a combined interval pattern",             "\\( *[<>]=? -?[0-9]+ and "},
     {"an interval pattern in a switch arm",     "^ +[<>]=? -?[0-9]+.*=>"},
     %% String examples must not stand in for the binary base type.
     {"a string literal",                        "\"[^\"]*\""},
     {"string as a declared type",               "(^|[<( ])string[ >)]"},
     {"binary as a declared type",               "(^|[<( ])binary[ >)]"},
     %% Requiring a callee excludes standalone mentions of the operators.
     {"a pipe into a call",                      "\\|> [A-Z]"},
     {"a valve into a call",                     "\\|\\?> [A-Z]"},
     %% Calling ValidateAs alone does not demonstrate its named error type.
     {"a codegen obligation instantiated",       "ValidateAs<"},
     {"ValidationError as a declared type",      "ValidationError>"},
     %% ValidateAs alone cannot satisfy the separate ParseAtom probe.
     {"a string parsed into a named set",        "ParseAtom<"},
     %% The compiler reserves this name, so user functions cannot match.
     {"a string resolved to an atom the VM has", "ToExistingAtom\\("},
     %% A binary delimiter alone does not demonstrate sized segments.
     {"a binary pattern",                        "<<"},
     %% Disjoint width ranges keep the two example probes independent.
     {"a byte-or-wider segment width",           ":([5-9]|[1-9][0-9]+)[,>]"},
     {"a sub-byte segment width",                ":[1-4][,>]"},
     %% The name before the colon distinguishes a segment size from an atom.
     {"a segment sized by an earlier field",     "[a-z]:[a-z][a-z]*[,>]"},
     %% The brackets select a whole string pattern, excluding expressions.
     {"a string literal in a pattern",           "\\( *\"[^\"]*\" *\\)"},
     %% A prefix segment differs from a whole-string pattern.
     {"a string literal as a segment",           "<<\"[^\"]*\","},
     {"a hex integer literal",                   "0[xX][0-9a-fA-F]"},
     %% Digits around the dot exclude rest markers and qualified names.
     {"a float literal",                         "[0-9]\\.[0-9]"},
     %% A float literal does not demonstrate an explicit integer conversion.
     {"a conversion into a float",               "Float\\.FromInt\\("},
     %% The visibility marker excludes lambdas in bodies.
     {"an arrow type in a signature",            "^(public|private) .*fn\\("},
     %% The preceding clause arrow, comma or bracket excludes tuple arms.
     {"a lambda handed to a site",
      "(-> |, |\\()(\\([a-z_][a-z_, ()]*\\)|[a-z_]+) => "},
     %% A PascalCase name before the slash distinguishes arity from division.
     {"a name in value position with its arity written", "[A-Z][A-Za-z]*/[0-9]"},
     %% A lowercase callee excludes named functions; projections use a dot.
     {"a call through a bound name",             "-> [a-z][a-z_]*\\("}].

the_lambda_probe_does_not_match_a_tuple_arm_test() ->
    Re = "(-> |, |\\()(\\([a-z_][a-z_, ()]*\\)|[a-z_]+) => ",
    ?assertEqual(nomatch,
                 re:run("    (false, true, _)     => :dead_letter,", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Rule(:standard) -> (cents) => cents", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Owed(pairs) -> pairs |> List.Fold(0, (acc, (_, n)) => acc + n)", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Large(xs) -> xs |> List.Filter(n => n > 100)", Re,
                        [multiline, {capture, none}])).

every_shipped_surface_form_has_an_example_test() ->
    Dir = project_root() ++ "/examples",
    %% Module examples span subdirectories. Exemplars use syntax the compiler
    %% cannot parse and must not count as runnable demonstrations.
    Names = [string:prefix(P, Dir ++ "/")
             || P <- filelib:wildcard(Dir ++ "/**/*.bs") ++
                     filelib:wildcard(Dir ++ "/*.bs"),
                string:find(P, "/exemplars/") =:= nomatch],
    Corpus =
        [begin
             {ok, Bin} = file:read_file(filename:join(Dir, N)),
             %% Prose mentions do not demonstrate a construct.
             Lines = [L || L <- string:split(binary_to_list(Bin), "\n", all),
                           not lists:prefix("//", string:trim(L, leading))],
             string:join(Lines, "\n")
         end || N <- lists:usort(Names), filename:extension(N) =:= ".bs"],
    Text = string:join(Corpus, "\n"),
    Missing = [What || {What, Re} <- demonstrated_surface(),
                       re:run(Text, Re, [multiline, {capture, none}]) =:= nomatch],
    %% Keep names in the failure output so it identifies missing examples.
    ?assertEqual([], Missing).

the_construction_probe_does_not_match_a_declaration_test() ->
    ?assertEqual(nomatch,
                 re:run("record Order   { Id: int }", "[A-Za-z]\\{",
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("New(id) -> Order{ Id = id }", "[A-Za-z]\\{",
                        [multiline, {capture, none}])).

the_interval_probe_does_not_match_a_guard_test() ->
    Re = "\\( *[<>]=? -?[0-9]",
    ?assertEqual(nomatch,
                 re:run("Classify(n) when n >= 4 -> :high", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Classify(>= 4 and <= 7) -> :reserved", Re,
                        [multiline, {capture, none}])),
    %% Negative bounds are how residuals spell the lower half of `int`.
    ?assertEqual(match,
                 re:run("Classify(<= -1) -> :negative", Re,
                        [multiline, {capture, none}])).

the_part_prefix_probe_does_not_match_a_signature_test() ->
    Re = "^[A-Z][A-Za-z]*\\((int|float|atom|binary) [a-z]",
    ?assertEqual(nomatch,
                 re:run("public atom Verdict(float mean)", Re,
                        [multiline, {capture, none}])),
    %% The return type also separates an unmarked signature from a head.
    ?assertEqual(nomatch,
                 re:run("Side Post(int | float amount)", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Post(float f) -> :debit", Re,
                        [multiline, {capture, none}])).

the_match_probe_does_not_match_a_comparison_test() ->
    Re = "[\\[(,] *== [a-z]",
    ?assertEqual(nomatch,
                 re:run("Same(n, m) when n == m -> :yes", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Run(head, [== head, ..rest]) -> 1", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Pair(k, (== k, x)) -> x", Re,
                        [multiline, {capture, none}])).

the_pipe_probe_does_not_match_a_valve_test() ->
    {_, Pipe} = lists:keyfind("a pipe into a call", 1, demonstrated_surface()),
    ?assertEqual(nomatch,
                 re:run("Place(n) -> Start(n) |?> Charge()", Pipe,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Restated(n) -> [n] |> Ints.Sum(0)", Pipe,
                        [multiline, {capture, none}])),
    %% A union's bar must not count as a pipe.
    ?assertEqual(nomatch,
                 re:run("type Res = int | (:error, atom)", Pipe,
                        [multiline, {capture, none}])).

the_valve_probe_does_not_match_a_pipe_test() ->
    {_, Valve} = lists:keyfind("a valve into a call", 1, demonstrated_surface()),
    ?assertEqual(nomatch,
                 re:run("Restated(n) -> [n] |> Ints.Sum(0)", Valve,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Place(n) -> Start(n) |?> Charge()", Valve,
                        [multiline, {capture, none}])).

the_width_probes_divide_at_the_byte_test() ->
    {_, Wide} = lists:keyfind("a byte-or-wider segment width", 1,
                              demonstrated_surface()),
    {_, Sub}  = lists:keyfind("a sub-byte segment width", 1,
                              demonstrated_surface()),
    Byte = "Decode(<<t:8, rest>>) -> Classify(t)",
    Nyb  = "Opcode(<<_:4, op:4, rest>>) -> Name(op)",
    ?assertEqual(match,   re:run(Byte, Wide, [multiline, {capture, none}])),
    ?assertEqual(nomatch, re:run(Byte, Sub,  [multiline, {capture, none}])),
    ?assertEqual(match,   re:run(Nyb,  Sub,  [multiline, {capture, none}])),
    ?assertEqual(nomatch, re:run(Nyb,  Wide, [multiline, {capture, none}])).

the_string_pattern_probe_does_not_match_an_expression_test() ->
    {_, Re} = lists:keyfind("a string literal in a pattern", 1,
                            demonstrated_surface()),
    ?assertEqual(nomatch,
                 re:run("Greet() -> \"hello\"", Re, [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Method(\"GET\") -> :get", Re,
                        [multiline, {capture, none}])).

%% The name before `:size` distinguishes a segment size from an atom.
the_segment_size_probe_does_not_match_an_atom_test() ->
    {_, Re} = lists:keyfind("a segment sized by an earlier field", 1,
                            demonstrated_surface()),
    ?assertEqual(nomatch,
                 re:run("Classify(t) -> (:error, :unknown)", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Decode(<<n:8, payload:n, rest>>) -> payload", Re,
                        [multiline, {capture, none}])).
