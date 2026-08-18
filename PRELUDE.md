# The prelude

**A census, not a decision.** Everything below is either already settled by a ticket — cited — or
named explicitly as a gap. Nothing here is invented to fill a hole. Written 2026-08-15 on David's
*"we need one of these"*, pointing at [Elixir's `Kernel`](https://elixir.hexdocs.pm/1.20.3/Kernel.html).

**Status vocabulary**, used on every row:

| | |
|---|---|
| **shipped** | decided *and* built — you can run it today |
| **decided** | a ticket settled it; the compiler does not have it yet |
| **owed** | decided, but a known defect in the spelling must be fixed first |
| **open** | genuinely undecided. Do not implement from this file |

---

## Why this is not Elixir's `Kernel`, and is much smaller

`Kernel` does three jobs. beam-sharp's design gives two of them away, and that is the single most
useful thing to know before reading the tables.

| `Kernel` does | beam-sharp |
|---|---|
| **Special forms and macros** — `def`, `if`, `unless`, `cond`, `case`, `\|>` | **Grammar, not prelude.** There are no macros, and `switch`, `\|>`, `\|?>` and `with` are syntax. Nothing here can be one of them |
| **Type-test guards** — `is_atom/1`, `is_integer/1`, `is_binary/1` | **Absent by design.** These exist because Elixir's runtime has no static types. Here the clause head plus the checker does that job — a prelude `is_integer` would be conceding the checker does not work |
| **Values and types** — data helpers, structs, `raise` | **This is the whole of the prelude**, and it is what the rest of this file describes |

So the closest analogue is not `Kernel` but **`Kernel.SpecialForms`**, which is what ticket 14 §6
actually modelled the stratification on.

---

## What ships today

**Two entries.** `bs_check:prelude/0` holds `option<T>` and `result<T, E>` and nothing else.
Everything else in stratum 1 below is decided-and-unbuilt, and the whole of stratum 2 is unbuilt.

---

## Stratum 1 — definitions a user could have written

Ordinary aliases. The compiler draws no special inference from them; they win no resolution
contest; they are in the prelude because you should not have to import them.

| Entry | Spelling | Status | Ticket |
|---|---|---|---|
| `bool` | `type bool = true \| false` | **decided** — and **built as a builtin instead**, see Drift | 10 |
| `option<T>` | `type option<T> = T \| :nothing` | **shipped** | 10 §5 |
| `result<T, E>` | `type result<T, E> = T \| (:error, E)` | **shipped** | 15 |
| the collection library | `List.Map`, `List.Filter`, `List.Fold` | **open** — see gaps | 27, 17 §2 |

**`option` and `result` are not two spellings of one idea**, and the rule is worth stating because
it decides which to reach for: *absence carries nothing, failure carries a reason*. `option<T>` is
bare, `result<T, E>` is tagged — **and the tag is a consequence of the payload, not a separate
choice**, since `atom | (:error, binary)` does not collapse where `atom | :error` does (ticket 15).

**The collection library moved strata**, which is why it is listed here and still open. Ticket 27
gave the language real type variables, so `List.Map` became a definition a user *could* have
written — stratum 1's own test — and it dropped out of the compiler-known stratum. What has not
been decided is its **names, shapes, or the module that holds it**, and it cannot be until the
module system is decided.

**One rule about it is already settled and constrains any answer**: ticket 17 §2 — *the
compiler-known prelude is inlined, user code is called, and precision follows the inlining*.
Emitting a call to a generic prelude loses precision on **both** sides of the spec; inlining
recovers `[integer()] -> [binary()]` exactly. That creates a two-tier emitted boundary the spec
must state (→ 18).

---

## Stratum 2 — compiler-known

What a user could not have written. Wins resolution, and the compiler draws inferences from it.
**A user may not add to this stratum** — though see the gaps, because the *reason* for that "no"
has been withdrawn.

| Entry | What it is | Status | Ticket |
|---|---|---|---|
| `ValidateAs<T>` | codegen: validates a foreign term against `T`, returns `result<T, ValidationError>` | **built** — F18 | 11, amended by 15 |
| `ValidationError` | the reason: a path into the term plus the type expected there, `(list<string>, string)` | **built** — F18. The spelling of a path segment is F18's recorded assumption, not a decision | 15 §2 |
| `ParseAtom<T>` | codegen: parses to a **finite atom union**; a cofinite `T` is an error | **decided** | 10 §4 |
| `ToExistingAtom` | the genuine interop escape — a peer node's reply, a dynamically named atom | **owed** — must be respelled | 10 §5, 15 §1 |
| `foreign_error` | the foreign failure type | **decided** | 15 |
| `string` | `binary` refined by valid UTF-8 | **built** — F9 as a *type*; F18 generates the membership check **inside `ValidateAs<T>`** and nowhere else, so a term from outside can now establish the property that only a literal could before | 20 |
| a serialisation encoder | the fifth codegen obligation, generated against a type | **decided** | 16 §4 |
| OTP message shapes | `Down`, `Exit`, `Timeout` | **decided** | 14 §6 |

**`ToExistingAtom` is owed, not merely unbuilt.** Ticket 10 §5 wrote it as `atom | :nothing`, and
ticket 15 §1 later made exactly that shape **an error at the declaration** — a singleton absorbed
into a cofinite top, so the failure channel collapses and `atom | :nothing` *is* `atom`. Two
known-good answers exist (a tagged failure member, or a success type narrower than the atom top)
and neither has been chosen. **Do not implement it from this file.**

**One hard rule stratum 2 has and stratum 1 does not**: ticket 27 §8 — *a codegen obligation
requires a ground type argument*. So `ValidateAs<TSource>` inside a polymorphic function is
rejected.

---

## Not in the prelude, and a `Kernel` reader will look for them here

| | Where it actually lives |
|---|---|
| `if`, `unless`, `cond`, `case` | nowhere — `switch` is the only branching construct (17 §6) |
| `\|>`, `\|?>` | **grammar** (17 §3, §4) |
| `==`, `!=`, `<`, `<=`, `+`, `-`, `*` | **operators** (8, 16). `==` means `=:=` |
| `&&`, `\|\|` | **do not exist.** The conjunction is `and` / `or`, in every position (44 amending 8) |
| `is_atom/1` and friends | absent by design — the clause head and the checker do this |
| `raise` | a prelude function taking **any term**, exactly `:erlang.error/1` (15). **decided**, unbuilt |
| `try` | absent — `monitor` + `receive` replaces it for remote failure (15) |

**`<` carries an owed prelude entry.** Ticket 16 restricts `<` to **same-type operands**, and keeps
the BEAM's universal term order — which is total across every type, `1 < :ok` is `true` — as *"a
named prelude escape"* for `ordered_set` and mixed-key sorting. **That name has never been
chosen.** It is a gap, listed below.

---

## What is not decided

Read this section before proposing anything. These are open, and three of them are the *same*
question wearing different clothes.

1. **What actually distinguishes stratum 1 from stratum 2.** Three candidate criteria have each
   been falsified by an existing member:
   - *"could a user have written it"* — fails, since ticket 27 moved the collection library into
     stratum 1 while `string` stayed in stratum 2;
   - *"requires a ground type argument"* — fails on `foreign_error`, which takes none and is
     stratum 2 anyway;
   - *"what the compiler draws inferences from"* — the surviving candidate, and it is not yet a
     definition.
2. **Whether *prelude membership* and *compiler-generated* are the same thing at all.** They were
   shown to come apart on 2026-08-13: a user-declared **opaque refinement** is something the
   compiler generates a check for, while plainly not being in the prelude. That withdrew the
   justification for "a user may not add to stratum 2", and the "no" now stands without its reason.
3. **How the two strata are documented differently**, and what *"in the prelude versus in a module
   you import"* means once the answer is a compiler guarantee rather than a definition.
4. **The collection library** — names, shapes, and which module holds it. Blocked on the module
   system, which is the map's most load-bearing fog patch.
5. **The name of the universal-order escape** (see `<` above).
6. **`ToExistingAtom`'s respelling** — owed, two known-good answers, neither chosen.
7. **Whether `hd`, `tl`, `length`, `elem` exist at all.** No decision was found for or against.
   Stated as absent evidence rather than as a "no".

---

## Drift found while writing this

**`bool` is decided one way and built the other.** Ticket 10 says *"`bool` is a prelude alias not a
builtin"*; `bs_check.erl` has `builtin(bool) -> union(atom_lit(true), atom_lit(false))`. Same family
as the bare-`true` defect F7 found — a decision recorded in prose, implemented differently, with
nothing comparing the two.

It is behaviourally invisible today (both spellings produce the same type), which is exactly why it
survived. It stops being invisible the moment a user writes `type bool = ...` themselves, or the
prelude gains a shadowing rule.

---

## What gates this file

**Nothing yet, and that is a known hole.** `LANGUAGE.md`'s blocks are compiled bidirectionally by
`bin/check-language.sh` — must-compile blocks must compile, `not-yet` blocks must **not** — so it
cannot drift silently. This file has no such gate, and most of its entries are `decided`-but-unbuilt,
which is precisely the shape the `not-yet` tag exists for. Extending the gate here would mean that
when `ParseAtom<T>` lands, CI names this paragraph instead of waiting for a reader to trip over it.
