# The standard environment

> **Renamed in substance 2026-08-25, not yet in filename.** David settled the model: one axis is
> *what ships out of the box before any external module*, called **the standard environment**
> (Miranda's term); the other is whether an entry is reachable **unqualified**. They are independent
> properties, so `Map.Get` is in the standard environment *and* requires a qualifier with no
> contradiction. `CONTEXT.md` carries both terms; **"prelude" is retired**. The file is still called
> `PRELUDE.md` because it is cited from ten places including the `check-links` gate and three
> compiler modules — renaming it is a separate chore, deliberately not bundled here.


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

**Four entries.** `bs_check:prelude/0` is `maps:merge(stratum_one(), stratum_two())`.
`stratum_one()` holds `option<T>`, `result<T, E>` and `foreign_error`; `stratum_two()` holds
`ValidationError`. Everything else in the tables below is decided-and-unbuilt.

> **Corrected 2026-08-26 by ENG-245.** This paragraph read *"**Two entries.** `bs_check:prelude/0`
> holds `option<T>` and `result<T, E>` and nothing else. Everything else in stratum 1 below is
> decided-and-unbuilt, and the whole of stratum 2 is unbuilt."* Every clause of that was false by
> the time it was read: F19 put `foreign_error` in `stratum_one()`, F18 put `ValidationError` in
> `stratum_two()`, and the stratum-2 table forty lines below this one marked **three** entries
> **built** — so the document contradicted itself within a single screen, and contradicted the
> compiler in both directions at once. `bin/check-status-claims.sh` now probes every row in these
> tables through `bsc` and fails on exactly this.

---

## Stratum 1 — definitions a user could have written

Ordinary aliases. The compiler draws no special inference from them; they win no resolution
contest; they are in the prelude because you should not have to import them.

| Entry | Spelling | Reach | Status | Ticket |
|---|---|---|---|---|
| `bool` | `type bool = true \| false` | unqualified | **decided** — and **built as a builtin instead**, see Drift | 10 |
| `option<T>` | `type option<T> = T \| :nothing` | unqualified | **shipped** | 10 §5 |
| `result<T, E>` | `type result<T, E> = T \| (:error, E)` | unqualified | **shipped** | 15 |
| the collection library | `List.Map`, `List.Filter`, `List.Fold` | **qualified** | **open** — see gaps | 27, 17 §2 |

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

| Entry | What it is | Reach | Status | Ticket |
|---|---|---|---|---|
| `ValidateAs<T>` | codegen: validates a foreign term against `T`, returns `result<T, ValidationError>` | unqualified | **built** — F18 | 11, amended by 15 |
| `ValidationError` | the reason: a path into the term plus the type expected there, `(list<string>, string)` | unqualified | **built** — F18. The spelling of a path segment is F18's recorded assumption, not a decision | 15 §2 |
| `ParseAtom<T>` | codegen: parses to a **finite atom union**; a cofinite `T` is an error | unqualified | **decided** | 10 §4 |
| `ToExistingAtom` | the genuine interop escape — a peer node's reply, a dynamically named atom | unqualified | **owed** — must be respelled | 10 §5, 15 §1 |
| `foreign_error` | the foreign failure type | unqualified | **built** — F19. Stored in `stratum_one()` though it is listed here: its TYPE is nameable by an author, which is how the wrapper is asked for, while only generated code produces the VALUES | 15 |
| `string` | `binary` refined by valid UTF-8 | unqualified | **built** — F9 as a *type*; F18 generates the membership check **inside `ValidateAs<T>`** and nowhere else, so a term from outside can now establish the property that only a literal could before | 20 |
| a serialisation encoder | the fifth codegen obligation, generated against a type | unqualified | **decided** | 16 §4 |
| OTP message shapes | `Down`, `Exit`, `Timeout` | unqualified | **decided** | 14 §6 |

**`ToExistingAtom` is owed, not merely unbuilt.** Ticket 10 §5 wrote it as `atom | :nothing`, and
ticket 15 §1 later made exactly that shape **an error at the declaration** — a singleton absorbed
into a cofinite top, so the failure channel collapses and `atom | :nothing` *is* `atom`. Two
known-good answers exist (a tagged failure member, or a success type narrower than the atom top)
and neither has been chosen. **Do not implement it from this file.**

**One hard rule stratum 2 has and stratum 1 does not**: ticket 27 §8 — *a codegen obligation
requires a ground type argument*. So `ValidateAs<TSource>` inside a polymorphic function is
rejected.

---

> **Scope corrected 2026-08-25.** This file is the **prelude** — what is reachable *without a
> qualifier*, B#'s `Kernel`-equivalent. The **standard library** is the separate layer reached
> *through* a qualifier (`Map.Get`), and B# has none of it yet. Entries below about a collection
> library are parked here for want of a home and belong to that layer, not this one; ticket 48
> decided its first module. See `CONTEXT.md` for both terms.

## Not in the prelude, and a `Kernel` reader will look for them here

| | Where it actually lives |
|---|---|
| `if`, `unless`, `cond`, `case` | nowhere — `switch` is the only branching construct (17 §6) |
| `\|>`, `\| unqualified |?>` | **grammar** (17 §3, §4) |
| `==`, `!=`, `<`, `<=`, `+`, `-`, `*` | **operators** (8, 16). `==` means `=:=` |
| `&&`, `\|\| unqualified |` | **do not exist.** The conjunction is `and` / `or`, in every position (44 amending 8) |
| `is_atom/1` and friends | absent by design — the clause head and the checker do this |
| `raise` | a prelude function taking **any term**, exactly `:erlang.error/1` (15). **decided**, unbuilt |
| `try` | absent — `monitor` + `receive` replaces it for remote failure (15) |

**`<` carries an owed prelude entry.** Ticket 16 restricts `<` to **same-type operands**, and keeps
the BEAM's universal term order — which is total across every type, `1 < :ok` is `true` — as *"a
named prelude escape"* for `ordered_set` and mixed-key sorting. **That name has never been
chosen.** It is a gap, listed below.

---

## Is a prelude even required? — reviewed 2026-08-25

David, on reading [`Kernel.SpecialForms`](https://elixir.hexdocs.pm/1.20.3/Kernel.SpecialForms.html):
*"I think we need to review what goes in the prelude as well. Or whether one is even required given
in Elixir they're macros we don't support (yet)."*

**The observation is right and it shrinks this file's claim considerably.** Elixir needs `Kernel`
and `Kernel.SpecialForms` to be *modules* because Elixir's syntax **is** macros — *"special forms
are the basic building blocks of Elixir, and therefore cannot be overridden by the developer"*, and
all 31 of them are macros auto-imported without a prefix. B# has no macros, so the same constructs
land somewhere else. Sorting all 31 against B#:

| Elixir special form | Where it lives in B# |
|---|---|
| `%{}`, `%struct{}`, `{args}`, `<<args>>` | **grammar** — brace forms, record construction, tuples, binary patterns (F13) |
| `left = right`, `^var` | **grammar** — `=` is match (F8), the pin is `== name` (45) |
| `left . right`, `left :: right`, `__block__` | **grammar** — field access, declaration syntax, blocks |
| `case/2`, `cond/1` | **grammar** — `switch`, the only branching construct (17 §6) |
| `alias/2`, `import/2` | **grammar** — `using` (40, 41) |
| `quote`, `unquote`, `unquote_splicing`, `require/2`, `super/1`, `__CALLER__`, `__aliases__/1`, `__cursor__/1` | **nothing — B# has no macros.** Eight of the thirty-one, and the largest single group |
| `try/1` | **absent by design** — `monitor` + `receive` replaces it (15) |
| `for/1` | absent |
| `__MODULE__`, `__DIR__`, `__ENV__`, `__STACKTRACE__` | absent — reflection is undecided, and nobody has asked |

**Not one of them needs a prelude.** They are grammar, or they are macro machinery B# does not have.
The same holds for `Kernel` proper: `+`, `==`, `<` are **operators** (8, 16), `|>` is **grammar**
(17 §3), and `is_atom/1` and friends are *"absent by design — the clause head and the checker do
this"*.

**So what is actually left?** The inventory above, read honestly, is:

- **type names** — `option`, `result`, `list`, `bool`, `string`, and now `map`;
- **codegen obligations** — `ValidateAs<T>`, `ParseAtom<T>`, the serialisation encoder,
  `ToExistingAtom`, plus the types they return;
- **`raise`** — and it is the *only* function anywhere in this file;
- one **unnamed gap**: `<`'s "named prelude escape" for the BEAM's universal term order.

**Four entries ship today** — `option<T>`, `result<T, E>`, `foreign_error` and `ValidationError` —
and all four are types. <!-- corrected 2026-08-26, ENG-245; said "Two entries ship today" -->

That the count is four rather than two does not soften the point this section is making, and it
is worth saying why: all four are **types**, so the prelude still ships no function at all.

### The consequence, and it reaches back into ticket 48

**B# may need no prelude *functions* at all.** `raise` is the only candidate, and `raise` is not a
keyword today — the lexer's entire reserved vocabulary is fifteen words: `_ and behaviour module or
private public record switch type using var when where with`. So `raise` is unbuilt in both senses,
and it could as easily be **grammar**, the way `switch` is, as a function.

If `raise` is grammar, **the prelude contains zero functions**, and it is exactly two things that
already have names of their own: *the builtin type names*, and *the codegen obligations*.

That matters for [ticket 48](wayfinder/issues/48-a-map-type-in-the-prelude.md)'s Q9, which asked
what namespace a prelude *function* lives in and measured that neither `Get` nor `Map` is free.
**That problem only exists if prelude functions exist.** Ticket 48 put the map operations in the
**standard library**, reached through a qualifier, so the unqualified-collision worry was created by
calling that layer "a function prelude" in the first place. Q9's answer — reserve the `Map`
qualifier — is still needed, because it is a *standard-library module name*. The rest of Q9's
framing was solving a problem that may not arise.

### Two questions this opens, both open

1. **Is `raise` grammar or a prelude function?** Grammar makes the prelude function-free and keeps
   the fifteen-keyword surface honest about what it costs. A function keeps the keyword count down
   but reintroduces the one thing Q9 was worried about.
2. **Does the term "prelude" survive?** It names a real set — *what is reachable without a
   qualifier* — and the lowercase/PascalCase rule at `bs_check.erl:710-712` needs that set to have a
   subject. But if the set is only types and codegen obligations, both already named in
   `CONTEXT.md`, the term may be carrying less than its own file implies.

### Where the word came from — surveyed 2026-08-25

Full survey, primary sources only:
[`research/prelude-the-word-across-languages.md`](wayfinder/research/prelude-the-word-across-languages.md).
The four findings that bear on the two questions above:

1. **No primary source says why Haskell chose the word.** Not the 2010 Report, not *A History of
   Haskell* (8 occurrences, none etymological), not the 1.0 preface, which explains *"Haskell"* and
   is silent on *"Prelude"*. One lead only: LML had one first. Miranda, Haskell's closest ancestor,
   called it *"the standard environment"*.
2. **The word connotes almost nothing.** Not implicitness — PureScript's must be imported by hand.
   Not one thing — Rust has five. Not a module — Rust's is *"a collection of names"*. Not functions
   — Gleam's has none.
3. **Haskell 1.0 tried exactly this split and abolished it in 1.3.** `PreludeCore` was types,
   classes and instances, always implicit and non-shadowable, with no free functions — killed
   because users could not redefine `+`, `==`, `>`. **The failure mechanism was the classes**, whose
   methods came in with them. Ticket 16 killed type classes for B#, so it cannot recur here.
4. **Gleam's prelude is types and data constructors with zero function values**, on this platform —
   shape-identical to B#'s. But Rust names its types-only layer the ***language*** prelude,
   distinguished by a qualifier from the library one; and only Rust's trait/function prelude ever
   needed versioning (2021, 2024). The types-only one never has.

**And the C#-family answer is not a prelude at all**: `predefined_type` is a grammar nonterminal,
`int`/`bool`/`string` are keywords aliasing `System` types. This file's own Drift section already
records B# leaning that way without deciding to — `bool` is *"decided one way and built the other"*,
a prelude alias in ticket 10 and `builtin(bool)` in `bs_check.erl`.

**So the live options for question 2 are three, not two:** keep *prelude* as Gleam does; qualify it
as Rust does (*language prelude* vs the standard library); or dissolve it C#-style into **builtin
types** plus **codegen obligations**, both of which `CONTEXT.md` already names — in which case the
word names nothing that is not already named. Renaming is not free: OCaml took **4.5 years** to go
`Pervasives` → `Stdlib`.

## The two areas — proposed 2026-08-25, and they are axes rather than categories

David, after the survey: *"The way I see it is split into 2 areas. The out of the box environment —
'the standard environment' — before any other external modules are included, and the names and
functions that are available without qualification. We're still in the design phase through
prototyping, so B# has the freedom to pivot to a cleaner distinction."*

**This is cleaner than anything proposed above it, and the reason is structural: those are two
independent properties, not two buckets.** Everything written earlier — including this file's own
framing, and ticket 48's Q5 — treated *"prelude"* as naming both at once, which is why `Map.Get`
kept looking anomalous. It is not anomalous. It ships out of the box **and** requires a qualifier;
those facts simply do not conflict.

Sorting the actual inventory against both axes:

| Entry | ships out of the box | reachable unqualified |
|---|---|---|
| `int`, `bool`, `string`, `atom`, `term` | yes | yes — builtin |
| `list<T>`, `option<T>`, `result<T, E>`, `map<K, V>` | yes | yes |
| `ValidateAs<T>`, `ParseAtom<T>`, the encoder | yes | yes — codegen obligations |
| `Map.Get`, `List.Map` | yes | **no** — qualified, and *inlined* (17 §2) |
| `raise` | yes | yes |
| the 47 terminals below | yes | **grammar — not names at all** |
| a user's own module | no | — |
| an external dependency | no | — |

**One inventory, two properties.** This file is already a census with status columns; it needs a
**qualification column**, not a restructure.

**The grammar row is a complete list, not a sample — swept 2026-08-25.** B#'s entire terminal
alphabet is **47 tokens**. None of them is a name in the sense the second axis means, so none can
collide with anything a user writes:

    keywords (14)   and behaviour module or private public record switch type using var when where with
    wildcard        _
    arithmetic      + - *
    comparison      == != < <= > >=
    pipes           |>  |?>
    union           |
    match           =
    arrows          ->  (clause head)      =>  (switch arm)
    brackets        ( ) [ ] { }
    binary open     <<                     (the close is two `>` tokens, not `>>`)
    separators      , : . ..
    optional        ?
    name classes    uident lident atom_lit integer string_lit

Three things the sweep turned up that are worth having written down:

> **Corrected 2026-08-25, same day, by David: *"I thought we tackled div mod / % previously."*** He
> is right and the claim below was wrong before it was rewritten. `/` and `%` are **decided** —
> [ticket 38](wayfinder/issues/38-division-and-modulo.md): *"`/` on two `int`s is truncated integer
> division and `%` is the remainder it leaves, signed by the dividend"* (`-7 / 2` is `-3`), with
> emission mapping `/` to Erlang's **`div`** and never its `/`, which is float division. The
> original text asserted the absence was *"not recorded anywhere"* and *"a gap rather than a
> decision"* — asserted, not searched. It is a decision, and only the **implementation** is missing.

- **`/` and `%` are decided and unbuilt.** Neither is a token: the lexer has `+`, `-` and `*` and
  stops there. Ticket 38 settled the semantics; nothing has emitted them yet. That is a **feature
  owed**, not an open question.
- **`not` is missing outright, and this one *is* a gap.** There is no `not` token and no production
  for it. [Ticket 44, amending 08](wayfinder/issues/44-conjunction-spelling.md), settled `and`
  and `or` — *"one spelling now, in every position … `&&`/`||` are removed rather than kept as
  synonyms"* — and **says nothing about negation**. So B# can spell conjunction and disjunction and
  cannot spell negation. Searched before being claimed this time, unlike the division entry above.
- **The pin operator is present; the grouping above hid it.** `bs_parser.yrl:355` is
  `pattern -> '==' lident : {p_eqvar, ...}`, so ticket 45's pin **reuses the existing `==` token**
  rather than adding one. The token list was right and the *classification* was not: `==` belongs
  under comparison **and** under patterns.
- **`?` is recognised only in order to be refused.** `bs_parser.yrl:103` is
  `field_decl -> uident '?' ':' type_expr`, whose action is a `return_error` — so the optional-field
  spelling is lexed, parsed, and then rejected with a diagnostic. It has **no accepted use**, which
  is what "reserved" means here.
- **`behavior` and `behaviour` both lex**, to the same `'behaviour'` token. The US spelling is
  accepted silently; no ticket records choosing that.
- **`string_lit` is built inside a helper** (`str_token/2`) rather than inline in its rule, so a
  naive sweep of the lexer under-reports the alphabet by one. Anyone re-deriving this list must read
  the `Erlang code.` section too — which is the repo's own *"sweep the lexer and the parser
  separately"* trap, met again.

### What the split buys, concretely

1. **`Map.Get` stops needing a category of its own.** It is in the standard environment and it is
   qualified. Neither *"prelude"* nor *"standard library"* has to be stretched to cover it, and
   ticket 48's Q5 — corrected once already — needs no third answer.
2. **The recorded boundary reads correctly again.** *BOUNDARY — Standard library breadth* rules out
   *"a library designed module-by-module"*. Shipping qualified compiler-known operations is not
   designing a library, so `Map.Get` never crossed it.
3. **The shadowing question becomes precise, and mostly answers itself.** The *"user names win"*
   lesson five languages learned applies **only to the unqualified column, and only to entries that
   are not keywords**. Today that is the codegen obligations and possibly `raise` — a closed,
   compiler-owned set. A closed set needs no shadowing rule. The rule is owed only if that column
   is ever opened to accretion.

### The naming that follows

- **Axis 1 — "the standard environment".** Miranda's own term, from `stdenv.m`: *"all the
  identifiers in the Miranda standard environment"*. Miranda is Haskell's closest ancestor, so this
  is the term Haskell **replaced** with *"prelude"* — and the survey found no primary source for why
  it did. Borrowing it back is accurate on its face: it is an environment you are given, not a
  library you import.
- **Axis 2 — a property, not a category.** *"Unqualified"* describes it exactly, and needs no
  coinage.

**Which retires "prelude" entirely**, because with the axes separated, neither area needs it. That
is a real loss of a familiar word — but the survey established the word reliably connotes almost
nothing: not implicitness (PureScript), not one thing (Rust's five), not a module (Rust's is *"a
collection of names"*), not functions (Gleam's has none). Little is given up.

**Cost, measured.** Renaming the *concept* is cheap — `CONTEXT.md` and prose. Renaming this *file*
is a chore: `PRELUDE.md` is cited from ten places including the `check-links` gate and three
compiler modules (`bs_check.erl`, `bs_emit.erl`, `bs_diag.erl`), plus F18, F19 and a test. The two
can be done separately, and the concept should not wait for the file.
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
