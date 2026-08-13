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

forms(#{module := Mod, functions := Fns, env := Env}) ->
    Exports = [{F, arity(F)} || F <- Fns],
    [{attribute, ?A, module, Mod},
     {attribute, ?A, export, [{name(F), A} || {F, A} <- Exports]}]
    ++ lists:append([[spec_attr(F, Env), function(F)] || F <- Fns]).

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

function(F) ->
    Name = name(F),
    Arity = arity(F),
    Clauses = element(6, F),                    % #fn.clauses
    {function, ?A, Name, Arity, [clause(C) || C <- Clauses]}.

%% A beam-sharp clause may name a parameter it does not use — `(:ok, n) -> :negative`
%% is idiomatic, and the name is documentation. Erlang warns about exactly that, so
%% a variable the body and guard never mention lowers to `_`-prefixed. Found by
%% running the emitter rather than by reading it: the first end-to-end build
%% produced two spurious "variable 'N' is unused" warnings.
clause({clause, Line, _Name, Patterns, Guard, Body}) ->
    Used = used_vars(Body, guard_vars(Guard)),
    {clause, Line,
     [pattern(P, Used) || P <- Patterns],
     guard(Guard),
     [expr(Body)]}.

guard_vars(none)          -> sets:new([{version, 2}]);
guard_vars({guard, Expr}) -> used_vars(Expr, sets:new([{version, 2}])).

used_vars({e_var, _, V}, Acc)        -> sets:add_element(V, Acc);
used_vars({e_tuple, _, Es}, Acc)     -> lists:foldl(fun used_vars/2, Acc, Es);
used_vars({e_call, _, _, As}, Acc)   -> lists:foldl(fun used_vars/2, Acc, As);
used_vars({e_op, _, _, A, B}, Acc)   -> used_vars(B, used_vars(A, Acc));
used_vars(_, Acc)                    -> Acc.

guard(none)           -> [];
guard({guard, Expr})  -> [[expr(Expr)]].

%%% ---------------------------------------------------------------------------
%%% Patterns
%%% ---------------------------------------------------------------------------

pattern({p_int, L, N}, _U)     -> {integer, L, N};
pattern({p_atom, L, A}, _U)    -> {atom, L, A};
pattern({p_wild, L}, _U)       -> {var, L, '_'};
pattern({p_tuple, L, Ps}, U)   -> {tuple, L, [pattern(P, U) || P <- Ps]};
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

expr({e_int, L, N})       -> {integer, L, N};
expr({e_atom, L, A})      -> {atom, L, A};
expr({e_var, L, V})       -> {var, L, var_name(V)};
expr({e_tuple, L, Es})    -> {tuple, L, [expr(E) || E <- Es]};
expr({e_call, L, F, As})  -> {call, L, {atom, L, F}, [expr(A) || A <- As]};
expr({e_op, L, Op, A, B}) -> {op, L, erl_op(Op), expr(A), expr(B)}.

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

bs_check_resolve(T, _Env) when is_map(T) -> T;
bs_check_resolve({t_ref, N}, Env) -> maps:get(N, Env);
bs_check_resolve({t_atom, A}, _) -> bs_types:atom_lit(A);
bs_check_resolve({t_builtin, int}, _) -> bs_types:int();
bs_check_resolve({t_builtin, atom}, _) -> bs_types:atom_top();
bs_check_resolve({t_builtin, term}, _) -> bs_types:term();
bs_check_resolve({t_tuple, Cs}, Env) ->
    bs_types:tuple([bs_check_resolve(C, Env) || C <- Cs]);
bs_check_resolve({t_union, Ms}, Env) ->
    bs_types:union([bs_check_resolve(M, Env) || M <- Ms]).

%% Where a set-theoretic type has no Erlang spelling, widen to the nearest
%% supertype that does. A cofinite atom set is the clearest case: Erlang can say
%% `atom()` but cannot say "every atom except :ok", so the exclusion is dropped.
spec_type(Ty) ->
    case parts(Ty) of
        []  -> {type, ?A, none, []};
        [P] -> P;
        Ps  -> {type, ?A, union, Ps}
    end.

parts(#{atoms := As, ints := Is, tuples := Ts}) ->
    atom_parts(As) ++ [int_part(R) || R <- Is] ++ [tuple_part(P) || P <- Ts].

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
