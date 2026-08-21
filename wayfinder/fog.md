# Not yet specified — the open patches

> **Split out of [`map.md`](map.md) on 2026-08-15**, which had reached 1,564 lines while its own
> comment promised *"one line per closed ticket"*. The split was verified to reconstruct the
> original byte-for-byte; **nothing here was edited, only moved**. `map.md` carries the index —
> headline, ticket number and topic tags per entry — and this file carries the bodies.
>
> Read the body before assuming a direction. Several patches wait on the module system, which is the most load-bearing of them.

## Not yet specified

<!-- in-scope fog: real, but not yet sharp enough to phrase as a ticket -->

- **Does a refined parameter get a boundary guard?** — raised by F2 on 2026-08-16 and written up as
  [ticket 46](issues/46-refined-parameter-at-the-boundary.md) ·
  [ENG-218](https://linear.app/davewil/issue/ENG-218). `type Octet = int where value >= 0
  and value <= 255` now narrows a parameter and the emitted `-spec` says `0..255`; nothing enforces
  it against a caller the compiler has never seen. Measured at the `ibs` prompt: `Classify(300)`
  returns `:reserved`, because the clause that matches lowers to `when Bs@r1 >= 9` and no upper test
  exists anywhere in the module. **Inside beam-sharp nothing is wrong** — site 1 rejects an `int`
  passed where an `Octet` is declared — so this is ticket 18's *"forging the tag is caught, forging
  the payload is not"* arriving on a new shape rather than a hole in the language. It is fog rather
  than a defect because 18 states the exported check is *"genuinely optional… this ticket's
  decision"*, so a feature may not take it; and it is worth deciding rather than parking because
  20 §5 puts a guard-decidable refinement in the O(1) tier precisely so that it CAN be checked
  cheaply, and `boundary_guards/4` already emits the record half at a measured +14 bytes. The
  interesting sub-question is the second narrowing already in that code: a clause written
  `Classify(>= 4 and <= 7)` tests both bounds itself, so a guard on it is dead weight, while
  `Classify(>= 9)` tests one and needs the other.
- **The boundary manifest's concrete format** — new with ticket 24, which gave it three consumers
  (the boundary classification, the missing-observation advisory, and the elision list) and
  deliberately named it one artefact rather than three, since 18 §5 already priced a build artefact
  as something the spec must define, version and keep stable. ~~Not yet sharp because what a consumer
  wants of it is exactly what ticket 25's exemplars would show, and none exist.~~ Note it is the
  map's first capability serving testing alone; it clears the scope bar on the 2026-08-13
  clarification as *one capability the language owes its author*, not the ecosystem track.
  **THE BLOCKING PREMISE IS STALE — 2026-08-13. Two exemplars now exist**
  ([`25a`](prototypes/25a-http-api-server.md), [`25b`](prototypes/25b-websocket-handler.md)), so
  "none exist" is simply no longer true, and this patch is unblocked whether or not it is yet
  sharp. **This is the second time the map has held a patch behind a premise nobody re-tested** —
  the walking skeleton's *"cannot be phrased sharply until the language surface exists"* was found
  to be *"true only of the whole surface… and it was invisible because nobody re-tested the
  claim."* Recorded here rather than repeated. What the two exemplars actually show a consumer
  wants: **the elision list is the half with teeth**, since 25a's route table and 25b's frame
  decoder both dispatch on shapes whose boundary guards 18 would elide, and a test of those paths
  then measures nothing; and **the client-API boundary is not observable for a raw `receive`
  process** — 25b's connection loop is not a `gen_server`, so 24's "client API against a running
  process" has no client API to name, which the manifest must either classify or admit it cannot.

- **The walking skeleton**: which slice of the spec it implements, and what language the
  compiler itself is written in. Cannot be phrased sharply until the language surface exists.
  **The first slice is BUILT (2026-08-13) — see Decisions-so-far. Two debts below are struck
  through as paid; the rest stand, and now have somewhere to be measured.**
  ~~One requirement is already known: it should **measure checker cost at the clause counts the
  showcase implies**. Ticket 04 found Etylizer's pathological inputs are `case` expressions
  with 40+ branches — precisely the large multi-clause `handle_info` this language advertises.~~
  **PAID 2026-08-13** (`compiler/bench/bs_bench.erl`, OTP 28.5, JIT warmed, 20 reps): the
  exhaustiveness check is **linear through the advertised shape and costs 59 µs at 40 clauses** —
  8.5 µs at 5, 29 µs at 20, 59 µs at 40, 151 µs at 80, all at 1.3–1.9 µs/clause. **There is no
  cliff where ticket 04 feared one.** It does begin to bend at **160 clauses (656 µs, 4.1
  µs/clause)**, which is the first observed sign of the complexity bound ticket 04 said does not
  exist — worth re-measuring when the algebra gains records and binaries, since both widen the
  product decomposition.
  **Ticket 11 adds a second requirement**: the skeleton must **generate at least one
  `ValidateAs<T>`**, over a recursive type. It is the first codegen obligation whose cost is
  entirely unmeasured — a synthesised O(n) structural traversal — and it stacks with the
  recursive-type measurement ticket 09 already asked for. ~~**Ticket 12 adds a third**: measure the
  retained failure arm at showcase clause counts. It was measured at 40 bytes (4.8%) on a
  two-clause function; the decision to keep it everywhere was taken without knowing the cost on a
  40-clause `handle_info`, which is the shape this language advertises.~~
  **PAID 2026-08-13, and it lands the reassuring way**: the arm is **constant-size, not
  proportional** — ~15 bytes of the `Code` chunk regardless of clause count, so its share *falls*
  as clauses grow: **10.6% at 2 clauses, 4.95% at 20, 2.76% at 40**. Ticket 12 kept it everywhere
  while worrying what forty clauses would cost; forty clauses cost proportionally less than two.
  Two honesty notes. The absolute two-clause figure here (11 bytes) does **not** reproduce ticket
  12's (40 bytes) — different harnesses measuring different things, and neither has been reconciled
  against the other, so treat the *shape* of this result as the finding and not the constant. And
  the first run of this benchmark was an **artefact**: with every clause returning the same atom
  the optimiser folded them all into the catch-all, pinning the baseline at 70 bytes for 2 clauses
  and 40 alike and reporting the arm as 66% of the chunk. Distinct return values fixed it. Recorded
  because the artefact was plausible and would have been believed. **Ticket 13 removes one
  constraint and adds two requirements.** Removed: **the compiler's host language is no longer
  constrained** — the emission contract is abstract-format forms, and `erlc +from_abstr` builds
  from serialised text with no `.erl` present, so the skeleton need not be a BEAM program. Added:
  it owes the **CI corpus** proving the pinned OTP range (current and previous two majors), and it
  owes **confirmation that `+from_abstr` exists on the oldest supported release** — only OTP 28.5
  is installed here, so the range is provisional until measured. Note the third measurement
  requirement above is now moot in one direction: ticket 12's failure arm cannot be suppressed on
  this target, so what remains to measure is its cost at showcase clause counts, not whether to
  keep it. **Ticket 14 adds two things to the CI corpus**, because the language now ships a *model
  of OTP* rather than only emitting for it: the **behaviour contracts** it checks callback
  signatures against (§4) and the **system-message shapes** in the compiler-known prelude stratum
  (§6). Whether either differs across the pinned range is **unmeasured** — only OTP 28.5 was
  installed when 14 was resolved. **Ticket 27 adds a fifth measurement and removes a worry.**
  ~~Added: if ticket 16 later wants **bounded type variables**, bounds are the feature that turns
  instantiation from matching into constraint solving, so their cost must be measured at showcase
  clause counts before they are accepted.~~ **RETIRED 2026-08-12 by ticket 16 §5** — bounds are
  refused outright, not deferred: a bound is undischargeable here because monomorphisation is
  closed by 13 and dictionary passing by 09, so the skeleton never owes that number and
  instantiation stays matching, not solving. Removed: the ticket's own fear that
  *recursive plus parametric* would be the combination that breaks the budget is now bounded by
  the four things 27 refused — no inference, no intersection arrows, no bounds, no row variables —
  so what the skeleton measures is a matching problem, not tallying in its general form.
  **Ticket 15 adds a sixth measurement and a new obligation.** The **compiler-emitted foreign
  wrapper** is the fourth codegen obligation, and the first whose cost is per *call site* rather
  than per type — it stacks with `ValidateAs<T>`'s traversal, and a program calling Erlang in a
  loop pays it repeatedly where the traversal is paid once. Also owed: confirmation that the
  emitted `try` survives the abstract-format path unchanged across the pinned OTP range, since
  ticket 13's `-spec` widening was already found to be silent about what it loses.
  **Ticket 16 adds a seventh measurement and retires the fifth.** Added: the generated
  **serialisation encoder** (§4) is the fifth codegen obligation and the second whose cost is a
  synthesised structural traversal — it stacks with `ValidateAs<T>` over the *same* recursive type,
  so the skeleton should measure them together rather than separately. Retired: 27's
  bounded-type-variable measurement, above — bounds are refused, not deferred.
  **Ticket 17 adds an eighth, and it is the first that is a cost rather than a capability.**
  17 §2 buys emitted *precision* by **inlining** every compiler-known prelude collection operation at
  every call site, and it priced only the benefit. The skeleton owes the **code-size** number at the
  pipeline lengths the showcase implies — this is a straight trade of emitted size for emitted type
  information, and no codegen obligation so far has had to be weighed that way. It also owes a check
  on the assumption 17 §8 records rather than establishes: **inlining a prelude function into a
  caller means a change to the prelude does not reach that caller without recompiling it**, which
  runs against ticket 13's aggregate-granularity hot loading. Probably benign because the prelude is
  compiler-known, but unverified.
  **Ticket 18 adds a ninth, and it is the first argued from *frequency* rather than from cost.**
  `ValidateAs<State>` inside the compiler-emitted `code_change/3` (18 §3) is an O(n) traversal
  affordable *because hot upgrades are rare*, not because it is cheap — so the skeleton owes the
  upgrade's cost at a realistic state size, which is the number that would falsify the reasoning
  rather than confirm it. Two smaller debts from the same ticket, both from
  [`prototypes/18a`](prototypes/18a_guard_cost.md): the **JIT-emitted native size** of a guard is
  unmeasured (§1b tried and failed — `erlang:memory(code)` varies by tens of kilobytes with load
  order alone), and every timing there is a **tight monomorphic loop with a warm cache**, so nothing
  says what a boundary guard costs at a cold or megamorphic call site. Note also that 18 §4's
  function-local rule makes the guard count predictable per function, so the corpus can *count* the
  emitted guards rather than estimate them.
  **Ticket 20 adds a tenth and an eleventh, and the eleventh is the first that is a cost in the
  *checker* rather than in emitted code.** Added: **`string`'s UTF-8 entry check is the sixth codegen
  obligation**, and the third whose cost is a synthesised O(n) traversal — it stacks with
  `ValidateAs<T>` and with 16's encoder, and unlike either it lands on the language's most-passed
  value, so the skeleton should measure it on a realistic string-handling path rather than in
  isolation. Note 20 §4 removes the obvious worst case by making a **literal a `string` by
  construction**, so what is owed is the runtime-built and foreign-received cost only. Added: **the
  exact binary union and the interval domain are two new algebra components the platform does not
  supply** — 20 measured that `erl_types` collapses same-constructor binary unions and quantises
  integer ranges, so beam-sharp implements both itself. Neither is expensive in principle (finite
  unions of intervals have a decision procedure; binary unions are pairs of integers), but both feed
  the exhaustiveness algorithm ticket 04 found has **no complexity bound**, and the skeleton owes the
  residual-computation cost at showcase clause counts over a *binary* subject — which is exactly the
  40-clause `handle_info` shape, now with a second domain in the algebra.
  **Ticket 23 adds a twelfth, and it is the second whose cost lands in emitted code rather than in
  the compiler.** 23 §6 attaches an `error_info` **cause map** to every compiler-*generated* check —
  boundary guards, `ValidateAs<T>`, `string`'s UTF-8 entry check — so the skeleton owes its
  **code-size cost at showcase clause counts, stacked on ticket 12's failure arm**. It is the same
  measurement 12 already has a harness for, and the honest worry is that a cause map is plausibly
  proportional to the type it describes where 12's arm was constant. Note the marker on the other
  side of the ledger: 23 §6 deliberately leaves the arm over *user-written* clauses untouched, so
  what is being measured is the generated-code sites only.
  **Ticket 25's third exemplar adds a thirteenth item, and it is the first that is a *blocker on the
  next increment* rather than a measurement.** Measured against the skeleton
  ([`25c_residual_probe.sh`](prototypes/25c_residual_probe.sh)): **the surface cannot state that a
  wire field has a width.** A parameter is declared `int`, ticket 20 put intervals in the *type*
  language, and intervals arise only from guards — which refine a clause, never a signature. So an
  octet bounded by a guard leaves the residual `int <= -1 | int >= 256`, values the wire cannot
  produce, and every wire dispatch is open. The skeleton README names
  `type Octet = int where value >= 0 && value <= 255;` as **the next slice increment**, and landing
  it alone would convert every wire dispatch to a **closed** residual — 252 unnamed values for an
  AMQP frame type, ~2³² for a class/method pair — which ticket 12 §2 makes an error.
  **So interval *patterns* must land in the same increment as interval *refinements*, or wire
  parsing breaks.** Neither ticket records that coupling; it is the sharpest thing 25c found.
  Two smaller skeleton facts from the same probe: **the skeleton does not implement ticket 12 §2 at
  all** — it accepts a catch-all over a genuinely closed atom residual, exit 0, no diagnostic, the
  first known place the skeleton is behind a closed decision; and **the residual does not scale as a
  diagnostic**, 40 singleton clauses producing **41 disjoint intervals on one line**, exact per
  ticket 20's algebra and useless to read or to synthesise a clause head from, which is what ticket
  23 makes it for. That last one is the first case in the map where **exactness and legibility pull
  apart**, and it argues the diagnostic should report the residual's shape at some width rather than
  enumerate it.
- **The typed model of OTP itself** — new with ticket 14, and distinct from the corpus that proves
  it. The language knows behaviour contracts and system-message shapes as types. Open: which
  behaviours ship built in (gen_server, supervisor, application, gen_statem, gen_event), how a
  **user-declared** contract is spelled — ticket 21 named Roc's `requires` as the stealable
  mechanism and 14 left generalising it as purely additive — and what happens to a *library*
  behaviour defined in Elixir. Not yet sharp enough to ticket, because it hangs on the prelude
  question below. **Ticket 18 §3 adds a second axis to this patch, and it is not the one the patch
  currently asks about.** Beyond *which* behaviours ship built in and how a user declares one, the
  compiler now **emits code inside the callbacks it knows**: `code_change/3` carries a generated
  `ValidateAs<State>`, decided because that entrance is rare where the per-message path is not. So a
  behaviour contract is not only a signature the compiler checks against — it is a set of callbacks
  the compiler may *write into*. Open with it: which other known callbacks earn emitted code, and
  what a **user-declared** contract can ask the compiler to emit, given ticket 21 named Roc's
  `requires` as the stealable mechanism and 14 left generalising it as purely additive.
- **The language's name.**
- **Does `using` get an alias?** — → **[ticket 47](issues/47-import-alias.md)**, raised 2026-08-16
  by ticket 41 on resolving it. C# has three import tiers and 41 settled two: `using Shop` is
  short-qualified (§5), `using Shop.Orders` is unqualified (§2). The third — `using Orders =
  Shop.Orders` — was parked, and **41 recorded that §2 inverted the argument against it** rather
  than leaving it merely unanswered. An alias was shelved as a pure *read* cost, because the reader
  had to find the alias line to learn what `Orders` meant; that assumed the competing form was a
  **qualified** name carrying its source in the call. §2 made the competing form a **bare** name
  carrying no source at all, so against that an alias is the *more* explicit spelling. Open:
  whether it exists; whether it aliases a module, a function or both, since §2's two import tables
  are keyed differently; and whether it **resolves** §2's ambiguity rule rather than merely
  abbreviating — if two imported modules both export `Orders`, an alias may be the only spelling
  for that program, which is a capability argument and not a convenience one. The exemplars do
  **not** force it: they write `List.Fold(…)` and `Orders.All()`, both of which §5's
  short-qualified tier already covers, which is why 41 could resolve without it.
- **Where DDD invariants live** — not commands, not types. An `Invariants` module, refinement in
  the type declarations, or nothing. **Ticket 20 §5 settles half of it and splits the rest by a
  sharp line**: refinement in the type declarations *is* available, but only where the predicate is
  a BEAM guard. So *"this order has at least one line"* is `when length(lines) > 0` and lives in the
  type; *"this email address is well-formed"* is O(n), is not user-declarable, and still has
  nowhere to live. What remains is therefore narrower than the patch was written for — it is only
  about the **non-guard-expressible** invariants, and ticket 22 inherits that narrowing.
  **Amended 2026-08-13 by ticket 29's amendment B**: the non-guard-expressible invariant *is* now
  user-declarable as an opaque refinement — just not in a clause head or a foreign declaration. So
  this patch narrows again: what still has nowhere to live is only the invariant a user wants
  enforced **at the boundary**, which is exactly where the placement rule bars it.
  **Amended 2026-08-13 by ticket 26 §1, which splits this patch's subject in two and settles the
  half nobody had named.** *Aggregate identity* — that an `Invoice` cannot be passed where an
  `Order` is wanted — is now enforced, by a minted tag, checked at compile time and at the boundary
  for +14 bytes. That was never written down as part of this patch and was silently missing from the
  language: under ticket 09 as written, two records with the same field set were one type. What
  remains here is *construction-time* invariants only, and the reason they are hard is now precisely
  stated rather than assumed: **the language guarantees shape, never provenance** (09 §5, ticket 21,
  re-verified in [`26b`](prototypes/26b_struct_field_set.exs) — a hand-built map compares `==` to a
  real Elixir struct). So no tag, keyword or type can express *"this was validated on the way in"*;
  only ticket 15's `result<T, E>` and ticket 18's boundary guards can, and they say it about a
  *call*, not about a value's history. **Do not re-raise aggregate identity here — it is decided.**
- **How a user-declared opaque refinement is actually checked** — new with
  [ticket 29](issues/29-refinement-type-prior-art.md)'s amendment B, recorded in full on
  [ticket 20 §5](issues/20-untheorised-term-shapes.md). Three owed items: **whether the compiler may
  emit a call to arbitrary user code at a boundary** (Ada does, invisibly, at parameter passing —
  and it interacts with ticket 18's rule that generated code is exactly where a guard is emitted
  unconditionally); **a spelling for the check site**, since beam-sharp has no subtype-conversion
  site to hang one on, and SPARK puts the obligation at the *conversion in the caller* rather than
  on the callee, so whatever site is chosen governs the proof obligation and not merely the runtime
  check; and **what happens when the predicate raises** — ticket 15's `result<T, E>` the obvious
  answer, Ada's `Predicate_Failure` the worked precedent. The first is sharp enough to ticket on its
  own. It is left as fog because the *site* has no answer until
  [ticket 26](issues/26-data-modelling.md) settles how a named type carrying a `where` clause is
  spelled and what it erases to — an inference, not an established dependency — and deciding item 1
  alone would fix the visible half of a rule whose invisible half is still open.
- **Stdlib shape as a principle** — Erlang-ish flat modules, C#-ish namespaced statics, or
  Gleam-ish. Breadth is out of scope; the shape is not. **The prelude now has known contents**
  from ticket 10 — `type bool = true | false;`, `type option<T> = T | :nothing;`,
  `ParseAtom<T>` and `ToExistingAtom` — which makes "what is in the prelude versus a module you
  import" a live sub-question rather than a hypothetical one. **Ticket 11 adds `ValidateAs<T>`**,
  and with it a sharper version of the question: `ParseAtom<T>` and `ValidateAs<T>` are
  compiler-generated rather than written, so the prelude is not only a set of definitions but a
  set of **codegen obligations** — and where those are documented, and whether a user can extend
  them, is unanswered. **Ticket 14 §6 answers half of this and sharpens the rest.** Answered: the
  prelude has **two strata**, modelled on Elixir's `Kernel.SpecialForms` — ordinary aliases a user
  could have written (`bool`, `option<T>`) versus a **compiler-known** stratum they could not
  (`ParseAtom<T>`, `ToExistingAtom`, `ValidateAs<T>`, and now OTP's `Down`/`Exit`/`Timeout`), which
  wins resolution and which the compiler draws inferences from. ~~Still open: **whether a user can
  add to the second stratum**~~ — ~~**ANSWERED 2026-08-13 by ticket 20 §5: no.** A user may declare a
  refinement whose predicate is a BEAM guard, and may not declare one that is O(n); the second
  stratum is compiler-known, and 11's refusal of unbounded work *"whose size a foreign sender
  chooses"* is the reason, applied at a second site.~~ **REOPENED the same day**, and sharper than
  before: ticket 20 §5's amendment permits users to declare **opaque** refinements after all
  (barred only from clause heads and foreign declarations), so the justification for the "no" is
  gone. A user-declared opaque refinement is something the compiler **generates a check for** —
  which is the property ticket 15's surviving criterion for stratum 2 turns on — while plainly not
  being in the prelude. **So the question is no longer "may a user add to stratum 2" but whether
  *prelude membership* and *compiler-generated* are the same thing at all**, given they have just
  been shown to come apart. Still open too: how the two strata are documented
  differently, and what "in the prelude versus in a module you import" means once the answer is a
  compiler guarantee rather than a definition. **Ticket 20 also adds `string` to stratum 2** and with
  it a fourth candidate criterion, since `string` is a *type* whose membership is established by
  *generated code* — it satisfies 15's "the compiler draws inferences from it" and 16's ground-type
  test alike, so it does not discriminate between the surviving candidates, but any criterion
  proposed from here must admit it. **Ticket 27 moves the boundary.** With real type variables, `List.Map` and friends
  are now definitions **a user could have written**, which is stratum 1's own test — so the
  collection library drops out of the compiler-known stratum and the question becomes narrower and
  sharper: stratum 2 now holds only the *codegen obligations* (`ParseAtom<T>`, `ToExistingAtom`,
  `ValidateAs<T>`) and OTP's system-message shapes. 27 also gives stratum 2 its first hard rule —
  **a codegen obligation requires a ground type argument** — which is a property no stratum-1
  definition has, and is therefore a candidate for what actually distinguishes the two strata,
  rather than "could a user have written it". **One concrete obligation is owed here, not just a
  question**: ticket 15 §1 rejects `atom | :nothing`, so **`ToExistingAtom` must be respelled** —
  a tagged failure member, or a success type narrower than the atom top. Left as a spec-drafting
  detail rather than a ticket because it is one prelude signature with two known-good answers, but
  it is *owed*, and it lives here rather than only as a correction on closed ticket 10.
  **Ticket 15 populates both strata further and adds a wrinkle**: `result<T, E>` joins stratum 1 (an ordinary parametric alias), `foreign_error` joins
  stratum 2 — but `foreign_error` is *not* a codegen obligation and takes no type argument, so it
  fails 27's candidate criterion while still belonging to the compiler-known stratum. **So the
  distinguishing property is neither "could a user have written it" nor "requires a ground type
  argument"**; the open question is sharper than either. A third candidate: stratum 2 is what the
  compiler *draws inferences from*, whether or not it generates it. **Ticket 16 narrows this by
  one.** Its §4 adds a *fifth* codegen obligation — a serialisation encoder generated against a
  language-published mapping — which satisfies **both** 27's candidate (it requires a ground type
  argument) **and** 15's third (the compiler draws inferences from it). Since `foreign_error`
  satisfies only the third, **15's candidate survives a second test and 27's does not**. Still not
  a settled criterion, but the field is down to one live answer. 16 also leaves one *named* debt
  here beyond `ToExistingAtom`'s respelling: what the published serialisation mapping says about
  the shapes ticket 20 calls untheorised — binaries and bitstrings above all, since 25 puts three
  of six ordinary workloads there. **Ticket 25 adds a SECOND named debt to that mapping, measured
  2026-08-13, and it inverts the direction 16 §4 was reasoning in.** 16 §4 cited `json:encode/1`'s
  *refusal* of tuples as the reason generation is owed — but the language's own types **force the
  mapping to define a tuple encoding rather than reject one**: `result<T, E>`'s failure member is
  `(:error, E)` and `ValidationError` is a tuple, so a 422 response body and any response embedding
  a `result` are both unencodable ([`25a`](prototypes/25a-http-api-server.md), measured:
  `{crashed, error, unsupported_type}`). Serialisation is admitted **by decree**, so a published
  mapping saying `(:error, E)` → `{"error": …}` settles it without disturbing ticket 15's tag —
  which is why this is a debt on the *mapping* and not a reopening of 15. Note the one part that
  needs no decree: **`ValidationError` should simply be respelled as a record**, since 26 shipped
  records the same day CONTEXT.md was still calling it *"a record candidate if one is ever
  introduced"*, and a record erases to a map. Third debt, smaller and also 25a's: **a record's
  minted tag reaches the serialiser** as ordinary data, so the mapping must say whether the wire
  format carries `"kind":"Shop.Orders.Order"` — and "always strip" is not obviously right, since a
  discriminated union on the wire is exactly what a tag is for. **Ticket 17 adds a third candidate criterion, and it is the
  first that is observable in the output**: stratum 2 is **what the compiler inlines**. 17 §2
  established that emitted precision is a privilege of inlining — a compiler-known `List.Map`
  recovers `[integer()] -> [binary()]` where an identical user-written generic emits `[any()]` — so
  the two strata are not merely documented differently, they **produce measurably different emitted
  types**. Unlike 27's criterion (which `foreign_error` fails) and 15's (a claim about the
  compiler's inferences), this one can be checked by reading the `.beam`. Whether it *coincides*
  with 15's surviving criterion or cuts across it is unexamined: `foreign_error` is a type, not an
  operation, so it has nothing to inline and the test may simply not apply to it — which would mean
  the criterion is well-formed only for the stratum's *operations*, and the stratum's *types* need a
  separate one. **Ticket 28 rules out one candidate answer on entirely new grounds, without settling
  the criterion.** Its disambiguation rule keys on the codegen obligations by *token class*, so
  **stratum 2's membership is now fixed at lex time** and the set must be closed and known before
  parsing begins — a user cannot introduce a name that takes an instantiation bracket. That kills an
  **open, user-extensible stratum 2** on *grammar* grounds, where ticket 20 §5 had killed it on
  safety grounds and then narrowed that refusal to a placement rule. Note it constrains only the
  bracket-taking members: it says nothing about whether `foreign_error` or `string` belong, which is
  where the live question actually sits.
- **Consuming Gleam and Elixir libraries** — possible, and at what ergonomic cost. **Sharper
  after ticket 10 §7**, which measured Gleam's representation rather than reading it: fieldless
  variants are bare atoms, variants with fields are tagged tuples, PascalCase becomes
  snake_case, `Nil` is the atom `nil` and `Result` is `{ok, _} | {error, _}`. So a Gleam type is
  already a structural shape beam-sharp can write directly — the ergonomic cost looks low, and
  the open part is what happens to Gleam's *nominal* intent when beam-sharp has no nominality to
  receive it.
  **THE ELIXIR HALF IS NOW A TICKET — 2026-08-21**, raised by David wanting a Req exemplar:
  → **[ticket 50](issues/50-naming-a-foreign-struct.md)**. Measured, the FFI already *names* an
  Elixir module — `using :'Elixir.String'` compiles, since ticket 32 made the module an atom — and
  a foreign map reads through `:maps.get` as a `term`. What has no answer is the **struct**: Req
  returns `%Req.Response{}`, a map tagged `__struct__`, where a beam-sharp record mints `Kind` from
  its *own* qualified name and therefore cannot match it. Gleam's half stays here; its shapes are
  tuples and atoms, so it never asks the question.
- **Laziness and `stream<T>`** — new with ticket 17 §5, and **deferred rather than refused**
  (David: *"defer lazy, we will want it"*). Nothing is lazy today: 17's fusion measurement showed
  the intermediate-list argument is already answered by the lowering, at no cost in precision. What
  the deferred option needs, recorded so it is not rediscovered: **compiler-known status in the
  prelude's second stratum with a fused lowering of its own** — without it, `xs |> Stream.Map(f)` is
  an ordinary user-level generic and degrades to `[any()]` under §2's two-tier rule, which is the
  worst outcome (it works, and is opaque); **an answer to how a lazy source meets ticket 14's
  process model**, since a stream over a mailbox or a socket is a process rather than a data
  structure, with different failure semantics; and **a position on early termination**, the one case
  fusion does not cover — `|> List.First()` after a map over a million rows still traverses a
  million rows. Cheap to add *because* 17 §1 chose qualified names: `Stream.Map` is a new module and
  nothing existing changes.
- **Bootstrapping — how much of beam-sharp is written in beam-sharp** (David, 2026-08-13). Three
  axes, and the map has **nothing** on any of them: a grep for self-hosting or bootstrapping returns
  zero, and `FFI` appears only as a *constraint* on what a foreign declaration may promise, never as
  a surface with a home.

  **The Elixir precedent is measured, not cited** (local, Elixir 1.19.5 — `module_info(compile)`'s
  source extension per module):

  | Erlang (`.erl`) | Elixir (`.ex`) |
  |---|---|
  | `elixir_parser`, `elixir_tokenizer`, `elixir_erl`, `elixir_bootstrap`, `elixir` | `Kernel`, `GenServer`, `Supervisor`, `Agent`, `Task` |

  **Elixir never self-hosted its front end.** Fourteen years in, the tokenizer, parser and emitter
  are still Erlang — `yecc` and `leex`, the same tools ticket 13 chose the skeleton's host for.
  What *is* written in Elixir is the standard library and the OTP layer. **That splits this patch
  the way the evidence does rather than the way ambition would**, and it says the achievable and
  valuable target is (c), not (a).

  **(a) The compiler in its own language, emitting BEAM bytecode.** *Optional, and ticket 13 already
  removed the pressure* — the emission contract is abstract-format forms and `erlc +from_abstr`
  builds from serialised text with no `.erl` present, so the host language is free and self-hosting
  buys no capability. What it would buy is **evidence**: a compiler is the hardest exemplar there
  is, and ticket 25's set does not contain one. Against that, the front end is where `leex`/`yecc`
  and `merl`'s parse-transform-based `?Q` live, which is precisely what Elixir kept in Erlang and
  what ticket 13 named as the reason the skeleton is an Erlang program. **So the honest question is
  not "does it self-host" but "which layer", and Elixir's answer is available for free.**

  **(b) The Erlang stdlib interface — the FFI *surface*.** ~~*The sharp one, and ticket-ready.*~~
  **GRADUATED 2026-08-13 to [ticket 32](issues/32-ffi-surface.md)** — it lives there now, not here.
  In short: what a foreign declaration may **promise** and what happens when one **raises** are both
  decided (18, 15), and ~~nobody has decided how one is spelled~~ — **RESOLVED 2026-08-14, so (c) is
  unblocked.** A declaration binding the foreign module, both spellings carried, one arity each,
  lowering to a real emitted function.

  **One measured fact changes what (c) can be.** Elixir exports its macros as `MACRO-`-prefixed
  functions (`MACRO-__using__`, `MACRO-defcallback`) — compile-time constructs of Elixir's own
  compiler, **not callable from another language** ([`32b`](prototypes/32b_name_census.md)). So
  `use GenServer` cannot cross any FFI, ever. (c) can be beam-sharp code over **`:gen_server`**,
  Erlang's module, whose surface is ordinary functions; it **cannot** be beam-sharp code over
  *Elixir's* `GenServer`, which is the shape the precedent above was measured to be. The precedent
  still holds for the **layering** question and no longer holds for the **seam**.

  **(c) A beam-sharp `GenServer`, as Elixir has one.** Ticket 14 decided that `[module: GenServer]`
  **names a contract the compiler knows as a type** and that the user writes a narrower signature
  the compiler checks by containment. It did **not** decide whether the thing on the other side —
  the `start_link`, the loop integration, the client-API wrappers — is *beam-sharp code over
  `:gen_server`* or *compiler-known types over Erlang's module with no beam-sharp module at all*.
  This is the one that matters most, because ticket 00 made `handle_call/3` the **showcase**: the
  language's headline demo currently has no stated implementation strategy underneath it. It also
  interacts with the prelude-strata fog — a beam-sharp `GenServer` is stratum 1 by the "could a
  user have written it" test and stratum 2 by "the compiler draws inferences from it", which is the
  discriminator that fog patch is down to one live answer on.

  **The dependency runs (b) → (c) → optionally (a)**, and it is worth noting that (c) is where
  ticket 31's `Plug.Builder` question also lands: composable middleware is a library written in the
  language over a compiler-known contract, which is structurally the same problem as GenServer.

- **Emitted code quality, and where the ceiling is** — → **[ticket 39](issues/39-emitted-code-quality.md)**,
  raised 2026-08-15 from the first benchmark against other BEAM languages. beam-sharp runs a hot
  integer loop **20% slower than Erlang, Elixir and Gleam while emitting instruction-for-instruction
  identical bytecode** — the other three cluster within 3%. Ruled out by measurement: the FFI (the
  compiler lowers `:erlang.rem` to the BIF), the instruction sequence (26 instructions, identical),
  and the `-spec` (stripping all seven leaves the loop byte-identical and the time unmoved). What
  remains is that the operands carry less JIT type information. **The interesting half is the
  ceiling, not the gap**: ticket 20's exact intervals mean beam-sharp *knows* facts Erlang's
  analyser has to reconstruct and cannot spell in a `-spec` — so it is discarding information at the
  emission boundary rather than paying a tax for being typed, and ticket 04's mandatory signature is
  a candidate for why (a declared `int` return is never narrowed to `0..99`). **No optimisation work
  has ever been done**, so this is a baseline and not a verdict.
- **Division and modulo** — → **[ticket 38](issues/38-division-and-modulo.md)**, raised 2026-08-15
  from running AoC 2019 Day 1. The language has **no division at all**: the operator table is
  `+ - *`, and `/`, `%`, `div` and `rem` are none of them in the lexer. **Absent by oversight rather
  than decision** — measured, division appears zero times in `LANGUAGE.md`, the tickets and this
  fog. Half of it is easy and half is not. Truncation is easy because the sources **converge**:
  C#, JavaScript and Erlang's `div`/`rem` all give `-7 / 2 = -3` and `-7 % 2 = -1` (measured
  locally; Python's floored `-4` and `1` is the outlier and is not an audience). **Divide by zero
  is the open half**, and it is where the sources split — C# throws, Erlang raises `badarith`,
  JavaScript yields `Infinity`, which beam-sharp cannot even represent without `float`. So the
  choice is a crash, or the **first operator in the language to carry a precondition**, which the
  interval algebra could already express and print. Surfaced by an *outside* workload rather than by
  an exemplar, which is the better class of evidence and is the reason it is a ticket.
- **`cond`, or whatever serves a long ladder of unrelated conditions** — new with ticket 17 §6,
  which made `switch` the only branching construct and takes a **tuple subject** for compound
  conditions. That is clean at two or three conditions and clumsy at five, where
  `(a, b, c, d, e) switch` is hard to read even with `_` absorbing the tail. Deliberately not paid
  for with a keyword until the shape is shown to occur: ~~**ticket 25 owes a report on whether the six
  exemplars produce it.**~~ ~~**REPORTED 2026-08-13 — the shape occurs, at width five**
  ([`25a`](prototypes/25a-http-api-server.md)).~~ **THAT REPORT IS RETRACTED THE SAME DAY (David):
  25a's width-five ladder is contrived and is not evidence.** *"In a web server you'd basically have
  a pipeline and pluggable middleware, e.g. Plug in Elixir. So something like the switch in that
  example is unlikely to be written."* Correct — Plug, Rack and ASP.NET Core all distribute those
  five concerns across **separate middleware**, each halting the pipeline on failure, so the
  architecture dissolves the ladder and nobody writes it. 25a **constructed a shape to answer the
  question** instead of writing the workload honestly, which is the one failure ticket 25 exists to
  prevent. **So the evidence rests on 25c alone, and 25c reports the shape at width four reading
  *fine*** — with the additional note that lifting two of its four conditions into named functions
  to fit the tuple *improved* the code, which a `cond` ladder would have inlined and made worse.
  **Net: there is still no case for `cond`, and the tuple subject may be a forcing function rather
  than a defect.** The readability cliff between 4 and 5 is real but is now measured only from one
  side. **David has asked for `switch` to be revisited regardless** — the live question is no longer
  "does the ladder occur" but whether the positional encoding is the right shape at any width. Adding `cond` later is still purely additive, and
  its catch-all would be a clause (`_ =>`), never an `else` — 17c measured that `else` is an
  `if`-only keyword on this platform and both Elixir pattern constructs reject it.
  **A second data point 2026-08-13 ([`25c`](prototypes/25c-event-queue-consumer.md)) locates the
  cliff between four and five.** A queue consumer's ack / requeue / dead-letter decision is width
  **four** — outcome, permanence, redelivered, delivery count — and it reads **fine**; none of 25a's
  three complaints bites at that width. Two findings that argue *against* the keyword rather than
  merely failing to argue for it: lifting two of the four conditions into named functions to fit the
  tuple **improved** the code, and a `cond` ladder would have inlined them as expressions and read
  worse; and the width-four ladder collapses from five rows to four with a **positional wildcard**,
  which ticket 12 §2 does not touch — that rule is about a catch-all clause, not a `_` inside a
  pattern. So the evidence is now two points with opposite verdicts and a locatable boundary, which
  is a better basis for David's decision than 25a's single reading.

- **A value-returned foreign error has no declared form** — →
  **[ticket 56](issues/56-foreign-value-returned-error.md)**, raised 2026-08-18 while **building**
  F19 rather than by argument: the wrapper was built and this is what it could not say. Ticket 15 §5
  fixes the foreign error channel to `(:error, term) | (:throw, term) | (:exit, term)`, and F19
  refuses at the declaration any foreign failure typed otherwise. That is right for a call that
  **throws**. It makes an ordinary class of Erlang function undeclarable: `file:read_file/1` returns
  `{ok, Binary} | {error, Reason}` as **values** and never throws, so `result<binary, foreign_error>`
  is a lie, `result<binary, atom>` is refused by the check F19 just built, and declaring it without
  `result` leaves the tuple crossing the boundary untyped — what ticket 18 exists to prevent. §5
  prices the cost as *"add a mapping step"*, and **the mapping step has nothing to map from**. Not a
  question about widening `foreign_error`: a `(:value, T)` member would type-check while still
  telling the author the error arrives by a channel it does not. `bs_diag.erl`'s
  `foreign_error_channel` message names the gap in prose and **must change when this resolves**.
  **It was numbered 48 for four days while holding its content only in Linear**, so a different
  question took that number on 2026-08-20 and the two trackers disagreed about what "48" meant — the
  canonicality failure in the mirror direction, found 2026-08-22 while resolving ticket 55.
  Sequence with 50 and 52: all three ask what an FFI declaration carries.

- **A map type in the prelude** — → **[ticket 48](issues/48-a-map-type-in-the-prelude.md)**, raised
  2026-08-21 by David during ticket 31: *"probably want to add map to prelude"*. There is no map
  type; `map<atom, term>` is refused at the declaration and `list<(atom, term)>` is what ticket 31
  §4 used instead, so this is an **ergonomic cost, not a blocker**. The objection that looked fatal
  is dead: a record erases to a map carrying a minted `Kind`, and the worry was that a map pattern
  would also match records — but measured against Elixir's `Descr`
  ([`31e`](prototypes/31e_elixir_maps_vs_structs.exs)), a map type declaring the tag key **absent**
  is disjoint from every struct while still admitting plain maps, so **the tag is what keeps them
  apart** rather than what maps threaten. What survives is that a map's key domain is unbounded, so
  a pattern over it never closes a residual and exhaustiveness is **vacuous** there — beam-sharp's
  first type over which the headline guarantee says nothing. Three candidates: opaque and
  Gleam-shaped, matchable and Erlang-shaped, or not at all. **Deliberately not resolvable yet** —
  the test is the one that cut function values, *"no exemplar declares one"*, and the exemplar most
  likely to want a map is 25a, whose pipeline rewrite ticket 31 has only just unblocked.

- **What the valve keys on: the atom, or the declared type?** — → **[ticket 49](issues/49-what-the-valve-keys-on.md)**,
  raised 2026-08-21 out of ticket 31. 31c's **shape B** keys `|?>` on the stage's declared parameter
  type rather than on `(:error, _)`, so a stage spells its halt `(:halt, Response)` and a `200 OK`
  stops being an error; the pipeline is character-identical either way. Two measurements from 31 bear
  on it and they pull opposite ways. **For:** the valve **refuses `option<T>`** — measured — so it
  does not serve C#'s `?.` or TypeScript's optional chaining, the two neighbours ticket 17 §4 named
  when it justified the borrow. **Against:** shape A is cheaper than 31 first reported, because a
  terminal stage declared `(:error, Response)` gives a one-clause unwrap, so the ergonomic argument
  for shape B is gone and only the atom's honesty remains. 31c's claim that the compiler gains
  *nothing it does not already have* is **unverified** and is the first thing to measure. Read cost
  is the real argument against: today you recognise `(:error, _)` on the page, where shape B asks you
  to know the stage's signature.

- **Dependency provenance: what a `.bs` file says about what it needs** — → **[ticket 52](issues/52-dependency-provenance.md)**,
  the residual of 51, which decided beam-sharp builds **no** dependency tool. `ERL_LIBS` reaches Req
  with no compiler change, and that is exactly the problem: a module opening `using :'Elixir.Req'`
  names the *module* and never the *application*, so a program's dependencies live only in the
  environment that happened to build it and **the clean-room handoff cannot reconstruct them**. Not
  what the scope boundary refuses — no resolution, locking, fetching or publishing — but what the
  source says about itself, which is a language question. The candidate 51 captured: the **FFI
  declaration may already be the right home**, since it is the one place the source already names a
  foreign thing. A name is compile-time checkable; a *version* would be resolution and stays refused.
  Sequence with 50 — both ask what an FFI declaration carries, and answering them apart risks two
  extensions to one construct designed by different sessions.

- **List length in the algebra: a proved-exhaustive program that crashes** — →
  **[ticket 54](issues/54-list-length-in-the-algebra.md)**, raised 2026-08-21 while measuring
  ticket 53's premise, which is how the worse thing was found under the smaller one. The repro is
  four lines: `Shape([]) -> :empty` beside `Shape([a, b, ..t]) -> :many` **compiles clean with no
  diagnostic** and crashes `function_clause` on `[7]`. A program the compiler proved exhaustive,
  crashing on a value of its declared type, over `list<int>`.
  **`bs_types` represents a list as `{nil_flag, elem}` — there is nowhere to put a length**, so a
  cons pattern subtracts *all* of non-empty regardless of how long its prefix is (over-subtracts,
  and this is the crash) while a cons with a *closed* rest subtracts **nothing** (under-subtracts —
  `[]`, `[]`+`[a, ..[]]` and `[]`+`[a, ..[]]`+`[a, b, ..[]]` all leave the identical residual). The
  two forms TOUR §5 demonstrates are exactly the two the representation can express; everything else
  is silently approximated. One root, two symptoms, and **fixing the unsound half alone would hide
  the other** — a route table written 53's way would still be unchecked and would now look fine.
  The live question is *how much* length to model: exact prefix, or an interval reusing ticket 20's
  machinery, which the residual printer already knows how to talk about. 449 tests pass today with
  the wrong behaviour and some may encode it. Takes precedence over 53's surviving sugar question.

<!--
  GRADUATED 2026-08-12 (ticket 10): "Runtime behaviour against untyped callers — what, if
  anything, the compiler emits to defend a typed function called from raw Erlang." This is
  ticket 18's question verbatim, and ticket 10 §7 supplied its sharpest evidence (the tag /
  payload asymmetry, observed in Gleam). Removed from the fog so it lives only as the ticket.
-->


