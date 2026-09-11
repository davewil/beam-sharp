# F25 — The return-mismatch diagnostic carries the signature to paste

**Status**      **done 2026-08-23** — 501 tests, twenty gate scripts. `return_not_declared` joins
                `contractual/0`, which is the first time the frozen subset has grown since F16
                defined it.
                **Amended 2026-09-10** ([ENG-346](https://linear.app/davewil/issue/ENG-346)): the
                corrected line is asked the declaration check before it is printed, and where
                that check would refuse it the diagnostic names the pair and the repair instead
                — see [the amendment](#amended-2026-09-10-eng-346--a-correction-the-declaration-check-refuses)
**Implements**  [ticket 23](../../wayfinder/issues/23-what-the-language-owes-an-agent.md) §8's
                second half — *"when a clause returns outside its signature, the diagnostic carries
                the corrected signature to paste"* — under §2 (the compiler synthesises the head,
                never the body) and §4 (a named subset is contractual). It **decides nothing**; 23
                closed 2026-08-13
**Unblocks**    nothing. It is the only item on 23 that was buildable without another ticket first:
                §3 and §6 are unbuilt, §5 waits on ticket 16 §4, §7 waits on ticket 22's spelling,
                and §8a/§9 are unreachable because beam-sharp has no generator
**Depends on**  F16 (the diagnostic as a term, and `contractual/0`), F5 (site 4, the clause return
                check that raises `return_not_declared`), F12 (`#fn.vis`, so the synthesised line
                carries `public` exactly when the source does)

## Why this one now

The feature queue was empty and ticket 23's build state had never been measured. Six of its twelve
sections are built; of the six that are not, this is the only one whose precondition is met — and
23 says of it, in its own words, that it *"needs no new machinery"*.

It is also the section that fails 23's own membership test today. §4's test for the contractual
subset is §2's: **does it hand the agent something to write?** `inexhaustive` passes, and carries
`heads` for exactly that reason. `return_not_declared` prints the uncovered residual and stops,
which tells an agent what is wrong and not what to write — so it is absent from `contractual/0`,
correctly, and this feature is what earns it a place.

## Measured before this file was written, not assumed

`bsc` at `0be76fb`, OTP 28. Three probes, and **two of them changed the design**.

**1. The baseline.** `public int Answer(int n)` with `Answer(n) -> :oops`:

```
error: Answer returns a value its signature does not declare
  not covered by the declared return type:
    :oops
```

**2. Two offending clauses produce two diagnostics, so the corrected signature must be
function-wide.** Measured on `Go(0) -> :zero` / `Go(n) -> (:error, "bad")` against `public int Go`:
two `return_not_declared` errors, one per clause, each with its own residual. Had each carried its
own corrected signature the compiler would print two contradictory pasteable lines — `int | :zero`
and `int | (:error, string)` — and pasting either leaves the other clause still wrong. **The
correction is a property of the function, not of the clause that tripped it**, so it is computed
once from the union of every residual and attached to all of them.

**3. `to_string` renders a record as its mint tag, which is not writable, and this is the reason
the feature has a refusal.** Probed directly:

```
to_string : { Kind: :'R.Invoice', Id: int }
to_pattern: { Kind: :'R.Invoice' }
```

Ticket 26 §1 mints that tag from the **qualified module path** precisely so one field decides the
record. It is a correct description of the set and a bad thing to paste into a signature: it
hard-codes a mint rather than naming `Invoice`. `bs_types` says the same of one other point in its
own comment — `binary \ string` is `[other]`, and *"there is nothing to write for it: the surface
has a word for the top and a word for the refinement, and none for the complement of a refinement
inside its base."*

**A line that looks pasteable and is not is worse than no line**, because §2's whole argument is
that the compiler hands the agent something it can use. So this feature prints the corrected
signature only where every part of it is writable, and otherwise leaves today's message exactly as
it is.

## What is being built

`return_not_declared` gains one line, and only when it can be trusted:

```
error: Answer returns a value its signature does not declare
  not covered by the declared return type:
    :oops
  the signature its clauses justify:
    public :oops | int Answer(int n)
```

### Three rules, each of which a probe forced

**The declared half is the author's own source text; the new half is the algebra's.** The return
type is rendered from the **type AST** — what the author wrote — and the residual from
`bs_types:to_string/1`. That is not tidiness: a function declared to return the record `Order`
renders through the algebra as `{ Kind: :'Shop.Order', … }`, and through the AST as `Order`. Taking
the declared half from source is what makes `Order | :oops` expressible at all.

**Parameters are rendered from the AST for the same reason**, and carry their binder names, because
the line exists to be pasted over the signature it replaces. `bsc --api` deliberately drops
parameter names (they are not part of an API), and this line is not an API answer.

**Refusal is a string test, and that is the honest test rather than a proxy.** The question is
whether the text about to be printed is pasteable, which is a question about the text. Both
unwritable spellings are detectable in the rendering and nowhere else in it: `{` is produced only
by `m_str/1`, the record field set, and `\` only by `b_str([other])`. Both survive nesting inside a
tuple or a list, because nesting renders through the same printers. Testing the type's structure
instead would test a proxy for the claim; testing the string tests the claim.

### Visibility, and why it is on the line

F12 made an unmarked signature private, so `public` is written exactly when it is meant. The
synthesised line reproduces `#fn.vis` — `public` when the source says so, nothing when it does not
— because a pasted line that silently exports a private function is a worse defect than the one
being fixed.

### `return_not_declared` joins `contractual/0`

Once the descriptor carries the corrected signature it passes §4's membership test, so the tag is
added to the frozen subset. The payload is a map and gains a key, which is the additive-only
evolution §4 chose maps for.

## Out of scope

- **Naming a record in the residual.** When the uncovered part of the return type contains a
  record, no signature is printed. Recovering `Invoice` from `:'R.Invoice'` means stripping the
  module prefix when the record is local and qualifying it when it is not, which is a lookup this
  feature does not build. What it would need is recorded here so the work is not lost: the record
  environment already keyed by qualified name, plus a decision about how a foreign record is
  spelled in a signature.
- **An inline map as the declared return type.** `type_source({t_map, _})` answers `none`, so a
  signature written as `{ Id: int } Make(int n)` gets no corrected line either. It is the one
  *written* form that can carry a `Kind:` field, and a signature is not where this feature wants to
  reason about whether the author's tag is theirs to paste. A record **named** in a signature
  arrives as `t_ref` and is unaffected, which is the ordinary case. Recorded here because it is a
  refusal a reader cannot infer from the record rule above — it is the mirror of it, on the declared
  side rather than the residual side.
- **Any type construct this file has not met.** `type_source/1` answers `none` for an unrecognised
  AST form rather than rendering it partially, so a construct added later disables the corrected
  line for signatures using it until someone teaches the function that form. This is deliberate and
  is the reason the feature cannot emit a half-rendered signature, but it does mean a new type form
  silently costs coverage here.
- **Narrowing a signature.** The corrected line only ever widens — it is the declared type union
  the residual. A declared type the clauses never fully use is legal and is not this diagnostic's
  business. 23 §8 names the risk it accepts here: widening becomes frictionless, which is a virtue
  only if widening is meant to be deliberate rather than rare, and the ceiling is what the clauses
  actually do rather than OTP's six-way union.
- **§8's first half**, the named stub type in a generated payload. There is no generator.

## Amended 2026-09-10, ENG-346 — a correction the declaration check refuses

### The measurement

Measured 2026-09-09 at `ea7f896` while resolving [ticket 70](../../wayfinder/issues/70-a-container-of-indiscriminable-members.md),
with no union declared anywhere:

```csharp
module Flat

public map<string, int> Pick(int n)
Pick(1) -> Ints()
Pick(n) -> Bins()

private map<string, int> Ints()
Ints() -> Ints()

private map<string, binary> Bins()
Bins() -> Bins()
```

The diagnostic offered `public map<string, int> | map<string, binary> Pick(int n)`. Pasted, that
line is refused by the declaration check, at a compile and at `bsc --api`:

```
error: no clause head can tell `map<string, int>` from `map<string, binary>`
```

So the compiler recommended a form it rejects: F19's defect a third time. Ticket 70 then decided
the union stays legal one container level in and that the objection to dispatching on it lives in
the advice, so the advice has to agree with the refusal.

### What changed

**The line is pasted back before it is printed.** `as_pasted/2` lexes and parses the line as a
declaration, resolves its return type in the module's type environment, and hands it to
`collapse_decl/2`, the declaration check both `check/2` and `exports_of/1` run. A line that
passes is printed. A line refused because no clause head can tell two members apart gets the pair
and the repair instead:

```
error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  widening the signature to cover it would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  tag the members so a clause head can, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag.
```

The second line of the new text is the declaration check's own header, so the author reads the
same words here as in the refusal they would get by widening the signature by hand. The repair is
09 §5's: *"two cases with the same payload need a tag, and the leading atom in a tuple already is
one."* It was compiled before this section was written: `Pick` returning `(:ints, …)` and
`(:bins, …)` under `(:ints, map<string, int>) | (:bins, map<string, binary>)` compiles clean, a
`Kind` dispatching on the two tags passes the exhaustiveness check, and `--api` answers both.

**Why the check itself and not one of its refusals.** The first fix (`f3e1eee`) asked only the
pairwise test ticket 70 named, and argued that absorption could not reach the line. The
`/code-review` spec axis found two more kinds of printed line the compiler refused when pasted:

| program | printed | pasted |
|---|---|---|
| `map<string, int>` declared, returning a `map<string, term>` | `map<string, int> \| map<string, term>` | `map<string, int>` is absorbed by `map<string, term>` |
| `list<map<string, int>>` declared, returning a `list<map<string, binary>>` | `list<map<string, int>> \| [map<string, binary>, ..]` | `syntax error before: '['` |
| `(int, map<string, int>)` declared, returning `(2, …)` | `(int, map<string, int>) \| (2, map<string, binary>)` | `syntax error before: 2` |

Asking refusals one at a time missed both, so the line now goes through the check and the parser
it would meet when pasted. Anything that refuses it other than indiscriminability withholds the
line, and since the review round (R2 below) the diagnostic says why, including for a failure the
paste-back does not name. When a map pattern ships and the indiscriminability refusal lifts, the
line prints again with no edit here.

**An absorbed declared type is dropped, not refused.** For the first row the correct line exists:
`public map<string, term> Pick(int n)`, which compiles. `signature_line/3` now drops the declared
half whenever the residual contains it (`bs_types:is_subtype/2`), which is F38's rule for the
bottom without F38's premise. The algebra cannot spell `map<string, term>` less `map<string, int>`,
so that residual is `map<string, term>`, and it contains what was declared. Where only one member
of a declared union is absorbed, the declared half is the author's text and cannot be split, and
the paste-back withholds the line, naming the member and what absorbs it (F25.18). Where the line
drops the declared type, it says so (R3).

**Writability is still asked first.** A record residual renders with `{`, which could parse as an
inline map type, so `writable/1` refuses it before the parser sees it.

**The term.** The descriptor gains four keys, each present on every `return_not_declared`, and
the three below `declared` are `none` when they have nothing to say, for F25.9's reason: a
consumer never tells "absent" from "refused". Adding keys is the additive-only change ticket 23 §4
chose maps for.

| key | when it is not `none` |
|---|---|
| `declared` | always: the declared return as the author wrote it, which every message leads with since Round 3 |
| `indiscriminable` | the widened line is refused: `#{member, beside}`, named as `indiscriminable_union`'s fields are and, since Round 4, as the author wrote them; `expanded`, a list of `#{name, is}` for each name that stands for a different spelling; and since Round 5 `declarations` (three lines) and `returns`, or `none` for both and `no_declarations := #{member, inside}` or `#{refused_by}`. `corrected` is `none` |
| `withheld` | no line is offered: `unspellable`, `declared_form`, `#{member, absorbed_by, expanded}`, or `#{class, reason}` for a failure the paste-back does not name. `corrected` is `none` |
| `replaces` | the line drops the declared type: `#{declared, within}`, the first as the author wrote it. `corrected` is the line |

**Two sites.** `bsc --api` prints no corrected signature: it answers what signatures declare and
never checks a body (`bs_api.erl`'s header). So there is no second printer to wire. The two
declaration sites appear where the claim is checked: F25.11 and the gate's probe 7 require the
withheld line to be refused by a compile **and** by `--api`, which reaches the declaration check
through `exports_of/1` and not `check/2`. The paste-back runs `collapse_decl/2`, which is what
both sites run.

### Not built

- **A tagged signature to paste.** The repair is named, not printed. Printing it would mean
  inventing the tag atoms, and pasting it would still leave every clause body returning an
  untagged value. §2 has the compiler synthesise heads and never bodies.
- **A spelling for the last two rows.** The Lst and Pair lines are withheld, where a correct line
  exists: `list<map<string, binary>>` covers a non-empty list, and `(int, map<string, binary>)`
  covers `(2, …)`. Printing them needs the printer to widen a pattern spelling to a type
  spelling, which is a decision about `bs_types:to_string/1`, not this ticket. Filed as
  [ENG-350](https://linear.app/davewil/issue/ENG-350).
- **The rest of the declaration check.** `as_pasted/2` runs the parser, `resolve/2` on the return
  type and `collapse_decl/2`. It does not run `type_env/1`'s refusals, which are about declarations
  other than a signature, or `private_callback/1`, which a pasted line cannot change because it
  keeps the original's visibility.

### Review round — David, 2026-09-10

Six calls this amendment made without asking were put to David after it landed. Answered:
**R1** (list and literal residuals withheld until ENG-350) accepted for now; **R4** (the
`indiscriminable` key on a frozen tag) and **R6** (reading "two sites" as the withheld line refused
at both) were questions about what the frozen set enforces and what R6 gives up, answered in the
conversation. R2, R3 and R5 were put with the output below and the compiler delta each would
need; David answered *"all 3"*, and **all three are built as proposed** (the section's closing
paragraph gives the names the build used). The proposals are kept as they were put.

**R2 — a paste-back that fails for a reason it does not name.** Before R2, `as_pasted/2` answered
`none` for anything but indiscriminability, so the line disappeared with no word. A crash and
silence were both rejected. Proposed: the line is withheld and the diagnostic says why, and an
unexpected failure is named as a compiler defect.

```
error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    [map<string, binary>, ..]
  no signature is offered: this residual has no spelling as a type yet.
```
```
  no signature is offered: checking it failed inside the compiler
  (badmatch in bs_check:as_pasted/2), which is a compiler defect.
```

Compiler delta: `as_pasted/2` answers `{withheld, Why}` with `Why` one of `syntax`, `absorbed`,
`{internal, Class, Reason}`; the term gains `withheld := none | Why`; one `message/1` clause per
`Why`. F25.4's record residual would get the same sentence, since it is withheld silently too.

**R3 — the absorbed declared type.** No line that keeps `map<string, int>` is legal: ticket 68
refuses `map<string, int> | map<string, term>`. So the choice is this line or no line, and what the
line does wrong is replace the declared type without saying so, when the likelier mistake is the
clause. Proposed:

```
  the signature its clauses justify:
    public map<string, term> Pick(int n)
  this replaces `map<string, int>`, which `map<string, term>` contains.
  If `map<string, int>` is what you meant, fix the clause, not the signature.
```

Compiler delta: `signature_line/3` reports whether it dropped the declared half; the term gains
`replaces := none | "map<string, int>"`; one `message/1` clause.

**R5 — the tag advice shows the shape.** Proposed:

```
  widening the signature to cover it would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  tag the members so a clause head can, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag.
```

It is a type, not a signature, and sits under no "paste this" heading: the clauses must change as
well, and §2 has the compiler write heads, never bodies. Compiler delta: the `message/1` clause
only; the term already carries both members.

**As built.** The deltas' names changed once they were written. `bs_check:corrected_signature/4`
answers the line, `{replacing, Line, D, New}`, `{refused, A, B}` or `{withhold, Why}`, and
`bs_diag:correction/1` spreads that across `corrected`, `indiscriminable`, `withheld` and
`replaces` (the table under *The term*). `Why` is `unspellable` (a record, `binary \ string`, or a
line the parser refuses), `declared_form` (an inline map or other unrendered declared form, which
F25 has always withheld and never explained), `{absorbed_member, M, By}`, or
`{crashed, Class, Reason}`. `replaces` carries the type it drops as the author wrote it, so
`type Counts = map<string, int>` reads *"this replaces `Counts`"* (F25.21). The internal tuple tags
are deliberately not the descriptor's key names: a function or tuple tag in `bs_check` that
matches a key `bs_diag` prints can reorder the term channel's output (ENG-349).

**Corrected after review.** The `/code-review` spec axis ran the build against programs the
proposals did not list, and three printed a reason that was false. Each is fixed and has a test:

- `public int Go(term r)` returning `r` said *"which is a compiler defect"*. Its residual prints
  `tuple` and `map`, which have no surface form, so the line resolves to nothing; so does a
  recursive type from another module, printed by a name that does not cross the boundary.
  `unknown_builtin` and `unknown_type` from `resolve/2` are now `unspellable` (F25.22, F25.23).
- `int | :'a b'` declared said the residual had no spelling. `type_source/1` wrote the declared
  atom bare, as `:a b`; it now quotes by the printer's rule (F25.24).
- A record beside `:oops` printed *"this residual has no spelling"* on the `:oops` diagnostic too,
  because the correction is worked out once for the function. The sentence now reads *"what the
  clauses return has no spelling as a type yet."* — a change to the approved wording, made because
  the approved wording was false for that program.

It also found R3 firing on a `none` return, *"this replaces `none`, which `:oops` contains"*, which
is true of every type. R3 now leaves the bottom alone.

**Left for David.** Three differences from what was put, none of them a false sentence:

- The term's shapes. The proposal sketched `replaces := none | "map<string, int>"` and
  `Why` one of `syntax`, `absorbed`, `{internal, …}`; the build carries `replaces := #{declared,
  within}`, because the sentence needs both types, and the `Why` names above.
- Two sentences he has not read: `declared_form`'s and the absorbed member's. The second names the
  member as the algebra resolves it, `map<string, int>`, where the author may have written an alias.
- R5 shows the refused pair only. With `int` declared and both maps in the residual, the shape is
  `(:tag1, map<string, int>) | (:tag2, map<string, binary>)`, and `int` is not in it: the advice
  says to tag the members, not what the whole return type becomes. The pair also prints resolved,
  so aliases the author wrote for the maps do not appear.

### Round 2 — David, 2026-09-11: the same cases in real code

David could not read the rounds above: every example was a minimal repro. The cases are rewritten
as web, session and database code in
[`f25-corrected-signature-in-real-code.md`](../../wayfinder/prototypes/f25-corrected-signature-in-real-code.md),
compiled at `bc4740b`. Writing them found [ENG-351](https://linear.app/davewil/issue/ENG-351), a
compiler crash on any foreign `map<K, V>` return.

They also show something the repros hid: in four of the six, the realistic fix is the **clause**.
For the checkout, the guest's quantities are still text and must become numbers. The refused-union
advice offers only tagging, which is the wrong repair there. **Asked, one question, and the three
items above follow from its answer:** should the refused case lead with R3's sentence? Proposed,
not built:

```
Checkout.bs:12:1: error: CartQuantities returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  If `map<string, int>` is what you meant, fix the clause, not the signature.
  Widening the signature to cover both would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  so if both are meant, tag them, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag.
```

Compiler delta: the refused correction carries the declared return's source text (`{refused, A, B,
RetSrc}`), since the sentence names the type as the author wrote it (`ViewCounts`, not
`map<string, int>`); one `correction_text/1` clause. If the answer is yes, the absorbed-member
case (program 4) takes the same sentence, and the tag shape stops being the only advice, which is
most of what the R5 item above was about. It touches ticket 70's decision (*"the repair is to tag
the two members"*): 70 put the objection in the advice, and this changes what the advice leads
with, not what is refused.

**Answered:** *"Probably, isn't that what B#'s lead feature is, guiding towards having complete
clause coverage?"* The nuance, given in reply: exhaustiveness is about the inputs, and this
diagnostic is about the outputs. What the two share is the stance that the signature states intent
and the compiler holds the clauses to it. F25 inverted that for outputs, and 23 §8 accepted it as
a risk.

### Round 3 — David, 2026-09-11: every return mismatch, or the refused case only

The answer's reason reaches past the refused case, so the gating question is its scope: does
**every** `return_not_declared` lead with the clause, with the widened line kept as the
alternative? A case where widening is the right fix, so the line must survive:

```csharp
module Payments

record Charge { OrderId: int, AmountCents: int }

// Take payment for an order. The author declared the happy path only, then
// wrote the clause for a declined card and forgot to widen the signature.
public atom TakePayment(Charge c, bool card_ok)

TakePayment(c, true)  -> :paid
TakePayment(c, false) -> (:declined, c.OrderId)
```

Today, at `bc4740b`:

```
Payments.bs:10:1: error: TakePayment returns a value its signature does not declare
  not covered by the declared return type:
    (:declined, int)
  the signature its clauses justify:
    public atom | (:declined, int) TakePayment(Charge c, bool card_ok)
```

Proposed, not built:

```
Payments.bs:10:1: error: TakePayment returns a value its signature does not declare
  not covered by the declared return type:
    (:declined, int)
  If `atom` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public atom | (:declined, int) TakePayment(Charge c, bool card_ok)
```

Compiler delta: every correction carries the declared return's source text, and the sentence
leads each `correction_text/1` clause. The heading keeps its words, so the term and the gates'
markers do not move. `TOUR.md`'s quoted `Unwrap` output gains the line. The refused case reads as
Round 2 proposed, and R3's replacing case already ends with the same sentence, so it moves up.

**Answered: *"all"*. Built as proposed.** Every `return_not_declared` opens with *"If `D` is what
you meant, fix the clause, not the signature."*, where `D` is the declared return as the author
wrote it: `ViewCounts`, `Counts`, `map<string, int> | :none`. The widened line follows as
*"Otherwise, the signature its clauses justify:"*; the refused case reads as Round 2 proposed; a
withheld line keeps its reason after the lead; R3's sentence moved to the top. An inline map,
the one declared form `type_source/1` will not write for a pasteable line, is written back for the
lead with its fields in the author's order: `{ Id: int, Email: binary }`, also nested, in a union
and as a generic argument. The algebra's printer would sort the fields, which is a type the author
did not write. A form nothing can write back is named as the printer spells it; no signature
reaches that today (F25.27).

**Two differences from what was put, from the review of the build.** The term gains `declared`,
always present, where Round 3 said the term would not move: the prose is a function of the term
(F16), so the lead's text had to be in it. `corrected` and the heading's words did not move. And
the refused case says *"Widening the signature to cover what the clauses return would be
refused:"* where Round 2 said *"to cover both"*: with `int` declared and two maps returned, "both"
named the maps, not what the lead had just named. `raise_tests`' alias case now reads the CLI
instead of the internal tuple, whose shape changed. The realistic programs in
`f25-corrected-signature-in-real-code.md` print this form now; two of them are pinned whole as
F25.25 and F25.26.

### Round 4 — David, 2026-09-11: the prior art, and a named type for the tag advice

David asked for the open items above to be resolved from prior art where possible. The survey is
[`f25-types-in-suggestions-prior-art.md`](../../wayfinder/research/f25-types-in-suggestions-prior-art.md):
rustc, TypeScript and Gleam were run, and Elm and GHC were read from source and docs.

**What the prior art settles.** *Whole type or fragment:* none of the four compilers prints part
of a type where the whole type would go. The pair-only shape (program 2) has no counterpart in
them. *Alias or expansion:* when the reason is structural, TypeScript and GHC keep the author's
name where the declared type is quoted and give the structure separately. Elm prints the name with
no reason, and Gleam and rustc print only the expansion. B# decided this for itself in ticket 09
§1: *"The compiler still knows the alias even though the algebra does not, so diagnostics print
the name."* So program 4's reason should name `ViewCounts` and add its expansion, which it does
not today. The same fault is in the declaration check's own absorbed-member diagnostic, measured
this round: a declared `(atom, term) | Name` is reported as `(:tag1, map<string, int>) | (:tag2,
map<string, binary>)` is absorbed by `(atom, term)`, never as `Name`.

**Where the survey's answer was wrong for B#.** The first reading of "print the whole type" was
the widened return with the pair tagged inline. David, on seeing that shape in a probe: *"This is
far from what I think looks like good language design - `public (atom, term) | (:tag1, map<string,
int>) | (:tag2, map<string, binary>) Receive(atom kind, map<string, int> counts, map<string,
binary> form)`"*. The survey answered how to print a type, not what a good repair looks like.
Where rustc and Gleam suggest wrapping, they name a variant of a *declared, named* type (``try
wrapping the expression in `CartResult::Text` ``). B#'s own idiom is the same: ticket 09 §2 gives
the language no union syntax, only `type` naming one (`type Distance = (:meters, float) | (:feet,
float)`). Ticket 70 decided that tagging is the repair; this round is about how the advice spells
it.

**Asked, one question: should the tag advice propose a named type?** Program 2, as an author
would finish it after following the advice (compiles clean at `ed0f246`):

```csharp
module CheckoutNamed

// The cart the checkout page can hold: a signed-in shopper's cart from the
// session, already numeric, or a guest's cart from the posted form, still text.
type Cart = (:priced, map<string, int>) | (:posted, map<string, binary>)

// Reading the session can fail: it may have expired.
public result<Cart, atom> CartQuantities(bool signed_in,
                                         result<map<string, int>, atom> session_cart,
                                         map<string, binary> form_fields)

CartQuantities(true, (:error, why), form_fields)  -> (:error, why)
CartQuantities(true, counts, form_fields)         -> (:priced, counts)
CartQuantities(false, session_cart, form_fields)  -> (:posted, form_fields)
```

Today, for the unfinished program 2:

```
CheckoutResult.bs:9:1: error: CartQuantities returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  If `result<map<string, int>, atom>` is what you meant, fix the clause, not the signature.
  Widening the signature to cover what the clauses return would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  so if both are meant, tag them, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag.
```

Proposed, not built:

```
CheckoutResult.bs:9:1: error: CartQuantities returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  If `result<map<string, int>, atom>` is what you meant, fix the clause, not the signature.
  Widening the signature to cover what the clauses return would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  so if both are meant, give them one type, each member tagged:
    type Name = (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  declare the return as `result<Name, atom>`, return each value inside its tag,
  and choose the name and the atoms.
```

`result<Name, atom>` is the whole return type, as the prior art requires, and it keeps the
author's `result`. Pasted as printed, with the placeholders left in, it compiles clean
(`CheckoutPlaceholder`, measured). Where no named type can help, it says so. In the webhook
receiver below, `(atom, term)` absorbs any tagged pair, whatever it is called:

```csharp
public (atom, term) | map<string, int> Receive(atom kind, map<string, int> counts, map<string, binary> form)

Receive(:ping, counts, form) -> counts
Receive(:form, counts, form) -> form
Receive(kind, counts, form)  -> (kind, counts)
```

Today it tells the author to tag the maps, which leads to a declaration the compiler refuses
(measured). Proposed: *"A named type would be refused too: `(atom, term)` absorbs `Name`."* and
no type is shown.

Compiler delta:

1. `bs_check:correction_of/4`, on `{refused, A, B}`: in the written return type from the pasted
   line, the node that resolves to `A`, whether a union member or a generic's argument, becomes
   `Name`, and the node that resolves to `B` is dropped. `type Name = …` and the rewritten
   signature are pasted back together through `collapse_decl/2`, with `Name` in `Env`. If that is
   refused, no type is shown and the refusal's reason is kept.
2. `bs_diag`: `indiscriminable` gains `declaration` (`"type Name = …"`) and `returns`
   (`"result<Name, atom>"`), or `none` and the reason. One `correction_text/1` clause changes, and
   one is added for the reason.
3. F25.26 and a new whole-message test for program 2. A gate probe, with an `inline` stub that
   prints the tagged union inline.

The alias question does not depend on this answer and is built either way: the absorbed-member
reason and the refused pair name `ViewCounts` as written, and add `` `ViewCounts` is `map<string,
int>` `` as a line after the reason. `A` and `B` are normalised constituents (ticket 09 §4), so a
pair member no written member resolves to keeps the printer's spelling.

**Accepted as built, on the repo's own ground rather than on prior art.** Ticket 23 §4 makes the
payload a map, so it grows by adding keys: `declared`, `replaces := #{declared, within}` and the
`withheld` names stand. *"Cover what the clauses return"* fixed a sentence that was false when the
declared type was not half of the refused pair. The `declared_form` sentence stands until a
program shows it misleading. **Left for David:** `LANGUAGE.md` §5 (lines 821-823) still says the
message offers the wider signature *"so the fix can be to the declaration rather than to the
body"*, which Round 3 reversed. `PACKET.md` is cut from that text, so the edit waits for him.

**Answered:** *"The readability should be a named type, the lexer, complier etc, should handle the
hidden tag if required."* So the placeholder atoms in the proposal above are out: the author
should not write `(:tag1, …)`. The answer can be read two ways, and each is a program below.

### Round 5 — David, 2026-09-11: records, or a tag the compiler inserts

**Reading 1: records, which the language accepts today.** Ticket 26 made `record` sugar for a
minted tag, on David's DDD argument: the name enters the term as data, and it is never written.
Program 2, finished that way, compiles clean at `ed0f246`, and the consumer dispatches on the
members by name:

```csharp
module CheckoutRecords

// A signed-in shopper's cart, from the session: already numeric.
record SessionCart { Items: map<string, int> }
// A guest's cart, from the posted form: every value still text.
record GuestCart { Fields: map<string, binary> }

type Cart = SessionCart | GuestCart

// Reading the session can fail: it may have expired.
public result<Cart, atom> CartQuantities(bool signed_in,
                                         result<map<string, int>, atom> session_cart,
                                         map<string, binary> form_fields)

CartQuantities(true, (:error, why), form_fields)  -> (:error, why)
CartQuantities(true, counts, form_fields)         -> SessionCart{ Items = counts }
CartQuantities(false, session_cart, form_fields)  -> GuestCart{ Fields = form_fields }

// A consumer dispatches on the named members; no tag is written anywhere.
public atom Source(Cart c)

Source(SessionCart s) -> :session
Source(GuestCart g)   -> :form
```

A record is a map, not a tuple, so the webhook receiver that Round 4 could not help compiles
this way too (`WebhooksRecords`, measured: `(atom, term) | Payload` with two records). The cost
is two declarations, a field name each, and `SessionCart{ Items = counts }` where the author had
`counts`.

Compiler delta under reading 1: F25's refused case prints the declarations with placeholder
names, `record Name1 { Value: map<string, int> }`, `record Name2 { Value: map<string, binary> }`,
`type Name = Name1 | Name2`, and the rewritten return, `result<Name, atom>`. They are pasted back
through a `type_env/1` built over the generated declarations and a module head, merged with the
author's, so a placeholder that collides with a name in the author's module is caught before it
prints. This departs from the survey: rustc and Gleam name a constructor of a type that already
exists, and none of them writes a declaration for the author.

**Reading 2: the compiler inserts the tag when the members need one.** The author writes the
plain named union and returns the values bare:

```csharp
module CheckoutAutoTag

type Cart = map<string, int> | map<string, binary>

public result<Cart, atom> CartQuantities(bool signed_in,
                                         result<map<string, int>, atom> session_cart,
                                         map<string, binary> form_fields)

CartQuantities(true, (:error, why), form_fields)  -> (:error, why)
CartQuantities(true, counts, form_fields)         -> counts
CartQuantities(false, session_cart, form_fields)  -> form_fields
```

Refused today, at the `type` line:

```
CheckoutAutoTag.bs:5:1: error: no clause head can tell `map<string, int>` from `map<string, binary>`
  in Cart
  both members survive normalisation, so neither is absorbed - but
  no pattern reaches either one and no guard separates them, so a
  value of this type can be passed and returned and never matched.
  This is a limit of the pattern grammar, not of the types: it
  lifts when a pattern form for these members ships.
```

Compiler delta under reading 2, which is a language change and so a ticket, not an F25 build:

- A named union's members gain a runtime tag the author never writes.
- The tag is chosen at each return site from the static type of the returned expression. For
  example, `counts` is `map<string, int>`, so it gets the first member's tag.
- A match on `Cart` dispatches on that tag.

It reopens three decisions:

- Ticket 09 §5 refused nominal unions because a raw Erlang caller can hand over an untagged map.
- Ticket 26 put the name in the term only where the author asks for a record.
- Ticket 70 decided that the author does the tagging.

**Asked, one question: is the advice reading 1 or reading 2?** If 2, the ticket is raised and
claimed, and F25's refused case keeps today's advice until it is decided. If there is no answer,
reading 1 is the default, because it is the one the language accepts. The alias item (program 4
names `ViewCounts`) is built after this answer, since the refused layout it sits in depends on it.

Measured, not explained: a declared `map<atom, term> | Payload` over the two records compiles
clean (`ParamsRecords`). A record is a map with atom keys, so the absorption check was expected to
refuse it. Noted for whoever next reads the map algebra.

**Answered: *"1, records"*. Built.** Program 2 now reads:

```
CheckoutResult.bs:9:1: error: CartQuantities returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  If `result<map<string, int>, atom>` is what you meant, fix the clause, not the signature.
  Widening the signature to cover what the clauses return would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  so if both are meant, give each a record of its own and name the pair:
    record Name1 { Value: map<string, int> }
    record Name2 { Value: map<string, binary> }
    type Name = Name1 | Name2
  declare the return as `result<Name, atom>`,
  build each value as its record, and choose the names.
```

The alias item was built with it. Program 4's reason names `ViewCounts` and then prints
`` (`ViewCounts` is `map<string, int>`) ``. A refused pair with an alias does the same, and the
record's field is typed `ViewCounts` (F25.29). What the build found beyond the proposal:

- **The webhook receiver is helped now.** Records are maps, so `(atom, term)` does not absorb them.
  The advice declares `(atom, term) | Name`, and the paste-back accepts it.
- **A pair member inside a non-generic named type has no written place.** For example,
  `type Stock = map<string, int> | :not_found` declared, with a CSV row returned. This pass sees
  `Stock` only resolved, so a rewrite would be a type nobody wrote or checked. The advice says to
  use records, names the holder, and shows no declaration (F25.31).
- **The placeholders move aside when the module already uses one**, as `NewName`, `NewName1` and
  `NewName2` (F25.32). A person's `record Name` is ordinary in an accounts module.
- **The term's keys differ from Round 4's sketch.** `declarations` is a list of three lines, and
  the expansion is `#{name, is}`, not `#{written, is}`: `bs_check` has a function `written/1`, and
  an atom shared with a `bs_diag` key reorders `--batch` output (ENG-349).
- **The pasted declarations are checked**, as the line is. They are parsed, entered into the
  author's environment beside the signature that uses them, and handed to `collapse_decl/2`. No
  program is known to make that refuse, so a refusal is reported as a compiler defect (F25.33).

## The scenarios

`corrected_signature_tests.erl` opens its sections with these identifiers, and this is what each
one establishes. The first six go through the `bsc` CLI; the last three read the diagnostic term
directly, because that is where the claim lives.

| | | |
|---|---|---|
| F25.1 | `Answer(n) -> :oops` under `public int Answer(int n)` | the output carries `public int \| :oops Answer(int n)` — a **whole signature**, not a type fragment |
| F25.2 | the same program, looking for the older message | `not covered by the declared return type:` still stands beside it |
| F25.3 | two offending clauses, `:zero` and `(:error, string)` | **two** diagnostics, and the **same** line on both: `public int \| :zero \| (:error, string) Go(int n)` |
| F25.4 | a record in the **residual** — `Make` declared `Order`, returning `Invoice` | no signature line at all; the ordinary message and the residual's `Kind: :'M4.Invoice'` both survive, and since ENG-346's R2 the diagnostic says why no line is offered |
| F25.5 | the mirror — a record as the **declared** type, returning `:oops` | `public Order \| :oops Make(int n)`, and no `Kind:` anywhere |
| F25.6 | a private `Helper` beside a public `Entry` | `int \| :oops Helper(int n)` — and **not** `public …` |
| F25.7 | `bs_diag:contractual()` | `return_not_declared` is a member |
| F25.8 | the descriptor for a mismatch | the term carries `corrected := "public int \| :oops Answer(int n)"` under its own key |
| F25.9 | the descriptor when no signature can be written | `corrected := none` — the key is present and says nothing, rather than being absent |
| F25.10 | ENG-346's program: `Pick` declared `map<string, int>`, returning a `map<string, binary>` | no signature line; the lead, *"Widening the signature to cover what the clauses return would be refused:"*, the pair, and since Round 5 two records and `type Name = Name1 \| Name2` with the return `Name`, all printed beside the residual, and no `(:tag1` |
| F25.11 | the line F25.10 withholds, pasted | refused with `no clause head can tell …` by a compile **and** by `--api` |
| F25.12 | `map<string, int>` declared, returning `:oops` | `public map<string, int> \| :oops Pick(int n)` still printed — `is_map` splits the two — and pasting it compiles clean |
| F25.13 | both maps in the **residual**, under a declared `int` | two diagnostics, both withheld with the pair named: pairing residual members only against the declared type would miss it. Since Round 4, both declare the whole return, `int \| Name`: the one program where it differs from the pair |
| F25.14 | the term, read off the CLI's term channel | `corrected := none` and `indiscriminable := #{member, beside, expanded, declarations, returns, no_declarations}`; an ordinary mismatch carries `indiscriminable := none` |
| F25.15 | `map<string, int>` declared, returning a `map<string, term>` | `public map<string, term> Pick(int n)` — the absorbed declared half is dropped — and pasting it compiles clean |
| F25.16 | `list<map<string, int>>` declared, returning a `list<map<string, binary>>` | no signature line and no refusal: the line would be a syntax error, and the union is legal; the residual `[map<string, binary>, ..]` still prints, and since R2 so does *"no signature is offered: what the clauses return has no spelling as a type yet."* |
| F25.17 | the Round 5 declarations as printed, placeholders and all, each clause building its record | compiles clean: the advice is right only if following it compiles (it held R5's tuple shape until Round 5) |
| F25.18 | `map<string, int> \| :none` declared, returning a `map<string, term>` | R2: withheld, naming `map<string, int>` and what absorbs it; the term carries `withheld := #{member, absorbed_by}` |
| F25.19 | an inline map `{ Id: int }` as the declared return | R2: *"the declared signature is written in a form this line does not reproduce"* |
| F25.20 | a failure the paste-back does not name | R2: `as_pasted/2` answers `{withhold, {crashed, Class, Reason}}`, and the prose says *"(badmatch in bs_check:as_pasted/2), which is a compiler defect"*. No program is known to reach it, so the producer half is fault injection (environments `type_env/1` never builds, through a test-only export) and the consumer half is the descriptor |
| F25.21 | `type Counts = map<string, int>` declared, returning a `map<string, term>` | R3: *"this replaces `Counts`"* — named as the author wrote it |
| F25.22 | `public int Go(term r)` returning `r` | the residual prints `tuple` and `map`, which have no surface form: unspellable, **not** a compiler defect |
| F25.23 | a residual that is another module's recursive `Tree` | printed by the name its author gave it, which does not cross a module boundary: unspellable, not a defect; declared in the module itself, the line prints |
| F25.24 | `int \| :'a b'` declared, returning `:oops` | `public int \| :'a b' \| :oops Go(int n)` — the declared atom quoted — and it compiles pasted |
| F25.25 | a payment handler declaring `atom`, whose decline clause returns `(:declined, int)` | Round 3, the whole message: the lead, then *"Otherwise, the signature its clauses justify:"* and the widened line. Widening is the right fix here, so the line must survive the lead |
| F25.26 | the checkout page, where a guest's quantities are still text | Round 3, the whole message: the lead, then the refused widening and, since Round 5, the records under a name as the case for both being meant |
| F25.27 | `declared_text/2` handed a form the grammar does not have | named as the algebra prints it, whole. Fault injection through the test-only export: no signature reaches it |
| F25.28 | the checkout whose session can expire, declared `result<map<string, int>, atom>` | Round 4 and 5, the whole message: the named type takes the pair's place inside the author's `result`, so the return is `result<Name, atom>` |
| F25.29 | the dashboard, declared `ViewCounts`, a `map<string, int>` alias | Round 4: *"no clause head can tell `ViewCounts` from …"*, then `` (`ViewCounts` is `map<string, int>`) ``, and `record Name1 { Value: ViewCounts }`; the term carries `expanded := [#{name, is}]` |
| F25.30 | the dashboard whose site may be unknown, `ViewCounts \| :not_found` | Round 4, the whole message: the absorbed member named `ViewCounts`, its structure beside it |
| F25.31 | `type Stock = map<string, int> \| :not_found` declared, a CSV row returned | Round 5: the pair sits inside a named type this pass sees resolved; the advice names the holder and shows no declaration, rather than a rewrite nobody checked |
| F25.32 | a module with its own `record Name` | the placeholders move aside to `NewName`, `NewName1`, `NewName2` |
| F25.33 | a declaration the paste-back refuses | reported as a compiler defect: *"refused (absorbed_member), which is a compiler defect."* No program is known to reach it; fault injection at the descriptor |

**F25.3 was measured before it was designed.** Two offending clauses produce two diagnostics; if
each carried its own correction the compiler would print two contradictory pasteable lines, and
pasting either would leave the other clause wrong. One line, from the union of every residual,
attached to both.

**F25.4 and F25.5 are one decision seen from both sides, and F25.4 is the half a gate written
after the code would miss.** A record in the residual has no writable spelling: `bs_types` renders
it as `{ Kind: :'M4.Invoice', Id: int, Total: int }`, which describes the set correctly and is a
bad thing to paste, because ticket 26 §1 mints that tag from the qualified module path — pasting
it hard-codes a mint instead of naming `Invoice`. So the **tag is expected in the output and
forbidden in the signature**, and the first draft of F25.4 asserted it was absent altogether,
which forbids the correct behaviour. The residual is asserted **present** so that a refusal is
known to have dropped one line rather than the whole diagnostic. F25.5 is why the declared half is
read from the source AST rather than from the algebra: through the algebra a declared record would
render as its mint tag and be refused too — a refusal with no cause.

**F25.9 exists so a consumer never has to tell "absent" from "refused".** F16 makes the term
canonical and the prose a pure function of it, so a key that vanishes when there is nothing to say
would push that distinction onto every reader of the term.

## The gate

`compiler/bin/check-corrected-signature.sh`, with `--self-test`. The self-test builds four stubs
and requires the gate to go red on three of them and green on the correct form:

- **silent** — the line is never printed. The defect this feature fixes.
- **per-clause** — each clause gets its own corrected signature. Green under a gate that only
  checks the line is present, red under this one, because two clauses must yield one line.
- **overreach** — a corrected signature printed for a record residual, carrying the mint tag. The
  plausible-but-wrong fix, and the one a gate written after the code would have blessed.
- **broken** — nothing compiled. Every probe asserting an absence must fire, or the gate is
  measuring a run that never happened.

ENG-346 added probes 6 to 9 and six stubs, each of which must fire its own probe and no other:

- **refused-anyway** — the compiler at `5a40668`, printing the line the declaration check
  refuses. Probe 6.
- **withheld** — the line dropped as F25.4 drops an unwritable one, with no reason and no repair.
  Probe 6: an author told nothing assumes an unwritable residual and pastes the union by hand.
- **one-site** — a compile refuses the withheld line and `--api` answers it. Probe 7.
- **compile-accepts** — the mirror: `--api` refuses and a compile accepts. Probe 7 reads the two
  sites in two branches, and without this stub the compile branch is never seen to fire alone.
- **over-refusal** — every correction with a map in it withheld. Probe 8, the control, is the
  only probe that catches it.
- **absorbed-map** — the compiler at `f3e1eee`, printing `map<string, int> | map<string, term>`.
  Probe 9.

The review round added probe 10 and two stubs, and changed probe 6's and probe 9's markers:

- **absorbed-silent** — the compiler at `a25d048`: the right line, with `map<string, int>` dropped
  without a word. Probe 9 (R3).
- **record-silent** — the record residual withheld with no reason. Probe 10's second branch;
  added when the `/code-review` standards axis showed that branch had never been seen to fire.
- **no-lead** — the compiler at `bc4740b`: the widened line as the headline, with no word that the
  clause may be what is wrong. Probe 1 (Round 3).
- **lead-last** — the lead present but after the line, R3's order at `bc4740b`. Probe 1 checks
  where the lead is, not only that it is there.
- **withheld-lead-last** — a withheld line whose lead follows its reason. Probe 10: probe 1 reads
  only the plain case, and a withheld message has no heading to order against.
- **silent-withhold** — also `a25d048`: the list residual withheld with no reason. Probe 10 (R2),
  which also requires the record case to say why wherever probe 3 finds its line withheld.

Rounds 4 and 5 added probes 11 and 12 and six stubs, and changed probe 6's markers to the records:

- **tag-shape** — the compiler at `1144ca9`: the refused widening explained, and the repair a tuple
  shape whose tags the author writes. Probe 6.
- **pair-only** — also `1144ca9`, on the checkout with a `result` return: the pair shown alone,
  `(:error, atom)` missing. Probe 11.
- **result-lost** — records under a name and a whole return, with `result` expanded into
  `Name | (:error, atom)`. Probe 11.
- **resolved-name** — `1144ca9` on the dashboard: `map<string, int>` in the reason where the lead
  says `ViewCounts`. Probe 12.
- **no-expansion** — the name kept and its structure dropped, which is Elm's choice. Probe 12.
- **resolved-absorbed** — `1144ca9` on the dashboard whose site may be unknown. Probe 12's
  second branch.
