# F25 — The return-mismatch diagnostic carries the signature to paste

**Status**      **done 2026-08-23** — 501 tests, twenty gate scripts. `return_not_declared` joins
                `contractual/0`, which is the first time the frozen subset has grown since F16
                defined it
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

## The scenarios

`corrected_signature_tests.erl` opens its sections with these identifiers, and this is what each
one establishes. The first six go through the `bsc` CLI; the last three read the diagnostic term
directly, because that is where the claim lives.

| | | |
|---|---|---|
| F25.1 | `Answer(n) -> :oops` under `public int Answer(int n)` | the output carries `public int \| :oops Answer(int n)` — a **whole signature**, not a type fragment |
| F25.2 | the same program, looking for the older message | `not covered by the declared return type:` still stands beside it |
| F25.3 | two offending clauses, `:zero` and `(:error, string)` | **two** diagnostics, and the **same** line on both: `public int \| :zero \| (:error, string) Go(int n)` |
| F25.4 | a record in the **residual** — `Make` declared `Order`, returning `Invoice` | no signature line at all; the ordinary message and the residual's `Kind: :'M4.Invoice'` both survive |
| F25.5 | the mirror — a record as the **declared** type, returning `:oops` | `public Order \| :oops Make(int n)`, and no `Kind:` anywhere |
| F25.6 | a private `Helper` beside a public `Entry` | `int \| :oops Helper(int n)` — and **not** `public …` |
| F25.7 | `bs_diag:contractual()` | `return_not_declared` is a member |
| F25.8 | the descriptor for a mismatch | the term carries `corrected := "public int \| :oops Answer(int n)"` under its own key |
| F25.9 | the descriptor when no signature can be written | `corrected := none` — the key is present and says nothing, rather than being absent |

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
