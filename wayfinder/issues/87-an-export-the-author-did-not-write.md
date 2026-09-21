# 87 — May an emitted module export a function the author did not write?

Type: grilling
Status: claimed — [ENG-398](https://linear.app/davewil/issue/ENG-398). Raised 2026-09-21 out of
[ENG-397](https://linear.app/davewil/issue/ENG-397), which the F54 build
([F54](../../compiler/features/F54-to-existing-atom.md), [ENG-294](https://linear.app/davewil/issue/ENG-294))
filed on finding ticket 10 §6.2's obligation decided and undischarged
Blocked by: —

## Why this is raised

[10](10-atoms-in-a-csharp-skin.md) §6.2 decided the obligation on 2026-08-12: *every atom
appearing in a type position must be emitted into the module's atom chunk*, because the language's
types are erased aliases and `ToExistingAtom` asks the atom table. [13](13-compilation-target-decision.md)
gave it a home, *"the Abstract Format path gives the compiler a place to add the forms that do
it"*, and named no form. Nothing in `bs_emit` discharges it. F54 shipped `ToExistingAtom` on
2026-09-21, the first construct that can tell, and LANGUAGE.md §10 says so under *"One thing it
cannot yet promise."*

This ticket is not a doubt about the obligation. It is the one thing ENG-397 could not settle:
every mechanism that discharges it changes what an emitted module looks like from outside, and
which change is acceptable is a decision about the module's surface, not about codegen.

**The inspector ENG-397 and ticket 10 used cannot see the answer.** Both read
`beam_lib:chunks(Beam, [atoms])`. Measured 2026-09-21 on OTP 29 with an inspector that builds the
probe names from strings at run time and never spells them: that chunk holds neither probe atom
under *any* mechanism, including the two that work, because a literal list goes into the literal
chunk and its atoms are interned when the loader decodes it. The honest oracle is the one F54's
suite already has, `in_fresh_vm/3`: a VM that never compiled the module, asked to resolve the name.

| mechanism | fresh VM resolves | why |
| -- | -- | -- |
| the atom in a `-type` / `-spec` only | no | ticket 10's finding; specs are documentation |
| a module attribute holding the list | no | attributes are a `term_to_binary` blob, decoded on request, never on load |
| an unexported function returning the list | no | unreachable, so removed with its literal |
| **an exported function returning the list** | **yes** | an exported body is always emitted |
| `-on_load`, the list bound and unused | no | the optimizer drops a pure unused expression |
| `-on_load`, `length(List)` matched | no | `length` of a literal is folded to `2` at compile time |
| `-on_load`, `erlang:phash2(List)` discarded | yes | `phash2` is not folded — today |

So there are two mechanisms, and one of them works by luck.

## The program

ENG-397's own, unchanged. A module whose type names an atom no clause head or expression spells:

```csharp
module Modes

type Mode = :fast | :slow

public list<Mode> Known()
Known() -> []

public result<atom, string> Resolve(string name)
Resolve(name) -> ToExistingAtom(name)
```

Compiles at `551c805`, and in a VM that loads `Modes.beam` without having compiled it,
`Resolve("fast")` is `(:error, "fast")`. The type says `:fast` is a `Mode`; the runtime says
there is no such atom.

## Q1 — May an emitted module export a function the author did not write?

One question, and it is about the module's **export list**, which is the only place the two
working mechanisms differ.

**If yes**, every emitted module carries one more export, `'bs@type_atoms'/0`, returning the
module's type-position atoms as a literal:

```erlang
-module('Modes').
-export(['Known'/0, 'Resolve'/1, 'bs@type_atoms'/0]).

'bs@type_atoms'() -> [fast, slow].

'Known'() -> [].
'Resolve'(Name) -> ... binary_to_existing_atom ...
```

What changes from outside: `'Modes':module_info(exports)` lists a function the author did not
write, and so does every tool that reads the export list — xref, dialyzer, Elixir's `exports/1`,
an IEx tab-complete on `:Modes.`. It is not spellable from B#: `@` is not in the identifier
grammar, and `bs@` is already the prefix `bs_lower` and `bs_emit` reserve for names the source
cannot collide with. `bsc --api Modes` is unchanged, because it reads the source, not the beam.

**If no**, the export list stays the author's and every emitted module carries an `-on_load`
hook instead:

```erlang
-module('Modes').
-export(['Known'/0, 'Resolve'/1]).
-on_load('bs@load'/0).

'bs@load'() -> _ = erlang:phash2([fast, slow]), ok.
```

What changes from outside: nothing in the export list, and everything about loading. An
`on_load` function runs on every load of the module, in a process the loader spawns, with
callers of the module suspended until it returns `ok`. And it is refused where a release is
upgraded: measured 2026-09-21,

```
code:atomic_load(['Modes'])   %% with 'bs@type_atoms'/0 exported
ok
code:atomic_load(['Modes'])   %% with -on_load
{error, [{'Modes', on_load_not_allowed}]}
```

Every B# module would be a module the platform will not load atomically, which is a cost paid
by an author who never wrote `ToExistingAtom`. And the literal survives only because `phash2` is
a call the optimizer does not evaluate: the day it does, every module silently loses its atoms
again, and the fresh-VM test is the only thing that would notice.

➡️ **Recommended: yes.** The export is the mechanism ticket 13 pointed at, a form added on the
Abstract Format path; it rests on a stated contract, that an exported function's body is
emitted, where the alternative rests on which BIFs `sys_core_fold` happens not to evaluate; it
loads everywhere the author's own functions load; and the thing it exposes is honest, the atoms
this module's types name, readable by anyone who asks the module. LANGUAGE.md §12's sentence,
*"Function names are exported PascalCase, exactly as written"*, stays true of the author's
names; it gains a second sentence saying the compiler's own exports wear `bs@` and are not for
calling.

### The compiler delta under yes

* `bs_emit:forms/1`: one more `{F, A}` in the export attribute, and one function form,
  `'bs@type_atoms'/0` returning `{nil | cons}` of `{atom, _, A}` for the sorted set.
* The set: walk the same resolved types `rec_type_attrs/2` at `bs_emit.erl:1406` already walks
  for the module's `-type` attributes (every parameter and return of every function, after
  `bs_check_resolve`, so an imported or named type is expanded), plus every type the module
  declares, through `bs_types:components/1`, collecting each finite atom part. Post-expansion is
  the reading §6.2 asks for: a `Mode` that came in through `using Kinds` is a type position of
  *this* module, and this module is the one a fresh VM may load alone.
* Emitted in every module, an empty list included, so the surface is one shape.
* The test: F54's `a_type_only_atom_resolves_in_a_vm_that_did_not_compile_it_test`, whose source
  is in ENG-397, goes back; its inspector is `in_fresh_vm/3`, never `beam_lib`.
* LANGUAGE.md §10 loses *"One thing it cannot yet promise"*; §12 gains the `bs@` sentence.

Under no, the same walk and the same test, with an `-on_load` attribute and `'bs@load'/0` in
place of the export, plus a `check-*.sh` probe that a fresh VM still resolves after every OTP
bump, since the mechanism's correctness is not the compiler's to promise.

<!-- Round 1, asked 2026-09-21. -->

## Not decided here

- **A third mechanism that is neither.** None was found: the loader interns atoms only from
  code it keeps, and the compiler keeps a body only when something exported reaches it. An
  `on_load` is "something exported" by another name, with the loading semantics above.
- **Whether `bs@` is a reserved prefix in the emitted module's export list.** That is
  [65](65-reserved-names-policy.md)'s policy ([ENG-255](https://linear.app/davewil/issue/ENG-255)),
  which this answer hands one entry: under yes, no author function may emit as `bs@…`, which the
  PascalCase rule already guarantees.
- **Leaving the gap.** LANGUAGE.md §10 says it today. Keeping it is ticket 10 §6.2 overturned,
  not a third answer to this question, and nothing measured here argues for it.
- **An atom named only by a type of a module that is never loaded.** No mechanism reaches it;
  the obligation is per module and was always so.
