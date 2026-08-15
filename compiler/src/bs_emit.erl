%%% Lowering to the Erlang Abstract Format — ticket 13's target.
%%%
%%% Ticket 13 chose the Abstract Format over Core Erlang, and the decisive reason
%%% was that it is a **one-way door, not a rung on a ladder**: `.abstr -> Core` is
%%% `erlc +from_abstr +to_core` and free, while `.core -> abstract forms` is
%%% unrecoverable. The emission contract is a *sequence of abstract-format forms*,
%%% with a standing obligation that the frontend never depend on in-process
%%% compiler state — which is what frees the compiler's host language, and which
%%% this module honours by producing plain terms and nothing else.
%%%
%%% Two things ticket 13 requires that show up here:
%%%
%%%   * **A `-spec` for every function whose type is known**, widened to the
%%%     nearest expressible supertype where a set-theoretic type has no Erlang
%%%     spelling. `spec_type/1` is that widening.
%%%
%%%     CORRECTED 2026-08-13, measured: the widening is observable through
%%%     **`-Wspecdiffs` only**. Ticket 13 §6 and an earlier version of this
%%%     comment both said `-Wunderspecs`/`-Wspecdiffs`, and `-Wunderspecs` can
%%%     never see it — not as a corpus artefact but *by construction*. Dialyzer
%%%     classifies a spec as a whole, and ticket 04 made signatures mandatory, so
%%%     every spec we emit has a domain **narrower** than the `_` success typing
%%%     infers while its range may be wider. Narrower somewhere and wider
%%%     elsewhere is neither supertype nor subtype, so it lands in "not equal",
%%%     which `-Wunderspecs` does not report. Verified: a hand-written
%%%     `same_dom(any()) -> atom()` fires `-Wunderspecs`; `narrow_dom(integer())
%%%     -> atom()` does not, and beam-sharp is always the second shape.
%%%
%%%   * **Nothing emitted for the failure arm.** Ticket 12 decided to retain it
%%%     and ticket 13 then found the decision was not ours to make on this target:
%%%     `erlc` inserts the `match_fail` arm and it cannot be suppressed. So the
%%%     honest crash comes free, and `20f` verifies it is actually there.

-module(bs_emit).

-export([forms/1, to_abstr/1]).

-define(A, 0).

%%% ---------------------------------------------------------------------------
%%% Naming.
%%%
%%% PROVISIONAL. The map's fog patch "Module and namespace system, and function
%%% identity" owes the real answer — whether a module identifier lowers to a bare
%%% snake_cased atom (risking collision with Erlang modules) or to something
%%% prefixed as Elixir's `Elixir.` is. Ticket 10 §3 deliberately did not decide it.
%%%
%%% This slice preserves the source name exactly and quotes it, because that is
%%% the only lossless option and therefore the one that pre-empts the decision
%%% least. `Readings` emits module `'Readings'` with function `'Classify'`, called
%%% from Erlang as `'Readings':'Classify'(X)`.
%%% ---------------------------------------------------------------------------

forms(Module = #{module := Mod, functions := Fns, env := Env}) ->
    Exports = [{F, arity(F)} || F <- Fns],
    Behaviours = maps:get(behaviours, Module, []),
    %% The behaviours travel in the emit context because a function name is not
    %% self-describing: whether `HandleCall/3` lowers to `handle_call/3` depends
    %% on what the MODULE declares. Ticket 35's contract scoping, carried.
    Ctx = #{module => Mod, env => Env, behaviours => Behaviours},
    [{attribute, ?A, module, Mod},
     {attribute, ?A, export, [{name(F, Behaviours), A} || {F, A} <- Exports]}]
    ++ [{attribute, ?A, behaviour, bs_otp:behaviour_name(B)} || B <- Behaviours]
    ++ lists:append([[spec_attr(F, Env, Behaviours), function(F, Ctx)]
                     || F <- Fns]).

%% THE ONE PLACE A B# FUNCTION NAME BECOMES AN ERLANG ONE.
%%
%% Four sites need it — the export list, the `-spec`, the function definition and
%% every local call — and they must agree or the module exports a name nothing
%% defines. Ticket 35's table is consulted here and nowhere else so they cannot
%% drift apart.
name(F, Behaviours) -> emitted_name(element(2, F), arity(F), Behaviours).

emitted_name(Name, Arity, Behaviours) ->
    case bs_otp:callback_name(Name, Arity, Behaviours) of
        none -> Name;
        Otp  -> Otp
    end.

arity(F) -> length(element(5, F)).              % length(#fn.params)

%%% ---------------------------------------------------------------------------
%%% Functions and clauses
%%%
%%% The one structural move the language rests on: N clause heads in the parameter
%%% position become N native Erlang clause heads. Ticket 01 verified by hand that
%%% five beam-sharp clauses produce five clause heads in the compiled beam's
%%% abstract_code chunk; this is the compiler doing what that lowering did.
%%% ---------------------------------------------------------------------------

function(F, Ctx) ->
    Name = name(F, maps:get(behaviours, Ctx, [])),
    Arity = arity(F),
    Params = element(5, F),                     % #fn.params
    Clauses = element(6, F),                    % #fn.clauses
    {function, ?A, Name, Arity, [clause(C, Params, Ctx) || C <- Clauses]}.

%% A beam-sharp clause may name a parameter it does not use — `(:ok, n) -> :negative`
%% is idiomatic, and the name is documentation. Erlang warns about exactly that, so
%% a variable the body and guard never mention lowers to `_`-prefixed. Found by
%% running the emitter rather than by reading it: the first end-to-end build
%% produced two spurious "variable 'N' is unused" warnings.
clause({clause, Line, _Name, Patterns, Guard, Body}, Params, Ctx) ->
    %% The boundary guard is injected BEFORE `Used` is computed. It mentions the
    %% parameter variable, so a parameter the body never names would otherwise
    %% lower to `_Foo` and the guard would reference an underscored variable —
    %% which is not a warning but a compile error in the emitted Erlang.
    {Patterns1, Tests} = boundary_guards(Patterns, Params, Line, Ctx),
    Guard1 = conjoin(Tests, Guard, Line),
    Used = used_vars(Body, guard_vars(Guard1)),
    {clause, Line,
     [pattern(P, Used) || P <- Patterns1],
     guard(Guard1, Ctx),
     body_exprs(Body, Ctx)}.

%%% ---------------------------------------------------------------------------
%%% Bodies — ticket 34's bindings
%%%
%%% An Erlang clause body is already a SEQUENCE and `{match, …}` is an ordinary
%%% form, so a binding needs no block, no `begin`, and nothing new in the
%%% emission contract. Measured before building: `f(O) -> B = O + 1, B * 2` and
%%% a destructuring `{A, B} = P` both compile and run through `compile:forms/2`.
%%% Keeping the body a flat list rather than wrapping it in a `{block, …}` also
%%% keeps the last expression in tail position, which ticket 13's tail-call test
%%% asserts on.
%%% ---------------------------------------------------------------------------

body_exprs({e_block, _, Binds, Final}, Ctx) ->
    binds(Binds, Final, Ctx) ++ [expr(Final, Ctx)];
body_exprs(E, Ctx) ->
    [expr(E, Ctx)].

binds([], _Final, _Ctx) -> [];
binds([{bind, L, Name, E} | Rest], Final, Ctx) ->
    %% A bound name nothing later mentions lowers to `_`-prefixed, for the same
    %% reason a parameter does: Erlang warns about it otherwise, and the warning
    %% would be about a variable the author did write, unlike the parameter case.
    %% Kept rather than rejected — binding a name to say what a value IS is a
    %% legitimate reason to write one, and ticket 23 puts the reader first.
    Later = later_vars(Rest, Final),
    Var = case sets:is_element(Name, Later) of
              true  -> var_name(Name);
              false -> list_to_atom([$_ | atom_to_list(var_name(Name))])
          end,
    [{match, L, {var, L, Var}, expr(E, Ctx)} | binds(Rest, Final, Ctx)];
%% A destructuring bind — F5, site 5. The checker has already proved it cannot
%% fail, so this is the same `{match, …}` with a pattern on the left and needs
%% nothing the emitter did not already have: `pattern/2` is what a clause head
%% is lowered through.
%% `pattern/2` already takes the used-variable set and underscores a name
%% nothing reads, which is the same rule a plain binding applies above — so a
%% destructuring bind needs no new lowering, only the set it is judged against.
binds([{dbind, L, P, E} | Rest], Final, Ctx) ->
    [{match, L, pattern(P, later_vars(Rest, Final)), expr(E, Ctx)}
     | binds(Rest, Final, Ctx)].

later_vars(Rest, Final) ->
    lists:foldl(fun(B, A) -> used_vars(element(4, B), A) end,
                used_vars(Final, sets:new([{version, 2}])), Rest).

%%% ---------------------------------------------------------------------------
%%% The boundary guard — ticket 18 §1, reaching records
%%%
%%% Ticket 26 §1 allocates two tiers and this emits the first. The TAG test is
%%% unconditional on an exported record parameter, because no body ever checks
%%% which record a map claims to be — a body projects fields, so it cannot
%%% object, which is exactly 18's test for where the free check is absent. The
%%% exact-field-set test is the second tier and is emitted only where a codegen
%%% obligation consumes the record; none exists yet, so its absence here is the
%%% correct observation rather than a gap. Measured in 26a at +14 bytes, flat in
%%% field count, against the +29 ticket 18 feared.
%%%
%%% Two deliberate narrowings, and they are limits rather than principles:
%%%
%%%   * only where the declared type is a SINGLE closed record. A union of
%%%     records would need a disjunction over tags, which is a different shape
%%%     and is not what F3.9 asserts.
%%%   * not where the clause's own pattern already constrains `Kind`, since the
%%%     head then performs the identical test and a second one is dead weight.
%%%     This is 18's "only where the function's own body would not object", in
%%%     miniature and decidable by reading one pattern.
%%% ---------------------------------------------------------------------------

boundary_guards(Patterns, Params, Line, Ctx) ->
    Zipped = lists:zip3(Patterns, Params, lists:seq(1, length(Patterns))),
    Folded = [guard_one(P, Param, I, Line, Ctx) || {P, Param, I} <- Zipped],
    {[NewP || {NewP, _} <- Folded],
     [T || {_, Ts} <- Folded, T <- Ts]}.

guard_one(Pat, {param, TypeExpr, _}, I, Line, Ctx) ->
    case record_tag(TypeExpr, Ctx) of
        none -> {Pat, []};
        {ok, Tag} ->
            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false ->
                    {Var, Pat1} = ensure_var(Pat, I, Line),
                    {Pat1, [tag_test(Var, Tag, Line)]}
            end
    end.

%% A single closed map member carrying a singleton `Kind`. Anything else — a
%% union, a bare `term`, an anonymous map without a tag — is not a record
%% parameter for this purpose.
record_tag(TypeExpr, #{env := Env}) ->
    try bs_check:resolve(TypeExpr, Env) of
        #{maps := [{closed, Fields}], atoms := {finite, []}, ints := [],
          tuples := [], lists := {false, none}, bins := []} ->
            case maps:find('Kind', Fields) of
                {ok, #{atoms := {finite, [Tag]}, ints := [], tuples := [],
                       lists := {false, none}, maps := [], bins := []}} -> {ok, Tag};
                _ -> none
            end;
        _ -> none
    catch _:_ -> none
    end.

constrains_kind({p_map, _, Fields}) -> lists:keymember('Kind', 1, Fields);
constrains_kind(_)                  -> false.

%% A wildcard has nothing to test against, so one is introduced. `@` keeps the
%% synthesised name out of the source's variable grammar, which is lowercase
%% alphanumerics — so it cannot collide with anything a user wrote.
ensure_var({p_wild, L}, I, _Line) ->
    V = list_to_atom("bs@" ++ integer_to_list(I)),
    {V, {p_var, L, V}};
ensure_var(P = {p_var, _, V}, _I, _Line) ->
    {V, P};
ensure_var(P, I, Line) ->
    %% A structural pattern already binds the shape; the tag still needs a name
    %% to be read from, so the whole pattern is aliased.
    V = list_to_atom("bs@" ++ integer_to_list(I)),
    {V, {p_alias, Line, V, P}}.

%% Emitted as ordinary surface nodes rather than abstract format, so that
%% `used_vars/2` and `expr/2` handle it by the paths they already have.
tag_test(Var, Tag, Line) ->
    {e_op, Line, '==',
     {e_foreign_call, Line, erlang, map_get,
      [{e_atom, Line, 'Kind'}, {e_var, Line, Var}]},
     {e_atom, Line, Tag}}.

conjoin([], Guard, _Line) -> Guard;
conjoin(Tests, none, Line) -> {guard, fold_and(Tests, Line)};
conjoin(Tests, {guard, Expr}, Line) -> {guard, fold_and(Tests ++ [Expr], Line)}.

fold_and([E], _Line) -> E;
fold_and([E | Rest], Line) -> {e_op, Line, '&&', E, fold_and(Rest, Line)}.

guard_vars(none)          -> sets:new([{version, 2}]);
guard_vars({guard, Expr}) -> used_vars(Expr, sets:new([{version, 2}])).

used_vars({e_var, _, V}, Acc)        -> sets:add_element(V, Acc);
used_vars({e_tuple, _, Es}, Acc)     -> lists:foldl(fun used_vars/2, Acc, Es);
used_vars({e_call, _, _, As}, Acc)   -> lists:foldl(fun used_vars/2, Acc, As);
used_vars({e_op, _, _, A, B}, Acc)   -> used_vars(B, used_vars(A, Acc));
used_vars({e_nil, _}, Acc)           -> Acc;
used_vars({e_proj, _, V, _}, Acc)    -> sets:add_element(V, Acc);
used_vars({e_block, _, Binds, Final}, Acc) ->
    lists:foldl(fun(B, A) -> used_vars(element(4, B), A) end,
                used_vars(Final, Acc), Binds);
used_vars({e_record, _, _, Fs}, Acc) ->
    lists:foldl(fun({_, E}, A) -> used_vars(E, A) end, Acc, Fs);
used_vars({e_with, _, Base, Fs}, Acc) ->
    lists:foldl(fun({_, E}, A) -> used_vars(E, A) end, used_vars(Base, Acc), Fs);
used_vars({e_foreign_call, _, _, _, As}, Acc) -> lists:foldl(fun used_vars/2, Acc, As);
%% Descending into arms is not optional and the failure is not a warning. A
%% parameter read ONLY inside an arm body would otherwise look unused, lower to
%% `_N` in the clause head, and the arm body would then emit `N` — which is a
%% compile ERROR in the emitted Erlang, against a file the author did not write.
%% Same shape as F1's spurious-warning finding, one degree worse.
%%
%% Arm-bound names are added along with everything else, and cannot pollute the
%% decision they are not part of: an arm may not rebind a name already in scope,
%% so no arm variable is ever the head variable being judged.
used_vars({e_switch, _, Subject, Arms}, Acc) ->
    lists:foldl(fun({arm, _, _, G, Body}, A) ->
                        used_vars(Body, sets:union(A, guard_vars(G)))
                end, used_vars(Subject, Acc), Arms);
used_vars({e_list, _, Items, Rest}, Acc) ->
    R = case Rest of nil -> Acc; _ -> used_vars(Rest, Acc) end,
    lists:foldl(fun used_vars/2, R, Items);
used_vars(_, Acc)                    -> Acc.

guard(none, _Ctx)          -> [];
guard({guard, Expr}, Ctx)  -> [[expr(Expr, Ctx)]].

%%% ---------------------------------------------------------------------------
%%% Patterns
%%% ---------------------------------------------------------------------------

pattern({p_int, L, N}, _U)     -> {integer, L, N};
pattern({p_atom, L, A}, _U)    -> {atom, L, A};
pattern({p_wild, L}, _U)       -> {var, L, '_'};
pattern({p_tuple, L, Ps}, U)   -> {tuple, L, [pattern(P, U) || P <- Ps]};
pattern({p_nil, L}, _U)        -> {nil, L};
%% `:=` rather than `=>`: a map pattern in Erlang is exact-key by construction,
%% and matching a key the term has not got fails the clause, which is the
%% `function_clause` ticket 12's failure arm is there to produce.
pattern({p_map, L, Fields}, U) ->
    {map, L, [{map_field_exact, L, {atom, L, K}, pattern(P, U)} || {K, P} <- Fields]};
%% Introduced by the boundary guard when the head is structural and the tag
%% still needs a name to be read from.
pattern({p_alias, L, V, P}, U) ->
    {match, L, {var, L, var_name(V)}, pattern(P, U)};
%% `[a, b, ..rest]` is a right fold of cons cells onto the rest.
pattern({p_list, L, Items, Rest}, U) ->
    lists:foldr(fun(P, Acc) -> {cons, L, pattern(P, U), Acc} end,
                case Rest of
                    nil -> {nil, L};
                    R   -> pattern(R, U)
                end,
                Items);
pattern({p_var, L, V}, Used)   ->
    case sets:is_element(V, Used) of
        true  -> {var, L, var_name(V)};
        false -> {var, L, list_to_atom([$_ | atom_to_list(var_name(V))])}
    end.

%% beam-sharp variables are lowercase-initial; Erlang's must be uppercase-initial.
%% Capitalising the first character is injective over the source's variable
%% grammar, so no two distinct names can collide, and the emitted name stays
%% readable in a crash report — which matters, because ticket 13 keeps per-file
%% `file` attributes precisely so crashes point at the right `.bs`.
var_name(V) ->
    [H | T] = atom_to_list(V),
    list_to_atom([string:to_upper(H) | T]).

%%% ---------------------------------------------------------------------------
%%% Expressions
%%% ---------------------------------------------------------------------------

expr({e_int, L, N}, _C)       -> {integer, L, N};
expr({e_atom, L, A}, _C)      -> {atom, L, A};
%% The bytes are already UTF-8-encoded — the lexer read them from the source and
%% validated them there — so this emits them raw and adds no `/utf8` specifier.
%% Re-encoding would double-encode every non-ASCII character, which is invisible
%% in an ASCII test and is why F9.3 exists.
expr({e_str, L, Bytes}, _C)   ->
    {bin, L, [{bin_element, L, {string, L, Bytes}, default, default}]};
expr({e_var, L, V}, _C)       -> {var, L, var_name(V)};
expr({e_tuple, L, Es}, C)     -> {tuple, L, [expr(E, C) || E <- Es]};
%% THE FOURTH NAMING SITE, and the one that fails silently if it disagrees with
%% the other three. A beam-sharp function calling `HandleCall(...)` inside a
%% `GenServer` module must emit `handle_call(...)`, because that is what the
%% export list and the definition now say. Get this wrong and the module compiles
%% and calls a function it does not have.
expr({e_call, L, F, As}, C)   ->
    Name = emitted_name(F, length(As), maps:get(behaviours, C, [])),
    {call, L, {atom, L, Name}, [expr(A, C) || A <- As]};
expr({e_op, L, Op, A, B}, C)  -> {op, L, erl_op(Op), expr(A, C), expr(B, C)};
expr({e_nil, L}, _C)          -> {nil, L};

%% Ticket 26 §1: a record erases to a MAP carrying its minted tag. The tag is
%% ordinary data in the term, which is the whole reason a union of records is
%% dispatched by an ordinary clause head — and the reason ticket 16's refusal of
%% protocols narrowed to *open* protocols once 26 landed.
expr({e_record, L, Name, Fields}, C = #{module := Mod}) ->
    Tag = bs_check:qualified(Mod, Name),
    {map, L,
     [{map_field_assoc, L, {atom, L, 'Kind'}, {atom, L, Tag}}
      | [{map_field_assoc, L, {atom, L, K}, expr(E, C)} || {K, E} <- Fields]]};

%% `o with { Total = 500 }` — width-preserving, and `:=` is what preserves it.
%% Updating a key the term has not got raises `badkey` rather than quietly
%% widening the record, so the field set cannot grow through this construct.
%% The tag is not re-minted: it is simply not among the keys being assigned.
expr({e_with, L, Base, Fields}, C) ->
    {map, L, expr(Base, C),
     [{map_field_exact, L, {atom, L, K}, expr(E, C)} || {K, E} <- Fields]};

%% One `map_get`. Guard-safe by construction, which is what lets the same node
%% serve the boundary tag test above.
expr({e_proj, L, V, Field}, _C) ->
    {call, L, {remote, L, {atom, L, erlang}, {atom, L, map_get}},
     [{atom, L, Field}, {var, L, var_name(V)}]};
%% A foreign call is an ordinary BEAM remote call. The compiler-emitted wrapper
%% and boundary guard the design calls for are NOT here yet - see LANGUAGE.md.
expr({e_foreign_call, L, Mod, Fn, As}, C) ->
    {call, L, {remote, L, {atom, L, Mod}, {atom, L, Fn}}, [expr(A, C) || A <- As]};
expr({e_list, L, Items, Rest}, C) ->
    lists:foldr(fun(E, Acc) -> {cons, L, expr(E, C), Acc} end,
                case Rest of
                    nil -> {nil, L};
                    R   -> expr(R, C)
                end,
                Items);

%% Ticket 17 §6 lowers to Erlang's own `case`, and needs nothing the emitter did
%% not already have: `pattern/2` is what a clause head goes through and an arm is
%% a one-pattern clause. The correspondence is the point — ticket 01 moved this
%% grammar out of switch arms and into the parameter position, so putting it back
%% lands on the construct Erlang always had underneath both.
%%
%% Nothing is emitted for the failure arm, for ticket 13's reason one level down:
%% the BEAM raises `case_clause` on a term no arm matches, exactly as it raises
%% `function_clause`, so ticket 12's retained failure arm comes free here too.
expr({e_switch, L, Subject, Arms}, C) ->
    {'case', L, expr(Subject, C), [arm(A, C) || A <- Arms]}.

arm({arm, L, P, Guard, Body}, C) ->
    Used = used_vars(Body, guard_vars(Guard)),
    {clause, L, [pattern(P, Used)], guard(Guard, C), [expr(Body, C)]}.

%% Ticket 16 settled that `==` means `=:=`, and decided it on internal agreement
%% rather than familiarity: Erlang's `==` coerces through tuples, lists and map
%% *values* and then stops at map keys, while the clause head and `maps:get` do
%% not coerce at all. The exact spelling agrees with two constructs and disagrees
%% with none.
erl_op('==') -> '=:=';
erl_op('!=') -> '=/=';
erl_op('<=') -> '=<';                            % Erlang spells it the other way round
erl_op('&&') -> 'andalso';
erl_op('||') -> 'orelse';
erl_op(Op)   -> Op.                              % + - * < > >=

%%% ---------------------------------------------------------------------------
%%% Specs — ticket 13's widening rule, made concrete
%%% ---------------------------------------------------------------------------

spec_attr(F, Env, Behaviours) ->
    Params = element(5, F),
    Ret = element(4, F),
    ArgTypes = [spec_type(bs_check_resolve(T, Env)) || {param, T, _} <- Params],
    RetType = spec_type(bs_check_resolve(Ret, Env)),
    {attribute, ?A, spec,
     {{name(F, Behaviours), length(Params)},
      [{type, ?A, 'fun', [{type, ?A, product, ArgTypes}, RetType]}]}}.

%% This used to be a second copy of `bs_check:resolve/2`. Records made the
%% duplication untenable rather than merely ugly: ticket 26 §1's tag mints from
%% the qualified name, and a second resolver would have been a second place for
%% that rule to live and drift.
bs_check_resolve(T, Env) -> bs_check:resolve(T, Env).

%% Where a set-theoretic type has no Erlang spelling, widen to the nearest
%% supertype that does. A cofinite atom set is the clearest case: Erlang can say
%% `atom()` but cannot say "every atom except :ok", so the exclusion is dropped.
spec_type(Ty) ->
    case parts(Ty) of
        []  -> {type, ?A, none, []};
        [P] -> P;
        Ps  -> {type, ?A, union, Ps}
    end.

parts(#{atoms := As, ints := Is, tuples := Ts, lists := Ls, maps := Ms,
        bins := Bs}) ->
    atom_parts(As) ++ [int_part(R) || R <- Is] ++ tuple_parts(Ts)
        ++ list_parts(Ls) ++ map_parts(Ms) ++ bin_parts(Bs).

%% All three non-empty points emit `binary()`, and that is this function's own
%% rule rather than a shortcut. Erlang's type language has no UTF-8 refinement,
%% so `string`, `binary` and `binary \ string` have one spelling between them and
%% the nearest supertype that exists is where they land.
%%
%% The widening is confined to the SPEC. Nothing above widens: the algebra keeps
%% the three apart exactly, which is what the checker reasons with. A spec is
%% what Dialyzer reads, and ticket 20's exactness requirement is about the
%% residual, not about the abstract chunk.
bin_parts([])  -> [];
bin_parts(_)   -> [{type, ?A, binary, []}].

%% Erlang's map type spells both halves of the distinction the algebra carries:
%% `:=` is a mandatory key and `=>` an optional one, so a closed member emits
%% all-mandatory and an open one adds `any() => any()` for the fields it does
%% not constrain. Nothing is widened to `map()`, which is what F3.12 asserts.
map_parts(top) -> [{type, ?A, map, any}];
map_parts(Members) -> [map_part(M) || M <- Members].

map_part({Kind, Fields}) ->
    Exact = [{type, ?A, map_field_exact, [{atom, ?A, K}, spec_type(V)]}
             || {K, V} <- lists:sort(maps:to_list(Fields))],
    Rest = case Kind of
               closed -> [];
               open   -> [{type, ?A, map_field_assoc,
                           [{type, ?A, any, []}, {type, ?A, any, []}]}]
           end,
    {type, ?A, map, Exact ++ Rest}.

tuple_parts(top) -> [{type, ?A, tuple, any}];
tuple_parts(Ps)  -> [tuple_part(P) || P <- Ps].

%% Erlang spells "list of T" and "non-empty list of T" but has no way to say
%% "either, with this element type" beyond the former, so a cons-only part
%% emits `nonempty_list(T)` and the pair emits `[T]`.
list_parts({false, none}) -> [];
list_parts({true, none})  -> [{type, ?A, nil, []}];
list_parts({false, any})  -> [{type, ?A, nonempty_list, [{type, ?A, any, []}]}];
list_parts({true, any})   -> [{type, ?A, list, [{type, ?A, any, []}]}];
list_parts({false, T})    -> [{type, ?A, nonempty_list, [spec_type(T)]}];
list_parts({true, T})     -> [{type, ?A, list, [spec_type(T)]}].

atom_parts({finite, L})    -> [{atom, ?A, A} || A <- L];
atom_parts({cofinite, _})  -> [{type, ?A, atom, []}].   % widened: the exclusion is lost

%% NOT DEAD, BUT NOT YET REACHABLE. Every branch below except the first is
%% unreachable from the current surface, and it is worth being precise about why
%% rather than deleting them or leaving it to be rediscovered.
%%
%% These read an interval out of a *declared* type. Ticket 20 put intervals in the
%% algebra and the checker genuinely uses them — it is what makes `math.bs`
%% exhaustive with no catch-all — but they only ever arise from a **guard**, and a
%% guard refines a clause rather than a signature. A parameter declared `int` is
%% `int` in the spec whatever its clauses test.
%%
%% The surface owes the syntax that would reach them: ticket 20 §5's guard
%% refinement, `type Positive = int where value > 0;`, which the parser does not
%% yet implement. That is the next slice increment, not a defect here.
%% Found by a teammate measuring emitter coverage for the OTP corpus.
int_part({neg_inf, pos_inf}) -> {type, ?A, integer, []};
int_part({Lo, Hi}) when is_integer(Lo), is_integer(Hi) ->
    {type, ?A, range, [{integer, ?A, Lo}, {integer, ?A, Hi}]};
int_part({neg_inf, Hi}) when is_integer(Hi), Hi < 0 -> {type, ?A, neg_integer, []};
int_part({0, pos_inf})  -> {type, ?A, non_neg_integer, []};
int_part({1, pos_inf})  -> {type, ?A, pos_integer, []};
int_part(_)             -> {type, ?A, integer, []}.     % widened: no Erlang spelling

tuple_part(Components) ->
    {type, ?A, tuple, [spec_type(C) || C <- Components]}.

%%% ---------------------------------------------------------------------------
%%% Serialisation
%%%
%%% Ticket 13's obligation that the frontend never depend on in-process compiler
%%% state is what makes this a *text* file rather than a term handed to `compile`:
%%% `erlc +from_abstr` builds from it with no `.erl` on disk, which is the fact
%%% that freed the host language.
%%% ---------------------------------------------------------------------------

%% THE CODING COMMENT IS LOAD-BEARING, AND F9 IS WHERE THAT WAS FOUND.
%%
%% `~p` prints a list of printable bytes as a quoted string and writes those
%% BYTES; `erlc` has read Erlang source as UTF-8 since OTP 17. So the `.abstr`
%% file was a serialisation boundary whose two ends disagreed, and a string
%% literal `"héllo"` round-tripped as five bytes instead of six — the `c3 a9`
%% pair read back as the single codepoint 233.
%%
%% Measured both ways before choosing: without this line the binary is 5 bytes,
%% with it 6. The alternative — emitting one `bin_element` per byte so no
%% character list is ever printed — fixes strings and leaves the identical trap
%% set for the next non-ASCII thing to reach a form, an atom with an accented
%% name being the obvious one. This fixes the boundary instead of one caller.
%%
%% It failed in the quiet direction: the program compiled, ran, and returned a
%% perfectly good binary that was the wrong one. Only a byte count showed it.
to_abstr(Forms) ->
    iolist_to_binary(["%% coding: latin-1\n"
                      | [io_lib:format("~p.~n", [F]) || F <- Forms]]).
