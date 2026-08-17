-module(bs_lower).

%%% ---------------------------------------------------------------------------
%%% The pipe and the valve — ticket 17 §1 and §4, F14
%%%
%%% Two operators, two different lowerings, and the difference is the whole
%%% design:
%%%
%%%   `a |> F(b)`   is a REWRITE. `pipe_into/3` builds `F(a, b)` and the parser
%%%                 emits that node directly, so the checker, the five check
%%%                 sites, the exhaustiveness walk and the `-spec` all see an
%%%                 ordinary call, because that is what exists. No downstream
%%%                 module learns the operator at all.
%%%
%%%   `a |?> F()`   cannot be a call — it BRANCHES — so it lowers to the
%%%                 two-armed `switch` ticket 17 §7 already specified. That is
%%%                 the trick that makes the valve nearly free: F7 built
%%%                 `switch`, F2 built union subtraction and F5 built the body
%%%                 check, so the value arm's parameter type is ALREADY the
%%%                 residual after `(:error, E)` is subtracted, and each stage in
%%%                 a chain is checked against the narrowed type without this
%%%                 feature writing a line of type code.
%%%
%%% WHY A PASS AND NOT A REDUCE ACTION
%%% The valve needs two synthesised names per stage, and they must be unique
%%% across the whole file rather than merely per line. `a |?> F() |?> G()` is one
%%% line and two valves; `a |?> F(b |?> G())` nests one inside the other's value
%%% arm. Erlang's scoping is flat within a clause, so a repeated name stops being
%%% a fresh binding and silently becomes a MATCH against the enclosing stage's
%%% value — a wrong program with no diagnostic anywhere. A yecc action cannot
%%% carry a counter, so the numbering happens here, in one walk, after the parse.
%%%
%%% `bs@` keeps both names out of the source's variable grammar, which is
%%% lowercase alphanumerics. The same convention `ensure_var/3` and the
%%% relational lowering already use, and the same reason — but it matters twice
%%% over here, because the error arm binds a name that would otherwise be a
%%% perfectly ordinary `e`, and `rebinds/3` would then report the author for a
%%% collision with generated code they never wrote.
%%% ---------------------------------------------------------------------------

-export([pipe_into/3, valves/1]).

%%% ---------------------------------------------------------------------------
%%% The pipe
%%% ---------------------------------------------------------------------------

%% The piped value becomes the FIRST argument. Ticket 17 §1 killed the dot as a
%% call, so this is what survived that argument rather than a second spelling
%% beside it.
%%
%% The rewritten node carries the OPERATOR's line, not the call's. Ticket 40 §2's
%% complaint — *"the defect is the diagnosis, not the outcome"* — applies
%% directly: the cost of a rewrite is that an error inside `x |> F(a)` reports
%% against `F/2`, and the least it can do is report at the line where the author
%% wrote the pipe. The natural write here is `line of the call`, and it is wrong.
pipe_into(L, Value, {e_call, _, Name, Args}) ->
    {e_call, L, Name, [Value | Args]};
pipe_into(L, Value, {e_qcall, _, Mod, Fun, Args}) ->
    {e_qcall, L, Mod, Fun, [Value | Args]};
pipe_into(L, Value, {e_foreign_call, _, Mod, Fun, Args}) ->
    {e_foreign_call, L, Mod, Fun, [Value | Args]}.

%%% ---------------------------------------------------------------------------
%%% The valve
%%% ---------------------------------------------------------------------------

%% Rewrites every `{e_valve, L, Subject, Call}` the parser produced into
%% `{e_valve, L, Switch}` — the lowered `switch`, kept INSIDE a marker node.
%%
%% The marker is not decoration. A bare `switch` would be indistinguishable from
%% one the author wrote, and the checker would then report two diagnostics about
%% generated code: `unreachable_arm` for the `(:error, e)` arm when the subject
%% cannot fail (F14 §4 exists to replace exactly that message), and ticket 12
%% §2's catch-all rule against the value arm, which is a catch-all by
%% construction. So the node stays marked all the way to `bs_check`, which
%% suppresses both, and to `bs_emit`, which unwraps it and emits the `case`.
valves(T) ->
    {T1, _} = lower(T, 0),
    T1.

lower({e_valve, L, Subject, Call}, N) ->
    %% Inner first, so a nested valve gets the lower numbers and the counter is
    %% still monotonic. Which end gets which number does not matter; that no two
    %% share one does.
    {Subject1, N1} = lower(Subject, N),
    {Call1, N2}    = lower(Call, N1),
    Err = name("bs@e", N2),
    Val = name("bs@v", N2),
    %% `(:error, e) => (:error, e)` — the error is returned UNCHANGED. Rebuilt
    %% rather than aliased because the arm's job is to be the value, and an alias
    %% would need a pattern form the surface has no reason to grow.
    ErrArm = {arm, L, {p_tuple, L, [{p_atom, L, error}, {p_var, L, Err}]}, none,
              {e_tuple, L, [{e_atom, L, error}, {e_var, L, Err}]}},
    %% `v => F(v)` — the same rewrite the pipe does, over the narrowed value.
    %% This is where the residual earns its keep: `v`'s type is what is left of
    %% the subject after the arm above subtracts the error member, so a stage
    %% declared over the narrow type (`CheckStock(Valid v)`) type-checks without
    %% the author restating the union.
    ValArm = {arm, L, {p_var, L, Val}, none,
              pipe_into(L, {e_var, L, Val}, Call1)},
    {{e_valve, L, {e_switch, L, Subject1, [ErrArm, ValArm]}}, N2 + 1};
%% Generic below, for `rebinds/3`'s reason: a valve can sit anywhere an
%% expression can, and enumerating the grammar here would be one more copy of the
%% same walk to keep in step with every future node.
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
