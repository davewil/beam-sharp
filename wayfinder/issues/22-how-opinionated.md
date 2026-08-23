# 22 — How opinionated is the language? Grammar, attributes, or convention

Type: grilling
Status: **resolved 2026-08-23** — David decided the residue. There is no incomplete marker, and a
signature with no clauses stays a hard error. The measurement pass and survey below are kept as the
evidence; they did not make this call.
Blocked by: 21 — resolved

## ANSWER — 2026-08-23

**There is no incomplete marker. A signature with no clauses stays a hard error.**

```csharp
public int Priority(FrameType f)      // still `error: Priority has a signature but no clauses`
```

David, asked what not building it would cost once the cost was measured:

> *"no, I don't think a half-written module is worth running, the compiler error is enough"*

The question the survey below spent itself on — attribute, keyword or convention — never gets
asked, because the construct does not exist. Nothing is added to the grammar, and the sixteenth
keyword is not spent.

### This overturns ticket 23 §7, which is the real consequence

[23 §7](23-what-the-language-owes-an-agent.md) decided *"a stub is legal, with an explicit marker"*,
and handed the spelling here. Both halves are now reversed: the stub is not legal, and there is no
marker. §7's argument was that the compiler is an interlocutor as well as a gate, so refusing to
compile withholds the residual exactly when it is most useful. **The measurement is what answered
it** — `--api` already prints that residual for a half-written module, exit 0:

```
int Priority(:body | :header | :heartbeat | :method)
```

So the interlocutor already exists, on a channel that works today. What §7 additionally wanted was a
`.beam` out of a module with a hole in it, and that is the part David refused.

Four things follow, and only one is work:

1. **The release gate §7 implied never has to be built.** It would have been the first construct in
   the language whose purpose was to be removed before shipping. There is now nothing to refuse.
2. **§12's two `[incomplete]` examples die with it**, since they were that marker in two positions.
3. **§8a is unaffected, because it was already unreachable** — 23's own build state records that
   there is no generator, so there is no scaffolded payload position wanting a stub type.
4. **One citation needs correcting.** `bs_api.erl` quotes §7 to justify `--api` answering for a
   half-written module. That behaviour **stands** — it rests on the module's own argument, that
   exhaustiveness is a property of the bodies while the API is what the signatures declare — but it
   can no longer lean on an overturned section, and the comment is corrected in place.

### The three other questions

Answered on the measurements above rather than referred back, since each turns on mechanism. Say so
if any is wrong and I will reopen it.

1. **Does the trigger count as fired?** Moot. The residue is decided, so it no longer matters
   whether 25's unwritten database exemplar would have narrowed it further.
2. **Is the domain arm dead?** **Yes**, and on mechanism rather than taste. No attribute grammar has
   ever existed; `[Port]` has no enforcement job left after F18 and F24; and the one non-vacuous DDD
   invariant, aggregate boundary, is already enforced by the record tag minted from the qualified
   module path (F3). Every candidate the arm rested on is built, dead, or bought elsewhere.
3. **Split out "which modules may name this one"?** **Yes**, as 22 itself proposed. Raised as
   [ticket 60](60-which-modules-may-name-this-one.md); a module today controls what it exposes,
   never who may name it, and until now that question belonged to nobody.

## MEASUREMENT PASS — 2026-08-23. The trigger has fired, and the ticket has shrunk to one construct

Status moved from `deferred` to `open`. **This section decides nothing.** 22 is HITL; what follows
is the ticket's own premises measured against the compiler that now exists, at `3492932`, so the
decision is made against code rather than against precedent. That was the whole reason for the
deferral.

### The trigger fired, and a second trigger disagrees with it

22's own trigger named the WebSocket handler *or* the protocol parser. **Both now exist** — 25b
(2026-08-13) and 25c, the event-queue consumer whose `frame.bs` is the protocol parser — and both
report the same thing: `record`, the minted tag and `with` appear in `index.bs` and nowhere else.
The DDD constructs did not narrow anything because they never showed up.

**Ticket 25's own candidate-set table nominates a different exemplar.** The only row listing 22 in
*"Tickets it decides"* is **database querying** (`17, 18, 22`); 25b lists `14, 20` and 25c lists
`12, 14, 15, 18`. The database exemplar is unwritten, and 25 calls it *"doubly owed"*. So the two
triggers disagree: the one this ticket wrote for itself has fired, the one ticket 25 wrote for it
has not.

### Four premises have gone stale since 2026-08-12, and each one removes an option

**1. There is no attribute grammar, and there never has been.** This ticket's case for attributes
rests on *"the mechanism already exists in the prototype for `[Erlang("lists", "reverse")]`"*. It
does not. The parser's `decl` alternation is `module_decl | type_decl | signature | clause |
foreign_decl | behaviour_decl | record_decl | using_decl` (`compiler/src/bs_parser.yrl:76-83`) and
nothing in it is bracket-shaped; `[` and `]` reach the grammar only in list syntax. `[Erlang(…)]`
and `[module: GenServer]` appear nowhere outside `wayfinder/` — **zero lines beginning with `[` in
all 99 `.bs` files in the repo.**

Both were built as keywords instead, and *that* is the finding:

| The attribute in the prose | What the compiler actually took | Where |
|---|---|---|
| `[Erlang("ets", "lookup")]` | `using :ets { … }` | `bs_parser.yrl:131-138` |
| `[module: GenServer]` | `behaviour GenServer` | `bs_parser.yrl:125` |

Twice the language has needed exactly what an attribute is for, and twice it has taken a keyword —
`behaviour` because it is *"the platform's own word, and literally what is emitted"*
(`bs_parser.yrl:118-124`). **So "domain conventions as attributes" is not the cheap half of the
candidate synthesis.** It is a lexer rule, a `decl` arm, an AST node and a checker pass before the
first domain attribute exists — and this ticket's argument for that arm was that the machinery had
already been paid for.

**2. `[Port]` has no enforcement job left, now by construction rather than by argument.** Ticket 21
left it documentation-only. F18 gave deep validation to `ValidateAs<T>` (2026-08-18) and F24
(2026-08-23) emits the boundary guard at exported functions, so the check `[Port]` was going to
mark is emitted where the compiler already compiles, at every public function, with nothing to opt
into and no opt-out. Ticket 18 resolved on 2026-08-13 and dropped its relation to this ticket as
stale.

**3. The one non-vacuous DDD invariant is already enforced, without a keyword.** 22 sifted four
candidate invariants and kept exactly one — aggregate boundary enforcement. Ticket 26 §1 mints the
record tag from the **qualified** module path (built as F3), on David's own requirement that
*"`Update(Order o)` called with an `Invoice` must be an error"*. It is checked at compile time and
again at the boundary, for +14 bytes. **The single thing an `aggregate` keyword was going to buy is
in the language already, bought by the record system.**

**4. The visibility half split out and shipped without this ticket.** 22's second open question —
*"is this one decision or two?"* — is answered **two**. Ticket 40 §3 decided it and F12 built it on
2026-08-17: `public`/`private` on the signature, private by default (`bs_parser.yrl:262-268`,
`bs_check.erl:43`). 22 predicted this outcome and asked for it: *"it probably is [worth having
independently], in which case it should be split out rather than held hostage here."*

**What did not ship is the half 22 called the useful one.** A module controls *what* it exposes,
never *who* may name it — `add_module_import/5` reads only the callee's export set
(`bs_check.erl:407-425`), and there is no `internal`, `friend`, `sealed` or `visible_to` anywhere
in the checker. So *"which modules may name this one"* is unbuilt, unowned, and now a free-standing
question rather than a part of this one.

### The open question this ticket asked first, and the evidence nobody logged against it

*"Does the guardrail argument survive?"* Two exemplars agreeing that the DDD constructs never
appeared is evidence against the **narrowing** case. It says nothing about the **guardrail** case,
because neither exemplar was an agent drifting. That hole is real and this section does not close it.

But there is one data point, and it is sitting unlabelled in ticket 25's results. The first time
the exemplars met the compiler, agent-written beam-sharp had drifted four ways:

- not one of the three `index.bs` files declared a `module` at all — caught by **F15**
- a `using` in 25a's `index.bs` that the other files were expected to inherit — caught by **F11**
- `admit.bs` reads five fields off a `Request` record that does not exist, undetected for six days
  — caught by **F3**
- the route table could not be written at all — raised as ticket 53, since resolved by F20

**Every one was caught by an architecture-neutral structural rule, and none of them would have been
caught by `[Aggregate]`, `[Command]` or `[Port]`.** The guardrail argument survives; what it
supports is the half of the candidate synthesis that is already built.

### So the residue is one construct, and what it needs is a spelling

Everything else on this ticket is built, dead, or split out. What remains is the question
[ticket 23](23-what-the-language-owes-an-agent.md) §7 handed over and recorded as fog: **how the
incomplete marker is spelled.** 23 decided its function and deliberately not its form — the
incompleteness is *a fact in the file* so the release gate is a text search; one marker per
**declaration**, not per hole; and CI refuses any marker, which makes it the first construct in the
language whose purpose is to be removed before shipping.

23 writes it in attribute syntax, in two positions:

```csharp
[incomplete]                                  // on the function
(:ok, ApplyReply) Apply(Order o, Command c);

type ApplyReply = [incomplete];               // in *type* position, so its own declaration
```

**Neither position parses today, and the compiler enforces the opposite rule.** A signature with no
clauses is a hard error — `no_clauses` at `bs_check.erl:1062-1064`, printed as *"has a signature but
no clauses"* at `bs_diag.erl:478-479` (~~`bs_diag.erl:468`~~, corrected 2026-08-23: F25 added ten
lines above it; the claim holds, the line number had drifted). There is no marker for a gate to
refuse, and there is no gate.

The compiler delta, per spelling:

| Spelling | What it costs |
|---|---|
| **Attribute** `[incomplete]` | invent the attribute grammar for one construct: lexer, `decl` arm, AST node, checker. Then a *second* rule for type position, where `[` means nothing today — `list<T>` is the type spelling and `[a, b]` is patterns and values only |
| **Keyword** `incomplete` | one lexer rule, one `signature` arm, one `type_decl` arm. The sixteenth keyword, and the same shape `public`/`private` took — and the same shape `behaviour` and `using` took when they were prose attributes |
| **Convention** — a comment or a naming rule | free, and refused by 23's own requirement. The marker has to make `no_clauses` legal, and a comment the compiler does not parse cannot |

The third option is not really on the table, because the marker must change what compiles. That
leaves inventing bracket syntax for one construct, against a sixteenth keyword — and the language
has taken the keyword twice already under exactly this pressure.

### What this ticket is asking David, and it is four questions rather than one

1. **Does the trigger count as fired**, given that 25's table nominates the unwritten database
   exemplar and not the two shapes that exist and agree?
2. **Is the domain arm dead?** No attribute grammar exists, `[Port]` has no job left, and the record
   tag already enforces the one invariant `aggregate` was for.
3. **Split out *"which modules may name this one"*** as its own ticket, as 22 itself proposed?
4. **How is the incomplete marker spelled**, and does that build enter the queue?

## SURVEY — 2026-08-23. The question is position, not spelling, and the survey is unanimous

The measurement pass above enumerated three spellings — attribute, keyword, convention — and all
three assume the marker sits **on the declaration**. Nobody had checked whether any other language
does that. Ran it rather than reasoning about it: `wayfinder/prototypes/22a_incomplete_marker_probe/`,
four runnable probes, each with a control that must be seen failing before its clean result counts.

| Language | How "unfinished" is spelled | Position | What the compiler does |
|---|---|---|---|
| **Gleam 1.18.1** | `todo` — a keyword | **body** | **compiles**, `warning: Todo found` — *"This code is incomplete"*, and it names the inferred type: *"I think its type is `Int`"* |
| **C# 9.0.306** | `throw new NotImplementedException()` | **body** | **compiles, and says nothing at all** — 0 warnings. Deferred to run time |
| C# | `public partial int Apply(int)` | declaration | **hard error CS8795** — *"must have an implementation part"* |
| C# | `partial void Audit(int)` (private) | declaration | legal, silent, and **every call is erased** |
| C# | `abstract string Render()` | declaration | legal — but means *"a subclass must supply this"*, a contract, not an admission |
| **Erlang/OTP 28** | `-spec` with no function | declaration | **hard error** — *"spec for undefined function apply_order/1"* |
| **B# at `0b761f6`** | signature with no clauses | declaration | **hard error** — *"Weigh has a signature but no clauses"* |

### Three findings, and the third one is the decision

**1. B# is not the odd one out. Every surveyed language makes a bodiless declaration a hard error.**
C# refuses it (CS8795), Erlang refuses it, B# refuses it. The one case C# permits — old-style
private `partial` — it permits by going *silent* and erasing the call, which is the opposite of what
23 §7 wants. So the premise that B# is being unusually strict is false; `no_clauses` is the majority
rule, and 23 §7 is asking B# to leave the consensus on purpose.

**2. Both languages that have a real marker put it in body position, and Gleam is the model.**
Gleam's `todo` does everything 23 §7 asks: the stub compiles, the diagnostic *names what is owed*,
and `gleam build --warnings-as-errors` is the release gate — a compiler flag rather than a text
search, though `grep todo` would work equally well, so §7's text-search requirement survives either
way. **The one thing the ticket assumed was contested — attribute versus keyword — is not contested
anywhere.** Nobody spells this with an attribute. Gleam uses a keyword; C# uses a library exception.

**3. Body position is cheap to write in B# and destroys the diagnostic — which is not the same
objection this section first made.**

~~B# has already refused the clause that body position needs: `Weigh(_) -> 0` is an error,
"discards cases the compiler can name".~~ **Corrected 2026-08-23, same day, before the question was
put to David.** That was measured on `_` over a closed atom union, and generalised from the one
parameter type that trips the check. Two more probes falsify it — both **compile, exit 0**:

```
Weigh(f) -> 0          // bound variable, same closed union     — StubBound,  clean
Apply(o, c) -> 0       // 23 §7's own record params             — StubRecord, clean
```

The `_` diagnostic says in its own words that a catch-all is *for* "a residual with an unbounded top
in it", so it was never the general rule about total clauses that the first draft read it as. **A
body-position marker is perfectly writable in B# today.** The objection is not that it cannot be
written. It is what happens when it is:

**3a. A total clause consumes the residual, and that residual is the entire point.** `walk`
subtracts what each clause certainly matches, so `Weigh(f) -> …` leaves nothing. StubBound compiles
**silently** — the compiler that would have said *"you still owe `:method | :header | :body |
:heartbeat`"* says nothing at all. 23 §7 wants a stub whose residual is *"the entire declared
parameter type, the most informative diagnostic the language can produce"*; body position turns that
into a clean build. **That is precisely C#'s failure mode** — `NotImplementedException` compiles
with zero warnings — and it is the half of the survey worth *not* copying.

**3b. §7 decided one marker per declaration, not per hole; body position marks holes by
construction.** A function with three written clauses and one unwritten gets a marker per unwritten
body. §7 ruled that out explicitly, and a declaration-position marker is the only form that obeys it.

Every surveyed language is **single-body**, so the distinction cannot arise for them and their
unanimity carries no information about it. B# is multi-clause with an exhaustiveness checker, which
is the one thing none of them had to weigh — so on *position* the survey does not transfer, and this
is [[a-ticket-that-resolves-against-its-own-survey]] flagged rather than folded into a
recommendation.

### The residual 23 §7 asks for already exists; `no_clauses` short-circuits in front of it

`walk([], Residual, _, Diags, _) -> {Residual, ...}` (`bs_check.erl:2206-2207`) returns the residual
untouched, and the residual is seeded as the entire declared parameter tuple at
`bs_check.erl:1060`. The inexhaustive diagnostic already prints it well — measured on the same probe:

```
error: Weigh is not exhaustive
  no clause matches:
    Weigh(:body | :heartbeat) -> ...
```

The `[] -> {F, [{error, Line, Name, no_clauses}]}` arm at `bs_check.erl:1062-1064` returns *before*
that walk ever runs. So 23 §7's *"a stub's residual is the entire declared parameter type"* is not a
feature to build — it is a feature to **stop suppressing**. Delete the early return for a marked
signature and the existing walk produces exactly that, naming every case the agent still owes.

### So the compiler delta, per spelling, measured rather than estimated

| Spelling | Written in B# | What the compiler must gain |
|---|---|---|
| **Keyword on the declaration** | `incomplete public int Weigh(FrameType f)` | one lexer rule; one `signature` arm beside the two at `bs_parser.yrl:262-264`; skip the `no_clauses` early return when the flag is set. The residual then falls out of the existing `walk`. Same shape `public`/`private` took in F12, and `behaviour` and `using` took before it |
| **Attribute on the declaration** | `[incomplete]`<br>`public int Weigh(FrameType f)` | all of the above, **plus** invent bracket syntax: a lexer rule, a `decl` arm, an AST node and a checker pass, for a construct no surveyed language spells this way. Then a *second* rule for type position, where `[` means nothing today |
| **Body position** — the survey's answer | `Weigh(f) -> incomplete` | one lexer rule and one expression arm — **cheapest of the three to build**. The cost is not build effort: the clause is total, so it consumes the residual and the stub compiles silently, and §7's *one marker per declaration* becomes one per hole |
| **Convention** — a comment | `// TODO` | free, and refused by 23 §7's own requirement: the marker must change what compiles, and a comment the parser drops cannot |

### What NOT building it costs — David's question, 2026-08-23, measured

Asked directly: *"if incomplete marker is not implemented what's the cost? a compiler error?"*
Probes 6 and 7, `run_cost.sh`. Three results, and the first one killed my own hypothesis.

**1. A stub does not blind the checker.** I expected one unwritten function to darken its module.
It does not. `StubMixed` holds a stub, a correct function and a planted return defect, and the
compiler reports **2 errors**; the same file with the stub deleted reports **1**. The stub adds its
own error and suppresses nothing. So the cost is not lost diagnostics.

**2. The cost is that nothing is emitted.** `StubBlocks` is correct apart from one unwritten
function — `Weigh` is total, exhaustive and would run today. Result: `beam files emitted: 0`.
F15 makes the directory the module, so **one unwritten function blocks execution of every finished
function in the directory**. You cannot run or test the written half until the last hole is filled.
That is the whole cost, and it is a *workflow* cost rather than a correctness one.

**3. `--api` already answers for the half-written module, and already prints the residual.** Same
module, exit **0**:

```
module StubBlocks
int Priority(:body | :header | :heartbeat | :method)
int Weigh(:body | :header | :heartbeat | :method)
```

This closes the inconsistency 23 recorded between `bs_api.erl:31-37` and `bs_check.erl:1063-1064`
with a measurement: the two really do disagree, `--api` answers where compilation refuses, and the
thing `--api` prints for the unwritten function **is** the residual §7 wants. So §7's diagnostic
exists today on a channel that already works. What it does not have is a way to produce a `.beam`.

**The cost of the workaround is the argument for the marker.** With no marker an agent must write
something plausible, and `Weigh(f) -> 0` compiles clean and silent (case 4). So today's choice is
not *"error or marker"* — it is **a hard error, or a placeholder that ships looking finished**.

### What this does to the four questions

Questions 1–3 are unchanged; the survey speaks only to question 4. On that one it kills the
**attribute** arm outright — no surveyed language spells this with an attribute, so B# would be
inventing bracket syntax in order to be alone, and it would have to invent it twice because `[`
means nothing in type position. It does **not** kill body position, which is cheap to build and is
what both languages with a marker chose; body position loses on what it costs the *diagnostic*
(3a, 3b) rather than on what it costs the compiler. That is a judgement about which is worth more —
a stub that compiles quietly, or a stub that names everything still owed — and it is David's.

**This section still decides nothing.** 22 is HITL.

## DEFERRED 2026-08-12 — revisit when there is a walking skeleton

**Trigger**: a walking skeleton exists to decide against. Not before.

**Reason** (David): *"I don't have an answer now, and not walking skeleton to decide on."* The
decision is close to irreversible — ticket 21 established that **no model has both enforcement and
revisability** — and every argument currently on this ticket is made from precedent rather than
from code that exists. Deciding it from precedent alone would be choosing an architecture for a
language nobody has written a program in yet.

**Check the trigger has actually fired before picking this up.** A skeleton that compiles one
function is not enough to judge whether a DDD grammar narrows the addressable set; ticket 25's
exemplars are the real test, and at least one of the non-aggregate shapes (WebSocket handler,
protocol parser) needs to exist. ~~**The skeleton now exists (2026-08-13); the exemplars do not**, so
the trigger has half fired.~~

**THE TRIGGER HAS NOW FIRED — 2026-08-13.** The skeleton exists, and so does one of the two
non-aggregate shapes this ticket named: the **WebSocket handler**
([`25b`](../prototypes/25b-websocket-handler.md), with a lowering that runs). What it reports is a
result for this ticket, and it is *not* the one the deferral feared:

- **The DDD constructs did not narrow anything — they never appeared.** `record`, the minted tag,
  `with` and projection are absent from every file of the WebSocket handler except its
  declarations. A protocol handler is patterns, integers and binaries. Nothing about the
  aggregate-shaped design made it miserable, which is the empirical answer this ticket was
  deferred to get.
- **What made it awkward was the type system's treatment of binaries** — length-prefixed framing
  sits outside ticket 20's grammar, and ticket 12's closed-residual rule costs eleven clauses to
  say "reserved". Both are orthogonal to how opinionated the language is.

**So the risk this ticket was deferred over is not the risk the exemplar found.** Two honest
limits before anyone reads that as a green light: it is **one** data point, and ~~the **protocol
parser** — the other non-aggregate shape named above — has not been written~~ — **corrected
2026-08-23: it has been.** 25c's `frame.bs` is that shape, and it repeats this answer. Both
non-aggregate shapes now agree, so only the first limit still stands. Whether one exemplar
is enough to decide a near-irreversible question is David's call, not the exemplar's.

**Inherited from [ticket 23](23-what-the-language-owes-an-agent.md) §7, 2026-08-13.** 23 made a
signature-with-no-clauses legal when carrying an explicit `[incomplete]` marker, and deliberately
did **not** spell it: attribute, keyword or convention is this ticket's subject exactly. Three
things 23 fixed about it regardless of spelling, so this ticket decides the form and not the
function — it is **a fact in the file** rather than only a diagnostic, because the release gate
should be a text search; it is **one per function**, not one per hole, because 23 §12 moved the
enumeration of holes onto the diagnostic channel; and **CI refuses any marker**, which makes it the
first construct in the language whose purpose is to be removed before shipping. That last property
is a live argument for this ticket: a construct that must not survive a release is a strong case
for enforcement, which is precisely the axis 21 found nothing can give you along with revisability.

**Inherited from [ticket 24](24-testing-story.md) §2, 2026-08-13, and it sharpens the visibility
half of this ticket by giving it a consumer.** 24 made the client API the test boundary and had the
compiler publish it, using ticket 14's behaviour contract as the discriminator — which classifies
callbacks and client API without needing visibility at all. What it cannot classify is the
remainder: a helper like `RecomputeTotal/1` is neither, and lands `unclassified`. 24 left it there
rather than inventing a rule, so this ticket inherits it with the field narrowed.

Two things that changes here. **The neutral-visibility option now has a concrete job** it did not
have when this ticket was deferred — 22's own note observed that if the only enforced thing is
visibility then the guardrail may be much thinner than assumed, and this is a case where it is not:
an agent writing tests in a loop targets `unclassified` functions **because they are the easiest
thing in the directory to test**, which is structural drift of exactly the kind agent authorship
produces. And **the useful boundary reading is confirmed by a second route**: 22 already suspected
that with directory-as-module the useful notion is *which modules may name this one* rather than
which functions are exported, and 18 §5's measurement says the same from the other side — elision is
exported-vs-local with one entry label per function, so per-function export control is not a thing
the BEAM offers cheaply.

Note what this does **not** hand over: 24 §1's carve-out — unit-testing a genuinely complex
operation whose edge the client API cannot reach — is a judgement, not a visibility rule, and
survives whatever this ticket decides.

### What each deferred option would need, so the work is not lost

**If domain keywords in the grammar** — `aggregate`, `command`, `query`:
- A decision on what each *enforces*, not merely marks. Of four candidate DDD invariants, three are
  worthless: "a query may not mutate" is vacuous under immutability, "a command returns the
  aggregate" is a trivial signature check, and "invariants hold" needs refinement types (→ ticket
  20). Only **aggregate boundary enforcement** is checkable and non-vacuous.
- Evidence from ticket 25 that a gateway, parser or game server does *not* fight the grammar.
- Acceptance that it cannot be migrated behind an option later.

**If domain attributes** — `[Aggregate]`, `[Command]`, `[Port]`:
- They must be read by the **beam-sharp compiler**, never a separate analyser. Ticket 21: the one
  precedent that needed a second tool in the build (.NET Code Contracts) was simply not run, and
  is archived.
- A statement of what each enforces, same as above.
- Note that ticket 21 leaves `[Port]` with **no enforcement job**: the only mechanism reaching all
  eight violation channels is a check emitted where an external term becomes a typed value, which
  is codegen and belongs to ticket 18. `[Port]` would be documentation only — decide whether that
  is worth a language feature.

**If neutral module visibility** (the reframing that prompted the deferral):
- **Work out what visibility means when the directory is the module.** Between `apply.bs` and
  `total.bs` it is *intra*-module and vacuous — everything already sees everything. The useful
  boundary is **which modules may name this one**, which is a different feature from C#'s
  `internal` and should not borrow its spelling without borrowing its semantics.
- Accept and document that this is **compile-time visibility over beam-sharp source only**. Ticket
  06: the BEAM has no visibility modifiers and *"no way to publish a function to your own compiler
  but not to `erl`"*. Exactly Roc's situation — the design half transplants, the enforcement half
  does not.
- **Decide whether it is worth having independently of the DDD question.** It probably is, in which
  case it should be split out rather than held hostage here.

### Two open questions recorded with it

- **Does the guardrail argument survive?** The case for opinionation leans on "enforced conventions
  constrain the agent". But if the only enforced thing is visibility, an agent can still put a
  handler in the wrong place, name it badly, or reach for the wrong shape — none of which
  visibility catches. The guardrail may be much thinner than this ticket assumes.
- **Is this one decision or two?** "Does DDD go in the language" and "is there a visibility feature"
  are bundled here, and the second may be worth having regardless of the first.

### Consequence for ticket 18

This ticket was coupled to [18](18-boundary-defence.md) on the grounds that you can only defend a
claim once you know what it is. **That coupling is weaker than it was.** Ticket 21 concluded the
only mechanism reaching all eight channels is a check emitted at the points beam-sharp already
compiles — which is decidable without knowing how much domain opinion the core carries. **Ticket 18
should not be treated as blocked by this deferral**; re-check its blockers before assuming it is.

## Question

beam-sharp wants to support a DDD style for rapid business-application development, with ports
and adapters out to everything else. **How much of that opinion goes in the language?**

Three places an opinion can live, and the decision is which conventions go where:

1. **In the grammar** — keywords like `aggregate`, `command`, `query`. Maximum enforcement,
   permanent, and every user of the language inherits the architecture.
2. **In attributes** — `[Aggregate]`, `[Command]`, `[Port]`. Opt-in, compiler-visible, removable.
   ~~The mechanism already exists in the prototype for `[Erlang("lists", "reverse")]`~~ — **false,
   corrected 2026-08-23: no attribute grammar has ever existed in the compiler, and both prose
   attributes were built as keywords instead. See the measurement pass above.** It is still what C#
   itself uses to let ASP.NET and EF layer strong opinions onto a neutral language.
3. **In convention and tooling** — directory names, linting, generators, documentation. Fully
   reversible, project-configurable, unenforceable by the compiler.

### The arguments already on the table

**For baking it in.** The compiler can enforce invariants a general language can only document —
an aggregate may not reach into another aggregate's internals; a command must return the
aggregate; a query may not mutate. Every codebase looks the same, so onboarding collapses, and a
constrained shape is markedly easier for LLM-assisted development to generate correctly. Errors
can speak the domain rather than the type system.

**Against.** The opinion is permanent — you can add to a grammar, never remove from one without
breaking somebody, and Elm 0.19's removal of native modules is the case study (→ ticket 21). Not
every BEAM program is a business app; a gateway, a protocol parser, a game server all fight a DDD
grammar. That matters more here than usual because [ticket 03](03-prior-art-static-multiclause.md)
found BEAM languages die of **no users and no ecosystem**, and narrowing the addressable set is
precisely that failure mode. And architecture is fashion on a far shorter cycle than a language —
Phoenix's contexts changed more than once while Elixir's `defmodule` did not.

### The agent-authorship argument, which the original analysis missed

The map's standing constraint — **written by agents, read by humans** — adds an argument for
opinionation that a human-authorship analysis does not produce: **an enforced convention is a
guardrail on the agent.** A general, flexible language gives an agent more rope, and the
characteristic failure of agent-written code is plausible-looking structural drift — code that
compiles, reads acceptably, and quietly diverges from how the rest of the system is built.
Conventions the compiler enforces are exactly what prevents that.

Weigh this against the arguments above; it does not cancel them. Narrowing the addressable set
still risks the ecosystem failure mode ticket 03 identified, and a grammar still cannot be
retracted. But "conventions cost the author effort" is a much weaker objection when the author is
a program, and "conventions keep the author honest" is a much stronger benefit.

### What ticket 21 established, which constrains the synthesis below

**Every model that enforces anything enforces it with the tool that already builds the code.** Roc:
module resolution plus the linker. Unison: the typechecker. Eiffel: the compiler. The one entry
that failed outright — .NET Code Contracts — needed a *second* tool in the build, and everyone
simply did not run it. **So an attribute is worth something only if the beam-sharp compiler reads
it.** An attribute checked by a separate analyser in CI is Code Contracts again, and Code Contracts
is archived.

**The contract that survived is the one that became a type.** Microsoft's named successor to Code
Contracts is nullable reference types. Eiffel's `require`/`ensure` are still grammar; Ada's
`Pre`/`Post` are still aspects. The library form is the one that died — so the discriminator is
tooling weight, not language-versus-library.

**No model has both enforcement and revisability.** Phoenix moved contexts three times because
nothing in Elixir depended on them; Roc apps are bound to one named platform and the FAQ answers
"No" to swapping. **That trade is real and must be chosen consciously rather than escaped.**

**Roc's `requires` is directly stealable**, even though its enforcement mechanism is not: the
platform declares the shape the application must have, and can hold an app type opaque via
`[Model : model]`. A typed, compiler-checked `requires` is strictly better than Erlang's
`-callback` attributes and works regardless of what the runtime permits.

### The candidate synthesis

Split by kind rather than by strength:

- **Structural conventions in the grammar** — directory is the module, one function per file,
  signatures mandatory on multi-clause functions. These are architecture-neutral. Go bakes in
  exactly this kind and no domain opinion at all, which is why it serves web services and
  compilers equally.
- **Domain conventions as attributes** — enforceable where present, absent where irrelevant, and
  ownable by a framework that can change its mind.

Decide whether that split is right, and if so **exactly which conventions land on each side**.

### The sub-question that will not go away

**What does a port owe the guaranteed core?** If the core's invariants are enforced, an adapter
that hands it a badly-shaped value must not be able to break them silently — and ticket 06 found
that on the BEAM an untyped caller does *not* always crash, with silent unsoundness the worst of
three outcomes. Elm validates values crossing a port at runtime; Gleam and purerl do not validate
at all. This ticket and [ticket 18](18-boundary-defence.md) must agree, and 18 cannot be decided
without this one's answer about how much the core claims.

## Notes

HITL. Raised 2026-08-12 from ticket 01's design conversation. Blocked by 21 because the precedents
carry the failure modes, and this decision is close to irreversible.
