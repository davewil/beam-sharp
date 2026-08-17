# F15 — A module is a directory: aggregation, `index.bs`, and the two path checks

**Status**      **claimed 2026-08-17** · [ENG-221](https://linear.app/davewil/issue/ENG-221)
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
deciding anything. Default is the current directory. The module path is the dirname taken relative
to the root, segments joined with `.`.

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
| F15.11 | the whole `examples/` corpus after the rewrite | every module compiles and runs; the examples gate loops over **directories** | 0 |

## The corpus rewrite is a scenario, not cleanup

F15 cannot compile its own corpus without it, and the reason is sharper than "30 files move":

- `examples/` holds **eleven flat files declaring eleven distinct modules**. Under the aggregate
  rule that directory is *one* module. Every one of them has to become its own directory.
- `examples/collections/` holds `List.bs` (`module Shop.Collections.List`) and `Totals.bs`
  (`module Shop.Reports`) — **two modules in one directory, already illegal** under the rule this
  feature builds. F11 shipped it because nothing yet said it was wrong. F15.4 is that check.

This is the F12 shape the features README flagged and the F8 precedent it cites: a whole-corpus
rewrite is its own increment, done deliberately with an id, not a diff that rides along behind the
checks.

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

## A wording drift for the map, not a decision for this feature

Ticket 41 §5 and §4 disagree about whether `index.bs` is **mandatory**:

- §5's operative rule, stated as the classification test: *"a directory containing `.bs` files is a
  module"*.
- §4, arguing for keeping `index.bs` function-free: *"`index.bs` is unambiguously the declaration
  file and **its presence is the module marker**"*.

F15 builds §5's version — `.bs` files present ⇒ module — because that is the one written as the
test, and F15.10 pins it. **This feature does not settle the other**; it is recorded here so the map
can, and so a later reader does not take F15's choice for a decision it never made.

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

`bsc --src-root examples Shop/Orders` compiles a multi-file directory into one `.beam` whose
functions report crashes against their own source files; both owed checks fire with the specified
tuples; the whole `examples/` corpus is rewritten into directories and compiles and runs; and every
gate stays green with the examples step looping over directories.

**And the REPL must be exercised by hand — again.** F11's own "Done when" records that `bs_repl`
appears zero times in the suite and that five features in a row found a hole at the `ibs` prompt.
A REPL whose unit of compilation has just become a **directory** is exactly the shape that
under-serves a single-file prompt, and F11 was the first of the five not to find it broken. `ibs -S`
against an aggregate module is a manual check this feature owes before it is done.
