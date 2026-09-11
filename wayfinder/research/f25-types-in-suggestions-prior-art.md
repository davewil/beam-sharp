# F25 — Prior art on how a diagnostic renders a type: whole or fragment, alias or expansion

Research for [F25](../../compiler/features/F25-corrected-signature.md) / ENG-346, 2026-09-11.

It serves two items in F25's *Left for David*, both visible in
[the real-code prototype](../prototypes/f25-corrected-signature-in-real-code.md). At `ed0f246`,
before F25's Round 4, program 2's tag shape shows only the refused pair, and program 4's reason
names `map<string, int>` where the author wrote `ViewCounts`. [Research 70](70-discriminability-prior-art.md) already found that no other
language is asked whether to refuse an indiscriminable union. This file asks only how other
compilers print a type inside a diagnostic.

Each claim paragraph under Q1 and Q2 carries one tag; the Summary and the two tables are synthesis
over them. **MEASURED**: a probe run for this file printed the quoted output. **CITED**: a primary
source fetched 2026-09-11 says it, with a permalink and line range. **CARRIED**: an existing file
in this repo says it.

| arm | instrument | what it can show |
|---|---|---|
| B# | the prototype file above, compiled at `bc4740b` | **carried** (from `prototypes/`, not `research/`; research 70 carried from `issues/` the same way) |
| rustc | `rustc 1.98.0 (88d9e12ae 2026-08-18) (Homebrew)`; source `rust-lang/rust@67eda617` | **measured**, **cited** |
| TypeScript | `tsc` 5.9.3, `--noEmit --strict --pretty false`; source `microsoft/TypeScript@c63de15` (tag `v5.9.3`); release notes `microsoft/TypeScript-Website@61332a7` | **measured**, **cited** |
| Elm | source `elm/compiler@1bd5b36`; no `elm` installed | **cited** only |
| Gleam | `gleam 1.18.1`; source `gleam-lang/gleam@4a83802` (tag `v1.18.1`) | **measured**, **cited** |
| GHC | User's Guide and source `ghc/ghc@9a442c93` (GitLab); no `ghc` installed | **cited** only |

The probe programs are kept in [`f25-probes/`](f25-probes/); where a claim below names
`/tmp/f25probe/X`, the program is `f25-probes/X`. Paths in quoted output are trimmed; Gleam's
colour codes are stripped (it ignored `NO_COLOR=1`).

---

## Summary

**Q1 — whole or fragment.** None of the four compilers prints a type fragment on its own where a
whole type would stand. All four print the whole expected type. rustc, Elm and TypeScript then
mark the part that differs, inside the whole type (rustc elides equal parts to `_`; Elm colours the
differing parts) or in an indented line beneath it (TypeScript names one union member). rustc's
and Gleam's wrap suggestions name a constructor and edit the expression; they print no type. The
nearest thing to a fragment is TypeScript's prose *"Consider adding 'undefined' to the type of the
target"*, which follows both whole types, and whose codefix writes the whole resulting union.

**Q2 — alias, expansion, or both.** Two of five show both, and both put the author's name where
the author's type is mentioned. TypeScript keeps the alias in the headline and gives the
structural reason in elaboration lines beneath it (measured). GHC's documented example keeps
synonyms in the Expected/Actual lines while its headline names the mismatching expanded parts, and
`-fprint-expanded-synonyms` (off by default) adds an expanded copy beneath (cited). Elm prints the
alias name, never its expansion, with a structural hint only when the alias names a record. Gleam
and rustc print the expansion (measured).

**What the prior art shows for B#.** B#'s `(:tag1, map<string, int>) | (:tag2, map<string,
binary>)` is part of a return type, printed on its own line in the slot where program 3 prints a
whole signature. No compiler surveyed does that. What they do instead: print the whole resulting
type (TypeScript's codefixes), print the whole type with placeholders for the unchanged parts
(rustc's `_`), or name the constructor and print no type (rustc's and Gleam's wrap hints). For
program 4, the two compilers that show both never put the expansion in place of the author's name:
the name stays where the declared type is quoted, and the structure comes in a separate headline
clause or line. Which of these B# takes is David's decision.

---

## Q1 — whole type or fragment in a repair suggestion

**CARRIED**, program 2 at `ed0f246`: the declared return is `result<map<string, int>, atom>`, and
the advice prints `(:tag1, map<string, int>) | (:tag2, map<string, binary>)` under *"tag them, with atoms of
your choosing:"*. `(:error, atom)` is not in it.

### rustc — whole in the message; the suggestion edits the expression

**MEASURED**, `rustc --edition 2021 /tmp/f25probe/rs/wrap.rs`: enum `CartResult` with variants
`Numeric(HashMap<String, i64>)`, `Text(HashMap<String, String>)`, `Expired(u32)`, and `fn cart(m:
HashMap<String, String>) -> CartResult { m }`:

```
10 |     m
   |     ^ expected `CartResult`, found `HashMap<String, String>`
   |
   = note: expected enum `CartResult`
            found struct `HashMap<String, String>`
help: try wrapping the expression in `CartResult::Text`
   |
10 |     CartResult::Text(m)
   |     +++++++++++++++++ +
```

**MEASURED**, two more probes. With two fitting variants (`wrap2.rs`) the help line was ``try wrapping the expression in a
variant of `CartResult` `` followed by one edited line per variant. Returning a `HashMap<String,
String>` from a function declared `-> ViewCounts`, `type ViewCounts = HashMap<String, i64>`
(`alias.rs`), the note printed the shared skeleton with equal arguments elided:
``expected struct `HashMap<_, i64>` `` / ``found struct `HashMap<_, String>` ``.

**CITED**,
[`rustc_hir_typeck/src/fn_ctxt/suggestions.rs#L2781-L2816`](https://github.com/rust-lang/rust/blob/67eda617e6a8f8ecec01e1ba7fafe2072a64adcc/compiler/rustc_hir_typeck/src/fn_ctxt/suggestions.rs#L2781-L2816):
the suggestion is two insertions around the expression (L2781-L2784); the message texts are
``"try wrapping the expression in `{variant}`{note}"`` (L2793) and ``"try wrapping the expression
in a variant of `{}`"`` (L2805). The elision is `cmp` in
[`rustc_trait_selection/src/error_reporting/infer/mod.rs#L1125-L1127`](https://github.com/rust-lang/rust/blob/67eda617e6a8f8ecec01e1ba7fafe2072a64adcc/compiler/rustc_trait_selection/src/error_reporting/infer/mod.rs#L1125-L1127),
*"Compares two given types, eliding parts that are the same between them and highlighting relevant
differences"*, called on the expected/found pair at L2379; equal type arguments become `"_"` at
L1027-L1030. The E0308 index entry
([`E0308.md`](https://github.com/rust-lang/rust/blob/67eda617e6a8f8ecec01e1ba7fafe2072a64adcc/compiler/rustc_error_codes/src/error_codes/E0308.md))
shows only ``expected `i32`, found `&str` `` style labels and does not mention the wrapping
suggestion.

### TypeScript — whole target, then one member beneath it

**MEASURED**, `/tmp/f25probe/ts/q1.ts`, `CartResult = { kind: "numeric"; items: Record<string,
number> } | { kind: "expired"; reason: string }`:

```
q1.ts(7,3): error TS2322: Type 'Record<string, string>' is not assignable to type 'CartResult'.
  Type 'Record<string, string>' is missing the following properties from type '{ kind: "expired"; reason: string; }': kind, reason
q1.ts(15,3): error TS2322: Type '405' is not assignable to type '{ error: string; } | "created" | "ok"'.
```

**MEASURED**, read from the output above: the headline names the whole target; the indented line
names one member. The unnamed union on line 15 prints whole, with no member line.

**CITED**,
[`src/compiler/checker.ts#L23097-L23103`](https://github.com/microsoft/TypeScript/blob/c63de15a992d37f0d6cec03ac7631872838602cb/src/compiler/checker.ts#L23097-L23103):
`// Elaborate only if we can find a best matching type in the target union`, then a re-check
against that one member with errors reported. `getBestMatchingType` (L24854-L24860) picks it:
discriminant, same reference or alias, object-literal fit, callable fit, then most overlap. The
texts are in
[`diagnosticMessages.json`](https://github.com/microsoft/TypeScript/blob/c63de15a992d37f0d6cec03ac7631872838602cb/src/compiler/diagnosticMessages.json):
`"Type '{0}' is not assignable to type '{1}'."` (2322, L1999) and `"Type '{0}' is missing the
following properties from type '{1}': {2}"` (2739, L3486).

**CITED**, repairs that change a type. None of the 73 file names in
[`src/services/codefixes/`](https://github.com/microsoft/TypeScript/tree/c63de15a992d37f0d6cec03ac7631872838602cb/src/services/codefixes)
names a fix that adds a member to a union return type (judged by name; the files were not all
read). The two nearest by name:

- [`fixReturnTypeInAsyncFunction.ts#L47`](https://github.com/microsoft/TypeScript/blob/c63de15a992d37f0d6cec03ac7631872838602cb/src/services/codefixes/fixReturnTypeInAsyncFunction.ts#L47):
  title `"Replace '{0}' with 'Promise<{1}>'"` (90036), both arguments whole types; L82 replaces the
  whole return type node. Its error 1064 ends `"Did you mean to write 'Promise<{0}>'?"`
  (`diagnosticMessages.json` L198), the whole resulting type.
- [`addOptionalPropertyUndefined.ts#L118-L129`](https://github.com/microsoft/TypeScript/blob/c63de15a992d37f0d6cec03ac7631872838602cb/src/services/codefixes/addOptionalPropertyUndefined.ts#L118-L129):
  title `"Add 'undefined' to optional property type"` (95169) names only the addition, but the edit
  builds a union of every existing member plus `undefined` and replaces the whole property type
  (L122-L126). Its error 2412 is `"Type '{0}' is not assignable to type '{1}' with
  'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the type of the target."`
  (L2327): whole types first, the addition named in prose after them.

### Elm — whole on both sides, differences coloured

**CITED**,
[`Reporting/Error/Type.hs#L311-L324`](https://github.com/elm/compiler/blob/1bd5b36915a38335195ca7792fe3995f53d84d5e/compiler/src/Reporting/Error/Type.hs#L311-L324):
`typeComparison` stacks a sentence, the whole actual type, a sentence, the whole expected type,
then hints. Both types come from `toDiff` in
[`Type/Error.hs#L230-L366`](https://github.com/elm/compiler/blob/1bd5b36915a38335195ca7792fe3995f53d84d5e/compiler/src/Type/Error.hs#L230-L366),
which wraps differing sub-terms in `D.dullyellow` and leaves matching ones plain. In the wrap case
(L298-L302), expected `List t2` against an actual that matches `t2`, the expected side prints
whole with only `List` in yellow, and no hint is attached (`Bag.empty`).

### Gleam — whole on both sides; the wrap hint names the constructor

**MEASURED**, `gleam check` in `/tmp/f25probe/gl2`, `fn maybe_views(row: ViewCounts) ->
Result(ViewCounts, Nil) { row }`: the label under `row` read ``Did you mean to wrap this in an
`Ok`?``; below the prose, `Expected type:` printed `Result(List(#(String, Int)), Nil)` and `Found
type:` printed `List(#(String, Int))`, each whole on its own indented line.

**CITED**,
[`compiler-core/src/error.rs#L3135-L3167`](https://github.com/gleam-lang/gleam/blob/4a83802ca33a8a96227a1b332768725f232f9779/compiler-core/src/error.rs#L3135-L3167):
`"Expected type:\n\n    "` and `"\n\nFound type:\n\n    "`, each followed by `print_type` of the
whole type; the hint is the label on the expression. The hint text, at
[L5202-L5213](https://github.com/gleam-lang/gleam/blob/4a83802ca33a8a96227a1b332768725f232f9779/compiler-core/src/error.rs#L5202-L5213),
is ``"Did you mean to wrap this in an `Ok`?"`` (or `` `Error` ``), given only when the found type
equals that argument of the expected `Result`.

| | verdict | expected type in the message | the repair suggestion | a fragment alone where a type would stand? |
|---|---|---|---|---|
| rustc | whole (difference marked inside) | whole; `note:` elides equal parts to `_` | variant path + edited expression | no |
| TypeScript | both | whole; one member in an indented line | whole replacement type, or the addition in prose | no |
| Elm | both | whole, differences in yellow | prose hints, none for the wrap case | no |
| Gleam | whole | whole | constructor named on the expression | no |

---

## Q2 — alias name, expansion, or both, when the reason is structural

**CARRIED**, program 4 at `ed0f246` (`type ViewCounts = map<string, int>`, declared `ViewCounts |
:not_found`): the lead names `ViewCounts | :not_found`, and the next line says *"widening it would
leave `map<string, int>` absorbed by `:not_found | map<string, term>`"*.

### GHC — synonyms in Expected/Actual, expanded parts in the headline, a full expansion on request

**CITED**,
[`docs/users_guide/using.rst#L1340-L1370`](https://gitlab.haskell.org/ghc/ghc/-/blob/9a442c93839e29067d7c5b67108494a4e7feea43/docs/users_guide/using.rst#L1340-L1370):
*"In type errors, also print type-synonym-expanded types."* With `type Foo = Int`, `type Bar =
Bool`, `type MyBarST s = ST s Bar`, the first three lines below are the documented message without
the flag, and the flag adds the last three:

```
Couldn't match type 'Int' with 'Bool'
Expected type: ST s Foo
  Actual type: MyBarST s
Type synonyms expanded:
Expected type: ST s Int
  Actual type: ST s Bool
```

**CITED**,
[`GHC/Tc/Errors/Ppr.hs#L5148-L5160`](https://gitlab.haskell.org/ghc/ghc/-/blob/9a442c93839e29067d7c5b67108494a4e7feea43/compiler/GHC/Tc/Errors/Ppr.hs#L5148-L5160):
today the unexpanded pair prints as `"Expected:"` / `"  Actual:"`, so the docs' first block is
older than the current layout; the expanded block keeps `"Type synonyms expanded:"`. With the flag
(it sets `cec_expand_syns`,
[`GHC/Tc/Errors.hs#L258`](https://gitlab.haskell.org/ghc/ghc/-/blob/9a442c93839e29067d7c5b67108494a4e7feea43/compiler/GHC/Tc/Errors.hs#L258))
both blocks are emitted, unexpanded first, only when expansion changes something (L5999-L6014),
and only *"as much as necessary"*: *"The whole point here is to make the difference in expected
and found types clearer"* (L6017-L6027).

### TypeScript — alias in the headline, structural reason beneath

**CITED**, TypeScript 4.2 release notes, *Smarter Type Alias Preservation*
([`TypeScript 4.2.md#L55-L58`](https://github.com/microsoft/TypeScript-Website/blob/61332a778fe41c95724b5f3ffd139f37ea41a267/packages/documentation/copy/en/release-notes/TypeScript%204.2.md#L55-L58)):

> We keep track of how types were constructed by keeping around parts of how they were originally
> written and constructed over time. ... Being able to print back the types based on how you used
> them in your code means that ... that often translates to getting better `.d.ts` file output,
> error messages, and in-editor type displays in quick info and signature help.

**MEASURED**, `/tmp/f25probe/ts/q2.ts`, `type ViewCounts = Record<string, number>`:

```
q2.ts(5,3): error TS2322: Type 'Record<string, unknown>' is not assignable to type 'ViewCounts'.
  'string' index signatures are incompatible.
    Type 'unknown' is not assignable to type 'number'.
q2.ts(10,3): error TS2322: Type 'Record<string, unknown>' is not assignable to type 'ViewCounts | "not_found"'.
```

**MEASURED**, read from the output above: the first keeps the author's name and gives the reason
in the expansion's parts (the index signature, `number`) without printing the expansion as a type.
The second, program 4's shape, keeps the name inside the union and gives no reason.

**CITED**, the elaboration text is `"'{0}' index signatures are incompatible."` (2634,
[`diagnosticMessages.json#L3108`](https://github.com/microsoft/TypeScript/blob/c63de15a992d37f0d6cec03ac7631872838602cb/src/compiler/diagnosticMessages.json#L3108)).

### Elm — the name only; a structural hint only for a record alias

**CITED**,
[`Type/Error.hs`](https://github.com/elm/compiler/blob/1bd5b36915a38335195ca7792fe3995f53d84d5e/compiler/src/Type/Error.hs):
the error type keeps both, `Alias ModuleName.Canonical Name.Name [(Name.Name, Type)] Type` (L48),
the last field being the expansion, but printing uses the name and arguments only (`Alias home
name args _ -> aliasToDoc ...`, L123-L131). When one side is an alias and the other is not
(L304-L340) and both dealias to records (`diffAliasedRecord`, L477-L484), the alias name prints in
yellow and the record diff's problems are kept; they become hints built from
`["Looks","like","the",f1,"field","is","missing."]`
([`Reporting/Error/Type.hs#L485-L497`](https://github.com/elm/compiler/blob/1bd5b36915a38335195ca7792fe3995f53d84d5e/compiler/src/Reporting/Error/Type.hs#L485-L497)).
For any other alias both sides print whole in yellow with no problem recorded (`Bag.empty`,
L317-L321 and L336-L340), so an alias of a dictionary type, the `ViewCounts` shape, gets the name
and no reason.

### Gleam — expansion only

**MEASURED**, `gleam check` in `/tmp/f25probe/gl`, `pub type ViewCounts = List(#(String, Int))`,
`fn page_views(row: List(#(String, String))) -> ViewCounts { row }`: `Expected type:` printed
`List(#(String, Int))` and `Found type:` printed `List(#(String, String))`. `ViewCounts` did not
appear in the message.

**CITED**,
[`compiler-core/src/type_/printer.rs#L124-L148`](https://github.com/gleam-lang/gleam/blob/4a83802ca33a8a96227a1b332768725f232f9779/compiler-core/src/type_/printer.rs#L124-L148):
*"Since Gleam type aliases are not part of the type system, we have to track them manually here."*
The one alias the printer restores is a public alias that re-exports an internal type from the
same package with the same parameters (L245-L257).

### rustc — expansion in the text, the name only by position

**MEASURED**, `/tmp/f25probe/rs/alias.rs`, `type ViewCounts = HashMap<String, i64>`:

```
5 | fn page_views(row: HashMap<String, String>) -> ViewCounts {
  |                                                ---------- expected `HashMap<String, i64>` because of return type
6 |     row
  |     ^^^ expected `HashMap<String, i64>`, found `HashMap<String, String>`
```

**MEASURED**, read from the output above: the label text is the expansion. The name appears only
as the source token the label underlines.

| | verdict | the author's alias name | the structure |
|---|---|---|---|
| GHC | both | Expected/Actual lines | the headline's mismatching parts; a second, expanded block with the flag (off by default) |
| TypeScript | both | the headline | elaboration lines beneath, as parts, not the whole expansion |
| Elm | name | wherever the type prints | a hint, for record aliases only |
| Gleam | expansion | nowhere, except re-export aliases | the printed type |
| rustc | expansion | the quoted source line only | the printed type |

---

## Not verified from a primary source

- A TypeScript codefix that adds a member to a union return type: none found at v5.9.3, judged
  by file name.
- rustc's policy on printing `type` aliases: measured behaviour only; no statement found.
- GHC's output, default or flagged: the User's Guide example only; no GHC was run.
- Elm: every claim is read from source; no Elm compiler was run. `Type/Type.hs` was not read; the
  `Alias` constructor in `Type/Error.hs` answered the question.
- The rustc wrapping message is in `fn_ctxt/suggestions.rs`; `demand.rs` at `67eda617` does not
  contain it.
