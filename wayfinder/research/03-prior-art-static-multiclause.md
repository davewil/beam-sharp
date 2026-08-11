# 03 — Prior art: static typing plus multi-clause heads on the BEAM

Research for [ticket 03](../issues/03-prior-art-static-multiclause.md) · 2026-08-11
Covers **purerl/PureScript**, **Hamler**, **Alpaca**, **Caramel**, the **NVLang** paper
(arXiv:2512.05224), and **Gleam** as the baseline the effort is defined against.

---

## 0. What this ticket found

Three findings dominate, and none of them is the one the ticket anticipated.

1. **The combination is proven, not speculative.** Alpaca shipped Erlang-style multi-clause
   heads on a Hindley-Milner BEAM language, with message-typed PIDs.
   The design is not blocked on a type-theory problem.

   > **CORRECTED 2026-08-11 by [ticket 19](../issues/19-purescript-backend-erl-audit.md).**
   > This bullet originally also claimed that "purerl's successor backend compiles PureScript's
   > multiple equations down to native Erlang clause heads". **That is wrong.**
   > `purescript-backend-erl` emits **exactly one clause, always, with no guard** — asserted in
   > its own source and verified across 443 functions in 44 golden-output modules, where the
   > maximum clause count is 1. The error was a misreading of commit `1be3f06`: that commit
   > reports a *bug* in which a pattern was wrongly stamped into the one head all source clauses
   > share, not a feature by which source clauses become heads. Alpaca's half of the claim
   > stands and is sufficient on its own.
2. **Nothing here died of a type-theory wall.** Caramel's author, asked what the project
   proved, answered the question "why is Erlang hard to type?" with *"as it turns out, it is
   not!"* ([claim 40]). What killed these projects was **bus factor of one**
   plus **no commercial consumer** plus the **ecosystem tail** — stdlib, CLI, LSP, formatter.
   That is the risk register beam-sharp inherits, and it is an entirely different register
   from the one the ticket expected.
3. **Gleam has no stated rationale for refusing multiple function heads — because the
   feature was never proposed and therefore never rejected.** See [§4](#4-gleams-rationale-for-refusing-multiple-function-heads).
   This is a materially better answer than either candidate the ticket offered: the omission
   is not evidence of a soundness or exhaustiveness problem, and cannot be cited as such.

Two corrections to the ticket's framing, recorded so they don't propagate:

- **NVLang is close to a null result for this effort, and its credibility is questionable.**
  It is plain Damas-Milner HM with nominal ADTs, single-headed functions, and a rule that
  *unifies* all branches to one type — the explicit opposite of union-of-clause-types. Read
  [§3.5](#35-nvlang--a-paper-to-handle-with-tongs) before citing it anywhere downstream.
- **purerl has not stalled.** It was deliberately superseded by a sibling backend from the
  same ecosystem, which was under heavy development as recently as July 2026. Succession is
  not abandonment, and the reason it survived is the most useful datum in the whole ticket.

---

## 1. Comparison table

| Language | Type system family | Multi-clause heads? | Exhaustiveness | Actors / messages typed | Last meaningful activity | Status |
|---|---|---|---|---|---|---|
| **purerl** (+ `purescript-backend-erl`) | PureScript's, unchanged: HM-derived with type classes, higher-kinded types, row polymorphism, row-typed records ([1]) | **In the source language only** — PureScript equations with pattern guards ([3]); **but no Erlang clause heads are emitted.** `purescript-backend-erl` produces exactly one clause per function, always, with no guard — corrected by [ticket 19](../issues/19-purescript-backend-erl-audit.md); see the note on claim [4] | **Error by default, expressed as a propagating `Partial =>` type-class constraint** rather than a diagnostic; dischargeable with `unsafePartial` ([5], [6]) | **Yes, thoroughly.** `Process a` phantom-typed by message type; `send :: Process a -> a -> Effect Unit`; `ProcessM msg` monad for receipt; Pinto types gen_server callbacks over `cont/stop/msg/state`; compile-time-disambiguated untagged unions for heterogeneous inboxes ([7]–[10]) | purerl: substantive work 2025-09-04. Successor `purescript-backend-erl`: **2026-07-30** ([11], [13]) | **Alive, via succession.** purerl itself deprecated *by its own README* in favour of backend-erl ([14]) |
| **Hamler** | Haskell/ML-style, forked from PureScript 0.13.6: type classes with fundeps and multi-param classes, ADTs, HKTs ([15], [16]) | **Yes**, and used heavily throughout its own stdlib, with Erlang-flavoured `[x\|xs]` cons patterns ([17]) | **Checked, but downgraded to a warning.** The fork *deletes* upstream's `Partial` constraint injection and emits the diagnostic to the writer channel instead ([18]) | **Essentially not.** `send :: forall a. Pid -> a -> Process ()` — `Pid` is unparameterised, so no send can ever be rejected. GenServer's client API drops the class constraint entirely ([19], [20]) | **2021-10-14** ([21]) | **Dead.** Not archived; two bug reports (2022, 2025) unanswered ([22]) |
| **Alpaca** | HM-family inference (Oleg-style eager inferencer + Algorithm W influence); **unions over pre-existing types**, not only tagged constructors; row polymorphism on records; no ML modules, no type classes ([23]–[26]) | **Yes** — `let map f [] = [] / let map f (h :: t) = ...`. But constructor patterns in heads were **buggy and never fixed** ([27], [28]) | **Warned, on by default, top-level functions only.** Inner `match` unchecked; the checker itself crashed on several inputs ([29], [30]) | **Yes, and most inventively.** `pid` parameterised by message type; any expression containing `receive` becomes a *receiver* with an associated type; message type inferred from the **whole call graph** of the spawned function ([31]–[33]) | **2019-04-07** ([34]) | **Dormant.** Not archived; no maintainer statement |
| **Caramel** | OCaml's own, by reusing the OCaml compiler frontend through Typedtree; polymorphic variants carry BEAM atoms. **Functors silently broken** ([35]–[37]) | **No.** Plain OCaml surface; every generated Erlang function has exactly one head with a `case` inside ([38]) | **OCaml Warning 8 passes through and is non-fatal**; partial matches reach the emitted Erlang as runtime `case_clause` holes ([39]) | **Yes, but modestly.** `'m Erlang.pid`; receive is a *capability function* `'m recv = timeout:after_time -> 'm option` passed into the loop, not a construct. `contramap` gives typed reply channels. Raw `Erlang.spawn`/`send` leaks untyped. "Typed OTP" was a documentation stub ([41]–[43]) | **2022-08-10** (last Ostera commit 2021-03-11) ([44]) | **Archived 2026-05-19** ([45]) |
| **NVLang** (paper only) | **Plain Damas-Milner HM**, Robinson unification with occurs check, Algorithm W. Nominal ADTs. *Zero* occurrences of "set-theoretic", "subtyping", "union type" or "intersection" in the paper ([46]–[48]) | **No.** Single-headed `fn`; dispatch inside via `case`. `T-Case` **unifies all branches to one type** — the opposite of union-of-clause-types ([49], [50]) | **Asserted, never specified.** An opaque premise `Exhaustive(M, {pᵢ})`, never defined; the whole proof is one sentence deferring to "the pattern matching compiler" ([51], [52]) | `Pid[τ]` where τ is the actor's message ADT; `Future[τ]` for replies; **Uniform-Reply** forces every constructor to reply with the same type. Heterogeneous mailboxes, selective receive, `after`, and gen_server are *never mentioned*; `𝒰(Pid, Pid[τ]) = ∅` lets an untyped PID unify with any typed one ([53]–[56]) | Submitted **2025-12-04** ([57]) | **arXiv preprint, no venue, no peer review, single author, no locatable implementation** ([58], [59]) |
| **Gleam** *(baseline)* | HM inference with exhaustiveness checking (per [ticket 00](../issues/00-charting-decisions.md)) | **No** — "Gleam functions can have only one function head" ([60]) | **Compile-time exhaustiveness on `case`**, implementing Jules Jacobs' pattern-match compilation algorithm ([64]) | **Not established by this ticket.** No primary source was gathered. The only characterisation in evidence is NVLang's secondary claim that "Gleam's actor types are relatively simple, treating all messages uniformly" ([61]) — an assertion from the least reliable source in this set. **Deferred to [ticket 14](../issues/14-concurrency-and-otp-model.md).** | Active | Shipping, v1.0 March 2024 ([62]) |

---

## 2. The three design mechanisms worth carrying forward

Extracted from the table because downstream tickets need them as mechanisms, not rows.

### 2.1 Exhaustiveness as a *propagating constraint*, not a diagnostic

PureScript does not report a non-exhaustive match. It **rewrites the expression's type**,
attaching a `Partial =>` constraint; the failure then arrives from the instance solver as an
unsolved constraint, and propagates up the call graph until someone discharges it with
`unsafePartial` ([5], [6]).

This is the most interesting single idea in the ticket, because it is a principled way to
have *both* "let it crash" and static totality: partiality becomes a fact recorded in the
type and paid for explicitly at a named site, rather than a compiler flag.

The counter-evidence is equally instructive. Hamler kept the algorithm and **removed exactly
this mechanism**, emitting a plain warning instead ([18]) — presumably
because propagating `Partial` through OTP-shaped code is painful. Its own stdlib carries a
clause commented `-- chant compiler`, added purely to placate the checker. Feeds
[ticket 12](../issues/12-totality-vs-let-it-crash.md).

### 2.2 Typing the mailbox is the make-or-break decision

Ranked by how much the type system actually knows:

- **purerl/Pinto** — `Process a`, `send :: Process a -> a -> Effect Unit`, `ProcessM msg` for
  receipt, and trapping exits changes the *monad* so the effect is visible in the type. The
  untyped-VM boundary is localised to a single `unsafeFromForeign` in `handle_info`
  ([7]–[9]). For heterogeneous inboxes, `Erl.Untagged.Union`
  builds a type-level list of choices with a runtime discriminator — and **rejects at compile
  time any union whose members cannot be told apart at runtime** ("Ambiguous Union",
  [10]). That is a worked answer to the hardest question in this space.
- **Alpaca** — `pid string`; `receive` promotes a function to a *receiver* type carrying its
  message type alongside its arrow type, with `t_rec` as a legitimate infinitely-recursive
  result; the message type is inferred from the entire call graph of the spawned function
  ([31]–[33]). Spawning a non-receiver yields a pid typed
  `undefined`, so every send to it is a type error — the leak Caramel left open, closed
  ([33]).
- **Caramel** — `'m Erlang.pid` plus receive-as-a-passed-capability. Cheaper: no new type
  former needed. But raw `Erlang.spawn`/`Erlang.send` leak untyped with no warning
  ([43]).
- **NVLang** — `Pid[τ]`, undercut by `𝒰(Pid, Pid[τ]) = ∅` and total type erasure
  ([55], [56]).
- **Hamler** — nothing. `forall a. Pid -> a` ([19]). A BEAM language whose
  types stop at the edge of the BEAM's actual programming model.

Feeds [ticket 14](../issues/14-concurrency-and-otp-model.md).

### 2.3 Parsing constructor patterns in the head is a real hazard

Alpaca's `let map f Some x = Some (f x)` is genuinely ambiguous with function application,
and it **crashed the compiler** ([27]) and misparsed arity
([28]). Both issues were still open when the project stopped. A C#-shaped
surface has an advantage here — parentheses around the parameter list remove the
juxtaposition ambiguity by construction — but the hazard should be designed against
explicitly. Feeds [ticket 08](../issues/08-head-and-guard-syntax.md).

Related, and less obvious — **but reversed by [ticket 19](../issues/19-purescript-backend-erl-audit.md)**.
This paragraph originally read that "source clauses surviving to native Erlang clause heads is
a non-trivial optimisation, not a free win", citing a July 2026 `purescript-backend-erl` bugfix
in which pattern-demand analysis stamped a refutable constructor tag "in the worst case [into]
the function head, making the source function's Nothing clauses unreachable and crashing live
code paths with `function_clause`" ([4]) — a miscompile in production code.

The bug is real; the moral was backwards. That backend emits **one** clause per function, so
every source equation shares a single head, and **that sharing is what made the bug possible**:
a fact true on only one path was hoisted into a head governing all of them. A backend emitting
one clause per equation could not have had this bug, because a per-clause pattern is scoped to
its clause by construction. So the correct reading is that **merging clauses is the non-trivial
and hazardous operation** — and the hazard was paid for in a shipped product. Feeds
[ticket 13](../issues/13-compilation-target-decision.md).

---

## 3. Why the efforts stalled — the inherited risk register

The ticket asked for the failure modes. They sort cleanly, and the sorting variable is not
the one you would guess.

### 3.0 The discriminator is commercial dependency

| Project | Internal consumer? | Outcome |
|---|---|---|
| purerl → backend-erl | **Yes** — id3as ships `norsk` on it; a July 2026 commit references breaking it ([13]) | Survived a full backend rewrite with the type system, ecosystem and FFI contract intact |
| Hamler | **No** — EMQX itself stayed Erlang | Clean stop mid-stride |
| Caramel | **No** — Ostera's own words point users to Gleam because it has "plenty of people using it for real-life workloads already" ([40]) | Archived |
| Alpaca | **No** — "there is no commercial work being done using it" ([70]) | Dormant |

A language with no internal consumer is a cost centre, and it is the cost centre that gets
cut when attention moves. This is the single most transferable finding in the ticket.

### 3.1 Hamler — **no stated reason found**; sponsor reallocation is the evident one

Searched and came back empty: no README notice (the README at the final commit still reads
as an actively promoted project with a nine-person Core Team and a call for contributors),
no "is this dead?" issue among all 79 issues, no status post in Discussions, no retirement
announcement from EMQ ([65]). **Recorded explicitly so a later reader knows
someone looked.**

The evident reason, labelled as inference from the commit graph: Hamler and its forked
compiler go silent within 48 hours of each other (2021-10-12 and 2021-10-14), immediately
after the 0.5 release and a burst of feature work — OTP 24 support, dictionary inlining.
Burnout produces a ragged tail; this is a clean cut across multiple repos by paid staff
(`yangm@emqx.io`, `feng@emqx.io`), which is the signature of engineers being reassigned.

Contributing factors visible in the artefacts:

1. **Bus factor of one compiler engineer** — every meaningful compiler commit is one person's.
2. **No commercial pull** (see §3.0).
3. **Cost of carrying a *fork*, not a dependency.** Hamler forked PureScript 0.13.6 and
   diverged inside the type checker. No upstream to merge from, permanent debt — and the
   bill arrived as issue #480 (2025-11-09): won't build on modern GHC, no replies
   ([22]).
4. **No users** — 79 issues over the project's life; the last two bug reports sat unanswered
   for years without anyone noticing.

### 3.2 Alpaca — **no statement from the maintainer exists**

Jeremy Pierre (j14159) never announced anything. The last word from him on the subject is
from 2018, still optimistic ([66]):

> "Slow but not abandoned 😄
>
> In my limited spare time I've been mostly focused on trying to understand enough about
> first class module systems like 1ML for future Alpaca implementation and have been
> dabbling a little with Truffle/Graal."

and, after listing four module-systems papers ([67]):

> "To be clear: I don't understand all of the above yet 😆 I've got a long way to go still
> and I think there's some work to do syntax-wise to make the semantics clearer and more
> approachable for a larger section of our community."

When "is the project dead" was finally asked in 2024, **he did not reply**. It was answered
by Louis Pilfold — Gleam's author, and formerly Alpaca's standard-library contributor
([68]):

> "Hello! I believe development has stopped, yes. Gleam is somewhat a spiritual successor to
> Alpaca. I was previously working on the standard library and decided to continue my work in
> Gleam."

Two documented artefacts fill in the shape. Twelve days before the end, a commit titled
"Refactoring AST: remove Alpaca-native AST work" ([69]):

> "Self-hosted is a nice-to-have and the mix of AST definition languages is getting in the
> way a lot right now. Deferring Alpaca-native AST indefinitely to focus on things that make
> the language usable for tasks other than itself."

And the README's own admissions: the typer is "begging for a complete rewrite", type errors
are "almost comically hostile to usability", there is "no command line front-end for the
compiler", and the missing pieces are "basic string manipulation functions and adapters for
`gen_server`" ([71]).

**Verdict:** Gleam absorbing the niche is *stated* (by Pilfold). Bus factor is *evidenced*.
The module-system rabbit hole and the ecosystem tail are *inference from primary artefacts*.
Burnout is **not evidenced by anything** — do not carry that hypothesis forward.

### 3.3 Caramel — **stated by the maintainer, and the statement is unusually useful**

Asked "Current project status?" in September 2021, Leandro Ostera answered eleven months
later ([40]):

> "Unfortunately my focus has shifted to other projects and I don't think I'll continue
> working on Caramel any time soon.
>
> This may change if in the near future I free up considerable time, but I can't make any
> promises. If I do find the time it's likely that I'll do another rewrite, starting off from
> the last rewrite in the `sugarcane` branch, and **the language would move further away from
> OCaml**.
>
> In the meantime, I encourage you to try out Gleam ✨ -- Louis is doing a wonderful job with
> it and there are plenty of people using it for real-life workloads already."

Three things in that quote matter here:

- **"the language would move further away from OCaml"** — the maintainer's own retrospective
  verdict that borrowing an existing frontend was the constraint, not the asset. The
  `sugarcane` rewrite branch, with quasiquoting added and the stdlib deleted, is what
  "further away" looked like in practice.
- **"plenty of people using it for real-life workloads"** — an implicit admission Caramel had
  none.
- **"my focus has shifted"** — attention reallocation, not defeat.

And the hypothesis his own words *contradict*, from his BOB 2024 talk abstract
([40]): Caramel answered the question *"why is Erlang hard to type? – and as
it turns out, it is not!"* **The "typing the BEAM is too hard" hypothesis should be dropped
from this effort's risk register**; it is contradicted by the person best placed to hold it.

The ecosystem tail is visible in the repo: it **vendors its own copies of ocaml-lsp and
ocamlformat** ([72]), and three manual chapters — Language Features, Standard
Library, Typed OTP — were listed in the table of contents and never written
([42]).

### 3.4 purerl — **a stated, deliberate handoff**

The one non-cautionary tale. From the README, by Nicholas Wolverson ([14]):

> "This is the "original" purerl, but the generated code is sub-par compared to the newer
> purescript-backend-erl, and with the addition of incremental compilation support the use of
> `purerl` directly can't be recommended. The ecosystem & FFI specification remains the same,
> so the below information remains correct, but for production use backend-erl is a better
> choice."

Code quality and incremental compilation drove a full backend rewrite, and **the type system,
ecosystem and FFI contract were preserved across it** — which is why the transition cost
users almost nothing. Note the bus-factor shape too: purerl was essentially one person, while
backend-erl draws on several id3as engineers with a commercial product depending on it.

### 3.5 NVLang — a paper to handle with tongs

Not a stalled project, but its reliability is a risk in its own right, because downstream
tickets will otherwise cite it as prior art. Flags, in order of severity:

1. **Reference [23] as printed does not correspond to a real publication** — attributed to
   Sagonas and Lindahl, but eqWAlizer is Meta's tool; the title appears fused with an
   unrelated 2008 paper ([59]).
2. **No locatable implementation.** No repo link, no artifact statement, no LOC count, no
   implementation-language statement — yet six benchmarks requiring a working compiler
   ([58]).
3. **Four mutually inconsistent send syntaxes** across the paper (`c.send Increment`,
   `send c "hello"`, `p ! m`, `p.send m`), and two incompatible surface syntaxes
   ([59]).
4. **Single author, no venue, no peer review; all five theorems are proof sketches**
   ([57]).
5. **No engagement with the highest-profile active work on typing the BEAM** — no Castagna,
   no Frisch, no CDuce, no Elixir set-theoretic types anywhere in 26 references
   ([48]).

What is nonetheless usable: `Pid[τ]` with τ a closed sum type is the minimum viable typed
actor, and it composes cleanly with HM because `Pid` is just a parametric constructor. And
its **Uniform-Reply rule** — every constructor of an actor's message type must reply with the
same type, copied from Akka Typed ([54]) — is worth recording precisely
because it is the explicit *rejection* of the union-of-clause-types approach this effort has
committed to. A set-theoretic τ would give per-message reply types instead of that
straitjacket.

The gap the paper leaves open is exactly beam-sharp's problem: **heterogeneous mailboxes,
selective receive, `after` timeouts and gen_server callback typing are never mentioned at
all** ([55]).

---

## 4. Gleam's rationale for refusing multiple function heads

**Finding: no stated rationale exists in any reachable primary source.** This is a negative
finding, deliberately reported as one, after two independent searches totalling ~90 tool
calls.

### 4.1 The reason there is no rationale: it was never proposed

This is the substantive discovery, and it is a better answer than either alternative the
ticket posed.

- The rule landed **pre-v0.1 as a bare design premise**. Issue #64, "Disallow multiple
  functions with the same name", opened by lpil on 2019-02-02 — **empty body, zero comments**
  — closed eight days later by a one-line commit, "Disallow duplicate module functions"
  ([73]).
- **All 143 issues** of `gleam-lang/suggestions` (the org's ideas repo) were enumerated.
  **Not one** asks for multi-clause function heads ([74]).
- Exact-phrase and semantic searches across `gleam-lang/gleam` issues and discussions for
  "multiple function heads", "multi-clause", "function clauses", "patterns in function
  arguments" return **zero feature requests** ([74]).
- The compiler renders `DuplicateName` as "Names in a Gleam module must be unique so one will
  need to be renamed" — the rule stated, no why. No explanatory comment anywhere it appears,
  and the repo has **no ADR or design-notes directory** ([75]).

So nobody has ever pushed hard enough to force a stated defence.

### 4.2 Against the ticket's hypotheses

The ticket asked specifically whether the reason is compiler simplicity or a
soundness/exhaustiveness problem. The evidence:

| Hypothesis | Verdict |
|---|---|
| (c) soundness / exhaustiveness problem | **Affirmatively weakened, not merely unsupported.** *What the source says:* Gleam's v0.33 exhaustiveness checker implements the algorithm from Jules Jacobs' "How to compile pattern matching" ([64]), and every maintainer description of it is framed around `case` — none connects it to the function-head question. *What I conclude from that, labelled as my inference:* that algorithm decides coverage over multi-column, nested pattern matrices, and multi-clause heads desugar to a single `case` on a tuple of the arguments — same analysis, same inference, one signature. So the machinery that would check multi-clause heads is already shipped, and exhaustiveness cannot have been the barrier. **No maintainer states this.** |
| (d) HM inference problem | **Unsupported, and the apparent evidence is a conflation.** Issue #419 has lpil posing `double(Int)` vs `double(Float)` and concluding "These are not a trivial problems" ([76]) — but that is *ad-hoc polymorphism / overloading*, different arity or type. Multi-clause heads share one arity and one signature. Do not cite #419 for this. |
| (b) design/readability preference | **The most plausible, but still inference.** lpil's consistently applied principles — "a strong desire to have only one way of doing things", features must "enable new things not otherwise possible" ([63]) — would rule multi-clause heads out on exactly the grounds that ruled out tuple destructuring in parameters ([77]). He has never said this about function heads. |
| (a) compiler simplicity / (e) BEAM identity, JS backend | **No evidence either way.** Gleam already compiles `case` to both Erlang and JS, so a desugaring would be routine. |

### 4.3 The nearest adjacent statements — labelled, not promoted

**(i) About function *overloading*, not multi-clause heads.** lpil on ErlangForums,
2024-03-11, answering "Why no function overloading?" ([78]):

> "No function overloading results in a much simpler language and easier to read code. You
> don't have to track complicated unions or type classes or such."

**This is not the rationale for the single-head rule.** In BEAM vocabulary "overloading"
means same name at different arities or types; multi-clause heads are same name, same arity,
one signature. The reason he gives — avoiding unions and type classes — is a type-system
argument that does not apply. Both independent searches flagged it as a conflation risk.
Recorded as the nearest neighbour, and no more.

**(ii) Gleam prototyped multi-clause representation and dropped it.** lpil on Elixir Forum,
2019, describing an abandoned syntax file `examples/clauses.glm` ([79]):

> "It was largely an experiment to see how we could represent multiple function clauses
> without duplicating the name."

He never says why it was dropped. This is direct prior art for
[ticket 08](../issues/08-head-and-guard-syntax.md): the *syntactic* problem of expressing
several clauses without repeating the function name was recognised in Gleam's own design
work, and abandoned unexplained.

**(iii) About patterns in parameter position — the same syntactic slot, a different
feature.** On a request to destructure a tuple in a parameter ([77]):

> "In Gleam we don't have multiple ways to do the same thing, and we only add features to
> solve problems that cannot otherwise be solved, so this feature is unsuitable for addition."

### 4.4 Unchecked surfaces

Reported so the negative finding is honest about its edges: the **Gleam Discord**
(inaccessible, and the likeliest place the question is actually asked) and **conference talk
audio/captions** (abstracts retrieved for Code Mesh LDN 2019, Code BEAM V Europe 2021, Code
BEAM Europe 2024, YOW! 2022; captions unretrievable — YouTube returned UNPLAYABLE, transcript
mirrors 403). Everything else was searched: forums via author-filtered API queries, all 307
posts of the main Elixir Forum thread grepped in full, the Changelog #588 transcript grepped,
`gleam.run/news`, `tour.gleam.run`, `lpil.uk`, and the recovered Gleam Book principles/FAQ
chapters.

---

## 5. What beam-sharp should take from this

Pointers for downstream tickets, not decisions — those belong to the tickets that own them.

- **The core bet is not blocked on type theory.** Alpaca shipped multi-clause heads with HM;
  the constraint is engineering endurance, not soundness. ([Ticket 11](../issues/11-type-system-shape.md))
- **Gleam's omission carries no technical warning.** It was never proposed, never rejected,
  and the exhaustiveness machinery that would check it already ships. beam-sharp's
  differentiator does not have to argue past a considered objection, because there isn't one.
- **Exhaustiveness must be an *error* and must cover nested positions.** Alpaca checked
  top-level only and Caramel let Warning 8 through into shipped output; both are the
  failure mode the effort exists to avoid. PureScript's `Partial =>` constraint is the
  design worth studying. ([Ticket 12](../issues/12-totality-vs-let-it-crash.md))
- **Typing the mailbox is where these projects separate.** purerl's compile-time ambiguity
  rejection for untagged unions is the most advanced worked solution found; Alpaca's
  whole-call-graph inference of a process's message type is the most interesting unexploited
  idea. ([Ticket 14](../issues/14-concurrency-and-otp-model.md))
- **Don't borrow a whole existing frontend.** Caramel got industrial-strength typing free and
  paid for it by emitting single-head-plus-`case` forever — non-idiomatic BEAM code, and it
  never had to solve the interesting problem because it never let you write it.
- **The real risk is the ecosystem tail and the bus factor**, not the type system. Every
  dormant project here was one person carrying a stdlib, a CLI, a formatter and an LSP alone.
  The map already rules tooling out of scope; this research says that scoping is correct
  *and* that it is the thing that actually kills projects of this shape.

---

## Claim → source

Claims are numbered 1–79 and **grouped by project, not in numeric order** — the tail numbers
(61, 65–72) were assigned to the stalled-project evidence and sit in their project's block.
Note that **claim 61 is cited from the Gleam row of the comparison table but is listed under
NVLang**, because it is NVLang's characterisation *of* Gleam rather than a Gleam source.

### purerl

| # | Claim | Source |
|---|---|---|
| 1 | purerl has no type system of its own — it consumes the mainline PureScript compiler's CoreFn output and `externs.json`, and "requires the mainline PureScript compiler (`purs`) to operate" | [purerl README](https://github.com/purerl/purerl/blob/abe9d99b8db40d2f925466b01e0da576900dc100/README.md) |
| 2 | Erlang representation: records become `#{atom() => any()}`, tagged unions become tuples with a tag element (`Some 42` → `{some, 42}`), newtypes erase | [purerl README](https://github.com/purerl/purerl/blob/abe9d99b8db40d2f925466b01e0da576900dc100/README.md) |
| 3 | Multiple equations with pattern guards, in purerl's own ecosystem code (`insertAt` with a literal binder clause, a pattern-guard clause and a catch-all) | [purescript-erl-lists `Erl/Data/List.purs`](https://github.com/purerl/purescript-erl-lists/blob/abfab26760d124907199873a0e12f9b67702aacc/src/Erl/Data/List.purs) |
| 4 | ~~Source clauses compile to native Erlang function heads~~ — **RETRACTED, see below.** What the cited commit actually reports is a July 2026 bugfix in which a pattern was stamped "in the worst case the function head, making the source function's Nothing clauses unreachable and crashing live code paths with `function_clause`" — a bug arising precisely *because* all source clauses share one head, not evidence that clauses become heads | [purescript-backend-erl commit 1be3f06](https://github.com/id3as/purescript-backend-erl/commit/1be3f069cdbb44b4083a256cc4696a4b225fc710) |
| 4a | **Correction**: `purescript-backend-erl` emits exactly one clause per top-level function, always, with no guard. `Convert/After.purs:158-163` wraps every definition as a singleton-head fun and `unsafeCrashWith`es on any other shape. Verified: 443 top-level functions across 44 golden modules, max clause count 1 | [ticket 19 audit](19-purescript-backend-erl-audit.md) |
| 5 | Non-exhaustive matches are not emitted as a diagnostic; the checker calls `addPartialConstraint`, rewriting the expression's type to `Partial => _`. Redundant/overlapping patterns *are* warnings (`tell`) | [PureScript `Exhaustive.hs`](https://github.com/purescript/purescript/blob/cb3c4965c8468d26c9b14cf0319db6dbd06ee4ff/src/Language/PureScript/Linter/Exhaustive.hs) |
| 6 | "The exhaustivity checker will introduce a `Partial` constraint for any pattern which is not exhaustive. By default, patterns must be exhaustive… The error can be silenced, however, by adding a local `Partial` constraint to your function" | [PureScript docs, Pattern-Matching.md](https://github.com/purescript/documentation/blob/master/language/Pattern-Matching.md) |
| 7 | `newtype Process (a :: Type) = Process Raw.Pid`; `send :: forall a. Process a -> a -> Effect Unit`; `spawn :: forall a. ProcessM a Unit -> Effect (Process a)`; `HasReceive` class fixes `receive :: ProcessM msg msg`; trapping exits switches to `ProcessTrapM msg` returning `Either ExitReason msg` | [purescript-erl-process `Erl/Process.purs`](https://github.com/purerl/purescript-erl-process/blob/46c3d8e32676e7a55b7b94b87116386689d0f476/src/Erl/Process.purs) |
| 8 | Pinto types gen_server callbacks over four parameters (`cont`, `stop`, `msg`, `state`) via `ResultT`; `ServerPid cont stop msg state` wraps `Process msg` | [purescript-erl-pinto `Pinto/GenServer.purs`](https://github.com/id3as/purescript-erl-pinto/blob/7cfd871aa9ce6ea1788a07e66f188a433a7bd8db/src/Pinto/GenServer.purs) |
| 9 | The untyped-VM boundary is a single `unsafeFromForeign` in `handle_info`, not a pervasive hole | [purescript-erl-pinto `Pinto/GenServer.purs`](https://github.com/id3as/purescript-erl-pinto/blob/7cfd871aa9ce6ea1788a07e66f188a433a7bd8db/src/Pinto/GenServer.purs) |
| 10 | `Erl.Untagged.Union` builds a type-level `Choices` list with `RuntimeType`/`RuntimeTypeMatch` classes for runtime discrimination, and an `IsAmbiguous` check that rejects at compile time any union whose members cannot be distinguished at runtime ("Ambiguous Union") | [purescript-erl-untagged-union `Erl/Untagged/Union.purs`](https://github.com/id3as/purescript-erl-untagged-union/blob/cbf40652d847ca2572ddda5259182aab552d3e04/src/Erl/Untagged/Union.purs) |
| 11 | purerl last substantive commit 2025-09-04; last release v0.0.24 on 2025-09-04; repo not archived | [purerl commit d96da34](https://github.com/purerl/purerl/commit/d96da3492d6e13e575f4854286d0dba08d2f9e0f) |
| 12 | purerl 0.0.22 maps to purs 0.15.14 — it tracks upstream PureScript explicitly, and is not on the newest upstream | [purerl README version table](https://github.com/purerl/purerl/blob/abe9d99b8db40d2f925466b01e0da576900dc100/README.md) |
| 13 | `purescript-backend-erl` last commit 2026-07-30, substantive compiler-optimiser work; commits reference breakage in "norsk", id3as's commercial product | [purescript-backend-erl commit history](https://github.com/id3as/purescript-backend-erl/commit/1be3f069cdbb44b4083a256cc4696a4b225fc710) |
| 14 | "This is the "original" purerl, but the generated code is sub-par compared to the newer purescript-backend-erl… for production use backend-erl is a better choice" | [purerl README](https://github.com/purerl/purerl/blob/abe9d99b8db40d2f925466b01e0da576900dc100/README.md) |

### Hamler

| # | Claim | Source |
|---|---|---|
| 15 | "The Hamler 0.1 compiler was forked from PureScript 0.13.6… CST -> AST -> CoreFn's syntax tree transformation, syntax analysis and type checking"; advertises compile-time type checking/inference, ADTs, currying, pattern matching and guards | [Hamler README](https://github.com/hamler-lang/hamler/blob/97e1e2f09c2c6e8ac5c7eb2637596dfceab3b788/README.md) |
| 16 | Multi-parameter type classes with functional dependencies in the stdlib: `class GenServer req rep st \| req -> rep, rep -> st, st -> req` | [Hamler `Control/Behaviour/GenServer.hm`](https://github.com/hamler-lang/hamler/blob/97e1e2f09c2c6e8ac5c7eb2637596dfceab3b788/lib/Control/Behaviour/GenServer.hm) |
| 17 | Multi-clause definitions with guards throughout the stdlib (`intersperse`, `isPrefixOf`), using `[x\|xs]` cons patterns | [Hamler `lib/Data/List.hm`](https://github.com/hamler-lang/hamler/blob/97e1e2f09c2c6e8ac5c7eb2637596dfceab3b788/lib/Data/List.hm) |
| 18 | The fork replaces upstream's `Partial`-constraint injection with `tell . errorMessage' ss $ NoInstanceFound …`, returning the expression unmodified; a commented-out alternative would have appended a synthetic error clause | [Hamler's PureScript fork, `Exhaustive.hs`](https://github.com/hamler-lang/purescript/blob/7500c4d29760bbb761cb05ad2ef58fd7e90f74b5/src/Language/PureScript/Linter/Exhaustive.hs) |
| 19 | `foreign import send :: forall a. Pid -> a -> Process ()` — unparameterised `Pid`, fully polymorphic message | [Hamler `lib/Control/Process.hm`](https://github.com/hamler-lang/hamler/blob/97e1e2f09c2c6e8ac5c7eb2637596dfceab3b788/lib/Control/Process.hm) |
| 20 | The GenServer client API drops the class constraint: `foreign import call :: forall req rep. Name -> req -> Process rep`; `Name` is a plain atom carrying no type information | [Hamler `Control/Behaviour/GenServer.hm`](https://github.com/hamler-lang/hamler/blob/97e1e2f09c2c6e8ac5c7eb2637596dfceab3b788/lib/Control/Behaviour/GenServer.hm) |
| 21 | Last commit to `hamler` 2021-10-14; to the forked compiler 2021-10-12; last release 0.5 on 2021-09-30; repo not archived | [hamler commit 97e1e2f](https://github.com/hamler-lang/hamler/commit/97e1e2f09c2c6e8ac5c7eb2637596dfceab3b788), [release 0.5](https://github.com/hamler-lang/hamler/releases/tag/0.5) |
| 22 | Issue #480 (2025-11-09) "can't build from source using ghc-9.10.3" has no replies; issue #478 (2022-03-06) reporting a shipped GenServer bug has no replies | [hamler issue #480](https://github.com/hamler-lang/hamler/issues/480), [issue #478](https://github.com/hamler-lang/hamler/issues/478) |
| 65 | No stated reason for the stop: README at the final commit still promotes the project with a nine-person Core Team and a call for contributions; no status thread in Discussions | [Hamler README](https://github.com/hamler-lang/hamler/blob/97e1e2f09c2c6e8ac5c7eb2637596dfceab3b788/README.md), [Discussions](https://github.com/hamler-lang/hamler/discussions) |

### Alpaca

| # | Claim | Source |
|---|---|---|
| 23 | "Alpaca is a statically typed, strict/eagerly evaluated, functional programming language for the Erlang virtual machine… formerly known as ML-flavoured Erlang (MLFE)" | [Alpaca README](https://github.com/alpaca-lang/alpaca/blob/main/README.md) |
| 24 | Inference is "based off of the sound and eager type inferencer in okmij.org/ftp/ML/generalization.html with some influence from tomprimozic/type-systems algorithm_w" | [Alpaca README, "Type Inferencing and Checking"](https://github.com/alpaca-lang/alpaca/blob/main/README.md) |
| 25 | Unions may be formed over pre-existing types, not only tagged constructors (`type number = int \| float`); membership is resolved by scope order — "If the inferencer has more than one ADT unifying integers and floats in scope, it will choose the one that occurs first" | [Alpaca Tour.md](https://github.com/alpaca-lang/alpaca/blob/main/Tour.md) |
| 26 | Row polymorphism on records; no ML modules ("ML-style modules aren't implemented at present"), no type classes, no `any`/root type | [Alpaca Tour.md](https://github.com/alpaca-lang/alpaca/blob/main/Tour.md), [README](https://github.com/alpaca-lang/alpaca/blob/main/README.md) |
| 27 | Multi-clause heads in the surface (`let map f [] = [] / let map f (h :: t) = (f h) :: (map f t)`); constructor patterns in heads crashed the compiler — issue #269, opened 2019-05-20, **still open** | [Alpaca Tour.md](https://github.com/alpaca-lang/alpaca/blob/main/Tour.md), [issue #269](https://github.com/alpaca-lang/alpaca/issues/269) |
| 28 | "Function parsing as incorrect arity with ADT as first arg" | [Alpaca issue #231](https://github.com/alpaca-lang/alpaca/issues/231) |
| 29 | "`{'warn_exhaustiveness', boolean()}` - If set to true (the default), the compiler will print warnings regarding missed patterns in **top level functions**" | [Alpaca README, "Using It"](https://github.com/alpaca-lang/alpaca/blob/main/README.md) |
| 30 | "Only top level expressions have exhaustiveness checking at present"; the checker crashed on synthetic type-variable names and on types imported from pre-compiled modules | [Alpaca issue #270 comment](https://github.com/alpaca-lang/alpaca/issues/270#issuecomment-494169634), [#170](https://github.com/alpaca-lang/alpaca/issues/170), [#228](https://github.com/alpaca-lang/alpaca/issues/228) |
| 31 | "Process identifiers… are typed with the kind of messages they are able to receive. The type of process that only knows how to receive strings can be expressed as `pid string`" | [Alpaca Tour.md, "PIDs"](https://github.com/alpaca-lang/alpaca/blob/main/Tour.md) |
| 32 | "Any expression that contains a `receive` block becomes a 'receiver' with an associated type"; goal: "Infinitely recursive functions as a distinct and allowable type for processes looping on receive" | [Alpaca README, "Processes" / "Intentions/Goals"](https://github.com/alpaca-lang/alpaca/blob/main/README.md) |
| 33 | "The type inferencer looks at the entire call graph of the function being spawned to determine type of messages that the process is capable of receiving"; `self()` unsupported because "it's a little tricky to type"; spawning a non-receiver types the pid `undefined` so "all message sends to that process will be a type error" | [Alpaca Tour.md, "Processes"](https://github.com/alpaca-lang/alpaca/blob/main/Tour.md), [README, "What's Missing"](https://github.com/alpaca-lang/alpaca/blob/main/README.md) |
| 34 | Last commit on `main` 2019-04-07 (`aa2bb55`); last release v0.2.8 on 2018-01-02; not archived | [Alpaca commit aa2bb55](https://github.com/alpaca-lang/alpaca/commit/aa2bb5594dda8292ca0bffb8e8a6ebc0f60e8dbc), [releases](https://github.com/alpaca-lang/alpaca/releases/tag/v0.2.8) |
| 66 | "Slow but not abandoned 😄 In my limited spare time I've been mostly focused on trying to understand enough about first class module systems like 1ML…" — j14159, 2018-08-07 | [Alpaca issue #251](https://github.com/alpaca-lang/alpaca/issues/251#issuecomment-410902178) |
| 67 | "To be clear: I don't understand all of the above yet 😆 I've got a long way to go still…" — j14159 | [Alpaca issue #251](https://github.com/alpaca-lang/alpaca/issues/251#issuecomment-411104084) |
| 68 | "I believe development has stopped, yes. Gleam is somewhat a spiritual successor to Alpaca. I was previously working on the standard library and decided to continue my work in Gleam." — lpil, 2024-09-04. j14159 never replied to the thread | [Alpaca issue #271](https://github.com/alpaca-lang/alpaca/issues/271#issuecomment-2328563794) |
| 69 | "Self-hosted is a nice-to-have and the mix of AST definition languages is getting in the way a lot right now. Deferring Alpaca-native AST indefinitely…" — commit 2019-03-26, twelve days before the last commit | [Alpaca commit 8e44088](https://github.com/alpaca-lang/alpaca/commit/8e44088241c68df3f3e6776b4199db0480adbdd3) |
| 70 | "the last commit was made 5 years ago and there is no ommercial work being done using it" — opener of the "is the project dead" issue, 2024-09-03 | [Alpaca issue #271](https://github.com/alpaca-lang/alpaca/issues/271#issuecomment-2327035096) |
| 71 | The typer is "begging for a complete rewrite"; type errors "almost comically hostile to usability"; "There's no command line front-end for the compiler"; missing "basic string manipulation functions and adapters for `gen_server`" | [Alpaca README](https://github.com/alpaca-lang/alpaca/blob/main/README.md) |

### Caramel

| # | Claim | Source |
|---|---|---|
| 35 | "it reuses most of the OCaml compiler frontend to type-check the Parsetree into a Typedtree" | [Caramel `manual/src/contrib/architecture.md`](https://github.com/leostera/caramel/blob/main/manual/src/contrib/architecture.md) |
| 36 | "Atoms in Caramel are treated as polymorphic variants"; OCaml records map to Erlang maps; dynamically dispatched calls unsupported "because we can't know the type of the arguments" | [Caramel syntax cheatsheet](https://github.com/leostera/caramel/blob/main/manual/src/guides/syntax-cheatsheet.md) |
| 37 | Functors silently broken: applying a parameterised module compiles a call to `pmod:some_function()` but no `pmod.erl` is created. Never answered; left open until archival | [Caramel issue #98](https://github.com/leostera/caramel/issues/98) |
| 38 | Every generated Erlang function has exactly one head with dispatch pushed into a `case` (e.g. `handle_message(State, Msg) -> … case Msg of …`) | [Caramel `examples/processes.t/run.t`](https://github.com/leostera/caramel/blob/main/examples/processes.t/run.t), [`examples/ocaml_to_erlang.t/run.t`](https://github.com/leostera/caramel/blob/main/examples/ocaml_to_erlang.t/run.t) |
| 39 | The committed expected output shows "Warning 8: this pattern-matching is not exhaustive" followed by "Compiling registered_process_name.erl OK", and the emitted Erlang retains the partial `case` | [Caramel `examples/processes.t/run.t`](https://github.com/leostera/caramel/blob/main/examples/processes.t/run.t) |
| 40 | "my focus has shifted to other projects and I don't think I'll continue working on Caramel any time soon… the language would move further away from OCaml… I encourage you to try out Gleam ✨ … plenty of people using it for real-life workloads already" — leostera, 2022-08-05. His BOB 2024 abstract: Caramel answered "why is Erlang hard to type? – and as it turns out, it is not!" | [Caramel discussion #102](https://github.com/leostera/caramel/discussions/102), [BOB 2024 talk page](https://bobkonf.de/2024/ostera.html) |
| 41 | `type 'm recv = timeout:after_time -> 'm option`; `send : 'm Erlang.pid -> 'm -> unit`; `contramap : ('b -> 'a) -> 'a Erlang.pid -> 'b Erlang.pid` | [Caramel `stdlib/process.ml`](https://github.com/leostera/caramel/blob/main/stdlib/process.ml) |
| 42 | The "Typed OTP" manual chapter contains one line — its title. Language Features, Standard Library and Typed OTP are empty links in the table of contents | [Caramel `manual/src/reference/otp/index.md`](https://github.com/leostera/caramel/blob/main/manual/src/reference/otp/index.md), [`manual/src/SUMMARY.md`](https://github.com/leostera/caramel/blob/main/manual/src/SUMMARY.md) |
| 43 | Raw `Erlang.spawn`/`Erlang.send` generate `-spec start(_) -> beam__erlang:pid(_).` and send an integer to a loop that never receives — no error, no warning | [Caramel `examples/processes.t/run.t`](https://github.com/leostera/caramel/blob/main/examples/processes.t/run.t) |
| 44 | Last commit on `main` 2022-08-10 (by an outside contributor); last Ostera commit 2021-03-11; `sugarcane` rewrite branch last touched 2022-02-26, with an earlier commit "chore: get rid of stdlib and docs for now"; last release v0.1.1 on 2021-03-07 | [commit 690f109](https://github.com/leostera/caramel/commit/690f1097f87923e193d4bf0c1cc31cccb6eae76a), [commit c34a952](https://github.com/leostera/caramel/commit/c34a95210133cba59d09e2209ad4c50a2e396b37), [commit 0fa447c](https://github.com/leostera/caramel/commit/0fa447c35ae230e6e5607f51cf69a9e5556fc1ef), [releases](https://github.com/leostera/caramel/releases/tag/v0.1.1) |
| 45 | "This repository was archived by the owner on May 19, 2026. It is now read-only." Repo moved from `AbstractMachinesLab/caramel` to `leostera/caramel` | [github.com/leostera/caramel](https://github.com/leostera/caramel) |
| 72 | The repo vendors its own copies of ocaml-lsp 1.4.0 and ocamlformat 0.17.0 | [Caramel `vendor/`](https://github.com/leostera/caramel/tree/main/vendor) |

### NVLang

| # | Claim | Source |
|---|---|---|
| 46 | "NVLang's type system extends the Hindley-Milner type system with specialized constructs for actor-based concurrency"; "Robinson's unification algorithm with an occurs check"; Algorithm W; Damas & Milner POPL '82 is the only type-theory foundation cited | [arXiv:2512.05224 §3, §3.4, §3.9, §5.1](https://arxiv.org/html/2512.05224v1) |
| 47 | Type grammar includes nominal ADTs, `Pid[τ]`, `Future[τ]`, `MonitorRef` and an `Any` type that is never mentioned again | [arXiv:2512.05224 §3.1](https://arxiv.org/html/2512.05224v1) |
| 48 | Zero occurrences of "subtyping", "semantic subtyping", "set-theoretic", "union type", "intersection", "row polymorphism" or "negation type"; no Castagna, Frisch, CDuce or Elixir set-theoretic-types reference in 26 refs; Caramel, Hamler and purerl absent from the bibliography | [arXiv:2512.05224 full text and bibliography](https://arxiv.org/html/2512.05224v1) |
| 49 | Every function is single-headed; the word "clause" occurs twice in the paper, both incidental | [arXiv:2512.05224 §2.1–2.3, §6.4](https://arxiv.org/html/2512.05224v1) |
| 50 | `T-Case` requires all branches to have the same result type τ | [arXiv:2512.05224 §3.3.5](https://arxiv.org/html/2512.05224v1) |
| 51 | The Receive rule carries an opaque, never-defined premise `Exhaustive(M, {pᵢ})` | [arXiv:2512.05224 §4.2](https://arxiv.org/html/2512.05224v1) |
| 52 | Theorem 4.3's entire proof: "Exhaustiveness is verified by the pattern matching compiler, which checks that the set of patterns {pᵢ} covers all constructors of ADT M." No algorithm, no decidability argument, no complexity bound | [arXiv:2512.05224 §4.6](https://arxiv.org/html/2512.05224v1) |
| 53 | "Each actor declares a message type—a sum type enumerating all messages it can receive—and the type system enforces that only valid messages are sent to that actor"; `Pid[τ]`, `Future[τ]`, `await : Future[τ] → τ` | [arXiv:2512.05224 §2.2, §3.7](https://arxiv.org/html/2512.05224v1) |
| 54 | Uniform-Reply: "NVLang enforces that all constructors in an actor's message type reply with the same type… This uniformity requirement simplifies the type system"; §2.3 concedes it "mirrors the design of Akka Typed" | [arXiv:2512.05224 §3.6.2, §2.3](https://arxiv.org/html/2512.05224v1) |
| 55 | "mailbox", "selective receive", "after", "timeout", "gen_server", "behaviour" and "callback" do not appear anywhere in the paper; supervision is a bespoke language construct, not OTP behaviours | [arXiv:2512.05224 §2.5, §4.4–4.5, §7.1](https://arxiv.org/html/2512.05224v1) |
| 56 | `𝒰(Pid, Pid[τ]) = ∅` — an untyped `Pid` unifies with any typed `Pid` producing no constraints, deliberately, "to enable interoperability with Erlang code where message types are unknown"; §5.6 specifies "complete type erasure" | [arXiv:2512.05224 §3.1, §3.4, §5.6](https://arxiv.org/html/2512.05224v1) |
| 57 | Single author (Miguel de Oliveira Guerreiro, IST/University of Lisbon), submitted 2025-12-04, arXiv-only, no venue; five theorems, all proof sketches, none mechanised | [arXiv:2512.05224 abstract page](https://arxiv.org/abs/2512.05224) |
| 58 | No repository link, artifact statement, availability statement, LOC count or implementation-language statement anywhere in the paper, despite six benchmarks requiring a working compiler for three languages | [arXiv:2512.05224 full text](https://arxiv.org/html/2512.05224v1) |
| 59 | Reference [23] attributes "Gradual typing of Erlang programs: The eqWAlizer experience, ICFP '22" to Sagonas and Lindahl — eqWAlizer is Meta's tool and no such publication exists; the paper also contains two incompatible surface syntaxes and four different send syntaxes (`c.send Increment`, `send c "hello"`, `p ! m`, `p.send m`) | [arXiv:2512.05224 bibliography, §2.2, §4.2, §6.4](https://arxiv.org/html/2512.05224v1) |
| 61 | NVLang on Gleam: "Gleam's actor types are relatively simple, treating all messages uniformly" — recorded as NVLang's *secondary characterisation*, not as an established fact about Gleam | [arXiv:2512.05224 §7.2](https://arxiv.org/html/2512.05224v1) |

### Gleam

| # | Claim | Source |
|---|---|---|
| 60 | "Gleam functions can have only one function head. Use a case expression to pattern match on function arguments." | [Gleam for Elixir users cheatsheet](https://gleam.run/cheatsheets/gleam-for-elixir-users/); cf. [Gleam for Erlang users](https://gleam.run/cheatsheets/gleam-for-erlang-users/) |
| 62 | Gleam v1.0 released 2024-03-04 | [gleam.run/news/gleam-version-1](https://gleam.run/news/gleam-version-1/) |
| 63 | "a strong desire to have only one way of doing things"; "Any new feature has to be generally useful and enable new things not otherwise possible in Gleam, while being a worthwhile trade for the added complexity" — Louis Pilfold, 2024-03-04 | [gleam.run/news/gleam-version-1](https://gleam.run/news/gleam-version-1/) |
| 64 | Gleam's exhaustiveness checker implements Jules Jacobs' "How to compile pattern matching" algorithm; described entirely in terms of `case` expressions, never connected to function heads | [gleam.run/news/v0.33-exhaustive-gleam](https://gleam.run/news/v0.33-exhaustive-gleam/) |
| 73 | Issue #64 "Disallow multiple functions with the same name" — opened by lpil 2019-02-02, **empty body, zero comments**, closed by a one-line commit "Disallow duplicate module functions" adding `Error::DuplicateFunction` | [gleam issue #64](https://github.com/gleam-lang/gleam/issues/64), [commit 6fee1aa0](https://github.com/gleam-lang/gleam/commit/6fee1aa0e52c07e90e989190d1a12c336257027b) |
| 74 | All 143 issues of `gleam-lang/suggestions` enumerated: none requests multi-clause function heads. Exact-phrase and semantic searches across `gleam-lang/gleam` issues and discussions return no feature request for it | [gleam-lang/suggestions](https://github.com/gleam-lang/suggestions/issues) |
| 75 | `DuplicateName` renders as "Names in a Gleam module must be unique so one will need to be renamed" — no explanatory comment in `error.rs`, `call_graph.rs`, `analyse.rs` or `type_/error.rs`; the repo has no ADR or design-notes directory | [gleam-lang/gleam `compiler-core/src/error.rs`](https://github.com/gleam-lang/gleam/blob/main/compiler-core/src/error.rs) |
| 76 | Issue #419 is about function *overloading* (`double(Int)` vs `double(Float)`); lpil: "What is the type of the `main` function in this module?… These are not a trivial problems." Also: "if you look at all the languages on the BEAM the majority of them do not support the definition of multiple functions with the same name" | [gleam issue #419](https://github.com/gleam-lang/gleam/issues/419) |
| 77 | On destructuring a tuple in a parameter: "In Gleam we don't have multiple ways to do the same thing, and we only add features to solve problems that cannot otherwise be solved, so this feature is unsuitable for addition." — lpil | [gleam discussion #1451](https://github.com/gleam-lang/gleam/discussions/1451) |
| 78 | "No function overloading results in a much simpler language and easier to read code. You don't have to track complicated unions or type classes or such." — lpil, 2024-03-11, answering a question about **overloading**, not multi-clause heads | [ErlangForums, "Gleam v1.0.0 released", post #7](https://erlangforums.com/t/gleam-v1-0-0-released/3351/7) |
| 79 | "It was largely an experiment to see how we could represent multiple function clauses without duplicating the name." — lpil, 2019, on the abandoned `examples/clauses.glm` | [Elixir Forum t/20349, post #137](https://elixirforum.com/t/gleam-a-statically-typed-language-for-the-erlang-vm/20349/137) |

---

**Method note.** Findings were gathered by five parallel agents working from repository
sources (GitHub API for dates and archival state, file contents at pinned commits), official
documentation, and the arXiv full text. Three explicit non-findings are preserved above
because a later reader would otherwise assume nobody looked: **no statement from Alpaca's
maintainer** explaining why it stopped, **no stated reason for Hamler's stop**, and **no
stated Gleam rationale** for the single-function-head rule. Unchecked surfaces are named in
[§4.4](#44-unchecked-surfaces).
