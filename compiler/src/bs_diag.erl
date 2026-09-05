%%% bs_diag — the diagnostic as a term, and prose as a pure function of it.
%%%
%%% `descriptor/2` builds the term and `message/1` owns every format string;
%%% prose is derived from the term, never written beside it. Nothing else in
%%% the compiler may print a diagnostic: `bin/check-diagnostics.sh` refuses a
%%% direct `io:format` at a report site, because such a site would pass every
%%% test while its output silently left the term channel (F16, ticket 23 §1).
%%%
%%% `message/1` returns `{Fmt, Args}` rather than finished text because some
%%% format strings carry an em dash: re-rendering finished text through `~s`
%%% is a `badarg` above codepoint 255, and `~ts` is a different encoding path
%%% from the one the tests were measured on. So `emit/2` prints the pair as
%%% it is, and `format/1`, the published pure function, is defined in terms
%%% of `message/1` rather than beside it.
%%%
%%% The descriptor is full fidelity and the prose is lossy: `residual` and
%%% `heads` carry every case, and `message/1` caps at ?RESIDUAL_CASES on the
%%% way out. So the residual travels as parts, never as finished text, since
%%% prose cannot be a pure function of an already-truncated term (ticket 43).
%%%
%%% Payloads are maps, not tuples, so a payload can gain a key without
%%% breaking a matcher: evolution is additive only (ticket 23 §4).
-module(bs_diag).

-export([descriptor/2, format/1, message/1, emit/2]).
-export([channel/0, set_channel/1, contractual/0]).

%% Three or fewer cases print in full, so the truncated form is the exact form
%% at the threshold and there is no second shape to switch into (ticket 43).
-define(RESIDUAL_CASES, 3).

%%% ---------------------------------------------------------------------------
%%% The channel
%%%
%%% Under `--diagnostics term` the prose goes to stderr exactly as before and
%%% the descriptor goes to stdout, so a consumer redirects rather than parses
%%% (F16; ticket 23 §1 names no flag).
%%%
%%% The flag is refused in the REPL rather than downgraded: `ibs` prints
%%% values on stdout, so stdout could not carry descriptors alone, and a flag
%%% accepted and ignored is a flag nobody can trust the next time.
%%%
%%% The channel lives in the process dictionary because the report sites
%%% (`parse_string/2`, `parse_path/1`, `load_unit/1` in `bsc`) have no
%%% `#opts{}` in scope. `set_channel/1` is called from the CLI's `dispatch/2`
%%% and nowhere else, so a library caller and every in-process test get
%%% `prose`; the CLI is a fresh process per run, so nothing leaks between.
%%% ---------------------------------------------------------------------------

%% Only `prose` and `term` exist, and the guard asserts that internal
%% invariant rather than validating input: `parse_args` halts on any other
%% value, so a third one here means the CLI grew a way to produce it and this
%% should stop rather than guess.
set_channel(Chan) when Chan =:= prose; Chan =:= term ->
    put(bs_diag_channel, Chan).

channel() ->
    case get(bs_diag_channel) of
        undefined -> prose;
        Chan      -> Chan
    end.

%% The tags whose payload shape is frozen: those that hand the author
%% something to write (ticket 23 §4; the membership test is §2's). A syntax
%% error does not, so it is structured and renderable but carries no shape
%% promise. `defended` is named contractual by §4 and is absent because no
%% feature has built it. `return_not_declared` qualifies since F25 gave it a
%% signature to paste.
contractual() ->
    [inexhaustive, catch_all_over_closed, switch_inexhaustive,
     arg_not_accepted, unreachable_clause, unreachable_arm,
     return_not_declared].

%%% ---------------------------------------------------------------------------
%%% Publishing
%%% ---------------------------------------------------------------------------

%% The prose goes where it always went; the term goes to stdout only when
%% asked for, so the default prints nothing new. One descriptor per line, and
%% `~0p` is what makes that true: plain `~p` wraps each descriptor across
%% lines with nothing between one and the next, so a consumer would have to
%% match brackets. Under `~0p` the newline is the frame (ticket 23).
emit(Chan, Desc) ->
    case Chan of
        term -> io:format("~0p~n", [Desc]);
        _    -> ok
    end,
    {Fmt, Args} = message(Desc),
    io:format(standard_error, Fmt, Args).

%% The published pure function: prose is this, applied to the term.
format(Desc) ->
    {Fmt, Args} = message(Desc),
    io_lib:format(Fmt, Args).

%%% ---------------------------------------------------------------------------
%%% descriptor/2 — the returned diagnostics (what `bsc:report/2` publishes)
%%%
%%% This heading carries no clause count: no gate reads one, so it drifts as
%%% tags are added (ENG-269).
%%% ---------------------------------------------------------------------------

%% Every returned diagnostic carries these four keys. Severity travels as data
%% rather than being implied by the tag, because `unreachable_clause` and
%% `unreachable_arm` are warnings amid errors, and a consumer should not
%% re-derive what the compiler already decided.
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
%%% Each way a binary segment can be wrong gets its own tag, so the message
%%% can name the fix for that shape (F13).
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
%% The operator is carried because the two division operators spell the same
%% mistake differently, and the fix differs with it (F26, ticket 38).
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
%% The arm twins of `vacuous_clause` and `unsatisfiable_guard` below. They are
%% tags of their own rather than one tag per fault shared across both sites,
%% because a consumer matches on the tag and then reads the keys: one tag
%% carrying `clause_number` at one site and `arm_number` at the other would
%% leave the key set undetermined by the tag (ENG-269 proposed reusing
%% `unsatisfiable_guard`; this is the one departure from it).
descriptor(Path, {Sev, Line, Fn, {vacuous_arm, N, Domain}}) ->
    (at(Sev, Path, Line, Fn))#{tag => vacuous_arm, arm_number => N,
                               domain => residual(Domain)};
descriptor(Path, {Sev, Line, Fn, {unsatisfiable_arm_guard, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unsatisfiable_arm_guard, arm_number => N};
descriptor(Path, {Sev, Line, Fn, switch_in_guard}) ->
    (at(Sev, Path, Line, Fn))#{tag => switch_in_guard};
descriptor(Path, {Sev, Line, Fn, {unreachable_clause, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unreachable_clause, clause_number => N};
%% `vacuous_clause` carries the domain rather than the offending pattern: the
%% author wrote the pattern, so the type it is not a member of is the half
%% they lack. It goes through `residual/1` so the term keeps the parts and
%% the prose stays a pure function of it (ENG-259, F16).
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
%% The residual is a type, so the exhaustiveness printer renders it and this
%% is a new tag rather than a new shape of diagnostic (ticket 36).
descriptor(Path, {Sev, Line, Fn, {field_value_not_accepted, Record, Field, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => field_value_not_accepted,
                               record => Record,
                               field => Field,
                               residual => residual(Residual),
                               rejected => bs_types:to_pattern(Residual)};
%% The verb is read from the form: a dot projects a field from a value and
%% `with` updates one on it, while the residual and the fix are the same for
%% both, the member that lacks the field (ENG-249).
descriptor(Path, {Sev, Line, Fn, {field_absent, Form, Field, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => field_absent,
                               form => Form,
                               field => Field,
                               residual => residual(Residual),
                               member => bs_types:to_pattern(Residual)};
%% `corrected` is `none` when there is nothing writable to offer, never
%% absent, so a consumer never has to tell "refused" from "missing" (F25).
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
%%% The two call-site refusals for a reserved qualifier. The shadow one is
%%% `ambiguous_module` with a compiler-known claimant on one side, so it is
%%% shaped like it: both candidates named, the full path offered (ticket 67).
descriptor(Path, {Sev, Line, Fn, {reserved_qualifier_shadowed, Q, Op, Mods}}) ->
    (at(Sev, Path, Line, Fn))#{tag => reserved_qualifier_shadowed,
                               qualifier => Q, operation => Op,
                               candidates => Mods};
descriptor(Path, {Sev, Line, Fn,
                  {unknown_reserved_operation, Q, Op, Got, Have}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unknown_reserved_operation,
                               qualifier => Q, operation => Op,
                               got => Got, declared => Have};
descriptor(Path, {Sev, Line, Fn, {unknown_record, Name}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unknown_record, record => Name};
descriptor(Path, {Sev, Line, Fn, wildcard_as_value}) ->
    (at(Sev, Path, Line, Fn))#{tag => wildcard_as_value};

%%% --- The codegen-obligation refusals (F18) ---------------------------------

%% The collapse met at an instantiation rather than at a declaration. The
%% descriptor carries the type, not the sentence, so a consumer can see which
%% instantiation was asked for (ticket 15 §1).
descriptor(Path, {Sev, Line, Fn, {validate_collapses, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => validate_collapses,
                               type => bs_types:to_string(Ty)};
descriptor(Path, {Sev, Line, Fn, {validate_domain_map, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => validate_domain_map,
                               type => bs_types:to_string(Ty)};
descriptor(Path, {Sev, Line, Fn, {map_pattern_deferred, Site, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => map_pattern_deferred,
                               site => Site,
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

%% beam-sharp has no statement terminator and both audiences type one from
%% habit, so this most likely error gets a sharper message than leex's tuple.
descriptor(Path, {lex, {Line, _Mod, {illegal, ";"}}}) ->
    #{tag => stray_semicolon, severity => error, file => Path, line => Line};
%% Negation has no spelling: the guard fragment is closed under complement,
%% so a `not` would compile into the spelling the author could have written,
%% and the refusal teaches that instead (ticket 63; `bin/check-negation.sh`
%% is the gate). `!` is an illegal character, so it fails here in the lexer,
%% a stage before `not` does. `!=` is a token of its own and never arrives
%% as an illegal character.
descriptor(Path, {lex, {Line, _Mod, {illegal, [$! | _]}}}) ->
    #{tag => no_negation, severity => error, file => Path, line => Line,
      spelling => "!"};
descriptor(Path, {lex, {Line, Mod, Reason}}) ->
    #{tag => lex_error, severity => error, file => Path, line => Line,
      detail => lists:flatten(Mod:format_error(Reason))};
%% `not` is a legal identifier and must not become a keyword (reserving names
%% is ticket 65's open question), so the hint is raised here, at the parse
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
%% Most often an unmatched shell glob rather than a real directory, so the
%% message says what was looked for instead of only naming the path (F15).
descriptor(Path, no_sources_here) ->
    #{tag => no_sources_here, severity => error, file => Path};

%%% ---------------------------------------------------------------------------
%%% The raised conditions (what `bsc:resolve_error/2` catches)
%%%
%%% These are found while resolving types, below the level that carries a
%%% line and a function name, and reach the author through the `try` in
%%% `check_and_emit/4`. A raised condition gets a descriptor exactly like a
%%% returned one; there is no second channel (F16.4).
%%% ---------------------------------------------------------------------------

%% A raise site that knows its file says so; the inner tuple keeps the shape
%% ticket 41 specified.
descriptor(_Path, {in_file, Path, Reason}) ->
    descriptor(Path, Reason);

descriptor(Path, {behaviour_not_satisfied, Line, Behaviour, Missing}) ->
    #{tag => behaviour_not_satisfied, severity => error, file => Path,
      line => Line, behaviour => Behaviour, missing => Missing};
%% `-behaviour` has no runtime effect and only exports matter, so a private
%% callback would break the contract at run time and silently (ticket 06).
descriptor(Path, {private_callback, N, A, Otp, Line}) ->
    #{tag => private_callback, severity => error, file => Path, line => Line,
      name => N, arity => A, otp_name => Otp};
descriptor(Path, {unknown_behaviour, B}) ->
    #{tag => unknown_behaviour, severity => error, file => Path, behaviour => B};
descriptor(Path, {unknown_type, N}) ->
    #{tag => unknown_type, severity => error, file => Path, type => N};
%% A type prefix in a pattern names something that is not a record (F22).
descriptor(Path, {not_a_record, Line, N}) ->
    #{tag => not_a_record, severity => error, file => Path, line => Line,
      type => N};
%% A field named beside a type prefix that the record has not got (F22).
descriptor(Path, {pattern_field_unknown, Line, Record, Field, Declared}) ->
    #{tag => pattern_field_unknown, severity => error, file => Path,
      line => Line, record => Record, field => Field, declared => Declared};
descriptor(Path, {unknown_builtin, B}) ->
    #{tag => unknown_builtin, severity => error, file => Path, type => B};
%% The message names the replacement, because the fix is always the same edit
%% and the reason is not obvious from the rule (F9.11).
descriptor(Path, {opaque_ret_at_boundary, Line, Mod, Fun}) ->
    #{tag => opaque_ret_at_boundary, severity => error, file => Path,
      line => Line, module => bs_types:atom_str(Mod), function => Fun};
descriptor(Path, {unknown_generic, N}) ->
    #{tag => unknown_generic, severity => error, file => Path, type => N};
%% A bracket the compiler knows at the wrong arity is a different mistake from
%% a bracket it does not know, and the fix is a different edit (F6.6).
descriptor(Path, {generic_arity, N, Want, Got}) ->
    #{tag => generic_arity, severity => error, file => Path, type => N,
      want => Want, got => Got};
descriptor(Path, {needs_type_args, N, Want}) ->
    #{tag => needs_type_args, severity => error, file => Path, type => N,
      want => Want};
descriptor(Path, {not_parametric, N}) ->
    #{tag => not_parametric, severity => error, file => Path, type => N};
%% A type defined in terms of itself with no constructor between describes no
%% set of values, and no implementation could give it one (F6.8, ticket 09
%% §3). Recursion through a constructor is well formed and has had a binder
%% since F28, so there is no "unbuilt" refusal beside this one any more.
descriptor(Path, {cyclic_type, N}) ->
    #{tag => cyclic_type, severity => error, file => Path, type => N};
%% A parametric alias that recurs under different arguments, such as
%% `type T<X> = (X, list<T<list<X>>>)`, is not a regular tree: unfolding it
%% never repeats, so no finite binder holds it. Refused by name because the
%% alternative is expanding forever (F28).
descriptor(Path, {non_regular_recursion, N}) ->
    #{tag => non_regular_recursion, severity => error, file => Path, type => N};
%% Stratum 2 of the prelude is compiler-known and a user may not redeclare it.
%% Refused at the declaration rather than resolved by shadowing, because the
%% alternative is a type error elsewhere with nothing pointing at the cause
%% (F18, ticket 27 §8, `PRELUDE.md`).
descriptor(Path, {compiler_known_type, Name, Line}) ->
    #{tag => compiler_known_type, severity => error, file => Path, line => Line,
      type => Name};
descriptor(Path, {kind_field_is_minted, Line, Name}) ->
    #{tag => kind_field_is_minted, severity => error, file => Path, line => Line,
      record => Name};
%% The collapse refused at the declaration. The descriptor carries the channel
%% as well as the two types, because the hint differs by channel and a
%% consumer should not parse the sentence to learn which (F31, ticket 15 §1).
descriptor(Path, {collapsed_failure_channel, Line, Channel, Member, Absorber}) ->
    #{tag => collapsed_failure_channel, severity => error, file => Path,
      line => Line, channel => Channel,
      member => bs_types:to_string(Member),
      absorbed_by => bs_types:to_string(Absorber)};
%% The two refinement tiers are told apart by what the predicate says (F2,
%% ticket 20 §5).
descriptor(Path, {opaque_refinement, Line}) ->
    #{tag => opaque_refinement, severity => error, file => Path, line => Line};
descriptor(Path, {empty_refinement, Line}) ->
    #{tag => empty_refinement, severity => error, file => Path, line => Line};
%% A relational pattern ships in the parameter position only, and a bare
%% "syntax error" would make that chosen omission look like an oversight (F2).
descriptor(Path, {relational_pattern_nested, Line}) ->
    #{tag => relational_pattern_nested, severity => error, file => Path,
      line => Line};
%% Two signatures of the same arity are one function declared twice, and its
%% clauses would otherwise merge silently (ticket 40 §2).
descriptor(Path, {name_redeclared, Name, Arity, Line}) ->
    #{tag => name_redeclared, severity => error, file => Path, line => Line,
      name => Name, arity => Arity};
%% The candidates print qualified because a qualified call is legal whatever
%% is in scope, so the message is pasteable source (ticket 41 §2, 23).
descriptor(Path, {ambiguous_call, Name, Arity, Mods, Line}) ->
    #{tag => ambiguous_call, severity => error, file => Path, line => Line,
      name => Name, arity => Arity, candidates => Mods,
      heads => [lists:flatten(io_lib:format("~s.~s(...)", [M, Name]))
                || M <- Mods]};
descriptor(Path, {unknown_module, Mod, Line}) ->
    #{tag => unknown_module, severity => error, file => Path, line => Line,
      module => Mod};
%% A file's `using` lines are its dependency list, so a call that skips them
%% is refused (ticket 41 §1, 23 §11).
descriptor(Path, {module_not_imported, Mod, Line}) ->
    #{tag => module_not_imported, severity => error, file => Path, line => Line,
      module => Mod};
descriptor(Path, {ambiguous_module, Short, Mods, Line}) ->
    #{tag => ambiguous_module, severity => error, file => Path, line => Line,
      module => Short, candidates => Mods};
%%% The declaration refusal for a reserved qualifier. Raised, so it carries its
%%% own line, like `module_path_mismatch`: there is no function to attribute
%%% it to, only a directory and a `module` line (ticket 67).
descriptor(Path, {reserved_module_name, Module, Line}) ->
    #{tag => reserved_module_name, severity => error, file => Path, line => Line,
      module => Module};
%% Two modules importing each other are refused by name rather than resolved
%% by following the cycle, which is a loop; F6's cyclic-alias guard is the
%% precedent, and it shipped after a hang (ticket 41).
descriptor(_Path, {import_cycle, Cycle}) ->
    #{tag => import_cycle, severity => error, cycle => Cycle};
%% `index.bs` holds everything except functions (ticket 41 §4).
descriptor(Path, {function_in_index, Name, Line}) ->
    #{tag => function_in_index, severity => error, file => Path, line => Line,
      function => Name};
%% A module's declared name must match its directory: `erlc`'s module-atom
%% and filename rule, lifted from the artefact to the source tree (ticket 41
%% §5, 13).
descriptor(Path, {module_path_mismatch, Declared, Expected, Line}) ->
    #{tag => module_path_mismatch, severity => error, file => Path, line => Line,
      declared => Declared, expected => Expected};
%% One directory is one module (ticket 13 §3).
descriptor(_Path, {module_disagreement, Declared}) ->
    #{tag => module_disagreement, severity => error,
      count => length(lists:usort([M || {_, M, _} <- Declared])),
      declarations => Declared};
descriptor(_Path, {no_module_declaration, Paths}) ->
    #{tag => no_module_declaration, severity => error, files => Paths};
%% The build tool's whole job is to name the source root, so a root that does
%% not contain the module is a usage error (ticket 41 §3).
descriptor(_Path, {src_root_mismatch, Dir, Root}) ->
    #{tag => src_root_mismatch, severity => error, directory => Dir,
      root => Root};
descriptor(_Path, {src_root_is_the_module, Dir}) ->
    #{tag => src_root_is_the_module, severity => error, directory => Dir};

%%% ---------------------------------------------------------------------------
%%% The remainder
%%%
%%% A raised tuple with no clause here comes back as `unhandled`, and the
%%% caller re-raises it rather than swallowing it, so the author sees a stack
%%% trace rather than nothing.
%%% ---------------------------------------------------------------------------

descriptor(Path, {Sev, _Line, _Fn, _} = D) when Sev =:= error; Sev =:= warning ->
    #{tag => unclassified, severity => Sev, file => Path, detail => D};
descriptor(_Path, _Other) ->
    unhandled.

%%% ---------------------------------------------------------------------------
%%% `not` in prefix position
%%%
%%% The hint is keyed on a shape, not on the token yecc reported, because the
%%% two positions it covers fail at different tokens (ticket 63):
%%%
%%%     when not (n > 100)            syntax error before: '('
%%%     int where not (value > 100)   syntax error before: '>'
%%%
%%% It cannot fire on a valid program: it runs only after the parse has
%%% failed, and `not` followed by an operand cannot parse anyway, because
%%% applying a variable would need an arrow and the language has no lambda
%%% (F6). A bare `not` used as a variable, followed by an operator, a comma or
%%% a bracket, is untouched. If lambdas ever arrive, `not (` becomes
%%% parseable and this rule needs revisiting.
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
%%% Every format string lives here and nowhere else, so prose changes in one
%%% place. The tests, the gates and the shipping documents replay these
%%% strings, and a change to one is a change to what they assert. This is a
%%% weaker promise than `contractual/0` above, which freezes the payload
%%% *shape* of seven tags (ticket 23 §4); no clause's prose is frozen by that
%%% list, and not every string here is replayed by something.
%%% ---------------------------------------------------------------------------

message(#{tag := inexhaustive, file := P, line := L, function := Fn,
          heads := Heads}) ->
    {"~s:~p: error: ~s is not exhaustive~n"
     "  no clause matches:~n~s",
     [P, L, Fn, heads_prose(Fn, Heads)]};
%% A catch-all is legal only over an open residual, and this message has to
%% carry a conditionally legal `_` to a reader from C# or TypeScript who has
%% never met one. So it says why the residual is closed and hands back the
%% cases: the residual is the missing case, so what makes the error
%% legitimate is what answers it (ticket 12 §2, 04).
message(#{tag := catch_all_over_closed, file := P, line := L, function := Fn,
          heads := Heads}) ->
    {"~s:~p: error: ~s discards cases the compiler can name~n"
     "  every value left here comes from a type you declared, so `_`~n"
     "  hides a case rather than admitting an unknown one:~n~s"
     "  a catch-all is for a residual with an unbounded top in it — a~n"
     "  `term` argument, or the open atom universe — where a foreign~n"
     "  sender chooses the inhabitants and there is nothing to enumerate.~n",
     [P, L, Fn, heads_prose(Fn, Heads)]};
%% The construct is a head's, so the message says where to put it rather than
%% only that it is wrong (F2).
message(#{tag := relational_in_bind, file := P, line := L, function := Fn}) ->
    {"~s:~p: error: ~s binds a relational pattern~n"
     "  `>= 4` names a span of values and introduces no name, so there~n"
     "  is nothing for a bind to bind. A bind must also be provably~n"
     "  irrefutable, and a span is the refutable construct itself.~n"
     "  Dispatch on it in a clause head instead.~n",
     [P, L, Fn]};
message(#{tag := no_clauses, file := P, line := L, function := Fn}) ->
    {"~s:~p: error: ~s has a signature but no clauses~n", [P, L, Fn]};
%% Only a divisor proved to be zero is refused, and the message says so,
%% because a reader's next question is whether every call site needs a
%% non-zero proof. It does not (ticket 23 §2).
message(#{tag := divide_by_zero, file := P, line := L, function := Fn,
          op := Op}) ->
    {"~s:~p: error: the right-hand side of `~s` in ~s is always zero~n"
     "  `~s` needs no proof that a divisor is non-zero — a divisor that MIGHT~n"
     "  be zero compiles and crashes at run time. Only one the compiler can~n"
     "  prove is zero is refused, and this is one.~n",
     [P, L, Op, Fn, Op]};
%% Not routed through the head printer: that prints `Fn(:cancelled) -> ...`,
%% and a switch has no function name and its arrow is `=>` (ticket 17 §6).
message(#{tag := switch_inexhaustive, file := P, line := L, function := Fn,
          arm := Arm}) ->
    {"~s:~p: error: this switch in ~s is not exhaustive~n"
     "  no arm matches:~n"
     "    ~s => ...~n",
     [P, L, Fn, Arm]};
%% A valve over a value with no `(:error, _)` member generates an arm that can
%% never match, but the author wrote no arms; they wrote the wrong operator,
%% so the diagnostic names the right one (F14 §4).
message(#{tag := valve_on_infallible, file := P, line := L, function := Fn,
          subject := Ty}) ->
    {"~s:~p: error: this |?> in ~s is over a value that cannot fail~n"
     "  ~s has no (:error, _) member, so the valve would never stop.~n"
     "  Write |> instead.~n",
     [P, L, Fn, Ty]};
%% Arm, not clause: a construct with no clauses in it cannot be told which
%% clause is dead.
message(#{tag := unreachable_arm, file := P, line := L, function := Fn,
          arm_number := N}) ->
    {"~s:~p: warning: arm ~p of this switch in ~s is unreachable~n"
     "  every value it matches is matched by an earlier arm.~n",
     [P, L, N, Fn]};
%% "Arm" is not the only word that changes from the clause pair: an arm has a
%% third repair, because the subject is right there and may itself be the
%% mistake (ENG-269).
message(#{tag := vacuous_arm, file := P, line := L, function := Fn,
          arm_number := N, domain := Dom}) ->
    {"~s:~p: warning: arm ~p of this switch in ~s matches no value~n"
     "  the subject's type is ~s, and this arm's pattern is not a~n"
     "  member of it — so no value reaching this switch can take~n"
     "  this arm.~n",
     [P, L, N, Fn, Dom]};
%% This one must not name the type: the pattern is a good member of it, and
%% the guard is what admits nothing.
message(#{tag := unsatisfiable_arm_guard, file := P, line := L, function := Fn,
          arm_number := N}) ->
    {"~s:~p: warning: arm ~p of this switch in ~s has an unsatisfiable guard~n"
     "  the pattern is a member of the subject's type; it is the~n"
     "  guard that admits nothing. Widen the guard, or delete the arm.~n",
     [P, L, N, Fn]};
%% A guard shares the whole expression grammar, so a switch parses inside one
%% and is refused here rather than in the grammar (F7).
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
%% Neither of the next two has an earlier clause covering it, so neither may
%% borrow `unreachable_clause`'s wording. This one names the type, because
%% the pattern is not a member of it and that is what the author got wrong:
%% `option<T>` is `T | :nothing`, untagged, so a `(:some, x)` brought from
%% C#, Rust or F# matches nothing at all (ENG-259).
message(#{tag := vacuous_clause, file := P, line := L, function := Fn,
          clause_number := N, domain := Dom}) ->
    {"~s:~p: warning: clause ~p of ~s matches no value of its input~n"
     "  the declared input is ~s, and this clause's pattern is not~n"
     "  a member of it — so no call can reach this clause.~n",
     [P, L, N, Fn, Dom]};
%% This one must not name the type: the pattern is a good member of it, and
%% the guard is what admits nothing.
message(#{tag := unsatisfiable_guard, file := P, line := L, function := Fn,
          clause_number := N}) ->
    {"~s:~p: warning: clause ~p of ~s has a guard no value satisfies~n"
     "  the pattern is a member of the input; it is the guard that~n"
     "  admits nothing. Widen the guard, or delete the clause.~n",
     [P, L, N, Fn]};
%% Both of the next two would otherwise reach the author as an `erlc` error
%% against the emitted `.abstr`, a file they did not write (ticket 34).
message(#{tag := rebinding, file := P, line := L, function := Fn, name := V}) ->
    {"~s:~p: error: ~s binds ~s twice~n"
     "  a name means one thing in a clause. There is no mutation to~n"
     "  assign with, so rename the second one.~n",
     [P, L, Fn, V]};
%% The same offence as `rebinding` and a different fix, hence a different tag:
%% in a body you rename, in a head you almost always meant the same value
%% again, spelled `== x` (F8.10, ticket 45).
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
%% The residual is the clause the caller must write: the fix proposed is an
%% edit to the function being checked, never to the callee (ticket 33 site
%% 1; 18 §4's function-local rule).
message(#{tag := arg_not_accepted, file := P, line := L, function := Fn,
          callee := Callee, position := Pos, rejected := Rejected,
          caller_head := Head}) ->
    {"~s:~p: error: ~s hands ~s an argument it does not accept~n"
     "  argument ~p is not covered by ~s's declared type:~n"
     "    ~s~n~s",
     [P, L, Fn, Callee, Pos, Callee, Rejected, caller_head_prose(Fn, Head)]};
%% Answered in field names, because `Order{Id} \ Order` would name the type
%% being built rather than the field forgotten. The verb is read from the
%% form: "builds an Order with the wrong fields" is false of a `with` that
%% invented a name, while the `Extra` sentence already fits both and
%% `field_list/2` renders an empty `Missing` as nothing (ticket 33 site 2,
%% 36, 23).
message(#{tag := field_set_mismatch, file := P, line := L, function := Fn,
          record := Record, form := Form, missing := Missing, extra := Extra}) ->
    {"~s:~p: error: ~s ~s an ~s with the wrong fields~n~s~s",
     [P, L, Fn, field_set_verb(Form), Record,
      field_list("  missing, and must be supplied", Missing),
      field_list("  not declared by " ++ atom_to_list(Record), Extra)]};
%% Shaped on `return_not_declared`'s message: both say a synthesised value is
%% not contained in a declared type, differing only in which declaration.
message(#{tag := field_value_not_accepted, file := P, line := L, function := Fn,
          record := Record, field := Field, rejected := Rejected}) ->
    {"~s:~p: error: ~s assigns ~s a value ~s does not accept~n"
     "  not covered by the declared type of ~s:~n"
     "    ~s~n",
     [P, L, Fn, Field, Record, Field, Rejected]};
%% The residual is the member that lacks the field, which is the tag to
%% discriminate on (ticket 33 site 3, F3.8).
message(#{tag := field_absent, file := P, line := L, function := Fn,
          form := projection, field := Field, member := Member}) ->
    {"~s:~p: error: ~s projects ~s from a value that may not carry it~n"
     "  this member has no ~s:~n"
     "    ~s~n"
     "  discriminate on the tag first, in a clause head.~n",
     [P, L, Fn, Field, Field, Member]};
%% The member handed back is either one arm of a union or the whole subject,
%% and the fix differs: the first is discriminated on, the second has no tag
%% and needs a record where an int is. So the line names both edits
%% (ENG-249, ticket 23 §4).
message(#{tag := field_absent, file := P, line := L, function := Fn,
          form := update, field := Field, member := Member}) ->
    {"~s:~p: error: ~s updates ~s on a value that may not carry it~n"
     "  this member has no ~s:~n"
     "    ~s~n"
     "  `with` updates a record: give it one, or discriminate on the tag~n"
     "  first, in a clause head.~n",
     [P, L, Fn, Field, Field, Member]};
%% Without this, the emitted `-spec` would claim what the body does not
%% deliver (ticket 33 site 4, 18). The residual answers what is not covered
%% and the signature answers what to write, so the signature is added, never
%% substituted (F25, ticket 23 §8). The `none` clause comes first: the
%% residual has no writable spelling, such as a record or `binary \ string`.
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
%% A destructuring bind is allowed exactly when this residual is empty, so it
%% is provably irrefutable (ticket 33 site 5, 34).
message(#{tag := bind_may_fail, file := P, line := L, function := Fn,
          unmatched := Unmatched}) ->
    {"~s:~p: error: this bind in ~s can fail~n"
     "  the pattern does not match:~n"
     "    ~s~n"
     "  a bind that can fail is a branch the exhaustiveness checker~n"
     "  never sees. Match it in a clause head instead.~n",
     [P, L, Fn, Unmatched]};
%% Reported as `unknown_callee` this would say the function does not exist,
%% when it is one word away from callable; that is why `bs_check:exports_of/1`
%% does not simply filter private functions out (F12, ticket 40 §3).
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
%% Arity overloading is permitted, so this is not "wrong number of arguments"
%% but a function not declared, beside ones that are. Naming the arities that
%% do exist keeps it a fix rather than a verdict (ticket 40 §2).
message(#{tag := arity_not_declared, file := P, line := L, function := Fn,
          callee := Callee, got := Got, declared := Have}) ->
    {"~s:~p: error: ~s calls ~s/~p, which nothing declares~n"
     "  ~s is declared at ~s. Arity overloading is permitted, so~n"
     "  ~s/~p would be a new function and needs its own signature.~n",
     [P, L, Fn, Callee, Got, Callee,
      lists:join(", ", [[$/ | integer_to_list(A)] || A <- Have]),
      Callee, Got]};
%% The three reserved-qualifier refusals (ticket 67). The first names the
%% spellings that are still legal, because only the bare name is taken and an
%% author just refused needs to know `Shop.Collections.List` remains open.
message(#{tag := reserved_module_name, file := P, line := L, module := Mod}) ->
    {"~s:~p: error: `~s` is a reserved qualifier, so no module may be called it~n"
     "  `~s.` names operations the compiler knows and inlines at the site;~n"
     "  no beam ships for it and no `using` is ever written. The name is~n"
     "  taken only as a WHOLE module name — `Shop.~s` is still legal, and~n"
     "  so is any other path with `~s` as a segment.~n",
     [P, L, Mod, Mod, Mod, Mod]};
%% The second is `ambiguous_module`'s shape with a compiler-known claimant:
%% both meanings named, the full path handed over as the fix.
message(#{tag := reserved_qualifier_shadowed, file := P, line := L,
          function := Fn, qualifier := Q, operation := Op,
          candidates := Mods}) ->
    {"~s:~p: error: ~s calls ~s.~s, and `~s` means two things here~n"
     "  `~s` is a reserved qualifier — the compiler's own operations —~n"
     "  and a `using` line also short-qualifies these to it:~n"
     "~s"
     "  write the module's full path to reach it, or drop the namespace~n"
     "  import to reach `~s.~s`.~n",
     [P, L, Fn, Q, Op, Q, Q,
      [io_lib:format("    ~s.~s(...)~n", [M, Op]) || M <- Mods],
      Q, Op]};
%% The third stops an unknown operation falling through to
%% `module_not_imported`, whose "add `using List`" is the one fix that can
%% never work for a reserved qualifier.
message(#{tag := unknown_reserved_operation, file := P, line := L,
          function := Fn, qualifier := Q, operation := Op, got := Got,
          declared := []}) ->
    {"~s:~p: error: ~s calls ~s.~s/~p, and `~s` has no operation of that name~n"
     "  `~s` is a reserved qualifier, so this cannot be fixed with a~n"
     "  `using` line — the operations under it are the compiler's own.~n",
     [P, L, Fn, Q, Op, Got, Q, Q]};
message(#{tag := unknown_reserved_operation, file := P, line := L,
          function := Fn, qualifier := Q, operation := Op, got := Got,
          declared := Have}) ->
    {"~s:~p: error: ~s calls ~s.~s/~p, and `~s.~s` takes ~s~n"
     "  the operations under a reserved qualifier are the compiler's own,~n"
     "  so the arity is fixed rather than overloadable.~n",
     [P, L, Fn, Q, Op, Got, Q, Op,
      lists:join(" or ", [[integer_to_list(A), " argument",
                           case A of 1 -> ""; _ -> "s" end] || A <- Have])]};
message(#{tag := unknown_record, file := P, line := L, function := Fn,
          record := Name}) ->
    {"~s:~p: error: ~s builds an ~s, which no record or type declares~n",
     [P, L, Fn, Name]};
%% `_` is an expression only so that `(a, _) = pair` parses (F5), so its use
%% as a value is caught here rather than by `erlc` against a file the author
%% did not write (F4.7).
message(#{tag := wildcard_as_value, file := P, line := L, function := Fn}) ->
    {"~s:~p: error: ~s uses `_` as a value~n"
     "  `_` is a pattern. It may stand on the left of `=` or in a~n"
     "  clause head; it names nothing to read back.~n",
     [P, L, Fn]};

%%% --- the codegen-obligation refusals (F18) ---------------------------------

%% The message says why rather than only what, because the rule is not
%% obvious and the fix is to want something else entirely.
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
%% Says the compiler is not ready, not that the pattern is wrong:
%% `{ Status: s }` is a member of `map<atom, term>`, so "matches no value"
%% would be false.
message(#{tag := map_pattern_deferred, file := P, line := L, function := Fn,
          site := Site, type := Ty}) ->
    %% The same refusal, not the same sentence: an arm's subject is not a
    %% parameter, and "a clause head" would send a `switch` author to the
    %% wrong line.
    {Where, Subject} =
        case Site of
            head -> {"a clause head", "the parameter's type is"};
            arm  -> {"a switch arm",  "the subject's type is"}
        end,
    {"~s:~p: error: ~s destructures a map whose keys are not a fixed list~n"
     "  ~s: ~s~n"
     "  `map<K, V>` ships as a type — declare it, pass it, store it,~n"
     "  return it — but matching one in ~s is not built. A pattern~n"
     "  over an unbounded key set cannot be proved exhaustive, which is~n"
     "  the guarantee every other head in this language keeps.~n"
     "  Bind the whole map and read it, or declare a record if the keys~n"
     "  are known.~n",
     [P, L, Fn, Subject, Ty, Where]};
%% Names the deferral, not a defect: the walk over an unbounded key set is
%% unbuilt, and a generated validator would silently certify anything
%% (ticket 48).
message(#{tag := validate_domain_map, file := P, line := L, function := Fn,
          type := Ty}) ->
    {"~s:~p: error: ~s validates against a map type whose keys are not~n"
     "  a fixed list~n"
     "  the type is: ~s~n"
     "  `map<K, V>` ships as a type — it can be declared, passed, stored~n"
     "  and returned — but the walk that would check an unbounded set of~n"
     "  keys is not built, and a generated validator would accept every~n"
     "  term it was handed. Validate against a record, or a `type` whose~n"
     "  fields are written out.~n",
     [P, L, Fn, Ty]};
message(#{tag := obligation_arity, file := P, line := L, function := Fn,
          obligation := Name, type_args := Types, args := Args}) ->
    {"~s:~p: error: ~s writes ~s with ~p type arguments and ~p values~n"
     "  ~s is a codegen obligation, not a function: it takes exactly one~n"
     "  type argument and one value. The bracket names the type to~n"
     "  generate a check for, the parentheses hold the term to check.~n"
     "  Write `~s<T>(x)`.~n",
     [P, L, Fn, Name, Types, Args, Name, Name]};
%% Two sentences, because the closed set of obligations lives in the checker
%% rather than the lexer: one is "wait for us", the other "that was never
%% going to work".
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

%%% --- the fatal ones --------------------------------------------------------

message(#{tag := stray_semicolon, file := P, line := L}) ->
    {"~s:~p: error: beam-sharp has no `;`~n"
     "  a declaration ends where the next one begins. Remove it.~n",
     [P, L]};
message(#{tag := lex_error, file := P, line := L, detail := D}) ->
    {"~s:~p: error: ~s~n", [P, L, D]};
message(#{tag := parse_error, file := P, line := L, detail := D}) ->
    {"~s:~p: error: ~s~n", [P, L, D]};
%% The refusal names what to write instead: every comparison the guard
%% fragment admits has an opposite already in the language (ticket 63).
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

%%% --- the raised ones -------------------------------------------------------

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
%% The fix is named because the alternative always exists: a property pattern
%% constrains fields without naming a type at all (F22).
message(#{tag := not_a_record, file := P, line := L, type := N}) ->
    {"~s:~p: error: ~s is not a record, so it cannot name a pattern~n"
     "  only a `record` declaration mints the tag a type prefix matches on.~n"
     "  to constrain fields without naming a type, write `{ Field: ... }`.~n",
     [P, L, N]};
%% Shaped on `field_set_mismatch`'s "not declared by Order" sentence, the
%% same mistake at a different site, and it hands back the field list (F22,
%% ticket 23).
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
%% The recursion is through a constructor, so `cyclic_type` does not apply;
%% what fails is regularity, and the message names the repair as well (F28).
message(#{tag := non_regular_recursion, file := P, type := N}) ->
    {"~s: error: ~s recurs at a different type argument each time~n"
     "  the recursion passes through a constructor, so the definition is~n"
     "  contractive -- but each unfolding names a WIDER argument than the~n"
     "  last, so it never comes back to itself and there is no finite~n"
     "  type to hold it.~n"
     "  Recur at the SAME argument (`~s<X>` inside `~s<X>`), or give the~n"
     "  inner position a concrete type.~n",
     [P, N, N, N]};
%% Two messages, because the hint is not one hint: "tag it" repairs an
%% absorbed `:nothing` and is nonsense about an absorbed `(:error, E)`, which
%% is already tagged (F31; ticket 15 §1 wrote only the first).
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
%%% The binary segment refusals (F13).
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

%%% --- the remainder ---------------------------------------------------------
%%%
%%% No catch-all beyond this one, which only the `unclassified` tag reaches.
%%% A tag with no clause here crashes rather than rendering generic prose, so
%%% a new diagnostic cannot ship looking as if it had a message (F16.7).

message(#{tag := unclassified, file := P, detail := D}) ->
    {"~s: ~p~n", [P, D]}.

%%% ---------------------------------------------------------------------------
%%% Head synthesis
%%%
%%% The compiler synthesises the head, never the body: a head is derived from
%%% the residual and cannot be wrong, while a body is a guess, and one bad
%%% suggestion poisons every good one. Lowering a set to a pattern plus guard
%%% is a real compilation step, so it lives here and consumers never each
%%% invert it differently (ticket 23 §2).
%%%
%%% The term carries every head and the prose carries three: the descriptor
%%% holds the residual's parts, per argument, per product, never finished
%%% text, because prose cannot be a pure function of a term truncated before
%%% it arrived (ticket 43).
%%% ---------------------------------------------------------------------------

%% The residual's tuple part is the argument list, so each product is a clause
%% head the author can paste in.
heads(Fn, Residual, Names) ->
    #{tuples := Products} = Residual,
    case Products of
        [] -> #{kind => residual_only, parts => parts(Residual)};
        _  ->
            Base = #{kind => products,
                     products => [[parts(C) || C <- P] || P <- Products]},
            %% `pasteable` is absent, not empty, when nothing is spellable: a
            %% cofinite atom set or `binary \ string` has no pattern, and `[]`
            %% invites a consumer to render an empty suggestion. The split is
            %% per product, because a residual can be part spellable and part
            %% not, and reporting only the heads would show clauses that do
            %% not cover the residual; the rest travels in `description`
            %% (F29.9).
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

%% One product as a description, untruncated like everything else the term
%% carries; the cap lives in the prose (ticket 43).
product_str(P) ->
    lists:flatten(["(", lists:join(", ", [join(parts(C), infinity) || C <- P]), ")"]).

%% One head per line. A residual argument is a union and a clause head is
%% not: `Classify(<= 199 | 300..399)` is a syntax error, so the parts are
%% expanded across the arguments and each combination is its own head, which
%% is why the count can exceed the product count and the cap counts lines
%% (F29.2). `name_binders/1` runs on the assembled line, because two binders
%% spelled the same in one head is `repeated_in_head` and no part can see its
%% siblings; the arrow is appended after naming, because a hoisted `when`
%% goes before the arrow.
pasteable(Fn, Product, Names) ->
    [lists:flatten(bs_types:name_binders(
                     io_lib:format("~s(~s)", [Fn, lists:join(", ", Combo)]))
                   ++ " -> ...")
     || Combo <- bs_types:head_combos(Product, Names)].

heads_prose(_Fn, #{kind := residual_only, parts := Parts}) ->
    io_lib:format("    ~s~n", [join(Parts, ?RESIDUAL_CASES)]);
%% The prose is a prefix of the term channel by construction: both come from
%% the one `pasteable` list, and the cap is the only difference (F29.10).
heads_prose(_Fn, H = #{kind := products, pasteable := Lines}) ->
    [cap([io_lib:format("    ~s~n", [L]) || L <- Lines]), unspellable_prose(H)];
heads_prose(_Fn, H = #{kind := products}) ->
    unspellable_prose(H).

%% Capped like the heads: the cap applies to whatever is being enumerated,
%% and uncapped this printed forty-one products on one line (ticket 43).
unspellable_prose(#{description := Ds}) ->
    [io_lib:format("  and no pattern spells:~n", []),
     cap([io_lib:format("    ~s~n", [D]) || D <- Ds])];
unspellable_prose(_) -> [].

%% The cap counts head lines as well as parts within a line: a residual over
%% two arguments is a product of the parts, so a cap that stayed on intervals
%% would print an unbounded number of lines once a second argument had a
%% residual too.
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
%% them: one head per line, through the head printer rather than the
%% description printer, because this is a paste site and a description such
%% as `F(int <= 5, _)` does not parse (F29). `none` when the argument is not
%% a whole parameter, since an expression has no head position to put a
%% pattern in, and `none` again when no part of the residual has a pattern:
%% where the residual is not expressible the term says so and offers nothing
%% (ticket 23 §2).
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

%% Construction supplies a field set and `with` updates one, so `update` never
%% carries a `Missing` list (ticket 26 §2).
field_set_verb(construction) -> "builds";
field_set_verb(update)       -> "updates".

field_list(_Label, [])    -> "";
field_list(Label, Fields) ->
    io_lib:format("~s:~n    ~s~n",
                  [Label, lists:join(", ", [atom_to_list(F) || F <- Fields])]).

plural(1) -> "";
plural(_) -> "s".
