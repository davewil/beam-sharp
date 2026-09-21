# F54 — `ToExistingAtom`: a string to an atom the VM already has

**Status**      **done 2026-09-21** — 19 tests in `to_existing_atom_tests`, 1050 in
                the suite, up from 1033 (one test and one prose case left
                `validate_as_tests`, which were asserting that this feature did
                not exist). No new gate: `check-status-claims.sh` gained the
                ledger row and `check-language.sh` a must-compile block and a
                `diagnoses:` block, all three seen red on the tree first;
                `examples/Names`, one roster row and the tour section it
                obliges. `./bin/verify.sh` green **twice from a clean clone**,
                the evidence dated at the end of this file
**Implements**  [ticket 10](../../wayfinder/issues/10-atoms-in-a-csharp-skin.md)
                §4, the second of the two names it left, with the return
                [ticket 67](../../wayfinder/issues/67-stdlib-shape-as-a-principle.md)
                chose on 2026-09-03: `result<atom, string>`
**Closes**      [ENG-294](https://linear.app/davewil/issue/ENG-294), whose
                `ParseAtom<T>` half was F39
**Decides**     two things the record left: **the call is written bare**, and
                **the argument is a `string`**. See §F54.6 and §F54.5 — both are
                refusals, and they are the only places this feature chose rather
                than implemented
**Raises**      [ENG-397](https://linear.app/davewil/issue/ENG-397) — ticket 10
                §6.2's atom-chunk obligation, decided and unbuilt, which this is
                the first construct that can expose. See §F54.3. **Decided the
                same day as ticket 87 and built as F55**
**Depends on**  F18, which established that a codegen obligation is not a call;
                F39, whose inline lowering this follows; F25, whose corrected
                signature offers the failure member back; F31, whose refusal of
                `option<atom>` is why the result has the shape it has

## What was there

Ticket 10 §4 decided this name on 2026-08-12 as `atom | :nothing`. Ticket 15 §1
made that shape an error at the declaration the same day: the singleton is
absorbed into the cofinite top, so `atom | :nothing` *is* `atom` and the failure
channel does not survive. Ticket 67 respelled it on 2026-09-03 —
`result<atom, string>`, the reason being the name that resolved to nothing —
and nothing built it. The compiler knew the name (`codegen_obligations/0` has
carried it since F18) and refused it:

```
error: Go uses ToExistingAtom, which is decided and not built yet
```

**That refusal was the failing test**, and flipping it is what this feature is.
Five shipping documents still called the respelling *owed* when this build
began, eighteen days after 67 chose it; each is corrected in place, dated.

## The program

```csharp
module Names

using :erlang {
    term whereis(atom name)
}

public result<atom, string> Resolve(string name)

Resolve(name) -> ToExistingAtom(name)

public bool Registered(string name)

Registered(name) -> Resolve(name) switch {
    (:error, _) => false,
    a           => :erlang.whereis(a) switch {
        :undefined => false,
        _          => true
    }
}
```

`Resolve("init")` is `:init`; `Resolve("zzz_no_such_name")` is
`(:error, "zzz_no_such_name")`, and the table is one atom no larger.

## What it compiles to

Inline, at the site, as `ParseAtom<T>` is: the whole body is one lookup and
there is nothing to share between two sites.

```erlang
case Name of
    Bs@ea0 ->
        try erlang:binary_to_existing_atom(Bs@ea0, utf8)
        catch error:badarg -> {error, Bs@ea0}
        end
end
```

The argument is bound **once**, and the `try` encloses **only the BIF**. Wrapping
the argument's own evaluation would report a crash computing the name as "no
atom has that name"; evaluating it twice would run its side effects twice. The
variable takes the foreign wrapper's counter so a second site in the same
function cannot collide with it.

## The compiler delta

| Site | What |
|---|---|
| `bs_check:type_of/3` | a clause for `{e_call, _, 'ToExistingAtom', Args}`, above the generic local call, and one for `{e_inst, _, 'ToExistingAtom', TypeArgs, Args}`, above the catch-all that produced `obligation_unbuilt`. Both go to `to_existing_atom/5` |
| `bs_check:to_existing_atom/5` | one value, no type argument; the argument a subtype of `string`; answers `atom | (:error, string)` |
| `bs_check:compiler_known_function/1` | a user function named `ToExistingAtom` is refused at the declaration — called from **both** `check_dir1/3` and `exports_of/2` |
| `bs_check:built_obligations/0` | all four; `codegen_obligations/0` is now exported, for `bs_diag` |
| `bs_emit:expr/2` | a clause for the bare call, emitting the `case` and `try` above |
| `bs_diag` | `to_existing_atom_arg` and `compiler_known_function`; `obligation_arity` has a sentence of its own for this name; `not_an_obligation` reads its roster from the checker |

`codegen_obligations/0` is **unchanged**, as F39 left it: the set is closed by
ticket 28 and building a name does not alter it. The grammar is untouched —
`ToExistingAtom(name)` was always a `call`, and the bracket production was
always admitted after the name; what changed is what the checker does with each.

## F54.1 — the decided case

An atom the VM has comes back as that atom. `ok` and `true` exist in every VM,
so nothing about the test depends on who minted them.

## F54.2 — a name no atom has: the error carries the name, and nothing is minted

`(:error, name)`, the name byte for byte — a non-ASCII name is the case that
would show a re-encoding, since both BIFs speak UTF-8 and a latin-1 detour would
not. And the property ticket 10 §4 named the long spelling for:

```erlang
Before = erlang:system_info(atom_count),
?assertEqual({error, Name}, M:'Resolve'(Name)),
?assertEqual(Before, erlang:system_info(atom_count)),
?assertError(badarg, binary_to_existing_atom(Name, utf8)).
```

## F54.3 — in a VM that did not compile it

**The in-process tests cannot see the trap this feature turns on.**
`build_and_load` compiles in the test VM, and the compiler interns every atom
the source spells the moment it lexes `:widget` — so in-process,
`ToExistingAtom("widget")` succeeds because the *compiler* minted the atom,
whatever the emitted module carries. `bsc Module Fn arg` has the same shape,
one VM compiling then running.

So one test spawns a VM that only loads the `.beam` and asks it. An atom in
value position resolves there, and a name spelled nowhere does not — the absent
control is what shows the fresh VM is not this one.

**The test that was written, seen red, and taken out.** An atom appearing
*only* in a type — `type Mode = :fast | :slow` with no clause head or expression
spelling either — is absent from the emitted module's atom chunk, so a fresh VM
answers `(:error, "fast")` for a member the declared type says is legal. That is
the sentence ticket 10 §6.2 wrote, and its obligation (*"emit every
type-position atom into the module's atom chunk"*, landed on ticket 13) is
decided and unbuilt. Two mechanisms were measured, each with an inspector that
never spells the probe atom, after a first measurement contaminated by its own
inspector said the opposite of both:

| mechanism | in the chunk? |
|---|---|
| a module attribute, `-bs_type_atoms([fast, slow]).` | **no** — an attribute is a `term_to_binary` blob; its atoms are minted only when something decodes it |
| an unexported function returning the list, warning silenced | **no** — the compiler removes an unreachable local function, and the literal with it |

The two that would work — an **exported** `'bs@type_atoms'/0`, or an `-on_load`
function that touches the list — each change the emitted module's surface
(LANGUAGE.md §12's *"exported PascalCase, exactly as written"*; a load hook on
every module), which is a decision no ticket has made. So the discharge is
[ENG-397](https://linear.app/davewil/issue/ENG-397), the language reference
says under `ToExistingAtom` what it cannot yet promise, and the fresh-VM
harness (`in_fresh_vm/3`) is in the suite for the build that closes it.

**A second finding from the same harness, not filed.** The first test module
was named `Peer`, and its `Peer.beam` on the test VM's path made the *spawned*
VM die at boot: `beam_load.c: module name in object code is 'Peer'` — on a
case-insensitive disk it shadows OTP's `peer`, exactly as the stray `Json.beam`
did in ENG-391. Renamed. Whether a B# module name that collides
case-insensitively with an OTP module should be refused is ticket 65's
reserved-names policy, which is open.

## F54.4 — the declared return must admit the failure member

A signature promising bare `atom` is a narrowing the checker refuses, and F25's
correction offers `(:error, string)` back. The test names `return_not_declared`
deliberately, as F39.5 did: while this name was unbuilt the same source was
refused too, as `obligation_unbuilt`, so a test asserting merely "some error"
passed before the feature existed.

## F54.5 — the argument is a `string`, and this was a choice

**This is where the sibling's rule does not carry over.** `ParseAtom<T>` admits
a `binary` (F39.7) because the argument goes nowhere: it is matched and dropped.
Here it flows *into* the result — the failure carries the name as a `string` —
and a `binary` that is not valid UTF-8 is not one. The BIF agrees:
`binary_to_existing_atom(<<255>>, utf8)` is `badarg`, the same failure a missing
name raises, so admitting `binary` would make two failures one and hand the
author `(:error, name)` for a value that was never a name.

So `term`, `int` and `binary` are each refused with `to_existing_atom_arg`, and
the message names the way from each to a `string`: a `term` from a boundary is
matched into one; a wire `binary` becomes one through `ValidateAs<string>`.

It is a refusal, so relaxing it later breaks nothing that compiles today. That
is the only reason it was safe to decide here rather than to raise a ticket.

## F54.6 — the construct's shape, and the call is written bare

**The record contradicted itself on the spelling, and this feature read it the
way the programs do.** Ticket 28 §1 says *"`ValidateAs`, `ParseAtom` and
`ToExistingAtom` always [write a type argument]"*, and the grammar comment and
LANGUAGE.md repeated it. But ticket 10 §4's own program writes
`ToExistingAtom(input)`, ticket 18 writes `ToExistingAtom(string) -> …`, and
ticket 67's resolving program — the one that chose the return — writes
`ToExistingAtom(name)`. None of them had a `T` to write, because the result is
fixed. The bare call is what three tickets' programs spell; 28's sentence was
written about the three names generically, before this one had a signature to
check it against. Both of 28's lines are corrected in place, dated.

**The name stays in ticket 28's closed set**, so `<` after it still opens a
bracket rather than reading as a comparison — and what that bracket holds is
then refused, as `obligation_arity` with what was written: `<atom>(s)` is
`1, 1`; `()` is `0, 0`; `(s, s)` is `0, 2`. The message is this name's own,
because the shared one ends *"Write `Name<T>(x)`"* — which for this name is
advice to write the form the same compiler just refused, F19's shape and the
one `check-advice-compiles.sh` exists for.

**The cost if David reverses this.** The bracket form is what every program
would then have to change to; a refusal relaxes for free, a spelling does not.

**A user may not declare the name.** `type_of/3` meets `ToExistingAtom(s)`
before any callee is looked up, so a user's `ToExistingAtom/1` would be
shadowed in silence. `compiler_known_function/1` refuses the declaration — the
rule `ValidationError` already had for a type — and it is wired at **both**
declaration passes, since `bsc --api` runs `exports_of/2` and never `check/2`:
F54.8 asserts the query answers status 1 with nothing on stdout. ENG-371's two
older refusals still have that gap; it was not widened here.

## F54.7 — the pipe form

`s |> ToExistingAtom()` runs, as F39.6 established for the bracket forms. F14's
rewrite has to fill the first argument for a bare compiler-known call and not
only for the forms it was measured on, so it is a running program rather than a
grammar fact.

## F54.9 — reading the result

A `switch` with `(:error, _)` and a binder is exhaustive: the residual after
the tuple arm is `atom`, which the binder takes whole. `Registered` in the
example is the same shape one level deeper.

## F54.10 — the sentences, as the author receives them

Four prose cases drive `bsc` as a subprocess, for the reason `validate_as_tests`
states: `check-diagnostics.sh` compares tag *sets*, so a `message/1` clause that
never dispatches leaves the gate green and the author holding a map. The
`obligation_arity` case asserts *"no type argument and one value"*; the
`not_an_obligation` case asserts the roster names all four — because
`bs_diag`'s hand-written roster named **three** for six days after F50 made it
four, and this is the sentence that would have kept saying so.

## Still owed

* ~~**Every type-position atom in the chunk** — ticket 10 §6.2, decided and
  unbuilt: [ENG-397](https://linear.app/davewil/issue/ENG-397), with the two
  mechanisms that would discharge it and why each is a decision. The fresh-VM
  test is in that issue's text, ready to put back.~~ **Built 2026-09-21 as
  [F55](F55-type-atoms-in-the-chunk.md)**, after ticket 87 chose the exported
  function. That build also found the table in §F54.3 was read through the
  wrong inspector: `beam_lib`'s atom chunk holds neither atom under *any*
  mechanism, the two that work included, because a literal's atoms are
  interned at load from the literal chunk. The rows are true; the column
  heading "in the chunk?" was the wrong question, and only a fresh VM answers
  the right one.
* **`obligation_unbuilt` is dead.** All four names in the closed set are built,
  so the branch that tells "wait for us" from "never going to work" is
  unreachable until a fifth obligation is decided. The clause stays; deleting it
  touches the term surface for nothing.
* **A module name that shadows an OTP module** on a case-insensitive disk —
  ticket 65's policy, not this feature's.

## Verified — 2026-09-21, at `06ec9d0`

`./bin/verify.sh && ./bin/verify.sh` from one fresh `git clone` of `06ec9d0`,
the two runs sequential because two clean runs started together race on the
per-user tree-sitter grammar cache:

```
run 1   All 46 stages passed (elapsed: 296s)
run 2   All 46 stages passed (elapsed: 288s)
```

Stage 11, the tour gate that has raced red on a fresh clone before, passed on
both. The `/code-review` that ran beside the pair found no hard standards
violation and no spec defect; its four judgement calls are recorded here so
they are not lost: this section, which the Status line promised before it
existed; `compiler_known_function/1` naming its one name rather than reading a
registry, kept because a registry of one is speculative; the comment style,
inherited from the sibling files; and `in_fresh_vm/3` concatenating a name into
a shell string, safe for the static literals it is handed. The pair measures
`06ec9d0` and nothing after it; the commit carrying this section adds only the
text you are reading.
