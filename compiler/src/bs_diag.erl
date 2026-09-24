%%% Diagnostics are terms; only this module formats and prints their prose.
%%% `message/1` supplies both `emit/2` and `format/1` with format/argument
%%% pairs. Reprinting finished text through `~s` fails above codepoint 255.
%%%
%%% `residual` and `heads` retain every case; only prose is capped. Map
%%% payloads evolve additively to preserve existing matchers.
%%% Rationale: compiler/features/F16-diagnostic-as-a-term.md.
-module(bs_diag).

-export([descriptor/2, format/1, message/1, emit/2, json/1, put_json/1]).
-export([channel/0, set_channel/1, contractual/0]).

%% Up to ?RESIDUAL_CASES cases print in full.
-define(RESIDUAL_CASES, 3).

%%% --- The channel ---
%%%
%%% Term and JSON channels write one descriptor per stdout line; prose uses
%%% stderr. The REPL refuses these channels because stdout also holds values.
%%% Report sites have no options record, so the channel is process-local. CLI
%%% dispatch sets it in a fresh process; library callers default to prose.

%% CLI argument parsing validates the channel before it reaches this guard.
set_channel(Chan) when Chan =:= prose; Chan =:= term; Chan =:= json ->
    put(bs_diag_channel, Chan).

channel() ->
    case get(bs_diag_channel) of
        undefined -> prose;
        Chan      -> Chan
    end.

%% Tags offering source to write have frozen payload shapes.
contractual() ->
    [inexhaustive, catch_all_over_closed, switch_inexhaustive,
     arg_not_accepted, unreachable_clause, unreachable_arm,
     return_not_declared].

%%% --- Publishing ---

%% `~0p` prevents wrapping: each newline frames one descriptor on stdout.
emit(Chan, Desc) ->
    case Chan of
        term -> io:format("~0p~n", [Desc]);
        json -> put_json(Desc);
        _    -> ok
    end,
    {Fmt, Args} = message(Desc),
    io:format(standard_error, Fmt, Args).

%% Diagnostics and `--api` share one-object-per-line framing. `put_chars`
%% preserves UTF-8 binaries; `~s` would re-encode their bytes.
put_json(Map) ->
    io:put_chars([json(Map), $\n]).

%%% --- The wire form ---
%%%
%%% JSON uses the platform encoder with text charlists converted to binaries.
%%% Integer lists need classification by tag and key: `declared` holds arities
%%% for two tags, but type text for others. `integer_list/2` owns this roster.
%%% Empty lists are arrays. Other integer lists must be printable text or raise
%%% an error naming the tag and key. Other lists encode as arrays.
%%% Rationale: compiler/features/F47-diagnostic-json.md.

%% `unclassified` carries raw diagnostics, including tuples JSON cannot encode.
%% Its `detail` is printed text on this channel.
json(#{tag := unclassified, detail := D} = Desc) ->
    encode(Desc#{detail := lists:flatten(io_lib:format("~0p", [D]))});
json(Desc) ->
    encode(Desc).

encode(Desc) ->
    Tag = maps:get(tag, Desc, undefined),
    json:encode(wire(Tag, tag, Desc)).

integer_list(name_arity_unfixed, declared) -> true;
integer_list(arity_not_declared, declared) -> true;
integer_list(_Tag, _Key)                   -> false.

wire(Tag, _Key, M) when is_map(M) ->
    maps:map(fun(K, V) -> wire(Tag, K, V) end, M);
wire(_Tag, _Key, []) ->
    [];
wire(Tag, Key, L) when is_list(L) ->
    case lists:all(fun erlang:is_integer/1, L) of
        true  -> integers(Tag, Key, L);
        false -> [wire(Tag, Key, X) || X <- L]
    end;
wire(_Tag, _Key, X) ->
    X.

integers(Tag, Key, L) ->
    case integer_list(Tag, Key) of
        true  -> L;
        false ->
            case io_lib:printable_unicode_list(L) of
                true  -> unicode:characters_to_binary(L);
                false -> error({json_list_unrostered, Tag, Key, L})
            end
    end.

format(Desc) ->
    {Fmt, Args} = message(Desc),
    io_lib:format(Fmt, Args).

%%% --- Returned diagnostics ---

%% Severity is explicit data; consumers must not infer it from the tag.
at(Sev, Path, Line, Fn) ->
    #{severity => Sev, file => Path, line => Line, function => Fn}.

article("int") -> "an";
article(_)     -> "a".

%% Checker-supplied positions preserve all parameters and their source names.
%% `none` means no parameter carries the union, so no head can be offered.
%% Rationale: compiler/features/F53-numeric-union-dispatch.md.
union_heads(_Fn, none) -> [];
union_heads(Fn, {Before, Name, After}) ->
    [lists:flatten(io_lib:format("~s(~s)", [Fn, join_params(Before, Part, Name, After)]))
     || Part <- ["int", "float"]].

join_params(Before, Part, Name, After) ->
    lists:join(", ", [atom_to_list(N) || N <- Before]
                     ++ [Part ++ " " ++ atom_to_list(Name)]
                     ++ [atom_to_list(N) || N <- After]).

dispatch_advice([]) ->
    "  Dispatch the parts where the value enters the function, and write~n"
    "  the operator in the clause where the part is known.~n";
dispatch_advice(Heads) ->
    "  Dispatch the parts in the head, and write the operator in each~n"
    "  clause, where the part is known:~n"
        ++ lists:flatten([["    ", H, " -> ...~n"] || H <- Heads]).

%% The frozen descriptor carries printed types, so literal advice reads them.
float_spelling(Undeclared, "float") ->
    case int_text(Undeclared) of
        true  -> "  `" ++ Undeclared ++ "` is an `int`; the float is `"
                     ++ Undeclared ++ ".0`.~n";
        false -> ""
    end;
float_spelling(_, _) -> "".

int_text([$- | Ds]) -> int_text(Ds);
int_text([_ | _] = Ds) -> lists:all(fun(C) -> C >= $0 andalso C =< $9 end, Ds);
int_text(_) -> false.

%% Split parser positions here; builders pass them through under `line`. Keep
%% `line` an integer and add `column` to preserve payload compatibility.
%% Rationale: compiler/features/F35-columns.md.
descriptor(Path, D) ->
    place(built(Path, D)).

%% The caller re-raises `unhandled`; it must pass through unchanged. Internal
%% `built/2` calls also rely on bare lines passing through.
place(unhandled) ->
    unhandled;
place(#{line := {Line, Column}} = Desc) ->
    Desc#{line := Line, column => Column};
place(Desc) ->
    Desc.

built(Path, {Sev, Line, Fn, {inexhaustive, Residual, Names}}) ->
    (at(Sev, Path, Line, Fn))#{tag => inexhaustive,
                               residual => residual(Residual),
                               heads => heads(Fn, Residual, Names)};
built(Path, {Sev, Line, Fn, {catch_all_over_closed, Residual, Names}}) ->
    (at(Sev, Path, Line, Fn))#{tag => catch_all_over_closed,
                               residual => residual(Residual),
                               heads => heads(Fn, Residual, Names)};
built(Path, {Sev, Line, Fn, {unsized_segment_not_last, _Size, _L}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unsized_segment_not_last};
built(Path, {Sev, Line, Fn, {segment_width_not_positive, N, _L}}) ->
    (at(Sev, Path, Line, Fn))#{tag => segment_width_not_positive, width => N};
built(Path, {Sev, Line, Fn, {segment_literal_too_wide, K, N, _L}}) ->
    (at(Sev, Path, Line, Fn))#{tag => segment_literal_too_wide,
                               value => K, width => N,
                               max => (1 bsl N) - 1};
built(Path, {Sev, Line, Fn, {segment_size_not_bound, V, _L}}) ->
    (at(Sev, Path, Line, Fn))#{tag => segment_size_not_bound, name => V};
built(Path, {Sev, Line, Fn, relational_in_bind}) ->
    (at(Sev, Path, Line, Fn))#{tag => relational_in_bind};
built(Path, {Sev, Line, Fn, no_clauses}) ->
    (at(Sev, Path, Line, Fn))#{tag => no_clauses};
%% A bare type-variable parameter admits only one binder clause.
built(Path, {Sev, Line, Fn, {pattern_on_type_variable, Var, Pos}}) ->
    (at(Sev, Path, Line, Fn))#{tag => pattern_on_type_variable,
                               type_variable => Var, argument => Pos};
%% A type variable appearing only in the return cannot be inferred at a call.
built(Path, {Sev, Line, Fn, {unrecoverable_type_variable, Var}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unrecoverable_type_variable,
                               type_variable => Var};
%% Codegen obligations require ground type arguments.
built(Path, {Sev, Line, Fn, {obligation_over_type_variable, Name, Var}}) ->
    (at(Sev, Path, Line, Fn))#{tag => obligation_over_type_variable,
                               obligation => Name, type_variable => Var};
built(Path, {Sev, Line, Fn, {divide_by_zero, Op}}) ->
    (at(Sev, Path, Line, Fn))#{tag => divide_by_zero, op => Op};
%% `literal` is the checker's float spelling of an integer literal, or `none`.
built(Path, {Sev, Line, Fn, float_remainder}) ->
    (at(Sev, Path, Line, Fn))#{tag => float_remainder};
built(Path, {Sev, Line, Fn, {mixed_operands, Op, Left, Right, Literal}}) ->
    (at(Sev, Path, Line, Fn))#{tag => mixed_operands, op => Op,
                               left => atom_to_list(Left),
                               right => atom_to_list(Right),
                               literal => Literal};
built(Path, {Sev, Line, Fn, {switch_inexhaustive, Residual, Names}}) ->
    Base = (at(Sev, Path, Line, Fn))#{tag => switch_inexhaustive,
                                      residual => residual(Residual)},
    %% Each arm needs a separate string: union syntax is not an arm pattern.
    case arms(Residual, Names) of
        [] -> Base#{arms => [],
                    description => [lists:flatten(bs_types:to_pattern(Residual))]};
        As -> Base#{arms => As}
    end;
built(Path, {Sev, Line, Fn, {valve_on_infallible, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => valve_on_infallible,
                               subject => bs_types:to_pattern(Ty)};
built(Path, {Sev, Line, Fn, {unreachable_arm, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unreachable_arm, arm_number => N};
%% Arm and clause tags stay distinct so each tag determines its payload keys.
built(Path, {Sev, Line, Fn, {vacuous_arm, N, Domain}}) ->
    (at(Sev, Path, Line, Fn))#{tag => vacuous_arm, arm_number => N,
                               domain => residual(Domain)};
built(Path, {Sev, Line, Fn, {unsatisfiable_arm_guard, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unsatisfiable_arm_guard, arm_number => N};
built(Path, {Sev, Line, Fn, switch_in_guard}) ->
    (at(Sev, Path, Line, Fn))#{tag => switch_in_guard};
built(Path, {Sev, Line, Fn, raise_in_guard}) ->
    (at(Sev, Path, Line, Fn))#{tag => raise_in_guard};
%% `callee` keeps the author's spelling, not Erlang's name/arity notation.
built(Path, {Sev, Line, Fn, {call_in_guard, Callee}}) ->
    (at(Sev, Path, Line, Fn))#{tag => call_in_guard, callee => Callee};
built(Path, {Sev, Line, Fn, {foreign_call_in_guard, Callee}}) ->
    (at(Sev, Path, Line, Fn))#{tag => foreign_call_in_guard, callee => Callee};
built(Path, {Sev, Line, Fn, {unreachable_clause, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unreachable_clause, clause_number => N};
%% Preserve domain parts in the term; only prose may truncate them.
built(Path, {Sev, Line, Fn, {vacuous_clause, N, Domain}}) ->
    (at(Sev, Path, Line, Fn))#{tag => vacuous_clause, clause_number => N,
                               domain => residual(Domain)};
built(Path, {Sev, Line, Fn, {unsatisfiable_guard, N}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unsatisfiable_guard, clause_number => N};
built(Path, {Sev, Line, Fn, {rebinding, V}}) ->
    (at(Sev, Path, Line, Fn))#{tag => rebinding, name => V};
built(Path, {Sev, Line, Fn, {repeated_in_head, V}}) ->
    (at(Sev, Path, Line, Fn))#{tag => repeated_in_head, name => V};
built(Path, {Sev, Line, Fn, {unbound_variable, V}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unbound_variable, name => V};
built(Path, {Sev, Line, Fn, {arg_not_accepted, Callee, Pos, Residual, Head}}) ->
    (at(Sev, Path, Line, Fn))#{tag => arg_not_accepted,
                               callee => Callee,
                               position => Pos,
                               residual => residual(Residual),
                               rejected => bs_types:to_pattern(Residual),
                               caller_head => caller_head(Fn, Head, Residual)};
built(Path, {Sev, Line, Fn, {field_set_mismatch, Record, Form, Missing, Extra}}) ->
    (at(Sev, Path, Line, Fn))#{tag => field_set_mismatch,
                               record => Record,
                               form => Form,
                               missing => Missing,
                               extra => Extra};
built(Path, {Sev, Line, Fn, {field_value_not_accepted, Record, Field, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => field_value_not_accepted,
                               record => Record,
                               field => Field,
                               residual => residual(Residual),
                               rejected => bs_types:to_pattern(Residual)};
built(Path, {Sev, Line, Fn, {field_absent, Form, Field, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => field_absent,
                               form => Form,
                               field => Field,
                               residual => residual(Residual),
                               member => bs_types:to_pattern(Residual)};
%% `corrected`, `indiscriminable`, `withheld` and `replaces` are always
%% present; unused values are `none`. `indiscriminable` names the refused
%% widening pair, `withheld` explains missing advice, and `replaces` names the
%% absorbed type. `declared` keeps the author's return-type spelling.
%% Rationale: compiler/features/F25-corrected-signature.md.
built(Path, {Sev, Line, Fn, {return_not_declared, Residual, {Declared, Corrected}}}) ->
    maps:merge((at(Sev, Path, Line, Fn))#{tag => return_not_declared,
                                          residual => residual(Residual),
                                          undeclared => bs_types:to_pattern(Residual),
                                          declared => Declared},
               correction(Corrected));
built(Path, {Sev, Line, Fn, {bind_may_fail, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => bind_may_fail,
                               residual => residual(Residual),
                               unmatched => bs_types:to_pattern(Residual)};
%%% --- Function values ---
built(Path, {Sev, Line, Fn, lambda_without_expectation}) ->
    (at(Sev, Path, Line, Fn))#{tag => lambda_without_expectation};
built(Path, {Sev, Line, Fn, {name_arity_unfixed, Name, Arities}}) ->
    (at(Sev, Path, Line, Fn))#{tag => name_arity_unfixed,
                               name => Name, declared => Arities};
built(Path, {Sev, Line, Fn, {lambda_param_refuted, Pos, Residual}}) ->
    (at(Sev, Path, Line, Fn))#{tag => lambda_param_refuted,
                               argument => Pos,
                               residual => residual(Residual),
                               unmatched => bs_types:to_pattern(Residual)};
built(Path, {Sev, Line, Fn, {not_callable, Var, Arity, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => not_callable,
                               name => Var, arity => Arity,
                               type => bs_types:to_string(Ty)};
built(Path, {Sev, Line, Fn, {instantiation_conflict, Callee, Var, LowPos, Low,
                             UpPos, Up}}) ->
    (at(Sev, Path, Line, Fn))#{tag => instantiation_conflict,
                               callee => Callee, type_variable => Var,
                               lower_argument => LowPos,
                               lower => bs_types:to_string(Low),
                               upper_argument => UpPos,
                               upper => bs_types:to_string(Up)};
built(Path, {Sev, Line, Fn, {validate_over_arrow, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => validate_over_arrow,
                               type => bs_types:to_string(Ty)};
built(Path, {Sev, Line, Fn, lambda_in_guard}) ->
    (at(Sev, Path, Line, Fn))#{tag => lambda_in_guard};
built(Path, {Sev, Line, Fn, {private_function, Mod, Callee, Arity}}) ->
    (at(Sev, Path, Line, Fn))#{tag => private_function,
                               module => Mod, callee => Callee, arity => Arity};
built(Path, {Sev, Line, Fn, {unknown_callee, Callee, Arity}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unknown_callee,
                               callee => Callee, arity => Arity};
built(Path, {Sev, Line, Fn, {arity_mismatch, Callee, Got, Want}}) ->
    (at(Sev, Path, Line, Fn))#{tag => arity_mismatch,
                               callee => Callee, got => Got, want => Want};
built(Path, {Sev, Line, Fn, {arity_not_declared, Callee, Got, Have}}) ->
    (at(Sev, Path, Line, Fn))#{tag => arity_not_declared,
                               callee => Callee, got => Got, declared => Have};
%%% Reserved-qualifier shadowing uses `ambiguous_module`'s candidate shape.
built(Path, {Sev, Line, Fn, {reserved_qualifier_shadowed, Q, Op, Mods}}) ->
    (at(Sev, Path, Line, Fn))#{tag => reserved_qualifier_shadowed,
                               qualifier => Q, operation => Op,
                               candidates => Mods};
built(Path, {Sev, Line, Fn,
                  {unknown_reserved_operation, Q, Op, Got, Have}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unknown_reserved_operation,
                               qualifier => Q, operation => Op,
                               got => Got, declared => Have};
built(Path, {Sev, Line, Fn, {duplicate_field, Key}}) ->
    (at(Sev, Path, Line, Fn))#{tag => duplicate_field, field => Key};
built(Path, {Sev, Line, Fn, {unknown_record, Name}}) ->
    (at(Sev, Path, Line, Fn))#{tag => unknown_record, record => Name};
built(Path, {Sev, Line, Fn, wildcard_as_value}) ->
    (at(Sev, Path, Line, Fn))#{tag => wildcard_as_value};

%%% --- Codegen-obligation refusals ---

built(Path, {Sev, Line, Fn, {validate_collapses, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => validate_collapses,
                               type => bs_types:to_string(Ty)};
%% Report the first inseparable pair as normalised members.
built(Path, {Sev, Line, Fn, {validate_indiscriminable, Ty, A, B}}) ->
    (at(Sev, Path, Line, Fn))#{tag => validate_indiscriminable,
                               type => bs_types:to_string(Ty),
                               member => bs_types:to_string(A),
                               beside => bs_types:to_string(B)};
built(Path, {Sev, Line, Fn, {numeric_union_operand, Op, Side, Ty, Heads}}) ->
    (at(Sev, Path, Line, Fn))#{tag => numeric_union_operand,
                               op => Op,
                               side => Side,
                               type => bs_types:to_string(Ty),
                               heads => union_heads(Fn, Heads)};
%% Nested prefixes are refused by position regardless of their type.
%% Undecidable prefixes carry the checker's reason for type-specific advice.
built(Path, {type_prefix_nested, Line}) ->
    #{tag => type_prefix_nested, severity => error, file => Path, line => Line};
built(Path, {type_prefix_undecidable, Line, Ty, Why}) ->
    #{tag => type_prefix_undecidable, severity => error, file => Path,
      line => Line, type => Ty, reason => Why};
built(Path, {Sev, Line, Fn, {map_pattern_deferred, Site, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => map_pattern_deferred,
                               site => Site,
                               type => bs_types:to_string(Ty)};
built(Path, {Sev, Line, Fn, {parse_atom_not_finite, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => parse_atom_not_finite,
                               type => bs_types:to_string(Ty)};
built(Path, {Sev, Line, Fn, {parse_atom_arg, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => parse_atom_arg,
                               type => bs_types:to_string(Ty)};
built(Path, {Sev, Line, Fn, {to_existing_atom_arg, Ty}}) ->
    (at(Sev, Path, Line, Fn))#{tag => to_existing_atom_arg,
                               type => bs_types:to_string(Ty)};
%% The clause-body pass raises this for `--api` as well as compilation. `path`
%% is a list of segments; an empty list means the top level.
built(Path, {unencodable_member, Line, Fn, Ty, Segs, Member, Kind}) ->
    (at(error, Path, Line, Fn))#{tag => unencodable_member,
                                 obligation => 'ToJson',
                                 type => bs_types:to_string(Ty),
                                 path => Segs,
                                 member => bs_types:to_string(Member),
                                 kind => Kind};
built(Path, {Sev, Line, Fn, {obligation_arity, Name, Types, Args}}) ->
    (at(Sev, Path, Line, Fn))#{tag => obligation_arity,
                               obligation => Name,
                               type_args => Types, args => Args};
%% The checker owns the roster of built obligations.
built(Path, {Sev, Line, Fn, {obligation_unbuilt, Name}}) ->
    (at(Sev, Path, Line, Fn))#{tag => obligation_unbuilt, obligation => Name,
                               built => bs_check:built_obligations()};
built(Path, {Sev, Line, Fn, {not_an_obligation, Name}}) ->
    (at(Sev, Path, Line, Fn))#{tag => not_an_obligation, name => Name,
                               obligations => bs_check:codegen_obligations()};

%%% --- Lexing and parsing failures ---

built(Path, {lex, {Line, _Mod, {illegal, ";"}}}) ->
    #{tag => stray_semicolon, severity => error, file => Path, line => Line};
%% `!` fails in the lexer; `!=` is a separate token and must not match here.
built(Path, {lex, {Line, _Mod, {illegal, [$! | _]}}}) ->
    #{tag => no_negation, severity => error, file => Path, line => Line,
      spelling => "!"};
built(Path, {lex, {Line, Mod, Reason}}) ->
    #{tag => lex_error, severity => error, file => Path, line => Line,
      detail => lists:flatten(Mod:format_error(Reason))};
%% `not` remains a legal identifier. Offer the hint only after parsing fails.
built(Path, {parse, {Line, Mod, Reason}, Tokens}) ->
    case not_in_prefix_position(Tokens, Line) of
        true ->
            #{tag => no_negation, severity => error, file => Path,
              line => Line, spelling => "not"};
        false ->
            built(Path, {parse, {Line, Mod, Reason}})
    end;
built(Path, {parse, {Line, Mod, Reason}}) ->
    #{tag => parse_error, severity => error, file => Path, line => Line,
      detail => lists:flatten(Mod:format_error(Reason))};
built(Path, no_sources_here) ->
    #{tag => no_sources_here, severity => error, file => Path};

%%% --- Raised conditions ---
%%%
%%% Type-resolution failures reach `check_and_emit/4` without a function name.
%%% They use the same descriptor channel as returned diagnostics.

%% A file supplied at the raise site overrides the caller's path.
built(_Path, {in_file, Path, Reason}) ->
    built(Path, Reason);

built(Path, {behaviour_not_satisfied, Line, Behaviour, Missing}) ->
    #{tag => behaviour_not_satisfied, severity => error, file => Path,
      line => Line, behaviour => Behaviour, missing => Missing};
%% `-behaviour` has no runtime effect; OTP callbacks must be exported.
built(Path, {private_callback, N, A, Otp, Line}) ->
    #{tag => private_callback, severity => error, file => Path, line => Line,
      name => N, arity => A, otp_name => Otp};
built(Path, {unknown_behaviour, B}) ->
    #{tag => unknown_behaviour, severity => error, file => Path, behaviour => B};
%% `bs_check:at_loc/2` adds a position without changing the condition's tag.
%% `place/1` splits it into line and column after building the descriptor.
built(Path, {at, Loc, Reason}) ->
    case built(Path, Reason) of
        unhandled -> unhandled;
        Desc      -> Desc#{line => Loc}
    end;
built(Path, {unknown_type, N}) ->
    #{tag => unknown_type, severity => error, file => Path, type => N};
%% `bs_check:hinted/2` supplies reachable modules without changing the tag.
built(Path, {unknown_type, N, Mods}) ->
    #{tag => unknown_type, severity => error, file => Path, type => N,
      suppliers => Mods};
built(Path, {unknown_type_in_module, Mod, N}) ->
    #{tag => unknown_type_in_module, severity => error, file => Path,
      module => Mod, type => N};
built(Path, {type_module_not_imported, Mod, N}) ->
    #{tag => type_module_not_imported, severity => error, file => Path,
      module => Mod, type => N};
built(Path, {ambiguous_type, N, Mods}) ->
    #{tag => ambiguous_type, severity => error, file => Path, type => N,
      candidates => Mods,
      heads => [lists:flatten(io_lib:format("~s.~s", [M, N])) || M <- Mods]};
built(Path, {not_a_record, Line, N}) ->
    #{tag => not_a_record, severity => error, file => Path, line => Line,
      type => N};
built(Path, {pattern_field_unknown, Line, Record, Field, Declared}) ->
    #{tag => pattern_field_unknown, severity => error, file => Path,
      line => Line, record => Record, field => Field, declared => Declared};
built(Path, {unknown_builtin, B}) ->
    #{tag => unknown_builtin, severity => error, file => Path, type => B};
%% `why` names the shape one guard cannot decide; `at` distinguishes the whole
%% return from a nested position. Records and recursive types also carry `name`
%% and `fields` for advice.
built(Path, {foreign_ret_beyond_one_guard, Line, Mod, Fun, Type, Why, Name, Fields, At}) ->
    #{tag => foreign_ret_beyond_one_guard, severity => error, file => Path,
      line => Line, module => bs_types:atom_str(Mod), function => Fun,
      type => Type, why => Why, name => Name, fields => Fields, at => At};
built(Path, {unknown_generic, N}) ->
    #{tag => unknown_generic, severity => error, file => Path, type => N};
built(Path, {generic_arity, N, Want, Got}) ->
    #{tag => generic_arity, severity => error, file => Path, type => N,
      want => Want, got => Got};
built(Path, {needs_type_args, N, Want}) ->
    #{tag => needs_type_args, severity => error, file => Path, type => N,
      want => Want};
built(Path, {not_parametric, N}) ->
    #{tag => not_parametric, severity => error, file => Path, type => N};
%% Recursive types require a constructor between references to themselves.
built(Path, {cyclic_type, N}) ->
    #{tag => cyclic_type, severity => error, file => Path, type => N};
%% Recursion under changing type arguments cannot use a finite binder.
built(Path, {non_regular_recursion, N}) ->
    #{tag => non_regular_recursion, severity => error, file => Path, type => N};
%% Compiler-known types cannot be redeclared or shadowed.
built(Path, {compiler_known_type, Name, Line}) ->
    #{tag => compiler_known_type, severity => error, file => Path, line => Line,
      type => Name};
%% Compiler-known calls resolve before user functions; redeclarations would be
%% unreachable.
built(Path, {compiler_known_function, Name, Line}) ->
    #{tag => compiler_known_function, severity => error, file => Path, line => Line,
      function => Name};
built(Path, {kind_field_is_minted, Line, Name}) ->
    #{tag => kind_field_is_minted, severity => error, file => Path, line => Line,
      record => Name};
%% Channel changes the absorption hint, not the tag. `where` distinguishes
%% absorbing fields sharing a source line.
built(Path, {absorbed_member, Line, Where, Channel, Member, Absorber}) ->
    #{tag => absorbed_member, severity => error, file => Path,
      line => Line, channel => Channel, where => Where,
      member => bs_types:to_string(Member),
      absorbed_by => bs_types:to_string(Absorber)};
%% Indiscriminability is a limit of the pattern grammar, not the type.
built(Path, {indiscriminable_union, Line, Where, A, B}) ->
    #{tag => indiscriminable_union, severity => error, file => Path,
      line => Line, where => Where,
      member => bs_types:to_string(A),
      beside => bs_types:to_string(B)};
built(Path, {opaque_refinement, Line}) ->
    #{tag => opaque_refinement, severity => error, file => Path, line => Line};
built(Path, {empty_refinement, Line}) ->
    #{tag => empty_refinement, severity => error, file => Path, line => Line};
%% Relational patterns are restricted to parameter position.
built(Path, {relational_pattern_nested, Line}) ->
    #{tag => relational_pattern_nested, severity => error, file => Path,
      line => Line};
%% Duplicate signatures of the same arity would silently merge clauses.
built(Path, {name_redeclared, Name, Arity, Line}) ->
    #{tag => name_redeclared, severity => error, file => Path, line => Line,
      name => Name, arity => Arity};
%% Split the first declaration's position here; `place/1` splits only `line`.
%% Both positions must survive so editors can mark both declarations.
built(Path, {type_redeclared, Name, Line, First}) ->
    #{tag => type_redeclared, severity => error, file => Path, line => Line,
      type => Name, first_line => line_of(First), first_column => column_of(First)};
%% Qualified candidates must be writable source.
built(Path, {ambiguous_call, Name, Arity, Mods, Line}) ->
    #{tag => ambiguous_call, severity => error, file => Path, line => Line,
      name => Name, arity => Arity, candidates => Mods,
      heads => [lists:flatten(io_lib:format("~s.~s(...)", [M, Name]))
                || M <- Mods]};
built(Path, {unknown_module, Mod, Line}) ->
    #{tag => unknown_module, severity => error, file => Path, line => Line,
      module => Mod};
%% A file's `using` declarations define its dependencies.
built(Path, {module_not_imported, Mod, Line}) ->
    #{tag => module_not_imported, severity => error, file => Path, line => Line,
      module => Mod};
built(Path, {ambiguous_module, Short, Mods, Line}) ->
    #{tag => ambiguous_module, severity => error, file => Path, line => Line,
      module => Short, candidates => Mods};
built(Path, {reserved_module_name, Module, Line}) ->
    #{tag => reserved_module_name, severity => error, file => Path, line => Line,
      module => Module};
built(_Path, {import_cycle, Cycle}) ->
    #{tag => import_cycle, severity => error, cycle => Cycle};
%% `index.bs` cannot contain functions.
built(Path, {function_in_index, Name, Line}) ->
    #{tag => function_in_index, severity => error, file => Path, line => Line,
      function => Name};
%% Module names must match directories, mirroring erlc's module/filename rule.
built(Path, {module_path_mismatch, Declared, Expected, Line}) ->
    #{tag => module_path_mismatch, severity => error, file => Path, line => Line,
      declared => Declared, expected => Expected};
%% One directory is one module.
built(_Path, {module_disagreement, Declared}) ->
    #{tag => module_disagreement, severity => error,
      count => length(lists:usort([M || {_, M, _} <- Declared])),
      declarations => Declared};
built(_Path, {no_module_declaration, Paths}) ->
    #{tag => no_module_declaration, severity => error, files => Paths};
%% A source root that does not contain the module is a usage error.
built(_Path, {src_root_mismatch, Dir, Root}) ->
    #{tag => src_root_mismatch, severity => error, directory => Dir,
      root => Root};
built(_Path, {src_root_is_the_module, Dir}) ->
    #{tag => src_root_is_the_module, severity => error, directory => Dir};

%%% --- Unrecognised diagnostics ---
%%%
%%% The caller re-raises `unhandled` so unknown raised conditions remain
%%% visible.

built(Path, {Sev, _Line, _Fn, _} = D) when Sev =:= error; Sev =:= warning ->
    #{tag => unclassified, severity => Sev, file => Path, detail => D};
built(_Path, _Other) ->
    unhandled.

%% Accept the correction shapes supplied by `bs_check:corrected_signature/4`.
correction(Line) when is_list(Line) ->
    corrections(#{corrected => Line});
correction({replacing, Line, Src, New}) ->
    corrections(#{corrected => Line, replaces => #{declared => Src, within => New}});
correction({refused, {SrcA, A}, {SrcB, B}, Records}) ->
    corrections(#{indiscriminable =>
                      maps:merge(#{member => SrcA, beside => SrcB,
                                   expanded => expanded([{SrcA, A}, {SrcB, B}])},
                                 records(Records))});
correction({withhold, Why}) ->
    corrections(#{withheld => withheld(Why)}).

corrections(Set) ->
    maps:merge(#{corrected => none, indiscriminable => none,
                 withheld => none, replaces => none}, Set).

records({records, Decls, Returns}) ->
    #{declarations => Decls, returns => Returns, no_declarations => none};
records({no_records, {nested, Member, Holder}}) ->
    #{declarations => none, returns => none,
      no_declarations => #{member => Member, inside => Holder}};
records({no_records, {check_failed, Reason}}) ->
    #{declarations => none, returns => none,
      no_declarations => #{refused_by => Reason}}.

expanded(Pairs) ->
    [#{name => Src, is => bs_types:to_string(T)}
     || {Src, T} <- Pairs, Src =/= bs_types:to_string(T)].

withheld({absorbed_member, {Src, M}, By}) ->
    #{member => Src, absorbed_by => bs_types:to_string(By),
      expanded => expanded([{Src, M}])};
withheld({crashed, Class, Reason}) ->
    #{class => Class, reason => Reason};
withheld(Why) when is_atom(Why) ->
    Why.

%% `bs_check:corrected_signature/4` sets at most one of `indiscriminable`,
%% `withheld` and `replaces`, so the first three clauses never compete. The
%% final clauses read `corrected` alone. Record advice uses placeholder names,
%% not pasteable declarations: clauses must change too. The compiler mints
%% record tags; authors do not write them.
correction_text(#{indiscriminable := #{member := M, beside := B, expanded := E} = I}) ->
    {Expansion, EArgs} = expansion_text("    ", E),
    {Advice, AArgs} = records_text(I),
    {"  Widening the signature to cover what the clauses return would be refused:~n"
     "    no clause head can tell `~s` from `~s`~n" ++ Expansion ++ Advice,
     [M, B] ++ EArgs ++ AArgs};
correction_text(#{withheld := Why}) when Why =/= none ->
    withheld_reason(Why);
correction_text(#{corrected := Line, replaces := #{declared := D, within := New}}) ->
    {"  Otherwise, the signature its clauses justify:~n"
     "    ~s~n"
     "  this replaces `~s`, which `~s` contains.~n",
     [Line, D, New]};
correction_text(#{corrected := none}) ->
    {"", []};
correction_text(#{corrected := Line}) ->
    {"  Otherwise, the signature its clauses justify:~n"
     "    ~s~n", [Line]}.

%% Corrections cover the whole function: an unspellable return may come from
%% another clause than the one carrying this diagnostic. Unexpected
%% `bs_check:as_pasted/2` failures are reported as compiler defects.
withheld_reason(unspellable) ->
    {"  no signature is offered: what the clauses return has no spelling as a type yet.~n", []};
withheld_reason(declared_form) ->
    {"  no signature is offered: the declared signature is written in a form~n"
     "  this line does not reproduce.~n", []};
withheld_reason(#{member := M, absorbed_by := By, expanded := E}) ->
    {Expansion, EArgs} = expansion_text("  ", E),
    {"  no signature is offered: widening it would leave `~s` absorbed by~n"
     "  `~s`, and a declared type may not hold an absorbed member.~n" ++ Expansion,
     [M, By | EArgs]};
withheld_reason(#{reason := Reason}) ->
    {"  no signature is offered: checking it failed inside the compiler~n"
     "  (~p in bs_check:as_pasted/2), which is a compiler defect.~n", [Reason]}.

%% One line per name the author wrote that stands for a different spelling.
expansion_text(Indent, Expanded) ->
    {lists:flatten([Indent ++ "(`~s` is `~s`)~n" || _ <- Expanded]),
     lists:append([[N, Is] || #{name := N, is := Is} <- Expanded])}.

%% The named type of records, whole, with the return it makes. Where none is
%% shown, the sentence says why: a pair member inside a named type this line
%% does not rewrite, or a declaration the check refused — a compiler defect.
records_text(#{declarations := Decls, returns := Returns}) when is_list(Decls) ->
    {"  so if both are meant, give each a record of its own and name the pair:~n"
     ++ lists:flatten(["    ~s~n" || _ <- Decls]) ++
     "  declare the return as `~s`,~n"
     "  build each value as its record, and choose the names.~n",
     Decls ++ [Returns]};
records_text(#{no_declarations := #{member := M, inside := Holder}}) ->
    {"  so if both are meant, give each a record of its own and name the pair.~n"
     "  No declaration is shown: `~s` is inside `~s`,~n"
     "  and this line does not rewrite a named type.~n", [M, Holder]};
records_text(#{no_declarations := #{refused_by := Reason}}) ->
    {"  so if both are meant, give each a record of its own and name the pair.~n"
     "  No declaration is shown: checking the one this compiler would write~n"
     "  failed (~p), which is a compiler defect.~n", [Reason]}.

%%% ---------------------------------------------------------------------------
%%% `not` in prefix position
%%%
%%% Keyed on shape, not on yecc's token: the two positions it covers fail at
%%% different tokens — `(` after `not (n > 100)`, `>` after `not (value >
%%% 100)`.
%%%
%%% Runs only after a parse failure; `not` followed by an operand cannot parse
%%% because the language has no lambda. A bare `not` used as a variable is
%%% untouched. If lambdas arrive, this rule needs revisiting.
%%% ---------------------------------------------------------------------------

%% The comparison is on the line alone and must stay that way. A position is
%% `{Line, Column}`: `L` is where `not` sits, `Line` is where yecc stopped (the
%% token after it). Comparing whole locations matches nothing — silently, so
%% the diagnostic degrades to a plain syntax error.
not_in_prefix_position([{lident, L, 'not'}, Next | Rest], Line) ->
    (line_of(L) =:= line_of(Line) andalso is_operand(Next))
        orelse not_in_prefix_position([Next | Rest], Line);
not_in_prefix_position([_ | Rest], Line) -> not_in_prefix_position(Rest, Line);
not_in_prefix_position([], _Line)        -> false.

%% A location is a `{Line, Column}` pair from the lexer, or a bare line from
%% anything that reports without a column. Both are real inputs here.
line_of({Line, _Column}) -> Line;
line_of(Line)            -> Line.

%% Only a declaration's position is asked for its column, and every declaration
%% carries one. A bare line here is a crash, not a guess.
column_of({_Line, Column}) -> Column.

is_operand({'(', _})         -> true;
is_operand({lident, _, _})   -> true;
is_operand({uident, _, _})   -> true;
is_operand({integer, _, _})  -> true;
is_operand({atom_lit, _, _}) -> true;
is_operand(_)                -> false.

%%% ---------------------------------------------------------------------------
%%% message/1 — owner of every format string
%%%
%%% Every format string lives here and nowhere else. The gate
%%% `bin/check-diagnostics.sh` reads the literal headers most clauses write;
%%% the six resolve-time conditions below are the deliberate exception, whose
%%% position is optional. `contractual/0` freezes the payload shape of seven
%%% tags; no clause's prose is frozen by that list, and not every string here
%%% is replayed by something.
%%% ---------------------------------------------------------------------------

%% A condition whose position is optional builds its header rather than writing
%% a literal. The six resolve-time conditions are found below the level that
%% holds a position and are given one by `bs_check:at_loc/2` when the
%% declaration they were found in has one. Both shapes are real: the positioned
%% header carries three slots (file, line, column), the bare one carries one
%% (file).
%%
%% Every other diagnostic carries a position always and writes its header as a
%% literal, which is what the gate reads. These six are the only exception: a
%% clause that writes the positioned header literally is a gate defect, because
%% it drops a column the term beside it carries.
placed(#{line := _, column := _}) -> "~s:~p:~p: ";
placed(_)                         -> "~s: ".

placed_args(#{file := P, line := L, column := C}) -> [P, L, C];
placed_args(#{file := P})                         -> [P].

%% `ToJson<T>`'s refusal, in three pieces. A member at the top of `T` has no
%% path to name.
%% Rationale: compiler/features/F50-to-json.md.
unencodable_at([])   -> "";
unencodable_at(Segs) -> "in " ++ lists:append(Segs) ++ ", ".

unencodable_member(M, tuple)  -> "`" ++ M ++ "` is a tuple, and JSON has no encoding for one";
unencodable_member(M, arrow)  -> "`" ++ M ++ "` is a function, which has no value outside this VM";
unencodable_member(M, binary) -> "`" ++ M ++ "` is a `binary`, which may hold bytes that are not UTF-8";
unencodable_member(M, term)   -> "`" ++ M ++ "` may hold a tuple or a function, and JSON encodes neither".

%% A `result` is the tuple an author meets first, so the tuple's repair names it.
unencodable_repair(tuple) ->
    "Encode what the tuple holds instead: take a `result` apart in a switch\n"
    "  arm and encode the value each arm has, or declare a record where the\n"
    "  tuple is.";
unencodable_repair(arrow) ->
    "Leave the function out of the value you put on the wire.";
unencodable_repair(binary) ->
    "Declare it `string`, which is UTF-8 by refinement and goes on the wire\n"
    "  as itself.";
unencodable_repair(term) ->
    "Validate the term into a declared type first, with ValidateAs<T>, and\n"
    "  encode that type.".

message(#{tag := inexhaustive, file := P, line := L, column := C, function := Fn,
          heads := Heads}) ->
    {"~s:~p:~p: error: ~s is not exhaustive~n"
     "  no clause matches:~n~s",
     [P, L, C, Fn, heads_prose(Fn, Heads)]};
%% A catch-all is legal only over an open residual. The message carries a
%% conditionally legal `_` for a reader from C# or TypeScript: the residual is
%% the missing case, so what makes the error legitimate is what answers it.
message(#{tag := catch_all_over_closed, file := P, line := L, column := C, function := Fn,
          heads := Heads}) ->
    {"~s:~p:~p: error: ~s discards cases the compiler can name~n"
     "  every value left here comes from a type you declared, so `_`~n"
     "  hides a case rather than admitting an unknown one:~n~s"
     "  a catch-all is for a residual with an unbounded top in it — a~n"
     "  `term` argument, or the open atom universe — where a foreign~n"
     "  sender chooses the inhabitants and there is nothing to enumerate.~n",
     [P, L, C, Fn, heads_prose(Fn, Heads)]};
%% The construct is a head's, so the message says where to put it rather than
%% only that it is wrong.
%% Rationale: compiler/features/F2-interval-refinements.md.
message(#{tag := relational_in_bind, file := P, line := L, column := C, function := Fn}) ->
    {"~s:~p:~p: error: ~s binds a relational pattern~n"
     "  `>= 4` names a span of values and introduces no name, so there~n"
     "  is nothing for a bind to bind. A bind must also be provably~n"
     "  irrefutable, and a span is the refutable construct itself.~n"
     "  Dispatch on it in a clause head instead.~n",
     [P, L, C, Fn]};
message(#{tag := no_clauses, file := P, line := L, column := C, function := Fn}) ->
    {"~s:~p:~p: error: ~s has a signature but no clauses~n", [P, L, C, Fn]};
%% The wording fits a pattern the same way it fits a guard: both test a shape a
%% type variable has none. The two ways out are the same.
message(#{tag := pattern_on_type_variable, file := P, line := L, column := C,
          function := Fn, type_variable := V, argument := I}) ->
    {"~s:~p:~p: error: ~s inspects a value whose type is the variable `~s`~n"
     "  the pattern in argument ~p tests a runtime shape, and `~s` has no shape"
     " until a caller chooses one~n"
     "  hint: a bare type variable admits one clause, so bind it — or take a"
     " union parameter instead of a type variable to dispatch on shape~n",
     [P, L, C, Fn, V, I, V]};
message(#{tag := unrecoverable_type_variable, file := P, line := L, column := C,
          function := Fn, type_variable := V}) ->
    {"~s:~p:~p: error: ~s's type variable `~s` appears in no parameter~n"
     "  instantiation is matching: a caller's arguments choose `~s`, and a variable"
     " only in the return type has nothing to be matched against~n"
     "  hint: write the type the function actually returns, or take a parameter"
     " whose type mentions `~s`~n",
     [P, L, C, Fn, V, V, V]};
message(#{tag := obligation_over_type_variable, file := P, line := L, column := C,
          function := Fn, obligation := Name, type_variable := V}) ->
    {"~s:~p:~p: error: ~s asks ~s to be generated over the type variable `~s`~n"
     "  a codegen obligation is a traversal of one concrete type, and `~s` is not"
     " one until a caller chooses it~n"
     "  hint: take the value already validated — a parameter of type `~s` was"
     " checked by its caller — or name the concrete type to validate into~n",
     [P, L, C, Fn, Name, V, V, V]};
%% Only a divisor proved to be zero is refused, so the message says so: a
%% divisor that might be zero compiles and crashes at run time.
message(#{tag := float_remainder, file := P, line := L, column := C, function := Fn}) ->
    {"~s:~p:~p: error: `%` in ~s has a `float` on both sides~n"
     "  `%` is the remainder over two `int`s; over two floats it has no meaning~n"
     "  the language has decided, and the platform's `rem` would crash.~n",
     [P, L, C, Fn]};
message(#{tag := mixed_operands, file := P, line := L, column := C, function := Fn,
          op := Op, left := Left, right := Right, literal := Lit}) ->
    {"~s:~p:~p: error: `~s` in ~s has ~s `~s` on its left and ~s `~s` on its right~n"
     "  nothing converts between the two: write the conversion, `Float.FromInt(n)`,~n"
     "  on the `int` side~s~n",
     [P, L, C, Op, Fn, article(Left), Left, article(Right), Right,
      case Lit of
          none -> "";
          Text -> ", or write `" ++ Text ++ "` to make the literal a float"
      end]};
message(#{tag := divide_by_zero, file := P, line := L, column := C, function := Fn,
          op := Op}) ->
    {"~s:~p:~p: error: the right-hand side of `~s` in ~s is always zero~n"
     "  `~s` needs no proof that a divisor is non-zero — a divisor that MIGHT~n"
     "  be zero compiles and crashes at run time. Only one the compiler can~n"
     "  prove is zero is refused, and this is one.~n",
     [P, L, C, Op, Fn, Op]};
%% Not routed through `heads_prose/2`: that prints `Fn(:cancelled) -> ...`,
%% and a switch has no function name and its arrow is `=>`. The pattern inside
%% the wrapper is the head channel's, via `arms/2`.
message(#{tag := switch_inexhaustive, file := P, line := L, column := C, function := Fn,
          arms := Arms} = D) ->
    {"~s:~p:~p: error: this switch in ~s is not exhaustive~n"
     "  no arm matches:~n~s",
     [P, L, C, Fn, arms_prose(Arms, D)]};
%% A valve over a value with neither member of the short-circuit pair generates
%% arms that can never match, but the author wrote no arms; they wrote the
%% wrong operator, so the diagnostic names the right one.
%%
%% It names both members because it looked for both. Naming `(:error, _)` alone
%% would tell an author their type had no error member while the compiler asked
%% a wider question.
%% Rationale: compiler/features/F30-valve-short-circuit-set.md.
message(#{tag := valve_on_infallible, file := P, line := L, column := C, function := Fn,
          subject := Ty}) ->
    {"~s:~p:~p: error: this |?> in ~s is over a value that cannot fail~n"
     "  ~s has no (:error, _) or :nothing member, so the valve would never stop.~n"
     "  Write |> instead.~n",
     [P, L, C, Fn, Ty]};
%% Arm, not clause: a construct with no clauses cannot be told which clause is
%% dead.
message(#{tag := unreachable_arm, file := P, line := L, column := C, function := Fn,
          arm_number := N}) ->
    {"~s:~p:~p: warning: arm ~p of this switch in ~s is unreachable~n"
     "  every value it matches is matched by an earlier arm.~n",
     [P, L, C, N, Fn]};
%% An arm has a third repair, because the subject is right there and may itself
%% be the mistake.
message(#{tag := vacuous_arm, file := P, line := L, column := C, function := Fn,
          arm_number := N, domain := Dom}) ->
    {"~s:~p:~p: warning: arm ~p of this switch in ~s matches no value~n"
     "  the subject's type is ~s, and this arm's pattern is not a~n"
     "  member of it — so no value reaching this switch can take~n"
     "  this arm.~n",
     [P, L, C, N, Fn, Dom]};
%% Must not name the type: the pattern is a good member of it, and the guard is
%% what admits nothing.
message(#{tag := unsatisfiable_arm_guard, file := P, line := L, column := C, function := Fn,
          arm_number := N}) ->
    {"~s:~p:~p: warning: arm ~p of this switch in ~s has an unsatisfiable guard~n"
     "  the pattern is a member of the subject's type; it is the~n"
     "  guard that admits nothing. Widen the guard, or delete the arm.~n",
     [P, L, C, N, Fn]};
%% A guard shares the whole expression grammar, so a switch parses inside one
%% and is refused here rather than in the grammar.
%% Rationale: compiler/features/F7-switch.md.
message(#{tag := switch_in_guard, file := P, line := L, column := C, function := Fn}) ->
    {"~s:~p:~p: error: ~s has a switch in a guard~n"
     "  a guard asks a question about the values a clause already~n"
     "  matched; it cannot branch. Move the switch into the body.~n",
     [P, L, C, Fn]};
%% Same reason as the switch above: a guard shares the whole expression
%% grammar, so a raise parses inside one and is refused here rather than in the
%% grammar. The repair names the body because that is where a crash belongs.
message(#{tag := raise_in_guard, file := P, line := L, column := C, function := Fn}) ->
    {"~s:~p:~p: error: ~s raises in a guard~n"
     "  a guard chooses which clause runs; it cannot crash. Move~n"
     "  the raise into the body of the clause it should fail.~n",
     [P, L, C, Fn]};
%% A guard may run only the BEAM's guard BIFs, never a user function; B#
%% inherits that from Erlang. The repair names the body and a switch because
%% that is the shape the author's guard was reaching for. Nothing here promises
%% a named-guard form.
%% Rationale: compiler/features/F41-call-in-guard.md.
message(#{tag := call_in_guard, file := P, line := L, column := C, function := Fn,
          callee := Callee}) ->
    {"~s:~p:~p: error: ~s calls ~s in a guard~n"
     "  a guard asks a question about the values a clause already~n"
     "  matched; it cannot call a function. Move the call into the~n"
     "  body and switch on its answer.~n",
     [P, L, C, Fn, Callee]};
%% The foreign case says why this call and not `:erlang.byte_size`: the set is
%% the BEAM's, and the author may know it.
message(#{tag := foreign_call_in_guard, file := P, line := L, column := C,
          function := Fn, callee := Callee}) ->
    {"~s:~p:~p: error: ~s calls ~s in a guard~n"
     "  only the BEAM's own guard functions may run in a guard, and~n"
     "  `~s` is not one of them. Move the call into the~n"
     "  body and switch on its answer.~n",
     [P, L, C, Fn, Callee, Callee]};
message(#{tag := unreachable_clause, file := P, line := L, column := C, function := Fn,
          clause_number := N}) ->
    {"~s:~p:~p: warning: clause ~p of ~s is unreachable~n"
     "  every value it matches is matched by an earlier clause.~n",
     [P, L, C, N, Fn]};
%% Names the type, because the pattern is not a member of it: `option<T>` is `T
%% | :nothing`, untagged, so a `(:some, x)` brought from C#, Rust or F# matches
%% nothing.
message(#{tag := vacuous_clause, file := P, line := L, column := C, function := Fn,
          clause_number := N, domain := Dom}) ->
    {"~s:~p:~p: warning: clause ~p of ~s matches no value of its input~n"
     "  the declared input is ~s, and this clause's pattern is not~n"
     "  a member of it — so no call can reach this clause.~n",
     [P, L, C, N, Fn, Dom]};
%% Must not name the type: the pattern is a good member of it, and the guard is
%% what admits nothing.
message(#{tag := unsatisfiable_guard, file := P, line := L, column := C, function := Fn,
          clause_number := N}) ->
    {"~s:~p:~p: warning: clause ~p of ~s has a guard no value satisfies~n"
     "  the pattern is a member of the input; it is the guard that~n"
     "  admits nothing. Widen the guard, or delete the clause.~n",
     [P, L, C, N, Fn]};
%% Would otherwise reach the author as an `erlc` error against the emitted
%% `.abstr`, a file they did not write.
message(#{tag := rebinding, file := P, line := L, column := C, function := Fn, name := V}) ->
    {"~s:~p:~p: error: ~s binds ~s twice~n"
     "  a name means one thing in a clause. There is no mutation to~n"
     "  assign with, so rename the second one.~n",
     [P, L, C, Fn, V]};
%% The same offence as `rebinding` and a different fix, hence a different tag:
%% in a body you rename, in a head you almost always meant the same value
%% again, spelled `== x`.
%% Rationale: compiler/features/F8-bind-and-match.md.
message(#{tag := repeated_in_head, file := P, line := L, column := C, function := Fn,
          name := V}) ->
    {"~s:~p:~p: error: ~s binds ~s twice in one head~n"
     "  a name means one thing in a clause, so this introduces ~s and~n"
     "  then introduces it again. To match the value the first one~n"
     "  holds, write `== ~s`.~n",
     [P, L, C, Fn, V, V, V]};
message(#{tag := unbound_variable, file := P, line := L, column := C, function := Fn,
          name := V}) ->
    {"~s:~p:~p: error: ~s uses ~s, which nothing binds~n"
     "  a name comes from a clause head or a binding above it.~n",
     [P, L, C, Fn, V]};
%% The residual is the clause the caller must write: the fix is an edit to the
%% function being checked, never to the callee.
message(#{tag := arg_not_accepted, file := P, line := L, column := C, function := Fn,
          callee := Callee, position := Pos, rejected := Rejected,
          caller_head := Head}) ->
    {"~s:~p:~p: error: ~s hands ~s an argument it does not accept~n"
     "  argument ~p is not covered by ~s's declared type:~n"
     "    ~s~n~s",
     [P, L, C, Fn, Callee, Pos, Callee, Rejected, caller_head_prose(Fn, Head)]};
%% Answered in field names, because `Order{Id} \ Order` would name the type
%% being built rather than the field forgotten. The verb is read from the
%% form; `field_list/2` renders an empty `Missing` as nothing.
message(#{tag := field_set_mismatch, file := P, line := L, column := C, function := Fn,
          record := Record, form := Form, missing := Missing, extra := Extra}) ->
    {"~s:~p:~p: error: ~s ~s an ~s with the wrong fields~n~s~s",
     [P, L, C, Fn, field_set_verb(Form), Record,
      field_list("  missing, and must be supplied", Missing),
      field_list("  not declared by " ++ atom_to_list(Record), Extra)]};
%% Shaped on `return_not_declared`'s message: both say a synthesised value is
%% not contained in a declared type, differing only in which declaration.
message(#{tag := field_value_not_accepted, file := P, line := L, column := C, function := Fn,
          record := Record, field := Field, rejected := Rejected}) ->
    {"~s:~p:~p: error: ~s assigns ~s a value ~s does not accept~n"
     "  not covered by the declared type of ~s:~n"
     "    ~s~n",
     [P, L, C, Fn, Field, Record, Field, Rejected]};
%% The residual is the member that lacks the field, which is the tag to
%% discriminate on.
%% Rationale: compiler/features/F3-records.md.
message(#{tag := field_absent, file := P, line := L, column := C, function := Fn,
          form := projection, field := Field, member := Member}) ->
    {"~s:~p:~p: error: ~s projects ~s from a value that may not carry it~n"
     "  this member has no ~s:~n"
     "    ~s~n"
     "  discriminate on the tag first, in a clause head.~n",
     [P, L, C, Fn, Field, Field, Member]};
%% The member handed back is either one arm of a union or the whole subject,
%% and the fix differs: the first is discriminated on, the second has no tag
%% and needs a record. The line names both edits.
message(#{tag := field_absent, file := P, line := L, column := C, function := Fn,
          form := update, field := Field, member := Member}) ->
    {"~s:~p:~p: error: ~s updates ~s on a value that may not carry it~n"
     "  this member has no ~s:~n"
     "    ~s~n"
     "  `with` updates a record: give it one, or discriminate on the tag~n"
     "  first, in a clause head.~n",
     [P, L, C, Fn, Field, Field, Member]};
%% Without this the emitted `-spec` would claim what the body does not deliver.
%% The residual answers what is not covered and `correction_text/1` answers
%% what to write, added beside the residual and never substituted for it.
%%
%% Every one leads with the clause: the signature states intent and the
%% compiler holds the clauses to it, as exhaustiveness does for the inputs. The
%% widened line is offered after it.
%% Rationale: compiler/features/F25-corrected-signature.md.
message(#{tag := return_not_declared, file := P, line := L, column := C, function := Fn,
          undeclared := Undeclared, declared := Declared} = D) ->
    {Fmt, Args} = correction_text(D),
    {"~s:~p:~p: error: ~s returns a value its signature does not declare~n"
     "  not covered by the declared return type:~n"
     "    ~s~n"
     "  If `~s` is what you meant, fix the clause, not the signature.~n"
     ++ float_spelling(Undeclared, Declared) ++ Fmt,
     [P, L, C, Fn, Undeclared, Declared | Args]};
%% A destructuring bind is allowed exactly when this residual is empty, so it
%% is provably irrefutable.
message(#{tag := bind_may_fail, file := P, line := L, column := C, function := Fn,
          unmatched := Unmatched}) ->
    {"~s:~p:~p: error: this bind in ~s can fail~n"
     "  the pattern does not match:~n"
     "    ~s~n"
     "  a bind that can fail is a branch the exhaustiveness checker~n"
     "  never sees. Match it in a clause head instead.~n",
     [P, L, C, Fn, Unmatched]};
%% A function as a value. The lambda's message names the two ways out; the bare
%% name's names the spelling that picks an arity.
%% Rationale: compiler/features/F46-function-as-a-value.md.
message(#{tag := lambda_without_expectation, file := P, line := L, column := C,
          function := Fn}) ->
    {"~s:~p:~p: error: a lambda in ~s has no arrow to take its type from~n"
     "  a lambda's type is the arrow its site expects — a call argument, a~n"
     "  clause return, a record field — and nothing here expects one.~n"
     "  Hand it to the site that expects it, or write a private function.~n",
     [P, L, C, Fn]};
message(#{tag := name_arity_unfixed, file := P, line := L, column := C, function := Fn,
          name := Name, declared := []}) ->
    {"~s:~p:~p: error: ~s uses ~s as a value, which nothing declares~n"
     "  every function has a signature. Write one, or fix the name.~n",
     [P, L, C, Fn, Name]};
message(#{tag := name_arity_unfixed, file := P, line := L, column := C, function := Fn,
          name := Name, declared := Arities}) ->
    {"~s:~p:~p: error: ~s uses ~s as a value, and nothing fixes which one~n"
     "  ~s is declared at ~s. A bare name reads its arity from the arrow~n"
     "  its site expects; where nothing does, write it: `~s/~p`.~n",
     [P, L, C, Fn, Name, Name,
      lists:join(", ", [[$/ | integer_to_list(A)] || A <- Arities]),
      Name, hd(Arities)]};
message(#{tag := lambda_param_refuted, file := P, line := L, column := C, function := Fn,
          argument := Pos, unmatched := Unmatched}) ->
    {"~s:~p:~p: error: a lambda in ~s can fail to match its parameter ~p~n"
     "  the pattern does not match:~n"
     "    ~s~n"
     "  a lambda's parameter is one irrefutable pattern. Bind it, and~n"
     "  switch on it in the body.~n",
     [P, L, C, Fn, Pos, Unmatched]};
message(#{tag := not_callable, file := P, line := L, column := C, function := Fn,
          name := Var, arity := Arity, type := Type}) ->
    {"~s:~p:~p: error: ~s calls ~s with ~p argument~s, and it is not a function of that arity~n"
     "  ~s has the type:~n"
     "    ~s~n"
     "  only a value whose type is an arrow of this arity can be called.~n",
     [P, L, C, Fn, Var, Arity, plural(Arity), Var, Type]};
%% One argument can be both sides: a function whose result is not a value its
%% own parameter takes, handed where the two must agree.
message(#{tag := instantiation_conflict, file := P, line := L, column := C, function := Fn,
          callee := Callee, type_variable := Var, lower_argument := Pos,
          lower := Low, upper_argument := Pos, upper := Up}) ->
    {"~s:~p:~p: error: ~s calls ~s with an argument that disagrees with itself about ~s~n"
     "  argument ~p supplies ~s as:~n"
     "    ~s~n"
     "  and accepts ~s only as:~n"
     "    ~s~n"
     "  no ~s satisfies both, so a value it produces would reach a function~n"
     "  that does not take it.~n",
     [P, L, C, Fn, Callee, Var, Pos, Var, Low, Var, Up, Var]};
message(#{tag := instantiation_conflict, file := P, line := L, column := C, function := Fn,
          callee := Callee, type_variable := Var, lower_argument := LowPos,
          lower := Low, upper_argument := UpPos, upper := Up}) ->
    {"~s:~p:~p: error: ~s calls ~s with arguments that disagree about ~s~n"
     "  argument ~p supplies ~s as:~n"
     "    ~s~n"
     "  argument ~p accepts ~s only as:~n"
     "    ~s~n"
     "  no ~s satisfies both, so a value from one would reach a function~n"
     "  that does not take it.~n",
     [P, L, C, Fn, Callee, Var, LowPos, Var, Low, UpPos, Var, Up, Var]};
message(#{tag := validate_over_arrow, file := P, line := L, column := C, function := Fn,
          type := Type}) ->
    {"~s:~p:~p: error: ~s asks ValidateAs to check a function~n"
     "  `~s` holds an arrow, and a function's type is not recoverable~n"
     "  from the value at run time, so there is nothing to check.~n"
     "  Take the function through a signature instead.~n",
     [P, L, C, Fn, Type]};
message(#{tag := lambda_in_guard, file := P, line := L, column := C, function := Fn}) ->
    {"~s:~p:~p: error: ~s writes a lambda in a guard~n"
     "  a guard asks a question about the values a clause already~n"
     "  matched; it cannot build a function. Move it into the body.~n",
     [P, L, C, Fn]};
%% Reported as `unknown_callee` this would say the function does not exist,
%% when it is one word away from callable; that is why
%% `bs_check:exports_of/1` does not simply filter private functions out.
%% Rationale: compiler/features/F12-public-and-private.md.
message(#{tag := private_function, file := P, line := L, column := C, function := Fn,
          module := Mod, callee := Callee, arity := Arity}) ->
    {"~s:~p:~p: error: ~s calls ~s/~p, which ~s declares `private`~n"
     "  a private function is not exported, so no other module can~n"
     "  reach it. Mark it `public` in ~s, or move the call inside it.~n",
     [P, L, C, Fn, Callee, Arity, Mod, Mod]};
message(#{tag := unknown_callee, file := P, line := L, column := C, function := Fn,
          callee := Callee, arity := Arity}) ->
    {"~s:~p:~p: error: ~s calls ~s/~p, which nothing declares~n"
     "  every function has a signature. Write one, or fix the name.~n",
     [P, L, C, Fn, Callee, Arity]};
message(#{tag := arity_mismatch, file := P, line := L, column := C, function := Fn,
          callee := Callee, got := Got, want := Want}) ->
    {"~s:~p:~p: error: ~s calls ~s with ~p arguments, and it takes ~p~n",
     [P, L, C, Fn, Callee, Got, Want]};
%% Arity overloading is permitted, so this is not "wrong number of arguments"
%% but a function not declared beside ones that are. Naming the arities that do
%% exist keeps it a fix rather than a verdict.
message(#{tag := arity_not_declared, file := P, line := L, column := C, function := Fn,
          callee := Callee, got := Got, declared := Have}) ->
    {"~s:~p:~p: error: ~s calls ~s/~p, which nothing declares~n"
     "  ~s is declared at ~s. Arity overloading is permitted, so~n"
     "  ~s/~p would be a new function and needs its own signature.~n",
     [P, L, C, Fn, Callee, Got, Callee,
      lists:join(", ", [[$/ | integer_to_list(A)] || A <- Have]),
      Callee, Got]};
%% Names the spellings still legal, because only the whole module name is taken
%% and an author just refused needs to know `Shop.Collections.List` remains
%% open.
message(#{tag := reserved_module_name, file := P, line := L, column := C, module := Mod}) ->
    {"~s:~p:~p: error: `~s` is a reserved qualifier, so no module may be called it~n"
     "  `~s.` names operations the compiler knows and inlines at the site;~n"
     "  no beam ships for it and no `using` is ever written. The name is~n"
     "  taken only as a WHOLE module name — `Shop.~s` is still legal, and~n"
     "  so is any other path with `~s` as a segment.~n",
     [P, L, C, Mod, Mod, Mod, Mod]};
%% `ambiguous_module`'s shape with a compiler-known claimant: both meanings
%% named, the full path handed over as the fix.
message(#{tag := reserved_qualifier_shadowed, file := P, line := L, column := C,
          function := Fn, qualifier := Q, operation := Op,
          candidates := Mods}) ->
    {"~s:~p:~p: error: ~s calls ~s.~s, and `~s` means two things here~n"
     "  `~s` is a reserved qualifier — the compiler's own operations —~n"
     "  and a `using` line also short-qualifies these to it:~n"
     "~s"
     "  write the module's full path to reach it, or drop the namespace~n"
     "  import to reach `~s.~s`.~n",
     [P, L, C, Fn, Q, Op, Q, Q,
      [io_lib:format("    ~s.~s(...)~n", [M, Op]) || M <- Mods],
      Q, Op]};
%% Stops an unknown operation falling through to `module_not_imported`, whose
%% "add `using List`" is the one fix that can never work for a reserved
%% qualifier.
message(#{tag := unknown_reserved_operation, file := P, line := L, column := C,
          function := Fn, qualifier := Q, operation := Op, got := Got,
          declared := []}) ->
    {"~s:~p:~p: error: ~s calls ~s.~s/~p, and `~s` has no operation of that name~n"
     "  `~s` is a reserved qualifier, so this cannot be fixed with a~n"
     "  `using` line — the operations under it are the compiler's own.~n",
     [P, L, C, Fn, Q, Op, Got, Q, Q]};
message(#{tag := unknown_reserved_operation, file := P, line := L, column := C,
          function := Fn, qualifier := Q, operation := Op, got := Got,
          declared := Have}) ->
    {"~s:~p:~p: error: ~s calls ~s.~s/~p, and `~s.~s` takes ~s~n"
     "  the operations under a reserved qualifier are the compiler's own,~n"
     "  so the arity is fixed rather than overloadable.~n",
     [P, L, C, Fn, Q, Op, Got, Q, Op,
      lists:join(" or ", [[integer_to_list(A), " argument",
                           case A of 1 -> ""; _ -> "s" end] || A <- Have])]};
%% F57: a map literal would keep the last value; the brace expression refuses.
message(#{tag := duplicate_field, file := P, line := L, column := C, function := Fn,
          field := Key}) ->
    {"~s:~p:~p: error: ~s writes the field ~s twice in one brace~n"
     "  a field set holds each key once; delete one of the two.~n",
     [P, L, C, Fn, Key]};
message(#{tag := unknown_record, file := P, line := L, column := C, function := Fn,
          record := Name}) ->
    {"~s:~p:~p: error: ~s builds an ~s, which no record or type declares~n",
     [P, L, C, Fn, Name]};
%% `_` is an expression only so that `(a, _) = pair` parses, so its use as a
%% value is caught here rather than by `erlc` against a file the author did not
%% write.
%% Rationale: compiler/features/F5-body-check-site.md.
message(#{tag := wildcard_as_value, file := P, line := L, column := C, function := Fn}) ->
    {"~s:~p:~p: error: ~s uses `_` as a value~n"
     "  `_` is a pattern. It may stand on the left of `=` or in a~n"
     "  clause head; it names nothing to read back.~n",
     [P, L, C, Fn]};

%%% --- the codegen-obligation refusals ---------------------------------------

%% The message says why rather than only what, because the rule is not
%% obvious and the fix is to want something else entirely.
message(#{tag := validate_collapses, file := P, line := L, column := C, function := Fn,
          type := Ty}) ->
    {"~s:~p:~p: error: ~s validates against a type that absorbs its own~n"
     "  failure channel~n"
     "  the type is: ~s~n"
     "  `result<T, ValidationError>` over it normalises straight back to~n"
     "  T, so the validator could only ever succeed and no caller could~n"
     "  write the failure clause. Validate against the type you actually~n"
     "  expect.~n",
     [P, L, C, Fn, Ty]};
%% The declaration is legal; the objection is to validating into it, so the
%% repair is a different target rather than a different type.
message(#{tag := validate_indiscriminable, file := P, line := L, column := C,
          function := Fn, type := Ty, member := M, beside := B}) ->
    {"~s:~p:~p: error: ~s validates into a union whose members no clause head can tell apart~n"
     "  the members are `~s` and `~s`~n"
     "  the type is: ~s~n"
     "  The validator works out which member arrived, then returns a type~n"
     "  with nowhere to keep the answer: a caller can pass the value on but~n"
     "  never dispatch on it. Tag the members - `(:a, ...) | (:b, ...)` -~n"
     "  and validate against that.~n",
     [P, L, C, Fn, M, B, Ty]};
%% Says the compiler is not ready, not that the pattern is wrong:
%% `{ Status: s }` is a member of `map<atom, term>`, so "matches no value"
%% would be false.
%%
%% The advice is the feature. `mixed_operands` next door offers the int
%% literal's float spelling — "write `0.0`" — and over a union that spelling is
%% refused too, by the no-flow rule. So this message names dispatch and nothing
%% else, and prints the two heads in the syntax the author writes them in,
%% which `check-advice-compiles.sh` pastes back and compiles.
%%
%% The parts are `int` and `float` by construction: the refusal fires only
%% where both are present and nothing else is (`numeric_union/1`).
%% Rationale: compiler/features/F53-numeric-union-dispatch.md.
message(#{tag := numeric_union_operand, file := P, line := L, column := C,
          function := Fn, op := Op, side := Side, type := Ty} = D) ->
    %% The advised heads are a format fragment, built by `union_heads/2` from
    %% the function's real parameter list — every position, with the author's
    %% own names — so what is printed is a clause they can paste. Where no
    %% parameter carries the union there is no head to write and the fragment
    %% says where to dispatch instead.
    {"~s:~p:~p: error: `~s` in ~s has `~s` on its ~s~n"
     "  a union whose parts are all numeric is the mixed pair wherever one~n"
     "  part would be: nothing converts between `int` and `float`, so `~s`~n"
     "  has no one meaning over both.~n"
     ++ dispatch_advice(maps:get(heads, D, [])),
     [P, L, C, Op, Fn, Ty, Side, Op]};
%% Says which test is true of more values than the type holds, rather than
%% claiming in general that none decides it — `term` is decided by every test
%% and `list<int>` by none, and one sentence for both would be false of one.
message(#{tag := type_prefix_nested, file := P, line := L, column := C}) ->
    {"~s:~p:~p: error: a type prefix goes where a whole argument goes~n"
     "  `Post(float f)` is the shipped form, and a switch arm takes it too.~n"
     "  Inside a tuple, a list or a record pattern it is not built yet —~n"
     "  bind the position there and dispatch it in a clause of its own.~n",
     [P, L, C]};
message(#{tag := type_prefix_undecidable, file := P, line := L, column := C,
          type := Ty, reason := Why}) ->
    %% The reason is a format fragment concatenated into the format string,
    %% not an argument: `~s` takes bytes, and a sentence carrying an em dash
    %% is a `badarg` there. `float_spelling/2` above is built the same way.
    Because =
        case Why of
            %% `map<K, V>`'s refusal, including the sentence that makes it
            %% temporary: it lifts when a pattern form for it ships.
            {narrower, Bif} ->
                "  `" ++ atom_to_list(Bif) ++ "` is true of more values than `" ++ Ty
                    ++ "` holds,~n  so one test does not decide it: it can be"
                    " declared, passed and~n  returned, and never matched on."
                    " Matching one is not built.~n"
                    "  The refusal is temporary by construction — the day a pattern"
                    " form~n  reaches inside, the type becomes decidable and it"
                    " lifts.~n";
            several_parts ->
                "  `" ++ Ty ++ "` spans more than one part and a prefix tests one:~n"
                "  name a part, in a clause of its own.~n";
            empty ->
                "  `" ++ Ty ++ "` holds no value, so no pattern can match it.~n"
        end,
    {"~s:~p:~p: error: `~s` cannot name a pattern~n"
     ++ Because ++
     "  A type prefix names a record, whose minted tag the pattern matches,~n"
     "  or a part the platform tests whole: `int`, `float`, `atom`,~n"
     "  `binary`, `bool`. Bind the value and read it otherwise.~n",
     [P, L, C, Ty]};
message(#{tag := map_pattern_deferred, file := P, line := L, column := C, function := Fn,
          site := Site, type := Ty}) ->
    %% The same refusal, not the same sentence: an arm's subject is not a
    %% parameter, and "a clause head" would send a `switch` author to the
    %% wrong line.
    {Where, Subject} =
        case Site of
            head -> {"a clause head", "the parameter's type is"};
            arm  -> {"a switch arm",  "the subject's type is"}
        end,
    {"~s:~p:~p: error: ~s destructures a map whose keys are not a fixed list~n"
     "  ~s: ~s~n"
     "  `map<K, V>` ships as a type — declare it, pass it, store it,~n"
     "  return it — but matching one in ~s is not built. A pattern~n"
     "  over an unbounded key set cannot be proved exhaustive, which is~n"
     "  the guarantee every other head in this language keeps.~n"
     "  Bind the whole map and read it, or declare a record if the keys~n"
     "  are known.~n",
     [P, L, C, Fn, Subject, Ty, Where]};
%% `ToExistingAtom` takes no type argument — its result is fixed — so the
%% sentence that ends "Write `Name<T>(x)`" would advise the form the compiler
%% just refused. It gets its own sentence, which `check-advice-compiles.sh`
%% exists to catch.
%% Rationale: compiler/features/F54-to-existing-atom.md.
message(#{tag := obligation_arity, file := P, line := L, column := C, function := Fn,
          obligation := 'ToExistingAtom', type_args := Types, args := Args}) ->
    {"~s:~p:~p: error: ~s writes ToExistingAtom with ~p type arguments and ~p values~n"
     "  ToExistingAtom is a codegen obligation, not a function, and it takes~n"
     "  no type argument and one value: its result is always~n"
     "  `result<atom, string>`, so there is no type to choose. The~n"
     "  parentheses hold the string to look up.~n"
     "  Write `ToExistingAtom(s)`.~n",
     [P, L, C, Fn, Types, Args]};
message(#{tag := obligation_arity, file := P, line := L, column := C, function := Fn,
          obligation := Name, type_args := Types, args := Args}) ->
    {"~s:~p:~p: error: ~s writes ~s with ~p type arguments and ~p values~n"
     "  ~s is a codegen obligation, not a function: it takes exactly one~n"
     "  type argument and one value. The bracket names the type to~n"
     "  generate a check for, the parentheses hold the term to check.~n"
     "  Write `~s<T>(x)`.~n",
     [P, L, C, Fn, Name, Types, Args, Name, Name]};
%% Two sentences, because the closed set of obligations lives in the checker
%% rather than the lexer: one is "wait for us", the other "that was never
%% going to work".
message(#{tag := obligation_unbuilt, file := P, line := L, column := C, function := Fn,
          obligation := Name, built := Built}) ->
    {"~s:~p:~p: error: ~s uses ~s, which is decided and not built yet~n"
     "  the instantiation bracket admits it — ticket 28 fixed the set of~n"
     "  names it may follow — but this compiler generates nothing for it.~n"
     "  Built today: ~s.~n",
     [P, L, C, Fn, Name,
      lists:join(", ", [atom_to_list(N) || N <- Built])]};
%% `ParseAtom<T>` reads `T`'s members to generate the parse, so a type with no
%% enumerable member list is refused at the call. The message names the whole
%% type rather than its atom part, because the mixed case — `:a | int`, whose
%% atom part is finite — is the one an author will not see.
%% Rationale: compiler/features/F39-parse-atom.md.
message(#{tag := parse_atom_not_finite, file := P, line := L, column := C, function := Fn,
          type := Ty}) ->
    {"~s:~p:~p: error: ~s parses into ~s, which is not a finite set of atoms~n"
     "  ParseAtom<T> generates one match arm per member of T, so T must be~n"
     "  atoms and nothing else, and there must be finitely many of them.~n"
     "  `atom` is every atom there could be, and a union carrying anything~n"
     "  besides atoms would promise a value the parse can never return.~n",
     [P, L, C, Fn, Ty]};
%% The argument is matched as a binary. A value of another kind could only
%% answer `:nothing`, which would read as "no member has that name" when the
%% truth is that the thing handed over was never a name.
message(#{tag := parse_atom_arg, file := P, line := L, column := C, function := Fn,
          type := Ty}) ->
    {"~s:~p:~p: error: ~s hands ParseAtom a ~s, and it parses a string~n"
     "  the generated match is over the members' printed names, so the~n"
     "  argument must be a `string` or a `binary`.~n"
     "  A `term` from a boundary is matched into one first.~n",
     [P, L, C, Fn, Ty]};
%% The argument flows into the result here — the failure carries the name as a
%% `string` — so a `binary` is refused as well as a `term`, and the sentence
%% names the way from each to a `string`.
message(#{tag := to_existing_atom_arg, file := P, line := L, column := C, function := Fn,
          type := Ty}) ->
    {"~s:~p:~p: error: ~s hands ToExistingAtom a ~s, and it looks up a string~n"
     "  the failure is `(:error, name)` with the name as a `string`, so the~n"
     "  argument must be one: a `binary` that is not valid UTF-8 has no~n"
     "  such name to hand back, and the lookup would fail the same way a~n"
     "  missing atom does. A `term` from a boundary is matched into a~n"
     "  string first; a wire `binary` becomes one through~n"
     "  `ValidateAs<string>`.~n",
     [P, L, C, Fn, Ty]};
%% The member and the path to it, then the repair that kind of member has.
%% The term carries the path as segments, so it is joined only here.
message(#{tag := unencodable_member, function := Fn, type := Ty, path := Segs,
          member := M, kind := Kind} = D) ->
    {placed(D) ++ "error: ~s calls ToJson over a type with no wire form~n"
     "  ~s~s~n"
     "  the type is: ~s~n"
     "  ~s~n",
     placed_args(D) ++ [Fn, unencodable_at(Segs), unencodable_member(M, Kind), Ty,
                        unencodable_repair(Kind)]};
message(#{tag := not_an_obligation, file := P, line := L, column := C, function := Fn,
          name := Name, obligations := Names}) ->
    {"~s:~p:~p: error: ~s writes ~s<...>, and ~s is not a codegen obligation~n"
     "  user code has no instantiation syntax: a type argument is written~n"
     "  only after a compiler-known name, which is ~s.~n"
     "  Everywhere else `<` is a comparison.~n",
     [P, L, C, Fn, Name, Name,
      lists:join(", ", [atom_to_list(N) || N <- Names])]};
message(#{tag := compiler_known_type, file := P, line := L, column := C, type := Name}) ->
    {"~s:~p:~p: error: ~s is a compiler-known type and cannot be redeclared~n"
     "  the standard environment has two kinds of entry: declared entries,~n"
     "  ordinary aliases you could have written, and compiler-known entries,~n"
     "  names the compiler owns because it is the only thing that builds a~n"
     "  value of them. ~s is compiler-known. Pick another name.~n",
     [P, L, C, Name, Name]};
message(#{tag := compiler_known_function, file := P, line := L, column := C,
          function := Name}) ->
    {"~s:~p:~p: error: ~s is a compiler-known function and cannot be declared~n"
     "  a call to ~s is read by the compiler before any function of this~n"
     "  module is looked up — it is a codegen obligation, written bare — so~n"
     "  a function declared under that name could never be called.~n"
     "  Pick another name.~n",
     [P, L, C, Name, Name]};

%%% --- the fatal ones --------------------------------------------------------

message(#{tag := stray_semicolon, file := P, line := L, column := C}) ->
    {"~s:~p:~p: error: beam-sharp has no `;`~n"
     "  a declaration ends where the next one begins. Remove it.~n",
     [P, L, C]};
message(#{tag := lex_error, file := P, line := L, column := C, detail := D}) ->
    {"~s:~p:~p: error: ~s~n", [P, L, C, D]};
message(#{tag := parse_error, file := P, line := L, column := C, detail := D}) ->
    {"~s:~p:~p: error: ~s~n", [P, L, C, D]};
%% The refusal names what to write instead: every comparison the guard
%% fragment admits has an opposite already in the language.
%% Rationale: compiler/features/F27-no-negation.md.
message(#{tag := no_negation, file := P, line := L, column := C, spelling := S}) ->
    {"~s:~p:~p: error: beam-sharp has no `~s`~n"
     "  negation is not an operator here. A guard and a refinement are built~n"
     "  from comparisons, and every comparison has an opposite you can write~n"
     "  directly: `<=` for `not >`, `>=` for `not <`, `!=` for `not ==`,~n"
     "  `==` for `not !=`. Which case a clause takes is the head's job.~n",
     [P, L, C, S]};
message(#{tag := no_sources_here, file := P}) ->
    {"bsc: no `.bs` files in ~s~n"
     "  a module is a directory holding `.bs` files (41 §5). If this~n"
     "  came from a shell glob, it matched nothing and was passed~n"
     "  through unexpanded — the corpus is one directory per module now.~n",
     [P]};

%%% --- the raised ones -------------------------------------------------------

message(#{tag := behaviour_not_satisfied, file := P, line := L, column := C,
          behaviour := B, missing := Missing}) ->
    {"~s:~p:~p: error: behaviour ~s is declared and not satisfied~n"
     "  these callbacks are mandatory and this module does not define them:~n"
     "~s"
     "  a `behaviour` attribute is emitted for the whole contract, so a~n"
     "  partial one would fail when the process starts rather than here.~n",
     [P, L, C, B, [io_lib:format("    ~s/~p~n", [N, A]) || {N, A} <- Missing]]};
message(#{tag := private_callback, file := P, line := L, column := C, name := N,
          arity := A, otp_name := Otp}) ->
    {"~s:~p:~p: error: ~s/~p is `private` and is a callback~n"
     "  this module declares a behaviour that calls it as ~s/~p, and a~n"
     "  behaviour is dispatched through the export list — `-behaviour`~n"
     "  itself has no runtime effect. Private, it would fail when the~n"
     "  process starts rather than here. Mark it `public`.~n",
     [P, L, C, N, A, Otp, A]};
message(#{tag := unknown_behaviour, file := P, behaviour := B}) ->
    {"~s: error: no behaviour named ~s~n"
     "  the compiler knows `GenServer`, `Supervisor`, `Application`,~n"
     "  `GenStatem` and `GenEvent`.~n",
     [P, B]};
%% A reachable module declares the name: the fix is a `using` line or the
%% qualified spelling, both named, rather than a declaration the author would
%% be writing twice.
%% Rationale: compiler/features/F44-type-names-cross-using.md.
message(#{tag := unknown_type, type := N, suppliers := Mods} = D) ->
    {placed(D) ++ "error: no type named ~s~n"
     "  it is declared elsewhere; bring it in, or name where it lives:~n"
     "~s",
     placed_args(D) ++
         [N, [io_lib:format("    `using ~s`, or write `~s.~s`~n", [M, M, N])
              || M <- Mods]]};
message(#{tag := unknown_type, type := N} = D) ->
    {placed(D) ++ "error: no type named ~s~n"
     "  declare it with `type ~s = ...` or `record ~s { ... }`.~n",
     placed_args(D) ++ [N, N, N]};
message(#{tag := unknown_type_in_module, module := Mod, type := N} = D) ->
    {placed(D) ++ "error: ~s declares no type named ~s~n"
     "  a qualified type is spelled as the module that declares it spells~n"
     "  it: a `record` or `type` line in ~s.~n",
     placed_args(D) ++ [Mod, N, Mod]};
message(#{tag := type_module_not_imported, module := Mod, type := N} = D) ->
    {placed(D) ++ "error: ~s.~s names ~s, which is never imported~n"
     "  add `using ~s` — a file's `using` lines are its dependency list,~n"
     "  and a type that skips them makes that list wrong.~n",
     placed_args(D) ++ [Mod, N, Mod, Mod]};
message(#{tag := ambiguous_type, type := N, candidates := Mods} = D) ->
    {placed(D) ++ "error: ~s is ambiguous — ~p imports declare it~n"
     "  name one of these instead:~n"
     "~s",
     placed_args(D) ++
         [N, length(Mods), [io_lib:format("    ~s.~s~n", [M, N]) || M <- Mods]]};
%% The fix is named because the alternative always exists: a property pattern
%% constrains fields without naming a type at all. An uppercase prefix still
%% needs a minted tag, and a lowercase one names a part instead, so an author
%% over `type Amount = int | float` is told the form exists and how to spell
%% it.
%% Rationale: compiler/features/F22-record-pattern-and-binder.md.
message(#{tag := not_a_record, file := P, line := L, column := C, type := N}) ->
    {"~s:~p:~p: error: ~s is not a record, so it cannot name a pattern~n"
     "  only a `record` declaration mints the tag a type prefix matches on.~n"
     %% Named as a form and not as a head: this refusal does not know the
     %% function's parameters, so a printed clause would be advice it cannot
     %% guarantee compiles. `check-advice-compiles.sh` catches that fault in
     %% the messages that do print a clause.
     "  a part is named by the part itself, lowercase — one clause taking~n"
     "  `int` beside one taking `float`.~n"
     "  to constrain fields without naming a type, write `{ Field: ... }`.~n",
     [P, L, C, N]};
%% Shaped on `field_set_mismatch`'s "not declared by Order" sentence, the same
%% mistake at a different site, and it hands back the field list.
message(#{tag := pattern_field_unknown, file := P, line := L, column := C, record := R,
          field := F, declared := Declared}) ->
    {"~s:~p:~p: error: ~s is not declared by ~s~n"
     "  ~s declares:~n~s",
     [P, L, C, F, R, R,
      field_list("", [D || D <- Declared, D =/= 'Kind'])]};
message(#{tag := unknown_builtin, type := B} = D) ->
    {placed(D) ++ "error: ~s is not a builtin type~n"
     "  this slice has `int`, `float`, `atom`, `term`, `none`, `bool`, `binary`,~n"
     "  `string` and `list<T>`.~n",
     placed_args(D) ++ [B]};
message(#{tag := foreign_ret_beyond_one_guard, module := Mod, function := Fun,
          type := Type, why := Why, name := Name, fields := Fields, at := At} = D) ->
    {placed(D) ++ "error: ~s.~s returns `~s`, which one guard cannot decide~n~s~s",
     placed_args(D) ++ [Mod, Fun, Type, beyond_why(Why, Name),
                        beyond_edit(Why, At, Type, Name, Fields)]};
message(#{tag := unknown_generic, file := P, type := N}) ->
    {"~s: error: no type named ~s takes a type argument~n"
     "  the standard environment has `list<T>`, `option<T>` and `result<T, E>`;~n"
     "  your own take one with `type ~s<T> = ...`.~n",
     [P, N, N]};
message(#{tag := generic_arity, type := N, want := Want,
          got := Got} = D) ->
    {placed(D) ++ "error: ~s takes ~p type argument~s, and got ~p~n",
     placed_args(D) ++ [N, Want, plural(Want), Got]};
message(#{tag := needs_type_args, type := N, want := Want} = D) ->
    {placed(D) ++ "error: ~s is parametric and was written without a bracket~n"
     "  it takes ~p type argument~s: write `~s<...>`.~n",
     placed_args(D) ++ [N, Want, plural(Want), N]};
message(#{tag := not_parametric, type := N} = D) ->
    {placed(D) ++ "error: ~s takes no type arguments~n"
     "  declare it as `type ~s<T> = ...` if it should.~n",
     placed_args(D) ++ [N, N]};
message(#{tag := cyclic_type, type := N} = D) ->
    {placed(D) ++ "error: the type ~s is defined in terms of itself, and the~n"
     "  recursion does not pass through a constructor~n"
     "  so there is no set of values it could describe -- and that is~n"
     "  not a missing feature. Put the recursion inside a shape (a~n"
     "  tuple, a list, or a record field), or drop it.~n",
     placed_args(D) ++ [N]};
%% The recursion is through a constructor, so `cyclic_type` does not apply;
%% what fails is regularity, and the message names the repair as well.
%% Rationale: compiler/features/F28-recursive-types.md.
message(#{tag := non_regular_recursion, file := P, type := N}) ->
    {"~s: error: ~s recurs at a different type argument each time~n"
     "  the recursion passes through a constructor, so the definition is~n"
     "  contractive -- but each unfolding names a WIDER argument than the~n"
     "  last, so it never comes back to itself and there is no finite~n"
     "  type to hold it.~n"
     "  Recur at the SAME argument (`~s<X>` inside `~s<X>`), or give the~n"
     "  inner position a concrete type.~n",
     [P, N, N, N]};
%% Three messages, because the hint is not one hint. "tag it" repairs an
%% absorbed `:nothing`, is nonsense about an absorbed `(:error, E)` which is
%% already tagged, and is nonsense again about `binary | string`, which is
%% not a failure channel at all.
%% Rationale: compiler/features/F31-collapse-at-the-declaration.md.
message(#{tag := absorbed_member, file := P, line := L, column := C,
          where := W, channel := nothing, member := M, absorbed_by := A}) ->
    {"~s:~p:~p: error: `~s` is absorbed by `~s`~n"
     "  in ~s~n"
     "  the failure channel does not survive normalisation, so the type~n"
     "  declared here IS `~s`. No caller can write the failure clause,~n"
     "  because no failure member is left to match.~n"
     "  hint: tag it - (:some, ~s) | :nothing~n",
     [P, L, C, M, A, W, A, A]};
message(#{tag := absorbed_member, file := P, line := L, column := C,
          where := W, channel := error, member := M, absorbed_by := A}) ->
    {"~s:~p:~p: error: `~s` is absorbed by `~s`~n"
     "  in ~s~n"
     "  the failure channel does not survive normalisation, so the type~n"
     "  declared here IS `~s`. No caller can write the failure clause,~n"
     "  because no failure member is left to match.~n"
     "  The failure member already carries its tag, so tagging it again~n"
     "  repairs nothing: narrow the success type until it cannot hold an~n"
     "  `(:error, ...)` of its own.~n",
     [P, L, C, M, A, W, A]};
%% The general case, and the repair is a fork on purpose. `binary | string`
%% normalises to `binary`, so the mechanical repair is to delete the member —
%% and that is almost certainly not what the author meant, since someone who
%% writes `binary | string` wanted either-or. The compiler knows the type and
%% cannot know the intent, so it states the type as fact and offers both
%% repairs rather than guessing.
message(#{tag := absorbed_member, file := P, line := L, column := C,
          where := W, channel := none, member := M, absorbed_by := A}) ->
    {"~s:~p:~p: error: `~s` is absorbed by `~s`~n"
     "  in ~s~n"
     "  every value of `~s` is already a `~s`, so the type declared here~n"
     "  IS `~s` and the member you wrote is not in it.~n"
     "  Delete the absorbed member, or narrow the one absorbing it -~n"
     "  which of those you meant is not something the compiler can tell.~n",
     [P, L, C, M, A, W, M, A, A]};
%% The refusal that expires. It names the pattern grammar rather than the type,
%% because the members are fine: nothing can reach them yet. When a map pattern
%% form ships this stops firing with no edit here.
message(#{tag := indiscriminable_union, file := P, line := L, column := C,
          where := W, member := M, beside := B}) ->
    {"~s:~p:~p: error: no clause head can tell `~s` from `~s`~n"
     "  in ~s~n"
     "  both members survive normalisation, so neither is absorbed - but~n"
     "  no pattern reaches either one and no guard separates them, so a~n"
     "  value of this type can be passed and returned and never matched.~n"
     "  This is a limit of the pattern grammar, not of the types: it~n"
     "  lifts when a pattern form for these members ships.~n",
     [P, L, C, M, B, W]};
message(#{tag := kind_field_is_minted, file := P, line := L, column := C, record := Name}) ->
    {"~s:~p:~p: error: ~s declares a field named Kind~n"
     "  the tag is minted from the type's qualified name, so a record~n"
     "  cannot also declare one. Rename the field.~n",
     [P, L, C, Name]};
message(#{tag := opaque_refinement, file := P, line := L, column := C}) ->
    {"~s:~p:~p: error: this refinement is not a predicate the checker can read~n"
     "  a refinement narrows a type, so the compiler has to be able to~n"
     "  reason about it: comparisons on `value`, joined with `and`/`or`.~n"
     "  `int where value >= 0 and value <= 255` is one.~n"
     "  A predicate that reads the value instead — `WellFormed(value)` —~n"
     "  is the O(n) tier. It is established once at a boundary and never~n"
     "  reasoned about, and this compiler has no site to establish it at.~n",
     [P, L, C]};
message(#{tag := empty_refinement, file := P, line := L, column := C}) ->
    {"~s:~p:~p: error: this refinement admits no values at all~n"
     "  the predicate contradicts itself, so nothing has this type and~n"
     "  no call to a function over it could ever be written.~n",
     [P, L, C]};
message(#{tag := relational_pattern_nested, file := P, line := L, column := C}) ->
    {"~s:~p:~p: error: a relational pattern goes where a whole argument goes~n"
     "  `Classify(>= 4 and <= 7)` is the shipped form. Inside a record~n"
     "  pattern, a tuple or a list it is not built yet — write the~n"
     "  comparison as a guard there: `when o.Total > 100`.~n",
     [P, L, C]};
%%% --- the binary segment refusals ---
%% Rationale: compiler/features/F13-binary-patterns.md.
message(#{tag := unsized_segment_not_last, file := P, line := L, column := C}) ->
    {"~s:~p:~p: error: a segment with no width is the REMAINDER~n"
     "  so it can only come last — anything after it would never~n"
     "  match. Give it a width (`payload:16`), size it by a field~n"
     "  bound earlier in the same pattern (`payload:size`), or move~n"
     "  it to the end.~n",
     [P, L, C]};
message(#{tag := segment_width_not_positive, file := P, line := L, column := C, width := N}) ->
    {"~s:~p:~p: error: a segment's width must be a positive number of bits~n"
     "  `~p` is not one. Omit the width entirely to bind the~n"
     "  remainder of the binary.~n",
     [P, L, C, N]};
message(#{tag := segment_literal_too_wide, file := P, line := L, column := C,
          value := K, width := N, max := Max}) ->
    {"~s:~p:~p: error: ~p does not fit in ~p bits~n"
     "  a ~p-bit segment holds 0..~p. The mistake is usually the~n"
     "  WIDTH rather than the value — check the field's size in the~n"
     "  format you are parsing.~n",
     [P, L, C, K, N, N, Max]};
message(#{tag := segment_size_not_bound, file := P, line := L, column := C, name := V}) ->
    {"~s:~p:~p: error: `~s` is not bound where this segment's size needs it~n"
     "  a binary is matched LEFT TO RIGHT, so a size must name a~n"
     "  field bound EARLIER in the same pattern. Erlang accepts this~n"
     "  and the match then silently never succeeds, which is why it~n"
     "  is refused here.~n",
     [P, L, C, V]};
message(#{tag := name_redeclared, file := P, line := L, column := C, name := Name,
          arity := Arity}) ->
    {"~s:~p:~p: error: ~s/~p is declared more than once~n"
     "  a name may carry MORE THAN ONE ARITY, so ~s/~p and ~s/~p would~n"
     "  be two functions — but two signatures of the SAME arity are one~n"
     "  function declared twice, and its clauses would merge silently.~n",
     [P, L, C, Name, Arity, Name, Arity, Name, Arity + 1]};
message(#{tag := type_redeclared, file := P, line := L, column := C, type := Name,
          first_line := First}) ->
    {"~s:~p:~p: error: ~s is declared twice — first at line ~p~n"
     "  `record`, `type` and a refinement all declare a TYPE NAME, and a~n"
     "  record is an alias for a tagged map, so the three spellings share~n"
     "  one namespace. A second declaration would silently replace the~n"
     "  first, and every function declared over ~s would then be checked~n"
     "  against a type you did not write. Rename one, or remove one.~n",
     [P, L, C, Name, First, Name]};
message(#{tag := ambiguous_call, file := P, line := L, column := C, name := Name,
          arity := Arity, candidates := Mods}) ->
    {"~s:~p:~p: error: ~s/~p is ambiguous — ~p imports declare it~n"
     "  name one of these instead:~n"
     "~s",
     [P, L, C, Name, Arity, length(Mods),
      [io_lib:format("    ~s.~s(...)~n", [M, Name]) || M <- Mods]]};
message(#{tag := unknown_module, file := P, line := L, column := C, module := Mod}) ->
    {"~s:~p:~p: error: `using ~s` names no module and no namespace~n"
     "  a module is a source file this invocation can reach; a namespace~n"
     "  is a path that other modules sit under. Neither matched.~n",
     [P, L, C, Mod]};
message(#{tag := module_not_imported, file := P, line := L, column := C, module := Mod}) ->
    {"~s:~p:~p: error: ~s is called but never imported~n"
     "  add `using ~s` — a file's `using` lines are its dependency list,~n"
     "  and a call that skips them makes that list wrong.~n",
     [P, L, C, Mod, Mod]};
message(#{tag := ambiguous_module, file := P, line := L, column := C, module := Short,
          candidates := Mods}) ->
    {"~s:~p:~p: error: ~s is ambiguous — ~p namespaces hold a module of that name~n"
     "  name one of these in full instead:~n"
     "~s",
     [P, L, C, Short, length(Mods), [io_lib:format("    ~s~n", [M]) || M <- Mods]]};
message(#{tag := import_cycle, cycle := Cycle}) ->
    {"error: these modules import each other in a cycle~n"
     "~s"
     "  the compiler checks a dependency before its dependents, so a~n"
     "  cycle has no order to check them in. Break it by moving the~n"
     "  shared declarations into a module both can import.~n",
     [[io_lib:format("    ~s~n", [M]) || M <- Cycle]]};
message(#{tag := function_in_index, file := P, line := L, column := C, function := Name}) ->
    {"~s:~p:~p: error: ~s is a function, and index.bs holds no functions~n"
     "  index.bs is the module's DECLARATION file — using, type, record~n"
     "  and behaviour. It is also the file every new declaration lands~n"
     "  in, so it is the most contended one in the module by~n"
     "  construction; putting functions there merges it with the one~n"
     "  thing file-per-function exists to keep apart.~n"
     "  Give ~s its own file in the same directory.~n",
     [P, L, C, Name, Name]};
message(#{tag := module_path_mismatch, file := P, line := L, column := C,
          declared := Declared, expected := Expected}) ->
    {"~s:~p:~p: error: `module ~s` does not match its directory~n"
     "  this directory says `module ~s`~n"
     "  a module's declaration and its path are the same name written~n"
     "  twice, and 40 §1 makes the declaration the emitted ATOM — so~n"
     "  when they disagree the atom and the tree have drifted apart.~n"
     "  Rename the directory, fix the declaration, or name the source~n"
     "  root with --src-root if this tree is rooted somewhere else.~n",
     [P, L, C, Declared, Expected]};
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

%%% --- the remainder ---
%%%
%%% No catch-all beyond this one, which only the `unclassified` tag reaches. A
%%% tag with no clause here crashes rather than rendering generic prose, so a
%%% new diagnostic cannot ship looking as if it had a message.
%%% Rationale: compiler/features/F16-diagnostic-as-a-term.md.

message(#{tag := unclassified, file := P, detail := D}) ->
    {"~s: ~p~n", [P, D]}.

%%% ---------------------------------------------------------------------------
%%% Head synthesis
%%%
%%% The compiler synthesises the head, never the body: a head is derived from
%%% the residual and cannot be wrong, while a body is a guess, and one bad
%%% suggestion poisons every good one. Lowering a set to a pattern plus guard
%%% is a real compilation step, so it lives here and consumers never invert it
%%% differently.
%%%
%%% The term carries every head and the prose carries three: the descriptor
%%% holds the residual's parts, per argument, per product, never finished
%%% text, because prose cannot be a pure function of a term truncated before
%%% it arrived.
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
            %% not cover the residual; the rest travels in `description`.
            %% Rationale: compiler/features/F29-residual-prints-a-pattern.md.
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
%% carries; the cap lives in the prose.
product_str(P) ->
    lists:flatten(["(", lists:join(", ", [join(parts(C), infinity) || C <- P]), ")"]).

%% One head per line. A residual argument is a union and a clause head is
%% not: `Classify(<= 199 | 300..399)` is a syntax error, so the parts are
%% expanded across the arguments and each combination is its own head, which
%% is why the count can exceed the product count and the cap counts lines.
%% `name_binders/1` runs on the assembled line, because two binders spelled
%% the same in one head is `repeated_in_head` and no part can see its
%% siblings; the arrow is appended after naming, because a hoisted `when`
%% goes before the arrow.
pasteable(Fn, Product, Names) ->
    [lists:flatten(bs_types:name_binders(
                     io_lib:format("~s(~s)", [Fn, lists:join(", ", Combo)]))
                   ++ " -> ...")
     || Combo <- bs_types:head_combos(Product, Names)].

%% One arm per residual member, spelled as a head spells it.
%%
%% `head_combos/2` is the head channel's own expansion, called with a
%% one-element argument list because a switch subject is one value where a
%% function's residual is a product over its parameters. That single call is
%% deliberate rather than a second printer: a residual in argument position
%% and a residual under a switch are the same question, and a separate
%% rendering would let the two drift.
%%
%% The empty list is not "no cases" but "no case a pattern can spell" — a
%% cofinite atom set or `binary \\ string` — and the caller carries it as
%% `description`, the same split `heads/3` makes for the same reason.
arms(Residual, Names) ->
    [lists:flatten(bs_types:name_binders(Combo))
     || Combo <- bs_types:head_combos([Residual], Names)].

%% Capped like the heads, and the unspellable remainder is reported in the
%% head channel's own words rather than handed over with a `=>` after it: an
%% arm the author cannot write is not a suggestion, and printing
%% `atom \\ (:x) => ...` invited pasting a type expression as a pattern.
arms_prose([], #{description := Ds}) ->
    [io_lib:format("  and no pattern spells:~n", []),
     cap([io_lib:format("    ~s~n", [D]) || D <- Ds])];
arms_prose(Arms, _D) ->
    cap([io_lib:format("    ~s => ...~n", [A]) || A <- Arms]).

heads_prose(_Fn, #{kind := residual_only, parts := Parts}) ->
    io_lib:format("    ~s~n", [join(Parts, ?RESIDUAL_CASES)]);
%% The prose is a prefix of the term channel by construction: both come from
%% the one `pasteable` list, and the cap is the only difference.
heads_prose(_Fn, H = #{kind := products, pasteable := Lines}) ->
    [cap([io_lib:format("    ~s~n", [L]) || L <- Lines]), unspellable_prose(H)];
heads_prose(_Fn, H = #{kind := products}) ->
    unspellable_prose(H).

%% Capped like the heads: the cap applies to whatever is being enumerated.
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
%% description printer, because this is a paste site and a description such as
%% `F(int <= 5, _)` does not parse. `none` when the argument is not a whole
%% parameter, since an expression has no head position to put a pattern in,
%% and `none` again when no part of the residual has a pattern: where the
%% residual is not expressible the term says so and offers nothing.
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
%% carries a `Missing` list.
field_set_verb(construction) -> "builds";
field_set_verb(update)       -> "updates".

%% A foreign return refused for a `string`. The type is named as written, and
%% the edit is offered only where one guard reaches the `string`; under a list
%% or a map, `binary` needs the walk too, which is refused, and its own route,
%% `term` then `ValidateAs`, is refused for a domain map. Why one guard cannot
%% decide it, by what was found. Plain strings, rendered through `~s`, so an
%% author's type name cannot reach the format.
%% Rationale: compiler/features/F40-foreign-return-rule.md.
beyond_why(list, _) ->
    "  a foreign return may promise only what one guard checks in O(1), and\n"
    "  every element of this list would need inspecting.\n";
beyond_why(map, _) ->
    "  a foreign return may promise only what one guard checks in O(1), and\n"
    "  every key and value of this map would need inspecting.\n";
beyond_why(recursive, Name) ->
    "  a foreign return may promise only what one guard checks in O(1), and\n"
    "  `" ++ atom_to_list(Name) ++ "` is recursive: only a walk decides one.\n";
beyond_why(record, Name) ->
    "  `" ++ atom_to_list(Name) ++ "` is a record, and Erlang cannot produce its "
    "`Kind`: the key is\n"
    "  minted by this compiler, so no value from outside carries it.\n";
beyond_why(string, _) ->
    "  `string` is `binary` refined by valid UTF-8, and checking that reads\n"
    "  every byte of a value the sender sizes. Establishing it is the\n"
    "  entry check, which this compiler does not have yet.\n";
beyond_why(arrow, _) ->
    "  a foreign return may promise only what one guard checks in O(1), and\n"
    "  `is_function/2` decides an arity and nothing about the types.\n".

%% The edit. A `string` one guard reaches has a replacement, `binary`; a
%% record has its inline field form, which a guard decides and which its own
%% `ValidateAs` would not accept from outside, since the validator wants the
%% `Kind` too; everything else has the route decided — `term` for the part a
%% guard cannot decide, then `ValidateAs<T>` where it is used. Where the whole
%% return is the offender the message can spell the replacement; inside a
%% tuple or a field it names the part.
beyond_edit(string, _At, "string", _Name, _Fields) ->
    "  declare it `binary`.\n";
beyond_edit(string, _At, _Type, _Name, _Fields) ->
    "  write `binary` where it says `string`.\n";
beyond_edit(record, whole, _Type, _Name, Fields) ->
    "  write its fields instead, `" ++ Fields ++ "`, which a guard decides.\n";
beyond_edit(record, inside, _Type, Name, Fields) ->
    "  write its fields where it says `" ++ atom_to_list(Name) ++ "`, `" ++
        Fields ++ "`, which a guard decides.\n";
beyond_edit(Why, whole, Type, _Name, _Fields) ->
    "  declare it `" ++ term_form(Why) ++ "`, then `ValidateAs<" ++ Type ++
        ">` where it is used.\n";
beyond_edit(_Why, inside, Type, _Name, _Fields) ->
    "  declare the part a guard cannot decide as `term` (`list<term>`,\n"
    "  `map<term, term>`), then `ValidateAs<" ++ Type ++ ">` where it is used.\n".

term_form(list)      -> "list<term>";
term_form(map)       -> "map<term, term>";
term_form(recursive) -> "term";
term_form(arrow)     -> "term".

field_list(_Label, [])    -> "";
field_list(Label, Fields) ->
    io_lib:format("~s:~n    ~s~n",
                  [Label, lists:join(", ", [bs_types:key_str(F) || F <- Fields])]).

plural(1) -> "";
plural(_) -> "s".
