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
-export([map_closed/1, map_open/1, map_dom/2, is_dom/1]).
-export([union/2, union/1, intersect/2, subtract/2]).
-export([is_none/1, is_open/1, is_subtype/2, to_string/1, to_pattern/1,
         pattern_parts/1, atom_str/1]).
%% F29 — the paste channel. `head_parts/2` is the printer whose output is meant
%% to be pasted back into the source; `to_pattern/1` above stays the DESCRIPTION
%% printer and its callers are unchanged.
-export([head_parts/2, head_combos/2, name_binders/1]).
%% F28 — the binder ticket 09 decided. `mu/2` names a type so its own body can
%% refer back to it; `recvar/1` is that back-reference. `unfold/1` is the only
%% way to look inside one, and every operation in this module calls it before
%% touching a part.
-export([mu/2, recvar/1, is_rec/1, unfold/1, rec_name/1, components/1]).

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
%%
%%   `dom`    — TICKET 48 Q1, and it is a THIRD KIND rather than a widening of
%%              the other two. `{closed | open, Fields}` is a finite product
%%              keyed by atom: `maps:keys/1` has something to enumerate, and
%%              `same_keys/2` and `keys_subset/2` decide by comparing those
%%              lists. `{dom, K, V}` is one uniform rule over an unbounded key
%%              domain — there is no list of names to sort — so the key
%%              machinery cannot run on it at all. That is why "just allow key
%%              types other than atom" is not the fix: the problem is not what
%%              type the keys are, it is that there is a finite list at all.
%%
%% Q7 fixes the shape and it is borrowed rather than invented: in Elixir's
%% `Descr` the named-key and domain-key maps are the SAME CONSTRUCTOR WITH A
%% DIFFERENT TAG VALUE, not two constructors. Being a 3-tuple beside two
%% 2-tuples is load-bearing — `m_subset({_, FP}, {open, FQ})` and
%% `discriminator({_Kind, Fields})` both match any 2-tuple, so a domain member
%% cannot fall into a named-field clause by accident.
%%
%% A DOMAIN MEMBER CARRIES Q3's EXCLUSION IN ITS MEANING: "every key in K, every
%% value in V, AND NO `Kind` KEY". It needs no fourth element to say so, because
%% a record is `{closed, #{'Kind' => atom_lit(Tag), ...}}` and the exclusion is
%% therefore decidable by `maps:is_key('Kind', Fields)` on the other side.
%%
%% This is the MISSING MIDDLE and that is the whole argument for paying for it.
%% `top` below is *any map whatsoever* and prints as bare `"map"`, so before 48
%% the algebra could say "exactly these named fields", "at least these named
%% fields", and "any map at all", with nothing in between.
-type map_member() :: {closed | open, #{atom() => ty()}} | {dom, ty(), ty()}.
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

%% F28 — A TYPE IS EITHER A PARTITION OR A BINDER, and the binder is the whole
%% of ticket 09's recursion arriving in the algebra.
%%
%% A partition is the six-part map above and is what every operation here
%% actually computes over. A binder names a type so its own body can refer back
%% to it, which is the one thing a finite Erlang term cannot otherwise express:
%% `type Tree = :leaf | (:node, Tree, Tree)` is `mu('Tree', :leaf | (:node,
%% recvar('Tree'), recvar('Tree')))`. Erlang has no cyclic terms, so the cycle
%% is spelled by NAME and closed by `unfold/1`.
%%
%% EQUIRECURSIVE, WHICH IS WHY THE NAME IS NOT PART OF THE MEANING. Ticket 09
%% decided two names over the same set are the same type. The name in a `mu` is
%% a binding occurrence and nothing more — it exists so `recvar` has something
%% to point at, and two binders with different names can be equal types. That is
%% what makes `is_subtype/2` need coinduction rather than comparison, and it is
%% the difference between what shipped here and an isorecursive system where the
%% name IS the type.
-type rec_ty() :: #{mu := atom(), body := ty()} | #{recvar := atom()}.

-type ty() :: #{atoms := atom_part(), ints := int_part(), tuples := tuple_part(),
                lists := list_part(), maps := map_part(), bins := bin_part()}
            | rec_ty().

%%% ---------------------------------------------------------------------------
%%% Constructors
%%% ---------------------------------------------------------------------------

none() -> #{atoms => {finite, []}, ints => [], tuples => [], lists => [],
            maps => [], bins => []}.

%%% ---------------------------------------------------------------------------
%%% F28 — the binder
%%% ---------------------------------------------------------------------------

%% `mu(Name, Body)` where `Body` may contain `recvar(Name)`. A binder whose body
%% never mentions its own name is not recursive and is returned unwrapped, so
%% nothing downstream has to unfold a type that does not need it — and so a
%% non-recursive alias is byte-identical to what it was before this feature.
mu(Name, Body) ->
    case mentions(Name, Body) of
        false -> Body;
        true  -> #{mu => Name, body => Body}
    end.

recvar(Name) when is_atom(Name) -> #{recvar => Name}.

is_rec(#{mu := _})     -> true;
is_rec(#{recvar := _}) -> true;
is_rec(_)              -> false.

rec_name(#{mu := N})     -> N;
rec_name(#{recvar := N}) -> N.

%% UNFOLDING IS SUBSTITUTION OF THE BINDER FOR ITS OWN VARIABLE, which is what
%% makes the representation equirecursive: `mu(T, B)` and `B[mu(T,B)/T]` are the
%% same type, and every operation may replace one with the other whenever it
%% needs to see a part.
%%
%% One step, never a fixpoint. The result is a partition whose components may
%% contain the SAME binder again, and that is exactly what terminates: a regular
%% tree has finitely many distinct subtrees, so the pairs an operation can meet
%% are finite and the assumption set below closes the loop.
unfold(#{mu := N, body := B} = M) -> subst_rec(B, N, M);
unfold(T)                         -> T.

%% A free `recvar` reaching an operation is a compiler defect, not a user error:
%% `resolve/3` binds every variable it introduces. Crashing here is deliberate —
%% the alternative is treating it as `none`, which would prove types empty and
%% go quiet rather than red, the failure mode `is_none/1` calls its sharpest
%% trap.
subst_rec(#{recvar := N}, N, M)          -> M;
subst_rec(#{recvar := _} = V, _, _)      -> V;
subst_rec(#{mu := N} = Inner, N, _)      -> Inner;   % shadowed; leave it alone
subst_rec(#{mu := M0, body := B}, N, Sub) -> #{mu => M0, body => subst_rec(B, N, Sub)};
subst_rec(T, N, Sub) ->
    T#{tuples => case maps:get(tuples, T) of
                     top -> top;
                     Ps  -> [[subst_rec(C, N, Sub) || C <- P] || P <- Ps]
                 end,
       lists  => [sp_map(fun(C) -> subst_rec(C, N, Sub) end, S)
                  || S <- maps:get(lists, T)],
       maps   => case maps:get(maps, T) of
                     top -> top;
                     Ms  -> [{K, maps:map(fun(_, C) -> subst_rec(C, N, Sub) end, F)}
                             || {K, F} <- Ms]
                 end}.

%% Does `Name` occur free in `T`? Used only by `mu/2`, to decide whether a
%% binder is needed at all.
mentions(N, #{recvar := N2}) -> N =:= N2;
mentions(N, #{mu := N})      -> false;                       % shadowed
mentions(N, #{mu := _, body := B}) -> mentions(N, B);
mentions(N, T) ->
    lists:any(fun(C) -> mentions(N, C) end, components(T)).

%% A spine is `{Prefix, closed}` or `{Prefix, {open, T}}`, and `{open, any}` is
%% the unconstrained tail `term/0` carries. `any` is a MARKER, not a type, so
%% neither helper may descend into it.
sp_map(F, {P, closed})      -> {[F(C) || C <- P], closed};
sp_map(F, {P, {open, any}}) -> {[F(C) || C <- P], {open, any}};
sp_map(F, {P, {open, T}})   -> {[F(C) || C <- P], {open, F(T)}}.

sp_components({P, closed})      -> P;
sp_components({P, {open, any}}) -> P;
sp_components({P, {open, T}})   -> P ++ [T].

%% Every component type held inside a partition, flattened. One place, so a part
%% added later is added here too rather than being silently skipped by three
%% separate walks.
components(T) ->
    Ts = case maps:get(tuples, T) of top -> []; Ps -> lists:append(Ps) end,
    Ls = lists:append([sp_components(S) || S <- maps:get(lists, T)]),
    Ms = case maps:get(maps, T) of
             top -> [];
             %% A DOMAIN MEMBER'S TWO TYPES ARE COMPONENTS TOO, and the clause
             %% above is a comprehension FILTER — a 3-tuple simply does not
             %% match `{_, F}`, so without this line `K` and `V` are dropped in
             %% silence rather than crashing. That is the failure the paragraph
             %% above this function exists to prevent, arriving by the exact
             %% route it names.
             Fs  -> lists:append([case M of
                                      {dom, K, V} -> [K, V];
                                      {_, F}      -> maps:values(F)
                                  end || M <- Fs])
         end,
    Ts ++ Ls ++ Ms.

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

%% Ticket 48 — `map<K, V>`. NOTE WHAT THIS DOES NOT DO: it has no emptiness
%% short-circuit, and that is the difference from `map_member/2` above rather
%% than an omission from it.
%%
%% A NAMED FIELD MUST BE PRESENT, so a field typed `none` admits no map and the
%% member collapses. A DOMAIN IS A CONSTRAINT ON ENTRIES THAT EXIST, so `#{}`
%% satisfies "every key in K, every value in V" vacuously and inhabits
%% `map<atom, Never>` — the type is populated no matter how empty K or V are.
%%
%% Reusing the field rule here would be the exact failure `is_none/1`'s own
%% comment describes one screen down: the type reports EMPTY, every containment
%% over it passes vacuously, and the compiler goes quieter rather than red. No
%% passing test sees that, so `map_type_tests` asserts the inhabitedness at the
%% boundary instead.
map_dom(K, V) -> (none())#{maps => [{dom, K, V}]}.

%% Does this type contain a domain member? The surface needs to ask, because
%% the pattern form is deferred (48 Q2) and both refusals that enforce the
%% deferral are stated against the TYPE rather than against the algebra.
is_dom(#{maps := Ms}) when is_list(Ms) ->
    lists:any(fun({dom, _, _}) -> true; (_) -> false end, Ms);
is_dom(_) -> false.

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
is_none(T) -> is_none(T, []).

%% F28 — ASSUME EMPTY ON REVISIT, and that is the CORRECT reading of
%% inhabitation rather than merely a way to stop walking.
%%
%% `type T = (:node, T, T)` is contractive — the recursion passes through a
%% constructor, so ticket 09 admits the definition — and yet it has no finite
%% values at all: every inhabitant would have to contain one already. Assuming a
%% binder empty until something proves otherwise returns exactly that. Assuming
%% it inhabited would report a type with no values as a usable one, and every
%% containment over it would then pass vacuously.
%%
%% `Tree = :leaf | (:node, Tree, Tree)` is untouched by the assumption: `:leaf`
%% proves it inhabited on the first unfolding, before the binder is reached a
%% second time.
is_none(#{mu := N} = M, Seen) ->
    lists:member(N, Seen) orelse is_none(unfold(M), [N | Seen]);
%% A BOUND VARIABLE IS THE HYPOTHESIS ITSELF; A FREE ONE IS A DEFECT.
%%
%% Inside the binder that named it, `recvar(N)` is exactly the thing being
%% assumed empty, so it answers `true` — dropping `Seen` here is what makes the
%% coinduction a no-op, and it is the defect that made `is_subtype(Iodata,
%% term)` answer FALSE: `Iodata \ term` ties the knot and returns a binder over
%% its own variable, which is empty, and reading that variable as inhabited made
%% a type fail to be a subtype of the top.
%%
%% Free — not on the chain — it is a defect in `resolve/3`, which binds every
%% variable it introduces. There `false` keeps it INHABITED, so the mistake
%% fails loudly downstream instead of proving something empty and going quiet.
is_none(#{recvar := N}, Seen) ->
    lists:member(N, Seen);
%% THE LIST PART IS CHECKED, NOT REQUIRED TO BE ABSENT. This head used to demand
%% `lists := []`, which was true by construction: `mk_spine/2` and `cons/1`
%% collapse a spine with an empty element to `none()`, and `sp_minus_aligned/3`
%% filters its results through `sp_empty/1`, so an inhabited-looking spine over
%% an empty element could not be built. A subtraction that ties a knot can build
%% one — its element is the assumption variable, which `sp_empty/1` cannot see
%% through because it carries no chain — so emptiness is decided here instead,
%% where the chain exists.
is_none(#{atoms := {finite, []}, ints := [], tuples := Ts, lists := Ls,
          maps := Ms, bins := []}, Seen)
  when Ts =/= top, Ms =/= top ->
    lists:all(fun(Cs) -> lists:any(fun(C) -> is_none(C, Seen) end, Cs) end, Ts)
        andalso lists:all(fun(S) -> sp_none(S, Seen) end, Ls)
        andalso lists:all(fun(M) -> m_empty(M, Seen) end, Ms);
is_none(_, _) ->
    false.

%% A spine is empty when a written position is. `{[], closed}` is `[]` — one
%% real value, never empty — and `{[], {open, any}}` is every list, so a spine
%% with no prefix is inhabited whatever its tail says.
sp_none({P, _}, Seen) -> lists:any(fun(C) -> is_none(C, Seen) end, P).

m_empty(M) -> m_empty(M, []).

%% `#{}` inhabits every domain member, so one is never empty. See `map_dom/2`
%% for why this is not the named-field rule with a different shape.
m_empty({dom, _K, _V}, _Seen) ->
    false;
m_empty({_Kind, Fields}, Seen) ->
    lists:any(fun(C) -> is_none(C, Seen) end, maps:values(Fields)).

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
                            %% A domain member's key set is unbounded, which is
                            %% the same unboundedness `open` reports — and 48
                            %% priced exactly this: an open key domain is the one
                            %% place exhaustiveness cannot work, since no finite
                            %% clause set closes the residual. So a catch-all
                            %% over it is legitimate rather than the
                            %% `catch_all_over_closed` mistake, which is what
                            %% this predicate decides.
                            ({dom, _, _}) -> true;
                            ({closed, Fs}) -> lists:any(fun is_open/1, maps:values(Fs))
                         end, Ms).

%%% ---------------------------------------------------------------------------
%%% Union — exact, never widening
%%% ---------------------------------------------------------------------------

union([]) -> none();
union([T]) -> T;
union([H | T]) -> union(H, union(T)).

%% F28 — UNION NEEDS TO UNFOLD AND NOTHING MORE. It never descends into a
%% component itself; the only descent below it is absorption, which asks
%% containment through `subtract/3` and gets that operation's own assumption set
%% with it. So there is no cycle for union to cut.
%% IDEMPOTENCE FIRST, and it is not an optimisation. A bare `recvar` has no
%% parts to read, and the commonest way one reaches an operation is a spine
%% asking what its elements are: `list<Iodata>` holds `recvar('Iodata')` in both
%% its prefix and its tail, so `l_elem/1` unions the variable with itself. That
%% answer is the variable, and it is exact.
union(A, A) -> A;
union(A, B) -> u_parts(open_for(union, A, B), open_for(union, B, A)).

%% A `mu` opens by unfolding. A bare `recvar` cannot: it is a name whose meaning
%% lives in an enclosing binder this operation was not given, and the algebra is
%% in disjunctive normal form with no union node to hold "this variable or that
%% partition". Unequal operands here would be a defect in the caller rather than
%% a user's type, so it says so instead of reading a key that is not there —
%% `badkey` from three frames down is the version of this that costs an hour.
open_for(_Op, #{mu := _} = T, _Other) -> unfold(T);
open_for(Op, #{recvar := N}, Other) ->
    erlang:error({free_recursive_variable, Op, N, Other});
open_for(_Op, T, _Other) -> T.

u_parts(A, B) ->
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
%%% F28 — the assumption set, and why both operations below return a BINDER
%%% ---------------------------------------------------------------------------
%%
%% `As` is the chain of argument pairs this operation has already entered,
%% each paired with the name it was given. Meeting a pair twice means the walk
%% has come back to where it was, and a regular tree has finitely many distinct
%% subtrees, so the pairs are finite and the chain always closes.
%%
%% BOTH OPERATIONS TIE THE KNOT WITH A FRESH BINDER, and `subtract` in
%% particular must NOT answer `none` there. The tempting reading — "assume the
%% difference is empty on revisit" — is the right way to DECIDE subtyping and
%% the wrong way to COMPUTE a residual: it makes the residual too small in
%% exactly the recursive positions, and a residual too small reports a false
%% *exhaustive*. That is the direction ticket 54's defect ran in and the one
%% this algebra is built to avoid. So the difference of two regular trees is
%% itself a regular tree, spelled with a binder, and the emptiness question is
%% left to `is_none/2`, which assumes empty on revisit and is the only place
%% that may.
%%
%% The name is the DEPTH of the chain. Two binders minted at the same depth are
%% in disjoint sibling subtrees — a `recvar` is only ever created by a
%% descendant of the binder that named it — so the scopes cannot overlap, and
%% `subst_rec/3` stops at a shadowing `mu` in the nested case. No counter has to
%% be threaded back out.
rec_step(Op, A, B, As, Parts) ->
    Key = {A, B},
    case assumed(Key, As) of
        {_, Name} -> recvar(Name);
        false ->
            Name = nm(length(As)),
            mu(Name, Parts(open_for(Op, A, B), open_for(Op, B, A),
                           [{Key, Name} | As]))
    end.

nm(D) -> list_to_atom("$mu" ++ integer_to_list(D)).

%% THE SEAM THAT LETS THE STOPWATCH BE SEEN TO FIRE, and it exists because F28's
%% own bar asks for it: the gate must go red on *a build with the memo table
%% disabled*. Stubbing a timeout into the gate's fixtures proves only that
%% `judge` can READ one; it does not prove the clock fires. With
%% `BS_NO_TYPE_MEMO` set, this never remembers a pair, so the walk over a regular
%% tree cannot close and the compile blows the budget — a real red, from a real
%% build, on the real defect.
%%
%% Read here rather than cached because the cost is paid only when a recursive
%% type is actually being compared, and a cached flag would be one more piece of
%% state to get wrong. Nothing outside the gate's `--self-test` ever sets it.
assumed(Key, As) ->
    case os:getenv("BS_NO_TYPE_MEMO") of
        false -> lists:keyfind(Key, 1, As);
        _     -> false
    end.

%%% ---------------------------------------------------------------------------
%%% Intersection
%%% ---------------------------------------------------------------------------

intersect(A, B) -> intersect(A, B, []).

%% `A ∩ A` is `A` for every type, and stating it here is what lets a bare
%% `recvar` meet itself — which happens whenever a recursive type's own
%% components are compared — without opening a variable that cannot be opened.
intersect(A, A, _As) -> A;
%% A FREE VARIABLE IS UNDECIDABLE HERE, SO IT IS KEPT WHOLE — the same choice
%% `t_subtract/3` and `m_subtract/3` already make for `top`, and for the same
%% reason. A `recvar` names a type whose meaning lives in a binder this
%% operation was not handed, so no exact answer is available; keeping the
%% operand keeps the result too BIG, which reports a false inexhaustive rather
%% than a false exhaustive. Erring the other way is the defect ticket 54 deleted.
intersect(#{recvar := _} = A, _B, _As) -> A;
intersect(A, #{recvar := _}, _As)      -> A;
intersect(A, B, As) ->
    case is_rec(A) orelse is_rec(B) of
        true  -> rec_step(intersect, A, B, As, fun i_parts/3);
        false -> i_parts(A, B, As)
    end.

i_parts(A, B, As) ->
    #{atoms  => a_intersect(maps:get(atoms, A), maps:get(atoms, B)),
      ints   => i_intersect(maps:get(ints, A), maps:get(ints, B)),
      tuples => t_intersect(maps:get(tuples, A), maps:get(tuples, B), As),
      lists  => l_intersect(maps:get(lists, A), maps:get(lists, B), As),
      maps   => m_intersect(maps:get(maps, A), maps:get(maps, B), As),
      bins   => ordsets:intersection(maps:get(bins, A), maps:get(bins, B))}.

%%% ---------------------------------------------------------------------------
%%% Subtraction — this is what computes ticket 04's residual
%%% ---------------------------------------------------------------------------

subtract(A, B) -> subtract(A, B, []).

%% `A \ A` is empty for every type, and as with `intersect/3` this is what lets
%% a bare `recvar` be subtracted from itself. It also short-circuits the common
%% case where a clause covers a component exactly.
subtract(A, A, _As) -> none();
%% Undecidable, kept whole, too big rather than too small — see `intersect/3`.
%% Both directions land on the minuend: an unknown minus anything is still that
%% unknown, and anything minus an unknown has had nothing proved removable.
subtract(#{recvar := _} = A, _B, _As) -> A;
subtract(A, #{recvar := _}, _As)      -> A;
subtract(A, B, As) ->
    case is_rec(A) orelse is_rec(B) of
        true  -> rec_step(subtract, A, B, As, fun s_parts/3);
        false -> s_parts(A, B, As)
    end.

s_parts(A, B, As) ->
    #{atoms  => a_subtract(maps:get(atoms, A), maps:get(atoms, B)),
      ints   => i_subtract(maps:get(ints, A), maps:get(ints, B)),
      tuples => t_subtract(maps:get(tuples, A), maps:get(tuples, B), As),
      lists  => l_subtract(maps:get(lists, A), maps:get(lists, B), As),
      maps   => m_subtract(maps:get(maps, A), maps:get(maps, B), As),
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

t_intersect(top, Bs, _Asm) -> Bs;
t_intersect(As, top, _Asm) -> As;
t_intersect(As, Bs, Asm) ->
    t_absorb([P || A <- As, B <- Bs, length(A) =:= length(B),
                   (P = product_meet(A, B, Asm)) =/= empty]).

product_meet(A, B, Asm) ->
    Cs = [intersect(X, Y, Asm) || {X, Y} <- lists:zip(A, B)],
    case lists:any(fun is_none/1, Cs) of
        true  -> empty;
        false -> Cs
    end.

%% `top \\ anything` stays `top`: the algebra cannot name "every tuple except
%% these", so it keeps the residual too BIG rather than too small - a false
%% inexhaustive rather than a false exhaustive. `anything \\ top` is empty, which
%% is exact, and is what makes a `_` catch-all remove every tuple.
t_subtract(_, top, _Asm) -> [];
t_subtract(top, _, _Asm) -> top;
t_subtract(As, Bs, Asm) ->
    lists:foldl(fun(B, Acc) -> t_minus_all(Acc, B, Asm) end, As, Bs).

t_minus_all(As, B, Asm) ->
    t_absorb(lists:append([product_minus(A, B, Asm) || A <- As])).

%% (A1×…×An) \ (B1×…×Bn) decomposes into n disjoint products:
%%
%%   ⋃ᵢ (A1∩B1) × … × (Aᵢ₋₁∩Bᵢ₋₁) × (Aᵢ\Bᵢ) × Aᵢ₊₁ × … × An
%%
%% Exact, and the reason a two-component tuple can be subtracted at all — a
%% componentwise subtraction would be plain wrong.
product_minus(A, B, _Asm) when length(A) =/= length(B) -> [A];
product_minus(A, B, Asm) ->
    N = length(A),
    Products =
        [begin
             Prefix = [intersect(lists:nth(J, A), lists:nth(J, B), Asm) || J <- lists:seq(1, I - 1)],
             Middle = subtract(lists:nth(I, A), lists:nth(I, B), Asm),
             Suffix = [lists:nth(J, A) || J <- lists:seq(I + 1, N)],
             Prefix ++ [Middle] ++ Suffix
         end || I <- lists:seq(1, N)],
    [P || P <- Products, not lists:any(fun is_none/1, P)].

%% Drop any product wholly contained in another. This removes redundancy without
%% ever merging two products into a wider one.
%%
%% TICKET 61 — CONTAINMENT BETWEEN EQUALS MUST KEEP ONE, NOT TWO AND NOT ZERO.
%% The previous spelling compared DISTINCT members only (`Q =/= P`), which had
%% both failure modes at once: a product unioned with itself survived twice —
%% `l_elem/1` does exactly that for every `list<T>`, and the doubled member then
%% read as ambiguity, stopping the validator's descent at the row — while two
%% structurally different spellings of the same product each absorbed the other
%% and BOTH vanished, a union of inhabited types reporting empty. `m_absorb/1`
%% fixed only the first half for maps; folding to a maximal antichain fixes
%% both: a product covered by anything already kept is dropped (equality keeps
%% the first), and a kept product covered by a newcomer gives way to it.
t_absorb(Ps0) ->
    Ps = [P || P <- Ps0, not lists:any(fun is_none/1, P)],
    lists:foldl(fun(P, Kept) ->
                        case lists:any(fun(Q) -> product_subset(P, Q) end, Kept) of
                            true  -> Kept;
                            false -> [Q || Q <- Kept, not product_subset(Q, P)]
                                     ++ [P]
                        end
                end, [], Ps).

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

m_intersect(top, Bs, _Asm) -> Bs;
m_intersect(As, top, _Asm) -> As;
m_intersect(As, Bs, Asm) ->
    m_absorb([M || A <- As, B <- Bs, (M = m_meet(A, B, Asm)) =/= empty]).

%% Same reasoning as `t_subtract`: the algebra cannot name "every map except
%% these", so `top` minus anything stays `top` — a residual kept too BIG, which
%% reports a false inexhaustive rather than a false exhaustive. `anything \ top`
%% is empty, which is what makes a `_` catch-all remove every map.
m_subtract(_, top, _Asm) -> [];
m_subtract(top, _, _Asm) -> top;
m_subtract(As, Bs, Asm) ->
    lists:foldl(fun(B, Acc) -> m_minus_all(Acc, B, Asm) end, As, Bs).

m_minus_all(As, B, Asm) ->
    m_absorb(lists:append([m_minus(A, B, Asm) || A <- As])).

%%% --- meet -------------------------------------------------------------------
%%%
%%% TICKET 48'S 2×2 IS NOW A 3×3, and the five new cells are here. The cost grew
%%% by multiplication rather than addition, which is the whole reason 48 called
%%% Q1 the expensive question and answered it anyway.
%%%
%%% The domain cells are stated FIRST so they are reached before the named-field
%%% clauses, which is a correctness requirement and not a style: `{dom, K, V}` is
%%% a 3-tuple and cannot match `{closed, F}` or `{open, F}`, but a mixed pair
%%% would fall through to `function_clause` without them.

%% Two domains meet pointwise: the entries that satisfy both rules are exactly
%% those whose key satisfies both and whose value satisfies both.
m_meet({dom, KA, VA}, {dom, KB, VB}, Asm) ->
    m_check({dom, intersect(KA, KB, Asm), intersect(VA, VB, Asm)});
%% A named-field member meeting a domain is that member, kept or dropped: it
%% already fixes its keys, so the domain either admits all of them or none.
%% `fields_fit/4` carries Q3 — a member with a `Kind` is a record and no record
%% is a `map<K, V>`.
m_meet(A = {Kind, FA}, {dom, KB, VB}, Asm) when Kind =:= closed; Kind =:= open ->
    case fields_fit(Kind, FA, KB, VB, Asm) of
        true  -> m_check(A);
        false -> empty
    end;
m_meet(A = {dom, _, _}, B = {Kind, _}, Asm) when Kind =:= closed; Kind =:= open ->
    m_meet(B, A, Asm);

m_meet({closed, FA}, {closed, FB}, Asm) ->
    %% Both fix the domain, so they must fix the same one.
    case same_keys(FA, FB) of
        true  -> m_check({closed, m_zip_intersect(FA, FB, Asm)});
        false -> empty
    end;
m_meet({closed, FA}, {open, FB}, Asm) ->
    %% The closed side fixes the domain; the open side may only constrain fields
    %% that domain has.
    case keys_subset(FB, FA) of
        true  -> m_check({closed, m_zip_intersect(FA, FB, Asm)});
        false -> empty
    end;
m_meet(A = {open, _}, B = {closed, _}, Asm) ->
    m_meet(B, A, Asm);
m_meet({open, FA}, {open, FB}, Asm) ->
    %% Neither fixes the domain, so the result constrains the union of the two
    %% field sets and stays open.
    m_check({open, m_zip_intersect(FA, FB, Asm)}).

%% Intersect on shared keys; keep the unshared ones as they are.
m_zip_intersect(FA, FB, Asm) ->
    maps:fold(fun(K, VB, Acc) ->
                      case maps:find(K, Acc) of
                          {ok, VA} -> Acc#{K => intersect(VA, VB, Asm)};
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
%%
%% THE DOMAIN CELLS ARE WHERE SUBTYPING IS DECIDED, and that is worth saying
%% plainly because 48 Q2 makes it easy to assume otherwise. Deferring the pattern
%% form spares `m_decompose/3`; it does NOT spare subtraction, because
%% `is_subtype(A, B) -> is_none(subtract(A, B))` and every parameter pass in the
%% language goes through it. A domain cell that returned the minuend
%% unconditionally would type-check nothing and refuse everything.
%%
%% Each cell that cannot decide keeps the minuend WHOLE — too big rather than too
%% small, the same honesty `{open, FA} \ {closed, _}` already applies. Too big
%% costs a refusal; too small costs a false exhaustiveness proof, and this
%% language's one promise is that the second never happens.

%% Domain minus domain. Subtracting a wider rule from a narrower one empties it,
%% which is what makes `map<atom, int>` pass where `map<atom, term>` is asked
%% for. Anything else keeps the minuend: "every atom key except the ones whose
%% value is an int" is not something this algebra can name.
m_minus({dom, KA, VA}, {dom, KB, VB}, Asm) ->
    case sub(KA, KB, Asm) andalso sub(VA, VB, Asm) of
        true  -> [];
        false -> [{dom, KA, VA}]
    end;
%% A CLOSED MEMBER MINUS A DOMAIN, AND THIS IS THE CELL Q3 AND Q7 BOTH LAND ON.
%% Q7 says the shipped brace map and `map<K, V>` are one type family, so a closed
%% member whose keys and values fit the rule IS one and subtracts away. Q3 says
%% the exclusion is `Kind` absent only, so a record — which carries a minted
%% `Kind` — never fits, and `Order` is not a `map<atom, term>`.
m_minus({closed, FA}, {dom, KB, VB}, Asm) ->
    case fields_fit(closed, FA, KB, VB, Asm) of
        true  -> [];
        false -> [{closed, FA}]
    end;
%% An open member is "at least these fields", so it admits maps carrying keys
%% nobody has named. Those may fall outside the domain, or carry a `Kind`.
%% Unprovable, so the minuend stays whole.
m_minus(A = {open, _}, {dom, _, _}, _Asm) ->
    [A];
%% A domain minus a named-field member. One member removes one shape from an
%% unbounded family and leaves an infinity behind, which is not nameable — the
%% same shape as `top` minus anything.
m_minus(A = {dom, _, _}, {Kind, _}, _Asm) when Kind =:= closed; Kind =:= open ->
    [A];

m_minus({closed, FA}, {closed, FB}, Asm) ->
    case same_keys(FA, FB) of
        true  -> m_decompose(closed, FA, FB, Asm);
        false -> [{closed, FA}]           % disjoint domains
    end;
m_minus({closed, FA}, {open, FB}, Asm) ->
    case keys_subset(FB, FA) of
        true  -> m_decompose(closed, FA, FB, Asm);
        false -> [{closed, FA}]           % the pattern names a field this record has not got
    end;
m_minus({open, FA}, {open, FB}, Asm) ->
    case keys_subset(FB, FA) of
        true  -> m_decompose(open, FA, FB, Asm);
        false -> [{open, FA}]
    end;
m_minus({open, FA}, {closed, _FB}, _Asm) ->
    %% An open member contains maps with fields the closed one has not got, and
    %% "these fields, plus at least one more" is not something this algebra can
    %% name. Keep the minuend whole: too big rather than too small, the same
    %% honesty the list part applies to its cons element.
    [{open, FA}].

m_decompose(Kind, FA, FB, Asm) ->
    Ks = lists:sort(maps:keys(FB)),
    Members =
        [begin
             {Before, [K | _]} = lists:splitwith(fun(X) -> X =/= K end, Ks),
             Narrowed = lists:foldl(
                          fun(J, Acc) ->
                                  Acc#{J => intersect(maps:get(J, FA), maps:get(J, FB), Asm)}
                          end, FA, Before),
             {Kind, Narrowed#{K => subtract(maps:get(K, FA), maps:get(K, FB), Asm)}}
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
%% A domain member has no `Kind` BY CONSTRUCTION — that is Q3 — so it is
%% untagged and compared against everything, which is what `none` means here.
discriminator({dom, _, _}) ->
    none;
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
%%
%% The domain clauses come first for the reason the meet grid gives: a 3-tuple
%% cannot match `{_, FP}`, but a MIXED pair would reach a named-field clause and
%% crash rather than answer.
m_subset({dom, KP, VP}, {dom, KQ, VQ}) ->
    sub(KP, KQ, []) andalso sub(VP, VQ, []);
m_subset({Kind, FP}, {dom, KQ, VQ}) when Kind =:= closed; Kind =:= open ->
    fields_fit(Kind, FP, KQ, VQ, []);
%% A domain admits maps no finite field list names, so it is inside no
%% named-field member.
m_subset({dom, _, _}, {_, _}) ->
    false;
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

%% Containment, spelled once. `m_subset/2` already reaches for the public
%% `is_none(subtract(A, B))` rather than threading assumptions, and the domain
%% cells follow it rather than inventing a second convention beside it.
sub(A, B, Asm) -> is_none(subtract(A, B, Asm)).

%% DOES A FINITE FIELD LIST SATISFY A DOMAIN RULE? This is where Q3 and Q7 are
%% enforced, and it is three conditions rather than two:
%%
%%   1. NO `Kind` — Q3's "`Kind` absent only". A record is
%%      `{closed, #{'Kind' => atom_lit(Tag), ...}}`, so this one line is what
%%      makes `Order` fail to be a `map<atom, term>`. Without it the domain
%%      quietly becomes `top`, which is the imprecision 48 exists to sit between.
%%   2. every key is in K — the key is a NAME, so it is tested as the singleton
%%      atom type it denotes.
%%   3. every value type is in V.
%%
%% An OPEN member can never satisfy this whatever its named fields say, because
%% the fields it does not name are unconstrained and may be a `Kind`. Saying so
%% here keeps the three callers from each having to remember it.
fields_fit(open, _Fields, _K, _V, _Asm) ->
    false;
fields_fit(closed, Fields, K, V, Asm) ->
    not maps:is_key('Kind', Fields) andalso
        lists:all(fun({Name, T}) ->
                          sub(atom_lit(Name), K, Asm) andalso sub(T, V, Asm)
                  end, maps:to_list(Fields)).

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

l_intersect(A, B, Asm) ->
    l_absorb([S || X <- A, Y <- B, S <- sp_meet(X, Y, Asm)]).

l_subtract(A, B, Asm) ->
    l_absorb(lists:foldl(
               fun(Y, Acc) -> lists:append([sp_minus(X, Y, Asm) || X <- Acc]) end,
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

sp_meet({P1, R1}, {P2, R2}, Asm) when length(P1) =:= length(P2) ->
    Ps = [intersect(A, B, Asm) || {A, B} <- lists:zip(P1, P2)],
    case lists:any(fun is_none/1, Ps) of
        true  -> [];
        false ->
            case rest_meet(R1, R2, Asm) of
                empty -> [];
                R     -> [{Ps, R}]
            end
    end;
sp_meet(X, Y, Asm) ->
    %% Unequal prefixes: grow the shorter one to the longer's length. A shorter
    %% CLOSED spine is one exact length and the other is longer, so they are
    %% disjoint — that is the base case, and it is what stops the recursion.
    {Short, Long} = case sp_len(X) < sp_len(Y) of
                        true  -> {X, Y};
                        false -> {Y, X}
                    end,
    case Short of
        {_, closed} -> [];
        _ -> lists:append([sp_meet(S, Long, Asm) || S <- sp_grow(Short, sp_len(Long))])
    end.

%% An open rest at length n INCLUDES length exactly n — "every later element is
%% in T" is vacuous when there are none. So closed ∩ open is closed.
rest_meet(closed, closed, _Asm)         -> closed;
rest_meet(closed, {open, _}, _Asm)      -> closed;
rest_meet({open, _}, closed, _Asm)      -> closed;
rest_meet({open, T1}, {open, T2}, Asm) ->
    case e_intersect(T1, T2, Asm) of
        none -> closed;   %% no later element is admissible: exactly this length
        T    -> {open, T}
    end.

%% --- difference ------------------------------------------------------------

sp_minus(X, Y, Asm) ->
    N1 = sp_len(X), N2 = sp_len(Y),
    if
        N1 =:= N2 -> sp_minus_aligned(X, Y, Asm);
        N1 < N2 ->
            case X of
                %% X is one exact length, shorter than everything Y describes.
                {_, closed} -> [X];
                _ -> lists:append([sp_minus(S, Y, Asm) || S <- sp_grow(X, N2)])
            end;
        true ->
            case Y of
                %% Y is one exact length, shorter than everything X describes.
                {_, closed} -> [X];
                _ ->
                    %% Grow Y to X's length. Only its longest member can meet X;
                    %% the closed ones it sheds are all shorter, so disjoint.
                    [Y2] = [S || S <- sp_grow(Y, N1), sp_len(S) =:= N1],
                    sp_minus_aligned(X, Y2, Asm)
            end
    end.

%% THE PRODUCT RULE, WITH THE REST AS ONE MORE COLUMN.
%%
%%   (P × RA) \ (Q × RB)
%%     = ⋃ᵢ [P₁∩Q₁, …, Pᵢ\Qᵢ, …, Pₙ] × RA        the prefix differs at i
%%     ∪  [P₁∩Q₁, …, Pₙ∩Qₙ] × (RA \ RB)          the prefix matches throughout
%%
%% which is `product_minus/2` verbatim plus the last line. Exact.
sp_minus_aligned({P, RA}, {Q, RB}, Asm) ->
    N = length(P),
    Differs =
        [begin
             Pre = [intersect(lists:nth(J, P), lists:nth(J, Q), Asm) || J <- lists:seq(1, I - 1)],
             Mid = subtract(lists:nth(I, P), lists:nth(I, Q), Asm),
             Suf = [lists:nth(J, P) || J <- lists:seq(I + 1, N)],
             {Pre ++ [Mid] ++ Suf, RA}
         end || I <- lists:seq(1, N)],
    Meet = [intersect(A, B, Asm) || {A, B} <- lists:zip(P, Q)],
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

%% ABSORPTION ASKS A FRESH QUESTION, so it starts a fresh assumption chain. It
%% is a containment test between two types that have already been computed, not
%% a step in the descent that produced them — and `subtract/3` cuts its own
%% cycles, so nothing here can spin.
sp_subset(S, Q) -> [] =:= [X || X <- sp_minus(S, Q, []), not sp_empty(X)].

%% A tail marker becoming a prefix element. `any` is kept as a marker in the
%% tail so `term()` does not recurse into itself; it expands here, and the
%% expansion is finite because `term()`'s own list part is one spine whose tail
%% is again the marker.
e_ty(any) -> term();
e_ty(T)   -> T.

e_none(none) -> true;
e_none(any)  -> false;
e_none(T)    -> is_none(T).

e_intersect(none, _, _Asm) -> none;
e_intersect(_, none, _Asm) -> none;
e_intersect(any, C, _Asm)  -> C;
e_intersect(C, any, _Asm)  -> C;
e_intersect(A, B, Asm)     -> intersect(A, B, Asm).

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

%% TICKET 61 — THE EXACT TOP PRINTS AS `term`, on every channel. `term` is not
%% an author's alias that erased by diagnostic time; it is the name of the top,
%% and its six-way decomposition tells the reader less than the one word does.
%% A PARTIAL residual is untouched — nothing short of the whole top takes this
%% spelling, so "the residual is a set the author must enumerate" still holds
%% everywhere enumeration says anything. The subtype test degrades safely: a
%% type semantically equal to the top but spelled through over-approximated
%% parts merely keeps its enumerated form.
to_string(T) ->
    case is_none(T) of
        true  -> "none";
        false ->
            case is_subtype(term(), T) of
                true  -> "term";
                false -> string:join(parts(T), " | ")
            end
    end.

%%% F28 — HOW A BINDER PRINTS, and the two cases are not the same reader.
%%%
%%% A binder that came from a `type` declaration carries the AUTHOR'S OWN NAME,
%%% and that is the best thing a message can say: `Tree` means something to the
%%% person reading it and its unfolding does not.
%%%
%%% One minted by `subtract/3` or `intersect/3` carries a synthetic name — the
%%% residual of `N \ :leaf` is a real recursive type nobody named — and `$mu0`
%%% would be noise. Those print ONE unfolding with the recursive positions shown
%%% as `...`, because the shape is what the author needs to see and the depth is
%%% not. Printing terminates either way: the name is a leaf, and the unfolding's
%%% own back-references are `recvar`, which is also a leaf.
rec_str(N) ->
    case synthetic(N) of
        false -> atom_to_list(N);
        true  -> "..."
    end.

synthetic(N) -> lists:prefix("$mu", atom_to_list(N)).

parts(#{mu := N, body := B}) ->
    case synthetic(N) of
        false -> [atom_to_list(N)];
        true  -> parts(B)
    end;
parts(#{recvar := N}) -> [rec_str(N)];
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
%% Printed the way the SURFACE spells it, which for a domain is `map<K, V>` and
%% not a brace form — there is no brace form to print, the pattern half being
%% deferred (48 Q2). A member kind with no printer reaches the author as a raw
%% Erlang term in the middle of a diagnostic.
m_str({dom, K, V}) ->
    "map<" ++ to_string(K) ++ ", " ++ to_string(V) ++ ">";
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

%% TICKET 61 — the exact top is one part, `term`, here as in `to_string/1`.
%% The leaves of this printer are already type words (`int`, `tuple`, `map`),
%% so the top's word is the consistent spelling — and suggesting `_` instead
%% would recommend a form ticket 12 §2 refuses over a closed residual.
pat_parts(#{mu := N, body := B}) ->
    case synthetic(N) of
        false -> [atom_to_list(N)];
        true  -> pat_parts(B)
    end;
pat_parts(#{recvar := N}) -> [rec_str(N)];
pat_parts(T = #{atoms := As, ints := Is, tuples := Ts, lists := Ls, maps := Ms,
                bins := Bs}) ->
    case is_subtype(term(), T) of
        true  -> ["term"];
        false -> a_str(As) ++ [i_str(R) || R <- Is] ++ ts_pat(Ts) ++ l_str(Ls)
                     ++ ms_pat(Ms) ++ b_str(Bs)
    end.

ts_pat(top) -> ["tuple"];
ts_pat(Ps)  -> ["(" ++ string:join([to_pattern(C) || C <- P], ", ") ++ ")" || P <- Ps].

%%% ---------------------------------------------------------------------------
%%% F29 — THE HEAD CHANNEL, which is a different job from the one above.
%%%
%%% `to_pattern/1` DESCRIBES a set: it is rendered into `rejected`, `member`,
%%% `undeclared`, `unmatched`, `subject` and the switch `arm`, all of which are
%%% sentences about a type. This printer produces text meant to be PASTED BACK
%%% INTO THE SOURCE, and the two come apart at every leaf where the surface's
%%% type syntax is not its pattern syntax:
%%%
%%%   int span      `300..399` describes; `>= 300 and <= 399` is what you write.
%%%                 Ticket 42 settled that on 2026-08-15 and the parser was built
%%%                 for it (`bs_parser.yrl:462-465`); only the printer was not.
%%%   union         `a | b` describes; a head has no `|`, so a union of parts is
%%%                 N HEAD LINES. F29.2.
%%%   record        `{ Kind: :'M.Order' }` describes; F22's `Order o` is what you
%%%                 write, where the name resolves at the error site.
%%%   list element  the element printer was `to_string`, so a record inside a
%%%                 list printed its field types and bound `int` twice. This one
%%%                 recurses into the head printer instead.
%%%   type word     `int`, `string`, `tuple`, `map`, `term` are TYPE words. In
%%%                 pattern position a lowercase word is a BINDER, so
%%%                 `Kind(string)` silently means `Kind(s)`. The head channel
%%%                 emits the binder it actually means, and `to_string/1` keeps
%%%                 the type word — which is why ticket 61's answer is untouched
%%%                 here (F29.8).
%%%
%%% NOT EVERYTHING HAS A HEAD. A cofinite atom set and `binary \ string` describe
%%% sets the surface cannot spell as a pattern, and inventing one would be worse
%%% than saying so. Those contribute NO part, which empties the head list and
%%% makes `pasteable` absent rather than empty (F29.9).
%%%
%%% BINDERS ARE PLACEHOLDERS UNTIL THE LINE IS ASSEMBLED. A head is built from
%%% parts that do not know about each other, and two binders spelled the same in
%%% one head is `repeated_in_head` — the exact defect this feature exists to stop
%%% emitting. So a binder travels as an open byte, its base name and a close
%%% byte, and `name_binders/1` numbers them once the whole line exists. The
%%% convention and its resolver live together here so that no caller can
%%% half-implement it.
%%%
%%% `Names` maps a record's minted tag to the source name that resolves AT THE
%%% ERROR SITE. It is threaded rather than derived from the tag, because the
%%% segment after the last dot is a name whether or not it is in scope, and
%%% suggesting a head that names a type the file cannot see is a worse failure
%%% than the discriminator it replaces (F29.4).
%%% ---------------------------------------------------------------------------

-define(B_OPEN, 0).
-define(B_CLOSE, 1).
-define(G_OPEN, 2).
-define(G_CLOSE, 3).
-define(G_SELF, 4).

binder(Base) -> [?B_OPEN] ++ Base ++ [?B_CLOSE].

%% A CONDITION ON THE BINDER TO ITS LEFT, hoisted to a `when` clause once the
%% line exists. `?G_SELF` stands for that binder's eventual name, and appears
%% twice in a two-sided span because `n >= 300 and n <= 399` names it twice.
guard(Cond) -> [?G_OPEN] ++ Cond ++ [?G_CLOSE].

%% The parts of a head, unjoined and one per LINE — never `|`-joined, which is
%% the whole of F29.2. `none` has no head: there is nothing left to match.
head_parts(T, Names) ->
    case is_none(T) of
        true  -> [];
        false -> hd_parts(T, Names, arg)
    end.

%% The top is a binder, not `term`. Ticket 61 gave the top its word on the
%% DESCRIPTION channel and this narrows that to the description channel rather
%% than overturning it: `Fn(term)` binds a variable named `term`, which is not
%% what the word was chosen to mean.
%% F28 — ON THE PASTE CHANNEL A BINDER UNFOLDS, AND ITS BACK-REFERENCE BINDS.
%%
%% This is the one printer where the author's own type name is the WRONG answer
%% even though it is the most readable one: a head is a pattern, and `Tree` is
%% not a pattern. So a `mu` shows one unfolding — the shapes the author has to
%% write clauses for — and each `recvar` inside becomes an ordinary binder,
%% which is exactly what a hand-written clause does: `Size((:node, l, r))` binds
%% the two subtrees rather than spelling them out. One unfolding is also all
%% that terminates, and all that is useful: the next level is the same shapes
%% again.
hd_parts(#{mu := _} = T, Names, Pos) -> hd_parts(unfold(T), Names, Pos);
hd_parts(#{recvar := _}, _Names, _Pos) -> [binder("x")];
hd_parts(T = #{atoms := As, ints := Is, tuples := Ts, lists := Ls, maps := Ms,
               bins := Bs}, Names, Pos) ->
    case is_subtype(term(), T) of
        true  -> [binder("x")];
        false -> a_pat(As) ++ [i_pat(R, Pos) || R <- Is] ++ ts_hd(Ts, Names)
                     ++ l_pat(Ls, Names) ++ ms_hd(Ms, Names) ++ b_pat(Bs)
    end.

%% A finite atom set is already pattern syntax.
%%
%% THE TWO COFINITE CASES ARE NOT THE SAME SET AND DO NOT GET THE SAME ANSWER.
%% `{cofinite, []}` is EVERY atom, which a binder spells exactly; `{cofinite,
%% [:x]}` is every atom except `:x`, which no pattern spells at all. Collapsing
%% them turned a forty-one-head diagnostic into a wall of type notation — the
%% failure F29.9's description channel exists to prevent, produced by the
%% mechanism meant to prevent it. Measured 2026-08-27 against `Classify(int n,
%% atom a)`.
a_pat({finite, []})    -> [];
a_pat({finite, L})     -> [atom_str(A) || A <- L];
a_pat({cofinite, []})  -> [binder("a")];
a_pat({cofinite, _})   -> [].

%% TICKET 42'S SPELLING, which the parser has accepted since 2026-08-15 and
%% nothing ever emitted. The `int` prefix is a TYPE prefix and does not belong in
%% a pattern; `..` was refused by 42 on meaning — "borrow the construct, or don't
%% borrow the glyph" — so a bounded span is the conjunction of its two bounds.
%% A RELATIONAL PATTERN GOES WHERE A WHOLE ARGUMENT GOES, and nowhere else. The
%% compiler already says so — `Step((:ok, <= 0))` is refused with *"a relational
%% pattern goes where a whole argument goes ... write the comparison as a guard
%% there"* — and the printer was emitting the refused form. Measured 2026-08-27:
%% F29's own table recorded `TupleNested` as a `syntax:<=` row, which it is not;
%% it parses and is then refused on meaning, and the fix is the shape the
%% diagnostic itself recommends.
%%
%% So at argument position a span is ticket 42's pattern, and below it a span is
%% a binder plus a guard. Both spell the same set; only one of them is legal at
%% each site.
i_pat({neg_inf, pos_inf}, _Pos) -> binder("n");
%% A single integer is a LITERAL, and a literal is a pattern at every depth.
i_pat({Lo, Lo}, _Pos)           -> integer_to_list(Lo);
i_pat({neg_inf, Hi}, arg)       -> "<= " ++ integer_to_list(Hi);
i_pat({Lo, pos_inf}, arg)       -> ">= " ++ integer_to_list(Lo);
i_pat({Lo, Hi}, arg)            -> ">= " ++ integer_to_list(Lo) ++
                                       " and <= " ++ integer_to_list(Hi);
i_pat({neg_inf, Hi}, nested)    ->
    binder("n") ++ guard([?G_SELF] ++ " <= " ++ integer_to_list(Hi));
i_pat({Lo, pos_inf}, nested)    ->
    binder("n") ++ guard([?G_SELF] ++ " >= " ++ integer_to_list(Lo));
i_pat({Lo, Hi}, nested)         ->
    binder("n") ++ guard([?G_SELF] ++ " >= " ++ integer_to_list(Lo) ++
                             " and " ++ [?G_SELF] ++ " <= " ++ integer_to_list(Hi)).

%% A tuple component that is itself a union multiplies the head lines, which is
%% F29.2 one level down. `TupleNested` exists because a printer fixed only at the
%% top level leaves this row broken.
ts_hd(top, _Names) -> [binder("t")];
ts_hd(Ps, Names)   ->
    lists:append(
      [["(" ++ string:join(Combo, ", ") ++ ")"
        || Combo <- combos([hd_parts(C, Names, nested) || C <- P])] || P <- Ps]).

%% THE LIST PATH, which is where the hardest row of this feature lives. The
%% element printer below is `hd_parts/2` and not `to_string/1`; that one
%% substitution is the whole of `RecordInList`.
%% THE FOLD IS NOT INHERITED, AND THAT IS THE WHOLE OF THE `list<T>` CASE.
%%
%% `l_str/1` folds `[] | [T, ..]` back into `list<T>` so that an ordinary list
%% type does not READ like a residual. On the head channel the same fold is
%% harmful: it collapses two spines that each have a pattern into one that has
%% none, and that absence is what made a new grammar production look necessary.
%%
%% F29 §1 was recorded on 2026-08-27 to close exactly this gap — `pattern ->
%% lident '<' type_list '>' lident`, so that `Ship(list<Order> xs)` could be
%% written. IT IS NOT NEEDED AND IS NOT BUILT. §1's argument is *"a list pattern
%% constrains a prefix … nothing spells every element"*, which is a ONE-HEAD
%% argument; F29.2, in the same file, made a residual N heads. Once it is N
%% heads, `list<Order>` is the two heads the author actually writes:
%%
%%     Ship([]) -> ...
%%     Ship([Order o, ..]) -> ...
%%
%% Measured 2026-08-27: both are grammatical today, and pasted back together they
%% drive the residual to none. See F29 §1 and §2, corrected in place.
l_pat([], _Names) -> [];
l_pat(Ss0, Names) ->
    lists:append([sp_pat(S, Names) || S <- lists:sort(Ss0)]).

%% An OPEN spine with no known prefix is `[] | [T, ..]` — both halves, because
%% neither alone covers it. This is the decomposition the fold above hides.
sp_pat({[], closed}, _Names)      -> ["[]"];
sp_pat({[], {open, any}}, _Names) -> ["[]", "[" ++ binder("x") ++ ", ..]"];
sp_pat({[], {open, T}}, Names)    ->
    ["[]"] ++ ["[" ++ H ++ ", ..]" || H <- hd_parts(T, Names, nested)];
sp_pat({P, closed}, Names)        ->
    ["[" ++ string:join(C, ", ") ++ "]"
     || C <- combos([hd_parts(E, Names, nested) || E <- P])];
sp_pat({P, {open, _}}, Names)     ->
    ["[" ++ string:join(C, ", ") ++ ", ..]"
     || C <- combos([hd_parts(E, Names, nested) || E <- P])].

ms_hd(top, _Names)    -> [binder("m")];
ms_hd(Members, Names) -> [m_hd(M, Names) || M <- Members].

%% F22'S SPELLING WHERE THE NAME RESOLVES, and 26 §1's discriminator where it
%% does not. `bs_parser.yrl:499-501` says the hand-written minted tag "makes an
%% erasure detail load-bearing in source" — F22 exists to replace exactly this,
%% and shipped without reaching the printer.
%% A RESIDUAL HEAD FOR A DOMAIN MEMBER IS A PATTERN NOBODY CAN WRITE YET, and
%% printing a brace form here would hand the author a suggestion the parser
%% refuses — the failure mode ENG-312 names one constructor over. The type is
%% what can honestly be said, so a binder typed by it is what is offered.
m_hd({dom, K, V}, _Names) ->
    binder("m") ++ ": map<" ++ to_string(K) ++ ", " ++ to_string(V) ++ ">";
m_hd({_Kind, Fields}, Names) ->
    case maps:find('Kind', Fields) of
        {ok, #{atoms := {finite, [Tag]}, ints := [], tuples := [],
               lists := [], maps := [], bins := []}} ->
            case maps:find(Tag, Names) of
                {ok, Src} -> Src ++ " " ++ binder(initial(Src));
                error     -> "{ Kind: " ++ atom_str(Tag) ++ " }"
            end;
        _ ->
            Ks = lists:sort(maps:keys(Fields)),
            "{ " ++ string:join([atom_to_list(K) ++ ": _" || K <- Ks], ", ") ++ " }"
    end.

%% `string` and `binary` are type words and become binders for the same reason
%% `int` does. `binary \ string` has no surface spelling at all — `b_str/1` says
%% so in as many words — so it contributes no head.
b_pat([])            -> [];
b_pat([utf8])        -> [binder("s")];
b_pat([other, utf8]) -> [binder("b")];
b_pat([other])       -> [].

initial([C | _]) when C >= $A, C =< $Z -> [C + 32];
initial([C | _])                       -> [C];
initial([])                            -> "x".

%% ONE ARGUMENT LIST PER HEAD LINE. The expansion lives here rather than in
%% `bs_diag` so that the tuple case above and the argument case below cannot
%% drift: a residual nested in a tuple multiplies head lines for exactly the same
%% reason a residual argument does, and `TupleNested` is the fixture that would
%% catch them disagreeing.
head_combos(Tys, Names) -> combos([head_parts(T, Names) || T <- Tys]).

%% The cartesian product, in argument order, with the empty case preserved: a
%% component with NO head spelling kills the lines it would have appeared in
%% rather than producing a head with a hole in it.
combos([]) -> [[]];
combos([P | Rest]) ->
    [[X | C] || X <- P, C <- combos(Rest)].

%% ONE PASS OVER THE FINISHED LINE, because uniqueness is a property of the line
%% and the parts are built without reference to each other. The first binder with
%% a given base keeps it; the rest are numbered. `Kind(s)` reads better than
%% `Kind(s1)`, and a second `s` in the same head is `repeated_in_head`, so both
%% halves are load-bearing.
%% The guards are hoisted rather than printed in place, and joined with `and`
%% because a `when` clause takes one condition however many parts contributed to
%% it. They are appended here rather than by the caller so that a head is a
%% finished head the moment this returns.
name_binders(Line) ->
    {Text, Guards} = nb(lists:flatten(Line), [], [], "", []),
    case Guards of
        [] -> Text;
        _  -> Text ++ " when " ++ string:join(Guards, " and ")
    end.

nb([], _Used, Acc, _Last, Gs) -> {lists:reverse(Acc), lists:reverse(Gs)};
nb([?B_OPEN | Rest], Used, Acc, _Last, Gs) ->
    {Base, Tail} = lists:splitwith(fun(C) -> C =/= ?B_CLOSE end, Rest),
    Name = fresh(Base, Used),
    nb(tl(Tail), [Name | Used], lists:reverse(Name) ++ Acc, Name, Gs);
nb([?G_OPEN | Rest], Used, Acc, Last, Gs) ->
    {Cond, Tail} = lists:splitwith(fun(C) -> C =/= ?G_CLOSE end, Rest),
    nb(tl(Tail), Used, Acc, Last, [self_named(Cond, Last) | Gs]);
nb([C | Rest], Used, Acc, Last, Gs) -> nb(Rest, Used, [C | Acc], Last, Gs).

%% `?G_SELF` is "the binder this condition is about", resolved to the name that
%% binder was actually given — which is not known until the line is walked,
%% because a second `n` in the same head is numbered.
self_named(Cond, Last) ->
    lists:append([case C of ?G_SELF -> Last; _ -> [C] end || C <- Cond]).

fresh(Base, Used) ->
    case lists:member(Base, Used) of
        false -> Base;
        true  -> fresh_n(Base, Used, 2)
    end.

fresh_n(Base, Used, N) ->
    Try = Base ++ integer_to_list(N),
    case lists:member(Try, Used) of
        false -> Try;
        true  -> fresh_n(Base, Used, N + 1)
    end.

ms_pat(top)     -> ["map"];
ms_pat(Members) -> [m_pat(M) || M <- Members].

%% `to_pattern/1` DESCRIBES a set — it is the channel `ms_pat(top) -> ["map"]`
%% belongs to — so a domain member describes as the type the author wrote. It is
%% NOT the paste channel and must not carry a binder: `binder/1`'s delimiters are
%% control bytes that only `nb/5` removes, and `nb/5` runs on the head channel
%% alone. A binder here reaches the author as `( m)` with two invisible
%% characters around the name, which is what the first cut of this clause did.
m_pat({dom, K, V}) ->
    "map<" ++ to_string(K) ++ ", " ++ to_string(V) ++ ">";
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
