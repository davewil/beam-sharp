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

**The term.** The descriptor gains three keys, each present on every `return_not_declared` and
`none` when it has nothing to say, for F25.9's reason: a consumer never tells "absent" from
"refused". Adding keys is the additive-only change ticket 23 §4 chose maps for.

| key | when it is not `none` |
|---|---|
| `indiscriminable` | the widened line is refused: `#{member, beside}`, named as `indiscriminable_union`'s fields are. `corrected` is `none` |
| `withheld` | no line is offered: `unspellable`, `declared_form`, `#{member, absorbed_by}`, or `#{class, reason}` for a failure the paste-back does not name. `corrected` is `none` |
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
| F25.10 | ENG-346's program: `Pick` declared `map<string, int>`, returning a `map<string, binary>` | no signature line; `widening the signature to cover it would be refused:`, the pair, and `tag the members instead` all printed, beside the residual |
| F25.11 | the line F25.10 withholds, pasted | refused with `no clause head can tell …` by a compile **and** by `--api` |
| F25.12 | `map<string, int>` declared, returning `:oops` | `public map<string, int> \| :oops Pick(int n)` still printed — `is_map` splits the two — and pasting it compiles clean |
| F25.13 | both maps in the **residual**, under a declared `int` | two diagnostics, both withheld with the pair named: pairing residual members only against the declared type would miss it |
| F25.14 | the term, read off the CLI's term channel | `corrected := none` and `indiscriminable := #{member, beside}`; an ordinary mismatch carries `indiscriminable := none` |
| F25.15 | `map<string, int>` declared, returning a `map<string, term>` | `public map<string, term> Pick(int n)` — the absorbed declared half is dropped — and pasting it compiles clean |
| F25.16 | `list<map<string, int>>` declared, returning a `list<map<string, binary>>` | no signature line and no refusal: the line would be a syntax error, and the union is legal; the residual `[map<string, binary>, ..]` still prints, and since R2 so does *"no signature is offered: what the clauses return has no spelling as a type yet."* |
| F25.17 | the R5 shape as a declaration, each clause returning inside its tag | compiles clean: the advice is right only if following it compiles |
| F25.18 | `map<string, int> \| :none` declared, returning a `map<string, term>` | R2: withheld, naming `map<string, int>` and what absorbs it; the term carries `withheld := #{member, absorbed_by}` |
| F25.19 | an inline map `{ Id: int }` as the declared return | R2: *"the declared signature is written in a form this line does not reproduce"* |
| F25.20 | a failure the paste-back does not name | R2: `as_pasted/2` answers `{withhold, {crashed, Class, Reason}}`, and the prose says *"(badmatch in bs_check:as_pasted/2), which is a compiler defect"*. No program is known to reach it, so the producer half is fault injection (environments `type_env/1` never builds, through a test-only export) and the consumer half is the descriptor |
| F25.21 | `type Counts = map<string, int>` declared, returning a `map<string, term>` | R3: *"this replaces `Counts`"* — named as the author wrote it |
| F25.22 | `public int Go(term r)` returning `r` | the residual prints `tuple` and `map`, which have no surface form: unspellable, **not** a compiler defect |
| F25.23 | a residual that is another module's recursive `Tree` | printed by the name its author gave it, which does not cross a module boundary: unspellable, not a defect; declared in the module itself, the line prints |
| F25.24 | `int \| :'a b'` declared, returning `:oops` | `public int \| :'a b' \| :oops Go(int n)` — the declared atom quoted — and it compiles pasted |

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
- **silent-withhold** — also `a25d048`: the list residual withheld with no reason. Probe 10 (R2),
  which also requires the record case to say why wherever probe 3 finds its line withheld.
