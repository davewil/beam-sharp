# 20 — What must the type system model that set-theoretic theory doesn't yet cover?

Type: grilling
Status: resolved 2026-08-13
Blocked by: — (was 11; closed 2026-08-12)

## Question

Ticket 04 established that the exhaustiveness mechanism is solved and shipped — but it also
listed what the theory **has not addressed at all**. These are *untheorised*, not merely
unimplemented, and this language inherits every one of them:

- **Binaries and bitstrings.** There is no `<<>>` typing anywhere in either Elixir type-system
  paper. For a BEAM language this is not an edge case: binaries are the string type, the wire
  format, and a first-class pattern-matching construct with size and unit specifiers. A
  multi-clause head matching on binary patterns is *idiomatic Erlang* and the theory is silent.
- **Improper lists.** Zero mentions in the literature.
- **Recursive and parametric types together.** Elixir's own signature milestone is explicitly
  gated on implementing both efficiently — the roadmap language is that failing to would "make
  the type system unfeasible".
- **Row polymorphism** — relevant if maps are to be typed structurally with extensibility.
- **OTP behaviours** — the callback contract as a typed object.

Decide, for each: does this language model it, approximate it, or exclude it — and if
excluded, what does a programmer write instead?

**Binaries deserve the most attention**, because excluding them quietly makes the headline
feature unusable in the domain the BEAM is most used for. Establish what a binary pattern in a
clause head would have to mean type-theoretically before deciding, rather than assuming it
falls out.

[Ticket 25](25-exemplar-programs.md) sharpens this considerably: of six ordinary BEAM workloads,
**three are binary work** — dynamic web pages, WebSocket frames and event-queue payloads. The most
common things people build on this platform sit precisely where the theory is missing. That should
be weighed before the type system is settled, not after.

Also weigh a product risk named by Castagna himself as an open problem: **readable error
messages and type pretty-printing** — and note that under the map's standing constraint (written
by agents, read by humans) this is a *product* problem rather than a cosmetic one, since the
diagnostic is consumed by an agent in a loop. See [ticket 23](23-what-the-language-owes-an-agent.md). For a language whose entire pitch is "the compiler proves
your clauses cover the input", an unreadable proof failure is not a cosmetic defect — it is
the feature failing in the only place a user meets it.

## Added by ticket 09 — resolved 2026-08-12

**The newtype gap.** [Ticket 09](09-union-representation.md) made naming pure aliasing, so
`Meters` and `Feet` over `float` are **one type**, as are `OrderId` and `CustomerId` over
`string`. The compiler will not catch passing one where the other is meant. Ticket 09 named the
cost explicitly rather than hiding it, and left the remedy here.

Two answers, and this ticket should pick one or say both:

- **Tags** — `{ :meters, float }` and `{ :feet, float }` are genuinely distinct *sets*, so the
  distinction is bought with a tuple rather than with type identity. Free, idiomatic Erlang,
  works today, and needs no theory. Cost: it changes the term, so it is visible at the interop
  boundary and in every pattern that touches the value.
- **Refinement types** — a predicate narrowing a type without changing its representation. This
  is the answer that would *also* settle the DDD-invariant question ticket 22 parked here ("only
  aggregate boundary enforcement is checkable and non-vacuous; the rest needs refinement
  types"), and it may supply a dispatch key for [ticket 16](16-ad-hoc-polymorphism.md), which
  lost nominal resolution to the same decision. Three open questions converging on one mechanism
  is worth noticing before deciding it is out of reach.

**Recursive and parametric together is now half-committed.** The bullet above records that
Elixir's roadmap is gated on implementing both efficiently. Ticket 09 has committed this
language to **equirecursive types with coinductive subtyping and a contractiveness rule** — so
the recursive half is decided, and only the interaction with parametricity is still open here.

## Added by ticket 10 — resolved 2026-08-12

**Value provenance (taint): can the language express that a value arrived from outside, and
should it?**

Ticket 10 went looking for a rule that prevents exhausting the BEAM's atom table (bounded at
1,048,576 by default, ~10,449 gone at a bare boot, never garbage collected) and found that no
rule available to the type system does the job. The reason is sharp:

- **Minting from a literal is not a runtime operation.** `erlc` constant-folds
  `binary_to_atom/1` on a literal binary, so the atom lands in the atom chunk and interns at
  module load — indistinguishable from writing `:foo`
  ([`prototypes/10b_atom_interning.erl`](../prototypes/10b_atom_interning.erl)).
- **So the table can only ever be exhausted by a string built at runtime**, and only when that
  string derives from untrusted input. The operative property is the value's *provenance*, not
  its type.

**No BEAM language expresses this.** Gleam's own documentation states the rule as prose
precisely because it cannot be checked: *"Never convert **user input** into atoms as filling
the atom table will cause the virtual machine to crash!"* — note "user input", not "strings".
Ticket 10 §4 responded by keeping minting out of the prelude, which is containment by omission
rather than by checking, and leaves the underlying question here.

This sits alongside the other entries on this ticket as a capability set-theoretic types do not
supply. It is worth deciding explicitly rather than by default, because the answer is plausibly
**no** — ticket 21 found that opinionated languages control *who may be on the other side*
rather than *what the data is*, and a taint system is a large surface for one hazard that a
prelude omission already blunts. If the answer is no, say so and say what a programmer relies
on instead.

Note the boundary with **[ticket 18](18-boundary-defence.md)**: that ticket owns checks emitted
*where an external term becomes a typed value*. Provenance is a different claim — that the
property travels *with* the value afterwards — which is why it is filed here rather than there.

## Added by ticket 11 — resolved 2026-08-12

**Integer intervals and guard refinement — folded in here from ticket 11.** Ticket 11 was the
keystone and held six decisions; it kept the `dynamic` boundary, the subtyping relation and the
guarantee, and sent this debt here because it is the same *kind* of question as the rest of this
ticket: a capability the type language may or may not have.

The debt comes from ticket 01's prototype. **No function whose totality rests on a guard can be
proved total without it** — which is most arithmetic recursion. `Fib` is the worked case:
`Fib(int n) when n <= 1` and `Fib(int n)` are only exhaustive and only terminating if the type
system can see that the second clause receives `n > 1`. That needs two things ticket 11 did not
decide:

- **Integer interval types** — CDuce has them, so this is a paved path rather than an invention.
- **Guard refinement** — narrowing a parameter's type inside a clause by the guard that selected
  it. Note this is *narrowing by a predicate*, which is the same machinery the refinement-type
  option above would need, so it converges with the newtype gap rather than adding a fourth
  mechanism.

**What ticket 11 settled that bounds this**: patterns over a `term` are **O(1) guard-decidable
only**, and BEAM guards are the vocabulary. Guard refinement therefore has an obvious ceiling —
whatever a BEAM guard can decide is refinable, and nothing else is. Decide whether the *type
language* is allowed to be richer than that ceiling in positions that are not boundary patterns.

**Also from ticket 11**: the top type is spelled **`term`**, and there is **no `dynamic`** — so
none of the gaps on this ticket can be papered over by weakening a type. If binaries are not
modelled, a binary is a `term` and must be matched.

## Notes

HITL. Surfaced by ticket 04's gap analysis. Was blocked by 11, since what the type system *is*
determines what these questions even mean; ticket 11 closed 2026-08-12.

## Status after ticket 16 — 2026-08-12

**Nothing foreclosed.** [Ticket 16](16-ad-hoc-polymorphism.md) refused an ad-hoc polymorphism
construct, so it supplies **no dispatch key**. The newtype gap ticket 09 §5 left open (`Meters` and
`Feet` over `float` are one type) therefore keeps exactly the status it had: if this ticket answers
it with **refinement types**, that answer is still free to supply a discrimination key, and ticket
16 does not compete with it.

Row polymorphism remains ticket 27 §7's refusal, unchanged and not revisited here.

One thing ticket 16 *does* hand over: its §4 decree that the language publishes a serialisation
mapping presumes every modelled shape has one. **Binaries and bitstrings — this ticket's headline
gap — are exactly where that presumption is untested**, and ticket 25 notes three of six ordinary
BEAM workloads are binary work. Whatever this ticket decides about `<<>>` typing owes a line on
what those shapes encode to.

## Datum from ticket 17 — resolved 2026-08-13

**A third independent sighting of binaries as the place precision goes to die**, and this one is in
beam-sharp's own emitted code rather than in the literature.

[Ticket 17](17-pipeline-and-comprehension.md) §3 measured fold under the lowering that ticket
adopted ([`prototypes/17b`](../prototypes/17b_what_fold_costs.erl), OTP 28):

```
-spec join_via_inlined_recursion([integer()]) -> bitstring().   % adopted lowering
-spec join_via_foldl([any()])                 -> binary().      % rejected lowering
```

The accumulator **widens at the recursive fixpoint** — `bitstring()` where `lists:foldl` gave the
tighter `binary()`. It is a sound supertype rather than a wrong answer, and 17 accepted it because
losing the input element type is the worse loss. But note *where* the imprecision landed: at a
binary, in the one operation whose lowering is a synthesised recursion rather than a comprehension.

So this ticket now has three: **no `<<>>` typing anywhere in either Elixir paper** (ticket 04);
**ticket 16 §4's published serialisation mapping presumes every modelled shape has one, and binaries
are exactly where that is untested**; and now **beam-sharp's own emission loses binary precision at
a fixpoint**. Ticket 25 puts three of six ordinary workloads on these shapes.

Whatever this ticket decides about `<<>>` typing should say whether the fixpoint widening is
avoidable — i.e. whether a declared binary type in the surface language would let the compiler emit
`binary()` instead of `bitstring()`, which would make it a *surface* type-system question rather
than a codegen artefact.

## Constraint from ticket 18 — resolved 2026-08-13

**"What one BEAM guard decides in O(1)" is now a load-bearing *set*, not a vocabulary — and binaries
are where it is unspecified.**

Ticket 18 §2 made that set the **admissible foreign return type set**: a foreign function's declared
return type may mention only what a guard decides in O(1), and anything deeper is a compile error at
the declaration. Until now the same phrase was doing lighter work — ticket 09 §4's union
discriminability rule and 11 §2's cap on clause-head patterns. It has now been promoted to deciding
what an FFI declaration may legally *say*.

**This ticket already holds three sightings of binaries as where precision dies** (no `<<>>` typing
in either Elixir paper; 16 §4's serialisation mapping untested exactly there; 17 §3's accumulator
widening to `bitstring()` at the fixpoint). This is a fourth, and it is the most concrete: `is_binary/1`
and `is_bitstring/1` are O(1), but **a binary's declared structure is not** — a binary declared as a
4-byte header plus a payload has no guard that decides it, and binary pattern matching in a clause
head is idiomatic Erlang precisely because that structure is what you match on. So this ticket owes
an answer to: **what may a foreign declaration say about a binary?** `binary` and nothing more, or is
there a structural binary type, and if so how does it cross the boundary — a `ValidateAs<T>` over a
bit syntax pattern?

**Corroboration this ticket can use, from a different runtime.** Elm's admissible port type set,
measured in [`research/18-elm-port-validation.md`](../research/18-elm-port-validation.md), is a
closed whitelist that rejects functions, type variables, `Dict`, `Set`, `Result` and *every* custom
union including a payload-free enum. That set is exactly "types with a decidable structural test" —
**ticket 09 §4's rule reached independently on a different platform**, which is the strongest
external evidence the map has that the discriminability criterion is the right one to build on.

**And a caution from the same file, aimed at whatever this ticket decides about numeric types.**
Elm defends its boundary and *still* admits ticket 06's outcome 3: `_Json_decodeInt` accepts any
finite whole number, so `1e300` crosses an `Int` port and `n + 1 == n`. beam-sharp does not inherit
this — `is_integer/1` is exact and BEAM integers are arbitrary precision — but it is a worked example
of a checking boundary whose *check* was weaker than the type it claimed to enforce, which is the
failure mode any approximate answer to this ticket would risk.

---

## Answer — resolved 2026-08-13

**The type system takes Erlang's full `<<_:M, _:_*N>>` binary grammar with an exact union, makes
`string` a `binary` refined by valid UTF-8, and admits refinements in two tiers cut on what one
BEAM guard decides in O(1) — with the opaque tier's user-declared half later narrowed to a
placement rule rather than a ban.**

The five sightings of *"binaries are where precision dies"* have one cause, and it is not
binaries. Every one traces to a **join that over-approximates on the way in**, never to a
subtraction failing on the way out: `erl_types` collapses `<<_:32>> | <<_:64>>` into
`<<_:32,_:_*32>>`, which admits a 96-bit value nobody declared, and ticket 04's residual then
subtracts correctly and walks forever. The same failure appears in a **second domain** — integer
ranges are quantised onto a fixed ladder, `5..20` snapping to `1..255` — so the finding
generalises: **beam-sharp inherits this platform's type *grammar* and cannot inherit its
*algebra*, in any domain**, because Dialyzer is a success-typing tool that may only ever be
optimistic.

**Binaries (§2).** The surface admits the full grammar with an exact union: a fixed size is a
closed set and provable, a repeating unit is open and takes ticket 12's catch-all, and exact
negation is never needed, since only emptiness and openness must be decided.

**The boundary (§3).** Ticket 18's boundary question answers *"anything the grammar can spell"* —
`byte_size` and `bit_size rem N` are guard BIFs, measured O(1) at 8 B and 8 MiB alike. That lands
opposite to expectation: **binaries need no `ValidateAs` where ticket 26's records do.** Ticket
17 §3's fixpoint widening was never a codegen artefact — its probe declared no spec, and a
declared one lands in the abstract chunk verbatim.

**Serialisation (§4).** `json:encode/1` crashes on non-UTF-8 binaries and on all bitstrings, a
fifth sighting ticket 16 §4 assumed away. So **`string` is `binary` refined by valid UTF-8**, a
bare `binary` encodes as base64, a non-byte-aligned bitstring is a compile-time error, and **a
literal is a `string` by construction**.

**Refinements (§5).** That forces refinements, in two tiers cut on the map's recurring line.
Guard refinements are reasoned about, legal in clause heads and at FFI, and **user-declarable**;
opaque O(n) refinements are **compiler-known only** — ticket 11's *"size a foreign sender
chooses"* at a second site — which **answers the fog's question about adding to the prelude's
second stratum: no**. **Integer intervals join the algebra**, buying guarded partitions without a
catch-all and `-spec` precision — *not* `Fib`.

**A named limit, a refusal, and two corrections.** `is_list` admits `[1,2|3]`, so `list<T>` is
not O(1)-decidable and **improper lists are a named limit** (§6) — but the adopted lowering gives
`function_clause`, so ticket 18's guarantee holds. **Taint is refused**, per ticket 21 (§7). Two
corrections travel with it: **ticket 11 overstated its own debt in both halves** (exhaustiveness
never needed intervals; termination was never promised), and **refinements do not settle ticket
09's newtype gap** — a refinement is a set, so `Meters` and `Feet` as `float where value >= 0`
are still one type, and **09's tuple tag stands**.

### Amended 2026-08-13 by ticket 29

[Ticket 29](29-refinement-type-prior-art.md) checked this ticket against the prior art it was
resolved without. **Nothing decided here is wrong; four things change and one is reopened.**

- **The two-tier cut is a tier-3 divergence, not the O(1) line applied again.** *No shipping
  language cuts refinements on the cost of deciding the predicate*, Ada included, and Ada 2012
  divides on the predicate's **syntactic form** instead — measured on GNAT 12.2, `Odd mod 2 = 1`
  is rejected as not predicate-static while `Positive_Ish > 0` is accepted, identical runtime
  cost and opposite tiers. The relation is **containment**: every Ada static predicate is one
  BEAM guard and the converse fails, so beam-sharp's cut liberalises a line Ada drew syntactically
  for want of a platform-given decidable predicate language.
- **Ada corroborates the structure independently**, having barred its dynamic tier since 2012
  from every construct where the compiler must enumerate or bound the subtype.
- **CDuce is measured at last** — `doc` upgraded to `local`, pinned at **0.6.0 (2017-03-17)** and
  installed via `archive.debian.org`. Its interval algebra is exact at every operation *including
  complement*, and **no SMT library is linked**, so §5's affordability argument is demonstrated
  rather than asserted. 29 also publishes the cost nobody had: below the measurement floor at 40
  clauses, quadratic past ~200.
- **The `string`/`binary` split is a tier-1 borrow this ticket did not claim** — but both
  audiences silently substitute U+FFFD on invalid UTF-8, which is ticket 06's outcome 3 in the two
  languages beam-sharp borrows from, so the *behaviour* is a deliberate divergence. .NET's
  serialiser independently reaches §4's base64 where node does not.
- **A third `erl_types` lossiness**, verified here as `t_bitstr(8,72)` → `<<_:64,_:_*8>>`, and its
  motive is worse than the other two: a **finite-height lattice, exactness traded for termination**
  by the platform's own designers, in the domain this ticket commits to exactness in.
  **beam-sharp escapes it, and the skeleton is the evidence** — ticket 04 made signatures
  mandatory, so nothing iterates to a fixpoint and the residual only shrinks; the skeleton's
  unbounded interval lattice terminates at every clause count measured.

**Reopened for David by that amendment**: whether users may declare *opaque* refinements at all.
Ada permits them and contains them with the same placement rule beam-sharp already applies, so
the ban on *declaring* one may do no safety work the placement rule is not already doing — against
which beam-sharp's checks have **no opt-out** where Ada's switch off with `-gnata`.

### Resolved the same day — the refusal is narrowed to a placement rule (David, 2026-08-13)

**User-declared opaque refinements are barred from clause heads and foreign declarations, and
permitted elsewhere.** Gap [g3] — GNATprove never run — is closed, and it decided this:
**GNATprove 12.1.0 discharges a `Dynamic_Predicate` statically whenever the caller's contract
entails it, including an O(n) content predicate**, the direct analogue of
`binary where valid_utf8`, with the induction carried by an ordinary loop invariant. So Ada's
permissiveness is *not* "permit and check later". Also measured: **SPARK's line is not Ada's** —
`Odd mod 2 = 1` is refused Ada's static tier on form while `Pos > 0` is admitted, and SPARK treats
them identically, so Ada's split is front-end *legality* where SPARK's is *entailment*.

**The evidence and the rule are the same shape.** SPARK proves it where the caller is inside the
verified subset, and at beam-sharp's boundary the caller never is (ticket 21 rules out ruling out
a foreign sender). Interior, caller known — the predicate is a dischargeable obligation.
Boundary, caller unknown — it is unbounded cost with nothing to discharge it against. Accepted
with the cost open-eyed: **beam-sharp pays for every check, always**, where Ada's switch off with
`-gnata`. Three things this owes are recorded above — whether the compiler may call user code at
a boundary, a spelling for the check site, and what happens when the predicate raises (ticket 15's
`result<T, E>`, with Ada's `Predicate_Failure` the precedent). Residual limit: `alt-ergo` would
not run, so a *negative* proof result must not be read as unprovable.

> Decision brief: [`../beam-sharp-eng-186.html`](../beam-sharp-eng-186.html) ·
> [published artifact](https://claude.ai/code/artifact/bdcae90e-5667-47b6-949b-7cb41534bb36)

**The five sightings of "binaries are where precision dies" have one cause, and it is not
binaries.** Every one of them traces to a *join* that over-approximates on the way in — not to a
subtraction failing on the way out. `erl_types` collapses `<<_:32>> | <<_:64>>` into the
arithmetic progression `<<_:32,_:_*32>>`, which admits a 96-bit value nobody declared; ticket
04's residual then subtracts correctly and walks forever, because the type it is subtracting from
was already infinite. Fix the union and subtraction was right all along.

The same failure appears in a **second** domain the moment you look: `erl_types` quantises every
integer range onto a fixed ladder of named Erlang types, snapping `5..20` to `1..255` and
`500..2000` to `1..1114111`. So the finding generalises past this ticket's subject matter:

> **beam-sharp can inherit this platform's type *grammar*. It cannot inherit its *algebra*, in
> any domain.** Dialyzer is a success-typing tool and may only ever be optimistic, so
> over-approximation costs it nothing. beam-sharp makes the opposite promise and pays for every
> widening.

That is measured twice rather than argued once — [`20a`](../prototypes/20a_binary_type_algebra.erl)
and [`20c`](../prototypes/20c_integer_intervals.erl).

## 0. What this ticket turned out to be

Nine items had accumulated here. Five were already dead and the ticket had not noticed:

| Item | Disposition |
|---|---|
| Row polymorphism | Dead — ticket 27 §7's refusal, unchanged |
| OTP behaviours as typed contracts | Dead here — ticket 14 §4 settled it; the residue is the fog patch, not this ticket |
| Recursive + parametric together | Dead — ticket 27 bounded it to a matching problem, not tallying in general |
| Readable diagnostics | Dead here — ticket 23's, already cross-referenced |
| The newtype gap | Dead — **refinements do not fix it**, see §7 |

What was live was **binaries**, **narrowing by a predicate**, and two exclusions. This is the
map's recurring shape — ticket 27 opened "three questions wearing one coat, and only one was
live"; ticket 16 "the hole ticket 05 flagged was half imaginary" — and it is now frequent enough
to be worth stating as a habit rather than a coincidence: *a ticket that has been open while nine
others resolved is mostly other tickets' answers, unrecognised.*

## 1. The line everything is cut on

Four rules on this map are the same rule: ticket 09 §4's union discriminability, ticket 11 §2's
cap on clause-head patterns over a `term`, ticket 18 §2's admissible foreign declaration set,
and now this ticket's refinement tiers. All four ask **what one BEAM guard decides in O(1)**.

Every decision below lands on one side of that line or the other, and *which side* is the whole
content of the decision. Read this ticket as one judgement applied five times, not as five
judgements.

## 2. Binary types — the full grammar, with an exact union

**The surface admits `<<_:M, _:_*N>>` exactly as Erlang spells it.** The premise "there is no
`<<>>` typing" is true of the set-theoretic literature and false of the platform: Erlang ships the
grammar, `erl_types` builds it, and subtyping over it is correct (`<<_:32>> <: binary()` true,
`<<_:64>> <: <<_:32>>` false).

**beam-sharp keeps a genuine union node where `erl_types` collapses one.** `<<_:32>> | <<_:64>>`
stays two members and its residual reaches `none()`. This is not an invention — `erl_types` itself
keeps `<<_:32>> | integer()` exact, because different constructors never merge. The lossiness is
same-constructor-only, so it was a representation choice all along.

Consequences, all forced by rules already on the map:

- **A fixed size is a closed set; a repeating unit is an open one.** So ticket 12's rule applies
  unchanged: a catch-all is legal over `<<_:32,_:_*8>>` and an error over `<<_:32>> | <<_:64>>`.
- **Exact negation is never needed.** `binary() \ <<_:32>>` has no representation, and does not
  need one: the checker must decide whether a residual is *empty* and whether it is *open*, and
  both are decidable on this domain. Ticket 12 already supplies the rule that consumes the answer.
- **Subsumption is not indiscriminability, and conflating them would reject a legal type.**
  `<<_:32>> | <<_:32,_:_*8>>` — the fixed member is contained in the open one, so the union
  *absorbs* to `<<_:32,_:_*8>>`. Legal. `<<_:_*3>> | <<_:_*5>>` — neither contains the other but
  they overlap at every multiple of 15 bits, so no guard separates them and ticket 09 §4 errors at
  the declaration. **The rule is about indiscriminable members, not overlapping ones.**
  Measured, [`20a` §7](../prototypes/20a_binary_type_algebra.erl).
- Intersection needed no decision: it is exact, and in the unit domain it is the LCM —
  `<<_:_*3>> ∩ <<_:_*5>> = <<_:_*15>>`.

## 3. The boundary — the whole grammar is admissible

Ticket 18 §2 asked what a foreign declaration may say about a binary. **Anything the grammar can
spell**, because `<<_:M, _:_*N>>` reduces to two arithmetic tests on the term header:

```erlang
m32(B)   when is_binary(B),    byte_size(B) =:= 4      -> exactly_32_bits;   % <<_:32>>
hdr(B)   when is_binary(B),    byte_size(B) >= 4       -> header_plus_payload; % <<_:32,_:_*8>>
unit3(B) when is_bitstring(B), bit_size(B) rem 3 =:= 0 -> unit_3;            % <<_:_*3>>
```

`byte_size/1` and `bit_size/1` are guard BIFs and both are O(1) — measured, 1M calls on 8 bytes
and on 8 MiB cost 2847 µs and 2108 µs, with the *larger* marginally faster, which is noise
([`20b`](../prototypes/20b_binary_boundary_guards.erl)). A repeating unit is a **modulus**, and a
modulus is arithmetic rather than traversal, which is why the unit half is free.

This lands the opposite way round from the ticket's expectation: **binaries are better behaved at
the boundary than ticket 26's records**, where a map erasure needs key-presence *and* value tests.
The one shape everyone assumed was the platform's awkward corner is the one that needs no
`ValidateAs` at all.

**Ticket 17 §3's fixpoint widening is avoidable, and was never a codegen artefact.** 17 measured
`bitstring()` where `lists:foldl` gave `binary()`, and asked whether a declared binary type would
recover it. It would: 17's probe declared no spec, so Dialyzer inferred one. Ticket 13 has
beam-sharp emitting a `-spec` for every function whose type is known, and a declared spec lands in
the abstract chunk **verbatim** — `-spec join([integer()]) -> binary().`, read back out of the
`.beam` in [`20b`](../prototypes/20b_binary_boundary_guards.erl). The surface now has the
vocabulary to say `binary()`, so it says it.

## 4. Serialisation — `string` is a refined `binary`

Ticket 16 §4 justified generating the encoder on a measured fact: `json:encode/1` fails on tuples
at any depth, **at runtime**, and generation moves that to compile time. **16 assumed binaries were
the safe case. They are not** ([`20e`](../prototypes/20e_json_binary_encoding.md)):

```
json:encode(<<"hello">>)      -> "hello"                    works
json:encode(<<255,254,0,1>>)  -> ** invalid_byte, 255        RUNTIME crash
json:encode(<<0:9>>)          -> ** unsupported_type         RUNTIME crash
```

This is a **fifth** sighting, and it cannot be fixed inside §2's grammar: `byte_size` reads the
header, and *"is this valid UTF-8"* reads the content. O(n), not a guard, not a clause head, not a
foreign declaration. Text-versus-bytes is therefore not a type in the adopted grammar — it is a
**refinement**, which is how §5 arrives forced rather than chosen.

The published mapping:

- **`string` = `binary where valid_utf8`** — encodes as a JSON string.
- **A bare `binary`** encodes as **base64**. Total, never fails.
- **A non-byte-aligned `bitstring`** has no encoding, and reaching the encoder with one is a
  **compile-time error** — 16 §4's move for tuples, applied to the shape 16 overlooked.
- **A literal is a `string` by construction.** The compiler sees the bytes and checks UTF-8 at
  compile time at zero runtime cost; the generated O(n) entry check exists only for binaries built
  or received at runtime. Without this every string literal in the language would pay a
  validation, which ticket 25's HTTP exemplar would break on immediately.

## 5. Refinements — two tiers, cut on §1's line

**Guard-decidable predicates are reasoned about. Everything else is merely established.**

```csharp
type Positive = int where value > 0;      // O(1): reasoned about, legal in a clause
                                          // head, legal at an FFI declaration
type string   = binary where valid_utf8;  // O(n): established once at a boundary by
                                          // generated code, never reasoned about
```

**Users may declare the first tier only.** The second is compiler-known, and `string` is its sole
member today. The reason is ticket 11's, at a second site: 11 refused unbounded work in a clause
head *"whose size a foreign sender chooses"*, and a user-declared O(n) refinement is that same
hazard moved — except worse, because `string`'s check is compiler-known and linear per byte where
an arbitrary user predicate could be quadratic or could fail to terminate.

**This answers a question standing in the map's fog** — *whether a user can add to the prelude's
second stratum* — with a no, and with a reason rather than by omission.

**Integer intervals join the type algebra.** Ticket 08's rule already named them —

> The checker credits any condition it can translate into a type operation. `not :shipped` → set
> difference. `n > 1` → interval refinement. `HasSku(lines, sku)` → nothing.

— without checking whether the platform supplies one. It does not: see the quantisation ladder in
§1. So beam-sharp builds its own, which is affordable because finite unions of integer intervals
are closed under union, intersection and complement with a decision procedure, CDuce ships exactly
this, and it is nowhere near SMT. Ticket 27 had already fenced the cost story by refusing
inference, intersection arrows, bounds and row variables, so this adds a *domain* to the algebra
rather than a *solving* problem.

**What intervals buy, stated precisely, because this ticket's own framing inflated it**: the right
to partition an integer domain by guards without a catch-all, and `-spec` precision that ticket 13
would otherwise widen. **Not `Fib`** — see §7.

What ticket 22 parked here survives in part. Under a guard-only user tier, *"this order has at
least one line"* is `when length(lines) > 0` and is expressible; *"this email address is
well-formed"* is not.

## 6. Improper lists — a named limit, not a modelled shape

`is_list/1` **returns true for `[1,2|3]`**, and it is the only O(1) list guard; the only guard that
rejects one is `length/1`, which is O(n). So **`list<T>` is not O(1)-decidable if it means a
*proper* list**, and ticket 18 §2's use of `list<term>` as the shape `list<Order>` degrades to was
optimistic.

It is not a hole in ticket 18's guarantee. Run an improper list through the inlined recursion
ticket 17 §2 adopted and you get **`function_clause`** — `3` matches neither `[]` nor `[_|_]`, so
ticket 12's retained failure arm fires ([`20d`](../prototypes/20d_improper_lists.erl)). Outcome 1
or 2, never outcome 3. 18's guarantee is *"a foreign term that breaks your types will crash — not
always where it entered, but never silently"*, and this satisfies it exactly: the crash is deferred
from the boundary to the traversal, and it is honest.

So improper lists are a **named limit**, the device ticket 18 used for `sys:replace_state/2`. The
language does not model them, `is_list` remains the emitted guard, and the spec states that a
foreign caller may put one past the boundary and will crash inside the traversal.

## 7. Value provenance (taint) — refused, and two corrections

**Refused.** Ticket 21 established that opinionated languages control *who may be on the other
side*, not *what the data is*, and a taint system is a large surface for one hazard that ticket 10
§4's prelude omission already blunts. A programmer relies on that omission: minting an atom from a
runtime-built string has no prelude spelling, so reaching the hazard requires reaching for the FFI,
which is where ticket 18's boundary already applies.

**Correction to ticket 11.** It filed the `Fib` debt here as *"only exhaustive and only terminating"*
without intervals. **Both halves were overstated.** Exhaustiveness never needed them — `Fib(int n)`
as a second clause is unguarded and matches everything, so the residual empties regardless.
Termination is a promise this language never made: ticket 11's guarantee is coverage, and ticket 12
made partiality the design. Running the case against `erl_types` even *reports* exhaustive — by
accident, because `neg_inf..1` widened to `integer()` and `integer() - integer()` emptied. A future
session re-running that probe would read the artefact as a pass, which is why
[`20c`](../prototypes/20c_integer_intervals.erl) records it explicitly.

**Correction to this ticket's own §"Added by ticket 09".** It hoped refinement types would settle
the newtype gap, and called three questions converging on one mechanism *"worth noticing before
deciding it is out of reach"*. **They do not converge.** Ticket 09 made naming pure aliasing, and a
refinement is just another *set* — so `Meters` and `Feet` as `float where value >= 0` remain one
type, because "non-negative" is not what distinguishes metres from feet. Only a differing predicate
separates them, and no honest predicate does. **09's tuple-tag remedy stands unchallenged**, and
ticket 16's finding that it supplies no dispatch key is unaffected.

## 8. What this hands on

- **Ticket 26** gains a comparison it did not have: binaries need no `ValidateAs` at the boundary
  where records do. If the record erasure is chosen partly on boundary cost, this is the
  cheap-shape control.
- **Ticket 25** loses its headline risk. Three of its six exemplars are binary work and were said
  to *"sit precisely where the theory is missing"* — they sit where the platform already had a
  grammar nobody had checked against a pessimistic algebra. The exemplars now **test** §2's exact
  union rather than await it, and the WebSocket handler is the one to write first, being the
  closed-union case.
- **Ticket 23** gains a diagnostic case: the residual over an exact binary union is a *size*, and
  "the missing pattern is `<<_:64>>`" is machine-readable in a way "the missing pattern is a
  4-byte header plus payload" is not.
- **Ticket 24** gains the observation that an interval refinement is a value generator's domain —
  `int where value > 0` is directly samplable where `binary where valid_utf8` is not.
- **The walking skeleton** owes a sixth codegen obligation and one measurement — see the map's
  fog patch.

## Evidence

| Claim | Where |
|---|---|
| Union is lossy; residual never terminates over binaries; subsumption ≠ indiscriminability | [`20a_binary_type_algebra.erl`](../prototypes/20a_binary_type_algebra.erl) |
| The whole grammar is O(1)-guard-decidable; `byte_size` is O(1); the declared spec is emitted verbatim | [`20b_binary_boundary_guards.erl`](../prototypes/20b_binary_boundary_guards.erl) |
| `erl_types` has no interval domain; the `Fib` artefact | [`20c_integer_intervals.erl`](../prototypes/20c_integer_intervals.erl) |
| `is_list` admits improper lists; the adopted lowering gives `function_clause` | [`20d_improper_lists.erl`](../prototypes/20d_improper_lists.erl) |
| `json:encode/1` crashes on non-UTF-8 binaries and on all bitstrings | [`20e_json_binary_encoding.md`](../prototypes/20e_json_binary_encoding.md) |

All measured locally on **OTP 28.5**, 2026-08-13.

## Amended by ticket 29 — 2026-08-13

[Ticket 29](29-refinement-type-prior-art.md) checked this ticket's decisions against prior art it
was resolved without. **Nothing decided here is wrong.** Four corrections follow; a fifth
(user-declared opaque refinements) is a design question and sits with David.

**1. §5's two-tier cut is a tier-3 divergence, not the O(1) line applied a fifth time.** This
ticket presents the cut as the map's recurring rule reaching a fourth domain, which is true
internally and reads as though the line were borrowed. It is not: **no shipping language cuts
refinements on the cost of deciding the predicate** — not Ada, and not Liquid Haskell, F\*, Nim,
Whiley or Dafny. Ada 2012 comes closest and divides on the **syntactic form** of the predicate
expression instead, measured on GNAT 12.2:

```ada
Static_Predicate => Odd mod 2 = 1      -- error: expression is not predicate-static
Static_Predicate => Positive_Ish > 0   -- accepted
```

Two predicates of identical runtime cost, opposite tiers. The relation is **containment, not
conflict**: every Ada static predicate is decidable by one BEAM guard and the converse fails, so
beam-sharp's cut is a strict liberalisation of a line Ada had to draw syntactically for want of a
platform-given decidable predicate language. **That is the reason to record**, and it is better
than the one given above — the BEAM guard set is a gift this platform makes and Ada's did not.

**2. Ada corroborates the *structure* independently.** Two tiers, the privileged one legal in a
dispatch construct and participating in the compiler's coverage check, shipped since 2012. Ada
bars its dynamic tier from case alternatives, loop parameters, index subtypes, slice ranges and
`'First`/`'Last`/`'Range` — every construct where the compiler must enumerate or bound the subtype,
which is §5's "never reasoned about" arrived at independently on an unrelated platform.

**3. CDuce is measured, not cited — `doc` upgraded to `local`.** §5 leaned on *"CDuce has them, so
this is a paved path"*, inherited from ticket 11 and never checked; the map cites CDuce 88 times
and had never run it. It installs (Debian stretch via `archive.debian.org`), and its interval
algebra is **exact at every operation including complement**: `Int \ 1--10` → `*--0 | 11--*`. **No
SMT library is linked**, at binary or package level, so this ticket's affordability argument —
intervals are affordable *because* they are not SMT — is now demonstrated rather than asserted.
Pinned: **CDuce 0.6.0, built 2017-03-17**. Ticket 29 also publishes the cost nobody had: at ticket
04's 40-clause shape the check is **below the measurement floor** and stays there to 100 clauses,
going quadratic past ~200 with no cliff and no non-termination.

**4. The `string`/`binary` split is a tier-1 borrow this ticket did not claim, and its *behaviour*
is a deliberate divergence.** C# has `string` and `byte[]`; TypeScript has `string` and
`Uint8Array`. But **both audiences silently substitute U+FFFD on invalid UTF-8** and make throwing
opt-in — which is ticket 06's outcome 3 in the two languages beam-sharp borrows from, and exactly
the case §4's entry check exists to prevent. State the divergence. Also: **.NET's JSON serialiser
independently encodes `byte[]` as base64**, reaching §4's mapping on its own, while node encodes
`Uint8Array` as an index-keyed object — so that choice follows C# rather than being unanimous.

**5. A third `erl_types` lossiness, in the binary domain, and its motive is worse than the other
two.** Verified locally on OTP 28.5:

```
t_bitstr(8, 64)  -> <<_:64,_:_*8>>
t_bitstr(8, 72)  -> <<_:64,_:_*8>>     % widened
t_bitstr(8, 200) -> <<_:64,_:_*8>>     % widened
```

The base is capped and everything above it silently widens. §2's two sightings — the union collapse
and the integer quantisation ladder — are **optimism**, which a success-typing tool may indulge.
This one is a **finite-height lattice: exactness traded for termination**, by the platform's own
designers, in precisely the domain this ticket commits beam-sharp to being exact in. That is a
sharper objection to an exact binary union than either sighting this ticket answered, and the spec
must say why beam-sharp escapes it rather than leave it implied.

**It does escape it, and the walking skeleton is the evidence.** Termination of a lattice-climbing
analysis is only at risk where the checker iterates to a fixpoint over an unbounded lattice.
Ticket 04 made signatures **mandatory**, so beam-sharp never infers a type by iteration — the
declared type is given and the residual only ever *shrinks* by subtraction. The skeleton's algebra
([`compiler/src/bs_types.erl`](../../compiler/src/bs_types.erl)) has an unbounded integer lattice
with no height cap and terminates at every clause count measured. **Exactness costs beam-sharp
nothing here because it bought mandatory signatures earlier**, which is the same trade ticket 27
noticed when it observed the frightening results attach to inference.

**Still open, and David's to decide:** whether users may declare opaque (O(n)) refinements at all.
§5 bars it outright, reasoning from ticket 11 that an arbitrary user predicate could be quadratic
or fail to terminate. **Ada permits exactly this and has since 2012**, containing it with the same
placement rule beam-sharp already applies — so the prohibition on *declaring* one may be doing no
safety work the placement rule is not already doing. Against that: beam-sharp's checks have **no
opt-out** where Ada's are switchable off with `-gnata`, so beam-sharp pays for every one, always.
See ticket 29's amendment B for the full argument on both sides, and note its gap [g3] — **SPARK's
GNATprove was never run**, and it is the one system that both permits arbitrary user predicates and
proves some of them statically.

### §5 amended — user-declared opaque refinements are permitted (David, 2026-08-13)

**The blanket refusal is narrowed to a placement rule.** §5 barred users from the opaque tier
entirely, reasoning from ticket 11 that an arbitrary user predicate *"could be quadratic or could
fail to terminate"*. That reason does not survive contact with the prior art: **Ada permits exactly
this and has since 2012**, and it is true of Ada too and did not stop Ada. The rule is now:

> **User-declared opaque refinements are barred from clause heads and from foreign declarations,
> not barred entirely.**

Ticket 11's hazard is specifically about unbounded work in a **clause head** whose size a foreign
sender chooses — and the placement rule already forbids that. The prohibition on *declaring* one was
doing no safety work the placement rule was not already doing.

**What decided it was measured, and it is the most consequential number in ticket 29.** GNATprove
12.1.0 discharges a `Dynamic_Predicate` **statically** whenever the caller's contract entails it —
including an **O(n) content predicate**, the direct analogue of `binary where valid_utf8`, with the
induction carried by an ordinary loop invariant. So Ada's permissiveness is not "permit and check
later"; the arbitrary user predicate is a first-class proof obligation, and a caller that can
establish it pays nothing at run time.

**And the evidence and the placement rule turn out to be the same shape.** SPARK proves it *when the
caller is inside the verified subset*. At beam-sharp's boundary the caller never is — ticket 21
rules out ruling out a foreign sender, and ticket 18's guarantee exists precisely because a foreign
term arrives with no contract. So:

- **Interior, caller known** → the predicate is a dischargeable obligation. Permitted.
- **Clause head or foreign declaration, caller unknown** → it is unbounded runtime cost with nothing
  to discharge it against. Still barred.

The counter-argument, kept because it is the real cost and it was accepted with open eyes:
**beam-sharp's checks have no opt-out where Ada's switch off with `-gnata`**, so beam-sharp pays for
every one, always. Ada can afford permissiveness partly because its predicate checks are absent by
default — which corroborates ticket 18's no-opt-out by contrast, and means a reader arriving from
Ada will expect a policy switch and find none.

**What taking this requires, recorded so it is not rediscovered:**

1. **Whether the compiler may emit a call to arbitrary user code at a boundary.** Ada does, and does
   it invisibly at parameter passing. This is the substantive open question, and it interacts with
   ticket 18's rule that generated code is exactly where a guard is emitted unconditionally.
2. **A spelling for where the check is inserted.** beam-sharp has no `subtype conversion` site to
   hang it on and would need one. Note ticket 29's third finding: in SPARK the obligation lands **at
   the conversion in the caller**, not on the callee — so whatever site is chosen governs the *proof
   obligation* and not merely the runtime check.
3. **What happens when the predicate itself raises.** Ticket 15's `result<T, E>` is the obvious
   answer and Ada's `Predicate_Failure` aspect is the worked precedent.

**One consequence the map must not be left contradicting**: §5's answer to the fog's *"can a user add
to the prelude's second stratum"* was **no**, justified by users being unable to declare opaque
refinements. That justification is gone. A user-declared opaque refinement is something the compiler
**generates a check for**, which is the property ticket 15's surviving criterion for stratum 2 turns
on — so the question is **reopened**, and reopened sharper: it is now about whether *prelude
membership* and *compiler-generated* are the same thing, when they have just been shown to come
apart.

**Residual limit on the evidence**: `alt-ergo` would not run in ticket 29's environment, so its probe
used `cvc4,z3` only. Every obligation was discharged without it, but a *negative* result on a harder
predicate must not be read as "SPARK cannot prove it" until alt-ergo runs.
