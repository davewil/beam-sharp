# F55 — every type-position atom in the chunk

**Status**      **done 2026-09-21** — 4 tests in
                `to_existing_atom_tests` (23 there now, up from 19), one in
                `repl_tests`, one in `cli_tests`; the first was the test F54
                wrote, saw red, and withdrew, and it was red again on this tree
                before the emitter changed; the fourth was red before the
                review's two gaps were closed. Five older tests that assumed a
                module holds only the author's functions were re-pointed. No
                new gate: the property is visible only to a VM that never
                compiled the module, which no `check-*.sh` spawns and the suite
                does. `./bin/verify.sh` green **twice from a clean clone** of
                `35dccac`, the evidence dated at the end of this file
**Implements**  [ticket 10](../../wayfinder/issues/10-atoms-in-a-csharp-skin.md)
                §6.2, the obligation, landed on
                [ticket 13](../../wayfinder/issues/13-compilation-target-decision.md)
                as a form on the Abstract Format path; and
                [ticket 87](../../wayfinder/issues/87-an-export-the-author-did-not-write.md),
                which chose the form
**Closes**      [ENG-397](https://linear.app/davewil/issue/ENG-397), which F54
                raised on 2026-09-21 and ticket 87 resolved the same day
**Decides**     nothing. §F55.4 says how ticket 87's *"every type the module
                declares"* is read, and it is the widest reading
**Depends on**  F54, whose `in_fresh_vm/3` is the only inspector that can see
                this; F28, whose type walk this reuses

## What was there

Ticket 10 §6.2 decided on 2026-08-12 that every atom appearing in a type
position must reach the emitted module's chunk, because the language's types
are erased aliases and `ToExistingAtom` asks the atom table. Ticket 13 gave the
obligation a home and named no form. Nothing in `bs_emit` discharged it, and
nothing could tell until F54 built `ToExistingAtom`: its fresh-VM test for a
type-only atom was written, seen red, and withdrawn when the discharge turned
out to need a decision about the module's surface. Ticket 87 asked one question
and David answered *yes*: an emitted module may export a function the author
did not write.

## The program

ENG-397's own, unchanged:

```csharp
module Modes

type Mode = :fast | :slow

public list<Mode> Known()
Known() -> []

public result<atom, string> Resolve(string name)
Resolve(name) -> ToExistingAtom(name)
```

Before this feature, a VM that loaded `Modes.beam` without having compiled it
answered `Resolve("fast")` with `(:error, "fast")`. Now it answers `:fast`.

## What it compiles to

One more export and one more function on every module:

```erlang
-module('Modes').
-export(['Known'/0, 'Resolve'/1, 'bs@type_atoms'/0]).

'bs@type_atoms'() -> [error, fast, slow].
```

`error` is there because `result<atom, string>` is `atom | (:error, string)`
and the tuple's tag is an atom in a type position too; `atom` itself is the
cofinite top and names nothing. The list is sorted, and it is `[]` on a module
whose types name no atom, so the surface is one shape.

**Why an exported function and nothing else.** An exported body is always
emitted, and a literal's atoms are interned when the module loads. Ticket 87
measured the alternatives in a fresh VM: an attribute is a blob decoded only on
request; an unexported function is removed as unreachable; `-on_load` keeps the
atoms only while its touching call is one the optimizer does not fold
(`erlang:phash2` yes, `length` no, an unused binding no), and `code:atomic_load`
refuses any module carrying it with `on_load_not_allowed`.

## The compiler delta

| Site | What |
|---|---|
| `bs_check:check_dir1/3` | the result map gains `declared_types`, every type the module declares as a resolved type — an alias body under `opaque_env/2`, a refinement and a record by name — and `type_vars`, the alias variables' names. `declared_types/2` beside `declared_type_names/1` |
| `bs_emit:signature_types/2` | every parameter and return of every function under `fn_env/2`, resolved once; `rec_type_attrs/2` reads it for the `-type` attributes and `type_atoms_form/4` for the chunk, so what counts as a signature type is decided in one place |
| `bs_emit:forms/1` | `{'bs@type_atoms', 0}` appended to the export attribute; `type_atoms_form/4` after `rec_type_attrs/2` |
| `bs_emit:type_atoms_form/4` | the signature types plus the declared types; `collect_atoms/2` walks them as `collect_mu/2` does, taking each atom part's named atoms (finite members and cofinite exclusions alike) **and each map member's keys**; the alias variables' atoms are subtracted; `atom_list/1` writes the literal |
| `bs_run:authors_exports/1` | the export list minus `module_info` and `bs@…`, exported; `resolve_and_call/2` reads it, so naming the compiler's export at the command line finds no such function |
| `bs_repl:exports/1` | the banner reads `bs_run:authors_exports/1` rather than restating it, and so does `visibility_tests` |

## F55.1 — a type-only atom resolves in a VM that did not compile it

F54's withdrawn test, verbatim: `Widget` gains `type Mode = :zzz_type_only_mode
| :zzz_other_mode` and `public list<Mode> Modes()`, neither member appears in
any clause head or expression, the beam is copied to a directory of its own,
and a spawned VM resolves both. **Seen red first** on this tree: the spawned VM
printed `{error,<<"zzz_type_only_mode">>}`.

## F55.2 — the export is on every module, and it is the type positions' atoms

In-process, since this is about the emitted surface and not the chunk:
`Widget:'bs@type_atoms'()` is `[error, zzz_other_mode, zzz_type_only_mode]`,
and a module whose one signature is `int -> int` answers `[]`.

## F55.3 — an imported type's members reach the importing module

`Kinds` declares `type Mode = :zzz_kind_fast | :zzz_kind_slow`; `Uses` says
`using Kinds` and names `Mode` in a signature, spelling neither member as a
value. Both modules compile through the CLI with `--src-root`; **`Uses.beam`
alone** is copied to a fresh directory and a spawned VM resolves both members
through it. This is ticket 87's post-expansion reading measured: the type came
in through `using`, it is a type position of `Uses`, and `Uses` is the module
a fresh VM may load alone.

## F55.4 — the set: keys count, and a parametric alias is walked opaque

Ticket 87's delta says *"plus every type the module declares"*, and the first
cut of this feature read it narrowly twice. The review caught both, and the
fourth test was red on each before the walk changed.

**Keys are atoms a type names.** `bs_types:components/1` yields the types a
type *holds* — a map member's field values, a domain's key and value types —
and never a field's name, because a name is not a type. A record's field
names and its minted `Kind` are nonetheless atoms in a type position, and a
module that declares `record Point { X: int }` and never constructs one has
`'X'`, `'Kind'` and `'Decl.Point'` in its chunk.

**A parametric alias has literals of its own.** `type Tagged<T> = :zzz_tagged
| T` names an atom whether or not any signature applies it. The bare name
cannot be resolved (`needs_type_args`), and erasing `T` to `term` — the
review's first suggestion — does not work either: `:zzz_tagged | term` is the
top, and the literal is absorbed. So the alias body is resolved under the
checker's **opaque** binding, each variable a singleton atom spelled as the
variable, which keeps every literal beside it; the variables' own atoms then
come out of the set. The one cost is an author who names an atom exactly as
an alias names a variable, `:T` beside `type Box<T>`, which loses `:T`;
variables are single capitals by convention and atoms are not.

Signatures are walked after `bs_check_resolve/2`, which is what makes the set
the *expanded* one: `list<Mode>` contributes `Mode`'s members, and a prelude
alias such as `result<T, E>` contributes its `error` tag.

## F55.5 — the runner and the REPL do not offer it

Two readers of `module_info(exports)` existed before this feature, and both
filtered `module_info` alone. Each now also filters `bs@`. `bsc modes.bs
bs@type_atoms` exits non-zero and prints no atom (before the filter it printed
the list and exited 0); the REPL banner is silent on `bs@`. Asserted at both
seams, because the banner is the one place the prompt *shows* what may be
called.

## F55.6 — what the review found, and what was kept

`/code-review` ran on the working tree before the commit and returned six
findings, all upheld. Two were real gaps in the set (§F55.4). One was the
Status line claiming the clean pair before it had run; it now says the pair
is owed until the commit that appends it. Three were duplication: the
signature walk copied from `rec_type_attrs/2` (now `signature_types/2`, read
by both); the "author's exports" filter written in the runner, the REPL and
the visibility tests (now `bs_run:authors_exports/1`, read by all three); and
the two abstract-code tests whose by-name selector had dropped the invariant
that a plain module holds no other function form (now an exact set, naming
the one compiler-added form).

## Out of scope

* **A roster row and a tour section.** The roster in `corpus_tests` lists
  surface the corpus demonstrates; this feature adds no surface a `.bs` file
  can spell. The tour's *decided but not built* table loses its row instead.
* **Whether `bs@` is a reserved export prefix**, and whether a module name
  may shadow an OTP module's — both ticket 65's, which ticket 87 handed one
  entry.
* **An atom named only by a type of a module that is never loaded.** No
  mechanism reaches it; the obligation is per module and was always so.

## Done when

`a_type_only_atom_resolves_in_a_vm_that_did_not_compile_it_test` is green on
the tree, and LANGUAGE.md §10 no longer says *"One thing it cannot yet
promise"*. Both hold.

## Verified — 2026-09-21, at `35dccac`

`./bin/verify.sh && ./bin/verify.sh` from one fresh `git clone` checked out at
`35dccac`, the two runs sequential, on the Omarchy box with `/usr/bin/core_perl`
on the mise path (Arch keeps Perl's `shasum` there, off the default path, and
`check-tour.sh` part 4 cannot run without it — a machine gap closed in the
machine's mise config, not in the repository):

```
run 1   All 46 stages passed (elapsed: 688s)
run 2   All 46 stages passed (elapsed: 666s)
```

Stage 11, the tour gate, passed on both (28 s, 29 s). The full eunit suite in
the working tree before the commit: 1056 passed, 0 failed — after one run in
which `the_diagnostics_gate_passes_test` timed out at eunit's 5-second default
while two document gates ran beside it, and passed alone in 3.4 s. The pair
measures `35dccac` and nothing after it; the commit carrying this section adds
only the text you are reading and the two status lines it turns to done.
