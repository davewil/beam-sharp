# 29 — Refinement types in shipping languages: what did ticket 20 reinvent?

Research for [issue 29](../issues/29-refinement-type-prior-art.md). Checks
[ticket 20](../issues/20-untheorised-term-shapes.md) §5 for divergence from prior art, and
touches [09](../issues/09-union-representation.md) §5 (the newtype gap),
[11](../issues/11-type-system-shape.md) §2 (unbounded work in a clause head),
[18](../issues/18-boundary-defence.md) §2 (the admissible foreign declaration set) and
[04](../issues/04-crossclause-exhaustiveness.md) (clause counts).

**Ticket 20's decisions are not re-opened by this file.** Where the evidence pushes against one,
the recommendation is recorded in [Amendments](#amendments-ticket-20-should-take) for the map to
take or decline.

---

## The verdict, first

**Ada's split corroborates ticket 20's *structure* and contradicts its *cut*.**

Ada 2012 does have two predicate tiers, has had them since 2012, and the privileged tier buys
almost exactly what ticket 20's guard refinements buy: legality in a dispatch construct, and
participation in the compiler's own coverage check. That much is the same shape reached
independently on an unrelated platform, and it is the strongest corroboration available.

But Ada does **not** cut on the cost of deciding the predicate. It cuts on the **syntactic form of
the predicate expression**, and the difference is not academic — measured on GNAT 12.2:

```
Static_Predicate => Odd mod 2 = 1      -> error: expression is not predicate-static (RM 3.2.4(16-22))
Static_Predicate => Positive_Ish > 0   -> ACCEPTED
```

Two predicates of *identical* runtime cost — one machine operation and a compare — land on opposite
tiers, separated by nothing but which operator they use [L3]. Barnes says so in the designers' own
words: *"we see that the predicate in the subtype `Even` cannot be a static predicate because the
operator `mod` is not permitted with the current instance"* [7].

So **ticket 20's line is beam-sharp's own invention, not a borrow** — and the map should say so,
because ticket 20 presented it as landing on the map's recurring O(1) line without noting that no
shipping language cuts there. That is the one amendment this file presses for.

The other two verdicts:

- **Solver-free interval refinement is something someone ships, and now has a published cost —
  because this file published it.** CDuce 0.6.0 installs, runs, and does exact interval union,
  intersection and complement with no solver linked into the binary. At ticket 04's 40-clause
  shape the checker cost is *below the measurement floor*; it goes quadratic past ~200 clauses.
  Ticket 20 §5's affordability claim holds at the clause counts this language advertises.
- **CDuce upgrades from `doc` to `local`.** The brief anticipated a downgrade and marked every
  CDuce claim for it. The opposite happened. The map's 88 CDuce citations are **corroborated**, at
  version 0.6.0, built 2017-03-17.

## Method and provenance

| Mark | Meaning |
|---|---|
| **doc** | Official documentation, reference manual, standard text, or the designers' own writing |
| **src** | Source code or repository artefacts of the implementation |
| **local** | Observed directly on this machine |

`local` claims carry an `[Ln]` reference and name the prototype that produced them. Everything
installed for this ticket is pinned: **CDuce 0.6.0** (Debian stretch, amd64 under emulation),
**GNAT 12.2.0** (Debian 12), **OTP 28.5**, **Gleam 1.18.1**, **node 22.22.3**, **.NET 9.0.10**.

Two `src` claims delegated to parallel sweeps were re-checked here against local installations and
upgraded to `local`: `erl_types`' bitstring widening and Gleam's `BitArray` arity. The rest of the
sweep material is marked as it arrived.

---

## Part 1 — Ada and SPARK

### 1.1 A range constraint and a predicate are different mechanisms, and Ada keeps them apart

This is the fact everything else in Part 1 hangs off, and ticket 29 did not anticipate it.

A **range constraint** (`subtype Small is Integer range 1 .. 10`) is part of the subtype's
*constraint*. A **predicate** is an *assertion aspect* — ARM 3.2.4(1/5): *"The predicate aspects are
assertion aspects (see 11.4.2)"* [1]. Three consequences, all measured [L5]:

| | on violation | present without `-gnata`? |
|---|---|---|
| range constraint | `CONSTRAINT_ERROR` | **yes** |
| `Dynamic_Predicate`, O(1) arithmetic | `ADA.ASSERTIONS.ASSERTION_ERROR` | **no** |
| `Dynamic_Predicate`, O(n) content scan | `ADA.ASSERTIONS.ASSERTION_ERROR` | **no** |

Compiled without `-gnata` the invalid values sail straight through — a `String` that fails its
own `All_Upper` predicate prints, and `4` inhabits a subtype whose predicate is `mod 2 = 1` — while
the range constraint still raises. Barnes confirms the design intent: *"Subtype predicates, like
pre- and postconditions and type invariants are similarly monitored by the pragma
Assertion_Policy. If a predicate fails (that is, has value False) then Assertion_Error is
raised."* [7]

**A constraint in Ada is a guarantee. A predicate is an assertion you can compile out.** That is a
sharper separation than beam-sharp has, and it lands on the side ticket 18 already chose: 18's
boundary guards have **no opt-out**, and this is corroboration for that rather than pressure
against it. But it is worth stating in the spec, because a reader coming from Ada will expect
`type Positive = int where value > 0` to be switchable and it is not.

Where the checks go, per ARM 3.2.4(31/5): *"On a subtype conversion, a check is performed that the
operand satisfies the predicates of the target subtype … after normal completion and leaving of a
subprogram, for each `in out` or `out` parameter that is passed by reference, a check is performed
… For an object created by an `object_declaration` with no explicit initialization expression …"*
[1]. Note what is absent: **there is no per-operation check.** ARM 3.2.4(35/3) says so outright —
*"A Dynamic_Predicate … can become False at other times. For example, the predicate of a record
subtype is not checked when a subcomponent is modified."* [1]

SPARK converts these runtime checks into proof obligations. It admits both predicate forms —
*"Static predicates and dynamic predicates are both in SPARK, but subject to some restrictions"*
[8] — and adds a **third** form, `Ghost_Predicate`, for predicates that mention ghost state and are
therefore never executable, only provable [9]. That third tier is cut on yet another line
(**executability**), which is itself worth noticing: the Ada family has three tiers on three
different criteria, and none of the three is cost.

### 1.2 `Static_Predicate` versus `Dynamic_Predicate` — the ticket's highest-value question

**The cut is syntactic form.** ARM 3.2.4(15/3): *"The expression of a Static_Predicate
specification shall be **predicate-static**; that is, one of the following"* — followed by seven
permitted forms [1]:

> a static expression; a membership test whose tested_simple_expression is the current instance,
> and whose membership_choice_list meets the requirements for a static membership test; a
> case_expression whose selecting_expression is the current instance, and whose
> dependent_expressions are static expressions; a call to a predefined equality or ordering
> operator, where one operand is the current instance, and the other is a static expression; a call
> to a predefined boolean operator `and`, `or`, `xor`, or `not`, where each operand is
> predicate-static; a short-circuit control form where both operands are predicate-static; or a
> parenthesized predicate-static expression.

Cost appears nowhere in that list. `mod` is absent not because it is slow but because it is not
one of the seven, which is why `Odd mod 2 = 1` is rejected and `Positive_Ish > 0` accepted at
identical cost [L3]. Membership tests and case expressions are admitted — both of which can
enumerate *many* values — while a single modulus is not.

**What the privileged tier buys, and it is recognisably ticket 20's list.** A `Static_Predicate`
subtype may appear as a `case` alternative; a `Dynamic_Predicate` subtype may not [L1]:

```
when Even_Digit => ...     -- Static_Predicate:  ACCEPTED
when Pos_Even   => ...     -- Dynamic_Predicate: error: cannot use subtype "Pos_Even"
                           --                    with non-static predicate as case alternative
```

and — the load-bearing half — **the predicate participates in coverage checking**. ARM
3.8.1(10.1/4): *"A discrete_choice that is a subtype_indication covers all values (possibly none)
that belong to the subtype **and that satisfy the static predicates of the subtype**"* [3].
Measured, a `case` over a five-value static-predicate subtype that omits one value is a compile
error naming the missing value [L1]:

```
p3.adb:8:07: error: missing case value: 8
```

That is ticket 04's residual, named, in a language shipped since 2012 — and it is close to
ticket 23's diagnostic requirement too. Barnes states the payoff exactly as the map would:
*"Observe that we do not have to list all the individual animals and naturally there is no others
clause … not only do we get the benefit of full coverage checking, but the code is also
maintenance free."* [7]

Ada also **withholds** things from predicated subtypes, in a list that reads like a cautious
version of ticket 20's — ARM 3.2.4(25/3–28/3) [1]: a predicated subtype may not be an index
subtype, a slice's discrete range, an array or entry index definition, or the prefix of `'First`,
`'Last` or `'Range` on a scalar; and a loop parameter may not range over a **nonstatic** predicated
subtype **or any `Dynamic_Predicate` subtype at all**. The pattern is consistent: anywhere the
compiler must *enumerate or bound* the subtype, only the static tier is admitted.

**Verdict.** Structure corroborated: two tiers, the privileged one reasoned about and legal in the
dispatch construct, the other merely checked. Cut contradicted: Ada's is `predicate-static` form,
beam-sharp's is O(1) runtime decidability.

**And the relation between the two cuts is containment, not crossing — beam-sharp's tier 1 is a
strict liberalisation of Ada's.** Take the seven predicate-static forms in turn against the BEAM
guard set: a static expression is a literal; a static membership test is a comparison chain over a
fixed finite set; a `case_expression` on the current instance with static arms is the same; a
predefined equality or ordering operator against a static expression is `=:=`/`<`/`>`; `and`, `or`,
`xor` and `not` are `andalso`/`orelse`/`xor`/`not`, all guard-legal; short-circuit and parentheses
add nothing. **Every Ada static predicate is decidable by one BEAM guard in O(1).** The converse
fails, and `mod 2 = 1` is the witness [L3]: `rem` is a guard BIF, so that predicate is beam-sharp
tier 1 and Ada tier 2. So Ada's static tier ⊂ beam-sharp's guard tier, properly.

That is a stronger reading than "the lines cross", and it changes what the divergence costs. Ada's
tier 1 is an approximation of decidability, reached syntactically because Ada has no
platform-given predicate language to point at; beam-sharp has one — the BEAM guard set — and can
therefore name the real criterion directly. **This is marked as inference, not measurement**: it is
the ARM's seven forms read against the guard set, not a probe. It would take a probe to be
certain, and the one form worth checking is a static membership test over an enumeration wide
enough that the compiled comparison chain stops being O(1).

### 1.3 Type identity — Ada separates *subtype* from *derived type*, and beam-sharp cannot

Measured [L4]:

```ada
subtype Meters_S is Float range 0.0 .. Float'Last;   -- Feet_S -> Meters_S: ACCEPTED silently
type    Meters_T is new Float range 0.0 .. Float'Last;  -- Feet_T -> Meters_T: rejected
```

```
p8.adb:18:19: error: expected type "Meters_T" defined at line 8
p8.adb:18:19: error:    found type "Feet_T" defined at line 9
```

So ticket 20 §7's conclusion is **right for the right reason**: a refinement is a set, and a
subtype in Ada is a set too, and Ada's subtypes do not distinguish metres from feet either. Ada
solves the newtype problem with a *different* construct — a derived type — and gets it for zero
runtime cost, because the derived type shares its parent's representation and the nominality is
erased before code generation.

**What Ada buys that beam-sharp forfeited in ticket 09** is therefore precisely *compile-time-only
nominality*, and here this file has to record a tension it cannot resolve. Ticket 09 §5 concluded
that compile-time-only nominality "is available on the BEAM and buys nothing, because erased
nominality is exactly an alias". Ada is a counter-example to the general form of that sentence:
`Meters_T` and `Feet_T` are erased at runtime and are emphatically *not* aliases at compile time.
What ticket 09's argument actually establishes is narrower — that erased nominality does not close
the *capability* gap it cared about (negation, union closure, boundary enforceability) — and that
narrower claim survives Ada intact. **This is ticket 09's business, not ticket 20's, and this file
does not re-open it**; it is recorded because ticket 29 asked and because the sentence as written
in the map is broader than its own evidence.

**Is ticket 09's tuple tag the same trade? No — it is a strictly worse one on the axis Ada wins.**
Ada's derived type changes nothing about the value; `{:meters, 3.0}` changes the term, which is
visible at every interop boundary and in every pattern that touches it, exactly as ticket 09 said.
Ada pays nothing; beam-sharp pays a wrapper. The reason is ticket 09's own and unchanged: Ada has
a nominal layer to erase, and beam-sharp deliberately has none.

### 1.4 May a user declare a predicate the compiler cannot decide? Yes, and Ada has since 2012

This is the sub-question with the most force against ticket 20, and the answer is unambiguous.

`Dynamic_Predicate` takes *any* boolean expression. Barnes: *"In the case of `Dynamic_Predicate`,
the expression can be any Boolean expression."* [7] The Reference Manual's own worked example is
not a cheap arithmetic test but an arbitrary function call on a limited private type — ARM
3.2.4(45/4) [1]:

```ada
subtype Open_File_Type is File_Type
  with Dynamic_Predicate => Is_Open (Open_File_Type),
       Predicate_Failure => raise Status_Error with "File not open";
```

Measured, an O(n) predicate scanning a string's every character — the direct analogue of
`binary where valid_utf8` — is legal, user-declared, and enforced at run time [L5]:

```
O(n) content predicate, user-declared -> ADA.ASSERTIONS.ASSERTION_ERROR
```

**What contains it is not a restriction on the predicate but a restriction on where the check
goes.** Ada inserts predicate checks at subtype conversion, at parameter passing, and at default
initialisation (§1.1) — never inside a dispatch construct, because §1.2 already bars the dynamic
tier from `case` alternatives and loop parameters. **The containment is structural, and it is the
same structure ticket 20 arrived at from the other end.**

This matters because ticket 20's refusal of user-declared opaque refinements is inherited from
ticket 11, whose hazard is specifically unbounded work *in a clause head*, "whose size a foreign
sender chooses". Ada demonstrates that the hazard can be contained by placement rather than by
prohibition. See [Amendments](#amendments-ticket-20-should-take).

---

## Part 2 — Does any language split refinements by decidability of the predicate?

**No. Not one of the five candidates cuts on the cost of evaluating the predicate.** Where each
one does cut:

| System | Where the line falls | Solver-free tier? |
|---|---|---|
| **Liquid Haskell** | syntactic triviality (`isTautoPred`: constructor match and structural equality), and only on the proof-by-logical-evaluation path, not the subtyping path | no meaningful one — Z3 unconditional once a constraint survives [s1] |
| **F\*** | what *normalisation* already closed — `guard_formula` is `Trivial \| NonTrivial`, decided after `Beta; Eager_unfolding; Simplify; Primops` | yes, a genuine non-SMT discharge, but keyed on prover power, not cost [s2] |
| **Nim** | whether the value was a **compile-time constant** | yes — see below [s3] |
| **Whiley** | which *phase and binary* runs; flow typing is prover-free, `where` clauses are runtime-checked unconditionally, static proof is opt-in | flow typing yes; the native verifier was itself a purpose-built SMT solver [s4] |
| **Dafny** | syntactic *compilability* (`ConstraintIsCompilable`) | for subset types, no — even a `CompiledZero` witness goes to Z3 [s5] |

`guard_t` in F\* has five fields and **none is a cost annotation** [s2]; Dafny's one piece of real
solver-free interval arithmetic (`NativeTypeAnalysis.cs`) is `newtype`-only, cannot reach a subset
type, and is a code-*generation* decision rather than a typing tier [s5]. The design boundary
ticket 20 drew — O(1)-decidable versus O(n) — is **unattested across all five**.

**Nim is the closest and is weaker than ticket 29 hoped.** Its mainline compiler does carry genuine
solver-free interval reasoning: `proveLe` in `compiler/guards.nim`, built on a saturating-arithmetic
fact model with no Z3 anywhere near it [s3]. But it is gated behind `{.staticBoundChecks: on.}` —
*the same pragma the Z3-backed DrNim requires* — it emits `warnStaticIndexCheck`, a **warning**,
never an error, and the actual safety guarantee is a runtime `raiseRangeErrorI` that `-d:danger`
compiles away. Decisively, the Nim manual defines a `range` as two literal bounds — *"To define a
subrange type, one must specify its limiting values"* [s3] — so **there is no user-declarable
predicate at all**. Nim's interval reasoning is cheap partly because Nim barely does it.

**A `local` correction to how ticket 20 framed its own affordability argument.** Ticket 20 wrote
that intervals are affordable *because* they are not SMT. That is true but incomplete as a reading
of the prior art: across all five systems, cheapness comes as much from **expressive restriction
plus a runtime backstop** as from avoiding a solver. Ada is the same story (§1.1: the assertion
you can compile out). The honest form of ticket 20's sentence is *intervals are affordable because
they are a decidable domain and beam-sharp refuses to let the predicate language grow past it* —
which is what ticket 27's four refusals already bought, and is a stronger argument than the one the
ticket made.

**Has anyone published a cost?** Only for the SMT-based paths — Liquid Haskell's two 2014 tables,
F\*'s Low\*/Meta-F\* numbers and per-query `--query_stats`, Whiley's 1.3 s per small test programme
over 731 valid tests, Dafny's per-assertion resource counts and IronFleet's 395 minutes [s1][s2]
[s4][s5]. **For the solver-free side there is nothing**: Whiley's native verifier is reported as
pass rates with no clock, Dafny's `NativeTypeAnalysis` has no published cost, and for Nim the
manual, the compiler user guide, the DrNim guide, PR #10965 and the RFC set contain **no benchmark
of any kind** [s3]. Part 3 supplies the missing number.

---

## Part 3 — CDuce, measured

CDuce is named 88 times across this map and had never been run. **It runs.**

It is not in opam — `opam search cduce` returns no matches on opam 2.1.6 [L6] — and the last suite
packaging it is **Debian stretch** (0.6.0-5, per the Debian sources API), which archive.debian.org
still serves. [`29a_Dockerfile`](../prototypes/29a_Dockerfile) builds it; the security suite is
needed alongside `main` or the dependency chain will not resolve. amd64 only, so it runs under
emulation on Apple Silicon.

**Version pinning matters here and the map's citations are undated.** What is measured below is
CDuce **0.6.0, built 2017-03-17** — the last packaged release. The gitlab development tree is
newer and was not measured.

CDuce has no "print this type" directive, so the method is to force a type error: `let f (x : T) :
Empty = x;;` makes the checker print its own normalised form of `T`. Where `T` really is empty the
file typechecks instead, which is itself the answer.

### 3.1 The algebra is exact [L6]

| Operation | Written | CDuce's normalisation |
|---|---|---|
| union, adjacent | `1--10 \| 11--20` | `1--20` |
| union, non-adjacent | `1--10 \| 20--30` | `1--10 \| 20--30` |
| intersection | `1--10 & 5--20` | `5--10` |
| intersection, disjoint | `1--10 & 20--30` | decided **empty** (branch reported unused) |
| complement | `Int \ 1--10` | `*--0 \| 11--*` |
| difference | `1--30 \ 10--20` | `1--9 \| 21--30` |
| double complement | `Int \ (Int \ 1--10)` | `1--10` |
| arbitrary bound | `5--20` | `5--20` |
| half-open | `500--2000 \| 3000--*` | `500--2000 \| 3000--*` |

Every one is exact. Set this beside ticket 20's measurement that `erl_types` snaps `5..20` to
`1..255` and `500..2000` to `1..1114111`: **the two bounds CDuce preserves verbatim are the two
Dialyzer destroys.** Ticket 20's "beam-sharp can inherit this platform's type grammar, not its
algebra" is confirmed from the other side — the algebra it wants exists, and it is CDuce's.

### 3.2 Intervals in the exhaustiveness algorithm [L6]

The residual over an interval subject is exact and is named:

```
let f (Int -> Int) | 0--9 -> 1 | 10--19 -> 2 | 20--* -> 3
  => This pattern matching is not exhaustive
     Residual type: *---1
```

`*--(-1)` — everything below zero, which is exactly what the clauses miss. And an exhaustive
interval partition with **no catch-all** is accepted, both over a declared interval (`0--19`) and
over all of `Int`. That is ticket 20 §5's stated benefit — *"the right to partition an integer
domain by guards without a catch-all"* — observed working rather than argued.

### 3.3 There is no solver in it [L6]

`ldd` on the binary lists expat, curl/gnutls, pcre and libc and their transitive dependencies;
`apt-cache depends cduce` lists camlp4, ocamlnet, ulex, pcre and ocaml-nox. **No SMT library, at
either level.** The `libgmp` that appears is gnutls', not a solver's.

So the answer to ticket 29's second question is yes: solver-free interval refinement reasoning,
including complement, is something a real implementation ships.

### 3.4 What it costs at ticket 04's clause counts [L7]

Timed inside one container to remove the ~1.2 s emulated start-up. Baseline is a one-clause
function with no intervals; net cost is the interesting column.

| Clauses | Exhaustive partition of `Int` | net | Nested overlapping intervals | net |
|---:|---:|---:|---:|---:|
| baseline (1) | 129 ms | — | — | — |
| 10 | 117 ms | ~0 | 126 ms | ~0 |
| **40** | **127 ms** | **~0** | **111 ms** | **~0** |
| 100 | 129 ms | ~0 | 121 ms | ~0 |
| 200 | 143 ms | 14 ms | 159 ms | 30 ms |
| 400 | 240 ms | 111 ms | 305 ms | 176 ms |
| 800 | 611 ms | 482 ms | 906 ms | 777 ms |
| 1600 | 2192 ms | 2063 ms | 3384 ms | 3255 ms |

Three findings:

- **At ticket 04's pathological shape — the 40-branch `case`, which is the large multi-clause
  `handle_info` this language advertises — interval checking is free.** It is below the
  measurement floor, and stays there to 100 clauses.
- **The cost is quadratic in clause count**, and only becomes visible past ~200. Each doubling
  from 400 costs ~4.3×, on both paths. There is no cliff and no non-termination; the growth is
  orderly.
- **The redundancy path is consistently ~1.6× the exhaustiveness path** at the same clause count,
  which is worth knowing because beam-sharp runs both.

Caveats, because this number will be quoted: emulated amd64; CDuce 0.6.0; and **CDuce's checker is
not beam-sharp's**. This is evidence that the interval domain is tractable at the shapes this
language advertises, not a prediction of beam-sharp's own checker. The walking skeleton still owes
its own number — see the map's fog patch, which ticket 20 already amended for exactly this.

---

## Part 4 — Structural binary typing outside Erlang

**Essentially nobody, and the closest analogues are not the ones the ticket expected.**

Erlang's `<<_:M, _:_*N>>` bundles four separable properties: bit granularity; a size in the type at
all; an *open repeating unit* (the type denotes the set `{M + k·N}`, not one size); and automatic
subsumption on values already in hand, with no cast and no proof term. Scoring all four is what
makes the comparison honest, because almost every near-miss fails a different one [s6].

**Gleam's `BitArray` is the sharp data point, and it fails at the first hurdle.** It took Erlang's
matching construct and not its type. Measured locally on Gleam 1.18.1 [L8]:

```
pub fn sized(b: BitArray(32)) -> Int
                          ^^ I was not expecting this  -- Found an Int, expected one of: `)`
```

`BitArray` takes no type parameter. Every `BitArray` is the same type, so passing a one-byte value
to a function that matches 32 bits compiles cleanly and falls to the catch-all at run time — the
size is a runtime match, never a claim the checker holds anyone to. Ticket 20's borrow of the full
Erlang grammar is therefore **a genuine differentiator over the nearest neighbour**, not table
stakes.

Of everything else surveyed [s6]:

- **HDLs are not the closest analogue**, contrary to the ticket's expectation. Bluespec and Clash
  win on width-in-type plus width arithmetic checked before elaboration, but neither has the open
  repetition; VHDL defers to a runtime bound check; SystemVerilog silently truncates; Chisel's
  widths never enter Scala's type system at all.
- **The systems that reach the *unit* constraint are refinement- and constraint-solved languages**:
  F\*/HACL\* (`inp:seq a{length inp % blocksize = 0}` — stronger than Erlang, in allowing a
  *variable* modulus, but its bit type is unpacked into bytes), Cryptol (`%` is a type function and
  `==` a proposition, so `{n} (n % 8 == 0) => [n] -> …` is well-formed — but as constrained
  polymorphism, not subsumption), and Sail via constrained existentials.
- **Zig is the strongest mainstream hit** and has no repetition: arbitrary-bit-width integers,
  packed structs whose backing width is enforced at compile time, and — uniquely in the survey —
  bit offsets carried in *pointer* types and rejected at a function boundary.
- **The data-description languages all fail the type-versus-library test**, and PADS says why in
  its own words: the mapping to the host language erases the dependency because the host has no
  dependent types.
- **Ada can *state* the constraint** (`Dynamic_Predicate => X'Length mod 4 = 0`) and checks it at
  run time; SPARK discharges it statically as a proof obligation, not as a type.

**Nothing combines all four axes in one first-class type.** The gap Erlang occupies is genuinely
unoccupied.

### 4.1 A third `erl_types` lossiness ticket 20 did not record [L8]

Ticket 20 found two places `erl_types` trades exactness for optimism — the same-constructor union
collapse (§2) and the integer quantisation ladder (its headline). Measured on OTP 28.5, there is a
third, in the binary domain, and its motive is different:

```erlang
t_bitstr(U, B) ->
  NewB = if U =:= 0 -> B;
            B >= (U * (?UNIT_MULTIPLIER + 1)) -> (B rem U) + U * ?UNIT_MULTIPLIER;
            true -> B
         end,
  ?bitstr(U, NewB).                                    % ?UNIT_MULTIPLIER is 8
```

```
t_bitstr(8,  71) -> <<_:71,_:_*8>>   exact
t_bitstr(8,  72) -> <<_:64,_:_*8>>   WIDENED
t_bitstr(8, 200) -> <<_:64,_:_*8>>   WIDENED
```

Any base at or above `U*9` is silently widened. `<<_:200,_:_*8>>` becomes a type admitting 64-bit
values nobody declared — the same defect ticket 20 §2 documented for unions, at a second site.

**The motive is the interesting part.** The union collapse and the quantisation ladder are
*optimism*, which a success-typing tool may indulge. This one is a **finite-height lattice**: the
base is bounded so that fixpoint iteration terminates. Ticket 20 §2 commits beam-sharp to an exact
binary union on the grounds that only emptiness and openness need deciding, which is a good
argument — but it should now be made explicitly against this, because the platform's own designers
gave up exactness in this exact domain for termination, and the spec should say why beam-sharp
does not have to. The map already holds ticket 04's finding that the exhaustiveness algorithm has
no complexity bound, so this is not a hypothetical worry.

---

## Part 5 — The `string` versus `binary` borrow

**Tier 1 confirmed, on both audiences.** C# has `string` and `byte[]`; TypeScript has `string` and
`Uint8Array`. Ticket 20 decided `string` on the `json:encode/1` evidence alone; the borrow
heuristic supports it independently and the ticket may claim tier 1 rather than tier 3 for the
*split*.

**But what each does when the bytes are not valid text diverges from beam-sharp, and the default is
not what a reader of either standard library would guess.** Measured [L9], decoding
`[0xff, 0xfe, 0x00, 0x01]`:

| | default | opt-in strict |
|---|---|---|
| C# `Encoding.UTF8.GetString` | `"�� "` — **substitutes, silently** | `new UTF8Encoding(false, true)` → `DecoderFallbackException` |
| TS `new TextDecoder()` | `"�� "` — **substitutes, silently** | `{fatal: true}` → `TypeError` |
| node `Buffer.toString('utf8')` | substitutes, silently | — |

Both audiences default to **silent lossy substitution** and make throwing opt-in. Neither treats
"valid UTF-8" as a property of the type: it is a decoder *policy*, chosen at the call site.

This is ticket 06's **outcome 3** in the two languages beam-sharp borrows from — a badly-typed
value neither crashes nor is rejected, and what comes out is wrong. It is the same shape as ticket
18's Elm finding (`1e300` through an `Int` port), and it is the exact case ticket 20's generated
entry check exists to prevent. **So the borrow is on the type split, not on the failure behaviour,
and beam-sharp is deliberately stricter than both.** The spec should say this where it states the
`string` type, in the same way the map already flags that `as` means the C# thing and not the
TypeScript thing.

**One unlooked-for corroboration and one divergence** on ticket 20 §4's serialisation mapping:

- `JsonSerializer.Serialize(byte[])` in .NET 9 yields `"//4AAQ=="` — **base64**. Ticket 20 §4
  decided a bare `binary` encodes as base64, and .NET reached the same mapping independently.
- `JSON.stringify(Uint8Array)` in node 22 yields `{"0":255,"1":254,"2":0,"3":1}` — an index-keyed
  object, matching nothing. So the two audiences agree on the type split and disagree on the
  encoding; ticket 20's choice follows C#, and that is worth recording as the tie-break rather
  than leaving it to look unanimous.
- `JSON.stringify("\uD800")` yields `"\ud800"` without throwing; .NET's serialiser replaces the
  lone surrogate with U+FFFD. Neither refuses. **Both are lossy at the JSON boundary in a way
  ticket 20's compile-time error for non-byte-aligned bitstrings is not.**

---

## Verdicts

**1. Does Ada's static/dynamic predicate split corroborate or contradict ticket 20's two tiers?**
**Both, and the split is instructive rather than fatal.** The *structure* is corroborated — two
tiers, the privileged one legal in the dispatch construct and participating in coverage checking,
the other established and never reasoned about — reached independently, on an unrelated platform,
shipped since 2012. The *cut* is contradicted: Ada's is the syntactic form of the predicate
expression, and two predicates of identical O(1) cost land on opposite tiers [L3]. **Ticket 20's
line is unattested anywhere in the prior art surveyed**, Ada included and all five of Part 2's
candidates included. But the two cuts stand in **containment, not conflict**: every Ada static
predicate is decidable by one BEAM guard in O(1) and the converse fails, so Ada's privileged tier
is properly inside beam-sharp's, and beam-sharp's cut is a **strict liberalisation** of a line Ada
had to draw syntactically for want of a platform-given predicate language (§1.2, marked as
inference).

**2. Is interval-only refinement reasoning without a solver a thing anyone ships?** **Yes.** CDuce
0.6.0 does exact union, intersection, complement and difference over integer intervals, with
half-open ends and arbitrary bounds preserved verbatim, and no SMT library linked at either the
binary or the package level [L6]. Nim's mainline compiler carries genuine solver-free interval
reasoning too, but gated behind a pragma, emitting warnings only, with no user-declarable predicate
[s3]. Nobody had published a cost for the solver-free side; [`29b`](../prototypes/29b_cduce_clause_scaling.sh)
now does — **free at ticket 04's 40-clause shape, quadratic past ~200** [L7].

**3. Do ticket 20's decisions need amending?** **Yes, two, and neither is a reversal.** §5's
two-tier cut needs recording as a **tier-3 divergence with its reason**, because it is presented as
the map's recurring O(1) line applied again and no shipping language cuts there (amendment A).
§5's blanket refusal of user-declared opaque refinements should be **narrowed to a placement rule**
— barred from clause heads and foreign declarations, not barred outright — because Ada permits
them, contains them the same way beam-sharp already does, and has done since 2012 (amendment B).
Three further claims **upgrade** rather than change: CDuce to `local` at a pinned version, the
`string`/`binary` split to a tier-1 borrow, and ticket 20 §2's evidence gains a third `erl_types`
lossiness whose motive is termination rather than optimism. **Nothing ticket 20 decided is
wrong.**

## Amendments ticket 20 should take

Recommended, not made — this file's `write_scope` is itself and the prototypes.

**A. Record the two-tier cut as a tier-3 divergence, with its reason.** *(Recommended: take it.)*
Ticket 20 §1 presents the refinement tiers as the map's recurring O(1) line applied a fifth time,
which is true internally and reads as though the line were borrowed. It is not: **no shipping
language cuts refinements on the cost of deciding the predicate** (§1.2, Part 2). Under the
borrow heuristic this is tier 3, and tier 3 requires the divergence be recorded in the spec with
its reason. The reason is available and good — beam-sharp's tier 1 is defined by the BEAM guard
set, which is a *platform-given* decidable predicate language that Ada, having no such set, had to
approximate syntactically. That is a better justification than the ticket currently gives, and the
map's amendment to the heuristic ("diverge deliberately", not "diverge only as a last resort")
already sanctions it.

**B. Narrow the refusal of user-declared opaque refinements.** *(Recommended: take it. The
counter-argument is real and is stated, but the default should be the narrower rule.)*

Ticket 20 §5 bars users from the second tier entirely, reasoning from ticket 11 that an arbitrary
user predicate "could be quadratic or could fail to terminate". **Ada permits exactly this and has
since 2012** [L5].

The framing that makes this a small amendment rather than a large one: **Ada and ticket 20 already
agree on the containment, and disagree only on who may declare a member.** Ada's dynamic tier is
barred from every construct where the compiler must enumerate or bound the subtype — case
alternatives, loop parameters, index subtypes, slice ranges, `'First`/`'Last`/`'Range` (§1.2) —
which *is* ticket 20's rule that tier 2 is never reasoned about, arrived at independently. Ticket
11's hazard, in turn, is specifically about unbounded work in a **clause head**, and beam-sharp
already bars tier 2 from clause heads and from foreign declarations for exactly that reason. So the
prohibition on *declaring* one is doing no safety work that the placement rule is not already
doing. The rule the evidence supports:

> user-declared opaque refinements are barred **from clause heads and from foreign declarations**,
> not barred entirely.

What taking it requires, captured so it is not rediscovered later: a decision on whether the
compiler may emit a call to arbitrary user code at a boundary (Ada does, invisibly, at parameter
passing); a spelling for where the check is inserted, since beam-sharp has no `subtype conversion`
site to hang it on and would need one; and a rule for what happens when the predicate itself raises
— ticket 15's `result<T, E>` is the obvious answer and Ada's `Predicate_Failure` aspect is the
worked precedent [g4].

**The counter-argument, kept because it is why David might decline.** beam-sharp's opaque tier is
established by *generated* code at an entry the user does not see, which is a heavier obligation
than Ada's: `string` is currently the tier's only member and its check is compiler-known and linear
per byte, where admitting user predicates turns one known check into an open-ended codegen surface
whose cost the compiler cannot bound. Ada can afford it partly because its predicate checks are
switchable off (§1.1) and beam-sharp's are not (ticket 18, no opt-out) — so beam-sharp pays for
every one, always, with no escape valve. **If that decides it, the refusal should say so**, because
"a user predicate could be quadratic" is true of Ada too and did not stop Ada.

**C. Upgrade CDuce from `doc` to `local`, at a pinned version.** *(Recommended: take it.)* Ticket
20 §5's *"CDuce ships exactly this"* is now measured, not inherited from ticket 11 — and the
measurement is stronger than the claim, since complement and difference are exact too and the
residual over intervals is named. The map should record **CDuce 0.6.0, built 2017-03-17** as what
was measured, because its 88 citations are undated and the development tree is newer and
unmeasured.

**D. Claim tier 1 for the `string`/`binary` split, and state the divergence in failure behaviour.**
*(Recommended: take it.)* Part 5. The split is a tier-1 borrow on both audiences; the *behaviour*
is a deliberate divergence, because both audiences silently substitute U+FFFD by default and
beam-sharp refuses. Also worth recording: .NET's JSON serialiser independently reached ticket 20
§4's base64 mapping, and node did not, so the choice follows C# rather than being unanimous.

**E. Add the `t_bitstr` widening to ticket 20 §2's evidence, and say why beam-sharp escapes it.**
*(Recommended: take it.)* §4.1. It is a third `erl_types` lossiness, in the binary domain, and its
motive is *termination* rather than optimism — which is a different and more serious objection to
an exact binary union than the two ticket 20 answered. beam-sharp very likely does escape it,
because ticket 04 made signatures mandatory and there is no fixpoint over an unbounded lattice to
iterate, but the spec should say so rather than leave it implied.

**F. A caution to carry, not an amendment.** Ada's predicate checks are **absent by default** —
compiled without `-gnata` an invalid value simply passes [L5] — while its range constraints are
not. Ticket 18's "no opt-out" is corroborated by the contrast rather than challenged, but a reader
arriving from Ada will expect an assertion policy and there is none.

## Gaps and where I looked

Recorded rather than filled by inference.

- **[g1] CDuce's development tree was not measured.** Only the packaged 0.6.0 (2017-03-17). The
  gitlab repository at `gitlab.math.univ-paris-diderot.fr/cduce/cduce` responds, and would need an
  OCaml toolchain and a camlp4-era build; not attempted, because the algebra questions were fully
  answered by the release and a newer tree would only strengthen a conclusion already reached.
- **[g2] CDuce's *implementation* of the interval domain was not read.** Part 3 measures behaviour
  at the surface. Whether the representation is a sorted disjoint list of intervals — the obvious
  encoding, and the one whose quadratic behaviour §3.4 is consistent with — is inferred from the
  timings, not established from source. Marked as inference in the prose and not relied on.
- **[g3] SPARK was attempted and not finished.** §1.1's account of what GNATprove discharges
  statically is `doc` from the SPARK Reference Manual and User's Guide only. What was established
  in trying to make it `local`: **GNATprove is packaged in no Debian suite** — the `spark` package
  is SPARK *2005*, last seen in stretch, not SPARK 2014 (Debian sources API); it is available as an
  **Alire crate at 12.1.1**, and `alr install gnatprove` yields **FSF 16.1.0**, whose `gnatwhy3`,
  `alt-ergo` and `z3` binaries require **glibc ≥ 2.38** and therefore will not run on Debian 12. A
  trixie image resolves that and was building when this file was finished; the probe written
  against it is in the scratch tree and is **not committed**, because an uncommitted probe that has
  not run is exactly the fake completion this repo's rules forbid. **If amendment B is taken, close
  this first** — SPARK is the one system that both permits arbitrary user predicates and proves
  some of them statically, which is precisely the design being considered, and the remaining work
  is one `docker build` plus the four-subprogram probe already drafted.
- **[g4] Ada's `Predicate_Failure` aspect is described but not measured.** ARM 3.2.4(14.2/4) and
  the `Text_IO` example show it can be a `raise_expression`, making the failure channel
  user-chosen — which is a closer analogue to ticket 15's `result<T, E>` than anything else in
  Part 1. Not probed; noted because it is the obvious next thing to look at if amendment B moves.
- **[g5] Part 2 and Part 4's non-local material came from parallel sweeps** and is marked `doc` or
  `src` as it arrived. Two claims were re-checked locally and upgraded ([L8]); the rest were not.
  The Sail existential encoding of a unit constraint in particular is marked by its sweep as
  *inferred, not run*, and is reported here with that caveat intact.
- **[g6] `Predicate_Failure` aside, no Ada 2022 additions were surveyed.** The ARM text used is
  the Ada 2022 edition, but the ticket's question is about the 2012 design and no attempt was made
  to find later refinements to it.

## Claim → source

| # | Source | Mark |
|---|---|---|
| 1 | Ada Reference Manual (Ada 2022) **3.2.4 Subtype Predicates** — predicate aspects are assertion aspects (1/5); predicate-static forms (15/3–22/3); places predicated subtypes are barred from (25/3–28/3); where checks are performed (31/5); `Assertion_Error` (31.1/4); NOTE 2 on when a Dynamic_Predicate can become false (35/3); `Text_IO` example (45/4) — <http://www.ada-auth.org/standards/22rm/html/RM-3-2-4.html> | **doc** |
| 2 | Ada Reference Manual **11.4.2 Pragmas Assert and Assertion_Policy** — the policy governing whether predicate checks are performed — <http://www.ada-auth.org/standards/22rm/html/RM-11-4-2.html> | **doc** |
| 3 | Ada Reference Manual **3.8.1 Variant Parts and Discrete Choices** (10.1/4) — *"A discrete_choice that is a subtype_indication covers all values (possibly none) that belong to the subtype and that satisfy the static predicates of the subtype"* — <http://www.ada-auth.org/standards/22rm/html/RM-3-8-1.html> | **doc** |
| 4 | Ada Reference Manual **3.4 Derived Types and Classes** — <http://www.ada-auth.org/standards/22rm/html/RM-3-4.html> | **doc** |
| 5 | Ada Reference Manual **3.5 Scalar Types** and **4.6 Type Conversions** — range constraints and `Constraint_Error` — <http://www.ada-auth.org/standards/22rm/html/RM-3-5.html>, <http://www.ada-auth.org/standards/22rm/html/RM-4-6.html> | **doc** |
| 6 | *(unused)* | — |
| 7 | John Barnes, **Rationale for Ada 2012, §2.5 Subtype predicates** — the permitted static forms; *"the predicate in the subtype Even cannot be a static predicate because the operator mod is not permitted with the current instance"*; *"In the case of Dynamic_Predicate, the expression can be any Boolean expression"*; case statements and full coverage checking; Assertion_Policy and Assertion_Error — <http://www.ada-auth.org/standards/12rat/html/Rat12-2-5.html> | **doc** |
| 8 | **SPARK Reference Manual, 3.2.4 Subtype Predicates** — *"Static predicates and dynamic predicates are both in SPARK, but subject to some restrictions"* — <https://docs.adacore.com/spark2014-docs/html/lrm/declarations-and-types.html> | **doc** |
| 9 | **SPARK User's Guide, Specification Features** — `Ghost_Predicate` for predicates mentioning ghost state — <https://docs.adacore.com/spark2014-docs/html/ug/en/source/specification_features.html> | **doc** |
| 10 | Debian sources API — `cduce` last present in **stretch** at 0.6.0-5; absent from buster onward — <https://sources.debian.org/api/src/cduce/> | **src** |
| 11 | CDuce download page — 0.6.0 is the last source release, "for OCaml 4.00 and 4.01"; development tree at `gitlab.math.univ-paris-diderot.fr/cduce/cduce` — <https://www.cduce.org/download.html> | **doc** |
| s1 | Liquid Haskell — `liquid-fixpoint` `Types/Refinements.hs` (`isTautoPred`), `Solver/Worklist.hs`, `Solver/Monad.hs` (`filterValid_`), `Solver/Common.hs` (`askSMT`), `Solver/Stats.hs`; Vazou et al., *Refinement Types For Haskell* (ICFP 2014) Table 1, and *LiquidHaskell: Experience with Refinement Types in the Real World* (Haskell Symposium 2014) Table 1 | **src** + **doc** |
| s2 | F\* — `FStarC.TypeChecker.Common.fsti` (`guard_formula`), `Rel.fst` (`simplify_guard_full_norm`, `smt_ok`), `Options.fst` (`--no_smt`, `--query_stats`); *Proof-oriented Programming in F\** book, `uth_smt.rst`; *Verified Low-Level Programming Embedded in F\** (ICFP 2017) Table 1; Meta-F\* (ESOP 2019) | **src** + **doc** |
| s3 | Nim — manual, *Subrange types* (*"one must specify its limiting values"*) <https://nim-lang.org/docs/manual.html>; `compiler/semfold.nim` (`rangeCheck`), `compiler/sempass2.nim` (`checkLe`, `optStaticBoundsCheck`), `compiler/guards.nim` (`proveLe`, `beSmart`), `compiler/ccgexprs.nim` (`raiseRangeErrorI`), `config/nim.cfg`; DrNim guide (*"combines the Nim frontend with the Z3 proof engine"*) <https://nim-lang.org/docs/drnim.html> | **src** + **doc** |
| s4 | Whiley — Pearce, Utting & Groves, JAR 2022 (*"it employs an intermediate assertion language … discharged using a purpose-built SMT solver"*; Boogie timings); Pearce & Groves, SCP 2015, design decisions D4 and D5; `WhileyCompiler` `wyc/Activator.java`, `wyil/check/FlowTypeCheck.java`, `wyil/interpreter/Interpreter.java` | **doc** + **src** |
| s5 | Dafny — `docs/DafnyRef/Types.md` §5.6.3 (*"This condition is checked by the verifier, not by the type checker"*), `Expressions.md` §9.10, `Attributes.md` §11.1.2; `SubsetTypeDecl.cs`, `NativeTypeAnalysis.cs`, `AnalyzeTypeConstraints.cs`; `docs/VerificationOptimization`; IronFleet (SOSP 2015) Figure 12 | **doc** + **src** |
| s6 | Part 4 survey — Erlang typespec docs and `erl_types.erl`; Gleam `compiler-core/src/type_/prelude.rs` (`bit_array()` with `arguments: vec![]`) and the Gleam tour; Cryptol `docs/RefMan/BasicTypes.rst` and `TypeCheck/TCon.hs`; Sail `doc/asciidoc/language.adoc`; HACL\* `lib/Lib.Sequence.fsti`, `lib/Lib.IntTypes.fsti`; Zig language reference; Ada RM 13.5.1; JLS §10.2; PADS (DDC, POPL 2006) | **doc** + **src** |
| L1 | [`29c_ada_predicate_tiers.sh`](../prototypes/29c_ada_predicate_tiers.sh) §1 — Static_Predicate legal as a case alternative; Dynamic_Predicate rejected; `missing case value: 8`. GNAT 12.2.0 | **local** |
| L3 | [`29c`](../prototypes/29c_ada_predicate_tiers.sh) §2 — `Odd mod 2 = 1` rejected as not predicate-static; `Positive_Ish > 0` accepted; identical runtime cost | **local** |
| L4 | [`29c`](../prototypes/29c_ada_predicate_tiers.sh) §4 — two subtypes of `Float` are one type; two derived types are not | **local** |
| L5 | [`29c`](../prototypes/29c_ada_predicate_tiers.sh) §3 — `Assertion_Error` for both predicate tiers, `Constraint_Error` for the range; without `-gnata` the predicate checks are absent and the range check is not; an O(n) user-declared content predicate is legal | **local** |
| L6 | [`29a_cduce_intervals.sh`](../prototypes/29a_cduce_intervals.sh) — the interval algebra; the exhaustiveness residual; `ldd` and `apt-cache depends` showing no solver; `opam search cduce` finding nothing. CDuce 0.6.0 | **local** |
| L7 | [`29b_cduce_clause_scaling.sh`](../prototypes/29b_cduce_clause_scaling.sh) — checker cost from 10 to 1600 interval clauses, both the exhaustiveness and redundancy paths | **local** |
| L8 | [`29e_binary_structure_in_types.sh`](../prototypes/29e_binary_structure_in_types.sh) — `erl_types:t_bitstr/2` widens any base at or above `U*9` (OTP 28.5); Gleam 1.18.1 rejects `BitArray(32)` and accepts a size mismatch silently | **local** |
| L9 | [`29d_string_vs_bytes.sh`](../prototypes/29d_string_vs_bytes.sh) — C# and TypeScript both substitute U+FFFD by default and throw only on opt-in; .NET serialises `byte[]` as base64, node serialises `Uint8Array` as an index-keyed object. node 22.22.3, .NET 9.0.10 | **local** |
| g1–g6 | Gaps — see [Gaps](#gaps-and-where-i-looked) | gap |

Reference 6 was allocated during drafting and not used; numbering is left intact so that
quotations in the body keep their marks. There is no [L2]: the probe that would have carried it
(GNATprove) is gap [g3].
