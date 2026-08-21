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
-export([nil/0, cons/1, list/1]).
%% F20: the list part stopped being two flags and became a union of spines, so
%% the places that used to pattern-match its shape ask for what they wanted
%% instead. `bs_check` wanted the element type of a tail; `bs_emit` wanted the
%% same thing for its walker, and wanted to know whether a type holds any list
%% at all. Neither wants a spine.
-export([list_elem/1, has_lists/1, has_nil/1, has_cons/1, spine/2]).
-export([binary_top/0, string/0]).
-export([map_closed/1, map_open/1]).
-export([union/2, union/1, intersect/2, subtract/2]).
-export([is_none/1, is_open/1, is_subtype/2, to_string/1, to_pattern/1,
         pattern_parts/1, atom_str/1]).

-export_type([ty/0]).

%% An atom part: every atom in the list, or every atom except those.
-type atom_part() :: {finite, [atom()]} | {cofinite, [atom()]}.

%% An integer part: sorted, disjoint, non-adjacent inclusive ranges.
-type bound() :: integer() | neg_inf | pos_inf.
-type int_part() :: [{bound(), bound()}].

%% A tuple part: a union of products, each a list of component types - or `top`,
%% every tuple of every arity, which is what `term` contains and what no finite
%% product list can express.
-type tuple_part() :: top | [[ty()]].

%% A list part: a union of SPINES.
%%
%% A spine describes a set of lists by a prefix of element types plus what
%% follows the prefix:
%%
%%   {P, closed}      length is exactly length(P); element i is in P_i
%%   {P, {open, T}}   length is at least length(P); element i is in P_i for
%%                    i =< length(P), and every LATER element is in T
%%
%% `[]` is `{[], closed}`. `none` is the empty union. `term()`'s lists are
%% `{[], {open, any}}` — length >= 0, elements unconstrained — which is every
%% list including the empty one, so the top needs one spine rather than two.
%%
%% THIS REPLACES `{boolean(), elem()}`, WHICH HAD NOWHERE TO PUT A LENGTH.
%% That was ticket 54's defect: a cons pattern was subtracted as *non-empty*
%% whatever its prefix, so `[]` beside `[a, b, ..]` was proved exhaustive and
%% crashed on `[7]`. The old comment defended two flags on the grounds that
%% "the pattern language can only ask two questions of a list" — which was true
%% of ticket 08's grammar as written and false of the programs people wrote in
%% it.
%%
%% `any` survives as a TAIL marker so `term()` can contain lists without
%% recursing into itself; a prefix holds real `ty()`, and `e_ty/1` expands the
%% marker at the one place a tail becomes a prefix element.
-type elem() :: none | any | ty().
-type rest() :: closed | {open, elem()}.
-type spine() :: {[ty()], rest()}.
-type list_part() :: [spine()].

%% A map part — ticket 26's records, and the anonymous map types they are equal
%% to. A member is a field set plus whether that set is the WHOLE domain:
%%
%%   `closed` — exactly these fields. A declared record, or a `type` written out.
%%   `open`   — at least these fields. What a property pattern matches, since
%%              `{ Kind: :'Shop.Order' }` says nothing about the other fields.
%%
%% The two are not decoration. A declared type is closed and a pattern is open,
%% so every subtraction the checker performs is closed-minus-open, and keeping
%% them apart is what lets one clause cover a record by naming only its tag.
%%
%% Like the tuple part, members are kept separate and only absorbed — never
%% merged into a wider one. The field product decomposes exactly the way the
%% tuple product does, keyed by field name instead of by position.
-type map_member() :: {closed | open, #{atom() => ty()}}.
-type map_part() :: top | [map_member()].

%% A binary part — ticket 20 §4's `string = binary where valid_utf8`, which is a
%% REFINEMENT and therefore a subset: `string` is not a second type beside
%% `binary`, it is the half of it that is valid UTF-8. So the part is the
%% two-element powerset of {the valid-UTF-8 binaries, the rest}:
%%
%%   []              empty
%%   [utf8]          `string`
%%   [other, utf8]   `binary`
%%   [other]         no surface spelling — see `b_str/1`
%%
%% This is the smallest encoding that is EXACT, and exactness is 20's headline:
%% `binary \ string` is the non-UTF-8 binaries, and both available shortcuts are
%% the failures that ticket. Collapsing it to `binary` widens, which is the
%% `erl_types` behaviour 20 spent itself refusing; collapsing it to `none`
%% reports a residual empty when it is not.
%%
%% Sizes are deliberately absent. Ticket 20 §2 published `<<_:M, _:_*N>>` with an
%% exact union, but that grammar has no surface spelling here and ticket 30 —
%% which needs one for the pattern form too — is open. F9 ships the top and the
%% refinement; the part is a set so a size partition refines it later without
%% changing its shape.
-type bin_part() :: [utf8 | other].

-type ty() :: #{atoms := atom_part(), ints := int_part(), tuples := tuple_part(),
                lists := list_part(), maps := map_part(), bins := bin_part()}.

%%% ---------------------------------------------------------------------------
%%% Constructors
%%% ---------------------------------------------------------------------------

none() -> #{atoms => {finite, []}, ints => [], tuples => [], lists => [],
            maps => [], bins => []}.

%% `term` in the surface language. The tuple part is deliberately absent: this
%% slice has no arity-polymorphic tuple top, and ticket 11 says a foreign value
%% must be matched rather than assumed, so nothing here needs one yet.
%%
%% The binary part is NOT one of those deliberate absences and must be full. A
%% `term` missing it stops being the top type, and every residual subtracted
%% from it is then wrong in the quiet direction.
term() ->
    #{atoms => {cofinite, []}, ints => [{neg_inf, pos_inf}], tuples => top,
      lists => [{[], {open, any}}], maps => top, bins => [other, utf8]}.

%% `binary` — the top of the part, both halves.
binary_top() -> (none())#{bins => [other, utf8]}.

%% `string` — ticket 20 §4, `binary` refined by valid UTF-8. A subset of
%% `binary_top/0`, so `is_subtype(string(), binary_top())` holds and the reverse
%% does not, which is the whole of F9's containment story.
string() -> (none())#{bins => [utf8]}.

atom_lit(A) when is_atom(A) -> (none())#{atoms => {finite, [A]}}.

atom_top() -> (none())#{atoms => {cofinite, []}}.

int() -> (none())#{ints => [{neg_inf, pos_inf}]}.

range(Lo, Hi) ->
    case r_empty({Lo, Hi}) of
        true  -> none();
        false -> (none())#{ints => [{Lo, Hi}]}
    end.

%% `[]` alone.
nil() -> (none())#{lists => [{[], closed}]}.

%% Every non-empty list whose elements are in T.
cons(T) ->
    case is_none(T) of
        true  -> none();
        false -> (none())#{lists => [{[T], {open, T}}]}
    end.

%% `list<T>` — the two together, which is what a signature declares and what the
%% pair `[]` / `[h, ..t]` must cover to be exhaustive.
list(T) -> union(nil(), cons(T)).

%% Everything any list in T can hold, at any position — the union of every
%% spine's prefix components and every spine's tail. A caller asking this wants
%% "what is in the list", which survives the spine representation unchanged.
list_elem(#{lists := Ss}) -> l_elem(Ss).

%% F20 — THE ONE SURFACE A LIST PATTERN HAS INTO THE ALGEBRA.
%%
%% `Prefix` is the type at each written position; `closed` means the pattern
%% ended (`[a, b]`, exactly two) and `open` means a rest marker followed
%% (`[a, b, ..]`, two or more). The marker constrains nothing, so the tail is
%% the top — which is also why unfolding terminates: no pattern can ever ask
%% about a position it did not write.
spine(Prefix, closed) when is_list(Prefix) -> mk_spine(Prefix, closed);
spine(Prefix, open)   when is_list(Prefix) -> mk_spine(Prefix, {open, any}).

mk_spine(Prefix, Rest) ->
    case lists:any(fun is_none/1, Prefix) of
        true  -> none();
        false -> (none())#{lists => [{Prefix, Rest}]}
    end.

%% Whether T admits a list at all. `[]` in the part means it does not.
has_lists(#{lists := Ss}) -> Ss =/= [].

%% Does T admit the empty list? A spine with an empty prefix does: `closed` is
%% `[]` itself, and `{open, _}` is length >= 0.
has_nil(#{lists := Ss}) -> lists:any(fun({[], _}) -> true; (_) -> false end, Ss).

%% Does T admit a non-empty list? A prefix of one or more forces length >= 1;
%% an empty prefix does only if its tail admits an element.
has_cons(#{lists := Ss}) -> lists:any(fun sp_has_cons/1, Ss).

sp_has_cons({[], closed})    -> false;
sp_has_cons({[], {open, T}}) -> not e_none(T);
sp_has_cons({_P, _})         -> true.

l_elem([]) -> none();
l_elem(Ss) ->
    Tails = [e_ty(T) || {_, {open, T}} <- Ss, not e_none(T)],
    Prefix = lists:append([P || {P, _} <- Ss]),
    case Prefix ++ Tails of
        [] -> none();
        Xs -> union(Xs)
    end.

tuple(Components) when is_list(Components) ->
    case lists:any(fun is_none/1, Components) of
        true  -> none();          % a product with an empty factor is empty
        false -> (none())#{tuples => [Components]}
    end.

%% Exactly these fields — a declared record, or the `type` a user writes that is
%% equal to it. Ticket 26 §1: the minting is not nominality, so a hand-written
%% type carrying the same tag IS the same type, and that falls out here because
%% nothing distinguishes them once both are a closed field set.
map_closed(Fields) -> map_member(closed, Fields).

%% At least these fields — what a property pattern matches.
map_open(Fields) -> map_member(open, Fields).

map_member(Kind, Fields) when is_map(Fields) ->
    case lists:any(fun is_none/1, maps:values(Fields)) of
        true  -> none();          % a field with an empty type admits no map
        false -> (none())#{maps => [{Kind, Fields}]}
    end.

%%% ---------------------------------------------------------------------------
%%% Emptiness
%%% ---------------------------------------------------------------------------

%% AN ERLANG MAP PATTERN IS PARTIAL, WHICH MAKES THIS HEAD THE FEATURE'S SHARPEST
%% TRAP. A component added to `none/0` and forgotten here does not fail — the
%% head still matches, a type whose only inhabitant is a binary reports EMPTY,
%% and every containment over it then passes vacuously. The compiler goes
%% quieter rather than red, which is F5's `Certain`/`Possible` failure in a third
%% costume: no passing test can see it, so `bins := []` below is verified by
%% mutating this line and watching the suite go red.
is_none(#{atoms := {finite, []}, ints := [], tuples := Ts, lists := [],
          maps := Ms, bins := []})
  when Ts =/= top, Ms =/= top ->
    lists:all(fun(Cs) -> lists:any(fun is_none/1, Cs) end, Ts)
        andalso lists:all(fun m_empty/1, Ms);
is_none(_) ->
    false.

m_empty({_Kind, Fields}) -> lists:any(fun is_none/1, maps:values(Fields)).

is_subtype(A, B) -> is_none(subtract(A, B)).

%%% ---------------------------------------------------------------------------
%%% Openness — ticket 12 §2's discriminator, and F2 is what makes it reachable
%%%
%%% *"A catch-all is legal only over an OPEN residual."* Until this feature there
%%% was no way to ask: every integer domain the surface could declare was `int`,
%%% which is open by construction, so `_` was always legal over one and the rule
%%% had nothing to bite on. `type Octet = int where value >= 0 and value <= 255`
%%% is the first CLOSED numeric domain the language can spell, and 252 unnamed
%%% octets is exactly the case 12 §2 wants named rather than swallowed.
%%%
%%% Open means *contains an unbounded top* — not "large". `0..255` has 256
%%% inhabitants and is closed; `int >= 0` has infinitely many and is open. The
%%% question the rule asks is whether the compiler could, in principle, hand the
%%% author the list of cases it wants written.
%%%
%%% THE SIX-KEY PATTERN IS DELIBERATE, for the reason `is_none/1` states one
%%% screen up: an Erlang map pattern is partial, so a component added to the
%%% algebra and forgotten here would not fail — the head would still match. The
%%% failure direction happens to be the loud one (a forgotten component reports
%%% CLOSED, and a legal catch-all becomes an error somebody notices immediately)
%%% but relying on that is relying on luck, and the next component might not be.
%%%
%%% `none()` ANSWERS FALSE. It has no unbounded top because it has nothing at
%%% all — the right answer to the question this asks, and the wrong one for a
%%% caller reading it as *"must be enumerated"*, since there is nothing to
%%% enumerate. Ask `is_none/1` first where that matters;
%%% `bs_check:closed_and_inhabited/1` is the only caller today and does.
is_open(#{atoms := As, ints := Is, tuples := Ts, lists := Ls, maps := Ms,
          bins := Bs}) ->
    a_open(As) orelse lists:any(fun r_unbounded/1, Is) orelse t_open(Ts)
        orelse l_open(Ls) orelse m_open(Ms)
        %% Any non-empty binary part is unbounded: the sender chooses the length,
        %% which is ticket 11's own reason for refusing unbounded work in a head.
        orelse Bs =/= [].

%% Ticket 10 made the atom universe open, so a cofinite set is the top and cannot
%% be enumerated — a foreign sender chooses the inhabitants.
a_open({cofinite, _}) -> true;
a_open({finite, _})   -> false.

r_unbounded({neg_inf, _}) -> true;
r_unbounded({_, pos_inf}) -> true;
r_unbounded({_, _})       -> false.

t_open(top) -> true;
t_open(Ps)  -> lists:any(fun(P) -> lists:any(fun is_open/1, P) end, Ps).

%% A list part is open when some spine leaves something unbounded — either its
%% length, or an element inside it.
%%
%% THIS IS WHERE TICKET 12 §2 REACHES LISTS, AND IT IS A BEHAVIOUR CHANGE.
%% Before ticket 54 the rule was "anything admitting a non-empty list is open,
%% because the length is unbounded" — true of the only two shapes the old
%% representation could hold. A union of CLOSED spines is not unbounded: over
%% `list<bool>`, a residual of `[{[bool], closed}]` is `[true]` and `[false]`,
%% two values, and a catch-all over it is now the error that names them. The
%% residual decides, never the type constructor.
l_open(Ss) -> lists:any(fun sp_open/1, Ss).

sp_open({P, closed})     -> lists:any(fun is_open/1, P);
sp_open({P, {open, T}})  -> not e_none(T) orelse lists:any(fun is_open/1, P).

m_open(top) -> true;
%% An `open` member is *at least* these fields, so it admits maps carrying
%% arbitrary others. That is the same unbounded top the name already says.
m_open(Ms)  -> lists:any(fun({open, _}) -> true;
                            ({closed, Fs}) -> lists:any(fun is_open/1, maps:values(Fs))
                         end, Ms).

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
      tuples => t_union(maps:get(tuples, A), maps:get(tuples, B)),
      lists  => l_union(maps:get(lists, A), maps:get(lists, B)),
      maps   => m_union(maps:get(maps, A), maps:get(maps, B)),
      %% Plain set union, so `string | binary` ABSORBS to `binary` rather than
      %% erroring. 20 §2's absorption rule is about containment and 09 §4's
      %% error is about indiscriminable members; `string` is nested, not
      %% overlapping, so the neighbouring rule correctly does not fire.
      bins   => ordsets:union(maps:get(bins, A), maps:get(bins, B))}.

%%% ---------------------------------------------------------------------------
%%% Intersection
%%% ---------------------------------------------------------------------------

intersect(A, B) ->
    #{atoms  => a_intersect(maps:get(atoms, A), maps:get(atoms, B)),
      ints   => i_intersect(maps:get(ints, A), maps:get(ints, B)),
      tuples => t_intersect(maps:get(tuples, A), maps:get(tuples, B)),
      lists  => l_intersect(maps:get(lists, A), maps:get(lists, B)),
      maps   => m_intersect(maps:get(maps, A), maps:get(maps, B)),
      bins   => ordsets:intersection(maps:get(bins, A), maps:get(bins, B))}.

%%% ---------------------------------------------------------------------------
%%% Subtraction — this is what computes ticket 04's residual
%%% ---------------------------------------------------------------------------

subtract(A, B) ->
    #{atoms  => a_subtract(maps:get(atoms, A), maps:get(atoms, B)),
      ints   => i_subtract(maps:get(ints, A), maps:get(ints, B)),
      tuples => t_subtract(maps:get(tuples, A), maps:get(tuples, B)),
      lists  => l_subtract(maps:get(lists, A), maps:get(lists, B)),
      maps   => m_subtract(maps:get(maps, A), maps:get(maps, B)),
      %% Set difference, so `binary \ string` is `[other]` — the non-UTF-8
      %% binaries, exactly and unspellably. See `b_str/1`.
      bins   => ordsets:subtract(maps:get(bins, A), maps:get(bins, B))}.

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

t_union(top, _) -> top;
t_union(_, top) -> top;
t_union(As, Bs) -> t_absorb(As ++ Bs).

t_intersect(top, Bs) -> Bs;
t_intersect(As, top) -> As;
t_intersect(As, Bs) ->
    t_absorb([P || A <- As, B <- Bs, length(A) =:= length(B),
                   (P = product_meet(A, B)) =/= empty]).

product_meet(A, B) ->
    Cs = [intersect(X, Y) || {X, Y} <- lists:zip(A, B)],
    case lists:any(fun is_none/1, Cs) of
        true  -> empty;
        false -> Cs
    end.

%% `top \\ anything` stays `top`: the algebra cannot name "every tuple except
%% these", so it keeps the residual too BIG rather than too small - a false
%% inexhaustive rather than a false exhaustive. `anything \\ top` is empty, which
%% is exact, and is what makes a `_` catch-all remove every tuple.
t_subtract(_, top) -> [];
t_subtract(top, _) -> top;
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
%%% Map part — ticket 26's records.
%%%
%%% The nearest prior art is the tuple part above, and this is deliberately its
%%% mirror: members kept separate, absorption but never merging, and a product
%%% decomposition for subtraction. The only difference is that the product is
%%% keyed by field NAME rather than by position, which is exactly what §1's map
%%% erasure bought — under the tuple erasure ticket 26 rejected, a field sits at
%%% a different offset per member and none of this would compose.
%%%
%%% One asymmetry with tuples is real and is why `closed`/`open` exist. Two
%%% tuples of different arity are disjoint, full stop. Two maps of different
%%% field sets are disjoint only if BOTH fix their domain — and a pattern never
%%% does, since `{ Kind: :'Shop.Order' }` constrains one field and says nothing
%%% about the rest.
%%% ---------------------------------------------------------------------------

m_union(top, _) -> top;
m_union(_, top) -> top;
m_union(As, Bs) -> m_absorb(As ++ Bs).

m_intersect(top, Bs) -> Bs;
m_intersect(As, top) -> As;
m_intersect(As, Bs) ->
    m_absorb([M || A <- As, B <- Bs, (M = m_meet(A, B)) =/= empty]).

%% Same reasoning as `t_subtract`: the algebra cannot name "every map except
%% these", so `top` minus anything stays `top` — a residual kept too BIG, which
%% reports a false inexhaustive rather than a false exhaustive. `anything \ top`
%% is empty, which is what makes a `_` catch-all remove every map.
m_subtract(_, top) -> [];
m_subtract(top, _) -> top;
m_subtract(As, Bs) -> lists:foldl(fun(B, Acc) -> m_minus_all(Acc, B) end, As, Bs).

m_minus_all(As, B) -> m_absorb(lists:append([m_minus(A, B) || A <- As])).

%%% --- meet -------------------------------------------------------------------

m_meet({closed, FA}, {closed, FB}) ->
    %% Both fix the domain, so they must fix the same one.
    case same_keys(FA, FB) of
        true  -> m_check({closed, m_zip_intersect(FA, FB)});
        false -> empty
    end;
m_meet({closed, FA}, {open, FB}) ->
    %% The closed side fixes the domain; the open side may only constrain fields
    %% that domain has.
    case keys_subset(FB, FA) of
        true  -> m_check({closed, m_zip_intersect(FA, FB)});
        false -> empty
    end;
m_meet(A = {open, _}, B = {closed, _}) ->
    m_meet(B, A);
m_meet({open, FA}, {open, FB}) ->
    %% Neither fixes the domain, so the result constrains the union of the two
    %% field sets and stays open.
    m_check({open, m_zip_intersect(FA, FB)}).

%% Intersect on shared keys; keep the unshared ones as they are.
m_zip_intersect(FA, FB) ->
    maps:fold(fun(K, VB, Acc) ->
                      case maps:find(K, Acc) of
                          {ok, VA} -> Acc#{K => intersect(VA, VB)};
                          error    -> Acc#{K => VB}
                      end
              end, FA, FB).

m_check(M) -> case m_empty(M) of true -> empty; false -> M end.

%%% --- subtraction ------------------------------------------------------------

%% (F1 × … × Fn) \ (G1 × … × Gn) over the subtrahend's keys, exactly as
%% `product_minus` does over a tuple's positions:
%%
%%   ⋃ᵢ  F where k₁…kᵢ₋₁ are intersected, kᵢ is subtracted, the rest untouched
%%
%% Componentwise subtraction would be plain wrong here for the same reason it is
%% wrong for tuples.
m_minus({closed, FA}, {closed, FB}) ->
    case same_keys(FA, FB) of
        true  -> m_decompose(closed, FA, FB);
        false -> [{closed, FA}]           % disjoint domains
    end;
m_minus({closed, FA}, {open, FB}) ->
    case keys_subset(FB, FA) of
        true  -> m_decompose(closed, FA, FB);
        false -> [{closed, FA}]           % the pattern names a field this record has not got
    end;
m_minus({open, FA}, {open, FB}) ->
    case keys_subset(FB, FA) of
        true  -> m_decompose(open, FA, FB);
        false -> [{open, FA}]
    end;
m_minus({open, FA}, {closed, _FB}) ->
    %% An open member contains maps with fields the closed one has not got, and
    %% "these fields, plus at least one more" is not something this algebra can
    %% name. Keep the minuend whole: too big rather than too small, the same
    %% honesty the list part applies to its cons element.
    [{open, FA}].

m_decompose(Kind, FA, FB) ->
    Ks = lists:sort(maps:keys(FB)),
    Members =
        [begin
             {Before, [K | _]} = lists:splitwith(fun(X) -> X =/= K end, Ks),
             Narrowed = lists:foldl(
                          fun(J, Acc) ->
                                  Acc#{J => intersect(maps:get(J, FA), maps:get(J, FB))}
                          end, FA, Before),
             {Kind, Narrowed#{K => subtract(maps:get(K, FA), maps:get(K, FB))}}
         end || K <- Ks],
    [M || M <- Members, not m_empty(M)].

%%% --- absorption -------------------------------------------------------------

%% Absorption is the checker's hot spot at scale, because it runs after every
%% subtraction and is quadratic in the number of members with a `subtract` per
%% field inside it. Measured before this was added: a 40-record dispatch cost
%% 6.1 ms and an 80-record one 47 ms, growing cubically in the clause count.
%%
%% The fix is the language's own discriminability rule (ticket 09) turned into
%% an index. **Absorption can only ever succeed between members that agree on
%% their discriminator**: `m_subset` requires the tag of the contained member to
%% subtract away against the container's, and two distinct singleton atoms never
%% do. So members are grouped by tag and compared only within their group —
%% plus against the members that carry no singleton tag, which are the only ones
%% that can swallow a member from any group.
%%
%% Nothing is merged that was not merged before; this changes which pairs are
%% CONSIDERED, not what containment means.
m_absorb(Ms0) ->
    %% `usort` first: absorption compares DISTINCT members, so two members that
    %% are the same term survive each other and a union of one record with
    %% itself would report two. Deduplication is not widening — the members are
    %% equal, so nothing is merged that was not already identical.
    Ms = lists:usort([M || M <- Ms0, not m_empty(M)]),
    Groups = maps:groups_from_list(fun discriminator/1, Ms),
    Untagged = maps:get(none, Groups, []),
    [M || M <- Ms,
          not lists:any(fun(N) -> N =/= M andalso m_subset(M, N) end,
                        rivals(M, Groups, Untagged, Ms))].

%% A member's tag, where it has exactly one. Anything else — no `Kind`, a
%% cofinite one, a union of tags — is `none` and is compared against everything.
discriminator({_Kind, Fields}) ->
    case maps:find('Kind', Fields) of
        {ok, #{atoms := {finite, [Tag]}, ints := [], tuples := [],
               lists := [], maps := []}} -> Tag;
        _ -> none
    end.

rivals(M, Groups, Untagged, All) ->
    case discriminator(M) of
        none -> All;
        Tag  -> maps:get(Tag, Groups, []) ++ Untagged
    end.

%% Is P contained in Q?
m_subset({_, FP}, {open, FQ}) ->
    %% Q constrains only its own keys, so P must have them and be narrower there.
    keys_subset(FQ, FP) andalso
        lists:all(fun(K) -> is_none(subtract(maps:get(K, FP), maps:get(K, FQ))) end,
                  maps:keys(FQ));
m_subset({closed, FP}, {closed, FQ}) ->
    same_keys(FP, FQ) andalso
        lists:all(fun(K) -> is_none(subtract(maps:get(K, FP), maps:get(K, FQ))) end,
                  maps:keys(FQ));
m_subset({open, _}, {closed, _}) ->
    %% An open member admits extra fields; a closed one does not.
    false.

same_keys(A, B) -> lists:sort(maps:keys(A)) =:= lists:sort(maps:keys(B)).

keys_subset(Sub, Sup) ->
    lists:all(fun(K) -> maps:is_key(K, Sup) end, maps:keys(Sub)).

%%% ---------------------------------------------------------------------------
%%% List part — F20, ticket 54.
%%%
%%% THE ALGEBRA NEVER MEASURES A LENGTH. It decomposes the cons cell, and length
%%% falls out. A non-empty list is a product of an element and a tail, and the
%%% rule that subtracts it exactly is `product_minus/2` above — already written,
%%% already exact, applied to tuples and maps and simply never applied here.
%%%
%%% The four languages surveyed for ticket 54 split on this. C# names a missing
%%% case `{ Length: 1 }`, because an array has an O(1) `Length` for the type
%%% system to talk about. Gleam names it `[_]`, because a cons chain has none —
%%% and beam-sharp has none either, so this is Gleam's answer. Elixir's
%%% set-theoretic checker, which rests on the same theory as this module, has
%%% the same hole this replaces.
%%%
%%% Termination lives in `sp_grow/2`: nothing unfolds on its own, unfolding is
%%% driven by the SUBTRAHEND's prefix length, and that is a syntactic property
%%% of a pattern someone wrote. The bound is per nesting level — `list<list<T>>`
%%% has an outer depth and an inner depth, and each follows its own element type
%%% down.
%%% ---------------------------------------------------------------------------

l_union(A, B) -> l_absorb(A ++ B).

l_intersect(A, B) ->
    l_absorb([S || X <- A, Y <- B, S <- sp_meet(X, Y)]).

l_subtract(A, B) ->
    l_absorb(lists:foldl(
               fun(Y, Acc) -> lists:append([sp_minus(X, Y) || X <- Acc]) end,
               A, B)).

sp_len({P, _}) -> length(P).

%% UNFOLD ONE STEP, AND IT IS EXACT:
%%
%%   {P, {open, T}}  ==  {P, closed}  ∪  {P ++ [T], {open, T}}
%%
%% A list of length >= n either has length exactly n, or has length >= n+1 with
%% element n+1 in T. Nothing is approximated and nothing is lost.
sp_unfold({P, {open, T}}) ->
    case e_none(T) of
        true  -> [{P, closed}];
        false -> [{P, closed}, {P ++ [e_ty(T)], {open, T}}]
    end.

%% Grow a spine until its prefix reaches L, unfolding as needed. The result is a
%% union equal to the input: the closed spines at lengths n..L-1, plus one open
%% spine at L.
sp_grow(S = {P, closed}, _L) when is_list(P) -> [S];
sp_grow(S = {P, {open, _}}, L) when length(P) >= L -> [S];
sp_grow(S, L) -> lists:append([sp_grow(X, L) || X <- sp_unfold(S)]).

%% --- meet ------------------------------------------------------------------

sp_meet({P1, R1}, {P2, R2}) when length(P1) =:= length(P2) ->
    Ps = [intersect(A, B) || {A, B} <- lists:zip(P1, P2)],
    case lists:any(fun is_none/1, Ps) of
        true  -> [];
        false ->
            case rest_meet(R1, R2) of
                empty -> [];
                R     -> [{Ps, R}]
            end
    end;
sp_meet(X, Y) ->
    %% Unequal prefixes: grow the shorter one to the longer's length. A shorter
    %% CLOSED spine is one exact length and the other is longer, so they are
    %% disjoint — that is the base case, and it is what stops the recursion.
    {Short, Long} = case sp_len(X) < sp_len(Y) of
                        true  -> {X, Y};
                        false -> {Y, X}
                    end,
    case Short of
        {_, closed} -> [];
        _ -> lists:append([sp_meet(S, Long) || S <- sp_grow(Short, sp_len(Long))])
    end.

%% An open rest at length n INCLUDES length exactly n — "every later element is
%% in T" is vacuous when there are none. So closed ∩ open is closed.
rest_meet(closed, closed)         -> closed;
rest_meet(closed, {open, _})      -> closed;
rest_meet({open, _}, closed)      -> closed;
rest_meet({open, T1}, {open, T2}) ->
    case e_intersect(T1, T2) of
        none -> closed;   %% no later element is admissible: exactly this length
        T    -> {open, T}
    end.

%% --- difference ------------------------------------------------------------

sp_minus(X, Y) ->
    N1 = sp_len(X), N2 = sp_len(Y),
    if
        N1 =:= N2 -> sp_minus_aligned(X, Y);
        N1 < N2 ->
            case X of
                %% X is one exact length, shorter than everything Y describes.
                {_, closed} -> [X];
                _ -> lists:append([sp_minus(S, Y) || S <- sp_grow(X, N2)])
            end;
        true ->
            case Y of
                %% Y is one exact length, shorter than everything X describes.
                {_, closed} -> [X];
                _ ->
                    %% Grow Y to X's length. Only its longest member can meet X;
                    %% the closed ones it sheds are all shorter, so disjoint.
                    [Y2] = [S || S <- sp_grow(Y, N1), sp_len(S) =:= N1],
                    sp_minus_aligned(X, Y2)
            end
    end.

%% THE PRODUCT RULE, WITH THE REST AS ONE MORE COLUMN.
%%
%%   (P × RA) \ (Q × RB)
%%     = ⋃ᵢ [P₁∩Q₁, …, Pᵢ\Qᵢ, …, Pₙ] × RA        the prefix differs at i
%%     ∪  [P₁∩Q₁, …, Pₙ∩Qₙ] × (RA \ RB)          the prefix matches throughout
%%
%% which is `product_minus/2` verbatim plus the last line. Exact.
sp_minus_aligned({P, RA}, {Q, RB}) ->
    N = length(P),
    Differs =
        [begin
             Pre = [intersect(lists:nth(J, P), lists:nth(J, Q)) || J <- lists:seq(1, I - 1)],
             Mid = subtract(lists:nth(I, P), lists:nth(I, Q)),
             Suf = [lists:nth(J, P) || J <- lists:seq(I + 1, N)],
             {Pre ++ [Mid] ++ Suf, RA}
         end || I <- lists:seq(1, N)],
    Meet = [intersect(A, B) || {A, B} <- lists:zip(P, Q)],
    Matches = case lists:any(fun is_none/1, Meet) of
                  true  -> [];
                  false -> sp_rest_minus(Meet, RA, RB)
              end,
    [S || S <- Differs, not sp_empty(S)] ++ Matches.

%% The prefix matched entirely, so whatever differs is in the tail.
sp_rest_minus(_Meet, closed, closed)    -> [];
sp_rest_minus(_Meet, closed, {open, _}) -> [];
sp_rest_minus(Meet, {open, TA}, closed) ->
    %% Length >= n minus length exactly n is length >= n+1. Unfold once and drop
    %% the closed half — the one place a subtraction makes the residual LONGER,
    %% and the reason `[]` beside `[a, b, ..]` can name `[int]`.
    case e_none(TA) of
        true  -> [];
        false -> [{Meet ++ [e_ty(TA)], {open, TA}}]
    end;
sp_rest_minus(Meet, {open, TA}, {open, TB}) ->
    case e_covers(TB, TA) of
        true  -> [];
        %% NOT EXPRESSIBLE AS ONE SPINE — "some later element is outside TB" is a
        %% disjunction over positions. Keep A, which UNDER-subtracts, which makes
        %% the residual too LARGE, which reports a false "not exhaustive". That
        %% is the safe direction; over-subtracting is the defect F20 deletes.
        %%
        %% Unreachable from source: every spine a PATTERN produces has rest
        %% `closed` or `{open, any}`, because the marker binds without
        %% constraining. Only declared-type-minus-declared-type with incomparable
        %% element types arrives here.
        false -> [{Meet, {open, TA}}]
    end.

%% --- normalisation ---------------------------------------------------------

l_absorb(Ss0) ->
    Ss = lists:usort([sp_norm(S) || S <- Ss0, not sp_empty(S)]),
    [S || S <- Ss, not lists:any(fun(Q) -> Q =/= S andalso sp_subset(S, Q) end, Ss)].

%% `{P, {open, none}}` admits no later element, so it is exactly length(P).
%% Normalising it means `sp_open/1` and equality both see one shape.
sp_norm({P, {open, T}}) ->
    case e_none(T) of
        true  -> {P, closed};
        false -> {P, {open, T}}
    end;
sp_norm(S) -> S.

sp_empty({P, _}) -> lists:any(fun is_none/1, P).

sp_subset(S, Q) -> [] =:= [X || X <- sp_minus(S, Q), not sp_empty(X)].

%% A tail marker becoming a prefix element. `any` is kept as a marker in the
%% tail so `term()` does not recurse into itself; it expands here, and the
%% expansion is finite because `term()`'s own list part is one spine whose tail
%% is again the marker.
e_ty(any) -> term();
e_ty(T)   -> T.

e_none(none) -> true;
e_none(any)  -> false;
e_none(T)    -> is_none(T).

e_intersect(none, _) -> none;
e_intersect(_, none) -> none;
e_intersect(any, C)  -> C;
e_intersect(C, any)  -> C;
e_intersect(A, B)    -> intersect(A, B).

%% Does B cover A?
e_covers(_, none)  -> true;
e_covers(none, _)  -> false;
e_covers(any, _)   -> true;
e_covers(_, any)   -> false;
e_covers(B, A)     -> is_none(subtract(A, B)).

%% A SPINE PRINTS AS A CLAUSE HEAD YOU CAN PASTE, which is the property that
%% makes a residual the clause the caller must write. `[]` beside `[a, b, ..]`
%% leaves `[int]`, not a quantity — C# would say `{ Length: 1 }` here and this
%% language has no `length` to say it with.
l_str([]) -> [];
l_str(Ss0) ->
    %% The folded forms. `list<T>` is `[] | [T, ..]` and printing it as two
    %% parts would make every ordinary list type read like a residual.
    case lists:sort(Ss0) of
        [{[], {open, any}}]                 -> ["list<term>"];
        [{[], closed}, {[T], {open, T}}]    -> ["list<" ++ to_string(T) ++ ">"];
        Ss                                  -> [sp_str(S) || S <- Ss]
    end.

sp_str({[], closed})       -> "[]";
sp_str({[], {open, any}})  -> "list<term>";
sp_str({[], {open, T}})    -> "list<" ++ to_string(T) ++ ">";
sp_str({P, closed})        -> "[" ++ sp_items(P) ++ "]";
sp_str({P, {open, _}})     -> "[" ++ sp_items(P) ++ ", ..]".

sp_items(P) -> string:join([to_string(T) || T <- P], ", ").

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

parts(#{atoms := As, ints := Is, tuples := Ts, lists := Ls, maps := Ms, bins := Bs}) ->
    a_str(As) ++ [i_str(R) || R <- Is] ++ ts_str(Ts) ++ l_str(Ls) ++ ms_str(Ms)
        ++ b_str(Bs).

%% Three of the four points have a surface spelling and the fourth does not.
%%
%% `[other]` is `binary \ string` and there is nothing to write for it: the
%% surface has a word for the top and a word for the refinement, and none for the
%% complement of a refinement inside its base. It is representable because the
%% alternatives are unsound (see `subtract/2`) and it is currently UNREACHABLE —
%% producing it needs a clause covering `string` but not `binary`, and F9 has no
%% pattern that discriminates the two. So this arm is defensive: it names the set
%% rather than crashing, and whoever lands the UTF-8 entry check or a `string`
%% pattern inherits the printing question with the representation already right.
b_str([])            -> [];
b_str([utf8])        -> ["string"];
b_str([other, utf8]) -> ["binary"];
b_str([other])       -> ["binary \\ string"].

ms_str(top) -> ["map"];
ms_str(Members) -> [m_str(M) || M <- Members].

%% Printed the way the surface spells it, because ticket 04 found the residual
%% IS the missing case and ticket 23 makes it the thing an agent is handed to
%% write. `Kind` is printed first when present — it is the discriminator, so it
%% is the field a reader needs to see to know which record is missing a clause.
m_str({Kind, Fields}) ->
    Ks = case maps:is_key('Kind', Fields) of
             true  -> ['Kind' | lists:sort(maps:keys(maps:remove('Kind', Fields)))];
             false -> lists:sort(maps:keys(Fields))
         end,
    Printed = [atom_to_list(K) ++ ": " ++ to_string(maps:get(K, Fields)) || K <- Ks],
    Tail = case Kind of open -> Printed ++ [".."]; closed -> Printed end,
    "{ " ++ string:join(Tail, ", ") ++ " }".

ts_str(top) -> ["tuple"];
ts_str(Ps)  -> [t_str(P) || P <- Ps].

%%% What you WRITE to match a type, as against what the type IS. The two coincide
%%% everywhere the surface's type syntax and pattern syntax coincide — which is
%%% most of this slice — and come apart at records.
%%%
%%% A record's whole field set is a correct description of the residual and a bad
%%% clause head: pasted in, `{ Kind: :'Shop.Invoice', Id: int, Total: int }` binds
%%% variables named `int` twice, because a lowercase name in pattern position is a
%%% variable. The head that covers the case is its **discriminator** — 26 §1 put
%%% the tag in the term precisely so one field decides it — so that is what is
%%% synthesised. Ticket 23: the compiler synthesises the head and never the body,
%%% and a head derived from the residual cannot be wrong.
to_pattern(T) ->
    case is_none(T) of
        true  -> "none";
        false -> string:join(pat_parts(T), " | ")
    end.

%% The same parts, UNJOINED — ticket 43's truncation runs over the rendered
%% sequence, so the thing being truncated has to be a sequence when it arrives.
%%
%% This is the whole of what 43 costs `bs_types`, and it is deliberately not
%% machinery: no cardinality function, no complement, no second format. 43's own
%% delta says this module gains nothing, and exporting a list the printer already
%% builds is the narrowest reading of that which still lets `bsc` do the job.
%%
%% Truncating HERE instead would have been one line shorter and wrong: every
%% other diagnostic site — the call argument, the projection, the clause return,
%% the destructuring bind, the switch arm — goes through `to_pattern/1`, and 43
%% scoped the rule to the inexhaustive head rather than to the printer.
pattern_parts(T) ->
    case is_none(T) of
        true  -> ["none"];
        false -> pat_parts(T)
    end.

pat_parts(#{atoms := As, ints := Is, tuples := Ts, lists := Ls, maps := Ms,
            bins := Bs}) ->
    a_str(As) ++ [i_str(R) || R <- Is] ++ ts_pat(Ts) ++ l_str(Ls) ++ ms_pat(Ms)
        ++ b_str(Bs).

ts_pat(top) -> ["tuple"];
ts_pat(Ps)  -> ["(" ++ string:join([to_pattern(C) || C <- P], ", ") ++ ")" || P <- Ps].

ms_pat(top)     -> ["map"];
ms_pat(Members) -> [m_pat(M) || M <- Members].

m_pat({_Kind, Fields}) ->
    case maps:find('Kind', Fields) of
        %% `bins := []` belongs in this pattern for the same reason it belongs in
        %% `is_none/1`: the map pattern is partial, so without it a `Kind` field
        %% typed `:'Shop.Order' | string` would print as a bare tag and the
        %% synthesised head would silently drop the string half.
        {ok, #{atoms := {finite, [Tag]}, ints := [], tuples := [],
               lists := [], maps := [], bins := []}} ->
            "{ Kind: " ++ atom_str(Tag) ++ " }";
        _ ->
            %% No discriminator to name, so every field is bound and ignored.
            %% Still pasteable, which is the property that matters here.
            Ks = lists:sort(maps:keys(Fields)),
            "{ " ++ string:join([atom_to_list(K) ++ ": _" || K <- Ks], ", ") ++ " }"
    end.

a_str({finite, []})   -> [];
a_str({finite, L})    -> [atom_str(A) || A <- L];
a_str({cofinite, []}) -> ["atom"];
a_str({cofinite, L})  -> ["atom \\ (" ++ string:join([atom_str(A) || A <- L], " | ") ++ ")"].

%% Quoted where the bare sigil cannot spell it. Ticket 04 makes the residual the
%% missing case and ticket 23 makes it the clause an agent is handed to write —
%% so it has to be something that lexes. A record's minted tag is the case in
%% point: `:Shop.Invoice` is not a token, `:'Shop.Invoice'` is.
atom_str(A) ->
    case atom_to_list(A) of
        S = [C | Rest] when C >= $a, C =< $z ->
            case lists:all(fun bare_char/1, Rest) of
                true  -> ":" ++ S;
                false -> ":'" ++ S ++ "'"
            end;
        S -> ":'" ++ S ++ "'"
    end.

bare_char(C) ->
    (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z)
        orelse (C >= $0 andalso C =< $9) orelse C =:= $_.

i_str({neg_inf, pos_inf}) -> "int";
i_str({Lo, Lo})           -> integer_to_list(Lo);
i_str({neg_inf, Hi})      -> "int <= " ++ integer_to_list(Hi);
i_str({Lo, pos_inf})      -> "int >= " ++ integer_to_list(Lo);
i_str({Lo, Hi})           -> integer_to_list(Lo) ++ ".." ++ integer_to_list(Hi).

t_str(P) -> "(" ++ string:join([to_string(C) || C <- P], ", ") ++ ")".
