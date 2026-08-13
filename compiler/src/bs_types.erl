%%% beam-sharp's type algebra — the walking-skeleton slice.
%%%
%%% A type is held as a **disjunctive normal form partitioned by constructor**:
%%% an atom part, an integer part, and a tuple part. Different constructors never
%%% interact, so union, intersection and subtraction are componentwise except
%%% inside tuples.
%%%
%%% Two decisions from the map are load-bearing here, and this module is the
%%% first place either is executable rather than argued:
%%%
%%%   * Ticket 20 — **the union is exact.** `erl_types` collapses same-constructor
%%%     unions (measured: `<<_:32>> | <<_:64>>` becomes an arithmetic progression
%%%     admitting 96 bits), which is sound for a success-typing tool and fatal for
%%%     a checker that must prove a residual empty. Nothing here widens.
%%%
%%%   * Ticket 20 §5 — **integer intervals are in the algebra**, so ticket 08's
%%%     rule that the checker credits `n > 1` as a type operation is honoured
%%%     rather than aspirational.
%%%
%%% Atoms are held as a finite set or a **cofinite** one, because ticket 10 made
%%% the atom universe open: `atom` is the cofinite top, and `atom \ :ok` has no
%%% finite representation. Cofinite sets close the algebra under complement
%%% without a negation node.

-module(bs_types).

-export([none/0, term/0, atom_lit/1, atom_top/0, int/0, range/2, tuple/1]).
-export([union/2, union/1, intersect/2, subtract/2]).
-export([is_none/1, is_subtype/2, to_string/1]).

-export_type([ty/0]).

%% An atom part: every atom in the list, or every atom except those.
-type atom_part() :: {finite, [atom()]} | {cofinite, [atom()]}.

%% An integer part: sorted, disjoint, non-adjacent inclusive ranges.
-type bound() :: integer() | neg_inf | pos_inf.
-type int_part() :: [{bound(), bound()}].

%% A tuple part: a union of products, each a list of component types.
-type tuple_part() :: [[ty()]].

-type ty() :: #{atoms := atom_part(), ints := int_part(), tuples := tuple_part()}.

%%% ---------------------------------------------------------------------------
%%% Constructors
%%% ---------------------------------------------------------------------------

none() -> #{atoms => {finite, []}, ints => [], tuples => []}.

%% `term` in the surface language. The tuple part is deliberately absent: this
%% slice has no arity-polymorphic tuple top, and ticket 11 says a foreign value
%% must be matched rather than assumed, so nothing here needs one yet.
term() ->
    #{atoms => {cofinite, []}, ints => [{neg_inf, pos_inf}], tuples => []}.

atom_lit(A) when is_atom(A) -> (none())#{atoms => {finite, [A]}}.

atom_top() -> (none())#{atoms => {cofinite, []}}.

int() -> (none())#{ints => [{neg_inf, pos_inf}]}.

range(Lo, Hi) ->
    case r_empty({Lo, Hi}) of
        true  -> none();
        false -> (none())#{ints => [{Lo, Hi}]}
    end.

tuple(Components) when is_list(Components) ->
    case lists:any(fun is_none/1, Components) of
        true  -> none();          % a product with an empty factor is empty
        false -> (none())#{tuples => [Components]}
    end.

%%% ---------------------------------------------------------------------------
%%% Emptiness
%%% ---------------------------------------------------------------------------

is_none(#{atoms := {finite, []}, ints := [], tuples := Ts}) ->
    lists:all(fun(Cs) -> lists:any(fun is_none/1, Cs) end, Ts);
is_none(_) ->
    false.

is_subtype(A, B) -> is_none(subtract(A, B)).

%%% ---------------------------------------------------------------------------
%%% Union — exact, never widening
%%% ---------------------------------------------------------------------------

union([]) -> none();
union([T]) -> T;
union([H | T]) -> union(H, union(T)).

union(A, B) ->
    #{atoms  => a_union(maps:get(atoms, A), maps:get(atoms, B)),
      ints   => i_union(maps:get(ints, A), maps:get(ints, B)),
      %% Products are kept as separate members. Absorption is applied so a
      %% member contained in another does not survive, but two overlapping
      %% products are BOTH kept — collapsing them is exactly the widening
      %% ticket 20 measured and refused.
      tuples => t_absorb(maps:get(tuples, A) ++ maps:get(tuples, B))}.

%%% ---------------------------------------------------------------------------
%%% Intersection
%%% ---------------------------------------------------------------------------

intersect(A, B) ->
    #{atoms  => a_intersect(maps:get(atoms, A), maps:get(atoms, B)),
      ints   => i_intersect(maps:get(ints, A), maps:get(ints, B)),
      tuples => t_intersect(maps:get(tuples, A), maps:get(tuples, B))}.

%%% ---------------------------------------------------------------------------
%%% Subtraction — this is what computes ticket 04's residual
%%% ---------------------------------------------------------------------------

subtract(A, B) ->
    #{atoms  => a_subtract(maps:get(atoms, A), maps:get(atoms, B)),
      ints   => i_subtract(maps:get(ints, A), maps:get(ints, B)),
      tuples => t_subtract(maps:get(tuples, A), maps:get(tuples, B))}.

%%% ---------------------------------------------------------------------------
%%% Atom part
%%% ---------------------------------------------------------------------------

a_union({finite, X},   {finite, Y})   -> {finite, lists:usort(X ++ Y)};
a_union({cofinite, X}, {cofinite, Y}) -> {cofinite, ordsets:intersection(os(X), os(Y))};
a_union({finite, X},   {cofinite, Y}) -> {cofinite, ordsets:subtract(os(Y), os(X))};
a_union(C = {cofinite, _}, F = {finite, _}) -> a_union(F, C).

a_intersect({finite, X},   {finite, Y})   -> {finite, ordsets:intersection(os(X), os(Y))};
a_intersect({cofinite, X}, {cofinite, Y}) -> {cofinite, lists:usort(X ++ Y)};
a_intersect({finite, X},   {cofinite, Y}) -> {finite, ordsets:subtract(os(X), os(Y))};
a_intersect(C = {cofinite, _}, F = {finite, _}) -> a_intersect(F, C).

%% A \ B  ==  A ∩ complement(B)
a_subtract(A, B) -> a_intersect(A, a_complement(B)).

a_complement({finite, X})   -> {cofinite, os(X)};
a_complement({cofinite, X}) -> {finite, os(X)}.

os(L) -> ordsets:from_list(L).

%%% ---------------------------------------------------------------------------
%%% Integer part — a real interval domain.
%%%
%%% Ticket 20 measured that `erl_types` has none: it snaps 5..20 to 1..255 and
%%% 500..2000 to 1..1114111. Everything below is exact, which is the point.
%%% ---------------------------------------------------------------------------

i_union(A, B) -> i_norm(A ++ B).

i_intersect(A, B) ->
    i_norm([R || X <- A, Y <- B, (R = r_meet(X, Y)) =/= empty]).

i_subtract(A, B) -> lists:foldl(fun(Y, Acc) -> i_norm(r_minus_all(Acc, Y)) end, A, B).

r_minus_all(Ranges, Y) -> lists:append([r_minus(X, Y) || X <- Ranges]).

%% One range minus one range: nothing, a prefix, a suffix, or both.
%%
%% The disjoint case must be handled first. Without it, {64,64} \ {32,32} returns
%% {33,64} — a range that grows a lower bound out of thin air. Found by the
%% union-is-exact test, which is the one property ticket 20 exists to guarantee.
r_minus(A, B) ->
    case r_meet(A, B) of
        empty -> [A];
        _     -> r_minus_overlapping(A, B)
    end.

r_minus_overlapping({ALo, AHi}, {BLo, BHi}) ->
    Left  = case b_lt(ALo, BLo) of
                true  -> [{ALo, b_pred(BLo)}];
                false -> []
            end,
    Right = case b_lt(BHi, AHi) of
                true  -> [{b_succ(BHi), AHi}];
                false -> []
            end,
    [R || R <- Left ++ Right, not r_empty(R)].

r_meet({ALo, AHi}, {BLo, BHi}) ->
    R = {b_max(ALo, BLo), b_min(AHi, BHi)},
    case r_empty(R) of true -> empty; false -> R end.

r_empty({Lo, Hi}) -> b_lt(Hi, Lo).

%% Sort, then merge overlapping *and adjacent* ranges — 1..3 and 4..6 are 1..6.
i_norm(Ranges) ->
    Sorted = lists:sort(fun({L1, _}, {L2, _}) -> b_le(L1, L2) end,
                        [R || R <- Ranges, not r_empty(R)]),
    i_merge(Sorted).

i_merge([]) -> [];
i_merge([R]) -> [R];
i_merge([{L1, H1}, {L2, H2} | T]) ->
    case b_le(L2, b_succ(H1)) of
        true  -> i_merge([{L1, b_max(H1, H2)} | T]);
        false -> [{L1, H1} | i_merge([{L2, H2} | T])]
    end.

%% Bound arithmetic. neg_inf < every integer < pos_inf.
b_lt(neg_inf, neg_inf) -> false;
b_lt(neg_inf, _)       -> true;
b_lt(_, neg_inf)       -> false;
b_lt(pos_inf, _)       -> false;
b_lt(_, pos_inf)       -> true;
b_lt(A, B)             -> A < B.

b_le(A, B) -> A =:= B orelse b_lt(A, B).

b_min(A, B) -> case b_lt(A, B) of true -> A; false -> B end.
b_max(A, B) -> case b_lt(A, B) of true -> B; false -> A end.

b_succ(pos_inf) -> pos_inf;
b_succ(neg_inf) -> neg_inf;
b_succ(N)       -> N + 1.

b_pred(neg_inf) -> neg_inf;
b_pred(pos_inf) -> pos_inf;
b_pred(N)       -> N - 1.

%%% ---------------------------------------------------------------------------
%%% Tuple part
%%% ---------------------------------------------------------------------------

t_intersect(As, Bs) ->
    t_absorb([P || A <- As, B <- Bs, length(A) =:= length(B),
                   (P = product_meet(A, B)) =/= empty]).

product_meet(A, B) ->
    Cs = [intersect(X, Y) || {X, Y} <- lists:zip(A, B)],
    case lists:any(fun is_none/1, Cs) of
        true  -> empty;
        false -> Cs
    end.

t_subtract(As, Bs) -> lists:foldl(fun(B, Acc) -> t_minus_all(Acc, B) end, As, Bs).

t_minus_all(As, B) -> t_absorb(lists:append([product_minus(A, B) || A <- As])).

%% (A1×…×An) \ (B1×…×Bn) decomposes into n disjoint products:
%%
%%   ⋃ᵢ (A1∩B1) × … × (Aᵢ₋₁∩Bᵢ₋₁) × (Aᵢ\Bᵢ) × Aᵢ₊₁ × … × An
%%
%% Exact, and the reason a two-component tuple can be subtracted at all — a
%% componentwise subtraction would be plain wrong.
product_minus(A, B) when length(A) =/= length(B) -> [A];
product_minus(A, B) ->
    N = length(A),
    Products =
        [begin
             Prefix = [intersect(lists:nth(J, A), lists:nth(J, B)) || J <- lists:seq(1, I - 1)],
             Middle = subtract(lists:nth(I, A), lists:nth(I, B)),
             Suffix = [lists:nth(J, A) || J <- lists:seq(I + 1, N)],
             Prefix ++ [Middle] ++ Suffix
         end || I <- lists:seq(1, N)],
    [P || P <- Products, not lists:any(fun is_none/1, P)].

%% Drop any product wholly contained in another. This removes redundancy without
%% ever merging two products into a wider one.
t_absorb(Ps0) ->
    Ps = [P || P <- Ps0, not lists:any(fun is_none/1, P)],
    [P || P <- Ps, not lists:any(fun(Q) -> Q =/= P andalso product_subset(P, Q) end, Ps)].

product_subset(P, Q) ->
    length(P) =:= length(Q) andalso
        lists:all(fun({X, Y}) -> is_none(subtract(X, Y)) end, lists:zip(P, Q)).

%%% ---------------------------------------------------------------------------
%%% Printing — the residual is the diagnostic, so this is a product surface.
%%%
%%% Ticket 04: the residual *is* the missing case. Ticket 23 will decide whether
%%% it also gets a machine-readable form; until then it has to read well.
%%% ---------------------------------------------------------------------------

to_string(T) ->
    case is_none(T) of
        true  -> "none";
        false -> string:join(parts(T), " | ")
    end.

parts(#{atoms := As, ints := Is, tuples := Ts}) ->
    a_str(As) ++ [i_str(R) || R <- Is] ++ [t_str(P) || P <- Ts].

a_str({finite, []})   -> [];
a_str({finite, L})    -> [":" ++ atom_to_list(A) || A <- L];
a_str({cofinite, []}) -> ["atom"];
a_str({cofinite, L})  -> ["atom \\ (" ++ string:join([":" ++ atom_to_list(A) || A <- L], " | ") ++ ")"].

i_str({neg_inf, pos_inf}) -> "int";
i_str({Lo, Lo})           -> integer_to_list(Lo);
i_str({neg_inf, Hi})      -> "int <= " ++ integer_to_list(Hi);
i_str({Lo, pos_inf})      -> "int >= " ++ integer_to_list(Lo);
i_str({Lo, Hi})           -> integer_to_list(Lo) ++ ".." ++ integer_to_list(Hi).

t_str(P) -> "(" ++ string:join([to_string(C) || C <- P], ", ") ++ ")".
