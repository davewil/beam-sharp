-module(bs_lower).

%%% ---------------------------------------------------------------------------
%%% Lowering of the pipe and the valve, run after the parse.
%%%
%%% `a |> F(b)` is a rewrite: `pipe_into/3` builds `F(a, b)` and the parser
%%% emits that node, so no later pass knows the operator exists.
%%%
%%% `a |?> F()` branches, lowering to a `switch`: the `(:error, e)` arm returns
%%% the error unchanged, the value arm applies the pipe rewrite. The value
%%% arm's type is the subject with the error member subtracted, so each stage
%%% of a chain checks against the narrowed type by the ordinary switch
%%% machinery.
%%%
%%% The valve is a pass, not a parser action: each stage needs two names unique
%%% across the whole file, and Erlang scoping is flat within a clause, so a
%%% reused name would silently match the enclosing stage's value. A yecc action
%%% cannot carry a counter, so the numbering happens here.
%%%
%%% Synthesised names start with `bs@`, which the variable grammar cannot
%%% spell, so they never collide with an author's binding.
%%% Rationale: compiler/features/F14-pipe-and-valve.md.
%%% ---------------------------------------------------------------------------

-export([pipe_into/3, valves/1]).

%%% ---------------------------------------------------------------------------
%%% The pipe
%%% ---------------------------------------------------------------------------

%% The piped value becomes the first argument. The node keeps the operator's
%% line, so an error inside `x |> F(a)` reports where the pipe was written.
pipe_into(L, Value, {e_call, _, Name, Args}) ->
    {e_call, L, Name, [Value | Args]};
pipe_into(L, Value, {e_qcall, _, Mod, Fun, Args}) ->
    {e_qcall, L, Mod, Fun, [Value | Args]};
pipe_into(L, Value, {e_foreign_call, _, Mod, Fun, Args}) ->
    {e_foreign_call, L, Mod, Fun, [Value | Args]};
%% A codegen obligation such as `ValidateAs<list<Order>>()` is a call, so the
%% pipe reaches it: the piped value joins the value arguments and the type
%% bracket takes nothing.
pipe_into(L, Value, {e_inst, _, Name, TypeArgs, Args}) ->
    {e_inst, L, Name, TypeArgs, [Value | Args]};
%% A call through a bound name is a call, so the pipe rewrites it too:
%% `n |> rule()` is `rule(n)`. The bare name stays a syntax error, as it is
%% for a function's name: the pipe rewrites a call.
pipe_into(L, Value, {e_apply, _, Var, Args}) ->
    {e_apply, L, Var, [Value | Args]}.

%%% ---------------------------------------------------------------------------
%%% The valve
%%% ---------------------------------------------------------------------------

%% Rewrites every `{e_valve, L, Subject, Call}` the parser produced into
%% `{e_valve, L, Switch}`: the lowered `switch`, kept inside a marker node.
%%
%% The marker lets `bs_check` suppress the two diagnostics the generated arms
%% would otherwise raise, `vacuous_arm` on the error arm when the subject
%% cannot fail and the catch-all rule against the value arm. `bs_emit`
%% unwraps the marker and emits the `case`.
valves(T) ->
    {T1, _} = lower(T, 0),
    T1.

lower({e_valve, L, Subject, Call}, N) ->
    %% Inner valves are numbered first, so the counter stays monotonic and no
    %% two stages share a name.
    {Subject1, N1} = lower(Subject, N),
    {Call1, N2}    = lower(Call, N1),
    Err = name("bs@e", N2),
    Val = name("bs@v", N2),
    %% `(:error, e) => (:error, e)`: the error is returned unchanged.
    ErrArm = {arm, L, {p_tuple, L, [{p_atom, L, error}, {p_var, L, Err}]}, none,
              {e_tuple, L, [{e_atom, L, error}, {e_var, L, Err}]}},
    %% `v => F(v)`: the pipe rewrite over the narrowed value. `v`'s type is the
    %% subject minus the error member, so a stage declared over the narrow type
    %% (`CheckStock(Valid v)`) checks without the author restating the union.
    %% `:nothing => :nothing`: absence is returned unchanged, as the error is;
    %% the arm's job is to be the value, so it is rebuilt rather than aliased.
    %% Rationale: compiler/features/F30-valve-short-circuit-set.md.
    %%
    %% It is emitted unconditionally, over every subject. `bs_lower` runs before
    %% the checker and has no types to ask, so the arm cannot be omitted where
    %% the subject carries no `:nothing`. What keeps that from widening every
    %% existing valve is in `bs_check:arms/10`: a generated arm no value reaches
    %% contributes no type.
    NothArm = {arm, L, {p_atom, L, nothing}, none, {e_atom, L, nothing}},
    ValArm = {arm, L, {p_var, L, Val}, none,
              pipe_into(L, {e_var, L, Val}, Call1)},
    {{e_valve, L, {e_switch, L, Subject1, [ErrArm, NothArm, ValArm]}}, N2 + 1};
%% A valve can sit anywhere an expression can, so the walk is generic over
%% tuples and lists rather than a copy of the grammar to keep in step.
lower(T, N) when is_tuple(T) ->
    {L, N1} = lower(tuple_to_list(T), N),
    {list_to_tuple(L), N1};
lower([H | T], N) ->
    {H1, N1} = lower(H, N),
    {T1, N2} = lower(T, N1),
    {[H1 | T1], N2};
lower(X, N) ->
    {X, N}.

name(Prefix, N) -> list_to_atom(Prefix ++ integer_to_list(N)).
