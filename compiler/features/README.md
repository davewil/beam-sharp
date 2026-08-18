# Features — how `bsc` gets built out

A **feature-driven** working style, influenced by
[magic-lisp](https://github.com/andrealaforgia/magic-lisp/tree/main/features): numbered capability
files, the walking skeleton as F1, concrete scenarios that assert on **exact output and exit
codes**, and a traceability id per scenario.

**Not Gherkin.** No `Given`/`When`/`Then`, no step definitions, no runner to install. The value
being borrowed is the *shape* — one file per capability, ordered, each naming what "done" means
before the work starts — not the syntax. A scenario here is a command, an input and an expected
result, in a table an agent can read and a human can check.

## Why this rather than a ticket

The wayfinder map produces **decisions**; it is explicitly plan-only except for the walking
skeleton. Features are the other half: they say *what the compiler does next*, in terms of
observable behaviour, against decisions the map has already closed. A feature file cites the
tickets it implements and never re-opens them — if a feature needs a decision, that is a ticket,
not a feature.

## The ordering rule

**Build what unblocks the most exemplars first.** `examples/exemplars/` holds ticket 25's three
exemplars, none of which parse today, and its README carries the table of what each is waiting for.
That table is the backlog; these files are its front end.

One rule learned the hard way and recorded in 25c: **interval patterns and interval refinements
must land in the same feature.** A capability that closes a residual without supplying a way to
name the cases makes previously-valid programs invalid.

## The harness the features are driven through

**Not a numbered feature** — it decides nothing and implements no ticket — but every feature below
is verified through it: `bsc FILE.bs [FUNCTION] [ARG...]` compiles and runs a program, and
`ibs -S FILE.bs` opens a REPL over it with `:reload`. Added 2026-08-14 on David's *"I want to drive
this compiler development by actually runnable code."* See the compiler README. A feature is done
when you can see it run, not only when its scenarios pass.

**And that is now enforced rather than intended.** `examples/` is the *must run* surface, and
`every_shipped_surface_form_has_an_example_test` fails by **name** when a shipped surface form has
nothing to look at. Added 2026-08-14 after David asked whether the examples showed every capability
as it was built: they did not, and four forms had shipped with tests and no example — record
**construction** sharpest among them, since `shop.bs` demonstrated every record operation except
building one. The list of forms is hand-maintained on purpose; a capability is a sentence and a probe
is a token, and only a person can say which token demonstrates which sentence. One row per feature is
the price of a capability never shipping invisible.

**It cannot cover everything, and the boundary is worth knowing.** Every example must compile, so no
capability whose whole behaviour is a *rejection* can be demonstrated there — the call-site check,
the projection error, exact field sets. Those live in the suite. Three surfaces, gated separately:
`examples/` must run, `LANGUAGE.md`'s blocks must compile or must not, and the tests carry what only
a rejection can show.

**A fourth surface was added 2026-08-15, and it is the one the clean-room handoff runs on.** The
three above all gate against the **compiler**, and there is a class of defect none of them can see:
unbuilt syntax does not compile, so a `not-yet` block in `LANGUAGE.md` holding the **decided** form
and one holding a **superseded** form fail identically. Ticket 44 changed the conjunction and left a
stale block with every gate green; ticket 42 added relational patterns the doc never mentioned.
[`bin/check-surface.sh`](../../bin/check-surface.sh) closes it by requiring every decision the map
tags `syntax` or `patterns` to cite its ticket in `LANGUAGE.md` — mechanical, and it puts whoever
lands a decision at the paragraph that needs changing. **This matters more than it looks**: a
`not-yet` block *is* the handoff's spec, so the one place the compiler-facing gates cannot reach is
the place a clean-room implementer depends on most.

**And `bin/check-map.sh` was never wired into CI** until the same day, having existed since the map
was split — it ran only when somebody remembered, and was catching two real defects per run on the
day it was finally added. Both now run **first** in the workflow, since neither needs a compiler.

## Anatomy of a feature file

```
# F<n> — <capability>

**Status**        not started | in progress | done
**Implements**    tickets it draws on — never decides
**Unblocks**      which exemplars/files stop failing
**Depends on**    other features

## Why this one now
## Scenarios          — F<n>.<m>, each with input, command, expected output, exit code
## Out of scope       — what this feature deliberately does not do
## Done when          — the observable condition
```

Scenario ids are stable and are what a commit message cites (`F2.3`), so the trail from a line of
Erlang back to the decision that required it is one grep.

## The files

| Feature | Status | Unblocks |
|---|---|---|
| [F1 — walking skeleton](F1-walking-skeleton.md) | **done** | the baseline; `examples/*.bs` |
| [F2 — interval refinements and interval patterns](F2-interval-refinements.md) | **done 2026-08-16** | 25b, 25c wire dispatch; it also ran 44's migration and repaired `25c_residual_probe.sh` |
| [F3 — records](F3-records.md) | **done 2026-08-14** | the record half of all three; `examples/Shop/shop.bs` |
| [F4 — local bindings](F4-local-bindings.md) | **done 2026-08-14** | nothing — it removes a papercut |
| [F5 — the body check site](F5-body-check-site.md) | **done 2026-08-14** | F3.3, F3.8, F3.10; 34's destructuring binds |
| [F6 — angle brackets and parametric types](F6-angle-brackets.md) | **done 2026-08-14** | the *bracket* in all three; `examples/Parcel/parcel.bs` |
| [F7 — `switch`](F7-switch.md) | **done 2026-08-15** | the *branching* in all three; `examples/Queue/queue.bs` |
| [F8 — `var` binds, `=` matches](F8-bind-and-match.md) | **done 2026-08-16** | nothing; it went first to avoid rewriting later features' files — and closed a soundness hole nobody knew was there |
| [F9 — `string` and `binary` as values](F9-strings-and-binaries.md) | **done 2026-08-15** | the `string` **fields** in all three, `list<string>`; **not** I/O |
| [F10 — OTP callbacks](F10-otp-callbacks.md) | **done 2026-08-15** | **`bin/spec-check.sh`**; the `behaviour` half of 25b, 25c |
| [F11 — the module system](F11-module-system.md) | **done 2026-08-17** | the collection library; the **imports** row that blocks all three exemplars. It also turned `check-corpus.sh` green for the first time since F9 |
| [F12 — `public` / `private`](F12-public-and-private.md) | **done 2026-08-17** · [ENG-222](https://linear.app/davewil/issue/ENG-222) | nothing — it closed 40 §3, and it was the last whole-corpus rewrite the language had queued |
| F13 — binary patterns | not started, **blocked** — ticket 30 is open | 25b, 25c |
| [F16 — the diagnostic is a term](F16-diagnostic-as-a-term.md) | **done 2026-08-18** · [ENG-224](https://linear.app/davewil/issue/ENG-224) | 23 §10 (`bsc --api`), which is specified *on this channel* and had no output shape until it existed |
| [F14 — the pipe and the valve](F14-pipe-and-valve.md) | **done 2026-08-18** · [ENG-223](https://linear.app/davewil/issue/ENG-223) | 25a's admission chain and the decode pipelines in 25b and 25c — and **ticket 31** now has a running operator to measure rather than argue about |
| [F15 — a module is a directory](F15-module-is-a-directory.md) | **done 2026-08-17** | the *other* half of the module system; `index.bs`, and 41 §4/§5's two checks — both now built |

**F16 IS BUILT, AND WHAT IT REVEALED IS THAT A REQUIREMENT CAN BE WRITTEN WHERE NOBODY WILL BUILD
IT — 2026-08-18.** The diagnostic is a term: `bsc --diagnostics term` publishes a descriptor for
every message the compiler can produce, returned and raised, and the prose is a pure function of it
at all 56 sites. 332 tests, nine gates, and `bsc.erl` down from 1,406 lines to 788.

**The constraint that decided the whole design was already specified — in a comment, on the function
it constrains, with nothing pointing at it.** Ticket 43 capped the printed residual at three cases
and recorded what the unbuilt half owed: *"the descriptor keeps all forty-one."* That single line is
the difference between a design that works and one that cannot, because it means **the prose is a
LOSSY function of the term** — so the descriptor has to carry the residual's *parts*, and a
descriptor holding the finished display string, which is the obvious first design, can never
re-derive the prose it is supposed to produce. §1 would have been satisfied in name and broken in
fact.

It was found by reading the code about to be moved, which is luck. The general form is this file's
own recurring subject one level in: F15 recorded that **a prose-only blocker is an invisible one**,
and this is the same failure for a REQUIREMENT. Written where the constraint applies rather than
where the work will happen, it is invisible to whoever builds the other side — no ticket named it,
the map's index could not have surfaced it, and `grep` found it only because the line sat inside
the region being cut.

**And the gate had to be pointed at a SHAPE rather than at a call.** The obvious rule — no
`io:format(standard_error, …)` outside `bs_diag` — is wrong, and wrong in the direction that makes
a gate a nuisance: the CLI legitimately prints `bsc: which function?` and the REPL echoes, and
neither is a diagnostic. What separates them is that a diagnostic **names a source location**, so
the gate greps for `~s:~p: error:` and lets usage errors alone. An exclusion that had to be argued
for every new CLI message would have been removed within two features, which is exactly how the
`examples/*.bs` exclusion rotted.

**A second cause was found for a symptom that already had one.** A "cancelled" eunit run with a
partial count means `/tmp/bsc_eunit` has filled up — and now also means
`every_example_still_compiles_test` blew eunit's **5s default**, since it shells out once per module
directory at 3.8s warm. On this feature's own fresh worktree the suite stopped at 67 of 332 before a
line had been changed. It has a timeout fixture now. CI never sees it because the workflow builds
the escript first, which is the blind spot that let `cli_tests` never once execute in CI.

**F14 IS BUILT, AND WHAT IT REVEALED IS THAT A CHECKER MUST KNOW WHAT IT WROTE ITSELF — 2026-08-18.**
Both operators run, ten gates are green and the suite is **319** tests. The pipe cost almost nothing
and that was the prediction: it is a parser rewrite, so `bs_check` and `bs_emit` never learned the
operator exists. The valve cost the whole feature, and every one of its costs came from the same
place — **the lowered `switch` is code the author did not write, and a compiler that cannot tell the
difference gives advice about it.** A bare `e_switch` would have earned `unreachable_arm` on the
generated error arm (the exact message F14 §4 exists to replace) and ticket 12 §2's catch-all rule
against the value arm, which is a catch-all *every single time*. So the node stays marked to the
checker and is unwrapped only at emission.

**The second thing it revealed is that two gates were lying by omission, which is the shape F11 and
F15 also found.** `bs_test_support:check_only/1` called `bs_parser:parse` directly and skipped the
new lowering pass — and an unlowered node falls through `type_of/3`'s catch-all to `term()` with no
diagnostics, so every valve assertion about clean source would have passed while **nothing was
checked at all**. A test helper that does not walk the compiler's own path is not testing the
compiler. And `editor/bin/check-tokens.sh` checked *"keywords and the two arrows"* — a hardcoded
pair — so it could not see `|>` or `|?>` at all; it now checks a named list of multi-character
operators, and was measured failing before it was believed. Both are the F12 lesson again: a gate
is only as good as what it was told to look at.

**AND THE QUEUE IS EMPTY FOR THE FOURTH TIME.** Every feature with a file is done. The only row left
is **F13 — binary patterns**, which has no file because it is blocked on **ticket 30**, still open.
The cycle the paragraphs below describe applies unchanged: *starve → resolve a decision → build →
find what the building reveals*. The decision to resolve next is 30's.

**THE FOURTH STARVATION BROKE THE CYCLE INSTEAD OF COMPLETING IT — 2026-08-18.** F16 was built
without resolving anything, because the queue was never the whole backlog: the *decided, unbuilt*
table further down this file has been carrying takeable work the whole time, and 23 §1 had sat in it
since the LSP question was answered. So the rule the three previous starvations taught — *resolve a
decision next* — is a rule about the FEATURE ROWS, not about the repo. **Read the decided-unbuilt
table before concluding there is nothing to build**; a decision that is closed and unbuilt is a
feature that has not been given a number yet. Ticket 30 is still the decision F13 needs, and that is
unchanged.

**F12 IS BUILT, AND WHAT IT REVEALED IS THAT A GATE IS ONLY AS GOOD AS ITS TAGGING — 2026-08-17.**
`public`/`private` sits on every signature in the repo, `'Fib'.beam` exports `Fib/1` and nothing
else, and ticket 40 is closed. Ten gates, 302 tests, 66 corpus signatures of which **18 are
private**.

**The finding is a tag, and it is worth more than the feature.** Ticket 40 was tagged `modules`
`codegen`. `check-surface.sh` selects on `syntax` or `patterns` — so **the one decision that puts a
keyword on every signature in the language was never asked for a `LANGUAGE.md` paragraph**, and this
feature could have rewritten all 32 `.bs` files with the reference silent and every gate green. That
is this file's own recurring subject arriving by a new route: not a gate that stopped looking (F11,
F15) but one that was never pointed at the thing. **A tag is applied when a decision is made** —
before anyone has built what would show which surfaces it touches — so the question at tagging time
is not *what is this decision about* but *would a reader of `LANGUAGE.md` see a difference*. Three
sections in 40, only §3 changes the surface: that is how a multi-section ticket gets tagged by its
majority.

**A whole-corpus rewrite is where an anchored probe dies quietly.** `corpus_tests.erl`'s
`{"bool as a declared type", "^bool "}` had **exactly one match in the corpus**, on a signature line,
and the marker moved it. The probe would have gone on asking the right question and matching
nothing. Every `^`-anchored probe in that roster is a hostage to any change at the start of a line,
and this is the second time the roster has needed attention in two features.

**Erlang will not tell you a tuple grew.** Seven `{signature, …}` pattern sites were widened and one
was missed; an unmatched comprehension pattern is not a compile error, so the checker collected *no
local callees at all* and every call became `unknown_callee`. 273 tests found it and the compiler
found none of it.

**And `erlc` deletes an unexported function nothing calls** — so a *dead* private function is not in
the beam and `module_info(functions)` cannot report it. The first REPL fixture written for that
diagnosis did not call its private function, and therefore tested the fallback while looking like it
tested the feature. Sixth feature running to find something at the `ibs` prompt, and the first to
arrive there with tests rather than fix it without them.

**F15 IS BUILT, AND WHAT IT REVEALED IS A GATE THAT HAD STOPPED LOOKING — 2026-08-17.** A module is
a directory: `bsc --src-root examples examples/Shop/Reports Restate 3` prints `9`, both owed checks
fire, and a crash in an aggregate names the file its clause is written in. 286 tests, nine gates.

**Three gates were pointed at `examples/*.bs`, which after the corpus rewrite matches nothing — and
an unmatched glob in bash is passed through unexpanded rather than vanishing.** So
`editor/bin/check-corpus.sh` ran its loop **exactly once, on a filename with a `*` in it**, reporting
one ERROR for a file that does not exist while checking none of the ones that do. That is the second
time in two features that this same script was found silently not checking, after F11 fixed its
SIGPIPE abort — and the lesson is the one that outlives both: *a gate that reports something is not a
gate that is looking*.

**Fixing it found a real grammar bug on the first honest run**, which is the argument for gates in one
line. `Shop.Collections.List.Sum(…)` was an ERROR node: `prec.left` on `module_path` made the path
swallow the function name. That is **F11's yecc finding in the other parser**, hidden by two things at
once — the glob had never reached the only file in the repo with a three-segment qualified call, and
one dot needs no decision, so `List.Map(x)` parsed correctly under the broken rule.

**And the `ibs` prompt found a wrong-file diagnostic that 285 passing tests did not.** Returned
diagnostics were per-file and right; raised ones still named the module's first file, so an error in
`Go.bs:6` printed as `index.bs:6` against a three-line file. Same failure, one code path along.

**F15 EXISTS AS A ROW BECAUSE F11 LEFT IT, AND A PROSE-ONLY BLOCKER IS AN INVISIBLE ONE.** The
module system has two halves and F11 built one: how modules *see each other*. The other is what a
module is *made of* — ticket 13's aggregate rule, where a directory is the module and every `.bs`
file in it compiles into one `.beam`, with `index.bs` holding the shared declarations and never a
function. Today one file is one module, and `examples/Counter/counter.bs` sits in `examples`.

**Two of ticket 41's four specified checks wait here rather than in F11**, and that is why this row
is not optional: `{module_path_mismatch, …}` (§5) tests a declaration against its *directory* path,
and `{function_in_index, …}` (§4) guards a file nothing can currently produce. Written against
today's layout, the first would fail every file in the repo. They are specified, they are owed, and
before this row they were recorded only in prose — which is exactly how F2 sat takeable-looking for
a day. `13b` already measured the mechanism working, so what is missing is plumbing, not technique.

**F11 IS BUILT, AND THE TWO THINGS IT REVEALED ARE WORTH MORE THAN THE FEATURE — 2026-08-17.**
Modules can see each other: `bsc examples/Shop/Reports/Totals.bs Restate 3` prints `9` across two
modules, resolved, ordered and checked without anybody naming a path or a build order. 268 tests.

**A RESOLVED DECISION WITH NOTHING IMPLEMENTING IT.** Ticket 40 §2 permitted arity overloading on
2026-08-15 and the compiler could not represent it — `callees` keyed by name alone, so
`maps:from_list/1` kept the last arity written, and `collect/1` gave `Length/1` the clauses of
`Length/2`. **This file had already written up that exact mechanism** for duplicate *type*
declarations, and nobody noticed it applied one namespace along. A decision is not built because it
is resolved, and the gap is invisible to a suite whose corpus never exercises the new rule — no `.bs`
file had ever overloaded an arity. It was found by *writing the example*.

**A GATE THAT REPORTS ONE FAILURE AND HOLDS FOUR.** `editor/bin/check-corpus.sh` aborts at its first
failing file: `… | grep -F ERROR | head -3` under `set -e` and `pipefail` gives `grep` a SIGPIPE and
kills the script. The single red file that was reported on 2026-08-16 was masking **four more**, and
every one was a shipped feature the tree-sitter grammar had never gained — strings (F9), `and`/`or`
where it still carried the *removed* `&&`/`||` (ticket 44), `var` (F8), `== name` (45), and `where`
(F2). `check-tokens.sh` passed the whole time, exactly as its own header warns it would: it proves a
keyword is present, never that a rule uses it. All five are fixed, the abort is fixed, and the gate is
green for the first time since F9 — **and neither editor gate is in CI, which is why five features'
worth of drift could accumulate unseen.** That is the finding that outlives this feature.

**THE PLACEHOLDERS RENUMBERED — 2026-08-17.** The module system took the **F11** slot and
`public`/`private` took **F12**, so binary patterns moved to F13 and pipe-and-valve to F14. This is
the F4/F5/F8 precedent exactly: a placeholder with **no file** may shift, and neither had one.
**Every paragraph below this line predates the shift** — where they say `F11` they mean binary
patterns and where they say `F12` they mean pipe and valve. Nothing below was rewritten, because
this file keeps its history rather than editing it.

**F2 IS BUILT, AND THE QUEUE IS EMPTY FOR THE THIRD TIME — 2026-08-16.** Every feature with a file
is done; F11 still waits on ticket 30 and F12 still has no file. The cycle ran exactly as the
paragraphs below predict — *starve → resolve a decision → build → find what the building reveals* —
and what F2's building revealed is worth naming here rather than only in its own file:

**Ticket 12 §2 was reachable before F2 and nobody had asked.** Its own examples are declared unions
of atoms, and F2 was written expecting to *create* the closed-residual case with `type Octet`. It
did not create it: after two guards over a bare `int` the residual can be `0..0`, which has no
unbounded top and is therefore closed by 12 §2's operative definition. Two switch tests had been
asserting the old behaviour since F7. **A rule whose trigger is computed rather than declared is
reachable from places its ticket never listed**, and the only way to find out is to build the
check and run the suite.

**And the third gate in a row was already red before the feature touched it.** F10 was chosen by a
red `spec-check.sh`; F2 found `editor/bin/check-tokens.sh` red on `var` — shipped by F8 with no
rule in either editor grammar — and `check-corpus.sh` red on `label.bs`, because the tree-sitter
grammar has no string-literal rule and F9 shipped strings. **Neither editor gate is in CI**, which
is the whole reason both could rot. That is the exclusion pattern this file has already written
about twice, in a directory the CI file does not mention at all.

**The next session belongs on the map**: ticket 30 unblocks F11, and F2 raised
[ticket 46](../../wayfinder/issues/46-refined-parameter-at-the-boundary.md).

**IT WENT THERE, AND THE QUEUE HAS AN ITEM AGAIN — 2026-08-16.**
[Ticket 41](../../wayfinder/issues/41-imports-and-cross-module-scope.md) resolved, which was the
*claimed* ticket rather than a fresh one: §2 and §5 had been answered on 08-15 and were
**unverifiable** until §3 closed, because neither unqualified names nor namespace resolution can be
checked without knowing where the checker gets another module's types. With
[40](../../wayfinder/issues/40-module-and-namespace-system.md) already resolved, **the module system
is now fully decided and entirely unbuilt** — which makes it the takeable feature, and it has no
file yet. It unblocks more than any remaining candidate: the collection library, and therefore
`list<string>` operations, AoC input, and three of the four fog patches that wait on the module
patch. F11 still waits on ticket 30 and F12 still has no file.

**Four checks and one delta are specified for it, so it has nothing to design**:
`{name_redeclared, Name, Arity, Line}` (40 §2), `{module_path_mismatch, Declared, Path, Line}`
(41 §5), `{function_in_index, Name, Line}` (41 §4), §2's ambiguity rule — plus the §3 delta, which
is smaller than its ticket claimed. **`bsc` is already multi-file**: `compile_only/2` is a map over
a file list and `bsc Alpha.bs Beta.bs` emits both beams, so what is missing is one shared
environment threaded through a loop that exists, not a new CLI or artefact. Measured in
[`41a`](../../wayfinder/prototypes/41a_multifile_probe.sh) — and the ticket's own opening premise
(*"the compiler is single-file"*) was **false**, which is the third time now that measuring a
ticket's premises changed what the work was.

**Two grammar rules gate all of it**: `using` over a modpath and `Module.Fn(…)` at a call site both
still fail to parse (`syntax error before: 'Alpha'`, `before: '.'`). They are owed by 41 §1/§2 and
are where the feature starts.

**And F8 is the reason this file should stop calling the empty queue a stall.** The feature was
built because a decision was resolved; it then closed a **soundness hole that no ticket, no
feature and no gate had ever noticed** — `F(acc, acc)` accepted as exhaustive over `(int, int)`
while `F(1, 2)` crashed. That was found by writing three lines of B# to check a sentence in
`LANGUAGE.md`, not by any of the six gates. The cycle *starve → resolve a decision → build → find
what the building reveals* is the working state, and its yield is not measurable from the queue's
length.

**The paragraph below is kept as written**, because its prescription was right and was followed.

**THE QUEUE HAD ONE ITEM AGAIN, AND IT WAS F8 — 2026-08-16.** It was empty for a day, which was the
table's most important fact at the time and is worth keeping in view: every feature file that
existed was done or blocked, F2 owed two decisions, F8 owed one token, F11 waited on ticket 30, and
F11 and F12 had no files. That was not a stall but the seam at the top of this file working exactly
as written — *a feature that needs a decision raises a ticket rather than making one*, and features
that keep that rule must eventually starve. **The prescription that followed was right and was
followed**: the next session went to the map, resolved [ticket 45](../../wayfinder/issues/45-match-token.md),
and handed the compiler back a buildable feature. **The cycle then ran a second time and closed:**
[43](../../wayfinder/issues/43-residual-summarised-form.md) was resolved 2026-08-16 and F2 is
takeable, so the queue is not starved. Worth recording that 43 was resolved *by measuring rather
than by choosing* — two of its own premises turned out to be false against
[`43a`](../../wayfinder/prototypes/43a_residual_at_width.escript), and the corrections, not the
option menu it framed, are what answered it.

**The starve-and-refill cycle is the working state, not a fault to design out.** A day of it cost
one ticket's work and returned a feature whose file is now *more* correct than it was — 45 found two
things F8 had wrong. Read a full table as a signal to go to the map, and an empty one as the same
signal shouted.

**A status in this table outranks the header of the file it links to.** F2's header read
`not started` while this row read `blocked`; a session took the header at its word, claimed the
feature and had to be turned round. Both are now `blocked` and both name the tickets — but the
general rule is worth more than the fix: **this table is the queue, so it is the queue's state.**
A feature file's header is a copy, and copies drift.

**And the root cause was neither file.** The map's canonicality contract puts *state* in Linear and
*content* in the repo — and F2 had **no Linear issue at all**, so its blocked-ness lived only in
prose, in two places, with nothing to reconcile them. F2 is now
[ENG-214](https://linear.app/davewil/issue/ENG-214) with native blocking edges to
[ENG-212](https://linear.app/davewil/issue/ENG-212) and
[ENG-213](https://linear.app/davewil/issue/ENG-213).

**The same gap was then found on F8, and closed before it cost anything.** F8's *The token* section
named a decision the file *"must not make"* and no ticket existed for it — identical to F2, one
feature along. It is now [ticket 45](../../wayfinder/issues/45-match-token.md) ·
[ENG-216](https://linear.app/davewil/issue/ENG-216), and F8 is
[ENG-217](https://linear.app/davewil/issue/ENG-217), blocked by it.

**So the rule, stated once here rather than rediscovered a third time:** *a feature file naming a
decision it needs **is** raising a ticket, and it does not count as raised until the repo file and
the Linear issue both exist.* Naming a blocker in prose feels like recording it and is not — a
blocker no query can find does not exist as far as the frontier is concerned, which is precisely
how F2 sat takeable-looking for a day. **F11 and F12 still have no issues**, deliberately: F11's
blocker is ticket 30, which is already on the map, and F12 has no file to state blockers from.

**F4 was built out of order and the rule was not bent quietly.** No exemplar is blocked on
bindings — the three that exist contain zero. It was built because David reached for one in the
first minute of using the compiler, which is a different ground from the ordering rule and is
stated as such in the file: *the first thing a fluent reader reaches for should not be absent by
accident.* The placeholders below it shifted by one; none had a file.

**F3 raised the map's first ticket from a feature**:
[ticket 33](../../wayfinder/issues/33-body-check-site.md) — *is a function body typed at all, and
where does the check run?* F2 and F3 hit the missing seam from opposite directions, and three of
F3's scenarios were deferred on it with their ids reserved. **RESOLVED 2026-08-14**, and F5 is now
what implements it: a body is typed, checking is containment at five sites (call argument,
construction, projection, clause return, destructuring bind), and the residual survives at four of
them — `subtract/2` + `to_pattern/1` hand a call site the clause head the *caller* must write, and
hand a projection the union member that lacks the field. **It takes the F5 slot ahead of angle
brackets**, since `option<T>` fields multiply construction sites and F3.10 is the hole F3 shipped
with; the placeholders below it shifted by one, and none had a file. The ticket carries the
compiler delta stated against the shipped source, so F5 has nothing to design.

**Two things the ticket found that F5 must not get backwards.** A body variable's type is read off
the clause's **refined domain** at the path `pattern_type/3` already records — a bare `p_var` is
`term`, so typing a body from its patterns fails every call site — and the intersection must use
**`Possible`, never `Certain`**, since an untranslatable guard makes `Certain` `none` and would
type a running body's variable as a value that cannot exist. `walk/5` already computes the right
domain and discards it, so the check is not a second pass.

**And a lesson about this seam rather than about this ticket.** Two of 33's premises went stale in
the three hours between raising it and resolving it — F4's scope pass made *"`bs_check` never
visits a function body"* false, and the Question's expression inventory was short by eight forms.
A ticket raised out of a feature is a **timestamped claim about the compiler**, so re-measuring its
Question is the first step of resolving it, not the last.

**F5 built it, and the corpus gate is what earned its keep.** All thirteen scenarios pass and the
three F3 deferred with their ids reserved are asserted rather than reserved; 106 tests, up from 79.
Ticket 33's compiler delta was accurate and its site enumeration complete — **and it missed the one
thing that would have broken the build**, because that thing is not about where a check runs but
about whether the checker can *address* the value it is checking. A list element had no path, so
`Reverse([x, ..rest], acc) -> Reverse(rest, …)` typed `rest` as `term` and a shipped example was
rejected by a checker working correctly on wrong information. Reverting the fix turns **7 of 106
tests red**, which is the rule at the top of this file arriving through the back door: *a capability
that closes a residual without supplying a way to name the cases makes previously-valid programs
invalid.* **Run the corpus gate before writing a single rejection test** — a regression otherwise
hides behind a green new test.

**And the trap that does not fail loudly.** Ticket 33 §5 warned the domain must use `Possible`,
never `Certain`. Built with `Certain`, the suite goes **1 test red** and the compiler is *quieter*,
not broken: `Certain` is `none` under an untranslatable guard, and every containment over `none`
passes vacuously. A check that fails by going silent cannot be tested by a passing test — it needs a
scenario asserting an error the wrong build **omits**, and both traps were confirmed by mutating the
source rather than by the suite being green.

**Two things F3 found that the next feature inherits.** The **benchmark had been broken on
master** since the `;` terminator was dropped, so the skeleton's recorded numbers were not
re-measurable — fixed, and the atom ladder reproduces them. And **`bin/spec-check.sh` is red**
independently of F3: `counter.bs` declares `behaviour GenServer` without defining its callbacks,
so Dialyzer reports three undefined callbacks. Whoever owns the OTP callbacks should close it; it
is a gate nobody can currently pass.

**A third thing no feature owns: a type name may be declared twice, silently.** Measured on master
2026-08-15 — four probes, all four compile clean and exit 0: `record Order` twice, `type Doc` twice,
and `type Order` / `record Order` in either order. `type_env/1` builds the environment with
`maps:from_list(Aliases ++ Records)` and `maps:from_list/1` keeps the **rightmost** duplicate, so the
rule is not source order — which is what makes it worth writing down rather than assuming. **A record
beats an alias of the same name whichever was written first**, because records are the right operand
of that `++`; between two records, or between two aliases, the later one in the file wins. The losing
declaration's fields simply vanish, and the function declared over the name is then checked for
exhaustiveness against a type its author did not write, which is the one guarantee the whole project
rests on. Found while answering why `shop.bs` may declare two records where Elixir allows one struct
per module: qualification (`Shop.Order`) is what makes the *two-record* case sound, and qualification
does nothing at all about the *same* name twice.

**It should be an error at the second declaration, and three shipped precedents settle that rather
than taste.** `kind_field_is_minted` already errors at a *declaration*, and its comment names ticket
15's collapse rule as the reason; rebinding is an error because *"a name means one thing in a
clause"* (34, F4); a cyclic alias is refused by name rather than expanded (F6.8). A warning would
leave a program whose meaning depends on which declaration the compiler happened to keep. And
`record Order` against `type Order` is the **same** error, not a second one — ticket 26 §1 makes a
record an alias for a tagged map and F3.2 asserts the two spellings are the same type, so there is
one namespace for them to collide in.

**The delta, so nothing needs designing.** `type_env/1`'s alias arm drops the line
(`{type_alias, _, N, …}`) — keep it, check `Aliases ++ Records` for a repeated key before
`maps:from_list/1`, and raise `{type_redeclared, Name, Line}` into the path `bsc:resolve_error/2`
already catches, which is the route `kind_field_is_minted` takes and the reason it can report a line.
One new `resolve_error/2` clause carries the message. This is a **sibling of, not the same as**, F6's
*"a type parameter shadows a type of the same name"*: that one is inside a single declaration, this
one is across two.

**F6 took ticket 27's own cut, and the ticket wrote it before the feature did.** Generics is three
questions wearing one coat; F6 built parameterised constructors and parametric aliases — both
**substitution with ground arguments** — and left polymorphic function *signatures*, which are
**matching**, to [ticket 37](../../wayfinder/issues/37-instantiation-by-matching.md). 27's line
*"the costs are asymmetric and they do not chain"* is the licence, and three measurements back it:
`Map` cannot be written at all (no arrow in the algebra, no lambda), no exemplar declares a
polymorphic function, and matching a variable **inside a union** — `option<T>` against
`int | :nothing` — is a question about subtraction that nothing has decided.

**The gate F6 owed was not a rejection test, it was a stopwatch.** A cyclic alias did not error on
master — it **hung**, and `type_env/1`'s own comment said why (*"this slice has no recursive aliases
yet"*). Parameters make `type Tree<T> = (T, list<Tree<T>>)` the first thing anyone tries, so the
guard shipped with the feature that made the hazard reachable rather than with the one that finally
implements recursion. **A hang is invisible to a green suite**, which is F5.7's lesson in a second
costume: the mutation had to be measured by a clock, not by a red test.

**And it is a shared-function change.** F6 edits `resolve/2` — the single funnel the checker and the
emitter both go through, which F5 exported precisely so there would not be two. The corpus gate ran
first for that reason and not by ritual, and it passed — but **not because F6 adds no rejection
path.** It adds four. It passed because expansion happens strictly before the algebra, so no
existing program's type changed, and because all four new rejections target source that previously
failed to parse or failed to terminate. The narrower sentence is the true one.

**F7 found a defect that was never about `switch`, and it is the worst shape one can take here.**
`LANGUAGE.md` §4 said `true` and `false` are the language's only keyword atoms and marked it
**shipped**; the lexer had `:true` and `:false` and no bare rule, so a bare `true` lexed as an
ordinary lowercase identifier — which in pattern position is a **variable**. `Decide(true, p)`
bound a name, matched everything, and returned `:ack` for `false`. The program **compiled and meant
something else**, and the only trace was an unreachable-clause warning that reads like a remark
about the code rather than a report of a misparse.

Two things follow that are worth more than the fix. **`bin/check-language.sh` could not have caught
it**: the claim is prose, not a fenced block, and the gate distinguishes compiles from does-not, not
means-what-it-says. And **it was reachable only by running ticket 17 §6's own example** — every
tuple-subject switch in `examples/exemplars/` is written in bare `true`/`false`, so the defect sat
directly under the feature nobody had built yet. A capability's own motivating example is a probe,
and running it before writing the feature is cheaper than trusting the reference's own status column.

**And F7 is the third feature in a row to find a hole at the `ibs` prompt** — F4 a stale diagnostic,
F5 a destructuring bind that did not work there, F7 the keyword atoms reported as unbound names. The
REPL has **no tests at all**: `bs_repl` appears zero times in the suite. Each feature has fixed what
it tripped over and none has closed the gap, which is now a pattern rather than three incidents.

**F8 takes the slot ahead of binaries, and the argument is cost rather than capability.** It
unblocks no exemplar. It goes first because it **rewrites every `.bs` file in the repo**, and every
later feature adds more of them — doing it after binaries and the pipe means rewriting their files
too. Same precedent as F5 taking the slot ahead of angle brackets: the features below had no file,
so binaries and pipe shift to F9 and F10 and nothing is lost.

**It is drafted and BLOCKED, which is F2's status for the same kind of reason.** The feature needs
one token — how to mark a name in a pattern that means *the value it holds* rather than a new
binding — and that is a spelling every future `.bs` file will carry, so it is a decision and not a
feature's to make. The file names the candidates, their collisions and a recommendation (`==acc`,
the only one reusing a spelling the language already has), and stops there.

**The capability behind it is the one Elixir spends `^` on**, and David named the reason: *"Elixir's
bind and ^ pin is for a reason, it's to bypass matching/binding."* Measured — beam-sharp cannot
match against a value computed at run time at all, so a reduce whose accumulator is *tested* rather
than rebound has no spelling, and the guard workaround costs the exhaustiveness credit because the
checker translates `var == literal` and not `var == var`.

**F9 split what was one row, and the cut is between decided and open rather than between big and
small.** *Binaries* was a single line here; it is two capabilities with opposite statuses. Binaries
**as values** — the type, the literal, the refinement, the boundary rule — is ticket 20 §§2–5,
resolved, and F9 built it. Binaries **as a parsing grammar** is ticket 30, which is **open** and
whose two questions are both unanswered: a segment sized by a bound variable is not expressible in
`<<_:M, _:_*N>>` at all, and a union discriminated by a *value* inside the binary has no story. F10
therefore ships blocked in the same way F2 and F8 are, and for the same reason — a feature may not
decide.

**F9 also declines a spelling rather than inventing one.** A sized binary type has none: 20 §2
published the algebra in Erlang's `<<_:M, _:_*N>>` notation, and this surface writes `list<T>` where
Erlang writes `[T]`. Borrowing it unexamined would be the first place the language does the
opposite. It is owed, ticket 30 is the closest owner since it needs a spelling for the pattern form
anyway, and *a pattern and a type that cannot be written in the same notation is a worse outcome
than either choice*.

**And the honest version of the AoC report's headline.** That report named `string` as the one thing
to build next and said it *"unblocks I/O for AoC"*. It does not, and F9's file says so before its
scenarios rather than after: reading a file needs the FFI plus the UTF-8 entry check, and splitting
lines needs the collection library, which is blocked on the module system. F9 removes **one of
three** blockers. What it does unblock is the other half of that sentence — `list<string>` and
`Id: string` failed on the identical `unknown_builtin`, and every record in `LANGUAGE.md` §6 and in
all three exemplars has a `string` field.

**The defect F9 found was in the emitter and only a string could reach it.** `to_abstr/1` wrote
forms with `~p` — bytes — and `erlc` read them back as UTF-8, so `"héllo"` became five bytes instead
of six. It compiled, ran, and returned a good binary that was the wrong one; only a byte count
showed it. Third in the series after F5's vacuous containment and F6's hang, and the same lesson
each time: **a defect that fails by going quiet cannot be found by a passing test.** The fix is one
line at the boundary rather than at the caller, because emitting per-byte integers would have fixed
strings and left the trap set for the next non-ASCII thing to reach a form.

**F10 was chosen by a red gate rather than by the ordering rule, and that is a third criterion this
file did not have.** F4 was built because David reached for a binding in the first minute; F8 took
its slot on rewrite cost. F10 unblocks no exemplar outright — it was built because
`bin/spec-check.sh` had failed on `master` since the day CI was added, and the cause was a decision
nobody had taken rather than a defect in the script. **A gate that cannot pass is not a backlog
item**, because every other gate's credibility rests on the set being green.

**The decision it needed turned out to be smaller than it looked, and mechanism is why.** Ticket 35
asked what name a callback lowers to and offered "a compiler-known table, or something the user
writes". The second **cannot be written down**: `signature -> type_prim uident '(' params ')'` and
`uident` is `[A-Z]{ALNUM}*`, so a beam-sharp function name is PascalCase by construction and
`handle_call` is not a spellable function name. That is a grammar fact, not a preference, and it
collapsed the sub-question — which is worth repeating as a habit: **check whether the alternative
can be expressed before weighing it.**

**And the answer is a table rather than a rule because it is contract-scoped.** A row fires only for
a name *and arity* that is a callback of a behaviour the module *declares*, so `HandleCall/3` in a
module with no `behaviour` line, or one declaring `Supervisor`, keeps its spelling. That is the
sentence answering 35's own worry that renaming would be "a naming rule by another route".

**Two CI exclusions came out, and only one of them was this feature's.** `extract-exemplars.sh
--check` had been excluded for a reason that stopped being true when an earlier session unified the
exemplar dialect, and nothing came back to re-enable it. **An exclusion that outlives its reason is
the same failure the CI file was written about** — so the block is gone and the rule is now that a
removed gate goes back with its reason, and the reason gets re-checked rather than inherited.

F11 onward are named but not written — deliberately. The map's own fog-of-war rule applies: don't
chart what you can't yet see.

**Editor support landed outside the compiler, and asked a question this file can answer.** `editor/`
now holds a Tree-sitter grammar plus TextMate and vim ones, with two gates
(`editor/bin/check-tokens.sh`, `check-corpus.sh`). David asked whether an LSP should be **ticketed**
to come back to. It is: **[ENG-205](https://linear.app/davewil/issue/ENG-205)**, and it is
deliberately **not a map ticket** — no `wayfinder/issues/NN-*.md`, following the convention ENG-199
already set with *"F3 (feature, not a map ticket)"*.

The distinction matters and the first answer got it wrong. *Tooling and ecosystem — … LSP …* sits
under the map's **Out of scope**, marked *"closed, never graduates"*, so the **map** must not acquire
a ticket for it. That is a statement about the design effort, not about what may be tracked — and
conflating the two is what produced the wrong answer (David: *"it's clearly a required thing I've
literally just asked for. So a Linear ticket for it is surely fine, doesn't have to be on the
/wayfinder map"*). Linear owns state for the whole of the work; the map owns the decisions. A thing
that has been asked for needs somewhere to live even when the map is not that place.

What the question does surface is that **three of an LSP's four prerequisites are already decided and
simply unbuilt**, which makes them features. Ticket 23's clarification is the test — *"is this the
multi-year track, or one capability the language owes its author"*:

| | Where it stands |
|---|---|
| 23 §1 — the diagnostic is a **term**, prose a pure function of it | **BUILT — F16, 2026-08-18.** `bs_diag` owns the descriptor and every format string; `bsc --diagnostics term` publishes it, and `bin/check-diagnostics.sh` is what stops the drift reopening |
| 23 §10 — `bsc --api <Module>` | **decided, unbuilt.** The map cites this by name as the example of what is *in* scope |
| Columns | **no decision owed.** Measured in parsetools 2.7.1: leex predefines `TokenCol` and `TokenLoc`, and yecc's `error_location` already defaults to `column`. `bs_lexer.xrl` writes `TokenLine` by choice. Since `line/1` is `element(2, T)`, the lexer's actions are the whole change in the parser; the cost is downstream, in the `~s:~p:` format strings and the Abstract Format annotations |
| 23 §5 — a JSON **encoding** of the term | **blocked**, and already logged: it inherits ticket 16 §4's serialisation mapping, which the map lists as owed and unwritten |

**And the thing worth not losing**: the residual is already pasteable source. `heads/2` prints the
clause to add, `caller_head/3` the one the caller must write, F7 the missing arm. 17c measured Gleam
printing *"The missing patterns are: False"* — prose, which a human reads and a tool cannot act on.
An editor action that inserts a clause derived from the residual **cannot be wrong**, because the
residual *is* the missing case. That is a reason to build 23 §1 for its own sake, and it holds
whether or not a server is ever written.

Nothing above was needed for the highlighting that shipped, which is itself evidence the map's
boundary is drawn in the right place.

**F3 was written ahead of F2, and F2 is why.** F2's own file says in bold that it must not be
implemented until the spelling of an interval pattern and the summarised form of a wide residual are
answered, and both are *"a decision, not a feature"*. The ordering rule then decides the rest:
records block all three exemplars where refinements block two, and ticket 26 closed on 2026-08-13
with four sections settled. The claim that *"F2's outcome will change what F3 should say"* was an
expectation with no probe behind it; F3 records it as an assumption and states where it would break.
