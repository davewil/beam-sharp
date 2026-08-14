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
    [{attribute, ?A, module, Mod},
     {attribute, ?A, export, [{name(F), A} || {F, A} <- Exports]}]
    ++ [{attribute, ?A, behaviour, otp_name(B)} || B <- Behaviours]
    ++ lists:append([[spec_attr(F, Env), function(F, #{module => Mod, env => Env})]
                     || F <- Fns]).

%% A FIXED, compiler-known table of five — not a derivation rule. The language
%% has no snake_case mapping anywhere and this does not introduce one; these are
%% names the compiler knows, the way it knows `ValidateAs`.
otp_name('GenServer')   -> gen_server;
otp_name('Supervisor')  -> supervisor;
otp_name('Application') -> application;
otp_name('GenStatem')   -> gen_statem;
otp_name('GenEvent')    -> gen_event;
otp_name(Other)         -> erlang:error({unknown_behaviour, Other}).

name(F) -> element(2, F).                       % #fn.name
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
    Name = name(F),
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
     [expr(Body, Ctx)]}.

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
          tuples := [], lists := {false, none}} ->
            case maps:find('Kind', Fields) of
                {ok, #{atoms := {finite, [Tag]}, ints := [], tuples := [],
                       lists := {false, none}, maps := []}} -> {ok, Tag};
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
used_vars({e_record, _, _, Fs}, Acc) ->
    lists:foldl(fun({_, E}, A) -> used_vars(E, A) end, Acc, Fs);
used_vars({e_with, _, Base, Fs}, Acc) ->
    lists:foldl(fun({_, E}, A) -> used_vars(E, A) end, used_vars(Base, Acc), Fs);
used_vars({e_foreign_call, _, _, _, As}, Acc) -> lists:foldl(fun used_vars/2, Acc, As);
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
expr({e_var, L, V}, _C)       -> {var, L, var_name(V)};
expr({e_tuple, L, Es}, C)     -> {tuple, L, [expr(E, C) || E <- Es]};
expr({e_call, L, F, As}, C)   -> {call, L, {atom, L, F}, [expr(A, C) || A <- As]};
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
                Items).

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

spec_attr(F, Env) ->
    Params = element(5, F),
    Ret = element(4, F),
    ArgTypes = [spec_type(bs_check_resolve(T, Env)) || {param, T, _} <- Params],
    RetType = spec_type(bs_check_resolve(Ret, Env)),
    {attribute, ?A, spec,
     {{name(F), length(Params)},
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

parts(#{atoms := As, ints := Is, tuples := Ts, lists := Ls, maps := Ms}) ->
    atom_parts(As) ++ [int_part(R) || R <- Is] ++ tuple_parts(Ts)
        ++ list_parts(Ls) ++ map_parts(Ms).

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

to_abstr(Forms) ->
    iolist_to_binary([io_lib:format("~p.~n", [F]) || F <- Forms]).
