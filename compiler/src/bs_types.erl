%%% Types are disjunctive normal forms partitioned by constructor. Operations
%%% are componentwise except within tuple, map and list products. Union never
%%% widens: `erl_types` merges same-constructor unions, which is sound for
%%% success typing but would lose the residual a checker must prove empty.
%%% Integer intervals are in the algebra, so a guard such as `n > 1` is a type
%%% operation. Atoms use finite
%%% or cofinite sets to close the open universe under complement without a
%%% negation node.

-module(bs_types).

-export([none/0, term/0, atom_lit/1, atom_top/0, int/0, range/2, tuple/1]).
%% BEAM floats and integers occupy disjoint parts.
-export([float_lit/1, float_top/0]).
-export([key_str/1]).
-export([nil/0, cons/1, list/1]).
%% Callers query list properties through this API, not the spine shape.
-export([list_elem/1, has_lists/1, has_nil/1, has_cons/1, spine/2]).
%% Signature inference uses the union of types at a tuple position.
-export([tuple_comp/3]).
-export([binary_top/0, string/0]).
%% F60: a process, a reference and a port, opaque to the type language.
-export([opaque/1]).
%% F60: the compiler-known named views of the tuples OTP sends.
-export([views/0, is_view/1, view_of_tuple/1, view_parts/1]).
-export([map_closed/1, map_open/1, map_dom/2, is_dom/1]).
-export([fun_ty/2, arrows/1, funs_of/1]).
-export([union/2, union/1, intersect/2, subtract/2]).
-export([is_none/1, is_open/1, is_subtype/2, to_string/1, to_pattern/1,
         pattern_parts/1, atom_str/1]).
%% `head_parts/2` emits source; `to_pattern/1` describes a set.
-export([head_parts/2, head_combos/2, name_binders/1]).
%% Matchability and printing share a structured intermediate, not text.
-export([head_reach/1, guard_buckets/1, constituents/1]).
%% Validation requires heads that distinguish constituents, not just reach them.
-export([separable/2]).
%% The checker and emitter share the single BEAM membership test, when one
%% exists, so type-prefix refusals and guards agree.
-export([part_test/1]).
%% Readers must unfold recursive binders before accessing a part.
-export([mu/2, recvar/1, is_rec/1, unfold/1, rec_name/1, components/1]).

-export_type([ty/0]).

%% An atom part: every atom in the list, or every atom except those.
-type atom_part() :: {finite, [atom()]} | {cofinite, [atom()]}.

%% Float sets use exact head equality: `0.0` and `-0.0` are distinct. There are
%% no float intervals; guards add no refinement and exhaustiveness over `float`
%% requires a catch-all.
-type float_part() :: {finite, [float()]} | {cofinite, [float()]}.

%% An integer part: sorted, disjoint, non-adjacent inclusive ranges.
-type bound() :: integer() | neg_inf | pos_inf.
-type int_part() :: [{bound(), bound()}].

%% `top` includes every tuple arity, which no finite product list can express.
-type tuple_part() :: top | [[ty()]].

%% A spine is a typed prefix followed by a closed or homogeneous open tail:
%%   {P, closed}     exactly length(P) elements, with types from P
%%   {P, {open, T}}  at least length(P) elements; later elements have type T
%% `[]` is `{[], closed}`; an empty union admits no lists. `any` is a tail
%% marker that avoids recursion in `term()`. Prefixes hold real types; `e_ty/1`
%% expands the marker when a tail becomes an element.
%% Rationale: compiler/features/F20-list-length.md.
-type elem() :: none | any | ty().
-type rest() :: closed | {open, elem()}.
-type spine() :: {[ty()], rest()}.
-type list_part() :: [spine()].

%% Map members are closed field sets, open field constraints, or domain rules.
%% Closed members require exactly their fields; patterns are open, so naming a
%% record's `Kind` covers its other fields. Members are absorbed, not merged.
%% Domain rules constrain every key and value and exclude the `Kind` key. Their
%% 3-tuple shape keeps them out of named-field clauses matching 2-tuples;
%% domain rules have no finite key list for field-set operations.
%% Rationale: compiler/features/F33-map-type.md.
-type map_member() :: {closed | open, #{atom() => ty()}} | {dom, ty(), ty()}.
-type map_part() :: top | [map_member()].

%% Binaries are partitioned into valid UTF-8 (`utf8`) and the rest (`other`).
%% `string` is `[utf8]`; `binary` is `[other, utf8]`. The `[other]` residual
%% has no surface spelling but must remain distinct for exact subtraction.
%% Sizes belong to binary patterns, not type expressions.
-type bin_part() :: [utf8 | other].

%% F60: values with no structure a pattern can take apart, each decided by one
%% guard (`is_pid/1`, `is_port/1`, `is_reference/1`). Like `bins`, an ordset
%% of kinds; unlike it, every kind has a surface spelling.
-type opaque_part() :: [pid | port | reference].

%% Function containment is pairwise, with contravariant domains and covariant
%% codomains: each function has one arrow per arity, not an intersection.
%% Subtraction removes contained arrows and keeps others whole, conservatively
%% over-approximating residuals to avoid false exhaustiveness. `top` includes
%% all arities. A value narrowed by `is_function/1` can be held or returned but
%% cannot be called without a known domain.
%% Rationale: compiler/features/F46-function-as-a-value.md.
-type arrow() :: {[ty()], ty()}.
-type fun_part() :: top | [arrow()].

%% Erlang terms cannot be cyclic; binders encode cycles by name and `unfold/1`
%% closes them. Types are equirecursive: binder names do not affect equality,
%% and subtyping is decided coinductively.
%% Rationale: compiler/features/F28-recursive-types.md.
-type rec_ty() :: #{mu := atom(), body := ty()} | #{recvar := atom()}.

-type ty() :: #{atoms := atom_part(), ints := int_part(), floats := float_part(),
                tuples := tuple_part(), lists := list_part(), maps := map_part(),
                bins := bin_part(), opaques := opaque_part(), funs := fun_part()}
            | rec_ty().

%%% --- Constructors ---

none() -> #{atoms => {finite, []}, ints => [], floats => {finite, []},
            tuples => [], lists => [], maps => [], bins => [], opaques => [], funs => []}.

%%% --- Binders ---

%% Unused binders are removed so non-recursive aliases keep their body shape.
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

%% Unfold one step, never to a fixpoint. Repeated binders give finitely many
%% subtree pairs, allowing operation assumption sets to close the cycle.
unfold(#{mu := N, body := B} = M) -> subst_rec(B, N, M);
unfold(T)                         -> T.

%% `resolve/3` must bind every variable it introduces. Free variables are
%% compiler defects; treating them as empty would invalidate exhaustiveness.
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
                 end,
       funs   => case maps:get(funs, T) of
                     top -> top;
                     Fs  -> [{[subst_rec(D, N, Sub) || D <- Ds], subst_rec(C, N, Sub)}
                             || {Ds, C} <- Fs]
                 end}.

mentions(N, #{recvar := N2}) -> N =:= N2;
mentions(N, #{mu := N})      -> false;                       % shadowed
mentions(N, #{mu := _, body := B}) -> mentions(N, B);
mentions(N, T) ->
    lists:any(fun(C) -> mentions(N, C) end, components(T)).

%% Neither helper may descend into `any`: it is a tail marker, not a type.
sp_map(F, {P, closed})      -> {[F(C) || C <- P], closed};
sp_map(F, {P, {open, any}}) -> {[F(C) || C <- P], {open, any}};
sp_map(F, {P, {open, T}})   -> {[F(C) || C <- P], {open, F(T)}}.

sp_components({P, closed})      -> P;
sp_components({P, {open, any}}) -> P;
sp_components({P, {open, T}})   -> P ++ [T].

%% All component walks rely on this enumeration; include every nested type.
components(T) ->
    Ts = case maps:get(tuples, T) of top -> []; Ps -> lists:append(Ps) end,
    Ls = lists:append([sp_components(S) || S <- maps:get(lists, T)]),
    Ms = case maps:get(maps, T) of
             top -> [];
             %% Domain keys and values must survive the component walk.
             Fs  -> lists:append([case M of
                                      {dom, K, V} -> [K, V];
                                      {_, F}      -> maps:values(F)
                                  end || M <- Fs])
         end,
    Arrows = case maps:get(funs, T) of
                 top -> [];
                 As  -> lists:append([Ds ++ [C] || {Ds, C} <- As])
             end,
    Ts ++ Ls ++ Ms ++ Arrows.

%% Every part must be full for `term` to remain the top type.
term() ->
    #{atoms => {cofinite, []}, ints => [{neg_inf, pos_inf}], floats => {cofinite, []},
      tuples => top, lists => [{[], {open, any}}], maps => top,
      bins => [other, utf8], opaques => [pid, port, reference], funs => top}.

float_top() -> (none())#{floats => {cofinite, []}}.

float_lit(F) when is_float(F) -> (none())#{floats => {finite, [F]}}.

%% Empty domains or codomains do not empty an arrow: `fn(none) -> term` admits
%% every unary function; `fn(int) -> none` admits non-returning ones.
fun_ty(Doms, Cod) when is_list(Doms) -> (none())#{funs => [{Doms, Cod}]}.

arrows(T) ->
    case unfold(T) of
        #{funs := Fs} -> Fs;
        _             -> []
    end.

funs_of(T) -> (none())#{funs => arrows(T)}.

binary_top() -> (none())#{bins => [other, utf8]}.

string() -> (none())#{bins => [utf8]}.

opaque(K) when K =:= pid; K =:= port; K =:= reference -> (none())#{opaques => [K]}.

%%% --- Named views ---
%%%
%%% A view names the positions of a tuple the platform sends, after its tag.
%%% The type is the ordinary tuple; the names are read by the pattern walk, the
%%% projection and the printers. The table is the one source for all three.
%%% Rationale: compiler/features/F60-down-and-exit.md.
views() ->
    #{'Down' => {'DOWN', ['Ref', 'Type', 'Object', 'Reason']},
      'Exit' => {'EXIT', ['Pid', 'Reason']}}.

is_view(Name) -> maps:is_key(Name, views()).

%% What each part of a view is declared as, in position order. A printer names
%% only the parts a residual has narrowed below these. `bs_check:stratum_two/0`
%% declares the same types as source. A part declared narrower here than there
%% would print in a residual no clause narrowed it in, which F60.14 sees; one
%% declared wider would print nothing, and no test sees that direction.
view_parts('Down') ->
    [{'Ref', opaque(reference)},
     {'Type', union(atom_lit(process), atom_lit(port))},
     {'Object', union([opaque(pid), opaque(port), tuple([atom_top(), atom_top()])])},
     {'Reason', term()}];
view_parts('Exit') ->
    [{'Pid', opaque(pid)}, {'Reason', term()}].

%% The parts a value of the view has narrowed below their declared types.
narrowed(Name, Named) ->
    [{F, T} || {{F, T}, {F, D}} <- lists:zip(Named, view_parts(Name)),
               not is_subtype(D, T)].

%% A tuple product whose first component is exactly a view's tag, at the view's
%% arity, is that view.
view_of_tuple([Tag | Rest]) ->
    case Tag of
        #{atoms := {finite, [A]}, ints := [], floats := {finite, []}, tuples := [],
          lists := [], maps := [], bins := [], opaques := [], funs := []} ->
            case [{Name, Fields} || {Name, {T, Fields}} <- maps:to_list(views()),
                                    T =:= A, length(Fields) =:= length(Rest)] of
                [{Name, Fields}] -> {ok, Name, lists:zip(Fields, Rest)};
                []               -> none
            end;
        _ -> none
    end;
view_of_tuple(_) -> none.

atom_lit(A) when is_atom(A) -> (none())#{atoms => {finite, [A]}}.

atom_top() -> (none())#{atoms => {cofinite, []}}.

int() -> (none())#{ints => [{neg_inf, pos_inf}]}.

range(Lo, Hi) ->
    case r_empty({Lo, Hi}) of
        true  -> none();
        false -> (none())#{ints => [{Lo, Hi}]}
    end.

nil() -> (none())#{lists => [{[], closed}]}.

cons(T) ->
    case is_none(T) of
        true  -> none();
        false -> (none())#{lists => [{[T], {open, T}}]}
    end.

list(T) -> union(nil(), cons(T)).

list_elem(#{lists := Ss}) -> l_elem(Ss).

%% A pattern's written prefix bounds unfolding. A rest marker leaves the tail
%% unconstrained; it cannot inspect unwritten positions.
spine(Prefix, closed) when is_list(Prefix) -> mk_spine(Prefix, closed);
spine(Prefix, open)   when is_list(Prefix) -> mk_spine(Prefix, {open, any}).

mk_spine(Prefix, Rest) ->
    case lists:any(fun is_none/1, Prefix) of
        true  -> none();
        false -> (none())#{lists => [{Prefix, Rest}]}
    end.

has_lists(#{lists := Ss}) -> Ss =/= [].

has_nil(#{lists := Ss}) -> lists:any(fun({[], _}) -> true; (_) -> false end, Ss).

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

tuple_comp(T, N, I) ->
    case unfold(T) of
        #{tuples := top} -> term();
        #{tuples := Rows} ->
            union([lists:nth(I, Cs) || Cs <- Rows, is_list(Cs), length(Cs) =:= N]);
        _ -> none()
    end.

tuple(Components) when is_list(Components) ->
    case lists:any(fun is_none/1, Components) of
        true  -> none();          % a product with an empty factor is empty
        false -> (none())#{tuples => [Components]}
    end.

%% A declared record and a structural type with the same fields and tag are
%% equal; the minted tag is not nominal.
map_closed(Fields) -> map_member(closed, Fields).

map_open(Fields) -> map_member(open, Fields).

map_member(Kind, Fields) when is_map(Fields) ->
    case lists:any(fun is_none/1, maps:values(Fields)) of
        true  -> none();          % a field with an empty type admits no map
        false -> (none())#{maps => [{Kind, Fields}]}
    end.

%% The empty map inhabits every domain rule, even with empty K or V. Unlike
%% required named fields, empty key or value types do not empty it.
map_dom(K, V) -> (none())#{maps => [{dom, K, V}]}.

%% The checker refuses domain-map patterns based on the type.
is_dom(#{maps := Ms}) when is_list(Ms) ->
    lists:any(fun({dom, _, _}) -> true; (_) -> false end, Ms);
is_dom(_) -> false.

%%% --- Emptiness ---

%% Erlang map patterns are partial. The emptiness head must include every part,
%% or values in an omitted part would be falsely proved absent.
is_none(T) -> is_none(T, []).

%% Revisited binders are empty for finite-value inhabitation: recursion with no
%% base case admits no finite values.
is_none(#{mu := N} = M, Seen) ->
    lists:member(N, Seen) orelse is_none(unfold(M), [N | Seen]);
%% Bound variables use the emptiness hypothesis. Free variables stay inhabited
%% so a resolver defect cannot silently prove a type empty.
is_none(#{recvar := N}, Seen) ->
    lists:member(N, Seen);
%% Subtraction can leave assumption variables inside spines; decide their
%% emptiness here with the assumption chain, not with `sp_empty/1`. Arrows are
%% always inhabited, so the function part must be absent.
is_none(#{atoms := {finite, []}, ints := [], floats := {finite, []}, tuples := Ts,
          lists := Ls, maps := Ms, bins := [], opaques := [], funs := []}, Seen)
  when Ts =/= top, Ms =/= top ->
    lists:all(fun(Cs) -> lists:any(fun(C) -> is_none(C, Seen) end, Cs) end, Ts)
        andalso lists:all(fun(S) -> sp_none(S, Seen) end, Ls)
        andalso lists:all(fun(M) -> m_empty(M, Seen) end, Ms);
is_none(_, _) ->
    false.

%% An empty prefix admits `[]` regardless of the tail type.
sp_none({P, _}, Seen) -> lists:any(fun(C) -> is_none(C, Seen) end, P).

m_empty(M) -> m_empty(M, []).

%% The empty map inhabits every domain rule.
m_empty({dom, _K, _V}, _Seen) ->
    false;
m_empty({_Kind, Fields}, Seen) ->
    lists:any(fun(C) -> is_none(C, Seen) end, maps:values(Fields)).

is_subtype(A, B) -> is_none(subtract(A, B)).

%%% --- Openness ---
%%%
%%% Catch-alls require an open residual: one containing an unbounded top. The
%%% pattern must include all eight parts because map patterns are partial.
%%% `none()` is not open; callers requiring enumeration must first exclude it,
%%% as `bs_check:closed_and_inhabited/1` does.
is_open(#{atoms := As, ints := Is, floats := Fl, tuples := Ts, lists := Ls,
          maps := Ms, bins := Bs, opaques := Os, funs := Fs}) ->
    a_open(As) orelse lists:any(fun r_unbounded/1, Is) orelse t_open(Ts)
        orelse l_open(Ls) orelse m_open(Ms)
        %% Cofinite float sets cannot be enumerated.
        orelse a_open(Fl)
        %% Binary lengths are unbounded.
        orelse Bs =/= []
        %% No pattern names a particular process, reference or port.
        orelse Os =/= []
        %% No pattern enumerates the functions of a type.
        orelse Fs =/= [].

%% Cofinite atom sets cannot be enumerated in an unbounded atom universe.
a_open({cofinite, _}) -> true;
a_open({finite, _})   -> false.

r_unbounded({neg_inf, _}) -> true;
r_unbounded({_, pos_inf}) -> true;
r_unbounded({_, _})       -> false.

t_open(top) -> true;
t_open(Ps)  -> lists:any(fun(P) -> lists:any(fun is_open/1, P) end, Ps).

%% Spine openness requires an unbounded length or element type.
l_open(Ss) -> lists:any(fun sp_open/1, Ss).

sp_open({P, closed})     -> lists:any(fun is_open/1, P);
sp_open({P, {open, T}})  -> not e_none(T) orelse lists:any(fun is_open/1, P).

m_open(top) -> true;
%% Open members admit arbitrary extra fields.
m_open(Ms)  -> lists:any(fun({open, _}) -> true;
                            %% Domain rules are treated as open residuals.
                            ({dom, _, _}) -> true;
                            %% A record closes on its tag whatever its fields
                            %% hold: the tag names the case (ticket 101).
                            ({closed, Fs} = M) ->
                                discriminator(M) =:= none andalso
                                    lists:any(fun is_open/1, maps:values(Fs))
                         end, Ms).

%%% --- Union: exact, never widening ---

union([]) -> none();
union([T]) -> T;
union([H | T]) -> union(H, union(T)).

%% Idempotence must precede unfolding: bare recursive variables have no parts.
%% Union descends only through absorption, whose subtraction owns its
%% assumption set, so union needs no separate cycle check.
union(A, A) -> A;
union(A, B) -> u_parts(open_for(union, A, B), open_for(union, B, A)).

%% A bare recursive variable needs its binder; union cannot represent it beside
%% an unequal operand. Such operands are a caller defect.
open_for(_Op, #{mu := _} = T, _Other) -> unfold(T);
open_for(Op, #{recvar := N}, Other) ->
    erlang:error({free_recursive_variable, Op, N, Other});
open_for(_Op, T, _Other) -> T.

u_parts(A, B) ->
    #{atoms  => a_union(maps:get(atoms, A), maps:get(atoms, B)),
      ints   => i_union(maps:get(ints, A), maps:get(ints, B)),
      floats => fl_union(maps:get(floats, A), maps:get(floats, B)),
      %% Absorb contained products but keep overlapping ones separate: merging
      %% would widen the union.
      tuples => t_union(maps:get(tuples, A), maps:get(tuples, B)),
      lists  => l_union(maps:get(lists, A), maps:get(lists, B)),
      maps   => m_union(maps:get(maps, A), maps:get(maps, B)),
      %% `string` is nested within `binary`, so their union is `binary`.
      bins   => ordsets:union(maps:get(bins, A), maps:get(bins, B)),
      opaques => ordsets:union(maps:get(opaques, A), maps:get(opaques, B)),
      funs   => f_union(maps:get(funs, A), maps:get(funs, B))}.

%%% --- Recursive operation assumptions ---
%%
%% `As` records argument pairs and binder names. Regular trees have finitely
%% many subtree pairs, so revisiting a pair closes the cycle. Intersection and
%% subtraction return a binder on revisit, never `none`: assuming an empty
%% residual would falsely prove exhaustiveness. Only `is_none/2` may make the
%% emptiness assumption. Names are chain depths. Equal-depth binders occupy
%% disjoint siblings; nested shadowing is handled by `subst_rec/3`.
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

%% `BS_NO_TYPE_MEMO` disables cycle closure for the recursive-types gate's
%% self-test. Read it only when comparing recursive types.
assumed(Key, As) ->
    case os:getenv("BS_NO_TYPE_MEMO") of
        false -> lists:keyfind(Key, 1, As);
        _     -> false
    end.

%%% --- Intersection ---

intersect(A, B) -> intersect(A, B, []).

%% Idempotence comes first so a bare recursive variable need not be opened.
intersect(A, A, _As) -> A;
%% Keep undecidable free-variable intersections whole, over-approximating
%% rather than risking false exhaustiveness.
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
      floats => fl_intersect(maps:get(floats, A), maps:get(floats, B)),
      tuples => t_intersect(maps:get(tuples, A), maps:get(tuples, B), As),
      lists  => l_intersect(maps:get(lists, A), maps:get(lists, B), As),
      maps   => m_intersect(maps:get(maps, A), maps:get(maps, B), As),
      bins   => ordsets:intersection(maps:get(bins, A), maps:get(bins, B)),
      opaques => ordsets:intersection(maps:get(opaques, A), maps:get(opaques, B)),
      funs   => f_intersect(maps:get(funs, A), maps:get(funs, B), As)}.

%%% --- Subtraction ---

subtract(A, B) -> subtract(A, B, []).

%% Equality comes first so a bare recursive variable can subtract itself.
subtract(A, A, _As) -> none();
%% Unknown operands cannot prove anything removed; retain the whole minuend to
%% avoid false exhaustiveness.
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
      floats => fl_subtract(maps:get(floats, A), maps:get(floats, B)),
      tuples => t_subtract(maps:get(tuples, A), maps:get(tuples, B), As),
      lists  => l_subtract(maps:get(lists, A), maps:get(lists, B), As),
      maps   => m_subtract(maps:get(maps, A), maps:get(maps, B), As),
      bins   => ordsets:subtract(maps:get(bins, A), maps:get(bins, B)),
      opaques => ordsets:subtract(maps:get(opaques, A), maps:get(opaques, B)),
      funs   => f_subtract(maps:get(funs, A), maps:get(funs, B), As)}.

%%% --- Function part ---
%%%
%%% Arrows are absorbed, never merged. Intersection keeps only arrows contained
%%% by the other operand, under-approximating incomparable arrows. Patterns
%%% have no function part, so pattern intersection cannot reach this inexact
%%% case.

%% Domain contravariant, codomain covariant, arity equal.
f_sub({Ds1, C1}, {Ds2, C2}, As) when length(Ds1) =:= length(Ds2) ->
    lists:all(fun({D1, D2}) -> is_none(subtract(D2, D1, As)) end,
              lists:zip(Ds1, Ds2))
        andalso is_none(subtract(C1, C2, As));
f_sub(_, _, _) ->
    false.

f_union(top, _) -> top;
f_union(_, top) -> top;
f_union(A, B)   -> f_absorb(A ++ B).

f_absorb(Fs) ->
    lists:foldl(fun(F, Acc) ->
                        case lists:any(fun(G) -> f_sub(F, G, []) end, Acc) of
                            true  -> Acc;
                            false -> [G || G <- Acc, not f_sub(G, F, [])] ++ [F]
                        end
                end, [], Fs).

f_intersect(top, B, _As) -> B;
f_intersect(A, top, _As) -> A;
f_intersect(A, B, As) ->
    f_absorb([X || X <- A, lists:any(fun(Y) -> f_sub(X, Y, As) end, B)]
             ++ [Y || Y <- B, lists:any(fun(X) -> f_sub(Y, X, As) end, A)]).

%% Unrepresentable function residuals retain the minuend conservatively.
f_subtract(_, top, _As)  -> [];
f_subtract(top, _, _As)  -> top;
f_subtract(A, B, As) ->
    [X || X <- A, not lists:any(fun(Y) -> f_sub(X, Y, As) end, B)].

%%% --- Float part ---
%%%
%%% OTP 27+ head equality (`=:=`) distinguishes signed zeros. `ordsets` and
%%% `usort` use `==` and would merge them, so float sets need exact membership.
%%% Rationale: compiler/features/F51-float.md.

fl_union({finite, X},   {finite, Y})   -> {finite, fl_set(X ++ Y)};
fl_union({cofinite, X}, {cofinite, Y}) -> {cofinite, fl_meet(X, Y)};
fl_union({finite, X},   {cofinite, Y}) -> {cofinite, fl_minus(Y, X)};
fl_union(C = {cofinite, _}, F = {finite, _}) -> fl_union(F, C).

fl_intersect({finite, X},   {finite, Y})   -> {finite, fl_meet(X, Y)};
fl_intersect({cofinite, X}, {cofinite, Y}) -> {cofinite, fl_set(X ++ Y)};
fl_intersect({finite, X},   {cofinite, Y}) -> {finite, fl_minus(X, Y)};
fl_intersect(C = {cofinite, _}, F = {finite, _}) -> fl_intersect(F, C).

fl_subtract(A, {finite, X})   -> fl_intersect(A, {cofinite, fl_set(X)});
fl_subtract(A, {cofinite, X}) -> fl_intersect(A, {finite, fl_set(X)}).

%% Sort places signed zeros together; exact deduplication must keep both.
fl_set(L) -> fl_dedup(lists:sort(L)).

fl_dedup([A, B | T]) when A =:= B -> fl_dedup([B | T]);
fl_dedup([A | T])                 -> [A | fl_dedup(T)];
fl_dedup([])                      -> [].

fl_member(F, L) -> lists:any(fun(G) -> G =:= F end, L).

fl_meet(X, Y)  -> [F || F <- fl_set(X), fl_member(F, Y)].
fl_minus(X, Y) -> [F || F <- fl_set(X), not fl_member(F, Y)].

%%% --- Atom part ---

a_union({finite, X},   {finite, Y})   -> {finite, lists:usort(X ++ Y)};
a_union({cofinite, X}, {cofinite, Y}) -> {cofinite, ordsets:intersection(os(X), os(Y))};
a_union({finite, X},   {cofinite, Y}) -> {cofinite, ordsets:subtract(os(Y), os(X))};
a_union(C = {cofinite, _}, F = {finite, _}) -> a_union(F, C).

a_intersect({finite, X},   {finite, Y})   -> {finite, ordsets:intersection(os(X), os(Y))};
a_intersect({cofinite, X}, {cofinite, Y}) -> {cofinite, lists:usort(X ++ Y)};
a_intersect({finite, X},   {cofinite, Y}) -> {finite, ordsets:subtract(os(X), os(Y))};
a_intersect(C = {cofinite, _}, F = {finite, _}) -> a_intersect(F, C).

a_subtract(A, B) -> a_intersect(A, a_complement(B)).

a_complement({finite, X})   -> {cofinite, os(X)};
a_complement({cofinite, X}) -> {finite, os(X)}.

os(L) -> ordsets:from_list(L).

%%% --- Integer part: exact intervals ---

i_union(A, B) -> i_norm(A ++ B).

i_intersect(A, B) ->
    i_norm([R || X <- A, Y <- B, (R = r_meet(X, Y)) =/= empty]).

i_subtract(A, B) -> lists:foldl(fun(Y, Acc) -> i_norm(r_minus_all(Acc, Y)) end, A, B).

r_minus_all(Ranges, Y) -> lists:append([r_minus(X, Y) || X <- Ranges]).

%% Check disjointness first: overlapping-range subtraction would otherwise grow
%% a disjoint minuend beyond its bounds.
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

%% Adjacent ranges merge as well as overlapping ones.
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

%% neg_inf < every integer < pos_inf.
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

%%% --- Tuple part ---

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

%% Subtracting `top` is exact and must precede the conservative case. Other
%% residuals from `top` are unrepresentable and retain `top` to avoid false
%% exhaustiveness.
t_subtract(_, top, _Asm) -> [];
t_subtract(top, _, _Asm) -> top;
t_subtract(As, Bs, Asm) ->
    lists:foldl(fun(B, Acc) -> t_minus_all(Acc, B, Asm) end, As, Bs).

t_minus_all(As, B, Asm) ->
    t_absorb(lists:append([product_minus(A, B, Asm) || A <- As])).

%% Product subtraction is a disjoint union, not componentwise subtraction:
%%   ⋃ᵢ (A1∩B1) × … × (Aᵢ₋₁∩Bᵢ₋₁) × (Aᵢ\Bᵢ) × Aᵢ₊₁ × … × An
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

%% Keep a maximal antichain without merging products. Equal members must leave
%% exactly one representative; mutual absorption must not remove both.
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

%%% --- Map part ---
%%%
%%% Absorb members without merging; subtract products by field name. Different
%%% field sets are disjoint only when both maps fix their domain.

m_union(top, _) -> top;
m_union(_, top) -> top;
m_union(As, Bs) -> m_absorb(As ++ Bs).

m_intersect(top, Bs, _Asm) -> Bs;
m_intersect(As, top, _Asm) -> As;
m_intersect(As, Bs, Asm) ->
    m_absorb([M || A <- As, B <- Bs, (M = m_meet(A, B, Asm)) =/= empty]).

%% Subtracting `top` is exact and must precede the conservative case. Other
%% residuals from `top` are unrepresentable and retain `top`.
m_subtract(_, top, _Asm) -> [];
m_subtract(top, _, _Asm) -> top;
m_subtract(As, Bs, Asm) ->
    lists:foldl(fun(B, Acc) -> m_minus_all(Acc, B, Asm) end, As, Bs).

m_minus_all(As, B, Asm) ->
    m_absorb(lists:append([m_minus(A, B, Asm) || A <- As])).

%%% --- Meet ---
%%%
%%% Domain clauses precede named-field clauses to handle mixed pairs; a
%%% domain's 3-tuple cannot match the named-field 2-tuples.

m_meet({dom, KA, VA}, {dom, KB, VB}, Asm) ->
    m_check({dom, intersect(KA, KB, Asm), intersect(VA, VB, Asm)});
%% `fields_fit/5` excludes records from domain maps.
m_meet(A = {Kind, FA}, {dom, KB, VB}, Asm) when Kind =:= closed; Kind =:= open ->
    case fields_fit(Kind, FA, KB, VB, Asm) of
        true  -> m_check(A);
        false -> empty
    end;
m_meet(A = {dom, _, _}, B = {Kind, _}, Asm) when Kind =:= closed; Kind =:= open ->
    m_meet(B, A, Asm);

m_meet({closed, FA}, {closed, FB}, Asm) ->
    case same_keys(FA, FB) of
        true  -> m_check({closed, m_zip_intersect(FA, FB, Asm)});
        false -> empty
    end;
m_meet({closed, FA}, {open, FB}, Asm) ->
    case keys_subset(FB, FA) of
        true  -> m_check({closed, m_zip_intersect(FA, FB, Asm)});
        false -> empty
    end;
m_meet(A = {open, _}, B = {closed, _}, Asm) ->
    m_meet(B, A, Asm);
m_meet({open, FA}, {open, FB}, Asm) ->
    m_check({open, m_zip_intersect(FA, FB, Asm)}).

m_zip_intersect(FA, FB, Asm) ->
    maps:fold(fun(K, VB, Acc) ->
                      case maps:find(K, Acc) of
                          {ok, VA} -> Acc#{K => intersect(VA, VB, Asm)};
                          error    -> Acc#{K => VB}
                      end
              end, FA, FB).

m_check(M) -> case m_empty(M) of true -> empty; false -> M end.

%%% --- Subtraction ---

%% Decompose over the subtrahend's keys as `product_minus/3` does over
%% positions. Domain subtraction also decides subtyping; undecidable cells keep
%% the whole minuend to avoid false exhaustiveness.

%% Only containment can empty a domain rule; other differences are not
%% representable and retain the whole minuend.
m_minus({dom, KA, VA}, {dom, KB, VB}, Asm) ->
    case sub(KA, KB, Asm) andalso sub(VA, VB, Asm) of
        true  -> [];
        false -> [{dom, KA, VA}]
    end;
%% Records carry `Kind`, so they never satisfy a domain rule.
m_minus({closed, FA}, {dom, KB, VB}, Asm) ->
    case fields_fit(closed, FA, KB, VB, Asm) of
        true  -> [];
        false -> [{closed, FA}]
    end;
%% Open members admit unnamed keys outside the domain, including `Kind`; retain
%% them whole.
m_minus(A = {open, _}, {dom, _, _}, _Asm) ->
    [A];
%% Removing a named shape from a domain leaves an unrepresentable residual.
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
    %% The residual may require extra fields, which cannot be represented;
    %% retain the whole open member.
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

%%% --- Absorption ---

%% Distinct singleton tags cannot contain each other. Compare within a tag
%% group and against untagged members, which may contain any group.
m_absorb(Ms0) ->
    %% Deduplicate first: the containment check compares distinct members.
    Ms = lists:usort([M || M <- Ms0, not m_empty(M)]),
    Groups = maps:groups_from_list(fun discriminator/1, Ms),
    Untagged = maps:get(none, Groups, []),
    [M || M <- Ms,
          not lists:any(fun(N) -> N =/= M andalso m_subset(M, N) end,
                        rivals(M, Groups, Untagged, Ms))].

%% Only singleton `Kind` tags form groups. All other members must be compared
%% against every group.
discriminator({dom, _, _}) ->
    none;
discriminator({_Kind, Fields}) ->
    case maps:find('Kind', Fields) of
        {ok, #{atoms := {finite, [Tag]}, ints := [], floats := {finite, []},
               tuples := [], lists := [], maps := []}} -> Tag;
        _ -> none
    end.

rivals(M, Groups, Untagged, All) ->
    case discriminator(M) of
        none -> All;
        Tag  -> maps:get(Tag, Groups, []) ++ Untagged
    end.

%% Domain clauses come first so mixed pairs cannot reach named-field logic.
m_subset({dom, KP, VP}, {dom, KQ, VQ}) ->
    sub(KP, KQ, []) andalso sub(VP, VQ, []);
m_subset({Kind, FP}, {dom, KQ, VQ}) when Kind =:= closed; Kind =:= open ->
    fields_fit(Kind, FP, KQ, VQ, []);
%% A domain admits maps outside any finite named-field member.
m_subset({dom, _, _}, {_, _}) ->
    false;
m_subset({_, FP}, {open, FQ}) ->
    keys_subset(FQ, FP) andalso
        lists:all(fun(K) -> is_none(subtract(maps:get(K, FP), maps:get(K, FQ))) end,
                  maps:keys(FQ));
m_subset({closed, FP}, {closed, FQ}) ->
    same_keys(FP, FQ) andalso
        lists:all(fun(K) -> is_none(subtract(maps:get(K, FP), maps:get(K, FQ))) end,
                  maps:keys(FQ));
m_subset({open, _}, {closed, _}) ->
    false.

sub(A, B, Asm) -> is_none(subtract(A, B, Asm)).

%% Domain membership excludes `Kind` and requires every key and value to fit.
%% Open members cannot qualify: unnamed fields are unconstrained.
fields_fit(open, _Fields, _K, _V, _Asm) ->
    false;
fields_fit(closed, Fields, K, V, Asm) ->
    not maps:is_key('Kind', Fields) andalso
        lists:all(fun({Name, T}) ->
                          sub(key_type(Name), K, Asm) andalso sub(T, V, Asm)
                  end, maps:to_list(Fields)).

%% F58: a name key is its atom; a string key is valid UTF-8 by the lexer, and
%% the algebra has no singleton binary, so its type is `string`. Exact against
%% every key type a dictionary can declare: `string`, `binary` and `term` hold
%% it, and `atom` does not.
key_type(K) when is_atom(K)   -> atom_lit(K);
key_type(K) when is_binary(K) -> string().

same_keys(A, B) -> lists:sort(maps:keys(A)) =:= lists:sort(maps:keys(B)).

keys_subset(Sub, Sup) ->
    lists:all(fun(K) -> maps:is_key(K, Sup) end, maps:keys(Sub)).

%%% --- List part ---
%%%
%%% Lists decompose into head/tail products; residuals describe shapes, not
%%% measured lengths. `sp_grow/2` unfolds only to the subtrahend's written
%%% prefix length. Each nesting level has its own bound.

l_union(A, B) -> l_absorb(A ++ B).

l_intersect(A, B, Asm) ->
    l_absorb([S || X <- A, Y <- B, S <- sp_meet(X, Y, Asm)]).

l_subtract(A, B, Asm) ->
    l_absorb(lists:foldl(
               fun(Y, Acc) -> lists:append([sp_minus(X, Y, Asm) || X <- Acc]) end,
               A, B)).

sp_len({P, _}) -> length(P).

%% Unfolding preserves the set: exactly n elements or at least n+1.
%% Rationale: compiler/features/F20-list-length.md.
sp_unfold({P, {open, T}}) ->
    case e_none(T) of
        true  -> [{P, closed}];
        false -> [{P, closed}, {P ++ [e_ty(T)], {open, T}}]
    end.

%% Growing preserves the union: closed lengths n..L-1 and an open spine at L.
sp_grow(S = {P, closed}, _L) when is_list(P) -> [S];
sp_grow(S = {P, {open, _}}, L) when length(P) >= L -> [S];
sp_grow(S, L) -> lists:append([sp_grow(X, L) || X <- sp_unfold(S)]).

%%% --- Meet ---

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
    %% A shorter closed spine is disjoint from the longer spine; this base case
    %% terminates recursion when aligning prefixes.
    {Short, Long} = case sp_len(X) < sp_len(Y) of
                        true  -> {X, Y};
                        false -> {Y, X}
                    end,
    case Short of
        {_, closed} -> [];
        _ -> lists:append([sp_meet(S, Long, Asm) || S <- sp_grow(Short, sp_len(Long))])
    end.

%% An open rest includes the empty tail, so closed intersect open is closed.
rest_meet(closed, closed, _Asm)         -> closed;
rest_meet(closed, {open, _}, _Asm)      -> closed;
rest_meet({open, _}, closed, _Asm)      -> closed;
rest_meet({open, T1}, {open, T2}, Asm) ->
    case e_intersect(T1, T2, Asm) of
        none -> closed;   %% no later element is admissible: exactly this length
        T    -> {open, T}
    end.

%%% --- Difference ---

sp_minus(X, Y, Asm) ->
    N1 = sp_len(X), N2 = sp_len(Y),
    if
        N1 =:= N2 -> sp_minus_aligned(X, Y, Asm);
        N1 < N2 ->
            case X of
                %% X is shorter than every list in Y.
                {_, closed} -> [X];
                _ -> lists:append([sp_minus(S, Y, Asm) || S <- sp_grow(X, N2)])
            end;
        true ->
            case Y of
                %% Y is shorter than every list in X.
                {_, closed} -> [X];
                _ ->
                    %% Only the longest grown member can meet X; the closed
                    %% members shed during growth are shorter and disjoint.
                    [Y2] = [S || S <- sp_grow(Y, N1), sp_len(S) =:= N1],
                    sp_minus_aligned(X, Y2, Asm)
            end
    end.

%% Product subtraction treats the rest as one more column: either a prefix
%% element differs, or the entire prefix matches and the rest differs.
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

sp_rest_minus(_Meet, closed, closed)    -> [];
sp_rest_minus(_Meet, closed, {open, _}) -> [];
sp_rest_minus(Meet, {open, TA}, closed) ->
    %% Removing length n from lengths >= n leaves lengths >= n+1.
    case e_none(TA) of
        true  -> [];
        false -> [{Meet ++ [e_ty(TA)], {open, TA}}]
    end;
sp_rest_minus(Meet, {open, TA}, {open, TB}) ->
    case e_covers(TB, TA) of
        true  -> [];
        %% A tail with some element outside TB cannot be one spine. Keeping A
        %% under-subtracts and may report false inexhaustiveness. Pattern rests
        %% are closed or {open, any}; this case only compares declared types
        %% with incomparable element types.
        false -> [{Meet, {open, TA}}]
    end.

%%% --- Normalisation ---

l_absorb(Ss0) ->
    Ss = lists:usort([sp_norm(S) || S <- Ss0, not sp_empty(S)]),
    [S || S <- Ss, not lists:any(fun(Q) -> Q =/= S andalso sp_subset(S, Q) end, Ss)].

%% An empty open rest is closed; normalise it for sp_open/1 and equality.
sp_norm({P, {open, T}}) ->
    case e_none(T) of
        true  -> {P, closed};
        false -> {P, {open, T}}
    end;
sp_norm(S) -> S.

sp_empty({P, _}) -> lists:any(fun is_none/1, P).

%% Containment of computed types needs fresh assumptions, independent of the
%% descent that produced them. subtract/3 terminates its own cycles.
sp_subset(S, Q) -> [] =:= [X || X <- sp_minus(S, Q, []), not sp_empty(X)].

%% Keeping `any` as a tail marker prevents term() from recursing into itself.
%% Expansion at a prefix position is finite: term() keeps the tail marker.
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

%% Coverage is directional: B covers A.
e_covers(_, none)  -> true;
e_covers(none, _)  -> false;
e_covers(any, _)   -> true;
e_covers(_, any)   -> false;
e_covers(B, A)     -> is_none(subtract(A, B)).

l_str([]) -> [];
l_str(Ss0) ->
    %% Fold [] | [T, ..] into the ordinary list<T> description.
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

%%% --- Printing ---

%% Only the whole top prints as `term`; partial residuals stay enumerated. An
%% over-approximated representation may conservatively stay enumerated.
to_string(T) ->
    case is_none(T) of
        true  -> "none";
        false ->
            case is_subtype(term(), T) of
                true  -> "term";
                false -> string:join(parts(T), " | ")
            end
    end.

%%% Named recursive types print their names. Synthetic types print one
%%% unfolding with `...` at back-references, so printing terminates.
%%% Rationale: compiler/features/F28-recursive-types.md.
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
parts(#{atoms := As, ints := Is, floats := Fl, tuples := Ts, lists := Ls, maps := Ms,
        bins := Bs, opaques := Os, funs := Fs}) ->
    a_str(As) ++ [i_str(R) || R <- Is] ++ fl_str(Fl) ++ ts_str(Ts) ++ l_str(Ls)
        ++ ms_str(Ms) ++ b_str(Bs) ++ o_str(Os) ++ f_str(Fs).

%% F60: each opaque kind is spelled as its builtin name.
o_str(Os) -> [atom_to_list(O) || O <- Os].

%% The lexer accepts every shortest round-tripping spelling from
%% float_to_list/2.
fl_str({finite, []})   -> [];
fl_str({finite, L})    -> [float_str(F) || F <- L];
fl_str({cofinite, []}) -> ["float"];
fl_str({cofinite, L})  -> ["float \\ (" ++ string:join([float_str(F) || F <- L], " | ") ++ ")"].

float_str(F) -> float_to_list(F, [short]).

%% Function top has no keyword spelling; use its arrow, fn(none) -> term.
f_str(top) -> ["fn(none) -> term"];
f_str(Fs)  -> [arrow_str(F) || F <- Fs].

arrow_str({Ds, C}) ->
    "fn(" ++ string:join([to_string(D) || D <- Ds], ", ") ++ ") -> " ++ to_string(C).

%% `binary \ string` has no pattern spelling. No pattern distinguishes valid
%% UTF-8 from other binaries, so pattern subtraction cannot produce [other].
b_str([])            -> [];
b_str([utf8])        -> ["string"];
b_str([other, utf8]) -> ["binary"];
b_str([other])       -> ["binary \\ string"].

ms_str(top) -> ["map"];
ms_str(Members) -> [m_str(M) || M <- Members].

%% Print the Kind discriminator first. Domain maps have no brace pattern
%% spelling. Every member kind must render as source syntax.
m_str({dom, K, V}) ->
    "map<" ++ to_string(K) ++ ", " ++ to_string(V) ++ ">";
m_str({Kind, Fields}) ->
    Ks = case maps:is_key('Kind', Fields) of
             true  -> ['Kind' | lists:sort(maps:keys(maps:remove('Kind', Fields)))];
             false -> lists:sort(maps:keys(Fields))
         end,
    Printed = [key_str(K) ++ ": " ++ to_string(maps:get(K, Fields)) || K <- Ks],
    Tail = case Kind of open -> Printed ++ [".."]; closed -> Printed end,
    "{ " ++ string:join(Tail, ", ") ++ " }".

ts_str(top) -> ["tuple"];
ts_str(Ps)  -> [t_str(P) || P <- Ps].

%%% Record descriptions use the discriminator: field type names in pattern
%%% position would bind variables, potentially repeating a name.
to_pattern(T) ->
    case is_none(T) of
        true  -> "none";
        false -> string:join(pat_parts(T), " | ")
    end.

%% Return all parts unjoined: bsc truncates only inexhaustive-head diagnostics.
%% Other callers of to_pattern/1 require the complete description.
pattern_parts(T) ->
    case is_none(T) of
        true  -> ["none"];
        false -> pat_parts(T)
    end.

%% Describe the exact top as `term`; `_` is refused over closed residuals.
pat_parts(#{mu := N, body := B}) ->
    case synthetic(N) of
        false -> [atom_to_list(N)];
        true  -> pat_parts(B)
    end;
pat_parts(#{recvar := N}) -> [rec_str(N)];
pat_parts(T = #{atoms := As, ints := Is, floats := Fl, tuples := Ts, lists := Ls,
                maps := Ms, bins := Bs, opaques := Os, funs := Fs}) ->
    case is_subtype(term(), T) of
        true  -> ["term"];
        false -> a_str(As) ++ [i_str(R) || R <- Is] ++ fl_str(Fl) ++ ts_pat(Ts)
                     ++ l_str(Ls) ++ ms_pat(Ms) ++ b_str(Bs) ++ o_str(Os) ++ f_str(Fs)
    end.

ts_pat(top) -> ["tuple"];
ts_pat(Ps)  -> [case view_of_tuple(P) of
                   {ok, Name, Named} -> view_pat(Name, Named);
                   none -> "(" ++ string:join([to_pattern(C) || C <- P], ", ") ++ ")"
               end || P <- Ps].

%% F60: a view prints by name, naming only the parts narrower than `term`.
view_pat(Name, Named) ->
    case [atom_to_list(F) ++ ": " ++ to_pattern(T) || {F, T} <- narrowed(Name, Named)] of
        []    -> atom_to_list(Name) ++ " " ++ binder_initial(Name);
        Parts -> atom_to_list(Name) ++ " { " ++ string:join(Parts, ", ") ++ " }"
    end.

binder_initial(Name) -> initial(atom_to_list(Name)).

%%% --- Clause heads --- Head text must parse as patterns; to_pattern/1 only
%%% describes types. Unions produce separate heads, never a `|` inside one
%%% head. Unspellable patterns contribute no part, making `pasteable` absent.
%%% Binders carry delimiter bytes until name_binders/1 makes names unique
%%% across the complete head, avoiding repeated_in_head errors. `Names` maps
%%% record tags to names in scope at the error site; a tag's final segment does
%%% not establish that its source name is in scope.
%%% Rationale: compiler/features/F29-residual-prints-a-pattern.md.

-define(B_OPEN, 0).
-define(B_CLOSE, 1).
-define(G_OPEN, 2).
-define(G_CLOSE, 3).
-define(G_SELF, 4).

binder(Base) -> [?B_OPEN] ++ Base ++ [?B_CLOSE].

%% The condition belongs to the binder on its left. ?G_SELF resolves to that
%% binder's final name when the condition is hoisted into the head's guard.
guard(Cond) -> [?G_OPEN] ++ Cond ++ [?G_CLOSE].

%% Each part is a separate head; `none` contributes no head.
head_parts(T, Names) -> [Text || {_Kind, Text} <- head_kinds(T, Names, arg)].

%%% --- Structured head parts --- The printer renders text; reachability
%%% inspects kinds, never that text. shape: a structural or relational pattern
%%% that reaches the member. guarded: a binder with a condition that reaches
%%% the member. binder: distinguishes no values within its BEAM guard bucket.
%%% annotated: a typed binder with no legal pattern spelling (map<K, V>).

head_kinds(T, Names, Pos) ->
    case is_none(T) of
        true  -> [];
        false -> hd_parts(T, Names, Pos)
    end.

%% Query nested position: bounded ints use guarded binders there and relational
%% patterns at argument position; both reach the member. Record names are
%% irrelevant: named and discriminator forms are shapes.
head_reach(T) ->
    Kinds = [K || {K, _} <- head_kinds(T, #{}, nested)],
    case lists:any(fun(K) -> K =:= shape orelse K =:= guarded end, Kinds) of
        true  -> pattern;
        false ->
            case lists:member(binder, Kinds) of
                true  -> guard;
                false -> none
            end
    end.

%% Disjoint BEAM guard buckets can be distinguished without patterns. Requires
%% constituents/1 output with absent or inhabited buckets; this shallow check
%% cannot determine whether nested types are empty.
guard_buckets(#{mu := _} = T) -> guard_buckets(unfold(T));
guard_buckets(#{recvar := _}) -> [atom, int, float, tuple, list, map, bin, pid, port,
                                  reference, 'fun'];
guard_buckets(#{atoms := As, ints := Is, floats := Fl, tuples := Ts, lists := Ls,
                maps := Ms, bins := Bs, opaques := Os, funs := Fs}) ->
    [atom  || As =/= {finite, []}] ++
    [int   || Is =/= []] ++
    %% is_float/1 and is_integer/1 are disjoint BEAM guards.
    [float || Fl =/= {finite, []}] ++
    [tuple || Ts =/= []] ++
    [list  || Ls =/= []] ++
    [map   || Ms =/= []] ++
    [bin   || Bs =/= []] ++
    %% is_pid/1, is_port/1 and is_reference/1 are disjoint BEAM guards.
    Os ++
    %% is_function/2 distinguishes arities, not domain or return types;
    %% fun_info supplies identity, not types.
    case Fs of
        top -> ['fun'];
        _   -> lists:usort([{'fun', length(Ds)} || {Ds, _} <- Fs])
    end.

%%% --- Type-prefix membership test --- A type prefix requires one BEAM guard
%%% BIF that decides membership exactly. Unknown shapes refuse the prefix
%%% rather than admit extra values. New algebra parts require
%%% inhabited_parts/1, part_bif/1 and bs_emit's type_test/3 to agree, or an
%%% inhabited type can be reported empty.
%%% Rationale: compiler/features/F53-numeric-union-dispatch.md.

%% bs_check and bs_emit share this result for refusal and emitted tests.
%% Refusal reasons distinguish multiple parts, refinements and empty types. One
%% unfolding exposes the top-level parts of a contractive recursive type.
part_test(#{mu := _} = T) -> part_test(unfold(T));
%% A bare back-reference is meaningful only inside its recursive binder.
part_test(#{recvar := _}) -> {no, several_parts};
part_test(#{} = T) ->
    case inhabited_parts(T) of
        [{atoms, {cofinite, []}}]          -> {ok, is_atom};
        [{atoms, {finite, [false, true]}}] -> {ok, is_boolean};
        [{ints, [{neg_inf, pos_inf}]}]     -> {ok, is_integer};
        [{floats, {cofinite, []}}]         -> {ok, is_float};
        %% is_binary admits invalid UTF-8; no BEAM guard tests string exactly.
        [{bins, [other, utf8]}]            -> {ok, is_binary};
        [{opaques, [pid]}]                 -> {ok, is_pid};
        [{opaques, [port]}]                -> {ok, is_port};
        [{opaques, [reference]}]           -> {ok, is_reference};
        %% Two opaque kinds share no single guard.
        [{opaques, _}]                     -> {no, several_parts};
        [{lists, [{[], {open, any}}]}]     -> {ok, is_list};
        [{maps, top}]                      -> {ok, is_map};
        [{tuples, top}]                    -> {ok, is_tuple};
        [{funs, top}]                      -> {ok, is_function};
        []                                 -> {no, empty};
        %% Return the part's broader BIF so diagnostics can name its mismatch.
        [{Part, _}]                        -> {no, {narrower, part_bif(Part)}};
        [_ | _]                            -> {no, several_parts}
    end;
part_test(_) -> {no, several_parts}.

part_bif(atoms)  -> is_atom;
part_bif(ints)   -> is_integer;
part_bif(floats) -> is_float;
part_bif(bins)   -> is_binary;
part_bif(lists)  -> is_list;
part_bif(maps)   -> is_map;
part_bif(tuples) -> is_tuple;
part_bif(funs)   -> is_function.

inhabited_parts(#{atoms := As, ints := Is, floats := Fl, tuples := Ts,
                  lists := Ls, maps := Ms, bins := Bs, opaques := Os, funs := Fs}) ->
    [{atoms, As}  || As =/= {finite, []}] ++
    [{ints, Is}   || Is =/= []] ++
    [{floats, Fl} || Fl =/= {finite, []}] ++
    [{tuples, Ts} || Ts =/= []] ++
    [{lists, Ls}  || Ls =/= []] ++
    [{maps, Ms}   || Ms =/= []] ++
    [{bins, Bs}   || Bs =/= []] ++
    [{opaques, Os} || Os =/= []] ++
    [{funs, Fs}   || Fs =/= []].

%% Pairwise checks need normalised members after flattening and absorption, not
%% the unions as written. Keep mu whole; head_reach/1 unfolds it once.
constituents(#{mu := _} = T)     -> [T];
constituents(#{recvar := _} = T) -> [T];
constituents(#{atoms := As, ints := Is, floats := Fl, tuples := Ts, lists := Ls,
               maps := Ms, bins := Bs, opaques := Os, funs := Fs}) ->
    N = none(),
    [N#{atoms => As} || As =/= {finite, []}]
        ++ [N#{ints => [R]} || R <- Is]
        ++ [N#{floats => Fl} || Fl =/= {finite, []}]
        ++ part_cs(Ts, fun(V) -> N#{tuples => V} end)
        ++ [N#{lists => [S]} || S <- Ls]
        ++ part_cs(Ms, fun(V) -> N#{maps => V} end)
        ++ [N#{bins => Bs} || Bs =/= []]
        ++ [N#{opaques => [O]} || O <- Os]
        ++ part_cs(Fs, fun(V) -> N#{funs => V} end).

%% top is one constituent, not a member list.
part_cs(top, Mk) -> [Mk(top)];
part_cs(Ps, Mk)  -> [Mk([P]) || P <- Ps].

%% ValidateAs<T> requires separation, not merely reachability. Within a shared
%% guard bucket, one separable tuple slot, list position or map key suffices.
%% Unmodelled pairs return true and under-refuse: recursive binders and named
%% fields beside domains. Both inputs must come from constituents/1.
separable(A, B) ->
    case is_rec(A) orelse is_rec(B) of
        true ->
            true;
        false ->
            Bs = guard_buckets(B),
            case [X || X <- guard_buckets(A), lists:member(X, Bs)] of
                []           -> true;
                [Shared | _] -> same_bucket(Shared, A, B)
            end
    end.

%% Disjoint atom sets and integer ranges separate by literals or comparisons.
same_bucket(atom, A, B) ->
    is_none(intersect(A, B));
same_bucket(int, A, B) ->
    is_none(intersect(A, B));
same_bucket(float, A, B) ->
    is_none(intersect(A, B));
same_bucket(tuple, #{tuples := [P]}, #{tuples := [Q]}) ->
    length(P) =/= length(Q)
        orelse lists:any(fun({X, Y}) -> parts_separable(X, Y) end,
                         lists:zip(P, Q));
same_bucket(list, #{lists := [S]}, #{lists := [R]}) ->
    spines_separable(S, R);
same_bucket(map, #{maps := [M]}, #{maps := [N]}) ->
    maps_separable(M, N);
%% Guards cannot distinguish UTF-8 validity or same-arity arrow types. A top
%% part includes every neighbour in its bucket.
same_bucket(_, _, _) ->
    false.

%% Check positions in either prefix against the other's prefix or tail. Beyond
%% a closed spine, none separates disjoint lengths.
spines_separable({P, _} = S, {Q, _} = R) ->
    lists:any(fun(I) -> parts_separable(elem_at(S, I), elem_at(R, I)) end,
              lists:seq(1, max(length(P), length(Q)))).

elem_at({P, _}, I) when I =< length(P) -> lists:nth(I, P);
elem_at({_, closed}, _)                -> none();
elem_at({_, {open, none}}, _)          -> none();
elem_at({_, {open, T}}, _)             -> e_ty(T).

%% Domains and fieldless maps share the empty map. Kind separates named maps
%% from domains, which exclude it. Other named-field/domain pairs are
%% unmodelled and return true.
maps_separable({dom, _, _}, {dom, _, _}) ->
    false;
maps_separable({dom, _, _}, {_, Fs}) ->
    map_size(Fs) > 0;
maps_separable({_, Fs}, {dom, _, _}) ->
    map_size(Fs) > 0;
maps_separable({KA, FA}, {KB, FB}) ->
    lacks(FA, KB, FB) orelse lacks(FB, KA, FA)
        orelse lists:any(fun(K) -> parts_separable(maps:get(K, FA),
                                                   maps:get(K, FB))
                         end,
                         [K || K <- maps:keys(FA), maps:is_key(K, FB)]).

%% A required key absent from a closed neighbour separates the maps. An open
%% neighbour may carry any key.
lacks(Fs, closed, Other) ->
    lists:any(fun(K) -> not maps:is_key(K, Other) end, maps:keys(Fs));
lacks(_, open, _) ->
    false.

%% Separation requires every constituent pair to separate.
parts_separable(X, Y) ->
    Ys = constituents(Y),
    lists:all(fun(A) -> lists:all(fun(B) -> separable(A, B) end, Ys) end,
              constituents(X)).

%% Top prints as a binder: `term` in a pattern is merely a variable name.
%% Recursive types unfold once; repeats and back-references become binders.
%% Seen must track mu names because unfold/1 reinserts the whole binder, which
%% would otherwise unfold forever.
hd_parts(T, Names, Pos) -> hd_parts(T, Names, Pos, []).

hd_parts(#{mu := N} = T, Names, Pos, Seen) ->
    case lists:member(N, Seen) of
        true  -> [{binder, binder("x")}];
        false -> hd_parts(unfold(T), Names, Pos, [N | Seen])
    end;
hd_parts(#{recvar := _}, _Names, _Pos, _Seen) -> [{binder, binder("x")}];
hd_parts(T = #{atoms := As, ints := Is, floats := Fl, tuples := Ts, lists := Ls,
               maps := Ms, bins := Bs, opaques := Os, funs := Fs}, Names, Pos, Seen) ->
    case is_subtype(term(), T) of
        true  -> [{binder, binder("x")}];
        false -> a_pat(As) ++ [i_pat(R, Pos) || R <- Is] ++ fl_pat(Fl)
                     ++ ts_hd(Ts, Names, Seen) ++ l_pat(Ls, Names, Seen)
                     ++ ms_hd(Ms, Names) ++ b_pat(Bs) ++ o_pat(Os) ++ f_pat(Fs)
    end.

%% F60: no literal names a process, reference or port; a head binds one.
o_pat([]) -> [];
o_pat(_)  -> [{binder, binder("p")}].

%% Float literals work at every depth; all floats use a binder, while a
%% cofinite set excluding literals has no head spelling.
fl_pat({finite, []})   -> [];
fl_pat({finite, L})    -> [{shape, float_str(F)} || F <- L];
fl_pat({cofinite, []}) -> [{binder, binder("f")}];
fl_pat({cofinite, _})  -> [].

%% Arrow types have no pattern spelling; heads bind them.
f_pat([]) -> [];
f_pat(_)  -> [{binder, binder("f")}].

%% Composite tuples and list spines are shapes regardless of component kinds.
texts(Parts) -> [Text || {_Kind, Text} <- Parts].

%% All atoms can use a binder; atoms excluding literals have no pattern.
a_pat({finite, []})    -> [];
a_pat({finite, L})     -> [{shape, atom_str(A)} || A <- L];
a_pat({cofinite, []})  -> [{binder, binder("a")}];
a_pat({cofinite, _})   -> [].

%% Relational patterns are legal only as whole arguments. Nested integer spans
%% require a binder and guard; type notation is not pattern syntax.
i_pat({neg_inf, pos_inf}, _Pos) -> {binder, binder("n")};
%% Integer literals are legal patterns at every depth.
i_pat({Lo, Lo}, _Pos)           -> {shape, integer_to_list(Lo)};
i_pat({neg_inf, Hi}, arg)       -> {shape, "<= " ++ integer_to_list(Hi)};
i_pat({Lo, pos_inf}, arg)       -> {shape, ">= " ++ integer_to_list(Lo)};
i_pat({Lo, Hi}, arg)            -> {shape, ">= " ++ integer_to_list(Lo) ++
                                        " and <= " ++ integer_to_list(Hi)};
%% Nested bounds must be guarded, not bare binders: head_reach/1 relies on this
%% kind to recognise separable refined ints inside tuples.
i_pat({neg_inf, Hi}, nested)    ->
    {guarded, binder("n") ++ guard([?G_SELF] ++ " <= " ++ integer_to_list(Hi))};
i_pat({Lo, pos_inf}, nested)    ->
    {guarded, binder("n") ++ guard([?G_SELF] ++ " >= " ++ integer_to_list(Lo))};
i_pat({Lo, Hi}, nested)         ->
    {guarded, binder("n") ++ guard([?G_SELF] ++ " >= " ++ integer_to_list(Lo) ++
                                       " and " ++ [?G_SELF] ++ " <= " ++
                                       integer_to_list(Hi))}.

%% Unions inside tuple components also multiply head lines.
ts_hd(top, _Names, _Seen) -> [{binder, binder("t")}];
ts_hd(Ps, Names, Seen)    ->
    lists:append(
      [case view_of_tuple(P) of
           {ok, Name, Named} -> view_hd(Name, Named, Names, Seen);
           none ->
               [{shape, "(" ++ string:join(Combo, ", ") ++ ")"}
                || Combo <- combos([texts(hd_parts(C, Names, nested, Seen)) || C <- P])]
       end || P <- Ps]).

%% F60: a view's head names only the parts the residual narrowed, so a clause
%% pasted from it reads as the handler it completes.
view_hd(Name, Named, Names, Seen) ->
    N = atom_to_list(Name),
    case narrowed(Name, Named) of
        [] -> [{shape, N ++ " " ++ binder(initial(N))}];
        Narrow ->
            [{shape, N ++ " { " ++ string:join([atom_to_list(F) ++ ": " ++ C
                                                 || {{F, _}, C} <- lists:zip(Narrow, Combo)],
                                                ", ") ++ " }"}
             || Combo <- combos([texts(hd_parts(T, Names, nested, Seen))
                                 || {_, T} <- Narrow])]
    end.

%% Heads keep [] and [T, ..] separate: list<T> is not a pattern. Elements use
%% hd_parts so nested records render as patterns, not types.
l_pat([], _Names, _Seen) -> [];
l_pat(Ss0, Names, Seen)  ->
    lists:append([sp_pat(S, Names, Seen) || S <- lists:sort(Ss0)]).

%% An empty-prefix open spine needs both [] and nonempty heads for coverage.
sp_pat({[], closed}, _Names, _Seen)      -> [{shape, "[]"}];
sp_pat({[], {open, any}}, _Names, _Seen) ->
    [{shape, "[]"}, {shape, "[" ++ binder("x") ++ ", ..]"}];
sp_pat({[], {open, T}}, Names, Seen)     ->
    [{shape, "[]"}] ++
        [{shape, "[" ++ H ++ ", ..]"}
         || H <- texts(hd_parts(T, Names, nested, Seen))];
sp_pat({P, closed}, Names, Seen)         ->
    [{shape, "[" ++ string:join(C, ", ") ++ "]"}
     || C <- combos([texts(hd_parts(E, Names, nested, Seen)) || E <- P])];
sp_pat({P, {open, _}}, Names, Seen)      ->
    [{shape, "[" ++ string:join(C, ", ") ++ ", ..]"}
     || C <- combos([texts(hd_parts(E, Names, nested, Seen)) || E <- P])].

ms_hd(top, _Names)    -> [{binder, binder("m")}];
ms_hd(Members, Names) -> [m_hd(M, Names) || M <- Members].

%% Prefer an in-scope record name; otherwise use its Kind discriminator. Domain
%% maps yield annotated binders, which have no legal clause head.
m_hd({dom, K, V}, _Names) ->
    {annotated,
     binder("m") ++ ": map<" ++ to_string(K) ++ ", " ++ to_string(V) ++ ">"};
m_hd({_Kind, Fields}, Names) ->
    case maps:find('Kind', Fields) of
        {ok, #{atoms := {finite, [Tag]}, ints := [], floats := {finite, []},
               tuples := [], lists := [], maps := [], bins := [], opaques := []}} ->
            case maps:find(Tag, Names) of
                {ok, Src} -> {shape, Src ++ " " ++ binder(initial(Src))};
                error     -> {shape, "{ Kind: " ++ atom_str(Tag) ++ " }"}
            end;
        _ ->
            Ks = lists:sort(maps:keys(Fields)),
            {shape, "{ " ++ string:join([key_str(K) ++ ": _" || K <- Ks],
                                        ", ") ++ " }"}
    end.

%% string and binary need binders; binary minus string has no pattern.
b_pat([])            -> [];
b_pat([utf8])        -> [{binder, binder("s")}];
b_pat([other, utf8]) -> [{binder, binder("b")}];
b_pat([other])       -> [].

initial([C | _]) when C >= $A, C =< $Z -> [C + 32];
initial([C | _])                       -> [C];
initial([])                            -> "x".

%% Tuple components and arguments share the same head expansion.
head_combos(Tys, Names) -> combos([head_parts(T, Names) || T <- Tys]).

%% Preserve argument order. A component with no head spelling removes every
%% combination containing it; never emit a head with a hole.
combos([]) -> [[]];
combos([P | Rest]) ->
    [[X | C] || X <- P, C <- combos(Rest)].

%% Assign unique binder names after assembling the whole line; duplicate names
%% cause repeated_in_head. Keep the first base name, number repeats. Hoist all
%% conditions into one when clause joined with and.
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

%% Resolve ?G_SELF only after its binder has received a unique name.
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

%% Descriptions must not contain binder control bytes: only nb/5 removes those
%% delimiters, and it runs exclusively on the head channel.
m_pat({dom, K, V}) ->
    "map<" ++ to_string(K) ++ ", " ++ to_string(V) ++ ">";
m_pat({_Kind, Fields}) ->
    case maps:find('Kind', Fields) of
        %% Require an empty binary part so a Kind union containing string
        %% cannot collapse to a bare atom tag.
        {ok, #{atoms := {finite, [Tag]}, ints := [], floats := {finite, []},
               tuples := [], lists := [], maps := [], bins := [], opaques := []}} ->
            "{ Kind: " ++ atom_str(Tag) ++ " }";
        _ ->
            Ks = lists:sort(maps:keys(Fields)),
            "{ " ++ string:join([key_str(K) ++ ": _" || K <- Ks], ", ") ++ " }"
    end.

a_str({finite, []})   -> [];
a_str({finite, L})    -> [atom_str(A) || A <- L];
a_str({cofinite, []}) -> ["atom"];
a_str({cofinite, L})  -> ["atom \\ (" ++ string:join([atom_str(A) || A <- L], " | ") ++ ")"].

%% Quote atoms the bare sigil cannot spell so generated heads lex correctly:
%% :'Shop.Invoice' is valid; :Shop.Invoice is not.
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

t_str(P) ->
    case view_of_tuple(P) of
        {ok, Name, Named} ->
            %% The whole view prints as its name; a narrowed one by its parts.
            case [atom_to_list(F) ++ ": " ++ to_string(T) || {F, T} <- narrowed(Name, Named)] of
                []    -> atom_to_list(Name);
                Parts -> atom_to_list(Name) ++ " { " ++ string:join(Parts, ", ") ++ " }"
            end;
        none -> "(" ++ string:join([to_string(C) || C <- P], ", ") ++ ")"
    end.

%% F58: a field key as it is written. A name prints bare; a string key prints
%% as its literal, quoted, with `"` and `\` escaped as the lexer reads them.
key_str(K) when is_atom(K) -> atom_to_list(K);
key_str(K) when is_binary(K) ->
    [$" | lists:flatmap(fun($") -> "\\\"";
                           ($\\) -> "\\\\";
                           (C) -> [C] end,
                        unicode:characters_to_list(K))] ++ [$"].
