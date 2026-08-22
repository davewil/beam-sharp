-module(corpus_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [project_root/0]).

%%% ---------------------------------------------------------------------------
%%% Every shipped surface form is demonstrated by a program that runs
%%%
%%% Asked for on 2026-08-14, after F6, by David: *"are there actual example bs
%%% files showing all the language capabilities as they are built?"* Measured,
%%% and the answer was no — record CONSTRUCTION, destructuring binds, `bool` and
%%% a user-declared parametric alias had all shipped with tests and no example.
%%% Construction is the sharpest of those: `shop.bs` demonstrated every record
%%% operation except building one.
%%%
%%% WHAT THIS CHECKS, AND WHAT IT DOES NOT
%%% It checks the CORPUS, not the compiler. Paired with
%%% `every_example_still_compiles_test` above it means: every surface form below
%%% appears in a file that compiles and runs. It cannot check a capability whose
%%% whole behaviour is a REJECTION — every example must compile, so the call-site
%%% check, the projection error and exact field sets are covered by tests up
%%% there and can never be covered down here. That split is the reason the
%%% language has three gated surfaces rather than one: examples must run,
%%% LANGUAGE.md's blocks must compile (or must not, if tagged `not-yet`), and the
%%% suite carries what only a rejection can show.
%%%
%%% THE LIST IS HAND-MAINTAINED, DELIBERATELY
%%% There is no way to derive it: a capability is a sentence about the language
%%% and a probe is a token, and only a person can say which token demonstrates
%%% which sentence. The cost is one row per feature; the point is that the row
%%% has to be written, so a capability cannot ship with nothing to look at.
%%% ---------------------------------------------------------------------------

%% {what it demonstrates, a regex that finds it}. Anchored on distinctive
%% tokens, so a probe fails loudly rather than matching something adjacent.
demonstrated_surface() ->
    [{"a module declaration",                    "^module "},
     {"a type alias",                            "^type [A-Z]"},
     {"a union in a type",                       "^type .*\\|"},
     {"a user-declared parametric alias",        "^type [A-Z][A-Za-z]*<"},
     {"a parametric type applied",               "<int"},
     {"a record declaration",                    "^record "},
     %% A declaration has a space before its brace (`record Order   { Id`) and a
     %% construction does not (`Order{ Id = ...`), which is what tells them apart.
     {"record construction",                     "[A-Za-z]\\{"},
     {"a width-preserving update",               " with \\{"},
     {"a field projection",                      "\\.[A-Z]"},
     {"a tag or property pattern",               "\\{ [A-Z][A-Za-z]*:"},
     {"a guard",                                 " when "},
     %% Ticket 44 renamed the conjunction from `&&` to `and`, and this probe is
     %% where the rename first showed up as a red gate rather than as a diff: the
     %% old regex was one glyph that could not appear in any other construct, and
     %% the new spelling is a word. So it is anchored on `when` — the guard is the
     %% position the row is a sentence about, and a bare " and " would also match
     %% the pattern combinator two rows down, which is a different capability.
     {"a conjunction in a guard",                "when .* and "},
     {"an empty-list pattern",                   "\\[\\]"},
     {"a list pattern with a rest",              "\\[[a-z]+, \\.\\."},
     {"a local binding",                         "^ +var [a-z]"},
     {"a destructuring bind",                    "^ +var \\([a-z]"},
     %% F8 / ticket 45. Anchored on a BRACKET or COMMA before the `==`, so it
     %% probes the pattern position rather than an ordinary comparison —
     %% pinned below, because `n == m` matching this would be a silent pass.
     {"a match against a bound value",           "[\\[(,] *== [a-z]"},
     %% F11. A dotted `module` line is a different capability from `^module `
     %% above: that one is satisfied by any module at all, and the thing worth
     %% being able to look at here is the NESTED path that ticket 40 §1 forces.
     {"a dotted module path",                    "^module [A-Z][A-Za-z]*\\."},
     %% Anchored on a capital after `using` so it cannot be satisfied by the
     %% foreign form two rows down, which is the same keyword and a different
     %% construct.
     {"a native module import",                  "^using [A-Z]"},
     {"a qualified call",                        "[A-Z][A-Za-z]*\\.[A-Z][A-Za-z]*\\("},
     {"a foreign module declaration",            "^using :"},
     {"a foreign call",                          ":[a-z]+\\.[a-z_]+\\("},
     %% F19 / ticket 15 §4. The wrapper itself has NO surface — that is its whole
     %% design — so the sentence this row asks about is the DECLARATION that
     %% obliges it, which is the only thing an author writes and the only thing
     %% there is to look at. Anchored on the indent and the lowercase Erlang
     %% name, so it probes a `using :mod {` block and cannot be satisfied by the
     %% `public result<…> Parse` signature two lines further down: those are two
     %% different sentences, and only the first one emits anything.
     {"a foreign declaration whose THROW is turned into a value",
      "^ +result<[a-z]+, foreign_error> [a-z]"},
     %% F23 / ticket 56, and it is a SEPARATE sentence from the row above even
     %% though neither adds a token to the grammar. The row above declares a
     %% function that throws and asks the compiler to catch it; this one declares
     %% a function that never throws and whose error is already an ordinary
     %% value — `file:read_file/1`, and most of OTP's IO surface with it. The
     %% capability is that the second shape is DECLARABLE AT ALL, which it was
     %% not before ticket 56, so it owes an example even though the surface it
     %% adds is nothing.
     %%
     %% Anchored on the call rather than the declaration: the declaration is an
     %% ordinary alias applied in an ordinary `using` block, with no token that
     %% distinguishes it from any other foreign signature — which is the point of
     %% the resolution and also why there is nothing else here to anchor on.
     {"a foreign call whose error arrives as a value, unwrapped",
      ":file\\.read_file\\("},
     {"an OTP behaviour",                        "^behaviour "},
     %% F10. The attribute alone was already demonstrated; a CALLBACK is a second
     %% sentence, because the behaviour line means nothing until the contract it
     %% names is actually satisfied — which is exactly the state that kept
     %% `spec-check.sh` red.
     {"an OTP callback",                         "^HandleCast\\("},
     %% F12 moved this probe's anchor rather than its meaning. Every signature
     %% now opens with a visibility marker, so `^bool ` matched nothing — and it
     %% had exactly ONE match in the corpus, which is how a mechanical rewrite
     %% can silently empty a probe that is still asking the right question.
     {"bool as a declared type",                 "^(public|private) bool "},
     %% F12 / ticket 40 §3. Two rows, because they are two sentences: that a
     %% function can be exported and that one can be withheld. The second is the
     %% one worth gating — a corpus marked `public` throughout would pass every
     %% other gate in this repo and demonstrate nothing.
     {"a public function",                       "^public "},
     {"a private function",                      "^private "},
     {"an atom literal",                         ":[a-z]"},
     %% F7. Four rows, because a switch, a tuple subject, a guarded arm and the
     %% keyword atoms are four sentences about the language and not one — and the
     %% last is here because it was `LANGUAGE.md`'s prose that claimed it shipped
     %% while nothing demonstrated it, which is precisely the rot this gate is
     %% for.
     {"a switch expression",                     " switch \\{"},
     {"a tuple subject in a switch",             "\\) switch \\{"},
     {"a guard on a switch arm",                 "when [^=]+ =>"},
     {"the keyword atoms true and false",        "[^:A-Za-z](true|false)[,)]"},
     %% F9. Three rows, because the literal, the refinement and its base are
     %% three sentences. `string` and `binary` are separated deliberately: a file
     %% using only `string` would demonstrate the refinement and leave the type
     %% it refines with nothing to look at, which is the shape F3 shipped with
     %% when `shop.bs` showed every record operation except building one.
     %% F2. Four rows, because a refinement, a span, a combined span and a span
     %% in an arm are four sentences about the language. The last is here because
     %% `queue.bs` says in a comment that a relational pattern is F2's and a guard
     %% is how a switch asks a numeric question "today" — so an arm that does it
     %% the new way is the thing that makes that comment stop being true.
     {"a refined type declaration",              "^type .* where value"},
     %% Anchored on the BRACKET, which is what puts the operator in pattern
     %% position: `Classify(>= 4)` matches and `when n >= 4` must not. Pinned
     %% below, because a probe that could not tell those apart would report a
     %% capability demonstrated that nobody can look at — F8's lesson, and the
     %% same shape as the `==` probe above.
     {"an interval pattern",                     "\\( *[<>]=? -?[0-9]"},
     {"a combined interval pattern",             "\\( *[<>]=? -?[0-9]+ and "},
     {"an interval pattern in a switch arm",     "^ +[<>]=? -?[0-9]+.*=>"},
     {"a string literal",                        "\"[^\"]*\""},
     {"string as a declared type",               "(^|[<( ])string[ >)]"},
     {"binary as a declared type",               "(^|[<( ])binary[ >)]"},
     %% F14. Two rows, because the pipe and the valve are two sentences: one
     %% rewrites a call, the other stops a chain. Neither can stand in for the
     %% other — a corpus that piped everywhere and never used a valve would leave
     %% the short-circuit with nothing to look at.
     %%
     %% ANCHORED ON WHAT FOLLOWS THE OPERATOR, not on the operator alone. Comments
     %% are stripped before the probe runs, so prose cannot satisfy it — but
     %% `pipeline.bs` is a file ABOUT these operators, and a bare `\|>` would be
     %% one editing accident away from being satisfied by a line that only
     %% mentions one. Requiring the callee's capital means the probe asks the
     %% question it is a sentence about: is anything actually piped into a call.
     %% Pinned below, both ways.
     {"a pipe into a call",                      "\\|> [A-Z]"},
     {"a valve into a call",                     "\\|\\?> [A-Z]"},
     %% F18. Two rows, because they are two sentences: that a type argument can
     %% be handed to a codegen obligation, and that the failure it answers with
     %% has a NAME a signature can be written against. The second is the one
     %% that would rot quietly — a corpus could call `ValidateAs<T>` and throw
     %% the result away, leaving `ValidationError` with nothing to look at even
     %% though every program that uses the first must spell the second.
     %%
     %% The instantiation probe needs no pin. It is anchored on a compiler-known
     %% name immediately followed by `<`, and ticket 28 made that sequence
     %% unambiguous in the grammar itself: nothing else in the language can
     %% produce it, so there is no near-miss for it to drift into.
     {"a codegen obligation instantiated",       "ValidateAs<"},
     {"ValidationError as a declared type",      "ValidationError>"},
     %% F13 / ticket 30. FIVE rows, because they are five sentences about the
     %% language and no one of them stands in for another. A corpus could open a
     %% binary pattern and never size a segment by a field, or never write a
     %% sub-byte width — and the sub-byte case is the one this whole answer goes
     %% past every surveyed language to support, so it is precisely the row that
     %% must not be satisfiable by accident.
     %%
     %% `<<` alone is enough for the first: nothing else in the language produces
     %% two adjacent `<`, which is the same argument that let the LEXER take the
     %% token. The generic bracket is always preceded by a name.
     {"a binary pattern",                        "<<"},
     %% Anchored on a width of 5..9 or 12..99, which excludes every single-digit
     %% width below 5 — so this row cannot be satisfied by the sub-byte row's
     %% `op:4` and vice versa. Two sentences, two disjoint probes.
     {"a byte-or-wider segment width",           ":([5-9]|[1-9][0-9]+)[,>]"},
     {"a sub-byte segment width",                ":[1-4][,>]"},
     %% A segment sized by a name rather than a number, which is ticket 30 §1 —
     %% the form every length-prefixed format needs and the one no language
     %% types.
     %%
     %% ANCHORED ON THE LOWERCASE LETTER BEFORE THE COLON, and the first draft
     %% was not: `:[a-z]+,` matched `(:error, :unknown)` and the pin below caught
     %% it immediately. That near-miss is not a coincidence — `payload:size` and
     %% `:size` are the same two characters, the LEXER cannot tell them apart
     %% either (see the `bin_size` productions), and a size is distinguished
     %% only by having a name immediately to its left. The probe has to make the
     %% same distinction the grammar does.
     {"a segment sized by an earlier field",     "[a-z]:[a-z][a-z]*[,>]"},
     %% Anchored on the BRACKET, so it probes pattern position: `Method("GET")`
     %% matches and a string in an expression must not. Same shape as the `==`
     %% and interval probes, and pinned below for the same reason.
     {"a string literal in a pattern",           "\\( *\"[^\"]*\" *\\)"},
     %% The PREFIX match — a string literal as a SEGMENT rather than as a whole
     %% pattern. Two sentences, not one: `Method("GET")` needs the whole string
     %% and `Request(<<"GET ", rest>>)` needs it to start with one and binds the
     %% remainder. This production fell out of the segment grammar rather than
     %% being designed, and a form that works by accident is one nobody notices
     %% breaking — which is the whole argument for giving it a row.
     {"a string literal as a segment",           "<<\"[^\"]*\","},
     %% Hex, which F13 owed and ticket 30's table did not name.
     {"a hex integer literal",                   "0[xX][0-9a-fA-F]"}].

every_shipped_surface_form_has_an_example_test() ->
    Dir = project_root() ++ "/examples",
    %% RECURSIVE, because F11's example is a pair of files in a subdirectory —
    %% a multi-module capability cannot be demonstrated by one file, so the
    %% corpus has to be able to hold a directory. Listing only the top level
    %% would have silently ignored it and reported the module system as
    %% undemonstrated.
    %% `exemplars/` is excluded, and it matters more here than anywhere: those
    %% files are written in the dialect the compiler CANNOT yet parse, so letting
    %% them into this corpus would let an unbuilt form satisfy a probe and report
    %% a capability as demonstrated that nobody can run. The gate would go quiet
    %% in exactly the direction it exists to prevent.
    Names = [string:prefix(P, Dir ++ "/")
             || P <- filelib:wildcard(Dir ++ "/**/*.bs") ++
                     filelib:wildcard(Dir ++ "/*.bs"),
                string:find(P, "/exemplars/") =:= nomatch],
    Corpus =
        [begin
             {ok, Bin} = file:read_file(filename:join(Dir, N)),
             %% Comments are stripped, so a form mentioned in prose does not
             %% count as demonstrated. Several of these files DISCUSS what they
             %% do not do.
             Lines = [L || L <- string:split(binary_to_list(Bin), "\n", all),
                           not lists:prefix("//", string:trim(L, leading))],
             string:join(Lines, "\n")
         end || N <- lists:usort(Names), filename:extension(N) =:= ".bs"],
    Text = string:join(Corpus, "\n"),
    Missing = [What || {What, Re} <- demonstrated_surface(),
                       re:run(Text, Re, [multiline, {capture, none}]) =:= nomatch],
    %% Named rather than counted: the failure has to say which capability nobody
    %% can look at, or it is a puzzle rather than a diagnostic.
    ?assertEqual([], Missing).

%% ...and the mirror, which is the half that rots silently. A probe matching
%% nothing would be caught above; a probe that no longer means what it says
%% would not, so the two most delicate ones are pinned against text that must
%% NOT match them.
the_construction_probe_does_not_match_a_declaration_test() ->
    ?assertEqual(nomatch,
                 re:run("record Order   { Id: int }", "[A-Za-z]\\{",
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("New(id) -> Order{ Id = id }", "[A-Za-z]\\{",
                        [multiline, {capture, none}])).

%% The third delicate probe, added with F8. `==` means exact equality in
%% EXPRESSION position too (ticket 16 fixed it as `=:=`), so the surface probe
%% for the pattern form could drift into matching an ordinary comparison and
%% report a capability demonstrated that nobody can look at.
%%
%% That is not hypothetical here: this whole feature exists because a bare name
%% in a pattern and a bare name in an expression LOOK the same and mean different
%% things. A probe that cannot tell them apart would repeat the confusion it is
%% meant to police.
%% The fourth delicate probe, added with F2 and for the identical reason. Ticket
%% 42 chose a spelling that is deliberately the SAME GLYPHS a guard uses — `>= 4`
%% in a head is the construct, `n >= 4` in a guard is the comparison — because
%% one conjunction and one relational family in every position is the whole of
%% ticket 44's argument. That makes the two forms one character apart in a regex,
%% so the probe is pinned against the guard it must not claim.
the_interval_probe_does_not_match_a_guard_test() ->
    Re = "\\( *[<>]=? -?[0-9]",
    ?assertEqual(nomatch,
                 re:run("Classify(n) when n >= 4 -> :high", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Classify(>= 4 and <= 7) -> :reserved", Re,
                        [multiline, {capture, none}])),
    %% A negative bound is the residual's own spelling for the lower half of
    %% `int`, so it has to be probeable too.
    ?assertEqual(match,
                 re:run("Classify(<= -1) -> :negative", Re,
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

%% F14's two probes, pinned in both directions. The operators share a first
%% character and differ by one glyph in the middle, which is exactly the shape
%% that makes one probe quietly answer for both — and the corpus would still be
%% green with the valve deleted.
the_pipe_probe_does_not_match_a_valve_test() ->
    {_, Pipe} = lists:keyfind("a pipe into a call", 1, demonstrated_surface()),
    ?assertEqual(nomatch,
                 re:run("Place(n) -> Start(n) |?> Charge()", Pipe,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Restated(n) -> [n] |> List.Sum(0)", Pipe,
                        [multiline, {capture, none}])),
    %% And the union bar, which is the other `|` in this language and appears in
    %% every second type declaration.
    ?assertEqual(nomatch,
                 re:run("type Res = int | (:error, atom)", Pipe,
                        [multiline, {capture, none}])).

the_valve_probe_does_not_match_a_pipe_test() ->
    {_, Valve} = lists:keyfind("a valve into a call", 1, demonstrated_surface()),
    ?assertEqual(nomatch,
                 re:run("Restated(n) -> [n] |> List.Sum(0)", Valve,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Place(n) -> Start(n) |?> Charge()", Valve,
                        [multiline, {capture, none}])).

%%% F13. The two segment-width probes divide the same syntax between them, so
%%% each has to be pinned against the OTHER's example — a pair of probes that
%%% both match everything would report two capabilities demonstrated and prove
%%% one. The sub-byte row is the one that matters: it is the case ticket 30's
%%% answer goes past every surveyed language to support, so it must not be
%%% satisfiable by an ordinary `t:8`.
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

%% A string in PATTERN position, not in an expression. Without this pin the row
%% would be satisfied by every `-> "hello"` in the corpus, which is the F8 and F2
%% failure a third time: a probe reporting a capability nobody can look at.
the_string_pattern_probe_does_not_match_an_expression_test() ->
    {_, Re} = lists:keyfind("a string literal in a pattern", 1,
                            demonstrated_surface()),
    ?assertEqual(nomatch,
                 re:run("Greet() -> \"hello\"", Re, [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Method(\"GET\") -> :get", Re,
                        [multiline, {capture, none}])).

%% The segment-size probe must not be satisfied by an ordinary atom literal,
%% which is the same two characters in a different position — `:size` after a
%% name is a size and `:size` after a bracket is an atom, and the lexer cannot
%% tell them apart either (see the `bin_size` productions in the grammar).
the_segment_size_probe_does_not_match_an_atom_test() ->
    {_, Re} = lists:keyfind("a segment sized by an earlier field", 1,
                            demonstrated_surface()),
    ?assertEqual(nomatch,
                 re:run("Classify(t) -> (:error, :unknown)", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Decode(<<n:8, payload:n, rest>>) -> payload", Re,
                        [multiline, {capture, none}])).
