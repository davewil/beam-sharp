# 09 — Does beam-sharp need recursive types, and what is the cheapest defensible point?

Research against [ticket 09](../issues/09-union-representation.md) §3, which decided equirecursive
types with coinductive subtyping on theory-coherence grounds. Touches
[11](../issues/11-type-system-shape.md) (which inherits the decision and its cost),
[20](../issues/20-untheorised-term-shapes.md) (exactness), [27](../issues/27-parametric-polymorphism.md)
(parametric aliases, which made recursive aliases the natural thing to write), and
`LANGUAGE.md` §18 (bootstrapping).

**Ticket 09's decision is not re-opened by this file.** Where the evidence pushes against it, the
recommendation is recorded in [Amendments](#amendments-ticket-09-and-11-should-take) for the map to
take or decline.

| Mark | Meaning |
|---|---|
| **doc** | Official documentation, reference manual, standard text, or the designers' own writing |
| **src** | Source code of the implementation |
| **local** | Observed directly on this machine |
| **preprint** | Not peer-reviewed. **Source [5] (Etylizer) is `arXiv:2603.22032v1`, marked on its own pages "DRAFT PAPER UNDER REVIEW", 23 March 2026.** Every [5] claim in this file carries that caveat, including the 2%-timeout figure, which is the number most likely to be quoted downstream. Source [2] is published (*Programming* 8(2), 2024) but was read as the extended arXiv version. |

Pinned for this file: **OTP 28.5**, **Elixir 1.19.5**, **Gleam 1.18.1**, beam-sharp at `833ba0a`.

---

## The three answers, first

**1. No program in this repo needs a recursive type, and the theory does not require one either —
but the language already has one, and it is `term`.**

Zero of the 25a/25b/25c exemplar types are recursive; the deepest is one level
(`record CreateOrder { Lines: list<Line> }`) [L1]. The only JSON contact is `Json.Encode(body)`
in `25a/encode_response.bs`, where `body` is a `term` and the call is opaque — David's summary is
**confirmed, not refuted** [L1]. And the theory-coherence pressure ticket 09 cited is weaker than
it stated: Frisch, Castagna and Benzaken define types over a **finite signature** and obtain
recursion by reading terms of that signature as *potentially infinite regular trees* [1]; Castagna's
own summary of what makes the theory hard is that *"the circularity which our bootstrapping
technique addresses comes only from the combination of arrow types, recursive types and Boolean
connectives"* [1]. **beam-sharp has no arrow in its algebra**, so with no recursion either, the
circularity that makes semantic subtyping difficult does not arise at all.

What is true is the other half, and ticket 09 did not say it: `bs_types:term/0` is already a
μ-type. Measured [L2]:

```
term()            = atom | int | tuple | list<term> | map | binary
list<term> <: term         = true
term \ list<term>          = atom | int | tuple | [term, ..] | map | binary
```

That first line *is* `term = μX. atom | int | tuple | list<X> | map | binary`, printed by the
checker's own `to_string/1`. It is held not with a μ-binder but with three saturating sentinels —
`lists => {true, any}`, `tuples => top`, `maps => top` (`bs_types.erl:47,56,116`) — whose comment
says so outright: *"`any` exists so `term()` can contain lists without recursing into itself."*
The sentinel is a coinductive assumption discharged by saturation instead of by a memo table, and
the third line above is the price: `term \ list<term>` should be `atom | int | tuple | map | binary`
and instead keeps `[term, ..]`, a residual that is too **big**.

**So beam-sharp does not sit at "no recursion". It sits at "one built-in recursive type,
over-approximated".** That is a different, and much better, starting position than ticket 09
assumed.

**2. Closing the gap is not "add a case" — it is a new inhabitant of a six-key closed map that the
module's own comments twice warn fails *silently* when a component is forgotten.**

`type_env/1` (`bs_check.erl:565`) eagerly pre-resolves every ground alias to a finite `ty()`; there
is no reference node, no laziness, no sharing. `resolve/3`'s `Seen` chain is threaded *verbatim*
through `t_tuple`, `t_map` and `t_generic` arguments, so **passing through a type constructor does
not reset it** — which means the guard cannot distinguish contractive recursion from a degenerate
cycle, and today it does not. Measured [L3]: `type Tree = (int, list<Tree>)` and `type X = X | int`
produce the **identical** diagnostic. Ticket 09's well-formedness rule is exactly the distinction
the current guard erases. Full cost inventory in [Part 2](#part-2--what-the-decided-but-unbuilt-gap-costs).

**3. Both intermediate points are worse for this language than they look — one is closed outright,
the other trades away the exactness ticket 20 spent itself buying.**

- **Nominal recursion** — recursion through a named constructor, equality by name, no coinduction —
  is what Gleam, OCaml, Haskell and Rust do, and it is why they pay almost nothing. Ticket 09 §1
  abolished nominal types, so it is **not available here**. Gleam is the sharp case: it **allows** a
  recursive custom type and **refuses** a recursive type *alias* with *"This type alias is defined
  in terms of itself… it would expand forever in a loop"* [3][L4] — the same position beam-sharp is
  in, in almost the same words, except Gleam has the escape hatch beam-sharp deliberately removed.
- **Depth-limited widening** — unfold *n* times then widen to top — is what Dialyzer does
  (`?REC_TYPE_LIMIT` = **2**, then `t_any()`) [4], and it is why recursive `-type` has been usable
  on this platform since 2010 without anyone paying for a memo table. It works because widening
  yields a supertype, which is the residual-too-big direction `l_subtract` already commits to. What
  it costs is **exactness**: the residual stops being exact at the widening frontier, and whether a
  given clause set reaches past that frontier is a per-type, per-clause-set property that nothing
  measures (§3.3).

So the choice is: refuse; buy recursion cheaply and give up the exact residual; or pay for the memo
table. **The cheapest defensible move is none of the three — it is to keep refusing and split the
refusal in two**, so that a legal `Tree` gets a *"not implemented yet"* diagnostic and `X = X | int`
gets a *"this is not a type"* one. That is roughly ten lines in `resolve/3`, adds nothing to the
algebra, is correct forever, and it fixes the thing [L3] just measured: the language currently tells
an author who wrote something legal the same thing it tells an author who wrote nonsense. **Nothing
in the corpus is waiting on the fork, so buying the answer now is buying it before the question
exists.**

---

## SUPERSEDED IN PART — the recommendation was built, 2026-08-18

**This file's own recommendation — "stay at point 1b, but split the refusal" — is now in the
compiler**, so every claim below that the guard *cannot* tell contractive recursion from degenerate
recursion has stopped being true. The analysis is left standing rather than rewritten, because it
was accurate when measured and it is the reasoning that produced the change.

What is now different, and where the file still says otherwise (§2.1, the point-0 row in §3, and
the claim→source table's last row):

* `resolve/3` threads a `'$ctor'` marker, pushed when the walk descends through a **tuple**, a
  **`list<T>`** or a **record field's closed map**, and *not* through a union or a refinement.
  `seen/2` asks whether a marker lies between the head of the chain and the name it has met again.
* Two error terms, not one: `{cyclic_type, N}` for a definition that is not contractive, and
  `{recursive_type, N}` for one that is. The messages say, respectively, that this is *not* a
  missing feature and that it *is* one.
* The old message's *"has no representation in the checker's algebra **yet**"* — quoted below as
  applying to both cases — now applies only to the contractive one.

**What is NOT changed:** the language still has no recursive types, `term` is still a μ-type held
by saturating sentinels, and subtracting `list<term>` from `term` still wrongly keeps `[term, ..]`.
Points 2–5 of the curve are all still unoccupied. This was a diagnostic split, not an
implementation.

---

## Part 1 — Is the theory pressure real?

### 1.1 The signature is finite; recursion is how you read it

FCB08 introduces recursion as a reading of the grammar, not as a constructor in it [1, §"Types"]:

> "In order to simplify the presentation of recursive types, we are going to consider potentially
> infinite regular terms produced by the following signature: `t ::= b | t×t | t→t | t∨t | ¬t | 0`.
> By regular, we mean that terms have only but a finite number of different sub-terms."

Schimpf, Wehr and Bieniusa state the same thing as a one-line switch [5, §3.1]:

> "To allow for recursive types, the definition of monomorphic types `t` is to be read
> coinductively. Hence, a monomorphic type is a potentially infinite tree."

Their grammar carries the annotation inline: `Mono types t,u ::= t∨t | ¬t | t→t (coinductive) | t×t
| α | b` [5, Fig. 5].

**Read the same grammar inductively and you have a set-theoretic type system without recursion.**
The model, the extensional interpretation, subtyping-as-emptiness (`s ≤ t ⟺ s\t ≃ 0`), unions,
intersections and negations are all unchanged. Nothing in the construction needs the coinductive
reading; the coinductive reading is what *buys* recursion.

### 1.2 The hard part of the theory is the interaction, and beam-sharp has already dropped half of it

Frisch's own account of where the difficulty comes from [1, §"Related work"]:

> "The circularity which our bootstrapping technique addresses comes only from the combination of
> arrow types, recursive types and Boolean connectives. … Simpler solutions could have been
> possible, e.g. by stratifying the type algebra so as to avoid any interaction between arrow types
> and existing XDuce types."

`bs_types:ty()` has six components — atoms, ints, tuples, lists, maps, binaries — and **no arrow
part**. `LANGUAGE.md` §9 says so in the language's own voice: *"there is no arrow in the type
algebra"*. So one of the three ingredients of the circularity is already absent by construction.
Adding recursion re-introduces one of the other two, but not the interaction that makes the
bootstrapping technique necessary in the first place.

### 1.3 Recursion is not free even in the meta-theory

Two obligations that only exist because of recursion, and neither appears in ticket 09:

- **Well-foundedness.** FCB08 §4.3 exists solely because recursive types can denote sets no finite
  value inhabits: *"let us consider the recursive type `t = t×t`. … To build such a value, we would
  need to consider an infinite tree, which is ruled out. As a consequence, the type `t` contains no
  value."* [1]. `t = t×t` is *contractive* and still empty. A contractiveness check is therefore
  necessary and not sufficient.
- **Regularity, which ticket 09 does not mention at all.** FCB08 §5.4: *"The proof of decidability
  (Section 6.9) essentially relies on three components: (i) the regularity of types, (ii) some
  algebraic properties of universal models, and (iii) the equivalence between subtyping and type
  emptiness problems"* [1]. Etylizer states the same, split from contractiveness [5, §3.1]:
  *"Regularity requires that a tree contains only finitely many distinct subtrees. This condition
  is crucial for establishing decidability of the subtyping algorithm. Contractiveness states that
  every infinite branch has infinitely many occurrences of the type constructors → and ×. This
  condition rules out nonsensical types fulfilling equations such as `t = t∨t` or `t = ¬t`."*

Ticket 09's contractiveness rule ("recursion must pass through a type constructor") is **exactly
right and correctly attributed** — it matches Etylizer's definition word for word. Regularity is
the condition it omits, and it is the one decidability hangs on.

### 1.4 The corpus: nothing needs one

Every type declared across the three exemplars, read in full [L1]:

| File | Declarations | Recursive? |
|---|---|---|
| `25a/index.bs` | `Method`, `Response`, `record CreateOrder { …, Lines: list<Line> }`, `record Line` | no — one level |
| `25b/index.bs` | `Opcode`, `record Frame`, `Decoded`, `DecodeError` | no |
| `25c/index.bs` | `FrameType`, `record Frame`, `record Delivery`, `record OrderPlaced`, `FrameError`, `MethodError`, `ConsumeError`, `Disposition` | no |

`ValidateAs<CreateOrder>` (25a) and `ValidateAs<OrderPlaced>` (25c) are the codegen obligations
`fog.md` flags as owing a measurement "over a recursive type" — but **neither of the two types they
are actually generated over is recursive**, so nothing in the corpus forces the recursive
`ValidateAs` case either.

The single JSON contact is `EncodeResponse((status, body)) -> (status, Json.Encode(body))`, with
`type Response = (int, term)`. The argument is a `term`; the call is a foreign path call resolved
by F11. **No `Json` type is written anywhere, and none is needed** — which is the whole reason
ticket 09's own motivating example (`type Json = …`) is not in the corpus.

---

## Part 2 — What the decided-but-unbuilt gap costs

### 2.1 What the checker does today, exactly

`bs_check.erl:744`:

```erlang
seen(N, Seen) ->
    case lists:member(N, Seen) of
        false -> ok;
        true  -> erlang:error({cyclic_type, N})
    end.
```

Called from `resolve({t_ref, N}, Env, Seen)` (line 652) and `resolve({t_generic, N, Args}, …)`
(line 680). The chain is extended only when *entering an alias body* (`[N | Seen]`), and it is
passed **unchanged** into `t_tuple` components (line 661), `t_map` field types (line 666),
`list<T>` arguments (line 672), union members (line 695) and refinement bases (line 701).

**Nothing resets it on crossing a constructor, so contractive and degenerate recursion are the same
event.** Verified [L3] — the two cases print the same message, via `bsc.erl:778`:

```
$ bsc /tmp/bs_a/tree.bs            # type Tree = (int, list<Tree>)
error: the type Tree is defined in terms of itself
  a recursive type has no representation in the checker's algebra
  yet, so it is refused rather than expanded forever.

$ bsc /tmp/bs_b/degen.bs           # type X = X | int
error: the type X is defined in terms of itself
  a recursive type has no representation in the checker's algebra
  yet, so it is refused rather than expanded forever.
```

The second message is correct and permanent. The first is correct *today* and describes a missing
feature as if it were the author's mistake. The F6 note in `features/README.md` says the guard
shipped "with the feature that made the hazard reachable rather than with the one that finally
implements recursion", which is honest — but the diagnostic does not carry that distinction, and
the local probe is what makes it visible.

### 2.2 The concrete work to close it

Ordered by risk, not by size.

1. **A new inhabitant of `ty()`.** `-type ty() :: #{atoms := …, ints := …, tuples := …, lists := …,
   maps := …, bins := …}` (`bs_types.erl:99`) is a six-key closed map. A μ-variable or named
   back-edge is a seventh shape, and **the module warns twice, in capitals, that a forgotten
   component fails silently rather than loudly**: `is_none/1` (line 186) matches all six keys and an
   unhandled shape falls to `is_none(_) -> false`; `is_open/1` (line 225) has the same six-key head
   with the same caveat. Every head that destructures a `ty()` must be audited: `is_none/1`,
   `is_open/1`, `union/2`, `intersect/2`, `subtract/2`, `to_string/1`, `to_pattern/1`,
   `pattern_parts/1`.
2. **`is_none/1` becomes a fixpoint with an assumption set.** Today it returns immediately. It is
   the inner loop of `is_subtype/2`, which is the inner loop of the exhaustiveness residual — the
   loop the 1.3–1.9 µs/clause benchmark measures. Coinduction means: on re-entering an in-progress
   emptiness goal, **assume it holds** (greatest fixpoint) rather than recursing. FCB08 describes
   the same object under the name *simulation* [1, §6.9]: *"a type is equivalent to 0 if and only
   if there exists a simulation containing it (in that case, the simulation represents a co-inductive
   proof of its emptiness)"*, terminating because *"a branch cannot be infinite because the
   algorithm will only consider the normal forms in `N(A)` which is a finite set"* — where
   `N(A) = P(P(A) × P(A))` over the atoms of the goal. **The search space is doubly exponential in
   the number of atoms; regularity is the only thing bounding it.**
3. **`type_env/1`'s eager `maps:map(… resolve(T, Env))` must become lazy or graph-building.** A
   recursive alias cannot be pre-resolved to a finite term, and the environment is already
   heterogeneous (parametric entries stay as surface templates) — so the shape of the fix exists,
   but it changes what "an entry in `Env`" means for the third time.
4. **`to_string/1` must print the alias name or diverge — and ticket 09 §1 says the name "never
   participates in the type algebra".** This is the tension worth surfacing: the residual *is* the
   diagnostic (ticket 04), so a recursive residual must be printable, and the only finite printing
   of a μ-type is the binder's name. `to_string(term())` already does a one-level unfold and stops
   at the `any` sentinel [L2]; a general μ-type has no sentinel to stop at. **09 did not cost this,
   and it is not fatal — but "the name is only a display device" and "the printer needs the name to
   terminate" are the same sentence read twice.**
5. **Downstream consumers.** 09 §4's discriminability check, 12 §2's openness check (`is_open/1` —
   is a μ-type "open"? its unfolding is unbounded, so probably yes, and that decides whether `_` is
   legal over it), and `ValidateAs<T>` codegen, which over a recursive type must emit a **named
   recursive function** rather than an inlined traversal. `fog.md` already owes that measurement
   and ticket 16 §4's serialisation encoder stacks on the same type.

### 2.3 The measurement that was taken is not evidence about the case that hurts

`fog.md` records the 40-clause benchmark as **PAID**: linear, 59 µs at 40 clauses, *"there is no
cliff where ticket 04 feared one"*. That benchmark ran with no recursive types in the algebra —
there could not have been any.

Etylizer's published pathology names the combination, not the clause count [5, §4.4]:

> "In total, for 2% of the functions in the whole case study, Etylizer could not type check a
> function and exceeded the timeout limit of 5 minutes. Most of these functions perform recursive
> transformations on deeply nested, recursively defined types, **such as the types for the Erlang
> AST**, which results in case expressions with over 40 branches. Improving performance for such
> functions is a key challenge in advancing the state of the art of set-theoretic types further."

Two things follow. **The 40-branch number ticket 04 carried is half the shape** — it is recursive
types *times* 40 branches, on an independent implementation, in 2026. And the named instance is a
compiler AST, which is `LANGUAGE.md` §18's bootstrapping question written as a type. The
"no cliff" result stands for what it measured and says nothing about this.

---

## Part 3 — The curve, and who is standing on it

| # | Position | Occupant | What it costs |
|---|---|---|---|
| 0 | Refuse every self-reference, contractive or not | **beam-sharp today** [L3]; Gleam's *alias* form [3][L4] | nothing |
| 1 | Recursion only through built-in constructors, held as a saturating top | **beam-sharp today, in fact** (`any`/`top`) [L2]; Elixir 1.19.5 `Descr` (`:term`) [L5] | already paid; residual too big |
| 2 | Recursion only through a **nominal** constructor; equality by name | Gleam custom types [3][L4]; ML/Haskell/Rust ADTs | near zero — **unavailable here** |
| 3 | Equirecursive, **depth-limited**, widen to top past *n* unfoldings | **Dialyzer**: `?REC_TYPE_LIMIT = 2` → `t_any()` [4] | cheap — **costs exactness, per-type and unmeasured** |
| 4 | Coinductive memo table **plus** a hard depth backstop | **TypeScript**: `maybeKeysSet` → `Ternary.Maybe`, cutoff at depth 100 [6] | the memo table, plus a bailout error |
| 5 | Full coinductive simulation over regular types, no cutoff | **CDuce** [1]; **Etylizer** [5] | ticket 09's decision; 5-min timeouts on 2% of a real corpus [5] |

### 3.1 Point 1 is where the language actually is, and it is load-bearing

Elixir is the strongest comparison because it is Castagna's own group doing this on the same VM.
**The theory has recursive types; the shipped implementation does not.** The Elixir paper's grammar
says *"Types are defined coinductively (for type recursion) and, as customary in semantic subtyping,
they are contractive (no infinite unions or negations) and regular"* [2, §3]. But
`Module.Types.Descr` in 1.19.5 has no μ, no fixpoint and no back-reference in its entire exported
surface, and a descr is a plain finite Elixir term [L5]:

```elixir
Descr.list(Descr.integer())   #=> %{list: {%{bitmap: 4}, %{bitmap: 2}}, bitmap: 2}
Descr.term()                  #=> :term
```

Hand-unfolding a recursive type does not converge [L5]:

```
j1 = nil|int ∪ list(j0);  j2 = nil|int ∪ list(j1);  j3 = nil|int ∪ list(j2)
equal?(j1, j2) => false     equal?(j2, j3) => false
to_quoted_string(j3) => "nil or integer() or list(nil or integer() or list(nil or integer() or list(nil or integer())))"
```

Each unfolding is a strictly larger finite term; there is no fixpoint reachable by iteration. The
only saturating value in the representation is `:term` — **the same trick as beam-sharp's `any`,
arrived at independently on the same platform by the people who wrote the theory.** Elixir's own
docs do not mention recursive types at all [7]; the roadmap runs inference → typed structs → typed
signatures, and typespecs *"will be phased out"* [7]. A recursive `@type json ::` compiles clean in
1.19.5 [L5] because the checker does not read typespecs, not because it handles the recursion.

**This is the single most load-bearing fact in the file**: the group that owns the theory shipped
the same approximation beam-sharp shipped, and has not yet paid for the general case.

### 3.2 Point 2 is closed by ticket 09 §1

Gleam allows `pub type Tree { Leaf Node(Tree, Int, Tree) }` and rejects `pub type Tree =
Result(#(Tree, Int, Tree), Nil)` with *"Type cycle … This type alias is defined in terms of itself
… If we tried to compile this recursive type it would expand forever in a loop, and we'd never get
the final type"* [3][L4]. Confirmed locally on 1.18.1; the error is `TypeError::RecursiveTypeAlias`
in `compiler-core/src/error.rs` [3].

Read that against `bsc.erl:778` and the convergence is close to verbatim. **The difference is that
Gleam's refusal costs nothing, because the constructor form is right there.** beam-sharp refuses the
alias and has no constructor form to refuse *toward*: ticket 09 §1 made every name an alias by
design, so the position Gleam occupies is not a position this language can reach without undoing
its own headline decision.

### 3.3 Point 3 is cheap and real, and what it costs here is exactness

Dialyzer's mechanism, read from OTP 28.5 source [4]:

```erlang
-define(REC_TYPE_LIMIT, 2).       %% erl_types.erl:236
-define(RECUR_EXPAND_LIMIT, 10).  %% erl_types.erl:4563
-define(RECUR_EXPAND_DEPTH, 2).   %% erl_types.erl:4564

can_unfold_more(TypeName, TypeNames) ->
  Fun = fun(E, Acc) -> case E of TypeName -> Acc + 1; _ -> Acc end end,
  lists:foldl(Fun, 0, TypeNames) < ?REC_TYPE_LIMIT.

t_limit_k(_, K) when K =< 0 -> ?any;
```

A named type unfolds **twice** along one chain and is then replaced by `any()`. The direction is
documented as an invariant at `t_limit/2` — *"`Res` must be strictly more general than `Term`"* —
so the widening always yields a **supertype**. That is exactly right for success typing, and it is
why recursive `-type` has been usable since OTP R13B04 [4] without anyone paying for a memo table.

**What it costs here is exactness, and the size of the loss is not knowable per-language — it is
per-type.**

The exhaustiveness residual is `t \ (Acc(p₁) | … | Acc(pₙ))`. Widening `t` upward makes the residual
bigger — a **false inexhaustive**, the safe direction, and the direction `l_subtract`'s own comment
already commits to (*"leaves the residual too BIG rather than too small, and a residual that is too
big reports a false inexhaustive rather than a false exhaustive"*, `bs_types.erl:643–654`).

**It does not automatically fail, and the first draft of this section claimed it did.** Widening is
applied by `resolve/3`, which is the single funnel both the declared type and the clause patterns go
through — so both sides of the subtraction are widened at the same depth and tend to agree. Worked
through: `type Tree = (int, list<Tree>)` at `?REC_TYPE_LIMIT = 2` resolves to
`(int, list<(int, list<term>)>)`; the pair `Sum((n, []))` / `Sum((n, [h, ..t]))` then subtracts to
empty exactly as it should. [L2] shows why — `e_covers(any, _) -> true`, so a pattern that reaches
the saturating top covers it exactly rather than approximately.

What is lost is **ticket 20's headline**: the residual is no longer exact, and where it stops being
exact depends on how deep the patterns reach relative to where the type was cut. A clause set that
inspects *past* the widening frontier gets a residual that is too big and undischargeable; one that
stops at or before it is fine. **That is a per-type, per-clause-set property, and nothing measures
it** — which is a poor thing to build an exhaustiveness guarantee on, but it is not the same as the
mechanism being unusable. Dialyzer never has to know the difference, because it reports success
typings rather than coverage.

The strong form — *"depth limiting makes every function over a recursive type unwritable"* — is
recorded as an unproven hypothesis in [Where the evidence is thin](#where-the-evidence-is-thin),
with the cheap falsification test.

### 3.4 Point 4 is what shipping point 5 actually looks like

TypeScript is the data point for "full coinduction plus a bailout". `recursiveTypeRelatedTo` in
`checker.ts` carries the assumption set explicitly [6]:

```ts
// If source and target are already being compared, consider them related with assumptions
if (maybeKeysSet.has(id)) {
    return Ternary.Maybe;
}
…
if (sourceDepth === 100 || targetDepth === 100) { overflow = true; return Ternary.False; }
```

That is the memo table (`maybeKeysSet` → `Ternary.Maybe`, resolved on unwind) with a hard depth
cutoff as a backstop, and a separate instantiation budget of depth 100 / 5,000,000 raising
*"Type instantiation is excessively deep and possibly infinite"* [6]. Recursive type aliases have
been permitted in more positions since TypeScript 4.1 [6]. **The cutoff is not the mechanism; it is
the thing that keeps a pathological input from hanging the compiler** — the same role
`compiler/features/README.md` records for F6's `Seen` guard, and the same lesson (*"a hang is
invisible to a green suite"*).

So point 4 is not cheaper than point 5. It is point 5 with an error message.

### 3.5 The recommendation

**Stay at point 0/1, and split the refusal.**

Concretely: thread one extra bit through `resolve/3` recording whether a type constructor has been
crossed since the alias was entered, and branch `seen/2` on it.

- **crossed = false** → `{degenerate_type, N}`. `type X = X | int` is not a type. Permanent,
  correct forever, and it is ticket 09 §3's well-formedness rule finally executable rather than
  argued.
- **crossed = true** → `{recursive_type_unsupported, N}`, naming the feature rather than the
  author's code, and pointing at this file.

That is roughly ten lines, adds no node to the algebra, no case to any operation on it, and no cost
to the exhaustiveness loop. It is the same shape as F6 itself — the guard that shipped with the
feature that made the hazard reachable — and it closes the honesty gap [L3] measured.

**Then do nothing further until something demands it**, and let the demand pick the point rather
than picking it now. If what arrives is a `Json`-shaped document type — shallow patterns, shallow
type — point 3 is probably enough and costs a flag. If what arrives is bootstrapping, the residual
has to be exact over a compiler AST, which is point 5 — and point 5 over a compiler AST is the exact
input Etylizer publishes a five-minute timeout for [5]. **The two triggers want different answers,
one of which is known to be slow, so committing to either before the trigger is known is the
expensive move** — the same reversibility argument ticket 11 §3 made when it chose arity-and-trust
over contract wrapping.

---

## What would change the answer

In rough order of likelihood.

1. **Bootstrapping.** `LANGUAGE.md` §18 lists *"how much of B# is written in B#"* as open. A
   compiler written in B# has an AST, and an AST is the canonical recursive type. This is also the
   *precise* shape Etylizer times out on — *"deeply nested, recursively defined types, such as the
   types for the Erlang AST … case expressions with over 40 branches"* [5]. **If bootstrapping goes
   past the front end, recursion is not optional and the cost is measured elsewhere at five
   minutes per function.**
2. **A user writes `type Json`.** Ticket 09 §3's own example. Nothing in the corpus does, but the
   moment a program models a document, a config tree, or a nested map, the alias mechanism refuses
   it and there is no constructor form to fall back to (§3.2). This is the most likely *user*
   trigger and it arrives without warning.
3. **`ValidateAs<T>` over a recursive `T`.** `fog.md` already books this measurement. It is
   currently unreachable: neither `CreateOrder` nor `OrderPlaced` is recursive [L1]. If it becomes
   reachable it needs both the type *and* a named recursive generated function.
4. **Ticket 16 §4's serialisation encoder over the same recursive type.** `fog.md` says measure them
   together. Same precondition.
5. **`stream<T>` / laziness** (`LANGUAGE.md` §18, "deferred, not refused"). A stream type is
   recursive by construction.
6. **An arrow entering the algebra.** Ticket 37's polymorphic function signatures need `fn(T) -> U`.
   Arrows alone do not need recursion — but arrows *plus* recursion *plus* Boolean connectives is
   exactly the circularity FCB08's bootstrapping technique exists to address [1]. **If both land,
   the theory gets materially harder at once, and that is an ordering constraint worth recording
   now.**

---

## Claim → source

| Claim | Mark | Source |
|---|---|---|
| FCB08's types are potentially infinite **regular** terms over a finite signature | doc | [1] §"Types": *"In order to simplify the presentation of recursive types, we are going to consider potentially infinite regular terms produced by the following signature"* |
| The circularity semantic subtyping's bootstrapping addresses comes from arrows + recursion + connectives, not from recursion alone | doc | [1] §"Related work" |
| Decidability relies on regularity of types, algebraic properties of universal models, and subtyping ≡ emptiness | doc | [1] §5.4 |
| Emptiness is decided by a *simulation* = a coinductive proof; termination is by the finiteness of `N(A) = P(P(A)×P(A))` | doc | [1] §5.4, §6.9 |
| `t = t×t` is contractive and still empty; recursion forces a separate well-foundedness criterion | doc | [1] §4.3 |
| Reading the type grammar coinductively is *how* recursion is admitted | doc *(preprint)* | [5] §3.1: *"To allow for recursive types, the definition of monomorphic types t is to be read coinductively"* |
| Contractiveness = every infinite branch has infinitely many constructor occurrences; rules out `t = t∨t`, `t = ¬t` | doc *(preprint)* | [5] §3.1 — matches ticket 09 §3's rule exactly |
| Regularity = finitely many distinct subtrees; *"crucial for establishing decidability"* | doc *(preprint)* | [5] §3.1 — **ticket 09 does not state this condition** |
| Etylizer times out (>5 min) on 2% of functions; the pathology is recursive AST types × 40+ branches | doc *(preprint)* | [5] §4.4 |
| Etylizer is the first set-theoretic implementation independent of CDuce; all prior ones supporting corecursive types build on CDuce | doc *(preprint)* | [5] §1 |
| Elixir's *theory* has recursive types: coinductive, contractive, regular | doc | [2] §3 |
| Elixir 1.19.5's `Module.Types.Descr` has **no** recursion/μ/fixpoint node in its exported surface | local | [L5] |
| A descr is a finite term; hand-unfolding a recursive type does not converge | local | [L5] |
| Elixir's only saturating value is `:term`; official docs never mention recursive types; roadmap is inference → structs → signatures; typespecs will be phased out | doc + local | [7], [L5] |
| Dialyzer allows recursive `-type` since OTP R13B04 (Dialyzer 2.2.0, "experimental") | doc | [4] release notes |
| Dialyzer unfolds a named type at most `?REC_TYPE_LIMIT` = 2 times, then widens to `any()` | src | [4] `erl_types.erl:236`, `can_unfold_more/2` |
| Dialyzer's widening is guaranteed to yield a supertype (`"Res must be strictly more general than Term"`) | src | [4] `erl_types.erl` `t_limit/2` |
| Dialyzer's cache is result memoisation for expansion cost, not an equirecursive representation | src | [4] `cache_key`/`cache_find`/`cache_put` |
| Gleam permits a recursive **custom type** and rejects a recursive **type alias** | src + local | [3] `TypeError::RecursiveTypeAlias`; [L4] |
| Gleam's custom types are nominal; two structurally identical wrappers are not interchangeable, while two aliases are | local | [L4] — **no official Gleam doc states "nominal" or "Hindley–Milner"; this is inference from compiler behaviour** |
| TypeScript decides recursive structural relations by a coinductive assumption set with a depth-100 backstop | src | [6] `checker.ts` `recursiveTypeRelatedTo`, `maybeKeysSet` → `Ternary.Maybe` |
| TypeScript's instantiation budget is depth 100 / 5,000,000, raising TS2589 | src | [6] `checker.ts` `instantiateTypeWithAlias` |
| Recursive conditional types (self-referencing aliases in more positions) landed in TypeScript 4.1 | doc | [6] TS 4.1 release notes |
| No exemplar type is recursive; the only JSON contact is an opaque `Json.Encode(term)` | local | [L1] |
| `bs_types:term/0` prints as a recursive equation and is held by three saturating sentinels | local + src | [L2]; `bs_types.erl:47,56,74,116` |
| `term \ list<term>` is over-approximate (keeps `[term, ..]`) | local | [L2] |
| `resolve/3`'s `Seen` chain is not reset by a type constructor, so contractive and degenerate recursion give the same error | local + src | [L3]; `bs_check.erl:638–702, 744` |
| `type_env/1` eagerly pre-resolves ground aliases to finite `ty()` terms | src | `bs_check.erl:565–582` |
| `ty()` is a six-key closed map whose own comments warn a forgotten component fails silently | src | `bs_types.erl:99, 186, 225` |
| The 40-clause "no cliff" benchmark was taken with no recursive types in the algebra | src | `fog.md`; `bs_types.erl` has no μ node |

### Where the evidence is thin

- **Unproven hypothesis, recorded because the first draft of this file asserted it as fact:**
  *depth-limited widening makes some functions over a recursive type unwritable* — a residual too
  big that no clause set can discharge, whenever the clauses inspect past the widening frontier.
  §3.3 shows the *ordinary* case works, because `resolve/3` widens both sides equally. Nothing was
  found that settles the boundary, and no source combines depth-limited recursion with an
  exhaustiveness obligation — Dialyzer does not check coverage, and CDuce/Etylizer do not
  depth-limit. **Cheap falsification, and it should be run before point 3 is either adopted or
  dismissed**: implement point 3 behind a flag, write `Tree` with a clause set that destructures two
  levels deep, and see whether the residual empties.
- **CDuce was not re-probed for this file.** Research 29 established CDuce 0.6.0 runs locally and
  upgraded the map's CDuce claims to `local`; nothing here re-measures its recursive-type
  behaviour, and the CDuce claims above come from FCB08 and from Etylizer's characterisation of it.
  A local `cduce` probe of a recursive type's subtyping cost is the obvious missing measurement.
- **No Gleam documentation states "nominal" or "Hindley–Milner"** in those words. §3.2's
  characterisation rests on compiler behaviour [L4] and on the compiler's own error type name.
- **Elixir's deferral of recursive types is documented by absence, not by statement.** The docs do
  not say "recursive types are deferred"; they simply never mention them, and the implementation
  has no node for one [L5]. That is strong evidence but it is not a designer's sentence, and it
  should not be quoted as one.
- **The Elixir guard paper [2] is 114 pages and was searched by keyword, not read in full.** Its
  §3 grammar statement is quoted accurately; a claim about what it says elsewhere on recursion
  should be re-checked before being made.
- **`is_open/1` over a μ-type is an open question**, not answered here. It decides whether `_` is
  legal over a recursive type under ticket 12 §2, and the answer is not obvious.

---

## Amendments ticket 09 and 11 should take

The map takes or declines these; this file does not apply them.

1. **09 §3 should add regularity beside contractiveness.** It is the condition FCB08 §5.4 names as
   load-bearing for decidability, and 09 omits it entirely. One sentence.
2. **09 §3's theory-coherence argument should be narrowed.** *"Semantic subtyping is defined over
   regular recursive types"* is true of FCB08's presentation and does not entail that this language
   must have them — the signature is finite and recursion is a reading of it [1][5], and the
   circularity FCB08's bootstrapping addresses needs arrows, which this algebra does not have. The
   decision may well stand; the *reason* given for it does not.
3. **09 should record that `term` is already a recursive type.** Held by saturating sentinels with a
   measured over-approximate residual [L2]. This is the strongest argument *for* the decision — the
   language could not avoid one — and 09 does not make it.
4. **11 should record the printing tension.** A μ-type's only finite printing is its binder's name,
   and 09 §1 says the name never participates in the algebra. The residual is the diagnostic, so
   this is not cosmetic.
5. **`fog.md`'s 40-clause "PAID" entry should be qualified.** It measured wide matches without
   recursive types; Etylizer's published pathology is recursive types *times* wide matches
   [5, preprint]. The number stands; the reassurance does not extend to the combination. Mark the
   Etylizer figure as not-yet-peer-reviewed wherever the map picks it up.
6. **`fog.md`'s `ValidateAs<T>` "over a recursive type" measurement is currently unreachable.**
   Neither type it is generated over in the corpus is recursive [L1]. Either the requirement needs a
   synthetic input or it should be marked as blocked on recursion landing.
7. **The diagnostic split of §3.5 should be filed as a small feature**, not left in this file.

---

## Sources

**Primary**

1. Alain Frisch, Giuseppe Castagna, Véronique Benzaken. *Semantic subtyping: Dealing
   set-theoretically with function, union, intersection, and negation types.* Journal of the ACM
   55(4), 2008. <https://www.cduce.org/papers/semantic_subtyping.pdf> — read locally; the PDF has
   no ToUnicode map and was decoded from its glyph encoding before quoting.
2. Giuseppe Castagna, Guillaume Duboc. *Guard Analysis and Safe Erasure Gradual Typing: a Type
   System for Elixir.* arXiv:2408.14345. <https://arxiv.org/pdf/2408.14345>
3. Gleam compiler source: `TypeError::RecursiveTypeAlias`,
   <https://github.com/gleam-lang/gleam/blob/7e623aa8/compiler-core/src/error.rs#L4258-L4264>, and
   the `alias_direct_cycle` / `alias_cycle` snapshot tests in
   `compiler-core/src/type_/tests/snapshots/`.
4. OTP 28.5, read locally at
   `/opt/homebrew/Cellar/erlang/28.5/lib/erlang/lib/dialyzer-5.4/src/erl_types.erl` — constants at
   lines 236–238, 4021, 4563–4564; `can_unfold_more/2` at 4940–4945; `t_limit/2` at 3496–3512.
   Release-note attribution from the bundled `dialyzer-5.4/doc/html/notes.md` (Dialyzer 2.2.0:
   *"Added support for recursive types (experimental)"*), mapped to OTP R13B04 via `vsn.mk` at the
   OTP git tags.
5. Albert Schimpf, Stefan Wehr, Annette Bieniusa. *Set-Theoretic Types for Erlang: Theory,
   Implementation, and Evaluation.* arXiv:2603.22032v1 — **preprint, marked "DRAFT PAPER UNDER REVIEW" on its own pages**, 23 March 2026.
   <https://arxiv.org/pdf/2603.22032> — this is Etylizer, the tool ticket 04 already cites.
6. TypeScript compiler source, `microsoft/TypeScript` at `b465fdbf`: `checker.ts`
   `instantiateTypeWithAlias` (L21020–21031), `getConditionalType` tail loop (L19776–19784),
   `recursiveTypeRelatedTo` (L23319–23440), `isDeeplyNestedType` (L25239). Release notes for
   TypeScript 4.1, *Recursive Conditional Types*.
7. *Gradual set-theoretic types*, official Elixir documentation,
   <https://hexdocs.pm/elixir/gradual-set-theoretic-types.html>.

**Local probes**

| Ref | What | How |
|---|---|---|
| L1 | Every exemplar type read in full; no recursion; `Json.Encode` takes a `term` | `compiler/examples/exemplars/**/*.bs` |
| L2 | `term()` prints as a recursive equation; `list<term> <: term`; `term \ list<term>` is over-approximate | `bs_types` called directly against the built `bsc` beams, OTP 28.5 |
| L3 | `type Tree = (int, list<Tree>)` and `type X = X \| int` give the identical error | `bsc` at `e1f1908`, built with `rebar3 escriptize` |
| L4 | Gleam 1.18.1: recursive custom type compiles; recursive alias errors *"Type cycle"*; nominal vs alias identity | `gleam build` in a scratch project |
| L5 | Elixir 1.19.5 `Module.Types.Descr`: no recursion node; descrs are finite terms; unfolding does not converge; a recursive `@type` compiles because typespecs are not checked | `elixir` scripts against `Module.Types.Descr` |
