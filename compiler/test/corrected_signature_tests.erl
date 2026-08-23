-module(corrected_signature_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [with_src/3, run_cli/1]).

%%% ---------------------------------------------------------------------------
%%% F25 — the return-mismatch diagnostic carries the signature to paste.
%%%
%%% Ticket 23 §8: "when a clause returns outside its signature, the diagnostic
%%% carries the corrected signature to paste." §2's line is that the compiler
%%% synthesises the head and never the body, and §4's membership test for the
%%% contractual subset is the same question: does it hand the agent something to
%%% write? Before this feature `return_not_declared` printed the uncovered
%%% residual and stopped, which answers what is WRONG and not what to WRITE.
%%%
%%% THE THREE TESTS THAT SHAPED THE FEATURE ARE 3, 4 AND 5, NOT 1. Test 1 is the
%%% happy path and a fix that only satisfies it is the plausible-but-wrong one:
%%% it prints a line per offending clause (test 3 fails), and it prints a mint
%%% tag for a record (test 4 fails) which is a line that LOOKS pasteable and is
%%% not.
%%% ---------------------------------------------------------------------------

-define(HEADING, "the signature its clauses justify:").

%% Two things this helper got wrong the first time, both of which made every
%% assertion below fail for the same uninformative reason — no output at all.
%% `place/3`'s second argument is the FILE NAME, so it needs the `.bs` extension
%% or nothing is a source file; and it answers the file it wrote, while F15 made
%% the DIRECTORY the unit of compilation, so what `bsc` is given is its dirname.
cli(Name, Src) ->
    with_src(Name ++ ".bs", Src,
             fun(Path, Root) ->
                     run_cli("--src-root " ++ Root ++ " " ++ filename:dirname(Path))
             end).

%%% ---------------------------------------------------------------------------
%%% 1 — the baseline
%%% ---------------------------------------------------------------------------

%% F25.1 — the line exists, and it is a whole signature rather than a type.
%% Pasting it over the declared line is the entire point, so the assertion is on
%% the line and not on the fragment: a fix that printed only `:oops | int` would
%% pass a substring check on the type and still leave the agent to assemble a
%% signature, which is the work §2 says the compiler owns.
a_return_mismatch_carries_the_signature_to_paste_test() ->
    Src = "module M1\npublic int Answer(int n)\nAnswer(n) -> :oops\n",
    Out = cli("M1", Src),
    ?assert(string:find(Out, ?HEADING) =/= nomatch),
    ?assert(string:find(Out, "public int | :oops Answer(int n)") =/= nomatch).

%% F25.2 — today's message is not replaced. The residual answers "what is not
%% covered" and the new line answers "what to write"; they are different
%% questions and the first one is what ticket 04 made the product surface.
the_uncovered_residual_survives_beside_it_test() ->
    Src = "module M2\npublic int Answer(int n)\nAnswer(n) -> :oops\n",
    Out = cli("M2", Src),
    ?assert(string:find(Out, "not covered by the declared return type:") =/= nomatch).

%%% ---------------------------------------------------------------------------
%%% 3 — the correction is a property of the FUNCTION
%%% ---------------------------------------------------------------------------

%% F25.3 — MEASURED FIRST: two offending clauses produce two diagnostics. If each
%% carried its own correction the compiler would print two contradictory
%% pasteable lines — `int | :zero` and `int | (:error, string)` — and pasting
%% either leaves the other clause still wrong. One line, from the union of every
%% residual, attached to both diagnostics.
two_offending_clauses_get_one_function_wide_signature_test() ->
    Src = "module M3\npublic int Go(int n)\n"
          "Go(0) -> :zero\n"
          "Go(n) -> (:error, \"bad\")\n",
    Out = cli("M3", Src),
    Line = "public int | :zero | (:error, string) Go(int n)",
    ?assertEqual(2, count_occurrences(Out, ?HEADING)),
    ?assertEqual(2, count_occurrences(Out, Line)).

%%% ---------------------------------------------------------------------------
%%% 4 — the refusal, and it is the half a gate written after the code would miss
%%% ---------------------------------------------------------------------------

%% F25.4 — a record in the RESIDUAL has no writable spelling. `bs_types` renders
%% it as `{ Kind: :'M4.Invoice', Id: int, Total: int }`, which is a correct
%% description of the set and a bad thing to paste: ticket 26 §1 mints that tag
%% from the qualified module path, so pasting it hard-codes a mint instead of
%% naming `Invoice`. No signature is printed, and the ordinary message stands.
%%
%% THE TAG IS EXPECTED IN THE OUTPUT AND FORBIDDEN IN THE SIGNATURE, and the
%% first draft of this test asserted it was absent altogether — which forbids the
%% correct behaviour. The residual prints `{ Kind: :'M4.Invoice' }` on purpose:
%% ticket 04 made the residual the missing case and `to_pattern/1` renders the
%% discriminator deliberately. What F25 refuses is the pasteable line, so that is
%% what is asserted, and the residual is asserted PRESENT so the refusal is known
%% to have dropped one line rather than the whole diagnostic.
a_record_in_the_residual_prints_no_signature_test() ->
    Src = "module M4\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Invoice{ Id = n, Total = 0 }\n",
    Out = cli("M4", Src),
    ?assert(string:find(Out, "returns a value its signature does not declare") =/= nomatch),
    ?assert(string:find(Out, "Kind: :'M4.Invoice'") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)).

%% F25.5 — the mirror, and it is why the declared half is read from the SOURCE
%% AST rather than from the algebra. Here the record is the DECLARED type and the
%% residual is an atom: through the algebra the declared half would render as its
%% mint tag and this case would be refused too, which would be a refusal with no
%% cause. From source it is `Order`, and `Order | :oops` is exactly what the
%% author should paste.
a_declared_record_is_named_not_minted_test() ->
    Src = "module M5\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> :oops\n",
    Out = cli("M5", Src),
    ?assert(string:find(Out, "public Order | :oops Make(int n)") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "Kind:")).

%%% ---------------------------------------------------------------------------
%%% 6 — visibility
%%% ---------------------------------------------------------------------------

%% F25.6 — F12 made an unmarked signature private, so `public` is written exactly
%% where it is meant. A synthesised line that exported a private function would
%% be a worse defect than the one it fixes.
a_private_function_is_not_exported_by_the_pasted_line_test() ->
    Src = "module M6\n"
          "public int Entry(int n)\n"
          "Entry(n) -> Helper(n)\n"
          "int Helper(int n)\n"
          "Helper(n) -> :oops\n",
    Out = cli("M6", Src),
    ?assert(string:find(Out, "int | :oops Helper(int n)") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "public int | :oops Helper")).

%%% ---------------------------------------------------------------------------
%%% 7 — the contractual subset
%%% ---------------------------------------------------------------------------

%% F25.7 — ticket 23 §4's membership test is §2's: does it hand the agent
%% something to write? It does now, so the tag joins the frozen subset. This is
%% the assertion that would fail if the descriptor were changed without the
%% promise being made.
return_not_declared_is_contractual_test() ->
    ?assert(lists:member(return_not_declared, bs_diag:contractual())).

%% F25.8 — the term channel carries it too, and as its own key. §1 makes the term
%% canonical and the prose a pure function of it, so a corrected signature that
%% existed only in the prose would be the wrong way round.
the_term_carries_the_corrected_signature_test() ->
    D = bs_diag:descriptor("m.bs", {error, 3, 'Answer',
                                    {return_not_declared,
                                     bs_types:atom_lit(oops),
                                     "public int | :oops Answer(int n)"}}),
    ?assertMatch(#{tag := return_not_declared,
                   corrected := "public int | :oops Answer(int n)"}, D).

%% F25.9 — and `none` when there is nothing writable to say, rather than the key
%% going missing. A consumer matching on the key must not have to distinguish
%% "absent" from "refused".
the_term_says_none_when_the_signature_is_refused_test() ->
    D = bs_diag:descriptor("m.bs", {error, 3, 'Make',
                                    {return_not_declared,
                                     bs_types:atom_lit(oops),
                                     none}}),
    ?assertMatch(#{tag := return_not_declared, corrected := none}, D).

%%% ---------------------------------------------------------------------------

count_occurrences(Hay, Needle) ->
    count_occurrences(Hay, Needle, 0).

count_occurrences(Hay, Needle, N) ->
    case string:find(Hay, Needle) of
        nomatch -> N;
        Rest    -> Skip = string:slice(Rest, string:length(Needle)),
                   count_occurrences(Skip, Needle, N + 1)
    end.
