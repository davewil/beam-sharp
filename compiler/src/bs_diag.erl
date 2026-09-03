%%% bs_diag — the diagnostic as a term, and prose as a pure function of it.
%%%
%%% F16, ticket 23 §1. Before this module every diagnostic was an `io:format`
%%% call in `bsc.erl`: 56 of them, and not one produced a value a consumer could
%%% read. The shapes were already terms internally — `{error, Line, Fn,
%%% {inexhaustive, Residual}}` — so the defect was never a missing model. It was
%%% that the model was destroyed at the boundary where the consumer stands,
%%% which is exactly what ticket 23 measured `erlc` doing: `compile:file/2`
%%% builds `{ErrorLocation, Module, ErrorDescriptor}` correctly and no flag on
%%% `erlc -h` recovers it.
%%%
%%% THE SPLIT, and it is OTP's own (tier 2): `descriptor/2` builds the term,
%%% `message/1` is the single owner of every format string, and prose is derived
%%% rather than written alongside. Nothing else in the compiler may print a
%%% diagnostic — `bin/check-diagnostics.sh` is the gate, and it exists because
%%% the drift this module closes reopens silently: a new report site calling
%%% `io:format` directly would pass every test, since the prose would be right.
%%%
%%% WHY `message/1` RETURNS `{Fmt, Args}` RATHER THAN THE TEXT. Several messages
%%% carry a literal em dash *inside the format string* (`ambiguous_call`,
%%% `import_cycle`). Today those reach the device through `io:format/3` with the
%%% codepoint in the format itself; re-rendering the finished text through `~s`
%%% is a `badarg` on a codepoint above 255, and through `~ts` it is a different
%%% encoding path from the one the corpus was measured on. So `emit/2` makes the
%%% identical call it always made, and `format/1` — the published pure function
%%% — is defined in terms of `message/1` rather than beside it. One owner, two
%%% renderings, no drift.
%%%
%%% THE DESCRIPTOR IS FULL FIDELITY AND THE PROSE IS LOSSY. This is not a choice
%%% made here; ticket 43 made it and wrote it down in the future tense — *"the
%%% descriptor keeps all forty-one and 23 §10's `bsc --api` is the full-fidelity
%%% channel"*. So `residual` and `heads` carry every case, and `message/1`
%%% applies 43's cap of ?RESIDUAL_CASES on the way out. That is why the residual
%%% travels as its *parts* rather than as finished text: prose cannot be a pure
%%% function of a term that has already been truncated.
%%%
%%% PAYLOADS ARE MAPS, NOT TUPLES (23 §4), because a map gains a key without
%%% breaking a matcher and a tuple cannot — so additive-only evolution is
%%% expressible in the data rather than promised in prose.
-module(bs_diag).

-export([descriptor/2, format/1, message/1, emit/2]).
-export([channel/0, set_channel/1, contractual/0]).

%% Ticket 43's threshold, and it must be the same number `bsc.erl` used before
%% this module existed — the truncated form IS the exact form at three cases or
%% fewer, so there is nothing to tune and no second shape to switch into.
-define(RESIDUAL_CASES, 3).

%%% ---------------------------------------------------------------------------
%%% The channel
%%%
%%% 23 §1 says only that "the CLI publishes both" and names no flag anywhere in
%%% the ticket. `--diagnostics term` is F16's assumption, recorded in the feature
%%% file: prose to stderr exactly as before, the descriptor to stdout, so a
%%% consumer redirects rather than parses.
%%%
%%% IT IS NOT AVAILABLE IN THE REPL, AND THAT IS A REFUSAL RATHER THAN A
%%% DOWNGRADE. `ibs` prints VALUES on stdout, so "stdout carries descriptors"
%%% cannot be true there — a consumer redirecting the stream would get a mix of
%%% the two. Silently falling back to prose would be worse than either: a flag
%%% that is accepted and ignored is a flag nobody can trust the next time.
%%%
%%% IT LIVES IN THE PROCESS DICTIONARY, AND DELIBERATELY. The alternative is
%%% threading a channel through `parse_string/2`, `parse_path/1` and
%%% `load_unit/1`, none of which have `#opts{}` in scope and two of which are
%%% reached from exported entry points. `set_channel/1` is called from `main/1`
%%% and from nowhere else, so a library caller — and every in-process test —
%%% gets `prose` and cannot be polluted by another test: the CLI is a fresh OS
%%% process every time it runs.
%%% ---------------------------------------------------------------------------

%% The guard is an assertion about an INTERNAL invariant, not input validation:
%% `parse_args` halts on any value other than these two, and `#opts.diagnostics`
%% defaults to `prose`, so a third value here means the CLI grew a way to
%% produce one and this should stop rather than guess.
set_channel(Chan) when Chan =:= prose; Chan =:= term ->
    put(bs_diag_channel, Chan).

channel() ->
    case get(bs_diag_channel) of
        undefined -> prose;
        Chan      -> Chan
    end.

%% 23 §4 — the frozen subset. The test for membership is §2's: does it hand the
%% agent something to write? A syntax error does not, so it is structured and
%% renderable and carries no shape promise. `defended` is named contractual by
%% §4 and is NOT here because it does not exist: it is §3's informational
%% boundary answer, which no feature has built.
%% `return_not_declared` joined on 2026-08-23 with F25. Until then it printed the
%% uncovered residual and stopped, which answers what is WRONG and not what to
%% WRITE — so it failed §4's own membership test and was correctly absent. It
%% carries the signature to paste now, so it passes.
contractual() ->
    [inexhaustive, catch_all_over_closed, switch_inexhaustive,
     arg_not_accepted, unreachable_clause, unreachable_arm,
     return_not_declared].

%%% ---------------------------------------------------------------------------
%%% Publishing
%%% ---------------------------------------------------------------------------

%% The prose goes where it always went. The term goes to stdout, and only when
%% asked for: the default prints nothing new, so no existing consumer moves.
%%
%% ONE DESCRIPTOR PER LINE, AND `~0p` IS WHAT MAKES THAT TRUE. A file with two
%% inexhaustive functions prints two descriptors, and under plain `~p` they wrap
%% across several lines each with NOTHING between them — so the only way to find
%% where one ends is to match brackets, which is precisely the screen-scraping
%% ticket 23 exists to abolish. `~0p` never breaks a line, so the frame is the
%% newline: a consumer reads a line and parses it, and needs no scanner of its
%% own. Measured before it was chosen; the multi-diagnostic case is a test.
emit(Chan, Desc) ->
    case Chan of
        term -> io:format("~0p~n", [Desc]);
        _    -> ok
    end,
    {Fmt, Args} = message(Desc),
    io:format(standard_error, Fmt, Args).

%% The published pure function. Prose is THIS, applied to the term — never
%% written next to it.
format(Desc) ->
    {Fmt, Args} = message(Desc),
    io_lib:format(Fmt, Args).

%%% ---------------------------------------------------------------------------
%%% descriptor/2 — the returned diagnostics (every term `bsc:report/2` publishes)
%%%
%%% THE COUNT THAT USED TO SIT IN THAT HEADING SAID 24, and there are 69 clauses
%%% below it minting 73 distinct tags. Whatever it counted on the day F16 landed,
%%% nothing re-measured it and no gate reads it, so it had been drifting for as
%%% long as diagnostics have been added. Replaced with a phrase rather than a
%%% corrected number, which would only start the same drift again (ENG-269).
%%% ---------------------------------------------------------------------------

%% The four keys every returned diagnostic carries. Severity travels as DATA
%% rather than being implied by the tag, because `unreachable_clause` and
%% `unreachable_arm` are warnings and everything around them is an error — a
%% consumer that had to know which is which from a list would be re-deriving
%% something the compiler already decided.
at(Sev, Path, Line, Fn) ->
    #{severity => Sev, file => Path, line => Line, function => Fn}.

descriptor(Path, {Sev, Line, Fn, {inexhaustive, Residual, Names}}) ->
    (at(Sev, Path, Line, Fn))#{tag => inexhaustive,
                               residual => residual(Residual),
                               heads => heads(Fn, Residual, Names)};
descriptor(Path, {Sev, Line, Fn, {catch_all_over_closed, Residual, Names}}) ->
    (at(Sev, Path, Line, Fn))#{tag => catch_all_over_closed,
                               residual => residual(Residual),
                               heads => heads(Fn, Residual, Names)};
%%% F13 — the four ways a binary segment can be wrong. Each one names the fix,
%%% because each is a shape the author meant something specific by.
descriptor(Path, {Sev, Line, Fn, {unsized_segment_not_last, _Size, _L}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unsized_segment_not_last};
descriptor(Path, {Sev, Line, Fn, {segment_width_not_positive, N, _L}}) ->
    (at(Sev, Path, Line, Fn))#{tag => segment_width_not_positive, width => N};
descriptor(Path, {Sev, Line, Fn, {segment_literal_too_wide, K, N, _L}}) ->
    (at(Sev, Path, Line, Fn))#{tag => segment_literal_too_wide,
                               value => K, width => N,
                               max => (1 bsl N) - 1};
descriptor(Path, {Sev, Line, Fn, {segment_size_not_bound, V, _L}}) ->
    (at(Sev, Path, Line, Fn))#{tag => segment_size_not_bound, name => V};
descriptor(Path, {Sev, Line, Fn, relational_in_bind}) ->
    (at(Sev, Path, Line, Fn))#{tag => relational_in_bind};
descriptor(Path, {Sev, Line, Fn, no_clauses}) ->
    (at(Sev, Path, Line, Fn))#{tag => no_clauses};
%% F26 / ticket 38. The operator is carried because the two spell the same
%% mistake differently, and the fix differs with it.
descriptor(Path, {Sev, Line, Fn, {divide_by_zero, Op}}) ->
    (at(Sev, Path, Line, Fn))#{tag => divide_by_zero, op => Op};
descriptor(Path, {Sev, Line, Fn, {switch_inexhaustive, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => switch_inexhaustive,
                               residual => residual(Residual),
                               arm => bs_types:to_pattern(Residual)};
descriptor(Path, {Sev, Line, Fn, {valve_on_infallible, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => valve_on_infallible,
                               subject => bs_types:to_pattern(Ty)};
descriptor(Path, {Sev, Line, Fn, {unreachable_arm, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unreachable_arm, arm_number => N};
%% ENG-269. The arm twins of `vacuous_clause` and `unsatisfiable_guard` below.
%%
%% TWO TAGS RATHER THAN ONE PER FAULT SHARED ACROSS BOTH SITES, for the reason
%% `unreachable_clause` and `unreachable_arm` are already two: a consumer matches
%% on the tag and then reads the keys, so one tag carrying `clause_number` at one
%% site and `arm_number` at the other would leave the key set undetermined by the
%% tag — and F16's "prose is a pure function of the term" would still need two
%% `message/1` clauses to say "arm" rather than "clause". Nothing is saved and a
%% contract is lost. ENG-269 proposed reusing `unsatisfiable_guard`; that is the
%% one place this fix departs from the issue, and this is why.
descriptor(Path, {Sev, Line, Fn, {vacuous_arm, N, Domain}}) ->
    (at(Sev, Path, Line, Fn))#{tag => vacuous_arm, arm_number => N,
                               domain => residual(Domain)};
descriptor(Path, {Sev, Line, Fn, {unsatisfiable_arm_guard, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unsatisfiable_arm_guard, arm_number => N};
descriptor(Path, {Sev, Line, Fn, switch_in_guard}) ->
    (at(Sev, Path, Line, Fn))#{tag => switch_in_guard};
descriptor(Path, {Sev, Line, Fn, {unreachable_clause, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unreachable_clause, clause_number => N};
%% ENG-259. The two faults that used to borrow `unreachable_clause`'s prose.
%%
%% `vacuous_clause` carries the DOMAIN rather than the offending pattern, because
%% the domain is the half the author does not have — they wrote the pattern, so
%% repeating it back says nothing, while the type it is not a member of is the
%% fact that ends the search. It goes through `residual/1` for the same reason
%% `inexhaustive` does: the term keeps the parts, and prose is a pure function
%% of the term (F16), so the rendering is not baked in at the site.
descriptor(Path, {Sev, Line, Fn, {vacuous_clause, N, Domain}}) ->
    (at(Sev, Path, Line, Fn))#{tag => vacuous_clause, clause_number => N,
                               domain => residual(Domain)};
descriptor(Path, {Sev, Line, Fn, {unsatisfiable_guard, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unsatisfiable_guard, clause_number => N};
descriptor(Path, {Sev, Line, Fn, {rebinding, V}}) ->
    (at(Sev, Path, Line, Fn))#{tag => rebinding, name => V};
descriptor(Path, {Sev, Line, Fn, {repeated_in_head, V}}) ->
    (at(Sev, Path, Line, Fn))#{tag => repeated_in_head, name => V};
descriptor(Path, {Sev, Line, Fn, {unbound_variable, V}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unbound_variable, name => V};
descriptor(Path, {Sev, Line, Fn, {arg_not_accepted, Callee, Pos, Residual, Head}}) ->
    (at(Sev, Path, Line, Fn))#{tag => arg_not_accepted,
                               callee => Callee,
                               position => Pos,
                               residual => residual(Residual),
                               rejected => bs_types:to_pattern(Residual),
                               caller_head => caller_head(Fn, Head, Residual)};
descriptor(Path, {Sev, Line, Fn, {field_set_mismatch, Record, Form, Missing, Extra}}) ->
    (at(Sev, Path, Line, Fn))#{tag => field_set_mismatch,
                               record => Record,
                               form => Form,
                               missing => Missing,
                               extra => Extra};
%% SITE 2's VALUE HALF — ticket 36. The residual is a type, so the printer that
%% already renders an exhaustiveness residual renders this one and ticket 23 is
%% satisfied without a new SHAPE of diagnostic — only a new tag.
descriptor(Path, {Sev, Line, Fn, {field_value_not_accepted, Record, Field, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => field_value_not_accepted,
                               record => Record,
                               field => Field,
                               residual => residual(Residual),
                               rejected => bs_types:to_pattern(Residual)};
%% SITE 3 — and, since ENG-249, `with`'s subject. The verb is read from the
%% form, as `field_set_mismatch` reads its own: the dot PROJECTS a field from
%% a value, `with` UPDATES one on it, and the residual and the fix are the same
%% in both — the member that lacks the field, discriminated on first.
descriptor(Path, {Sev, Line, Fn, {field_absent, Form, Field, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => field_absent,
                               form => Form,
                               field => Field,
                               residual => residual(Residual),
                               member => bs_types:to_pattern(Residual)};
%% F25 — the payload gained `corrected`, which is §4's additive-only evolution
%% working as intended: a map gains a key without breaking a matcher. It is
%% `none` when there is nothing writable to offer, rather than absent, so a
%% consumer never has to tell "refused" from "missing".
descriptor(Path, {Sev, Line, Fn, {return_not_declared, Residual, Corrected}}) ->
    (at(Sev, Path, Line, Fn))#{tag => return_not_declared,
                               residual => residual(Residual),
                               undeclared => bs_types:to_pattern(Residual),
                               corrected => Corrected};
descriptor(Path, {Sev, Line, Fn, {bind_may_fail, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => bind_may_fail,
                               residual => residual(Residual),
                               unmatched => bs_types:to_pattern(Residual)};
descriptor(Path, {Sev, Line, Fn, {private_function, Mod, Callee, Arity}}) ->
    (at(Sev, Path, Line, Fn))#{tag => private_function,
                               module => Mod, callee => Callee, arity => Arity};
descriptor(Path, {Sev, Line, Fn, {unknown_callee, Callee, Arity}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unknown_callee,
                               callee => Callee, arity => Arity};
descriptor(Path, {Sev, Line, Fn, {arity_mismatch, Callee, Got, Want}}) ->
    (at(Sev, Path, Line, Fn))#{tag => arity_mismatch,
                               callee => Callee, got => Got, want => Want};
descriptor(Path, {Sev, Line, Fn, {arity_not_declared, Callee, Got, Have}}) ->
    (at(Sev, Path, Line, Fn))#{tag => arity_not_declared,
                               callee => Callee, got => Got, declared => Have};
descriptor(Path, {Sev, Line, Fn, {unknown_record, Name}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unknown_record, record => Name};
descriptor(Path, {Sev, Line, Fn, wildcard_as_value}) ->
    (at(Sev, Path, Line, Fn))#{tag => wildcard_as_value};

%%% --- F18, the codegen-obligation site ---------------------------------------

%% Ticket 15 §1's collapse, met at an instantiation rather than at a declaration.
%% The descriptor carries the TYPE, not the finished sentence, so a consumer can
%% see which instantiation was asked for.
descriptor(Path, {Sev, Line, Fn, {validate_collapses, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => validate_collapses,
                               type => bs_types:to_string(Ty)};
descriptor(Path, {Sev, Line, Fn, {obligation_arity, Name, Types, Args}}) ->
    (at(Sev, Path, Line, Fn))#{tag => obligation_arity,
                               obligation => Name,
                               type_args => Types, args => Args};
descriptor(Path, {Sev, Line, Fn, {obligation_unbuilt, Name}}) ->
    (at(Sev, Path, Line, Fn))#{tag => obligation_unbuilt, obligation => Name};
descriptor(Path, {Sev, Line, Fn, {not_an_obligation, Name}}) ->
    (at(Sev, Path, Line, Fn))#{tag => not_an_obligation, name => Name,
                               obligations => ['ValidateAs', 'ParseAtom',
                                               'ToExistingAtom']};

%%% ---------------------------------------------------------------------------
%%% The fatal ones — lexing and reading, before there is a function to name
%%% ---------------------------------------------------------------------------

%% beam-sharp has no statement terminator, and both audiences type one from
%% habit — so this is the most likely error in the language and it gets the
%% sharpest message rather than leex's raw tuple.
descriptor(Path, {lex, {Line, _Mod, {illegal, ";"}}}) ->
    #{tag => stray_semicolon, severity => error, file => Path, line => Line};
%% Ticket 63 refused negation, and refused it on REDUNDANCY rather than danger:
%% the guard fragment `alternatives/1` reads is already closed under complement,
%% so a `not` the translator had learned would compile into the exact spelling
%% the author could have written. The refusal came with an obligation — the
%% absence teaches — and these two clauses are it. `bin/check-negation.sh` is
%% the gate.
%%
%% `!` FIRST, BECAUSE IT NEVER REACHES THE PARSER. It is an illegal character,
%% so it fails here in the lexer, one stage earlier than `not` does. `!=` is a
%% token of its own and so never arrives as an illegal character at all — the
%% suite asserts that separately rather than leaving it to be assumed.
descriptor(Path, {lex, {Line, _Mod, {illegal, [$! | _]}}}) ->
    #{tag => no_negation, severity => error, file => Path, line => Line,
      spelling => "!"};
descriptor(Path, {lex, {Line, Mod, Reason}}) ->
    #{tag => lex_error, severity => error, file => Path, line => Line,
      detail => lists:flatten(Mod:format_error(Reason))};
%% `not` IS NOT A KEYWORD AND MUST NOT BECOME ONE. It is a legal identifier
%% today — `F(not) when not > 100` compiles and runs — and reserving it would be
%% the cheap route to a sharp message while quietly taking a name out of the
%% language. That is ticket 65's question (reserved names as a policy, not one
%% name at a time) and 65 is open. So the hint is raised HERE, at the parse
%% failure, where it cannot reach a program that parses.
descriptor(Path, {parse, {Line, Mod, Reason}, Tokens}) ->
    case not_in_prefix_position(Tokens, Line) of
        true ->
            #{tag => no_negation, severity => error, file => Path,
              line => Line, spelling => "not"};
        false ->
            descriptor(Path, {parse, {Line, Mod, Reason}})
    end;
descriptor(Path, {parse, {Line, Mod, Reason}}) ->
    #{tag => parse_error, severity => error, file => Path, line => Line,
      detail => lists:flatten(Mod:format_error(Reason))};
%% F15 — most often an unmatched shell glob rather than a real directory, so the
%% message says what was looked for instead of just naming the path.
descriptor(Path, no_sources_here) ->
    #{tag => no_sources_here, severity => error, file => Path};

%%% ---------------------------------------------------------------------------
%%% The raised conditions (`bsc:resolve_error/2`'s 32)
%%%
%%% These are found while RESOLVING types — below the level that carries a line
%%% and a function name — and reach the author through the `try` in
%%% `check_and_emit/4`. They are not a second channel: a raised condition gets a
%%% descriptor exactly like a returned one, which is F16.4.
%%% ---------------------------------------------------------------------------

%% A raise site that knows its file says so, and the inner tuple stays exactly
%% the shape ticket 41 specified.
descriptor(_Path, {in_file, Path, Reason}) ->
    descriptor(Path, Reason);

descriptor(Path, {behaviour_not_satisfied, Line, Behaviour, Missing}) ->
    #{tag => behaviour_not_satisfied, severity => error, file => Path,
      line => Line, behaviour => Behaviour, missing => Missing};
%% Ticket 06 measured that `-behaviour` has no runtime effect and only exports
%% matter, so this would otherwise break the contract at run time and silently.
descriptor(Path, {private_callback, N, A, Otp, Line}) ->
    #{tag => private_callback, severity => error, file => Path, line => Line,
      name => N, arity => A, otp_name => Otp};
descriptor(Path, {unknown_behaviour, B}) ->
    #{tag => unknown_behaviour, severity => error, file => Path, behaviour => B};
descriptor(Path, {unknown_type, N}) ->
    #{tag => unknown_type, severity => error, file => Path, type => N};
%% F22 — a type prefix in a pattern that names something which is not a record.
descriptor(Path, {not_a_record, Line, N}) ->
    #{tag => not_a_record, severity => error, file => Path, line => Line,
      type => N};
%% F22 — a field named beside a type prefix that the record has not got.
descriptor(Path, {pattern_field_unknown, Line, Record, Field, Declared}) ->
    #{tag => pattern_field_unknown, severity => error, file => Path,
      line => Line, record => Record, field => Field, declared => Declared};
descriptor(Path, {unknown_builtin, B}) ->
    #{tag => unknown_builtin, severity => error, file => Path, type => B};
%% F9.11. The message names the replacement, because the fix is always the same
%% edit and the reason is not obvious from the rule.
descriptor(Path, {opaque_ret_at_boundary, Line, Mod, Fun}) ->
    #{tag => opaque_ret_at_boundary, severity => error, file => Path,
      line => Line, module => bs_types:atom_str(Mod), function => Fun};
%% F19 / ticket 15 §5. Its sibling one clause up: both are a foreign RETURN TYPE
%% refused at the declaration, and both name the replacement because the fix is
%% one edit either way. The payload is carried as a rendered string rather than
%% as a type, so `message/1` stays a pure function of the descriptor — the term
%% is what a consumer reads, and a consumer that had to re-run the algebra to
%% print it would not be reading a diagnostic.
descriptor(Path, {unknown_generic, N}) ->
    #{tag => unknown_generic, severity => error, file => Path, type => N};
%% F6.6. A bracket the compiler KNOWS at the wrong arity is a different mistake
%% from a bracket it does not know, and the fix is a different edit.
descriptor(Path, {generic_arity, N, Want, Got}) ->
    #{tag => generic_arity, severity => error, file => Path, type => N,
      want => Want, got => Got};
descriptor(Path, {needs_type_args, N, Want}) ->
    #{tag => needs_type_args, severity => error, file => Path, type => N,
      want => Want};
descriptor(Path, {not_parametric, N}) ->
    #{tag => not_parametric, severity => error, file => Path, type => N};
%% F6.8. TWO REFUSALS, NOT ONE — ticket 09 §3's well-formedness rule made
%% visible. One is a mistake that cannot be given a meaning by any amount of
%% implementation; the other is well formed and simply unbuilt.
descriptor(Path, {cyclic_type, N}) ->
    #{tag => cyclic_type, severity => error, file => Path, type => N};
%% F28 — `recursive_type` IS GONE, and its absence is the feature. It said "well
%% formed, and this compiler has no binder for it"; the binder exists, so the
%% only honest thing to do with the tag is delete it rather than leave a message
%% nothing can print. `cyclic_type` above stays exactly as it was: that one was
%% never about a missing feature.
%%
%% What took its place is narrower and genuinely unbuildable. A parametric alias
%% that recurs under DIFFERENT arguments — `type T<X> = (X, list<T<list<X>>>)` —
%% is not a regular tree: unfolding it produces `T<int>`, `T<list<int>>`,
%% `T<list<list<int>>>` and never repeats, so there is no finite binder to hold
%% it. Refused by name because the alternative is expanding forever, which is
%% the hang this feature's gate exists to catch.
descriptor(Path, {non_regular_recursion, N}) ->
    #{tag => non_regular_recursion, severity => error, file => Path, type => N};
%% F18. Stratum 2 of the prelude is compiler-known and a user may not add to it
%% (`PRELUDE.md`, ticket 27 §8). Refused at the DECLARATION rather than resolved
%% by shadowing, because the alternative is a type error somewhere else with
%% nothing pointing at the line that caused it.
descriptor(Path, {compiler_known_type, Name, Line}) ->
    #{tag => compiler_known_type, severity => error, file => Path, line => Line,
      type => Name};
descriptor(Path, {kind_field_is_minted, Line, Name}) ->
    #{tag => kind_field_is_minted, severity => error, file => Path, line => Line,
      record => Name};
%% F31. Ticket 15 §1's collapse at the site 15 §1 chose, beside the other
%% declaration refusals rather than beside F18's. The descriptor carries the
%% CHANNEL as well as the two types, because the hint differs by channel and a
%% consumer should not have to parse the sentence to find out which one it was.
descriptor(Path, {collapsed_failure_channel, Line, Channel, Member, Absorber}) ->
    #{tag => collapsed_failure_channel, severity => error, file => Path,
      line => Line, channel => Channel,
      member => bs_types:to_string(Member),
      absorbed_by => bs_types:to_string(Absorber)};
%% F2 / ticket 20 §5. The two tiers are told apart by what the predicate SAYS.
descriptor(Path, {opaque_refinement, Line}) ->
    #{tag => opaque_refinement, severity => error, file => Path, line => Line};
descriptor(Path, {empty_refinement, Line}) ->
    #{tag => empty_refinement, severity => error, file => Path, line => Line};
%% F2's scope call, made legible: the construct ships in the parameter position
%% only, and "syntax error" would make a chosen omission look like an oversight.
descriptor(Path, {relational_pattern_nested, Line}) ->
    #{tag => relational_pattern_nested, severity => error, file => Path,
      line => Line};
%% Ticket 40 §2. Two signatures of the SAME arity are one function declared
%% twice, and its clauses would otherwise merge silently.
descriptor(Path, {name_redeclared, Name, Arity, Line}) ->
    #{tag => name_redeclared, severity => error, file => Path, line => Line,
      name => Name, arity => Arity};
%% 41 §2 requirement 1. The candidates print QUALIFIED because a qualified call
%% is legal regardless of what is in scope — so the message is pasteable source,
%% which is the property ticket 23 gives the residual.
descriptor(Path, {ambiguous_call, Name, Arity, Mods, Line}) ->
    #{tag => ambiguous_call, severity => error, file => Path, line => Line,
      name => Name, arity => Arity, candidates => Mods,
      heads => [lists:flatten(io_lib:format("~s.~s(...)", [M, Name]))
                || M <- Mods]};
%% `import_shadows_local` stood here until 2026-09-02. Ticket 47 Q2 settled that
%% a local and an import are not two meanings of a bare name — 41 §2 resolves
%% them "local, then imports" — so nothing raises the term any more and the
%% descriptor went with the check (ENG-270). `ambiguous_call` above is the
%% surviving half of §2's one sentence, and it fires at the use.
descriptor(Path, {unknown_module, Mod, Line}) ->
    #{tag => unknown_module, severity => error, file => Path, line => Line,
      module => Mod};
%% 41 §1 reason 3 met rather than decided: a file's `using` lines ARE its
%% dependency list, in the file and checkable (ticket 23 §11).
descriptor(Path, {module_not_imported, Mod, Line}) ->
    #{tag => module_not_imported, severity => error, file => Path, line => Line,
      module => Mod};
descriptor(Path, {ambiguous_module, Short, Mods, Line}) ->
    #{tag => ambiguous_module, severity => error, file => Path, line => Line,
      module => Short, candidates => Mods};
%% Two modules importing each other. F6's cyclic-ALIAS guard is the precedent 41
%% names: refuse by name rather than expand, because resolving a cycle by
%% following it is a loop — and that guard shipped after a HANG, which no green
%% suite could see.
descriptor(_Path, {import_cycle, Cycle}) ->
    #{tag => import_cycle, severity => error, cycle => Cycle};
%% Ticket 41 §4. `index.bs` holds everything except functions.
descriptor(Path, {function_in_index, Name, Line}) ->
    #{tag => function_in_index, severity => error, file => Path, line => Line,
      function => Name};
%% Ticket 41 §5. Ticket 13's measured `erlc` module-atom/filename rule lifted one
%% level, from the emitted artefact to the source tree.
descriptor(Path, {module_path_mismatch, Declared, Expected, Line}) ->
    #{tag => module_path_mismatch, severity => error, file => Path, line => Line,
      declared => Declared, expected => Expected};
%% One directory is one module (ticket 13 §3's aggregate rule).
descriptor(_Path, {module_disagreement, Declared}) ->
    #{tag => module_disagreement, severity => error,
      count => length(lists:usort([M || {_, M, _} <- Declared])),
      declarations => Declared};
descriptor(_Path, {no_module_declaration, Paths}) ->
    #{tag => no_module_declaration, severity => error, files => Paths};
%% Ticket 41 §3 draws the build-tool boundary at naming the source root, so a
%% root that does not contain what it is rooting is a usage error.
descriptor(_Path, {src_root_mismatch, Dir, Root}) ->
    #{tag => src_root_mismatch, severity => error, directory => Dir,
      root => Root};
descriptor(_Path, {src_root_is_the_module, Dir}) ->
    #{tag => src_root_is_the_module, severity => error, directory => Dir};

%%% ---------------------------------------------------------------------------
%%% The remainder
%%%
%%% `unhandled` is how a RAISED tuple with no clause here is re-raised rather
%%% than swallowed — the behaviour `resolve_error/2` had, kept exactly, because
%%% what the author would otherwise see is an escript stack trace.
%%% ---------------------------------------------------------------------------

descriptor(Path, {Sev, _Line, _Fn, _} = D) when Sev =:= error; Sev =:= warning ->
    #{tag => unclassified, severity => Sev, file => Path, detail => D};
descriptor(_Path, _Other) ->
    unhandled.

%%% ---------------------------------------------------------------------------
%%% `not` in prefix position — ticket 63
%%%
%%% WHY A SHAPE AND NOT A TOKEN. The two positions the decision covers fail at
%%% DIFFERENT tokens, so a rule keyed on the one yecc reported would see the
%%% first and miss the second entirely:
%%%
%%%     when not (n > 100)            syntax error before: '('
%%%     int where not (value > 100)   syntax error before: '>'
%%%
%%% The ticket's argument that a guard and a refinement cannot come to disagree
%%% is about the one `alternatives/1` they share in the CHECKER. It does not
%%% reach the parser, so the refinement position is measured here rather than
%%% inherited from the guard one.
%%%
%%% WHY THIS CANNOT MIS-FIRE ON A VALID PROGRAM. Two reasons, and the second is
%%% the one that matters. It only runs after the parse has ALREADY failed. And
%%% the shape it looks for cannot occur in a program that parses: applying a
%%% variable would need an arrow, and F6 measured that `ty()` has no arrow part
%%% and the surface language has no lambda. So `not (`, `not x`, `not 3` and
%%% `not :a` are unparseable in every valid program, while a bare `not` used as
%%% an ordinary variable — followed by an operator, a comma or a bracket — is
%%% untouched by this and keeps working.
%%%
%%% IF LAMBDAS EVER ARRIVE, `not (` BECOMES PARSEABLE and this rule needs
%%% revisiting. That sits beside ticket 63's other re-open trigger rather than
%%% replacing it.
%%% ---------------------------------------------------------------------------

not_in_prefix_position([{lident, L, 'not'}, Next | Rest], Line) ->
    (L =:= Line andalso is_operand(Next))
        orelse not_in_prefix_position([Next | Rest], Line);
not_in_prefix_position([_ | Rest], Line) -> not_in_prefix_position(Rest, Line);
not_in_prefix_position([], _Line)        -> false.

is_operand({'(', _})         -> true;
is_operand({lident, _, _})   -> true;
is_operand({uident, _, _})   -> true;
is_operand({integer, _, _})  -> true;
is_operand({atom_lit, _, _}) -> true;
is_operand(_)                -> false.

%%% ---------------------------------------------------------------------------
%%% message/1 — the single owner of every format string
%%%
%%% Every one of these moved here verbatim from `bsc.erl`. The prose is
%%% unchanged to the byte: 321 tests assert on it, and that is the net this
%%% refactor was steered by.
%%% ---------------------------------------------------------------------------

message(#{tag := inexhaustive, file := P, line := L, function := Fn,
          heads := Heads}) ->
    {"~s:~p: error: ~s is not exhaustive~n"
     "  no clause matches:~n~s",
     [P, L, Fn, heads_prose(Fn, Heads)]};
%% TICKET 12 §2 — a catch-all is legal only over an OPEN residual, and this is
%% the message that has to carry a *conditionally legal* `_` to a reader who has
%% never met one. Neither borrowed audience expects that: C#'s `_` in a switch
%% arm is just a pattern and TypeScript's `default` is just a branch. 12 accepted
%% the cost because the alternative puts the headline guarantee one character
%% from being switched off, silently, with no trace in the diff.
%%
%% So the message says WHY it is closed and hands back the cases, which is ticket
%% 04's finding doing the work: the residual IS the missing case, so the thing
%% that makes the error legitimate is the same thing that answers it.
message(#{tag := catch_all_over_closed, file := P, line := L, function := Fn,
          heads := Heads}) ->
    {"~s:~p: error: ~s discards cases the compiler can name~n"
     "  every value left here comes from a type you declared, so `_`~n"
     "  hides a case rather than admitting an unknown one:~n~s"
     "  a catch-all is for a residual with an unbounded top in it — a~n"
     "  `term` argument, or the open atom universe — where a foreign~n"
     "  sender chooses the inhabitants and there is nothing to enumerate.~n",
     [P, L, Fn, heads_prose(Fn, Heads)]};
%% F2. The construct is a head's, and the message says where to put it rather
%% than only that it is wrong.
message(#{tag := relational_in_bind, file := P, line := L, function := Fn}) ->
    {"~s:~p: error: ~s binds a relational pattern~n"
     "  `>= 4` names a span of values and introduces no name, so there~n"
     "  is nothing for a bind to bind. A bind must also be provably~n"
     "  irrefutable, and a span is the refutable construct itself.~n"
     "  Dispatch on it in a clause head instead.~n",
     [P, L, Fn]};
message(#{tag := no_clauses, file := P, line := L, function := Fn}) ->
    {"~s:~p: error: ~s has a signature but no clauses~n", [P, L, Fn]};
%% Ticket 23 §2's test — does it hand the agent something to WRITE? A bare
%% "divide by zero" does not, because the reader's next question is whether the
%% language wanted a non-zero proof at every call site. It did not, and saying so
%% is the whole message: only a divisor proved to BE zero is refused.
message(#{tag := divide_by_zero, file := P, line := L, function := Fn,
          op := Op}) ->
    {"~s:~p: error: the right-hand side of `~s` in ~s is always zero~n"
     "  `~s` needs no proof that a divisor is non-zero — a divisor that MIGHT~n"
     "  be zero compiles and crashes at run time. Only one the compiler can~n"
     "  prove is zero is refused, and this is one.~n",
     [P, L, Op, Fn, Op]};
%% Ticket 17 §6, and ticket 04's residual at a third site. Deliberately NOT
%% routed through the head printer: that prints `Fn(:cancelled) -> ...`, and a
%% switch has no function name and its arrow is `=>`.
message(#{tag := switch_inexhaustive, file := P, line := L, function := Fn,
          arm := Arm}) ->
    {"~s:~p: error: this switch in ~s is not exhaustive~n"
     "  no arm matches:~n"
     "    ~s => ...~n",
     [P, L, Fn, Arm]};
%% F14 §4, and the message is the feature. A valve over a value with no
%% `(:error, _)` member generates an arm that can never match, and the honest
%% report is not `unreachable arm 1` — the author wrote no arms. What they wrote
%% was the wrong operator, so the diagnostic names the right one.
message(#{tag := valve_on_infallible, file := P, line := L, function := Fn,
          subject := Ty}) ->
    {"~s:~p: error: this |?> in ~s is over a value that cannot fail~n"
     "  ~s has no (:error, _) member, so the valve would never stop.~n"
     "  Write |> instead.~n",
     [P, L, Fn, Ty]};
%% Arm, not clause. The word is the whole of the message's usefulness: a
%% construct with no clauses in it cannot be told which clause is dead.
message(#{tag := unreachable_arm, file := P, line := L, function := Fn,
          arm_number := N}) ->
    {"~s:~p: warning: arm ~p of this switch in ~s is unreachable~n"
     "  every value it matches is matched by an earlier arm.~n",
     [P, L, N, Fn]};
%% ENG-269. The wording is the whole fix here too, and "arm" is not the only
%% word that has to change from the clause pair: the repair differs. A clause
%% that is not a member of its input is edited or deleted; an arm has a THIRD
%% option, because the subject is right there and may itself be the mistake.
message(#{tag := vacuous_arm, file := P, line := L, function := Fn,
          arm_number := N, domain := Dom}) ->
    {"~s:~p: warning: arm ~p of this switch in ~s matches no value~n"
     "  the subject's type is ~s, and this arm's pattern is not a~n"
     "  member of it — so no value reaching this switch can take~n"
     "  this arm.~n",
     [P, L, N, Fn, Dom]};
%% And this one must NOT name the type, for `unsatisfiable_guard`'s reason: the
%% pattern is a perfectly good member of it, and the guard is what admits
%% nothing. Sending this author to look at the pattern would be the same
%% misdirection in a new costume.
message(#{tag := unsatisfiable_arm_guard, file := P, line := L, function := Fn,
          arm_number := N}) ->
    {"~s:~p: warning: arm ~p of this switch in ~s has an unsatisfiable guard~n"
     "  the pattern is a member of the subject's type; it is the~n"
     "  guard that admits nothing. Widen the guard, or delete the arm.~n",
     [P, L, N, Fn]};
%% F7's own grammar opens this, the way F5's opened `_`-as-a-value: a guard
%% shares the whole expression grammar, so a switch parses inside one.
message(#{tag := switch_in_guard, file := P, line := L, function := Fn}) ->
    {"~s:~p: error: ~s has a switch in a guard~n"
     "  a guard asks a question about the values a clause already~n"
     "  matched; it cannot branch. Move the switch into the body.~n",
     [P, L, Fn]};
message(#{tag := unreachable_clause, file := P, line := L, function := Fn,
          clause_number := N}) ->
    {"~s:~p: warning: clause ~p of ~s is unreachable~n"
     "  every value it matches is matched by an earlier clause.~n",
     [P, L, N, Fn]};
%% ENG-259. THE WORDING IS THE WHOLE FIX, so both of these say what the other
%% one does not. `unreachable_clause` above sends the reader to look for the
%% clause that covers this one; neither of these has such a clause, and the
%% first of them may be the only clause in the function.
%%
%% This one names the type, because the pattern is not a member of it and that
%% membership is the thing the author got wrong. It is the most likely first
%% mistake in the language: `option<T>` is `T | :nothing`, UNTAGGED, so the
%% `(:some, x)` a reader brings from C#, Rust or F# matches nothing at all.
message(#{tag := vacuous_clause, file := P, line := L, function := Fn,
          clause_number := N, domain := Dom}) ->
    {"~s:~p: warning: clause ~p of ~s matches no value of its input~n"
     "  the declared input is ~s, and this clause's pattern is not~n"
     "  a member of it — so no call can reach this clause.~n",
     [P, L, N, Fn, Dom]};
%% And this one must NOT name the type: the pattern is a perfectly good member
%% of it, and the guard is what admits nothing. Telling this author to check the
%% pattern would be the same misdirection in a new costume.
message(#{tag := unsatisfiable_guard, file := P, line := L, function := Fn,
          clause_number := N}) ->
    {"~s:~p: warning: clause ~p of ~s has a guard no value satisfies~n"
     "  the pattern is a member of the input; it is the guard that~n"
     "  admits nothing. Widen the guard, or delete the clause.~n",
     [P, L, N, Fn]};
%% Ticket 34. Both of these would otherwise reach the author as an `erlc` error
%% against the emitted `.abstr` — a file they did not write and cannot fix.
message(#{tag := rebinding, file := P, line := L, function := Fn, name := V}) ->
    {"~s:~p: error: ~s binds ~s twice~n"
     "  a name means one thing in a clause. There is no mutation to~n"
     "  assign with, so rename the second one.~n",
     [P, L, Fn, V]};
%% F8.10. The same offence as `rebinding` and a DIFFERENT fix, which is why it is
%% a different descriptor rather than a shared one: in a body you rename, in a
%% head you almost always meant *the same value again*, and ticket 45 supplies
%% the spelling for saying so.
message(#{tag := repeated_in_head, file := P, line := L, function := Fn,
          name := V}) ->
    {"~s:~p: error: ~s binds ~s twice in one head~n"
     "  a name means one thing in a clause, so this introduces ~s and~n"
     "  then introduces it again. To match the value the first one~n"
     "  holds, write `== ~s`.~n",
     [P, L, Fn, V, V, V]};
message(#{tag := unbound_variable, file := P, line := L, function := Fn,
          name := V}) ->
    {"~s:~p: error: ~s uses ~s, which nothing binds~n"
     "  a name comes from a clause head or a binding above it.~n",
     [P, L, Fn, V]};
%% SITE 1 of ticket 33's five. The residual is the clause the CALLER must write.
%% It proposes an edit to the function being checked and never to the callee:
%% ticket 18 §4's function-local rule is what stops this from suggesting you
%% widen `Update`.
message(#{tag := arg_not_accepted, file := P, line := L, function := Fn,
          callee := Callee, position := Pos, rejected := Rejected,
          caller_head := Head}) ->
    {"~s:~p: error: ~s hands ~s an argument it does not accept~n"
     "  argument ~p is not covered by ~s's declared type:~n"
     "    ~s~n~s",
     [P, L, Fn, Callee, Pos, Callee, Rejected, caller_head_prose(Fn, Head)]};
%% SITE 2. `Order{Id} \ Order` names the type you were BUILDING rather than the
%% field you forgot — correct, and worthless — so this one site answers in field
%% names. It still hands back something to write, which is what ticket 23 asks.
%% THE VERB IS READ FROM THE FORM — ticket 36. `with` reaches this same site
%% now, and *"Bump builds an Order with the wrong fields"* is false about an
%% expression that updates one: nothing is missing there, a name was invented.
%% One field on the descriptor rather than a fourth diagnostic shape, because
%% the `Extra` arm's own sentence — *"not declared by Order"* — was already the
%% right one, and `field_list/2` already renders an empty `Missing` as nothing.
message(#{tag := field_set_mismatch, file := P, line := L, function := Fn,
          record := Record, form := Form, missing := Missing, extra := Extra}) ->
    {"~s:~p: error: ~s ~s an ~s with the wrong fields~n~s~s",
     [P, L, Fn, field_set_verb(Form), Record,
      field_list("  missing, and must be supplied", Missing),
      field_list("  not declared by " ++ atom_to_list(Record), Extra)]};
%% SITE 2's VALUE HALF. Shaped on site 4's message deliberately: both say that a
%% synthesised value is not contained in a type someone declared, and the only
%% difference is which declaration — a signature's return there, a record's
%% field here.
message(#{tag := field_value_not_accepted, file := P, line := L, function := Fn,
          record := Record, field := Field, rejected := Rejected}) ->
    {"~s:~p: error: ~s assigns ~s a value ~s does not accept~n"
     "  not covered by the declared type of ~s:~n"
     "    ~s~n",
     [P, L, Fn, Field, Record, Field, Rejected]};
%% SITE 3. The residual IS the member that lacks the field, which is the tag to
%% discriminate on — the sentence F3.8 deferred, needing no new machinery.
message(#{tag := field_absent, file := P, line := L, function := Fn,
          form := projection, field := Field, member := Member}) ->
    {"~s:~p: error: ~s projects ~s from a value that may not carry it~n"
     "  this member has no ~s:~n"
     "    ~s~n"
     "  discriminate on the tag first, in a clause head.~n",
     [P, L, Fn, Field, Field, Member]};
%% ENG-249 — the same residual serves `with`, whose subject was unchecked
%% until 2026-09-03. The member handed back is either one arm of a union or
%% the whole subject (`int`), and the fix differs: the first is discriminated
%% on, the second has no tag to discriminate and needs a record where an int
%% is. Ticket 23 §4 asks that what is handed back be writable, so the line
%% names both edits rather than one that cannot be followed.
message(#{tag := field_absent, file := P, line := L, function := Fn,
          form := update, field := Field, member := Member}) ->
    {"~s:~p: error: ~s updates ~s on a value that may not carry it~n"
     "  this member has no ~s:~n"
     "    ~s~n"
     "  `with` updates a record: give it one, or discriminate on the tag~n"
     "  first, in a clause head.~n",
     [P, L, Fn, Field, Field, Member]};
%% SITE 4. Without this, beam-sharp emits a `-spec` claiming what its own body
%% does not deliver — the defect ticket 18 measured in Gleam, from a body rather
%% than from an FFI declaration.
%% F25 / ticket 23 §8. The residual answers what is not COVERED; the second line
%% answers what to WRITE. They are different questions and ticket 04 made the
%% first one a product surface, so the signature is an addition rather than a
%% replacement. The `none` clause comes first and is the case where the residual
%% has no writable spelling — a record, or `binary \ string`.
message(#{tag := return_not_declared, file := P, line := L, function := Fn,
          undeclared := Undeclared, corrected := none}) ->
    {"~s:~p: error: ~s returns a value its signature does not declare~n"
     "  not covered by the declared return type:~n"
     "    ~s~n",
     [P, L, Fn, Undeclared]};
message(#{tag := return_not_declared, file := P, line := L, function := Fn,
          undeclared := Undeclared, corrected := Corrected}) ->
    {"~s:~p: error: ~s returns a value its signature does not declare~n"
     "  not covered by the declared return type:~n"
     "    ~s~n"
     "  the signature its clauses justify:~n"
     "    ~s~n",
     [P, L, Fn, Undeclared, Corrected]};
%% SITE 5. Ticket 34 deferred the destructuring bind here rather than refusing
%% it: provably irrefutable exactly when this residual is empty.
message(#{tag := bind_may_fail, file := P, line := L, function := Fn,
          unmatched := Unmatched}) ->
    {"~s:~p: error: this bind in ~s can fail~n"
     "  the pattern does not match:~n"
     "    ~s~n"
     "  a bind that can fail is a branch the exhaustiveness checker~n"
     "  never sees. Match it in a clause head instead.~n",
     [P, L, Fn, Unmatched]};
%% F12 / ticket 40 §3. The whole reason `exports_of/1` does not simply filter:
%% reported as `unknown_callee` this would tell the author the function does not
%% exist, when it plainly does and is one word away from being callable.
message(#{tag := private_function, file := P, line := L, function := Fn,
          module := Mod, callee := Callee, arity := Arity}) ->
    {"~s:~p: error: ~s calls ~s/~p, which ~s declares `private`~n"
     "  a private function is not exported, so no other module can~n"
     "  reach it. Mark it `public` in ~s, or move the call inside it.~n",
     [P, L, Fn, Callee, Arity, Mod, Mod]};
message(#{tag := unknown_callee, file := P, line := L, function := Fn,
          callee := Callee, arity := Arity}) ->
    {"~s:~p: error: ~s calls ~s/~p, which nothing declares~n"
     "  every function has a signature. Write one, or fix the name.~n",
     [P, L, Fn, Callee, Arity]};
message(#{tag := arity_mismatch, file := P, line := L, function := Fn,
          callee := Callee, got := Got, want := Want}) ->
    {"~s:~p: error: ~s calls ~s with ~p arguments, and it takes ~p~n",
     [P, L, Fn, Callee, Got, Want]};
%% Ticket 40 §2 permits arity overloading, so this is not "wrong number of
%% arguments" — it is a function that has not been declared, next to ones that
%% have. Naming the arities that DO exist is what keeps it a fix rather than a
%% verdict.
message(#{tag := arity_not_declared, file := P, line := L, function := Fn,
          callee := Callee, got := Got, declared := Have}) ->
    {"~s:~p: error: ~s calls ~s/~p, which nothing declares~n"
     "  ~s is declared at ~s. Arity overloading is permitted, so~n"
     "  ~s/~p would be a new function and needs its own signature.~n",
     [P, L, Fn, Callee, Got, Callee,
      lists:join(", ", [[$/ | integer_to_list(A)] || A <- Have]),
      Callee, Got]};
message(#{tag := unknown_record, file := P, line := L, function := Fn,
          record := Name}) ->
    {"~s:~p: error: ~s builds an ~s, which no record or type declares~n",
     [P, L, Fn, Name]};
%% F5's own grammar opens this hole: `_` is an expression only so that
%% `(a, _) = pair` parses. Caught here rather than by `erlc` against a file the
%% author did not write, which is F4.7's rule.
message(#{tag := wildcard_as_value, file := P, line := L, function := Fn}) ->
    {"~s:~p: error: ~s uses `_` as a value~n"
     "  `_` is a pattern. It may stand on the left of `=` or in a~n"
     "  clause head; it names nothing to read back.~n",
     [P, L, Fn]};

%%% --- F18 ---------------------------------------------------------------------

%% The message says WHY rather than only what, because the rule is not obvious
%% and the fix is to want something else entirely.
message(#{tag := validate_collapses, file := P, line := L, function := Fn,
          type := Ty}) ->
    {"~s:~p: error: ~s validates against a type that absorbs its own~n"
     "  failure channel~n"
     "  the type is: ~s~n"
     "  `result<T, ValidationError>` over it normalises straight back to~n"
     "  T, so the validator could only ever succeed and no caller could~n"
     "  write the failure clause. Validate against the type you actually~n"
     "  expect.~n",
     [P, L, Fn, Ty]};
message(#{tag := obligation_arity, file := P, line := L, function := Fn,
          obligation := Name, type_args := Types, args := Args}) ->
    {"~s:~p: error: ~s writes ~s with ~p type arguments and ~p values~n"
     "  ~s is a codegen obligation, not a function: it takes exactly one~n"
     "  type argument and one value. The bracket names the type to~n"
     "  generate a check for, the parentheses hold the term to check.~n"
     "  Write `~s<T>(x)`.~n",
     [P, L, Fn, Name, Types, Args, Name, Name]};
%% Two different sentences, and the difference is the whole value of having the
%% closed set in the checker rather than in the lexer: one is "wait for us", the
%% other is "that was never going to work".
message(#{tag := obligation_unbuilt, file := P, line := L, function := Fn,
          obligation := Name}) ->
    {"~s:~p: error: ~s uses ~s, which is decided and not built yet~n"
     "  the instantiation bracket admits it — ticket 28 fixed the set of~n"
     "  names it may follow — but this compiler generates nothing for it.~n"
     "  ValidateAs<T> is the one that is built.~n",
     [P, L, Fn, Name]};
message(#{tag := not_an_obligation, file := P, line := L, function := Fn,
          name := Name, obligations := Names}) ->
    {"~s:~p: error: ~s writes ~s<...>, and ~s is not a codegen obligation~n"
     "  user code has no instantiation syntax: a type argument is written~n"
     "  only after a compiler-known name, which is ~s.~n"
     "  Everywhere else `<` is a comparison.~n",
     [P, L, Fn, Name, Name,
      lists:join(", ", [atom_to_list(N) || N <- Names])]};
message(#{tag := compiler_known_type, file := P, line := L, type := Name}) ->
    {"~s:~p: error: ~s is a compiler-known type and cannot be redeclared~n"
     "  the prelude has two strata: ordinary aliases you could have~n"
     "  written, and names the compiler owns because it is the only thing~n"
     "  that builds a value of them. ~s is in the second. Pick another~n"
     "  name.~n",
     [P, L, Name, Name]};

%%% --- the fatal ones ---------------------------------------------------------

message(#{tag := stray_semicolon, file := P, line := L}) ->
    {"~s:~p: error: beam-sharp has no `;`~n"
     "  a declaration ends where the next one begins. Remove it.~n",
     [P, L]};
message(#{tag := lex_error, file := P, line := L, detail := D}) ->
    {"~s:~p: error: ~s~n", [P, L, D]};
message(#{tag := parse_error, file := P, line := L, detail := D}) ->
    {"~s:~p: error: ~s~n", [P, L, D]};
%% Ticket 63. The refusal names the thing to write instead, which is the whole
%% reason the decision went this way rather than leaving a bare syntax error:
%% every comparison the guard fragment admits has an opposite already in the
%% language, so there is always a concrete answer to give.
message(#{tag := no_negation, file := P, line := L, spelling := S}) ->
    {"~s:~p: error: beam-sharp has no `~s`~n"
     "  negation is not an operator here. A guard and a refinement are built~n"
     "  from comparisons, and every comparison has an opposite you can write~n"
     "  directly: `<=` for `not >`, `>=` for `not <`, `!=` for `not ==`,~n"
     "  `==` for `not !=`. Which case a clause takes is the head's job.~n",
     [P, L, S]};
message(#{tag := no_sources_here, file := P}) ->
    {"bsc: no `.bs` files in ~s~n"
     "  a module is a directory holding `.bs` files (41 §5). If this~n"
     "  came from a shell glob, it matched nothing and was passed~n"
     "  through unexpanded — the corpus is one directory per module now.~n",
     [P]};

%%% --- the raised ones --------------------------------------------------------

message(#{tag := behaviour_not_satisfied, file := P, line := L,
          behaviour := B, missing := Missing}) ->
    {"~s:~p: error: behaviour ~s is declared and not satisfied~n"
     "  these callbacks are mandatory and this module does not define them:~n"
     "~s"
     "  a `behaviour` attribute is emitted for the whole contract, so a~n"
     "  partial one would fail when the process starts rather than here.~n",
     [P, L, B, [io_lib:format("    ~s/~p~n", [N, A]) || {N, A} <- Missing]]};
message(#{tag := private_callback, file := P, line := L, name := N,
          arity := A, otp_name := Otp}) ->
    {"~s:~p: error: ~s/~p is `private` and is a callback~n"
     "  this module declares a behaviour that calls it as ~s/~p, and a~n"
     "  behaviour is dispatched through the export list — `-behaviour`~n"
     "  itself has no runtime effect. Private, it would fail when the~n"
     "  process starts rather than here. Mark it `public`.~n",
     [P, L, N, A, Otp, A]};
message(#{tag := unknown_behaviour, file := P, behaviour := B}) ->
    {"~s: error: no behaviour named ~s~n"
     "  the compiler knows `GenServer`, `Supervisor`, `Application`,~n"
     "  `GenStatem` and `GenEvent`.~n",
     [P, B]};
message(#{tag := unknown_type, file := P, type := N}) ->
    {"~s: error: no type named ~s~n"
     "  declare it with `type ~s = ...` or `record ~s { ... }`.~n",
     [P, N, N, N]};
%% F22. The fix is named because the alternative spelling always exists: a
%% property pattern constrains fields without naming a type at all.
message(#{tag := not_a_record, file := P, line := L, type := N}) ->
    {"~s:~p: error: ~s is not a record, so it cannot name a pattern~n"
     "  only a `record` declaration mints the tag a type prefix matches on.~n"
     "  to constrain fields without naming a type, write `{ Field: ... }`.~n",
     [P, L, N]};
%% F22. Shaped on site 2's `not declared by Order` sentence deliberately — the
%% same mistake, met at a different site — and it hands back the field list,
%% which is what ticket 23 asks a diagnostic to do.
message(#{tag := pattern_field_unknown, file := P, line := L, record := R,
          field := F, declared := Declared}) ->
    {"~s:~p: error: ~s is not declared by ~s~n"
     "  ~s declares:~n~s",
     [P, L, F, R, R,
      field_list("", [D || D <- Declared, D =/= 'Kind'])]};
message(#{tag := unknown_builtin, file := P, type := B}) ->
    {"~s: error: ~s is not a builtin type~n"
     "  this slice has `int`, `atom`, `term`, `bool`, `binary`,~n"
     "  `string` and `list<T>`.~n",
     [P, B]};
message(#{tag := opaque_ret_at_boundary, file := P, line := L, module := Mod,
          function := Fun}) ->
    {"~s:~p: error: ~s.~s returns `string`, which a guard cannot decide~n"
     "  `string` is `binary` refined by valid UTF-8, and checking that~n"
     "  reads every byte of a value the sender sizes.~n"
     "  declare it `binary`. Establishing the refinement is the UTF-8~n"
     "  entry check, which this compiler does not have yet.~n",
     [P, L, Mod, Fun]};
%% F19. THE LAST TWO LINES ARE A DEBT NOTICE AND WILL GO STALE — see the note in
%% `features/F19-foreign-try-wrapper.md` under Out of scope, which names this
%% function. They are here rather than left unsaid because an author whose
%% foreign function returns `(:ok, V) | (:error, R)` as ordinary VALUES would
%% otherwise work through several spellings before concluding the form does not
%% exist, and ticket 23's rule is that the debt lives on the channel. When the
%% ticket that decides that case lands, this is the paragraph that changes.
message(#{tag := unknown_generic, file := P, type := N}) ->
    {"~s: error: no type named ~s takes a type argument~n"
     "  the prelude has `list<T>`, `option<T>` and `result<T, E>`;~n"
     "  your own take one with `type ~s<T> = ...`.~n",
     [P, N, N]};
message(#{tag := generic_arity, file := P, type := N, want := Want,
          got := Got}) ->
    {"~s: error: ~s takes ~p type argument~s, and got ~p~n",
     [P, N, Want, plural(Want), Got]};
message(#{tag := needs_type_args, file := P, type := N, want := Want}) ->
    {"~s: error: ~s is parametric and was written without a bracket~n"
     "  it takes ~p type argument~s: write `~s<...>`.~n",
     [P, N, Want, plural(Want), N]};
message(#{tag := not_parametric, file := P, type := N}) ->
    {"~s: error: ~s takes no type arguments~n"
     "  declare it as `type ~s<T> = ...` if it should.~n",
     [P, N, N]};
message(#{tag := cyclic_type, file := P, type := N}) ->
    {"~s: error: the type ~s is defined in terms of itself, and the~n"
     "  recursion does not pass through a constructor~n"
     "  so there is no set of values it could describe -- and that is~n"
     "  not a missing feature. Put the recursion inside a shape (a~n"
     "  tuple, a list, or a record field), or drop it.~n",
     [P, N]};
%% F28 — the third case, and the only one left that a binder cannot hold. The
%% recursion IS through a constructor, so the contractive rule is satisfied and
%% `cyclic_type` above does not apply; what fails is regularity. The message
%% says which argument changed, because that is the one thing the author can
%% act on, and it names the repair rather than only the refusal.
message(#{tag := non_regular_recursion, file := P, type := N}) ->
    {"~s: error: ~s recurs at a different type argument each time~n"
     "  the recursion passes through a constructor, so the definition is~n"
     "  contractive -- but each unfolding names a WIDER argument than the~n"
     "  last, so it never comes back to itself and there is no finite~n"
     "  type to hold it.~n"
     "  Recur at the SAME argument (`~s<X>` inside `~s<X>`), or give the~n"
     "  inner position a concrete type.~n",
     [P, N, N, N]};
%% F31 / ticket 15 §1. TWO MESSAGES, BECAUSE THE HINT IS NOT ONE HINT.
%% 15 §1 wrote `hint: tag it - (:some, atom) | :nothing`, which repairs an
%% absorbed `:nothing` and is nonsense about an absorbed `(:error, E)` - that
%% member is already tagged, so the advice would name a form that does not fix
%% the program. F31 records the split as an assumption rather than a decision:
%% 15 §1 only wrote the one.
message(#{tag := collapsed_failure_channel, file := P, line := L,
          channel := nothing, member := M, absorbed_by := A}) ->
    {"~s:~p: error: `~s` is absorbed by `~s`~n"
     "  the failure channel does not survive normalisation, so the type~n"
     "  declared here IS `~s`. No caller can write the failure clause,~n"
     "  because no failure member is left to match.~n"
     "  hint: tag it - (:some, ~s) | :nothing~n",
     [P, L, M, A, A, A]};
message(#{tag := collapsed_failure_channel, file := P, line := L,
          channel := error, member := M, absorbed_by := A}) ->
    {"~s:~p: error: `~s` is absorbed by `~s`~n"
     "  the failure channel does not survive normalisation, so the type~n"
     "  declared here IS `~s`. No caller can write the failure clause,~n"
     "  because no failure member is left to match.~n"
     "  The failure member already carries its tag, so tagging it again~n"
     "  repairs nothing: narrow the success type until it cannot hold an~n"
     "  `(:error, ...)` of its own.~n",
     [P, L, M, A, A]};
message(#{tag := kind_field_is_minted, file := P, line := L, record := Name}) ->
    {"~s:~p: error: ~s declares a field named Kind~n"
     "  the tag is minted from the type's qualified name, so a record~n"
     "  cannot also declare one. Rename the field.~n",
     [P, L, Name]};
message(#{tag := opaque_refinement, file := P, line := L}) ->
    {"~s:~p: error: this refinement is not a predicate the checker can read~n"
     "  a refinement narrows a type, so the compiler has to be able to~n"
     "  reason about it: comparisons on `value`, joined with `and`/`or`.~n"
     "  `int where value >= 0 and value <= 255` is one.~n"
     "  A predicate that reads the value instead — `WellFormed(value)` —~n"
     "  is the O(n) tier. It is established once at a boundary and never~n"
     "  reasoned about, and this compiler has no site to establish it at.~n",
     [P, L]};
message(#{tag := empty_refinement, file := P, line := L}) ->
    {"~s:~p: error: this refinement admits no values at all~n"
     "  the predicate contradicts itself, so nothing has this type and~n"
     "  no call to a function over it could ever be written.~n",
     [P, L]};
message(#{tag := relational_pattern_nested, file := P, line := L}) ->
    {"~s:~p: error: a relational pattern goes where a whole argument goes~n"
     "  `Classify(>= 4 and <= 7)` is the shipped form. Inside a record~n"
     "  pattern, a tuple or a list it is not built yet — write the~n"
     "  comparison as a guard there: `when o.Total > 100`.~n",
     [P, L]};
%%% F13 — the binary segment refusals.
message(#{tag := unsized_segment_not_last, file := P, line := L}) ->
    {"~s:~p: error: a segment with no width is the REMAINDER~n"
     "  so it can only come last — anything after it would never~n"
     "  match. Give it a width (`payload:16`), size it by a field~n"
     "  bound earlier in the same pattern (`payload:size`), or move~n"
     "  it to the end.~n",
     [P, L]};
message(#{tag := segment_width_not_positive, file := P, line := L, width := N}) ->
    {"~s:~p: error: a segment's width must be a positive number of bits~n"
     "  `~p` is not one. Omit the width entirely to bind the~n"
     "  remainder of the binary.~n",
     [P, L, N]};
message(#{tag := segment_literal_too_wide, file := P, line := L,
          value := K, width := N, max := Max}) ->
    {"~s:~p: error: ~p does not fit in ~p bits~n"
     "  a ~p-bit segment holds 0..~p. The mistake is usually the~n"
     "  WIDTH rather than the value — check the field's size in the~n"
     "  format you are parsing.~n",
     [P, L, K, N, N, Max]};
message(#{tag := segment_size_not_bound, file := P, line := L, name := V}) ->
    {"~s:~p: error: `~s` is not bound where this segment's size needs it~n"
     "  a binary is matched LEFT TO RIGHT, so a size must name a~n"
     "  field bound EARLIER in the same pattern. Erlang accepts this~n"
     "  and the match then silently never succeeds, which is why it~n"
     "  is refused here.~n",
     [P, L, V]};
message(#{tag := name_redeclared, file := P, line := L, name := Name,
          arity := Arity}) ->
    {"~s:~p: error: ~s/~p is declared more than once~n"
     "  a name may carry MORE THAN ONE ARITY, so ~s/~p and ~s/~p would~n"
     "  be two functions — but two signatures of the SAME arity are one~n"
     "  function declared twice, and its clauses would merge silently.~n",
     [P, L, Name, Arity, Name, Arity, Name, Arity + 1]};
message(#{tag := ambiguous_call, file := P, line := L, name := Name,
          arity := Arity, candidates := Mods}) ->
    {"~s:~p: error: ~s/~p is ambiguous — ~p imports declare it~n"
     "  name one of these instead:~n"
     "~s",
     [P, L, Name, Arity, length(Mods),
      [io_lib:format("    ~s.~s(...)~n", [M, Name]) || M <- Mods]]};
message(#{tag := unknown_module, file := P, line := L, module := Mod}) ->
    {"~s:~p: error: `using ~s` names no module and no namespace~n"
     "  a module is a source file this invocation can reach; a namespace~n"
     "  is a path that other modules sit under. Neither matched.~n",
     [P, L, Mod]};
message(#{tag := module_not_imported, file := P, line := L, module := Mod}) ->
    {"~s:~p: error: ~s is called but never imported~n"
     "  add `using ~s` — a file's `using` lines are its dependency list,~n"
     "  and a call that skips them makes that list wrong.~n",
     [P, L, Mod, Mod]};
message(#{tag := ambiguous_module, file := P, line := L, module := Short,
          candidates := Mods}) ->
    {"~s:~p: error: ~s is ambiguous — ~p namespaces hold a module of that name~n"
     "  name one of these in full instead:~n"
     "~s",
     [P, L, Short, length(Mods), [io_lib:format("    ~s~n", [M]) || M <- Mods]]};
message(#{tag := import_cycle, cycle := Cycle}) ->
    {"error: these modules import each other in a cycle~n"
     "~s"
     "  the compiler checks a dependency before its dependents, so a~n"
     "  cycle has no order to check them in. Break it by moving the~n"
     "  shared declarations into a module both can import.~n",
     [[io_lib:format("    ~s~n", [M]) || M <- Cycle]]};
message(#{tag := function_in_index, file := P, line := L, function := Name}) ->
    {"~s:~p: error: ~s is a function, and index.bs holds no functions~n"
     "  index.bs is the module's DECLARATION file — using, type, record~n"
     "  and behaviour. It is also the file every new declaration lands~n"
     "  in, so it is the most contended one in the module by~n"
     "  construction; putting functions there merges it with the one~n"
     "  thing file-per-function exists to keep apart.~n"
     "  Give ~s its own file in the same directory.~n",
     [P, L, Name, Name]};
message(#{tag := module_path_mismatch, file := P, line := L,
          declared := Declared, expected := Expected}) ->
    {"~s:~p: error: `module ~s` does not match its directory~n"
     "  this directory says `module ~s`~n"
     "  a module's declaration and its path are the same name written~n"
     "  twice, and 40 §1 makes the declaration the emitted ATOM — so~n"
     "  when they disagree the atom and the tree have drifted apart.~n"
     "  Rename the directory, fix the declaration, or name the source~n"
     "  root with --src-root if this tree is rooted somewhere else.~n",
     [P, L, Declared, Expected]};
message(#{tag := module_disagreement, count := Count,
          declarations := Declared}) ->
    {"error: one directory is one module, and this one declares ~p~n"
     "~s"
     "  every `.bs` file in a directory compiles into the same `.beam`,~n"
     "  so these are not two modules — they are one module that cannot~n"
     "  decide on its name. A file with no `module` line inherits the~n"
     "  directory's, which is the usual way to write the others.~n",
     [Count, [io_lib:format("    ~s:~p: module ~s~n", [Pa, L, M])
              || {Pa, M, L} <- Declared]]};
message(#{tag := no_module_declaration, files := Paths}) ->
    {"error: this directory holds `.bs` files and no `module` line~n"
     "~s"
     "  a directory holding `.bs` files is a module (41 §5) and a module~n"
     "  needs a name. Put `module Something` in index.bs and the rest~n"
     "  of the files inherit it.~n",
     [[io_lib:format("    ~s~n", [Pa]) || Pa <- Paths]]};
message(#{tag := src_root_mismatch, directory := Dir, root := Root}) ->
    {"bsc: --src-root ~s does not contain ~s~n"
     "  the source root is the directory module paths are relative to,~n"
     "  so it has to be an ancestor of the module being compiled.~n",
     [Root, Dir]};
message(#{tag := src_root_is_the_module, directory := Dir}) ->
    {"bsc: --src-root ~s is the module directory itself~n"
     "  a module needs at least one path segment below the root to take~n"
     "  its name from. Name the root one level up.~n",
     [Dir]};

%%% --- the remainder ----------------------------------------------------------
%%%
%%% NO CATCH-ALL BEYOND THIS ONE, and it is reached only through the
%%% `unclassified` tag `descriptor/2` mints for a diagnostic shape it does not
%%% know. A tag with no clause here CRASHES rather than rendering something
%%% generic, which is F16.7: a generic renderer would let a new diagnostic ship
%%% looking like it had a message.

message(#{tag := unclassified, file := P, detail := D}) ->
    {"~s: ~p~n", [P, D]}.

%%% ---------------------------------------------------------------------------
%%% Head synthesis — 23 §2, and ticket 43's cap
%%%
%%% THE COMPILER SYNTHESISES THE HEAD, NEVER THE BODY. The residual is a *set*
%%% and a clause head is a *pattern plus a guard*; lowering one to the other is a
%%% real compilation step, and it lives here so that consumers never each invert
%%% it differently. A head is derived from the residual and cannot be wrong; a
%%% body is a guess, and one bad suggestion poisons every good one.
%%%
%%% THE TERM CARRIES ALL OF THEM AND THE PROSE CARRIES THREE. Ticket 43 wrote
%%% this down when it capped the prose: *"the descriptor keeps all forty-one"*.
%%% So what travels in the descriptor is the residual's PARTS, per argument, per
%%% product — never finished text — because prose cannot be a pure function of a
%%% term that was truncated before it got here.
%%% ---------------------------------------------------------------------------

%% The residual's tuple part is the *argument list*, so each product is a clause
%% head the author can paste in.
heads(Fn, Residual, Names) ->
    #{tuples := Products} = Residual,
    case Products of
        [] -> #{kind => residual_only, parts => parts(Residual)};
        _  ->
            Base = #{kind => products,
                     products => [[parts(C) || C <- P] || P <- Products]},
            %% F29.9 — ABSENT, NOT EMPTY, AND BOTH KEYS WHERE THE RESIDUAL IS
            %% MIXED. A cofinite atom set and `binary \ string` are sets the
            %% surface has no pattern for, and `pasteable => []` invites a
            %% consumer to render an empty list as though it were a suggestion.
            %%
            %% THE SPLIT IS PER PRODUCT, not per residual, because a residual can
            %% be part spellable and part not: `Classify(int n, atom a)` leaves
            %% one product with forty-one heads and forty products whose atom
            %% component is `atom \ (:x)`. Reporting only the heads would show a
            %% list of clauses that does not cover the residual and say nothing
            %% about the rest — wrong by omission rather than by content. So the
            %% unspellable products are carried beside the heads.
            {Lines, Unspellable} =
                lists:foldl(fun(P, {Ls, Us}) ->
                                    case pasteable(Fn, P, Names) of
                                        [] -> {Ls, [product_str(P) | Us]};
                                        L  -> {Ls ++ L, Us}
                                    end
                            end, {[], []}, Products),
            with_description(with_pasteable(Base, Lines), lists:reverse(Unspellable))
    end.

with_pasteable(Base, [])    -> Base;
with_pasteable(Base, Lines) -> Base#{pasteable => Lines}.

with_description(Base, [])  -> Base;
with_description(Base, Ds)  -> Base#{description => Ds}.

%% One product as a description. Untruncated, like everything else the term
%% carries — the prose is where ticket 43's cap lives.
product_str(P) ->
    lists:flatten(["(", lists:join(", ", [join(parts(C), infinity) || C <- P]), ")"]).

%% ONE HEAD PER LINE, WHICH IS F29.2 AND IS WHY THIS IS A LIST.
%%
%% A residual argument is a UNION and a clause head is not: `Classify(<= 199 |
%% 300..399)` is a syntax error, and joining the parts with `|` was the printer
%% asserting a form the grammar has never had. So the parts are expanded across
%% the arguments and each combination is its own head — which is also why the
%% count can exceed the product count, and why ticket 43's cap counts LINES.
%%
%% `name_binders/1` runs on the assembled line rather than on the parts, because
%% two binders spelled the same in one head is `repeated_in_head` — the very
%% defect `RecordInList` was filed for — and no part can see its siblings.
%% The arrow is appended AFTER the binders are named, because naming is also
%% where a nested span's `when` clause is hoisted to, and a guard goes before the
%% arrow rather than after it.
pasteable(Fn, Product, Names) ->
    [lists:flatten(bs_types:name_binders(
                     io_lib:format("~s(~s)", [Fn, lists:join(", ", Combo)]))
                   ++ " -> ...")
     || Combo <- bs_types:head_combos(Product, Names)].

heads_prose(_Fn, #{kind := residual_only, parts := Parts}) ->
    io_lib:format("    ~s~n", [join(Parts, ?RESIDUAL_CASES)]);
%% F29.10 — THE PROSE IS A PREFIX OF THE TERM CHANNEL, now by construction. The
%% claim below used to be that the two "cannot say different things"; it was true
%% on content and false on completeness, because the term joined at `infinity`
%% and the prose capped, from two separate expressions. They are one expression
%% now, and the cap is the only difference between them.
heads_prose(_Fn, H = #{kind := products, pasteable := Lines}) ->
    [cap([io_lib:format("    ~s~n", [L]) || L <- Lines]), unspellable_prose(H)];
heads_prose(_Fn, H = #{kind := products}) ->
    unspellable_prose(H).

%% CAPPED LIKE THE HEADS, and for the same reason: ticket 43 scoped its rule to
%% *"at most three of whatever it is enumerating"*, and this is enumerating too.
%% Uncapped, a two-argument residual printed forty-one products on one line.
unspellable_prose(#{description := Ds}) ->
    [io_lib:format("  and no pattern spells:~n", []),
     cap([io_lib:format("    ~s~n", [D]) || D <- Ds])];
unspellable_prose(_) -> [].

%% THE RULE APPLIES TO HEAD LINES TOO, AND AT TWO DEPTHS AT ONCE. A residual over
%% a two-argument function is a PRODUCT, so the head count is the product of the
%% parts — a rule that stayed on intervals would print an unbounded number of
%% lines the moment a second argument had a residual too. Measured before this
%% was written: forty singleton clauses over `(int, atom)` print 41 head lines,
%% one of them itself truncated.
cap(Lines) when length(Lines) =< ?RESIDUAL_CASES -> Lines;
cap(Lines) ->
    {Shown, Rest} = lists:split(?RESIDUAL_CASES, Lines),
    Shown ++ [io_lib:format("    ... (~p more)~n", [length(Rest)])].

%% ASCII `...`, not `…`. A diagnostic goes to stderr through terminals the
%% compiler does not control, and the ellipsis character buys two columns.
join(Parts, infinity) ->
    lists:flatten(lists:join(" | ", Parts));
join(Parts, N) when length(Parts) =< N ->
    lists:flatten(lists:join(" | ", Parts));
join(Parts, N) ->
    {Shown, Rest} = lists:split(N, Parts),
    lists:flatten([lists:join(" | ", Shown),
                   io_lib:format(" | ... (~p more)", [length(Rest)])]).

parts(Ty) -> bs_types:pattern_parts(Ty).

%% Published untruncated, for the same reason `heads` is.
residual(Ty) -> join(parts(Ty), infinity).

%% The caller's head with the rejected values in the position that rejected
%% them. Only synthesised when the argument IS a whole parameter — an arbitrary
%% expression has no position in the head to put a pattern in, and inventing one
%% would hand back something that does not compile. `none` is 23 §2's *"where
%% the residual is not expressible the term says so and offers nothing"*.
%% F29 — A PASTE SITE, SO IT USES THE HEAD PRINTER AND RETURNS A LIST.
%%
%% This read `to_pattern/1`, which is the DESCRIPTION printer: an interval
%% residual produced `F(int <= 5, _) -> ...` under the heading *"the clause to
%% add here"*, and that head does not parse. It is the same defect as the
%% inexhaustive site, at the one place a reader is most likely to paste from,
%% and nothing found it because a printer is not part of any surface being added.
%%
%% A list, for F29.2's reason: the residual is a union and a clause head is not.
%% `none` where the argument is not a whole parameter, and `none` again where no
%% part of the residual has a pattern — 23 §2's *"where the residual is not
%% expressible the term says so and offers nothing"*, which is now reachable
%% rather than aspirational.
caller_head(_Fn, none, _Residual) -> none;
caller_head(Fn, {Pos, Arity, Names}, Residual) ->
    case bs_types:head_parts(Residual, Names) of
        [] -> none;
        Parts ->
            [lists:flatten(
               bs_types:name_binders(
                 io_lib:format("~s(~s)",
                               [Fn, lists:join(", ", slots(Pos, Arity, Part))]))
               ++ " -> ...")
             || Part <- Parts]
    end.

slots(Pos, Arity, Part) ->
    [case I of Pos -> Part; _ -> "_" end || I <- lists:seq(1, Arity)].

caller_head_prose(_Fn, none) -> "";
caller_head_prose(_Fn, Heads) ->
    ["  the clause to add here:\n",
     cap([io_lib:format("    ~s~n", [H]) || H <- Heads])].

%% Construction supplies a field set; `with` updates one. Ticket 26 §2 is the
%% reason `update` can never carry a `Missing` list.
field_set_verb(construction) -> "builds";
field_set_verb(update)       -> "updates".

field_list(_Label, [])    -> "";
field_list(Label, Fields) ->
    io_lib:format("~s:~n    ~s~n",
                  [Label, lists:join(", ", [atom_to_list(F) || F <- Fields])]).

plural(1) -> "";
plural(_) -> "s".
