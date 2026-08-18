# F17 — `bsc --api <Module>`, the compiler query mode

**Status**      **done 2026-08-18**
**Implements**  [ticket 23](../../wayfinder/issues/23-what-the-language-owes-an-agent.md) §10 (the
                query mode itself), constrained by §11 (the compilation unit is the answer's
                boundary) and §12 (verbosity is not a virtue; the debt lives on the channel, not
                in the source). It draws on [40 §3](../../wayfinder/issues/40-module-and-namespace-system.md)
                for what "public" means and [41 §5](../../wayfinder/issues/41-imports-and-cross-module-scope.md)
                for the module atom. It **decides nothing** — 23 closed on 2026-08-13.
**Unblocks**    nothing that has a file. It is the other half of what an agent authoring against
                this language can ask the compiler, the first half being F16's diagnostic channel.
**Depends on**  [F16](F16-diagnostic-as-a-term.md) — the channel this answers on; F12 for
                `public`/`private`; F15 for the module-as-directory.

## Why this one now

**Because F16 built the channel and said so in its own last line.** 23 §10 is specified *on top of*
§1 — *"reads source and answers **on this channel**"* — and F16's file records the ordering
argument: building `--api` first would have meant inventing a provisional shape §1 then replaced,
or a second descriptor for the API path. The channel now exists, `bs_diag:emit/2` publishes on it,
and the one remaining thing 23 §10 needs is a producer.

**And the two answers that exist today are both inadequate, which is the ticket's own framing.**
The directory listing gives names without types. The built artefact — `module_info(exports)` plus
the `-spec` from the `abstract_code` chunk — requires a build and answers in **Erlang**, so the
consumer is handed `{ok, integer()}` where the language said `(:ok, int)` and has to invert the
lowering the compiler just did.

## The two facts that decided the whole design, and both were measured rather than chosen

**A signature's types resolve without a `World`.** `bs_check:exports_of/1` builds the type
environment from *this module's own declarations* and resolves each signature against it; it takes
no world and asks for none. `bs_check:check_dir/3` does — and `add_import/7` **raises**
`{unknown_module, M, L}` for any `using` line whose target is not already checked. So a full check
cannot answer for a module that imports anything without first checking its dependencies, and the
declaration pass answers for every module in the repo with no dependency work at all. That is what
makes 23 §10's *"with no build"* true rather than aspirational: nothing is compiled, nothing is
emitted, and no dependency is even read.

**A type name does not cross the module boundary.** `import_env/3` populates `funs`, `mods`,
`qual` and `privates` — and no table of types. `exports_of/1` hands a dependent the **resolved**
type, never the name the author wrote. So printing `Reply HandleCall(Request, term, int)` would
answer in a vocabulary the caller cannot use: `Request` and `Reply` are `Counter`'s private words.
The resolved form is the only thing that travels, so the resolved form is what `--api` prints.

Everything else follows from those two. `--api` reports **declarations**, resolved, and refuses
only on conditions that make the declarations themselves unreadable or untrue.

## Where the refusal line falls, and why it is not "does the module compile"

A module with an inexhaustive function still answers. Exhaustiveness is a property of the
**bodies**; the API is what the **signatures** declare, and 23 §7 is explicit that the compiler
under agent authorship is an interlocutor as well as a gate — withholding the answer exactly when
the module is half-written is the worst possible input to a feedback loop.

What *is* refused is anything that makes a declaration untrue:

| condition | why it refuses |
|---|---|
| a signature naming an unknown type | there is no type to report |
| `module_path_mismatch` (41 §5) | the **module atom** is part of the answer, and this module cannot be built under the atom it declares — reporting it would hand back a `using` line that can never resolve |
| a file that will not lex or parse | there are no declarations to read |

Each is reported through `bs_diag` with its existing descriptor and its existing prose. **No new
diagnostic tag is minted by this feature**, which is why `bin/check-diagnostics.sh` needed no
allowlist entry.

## The CLI spelling is not decided by the ticket, and this is the assumption

Ticket 23 names no flag for §10 any more than it did for §1 — it says only *"`bsc --api
<Module>`"*, which is the flag and nothing about its output. Taken here, F16-style:

- **`--api` takes a PATH**, exactly as every other `bsc` argument does: a module directory, or any
  file in one. F15 settled that naming a file names its module, so `<Module>` is satisfied by the
  spelling the CLI already has. Resolving a bare module *atom* (`bsc --api Shop.Reports`) is out
  of scope — see below.
- **The answer goes to stdout in whichever form the channel selects.** The existing selector
  governs it: `--diagnostics prose` (the default) prints signature lines, `--diagnostics term`
  prints one descriptor map per line. The internal name of that setting is already **`channel`**
  (`bs_diag:set_channel/1`), and §1 says the CLI publishes both encodings of it, so a second
  selector would be a second answer to a question already answered.
- **The answer is printed once, not twice.** A diagnostic goes to both streams because a human is
  watching a build while a tool reads the term. An `--api` invocation has exactly one consumer, and
  duplicating its answer onto stderr would be noise.

## What is printed, and what is deliberately left out

```
$ bsc --api examples/Counter
module Counter
behaviour GenServer
(:reply, int, int) HandleCall(:get | (:add, int), term, int)
(:noreply, int) HandleCast(:reset | (:add, int), int)
(:ok, int) Init(int)
```

**The union members come out in the algebra's order, not the source's** —
`counter.bs` writes `(:add, int) | :reset`. That is not cosmetic and it is not a
defect either: the type is a set, the order it prints in is `bs_types`' own
normalisation, and a caller reading the answer is being told what is admissible
rather than what was typed.

**`term` stays `term`.** `bs_types:to_string/1` renders the top type as
`atom | int | tuple | list<term> | map | binary` — correct, longer, and telling
the caller less than the one word the language already has. `HandleCall`'s
`from` parameter is where this shows up, and 23 §12 keeps full weight on read
cost. The shortcut lives in `bs_api` rather than in `to_string/1`, because that
function is shared with every diagnostic and a residual is a set the author must
enumerate — there the expansion is exactly the point.

**Sorted by name then arity**, not in source order. A module is a directory (F15), so source order
is an artefact of how the author split the files; sorting makes the answer a function of the
module rather than of its layout.

**No `public` marker.** Every line is public by construction — F12 makes a private function not
part of the module's API — so the word carries no information, and §12 is explicit that a
generator's ability to emit something is not a reason to require it.

**No parameter names in the prose.** A caller supplies a *value*, not a name. The names are real
information about intent, so they are not discarded: they travel in the term, which is F16's split
exactly — the term is full fidelity and the prose is the lossy function of it.

**Nothing is truncated, anywhere.** `bsc.erl` and `F2-interval-refinements.md` both already
describe `--api` as *the full-fidelity channel* against ticket 43's three-case cap on printed
residuals. So `?RESIDUAL_CASES` and `bs_diag`'s capped joiner appear nowhere in `bs_api`: a record
expanding into a long field list is the correct answer, not a defect to cap.

## The term

One map per line, `~0p`, framed by the newline — F16's framing rule, which it learned by shipping
the un-framed version first. The first line describes the module and the rest describe its
operations, each tagged so a consumer dispatches rather than counts:

```erlang
#{tag => module,module => 'Counter',path => "examples/Counter",
  behaviours => ['GenServer'],operations => 3}
#{tag => operation,module => 'Counter',name => 'Init',arity => 1,
  file => "examples/Counter/counter.bs",line => 15,
  params => [#{name => seed,type => "int"}],result => "(:ok, int)"}
```

**`file` and `line` are on the operation, not on the module**, and that is 23 §11 in the small: the
compilation unit is a directory, so "which file declares this" is a question only the compiler can
answer cheaply and the consumer cannot answer at all.

**Types travel as rendered strings**, which is F16's precedent rather than a new choice: its
descriptors carry `residual` and `heads` as strings joined from `bs_types:pattern_parts/1`. Here it
is `bs_types:to_string/1`, because a signature type is a **type** rather than a pattern to write.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F17.1 | `examples/Counter` | `bsc --api examples/Counter` | `module Counter`, `behaviour GenServer`, then one signature line per public operation, sorted | 0 |
| F17.2 | a module with a private function | `bsc --api …` | the private function is **absent**; the public ones are all there | 0 |
| F17.3 | a signature written in terms of a type alias | `bsc --api …` | the alias is **resolved** — a type name is module-local and means nothing to a caller | 0 |
| F17.4 | a signature taking a record | `bsc --api …` | the record's minted tag and its exact field set, as `bs_types` spells them | 0 |
| F17.5 | any module, into an empty output directory | `bsc --api … ; ls DIR` | **no `.beam` and no `.abstr`** — 23 §10's "with no build", asserted rather than assumed | 0 |
| F17.6 | a module split across several files, nested under a namespace | `bsc --src-root R --api R/A/B` | one aggregated answer, each operation carrying the file that declares it | 0 |
| F17.7 | the same module, **no** `--src-root` | `bsc --api R/A/B` | `module_path_mismatch` — the answer never describes a module that could not be built under the atom it declares | 1 |
| F17.8 | any module | `bsc --diagnostics term --api …` | one descriptor map per line: a `module` map then one `operation` map each, every line parsing back as a term | 0 |
| F17.9 | a module with no `public` signature | `bsc --api …` | `module X` and nothing else on stdout; stderr names the one word being asked for | 0 |
| F17.10 | a signature naming a type that does not exist | `bsc --api …` | the ordinary `unknown_type` diagnostic on the channel, and **no** answer | 1 |
| F17.11 | any module | `bsc --api PATH 5` | refused: `--api` answers about a module, it does not run one | 2 |
| F17.12 | a module with a `using` line, whose dependency is never named | `bsc --api …` | it answers — the declaration pass needs no `World`, which is why "no build" is true | 0 |
| F17.13 | a module with an inexhaustive function | `bsc --api …` | it answers — exhaustiveness is a property of the bodies, not of the API | 0 |

## Out of scope

- **Resolving a bare module atom** (`bsc --api Shop.Reports`). It is the nicer spelling for an
  agent that knows the atom and not the layout, and it needs `bsc:source_index/2` — a private
  function whose job is exactly this and which must not be reimplemented, because *a
  classification rule with two implementations has two answers*. What the deferred option needs:
  `source_index/2` exported, and a decision about what the default root is when `--src-root` is
  absent (the compile path's default is the module directory's own parent, which cannot work for
  a lookup that has no directory yet).
- **The lowered Erlang names.** `HandleCall/3` is what the language calls it; `handle_call/3` is
  what the BEAM calls it. 23 §10's complaint about the built artefact is that it *answers in
  Erlang*, so reporting the lowered name here would reintroduce the defect the mode exists to fix.
- **Type and record declarations as their own entries.** They are module-local names (see above),
  and their content is already carried in resolved form by every signature that uses them.
- **23 §5's JSON encoding**, still blocked on ticket 16 §4's serialisation mapping. This feature
  makes it look closer than it is: an API listing is the most JSON-shaped thing the compiler has
  produced, and the reason not to is unchanged.
- **`defended` (23 §3)**, which does not exist, and **23 §7's stub marker**, which is ticket 22's
  spelling question and deferred. `--api` reports only what the compiler knows, per §12.
- **Type and record declarations of a module you are about to depend on.** The same fact that
  decided the output shape — a type name does not cross the module boundary — means there is no
  answer to give here yet, rather than an answer this feature declined to give.

## Done when

`bsc --api` answers for every module in `examples/` without compiling anything, in beam-sharp's
vocabulary, with private functions absent and type names resolved; the same answer is available as
one descriptor map per line under `--diagnostics term`; every scenario above is asserted by a test
that drives the built escript with **no silent skip**; and all twelve gates are green.

## Done — what it took, and the thing the measurement changed

**Built 2026-08-18.** `bsc --api examples/Counter` prints three operations with their types
resolved and nothing built; the term channel publishes the same answer as one map per line; the
suite is **358**, up 24, and all twelve gates are green.

**THE DESIGN WAS DECIDED BY TWO GREPS, AND THE FIRST ONE REVERSED THE PLAN.** The obvious
implementation of a query mode is *check the module and report what the checker produced*, and it
is wrong here for a reason nothing in ticket 23 predicts: `bs_check:check_dir/3` raises
`unknown_module` for any `using` line it cannot resolve, so the full-check design answers for a
leaf module and **fails for exactly the modules worth querying** — the ones with dependencies.
`bs_check:exports_of/1` has no such coupling. That is not a preference between two designs; one of
them does not work, and the difference is invisible until it meets a module with an import.
`a_module_with_imports_answers_without_its_dependencies_test` is that case, and it asserts both
halves: the query answers, and the same module does not compile.

**THE SECOND GREP DECIDED THE OUTPUT.** `import_env/3` builds four tables and none of them holds a
type, so a dependent module has never once seen the name `Reply`. Printing declared type names
would have produced an answer that reads perfectly and cannot be acted on from outside the module —
which is 23 §2's own warning about approximations, one construct along: *output that reads as
actionable and silently is not*.

**AND `--src-root` HAD TO EARN ITS PLACE OR BE REFUSED.** F16 recorded that a flag accepted and not
honoured costs the flag its credibility everywhere else, and the first draft of this feature
accepted `--src-root` and did nothing with it, because signature resolution genuinely does not need
a root. What it *does* need a root for is the **module atom**: the answer names one, and 41 §5's
check is what makes that name true. So the path check runs, and F17.7 is the scenario that proves a
wrong answer is refused rather than printed.

**A `.bs` SUFFIX MAKES AN ARGUMENT A PATH WHETHER THE FILE EXISTS OR NOT, AND THAT ANSWERED THE
WRONG QUESTION.** `bsc --api /tmp/nope.bs` reported the API of `/tmp` — because `module_dir_of/1`
hands back the directory, and any directory with a stray `.bs` file in it is a module. Measured, not
theorised. An answer about a module nobody named is worse than a refusal, so a path that does not
exist is now an invocation error. The general shape is this repo's own recurring one: a rule that is
right for compiling (*naming a file names its module*) is right for querying too, right up to the
input the compile path never sees, because `file/2` checks `is_file/1` first and the query had no
equivalent.

**WHAT THIS FEATURE TOUCHED OUTSIDE ITS OWN MODULE IS ONE EXPORT LINE.** `bsc` now exports
`expected_module/2`, `parse_path/1` and `module_dir_of/1` beside `module_dirs/1` and `dir_kind/1`,
for the reason already written on those two: *a classification rule with two implementations has two
answers*. The module a path implies, the parse that publishes its own diagnostics, and "naming a
file names its module" are all rules `bsc` owns, and the query mode reads them rather than
reimplementing them. Every one of the three would have been between six and twenty lines to copy,
and each copy would have been a second answer waiting to drift.

