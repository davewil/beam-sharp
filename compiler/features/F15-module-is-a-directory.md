# F15 — A module is a directory: aggregation, `index.bs`, and the two path checks

**Status**      **done 2026-08-17** · [ENG-221](https://linear.app/davewil/issue/ENG-221)
**Implements**  [ticket 13](../../wayfinder/issues/13-compilation-target-decision.md) §3 and
                [ticket 41](../../wayfinder/issues/41-imports-and-cross-module-scope.md) §3–§5,
                all resolved — decides nothing
**Unblocks**    the *other* half of the module system: `index.bs`, ticket 41's last two specified
                checks, and the one-function-per-file `write_scope` the whole agent story rests on
**Depends on**  F11

## Why this one now

F11 built how modules **see each other** and left what a module is **made of**. This is the second
half, and it is the last piece of tickets 40/41 that is fully decided and entirely unbuilt.

It is also the row that exists *because* a prose-only blocker is an invisible one. Two of ticket
41's four specified checks — `{module_path_mismatch, …}` (§5) and `{function_in_index, …}` (§4) —
were moved out of F11 with a reason, and until this file existed that reason lived in a README
paragraph. That is precisely how F2 sat takeable-looking for a day.

**The two moved scenarios are F11.3 and F11.13**, restated below as F15.5 and F15.6 with their
original wording intact.

## What is being built

Today `bsc` reads one `.bs` file and writes one `.beam`. After this, the **directory** is the unit:

```
Shop/
  Orders/
    index.bs        module Shop.Orders   — using, type, record, behaviour. No functions.
    Total.bs        module Shop.Orders   — one function
    Apply.bs        module Shop.Orders   — one function
  Reports/
    index.bs        module Shop.Reports
```

`Shop/Orders` emits **one** `'Shop.Orders'.beam` holding `Total/1` and `Apply/1`. `Shop` holds no
`.bs` files, so it is a **namespace**: no atom, no beam, nothing emitted (41 §5).

A crash still names the file the function was written in, not the aggregate — 13 §3 measured this
in [`13b`](../../wayfinder/prototypes/13b_aggregate_attribution.erl) via a repeated
`{attribute, ANNO, file, {Name, Line}}` re-pointing every form after it:

```erlang
total/1 crash: {'Shop.Orders.Order',total,[99],[{file,"Order/Total.bs"},{line,42}]}
```

**What is missing is the plumbing, not the technique.**

## The source root, and why it is a flag rather than a ticket

41 §5's rule is *"a file's `module` declaration must match its **directory** path — `Shop/Orders/Total.bs`
must say `module Shop.Orders`"*. A relative path needs something to be relative **to**, and that is
the one thing this feature has to be careful about, because getting it wrong makes the check weaker
rather than cheaper.

**A suffix match was considered and rejected.** "The declared path must be a suffix of the directory
path" needs no root and looks like the frugal reading. It is not: it *accepts* `Shop/Orders/Total.bs`
declaring `module Orders`, because `Orders` is a suffix of `…/Shop/Orders`. A module silently
dropping its leading segments mints a different atom — which is the exact drift between the §1 atom
and the path on disk that §5 exists to stop. A rule that does not discriminate the failure its
ticket named is not a cheaper version of that rule.

**So the root is explicit, and 41 §3 already said where it comes from.** That section drew the
build-tool boundary in advance and named this input:

> `bsc` is given a set of `.bs` files (as it already is) **or a directory to walk**, and computes
> the order itself from the `using` edges. A build tool's job is *which files*, **where the source
> root is**, and *what to do with the output* — not *in what sequence to compile them*.
>
> Where that decision now lives: nowhere yet, deliberately. […] **there is nothing to decide until
> something needs building that a file list cannot express.**

F15 is that moment, and §3 wrote the sentence so a future session would notice it. `bsc` gaining
`--src-root` is the compiler **accepting an input the ticket already specified**, not this feature
deciding anything. The module path is the dirname taken relative to the root, segments joined
with `.`.

**The default root is the module directory's own parent**, which makes a single-segment module need
no flag (`bsc examples/Fib` checks `Fib` against `module Fib`) and makes a multi-segment one
**fail loudly** until a root is named — `bsc examples/Shop/Reports` defaults to a root of
`examples/Shop`, expects `module Reports`, finds `module Shop.Reports` and says so. That is the
right shape for a default: it is never silently weaker than the explicit form, it teaches the flag
at the moment the flag is needed, and it never quietly accepts a path the flag would reject.

**The cwd was the other candidate and it is worse**, because every gate and test in this repo runs
from a directory that is not the source root — CI runs from `compiler/`, so `examples/Fib` would
have to declare `module examples.Fib`.

## Scenarios

| id | input | expected | exit |
|---|---|---|---|
| F15.1 | `Shop/Orders/` holding `Total.bs` and `Apply.bs`, both `module Shop.Orders` | **one** `'Shop.Orders'.beam` exporting `Total/1` and `Apply/1` | 0 |
| F15.2 | `bsc --src-root . Shop/Orders` — a **directory** argument | walks it, compiles the module; equivalent to naming its files (41 §3) | 0 |
| F15.3 | a `record` in `index.bs`, used by `Total.bs` in the same directory | resolves — one module, one scope; the tag is still `'Shop.Orders.Order'` (26 §1) | 0 |
| F15.4 | `Shop/Orders/Total.bs` says `module Shop.Orders`, `Apply.bs` says `module Shop.Reports` | an error naming both files — one directory is one module | 1 |
| F15.5 | `Shop/Orders/Total.bs` declaring `module Shop.Billing` | `{module_path_mismatch, Declared, Path, Line}` | 1 |
| F15.6 | a function declared in `index.bs` | `{function_in_index, Name, Line}` | 1 |
| F15.7 | `Shop/Orders/Total.bs` declaring `module Orders` | `{module_path_mismatch, …}` — the **suffix case**, rejected on purpose | 1 |
| F15.8 | `Shop/` holding only directories | classified a **namespace** — no atom, no `.beam`, nothing emitted (41 §5) | 0 |
| F15.9 | a runtime crash in `Total.bs` of an aggregate | the stack names `Total.bs` and its line, not the aggregate — 13 §3, measured in `13b` | — |
| F15.10 | `Shop/Orders/` with no `index.bs`, holding `Total.bs` | **accepted** — §5's test is `.bs` files present, not `index.bs` present (see the wording drift below) | 0 |
| F15.11 | `Shop/` holding `.bs` files **and** `Shop/Collections/List/` holding `.bs` files | **two modules** — `Shop` and `Shop.Collections.List`, with `Shop/Collections/` a namespace between them. §5's classification is per-directory and total | 0 |
| F15.12 | a diagnostic on `Length/2` where `Length/1` and `Length/2` are in **different files** of one directory | names `Length2.bs` — the file the clause is actually in | 1 |
| F15.13 | a sibling file with **no** `module` declaration | the two existing defaults disagree today; F15 makes them agree (see below) | — |
| F15.14 | the whole `examples/` **and** `aoc/` corpora after the rewrite | every module compiles and runs; both gates loop over **directories** | 0 |

## The corpus rewrite is a scenario, not cleanup

F15 cannot compile its own corpus without it, and the reason is sharper than "30 files move":

- `examples/` holds **eleven flat files declaring eleven distinct modules**. Under the aggregate
  rule that directory is *one* module. Every one of them has to become its own directory.
- `examples/collections/` holds `List.bs` (`module Shop.Collections.List`) and `Totals.bs`
  (`module Shop.Reports`) — **two modules in one directory, already illegal** under the rule this
  feature builds. F11 shipped it because nothing yet said it was wrong. F15.4 is that check.

- **`aoc/` is a second corpus and it is worse**, which F8 already had to learn once. All three of
  its files declare `module Day01` — `aoc/2019/day01/day01.bs`, `aoc/2025/day01/day01.bs` and
  `aoc/bench/bench_bs.bs` — and not one sits in a directory that matches. Two are `day01` against
  `Day01` (a case difference, which is a mismatch), and the third is in `bench/`. `bsc.erl:159-165`
  names this file exactly, as the reason it refused to infer a module name from a path:
  *"the repo's own files do not keep that correspondence — `aoc/2019/day01/day01.bs` declares
  `module Day01` — and inventing a filename rule is ticket 41 §5's `module_path_mismatch`, which
  belongs with the directory-as-module work."* This is that work.

This is the F12 shape the features README flagged and the F8 precedent it cites: a whole-corpus
rewrite is its own increment, done deliberately with an id, not a diff that rides along behind the
checks. **The moves and the content edits are separate commits**, because eleven `git mv`s mixed
with content changes is an unreviewable diff.

## The examples gate changes what it covers, and that is stated rather than incidental

The CI step compiles **each file individually**:

```bash
find examples -path examples/exemplars -prune -o -name '*.bs' -print0 |
  while IFS= read -r -d '' f; do ./_build/default/bin/bsc -o "$(mktemp -d)" "$f" || exit 1; done
```

Under aggregation that is wrong rather than merely outdated — a per-file invocation either emits a
`.beam` missing the rest of its directory or errors outright. The loop becomes a loop over
**directories**, which is a change in what the gate proves, so it belongs in this file rather than
arriving unannounced in a diff. The `exemplars/` prune stays exactly as it is and for the same
reason.

**And it is not one loop, it is four.** Three of them compile:

| Walker | What it does today | Under F15 |
|---|---|---|
| CI `Examples compile and run` | `find examples … -name '*.bs'`, one `bsc` per file | one `bsc` per **directory** |
| `body_check_tests:every_example_still_compiles_test` | `file:list_dir` of `examples`, **top level only**, `bsc:file_to_dir/2` per file | per directory — and it never saw `collections/` at all |
| `body_check_tests:every_aoc_program_still_compiles_test` | `aoc/**/*.bs`, `bsc:file_to_dir/2` per file | per directory, with a root per year |
| `corpus_tests:every_shipped_surface_form_has_an_example_test` | reads file **text** to probe for surface forms | unaffected by aggregation; the paths in it move |

Note the second row: the examples gate that runs in eunit lists only the *top level*, so
`examples/collections/` — F11's only multi-module example — was outside it. CI's step recursed and
eunit's did not. Squaring them is F15's, because F15 is what makes the distinction matter.

**The exemplar exclusion is spelled two ways in two places** — `-path examples/exemplars -prune` in
CI and `string:find(P, "/exemplars/") =:= nomatch` in `corpus_tests` — which is one drift away from
a gate that prunes nothing. F15 does not unify them (that is not its job) but records it here,
because `parse_quietly/1` is the *only* reason the three `index.bs` files are invisible to the
source index today, and F15 is the feature most likely to make them parse.

## Three things reading the compiler found, before a line of it was changed

**`compile_only/2` is not a map over a file list, and its own comment says it is.** The comment at
`bsc.erl:74-77` describes the code as it stood *before* F11; today it delegates to `compile_set/2`,
a dependency-ordered fold carrying a `World` accumulator. A plan written against the comment would
have been a plan against code that no longer exists.

**`bs_emit` emits no `file` attribute at all**, and a comment at `bs_emit.erl:434` says ticket 13
*"keeps per-file `file` attributes precisely so crashes point at the right `.bs`"*. It describes an
intention. The technique is real and measured — in the **prototype**, `13b`, and nowhere in `src/`.
F15.9 is where it stops being a comment.

**Two defaults for a missing `module` line disagree**, and directory-as-module is what makes it
bite. `bsc.erl:184-188`'s `module_of/1` returns `undefined` and the file is then **silently dropped
from the source index**; `bs_check.erl:121-125`'s `module_name/1` defaults to `'Main'` and the file
is emitted under that name. Under one-file-per-module a file without a `module` line is a rarity.
Under aggregation it is the *common case* — a sibling file next to an `index.bs` that already names
the module. F15.13 makes the two agree: a file with no `module` declaration **inherits the module of
its directory**, and a directory whose files declare no module at all is an error rather than
`'Main'`. This is the likeliest source of a green check over a wrong `.beam` in the whole feature.

## A wording drift for the map, not a decision for this feature

**First: is `index.bs` mandatory?** Ticket 41 §5 and §4 disagree:

- §5's operative rule, stated as the classification test: *"a directory containing `.bs` files is a
  module"*.
- §4, arguing for keeping `index.bs` function-free: *"`index.bs` is unambiguously the declaration
  file and **its presence is the module marker**"*.

F15 builds §5's version — `.bs` files present ⇒ module — because that is the one written as the
test, and F15.10 pins it. **This feature does not settle the other**; it is recorded here so the map
can, and so a later reader does not take F15's choice for a decision it never made.

**Second, and sharper: what is a "sub-module"?** 41 §5 glosses ticket 13 as having *"made a
directory inside a module a source-only sub-module"*. Read that way, a module directory holding
another module directory is one aggregate and one `.beam`, which contradicts §5's own rule that a
directory holding `.bs` files **is** a module.

**The gloss is the imprecise half, and 13's own measurement settles it.** 13 §3's observed output
is two *files* in one beam:

```erlang
total/1 crash: {'Shop.Orders.Order',total,[99],[{file,"Order/Total.bs"},{line,42}]}
apply/1 crash: {'Shop.Orders.Order',apply,[99],[{file,"Order/Apply.bs"},{line,7}]}
```

`Order/` there is the **module directory** — atom `'Shop.Orders.Order'` — and `Total.bs` and
`Apply.bs` are the sub-modules aggregating into it. 13's sub-module is a **file**, not a
subdirectory, so "one `.beam` per aggregate" and "one `.beam` per directory" are the same sentence
and there is no conflict to resolve.

So F15 builds §5's classification as **per-directory and total**, and F15.11 pins it rather than
leaving it to whatever falls out of a glob. The corpus then *exercises* the mixed case instead of
dodging it: `examples/Shop/` holds `.bs` files and a `Collections/` subdirectory, `Collections/`
holds only directories and is therefore a namespace, and `Collections/List/` is a module again.
That is all three tiers of 41 §5 in one path, runnable.

## Out of scope

- **`public` / `private` — ticket 40 §3.** Still F12. 41 §4's private-helper answer ("a helper gets
  its own file, and `private` keeps it out of the export list") depends on F12, so until F12 lands,
  a helper in its own file is exported. That is consistent, and it is F11's argument unchanged.
- **A build tool.** 41 §3's boundary holds: `--src-root` and a file set are inputs; the order is
  still computed from the `using` edges. Nothing here schedules a build tool.
- **The exemplars.** They are already directories with `index.bs`, and they are generated from
  ticket 25's write-ups by `bin/extract-exemplars.sh`, which is gated. They stay pruned. **But note
  what they show**: not one of the three `index.bs` files carries a `module` declaration at all. If
  a module's name comes from its declaration, three canonical write-ups are missing it — that is a
  finding for ticket 25, not an edit F15 should make to generated files.
- **The import alias** — [ticket 47](../../wayfinder/issues/47-import-alias.md), open.

## Done when

`bsc --src-root examples examples/Shop/Reports` compiles a multi-file directory into one `.beam`
whose functions report crashes against their own source files; both owed checks fire with the
specified tuples; **both** the `examples/` and `aoc/` corpora are rewritten into directories and
compile and run; and every gate stays green with all three compiling walkers looping over
directories.

**A diagnostic must name the file the clause is in** (F15.12), not the directory and not the first
file in it. The diagnostic 4-tuple `{error, Line, FnName, Descriptor}` carries a name and no arity,
so under 40 §2's arity overloading a `{Name, Arity} -> Path` lookup cannot answer it — and
`examples/collections/List.bs` **already** has `Length/1` beside `Length/2`. A lossy lookup here
points a human at the wrong file while every check stays green, which is this project's recorded
worst failure shape and has now appeared four times. The path travels with the declaration.

**And the REPL must be exercised by hand — again.** F11's own "Done when" records that `bs_repl`
appears zero times in the suite and that five features in a row found a hole at the `ibs` prompt.
A REPL whose unit of compilation has just become a **directory** is exactly the shape that
under-serves a single-file prompt, and F11 was the first of the five not to find it broken. `ibs -S`
against an aggregate module is a manual check this feature owes before it is done.

**DONE — 2026-08-17.** All scenarios hold, **286 tests** pass (up from 268), and all nine gates are
green. `bsc --src-root examples examples/Shop/Reports Restate 3` prints `9` through a namespace tier
whose module directories are now real directories.

The REPL check was run and **found a defect** (below). It passes now: `Restate(3)` → `9` and
`Counted(4)` → `8` at the prompt, from two files in one aggregate, opened either on the directory or
on one of its files; and `:reload` picks up an edit to a **sibling** file the prompt was never opened
on — driven through a FIFO so the edit lands mid-session, because an edit made before the prompt
starts proves nothing.

## What the building revealed

**THE `ibs` PROMPT FOUND A WRONG-FILE BUG THE SUITE COULD NOT — TWICE OVER.** The first was
`beam_for/2`, which keyed the build's results by the path it was handed while the build now keys them
by module directory: every `ibs -S file.bs` died in `no match of right hand side value false`, an
escript stack trace. The comment above `run/3` predicts this in so many words — *a capability gets
wired into the compile path and not into this one* — and it is the sixth feature at that seam.

The second is sharper, because the feature had already been designed against it. Diagnostics that are
**returned** were per-file and correct, which is the entire reason the checker's function pass runs
per file. Diagnostics that are **raised** still went through the module's first file, so a call to an
unimported module in `Go.bs:6` was reported as `index.bs:6` — and `index.bs` was three lines long.
**A diagnostic pointing at a line that does not exist in the file it names**, from the same
wrong-file failure the design had closed one code path along. That is where this project keeps
finding its bugs, and it was found by typing at the prompt rather than by 285 passing tests.

**THREE GATES WERE POINTED AT A GLOB THAT MATCHES NOTHING, AND BASH PASSES THOSE THROUGH.** An
unmatched glob does not vanish; `examples/*.bs` arrives at the program as a literal string with a `*`
in it. So `spec-check.sh` handed `bsc` a path that cannot exist, `check-language.sh` wrote all 24 of
its blocks into one directory that is now one module, and `editor/bin/check-corpus.sh` **ran its loop
exactly once, on a filename with a `*` in it** — reporting one ERROR for a file that does not exist
while checking none of the ones that do. That last is the same shape as the abort F11 fixed in the
same script: a gate that silently stops checking.

**AND FIXING THE CORPUS GATE IMMEDIATELY FOUND A REAL GRAMMAR BUG, which is the gate paying for
itself on its first honest run.** `Shop.Collections.List.Sum(…)` was an ERROR node in the tree-sitter
grammar. `prec.left` on `module_path` says *extend*, so the path swallowed the function name — **F11's
yecc finding wearing the other face**, in the other parser, found the same way: by running it.

Two things hid it. The corpus gate's top-level glob had never reached `examples/collections/`, which
was the only file in the repo with a three-segment qualified call. And **one dot needs no decision**:
`List.Map(x)` parses under either reading, so the rule looked correct everywhere it was exercised.
Deciding where the path stops takes two tokens of lookahead — the uident *and* whether a `(` follows —
so the associativity comes off and the conflict is declared. GLR explores both, which is the thing
tree-sitter is for and the reason this grammar has a `conflicts` list at all.

**THREE STALE PREMISES IN THE REPO'S OWN COMMENTS**, all found by reading before writing: a comment
calling `compile_only/2` *"a map over a file list"* that F11 had already made a dependency-ordered
fold; a comment claiming ticket 13 *"keeps per-file `file` attributes"* when the emitter emitted none;
and two disagreeing defaults for a missing `module` line — `undefined`, which silently dropped the
file from the source index, beside `'Main'`, which emitted it under that name.

**THE TEST HARNESS HAD TO LEARN THE RULE `modules_tests` LEARNED IN F11.** Every fixture went into one
shared directory, which is one module with twenty `module` lines. Two runs of the unchanged tree then
failed 2 and then 4 tests, in different modules, because `erlang:unique_integer/1` restarts on a fresh
node and run two was writing into run one's directories — a stale-file annoyance before this feature
and a `name_redeclared` after it.

**And a case-only rename is a no-op on macOS.** `git mv day01 Day01` reports success and does nothing,
because the filesystem is case-insensitive and the two paths are the same directory. Caught by
re-listing rather than by trusting the exit code. The check itself was never fooled — it compares the
declaration against the name on disk, and got `day01` vs `Day01` right on the first run.
