# Brief — ticket 65 (ENG-255): reserved names, the policy

Status: **open, left open.** Evidence for David; nothing here is decided. Probes: `artifacts/probes/65/`.

**Most of this ticket has been answered by later tickets, and the ticket text does not say so.** Grepped before
writing (`wayfinder/issues/*.md`, `compiler/features/*.md`): [67](../../wayfinder/issues/67-stdlib-shape-as-a-principle.md)
Q1 answered closed-by-construction ("answers the first question ticket 65 put to itself"); 96's round 3 answered
Q6 *yes* on 2026-09-25 — "every qualifier the standard environment adds is reserved on 67 Q6's terms … a user module
with that short name is refused where it would be written as the word; a dotted path holding it is not … This answers
ticket 65's first question by rule"; F32 built it for `List`/`Map`/`Term`, F51 added `Float`
(`bs_check.erl:1701`: `['List','Map','Term','Float']`). The three options in the ticket text (reserve per module /
unreachable namespace / user names win) were not chosen between — the first was taken for qualifiers. What is left is
below.

## What the compiler does today (`65-p1`, one module per case)

```
module Map | List | Term            -> error: `Map` is a reserved qualifier, so no module may be called it
module Shop.Collections.List        -> compiles (the dotted path is not the reserved word)
module String | Int | Process | GenServer | Supervisor | Logger | Json   -> compile (not reserved yet)
type option<T> = …   /   type term = int          -> syntax error before `option` / `term`
record Map { Id: int }                               -> compiles
public int List(int x)   /   Raise   /   Map        -> compile (a FUNCTION may carry a reserved qualifier's name)
record Exit {…}  /  type Down = int                  -> error: `Exit` is a compiler-known type and cannot be redeclared
public int bs@type_atoms(int x)                      -> error: illegal characters "@"
module Elixir.Enum                                   -> COMPILES; emits Elixir.Enum.beam      (see below)
```

Three observations that change the ticket's framing:

1. **The "namespace the user's syntax cannot reach" (the ticket's option 2) already exists, for types.** Builtin types
   are lowercase (`option`, `result`, `map`, `list`, `term`, `string`…); user type declarations take `uident` only
   (`bs_parser.yrl:206`, `bs_lexer.xrl:150,153`), so a user cannot collide with any of them — the failed
   `type option<T>` above is a parse error, not a reservation. The only type collisions left are the PascalCase
   compiler-known ones (`ValidationError`, `Down`, `Exit`: `bs_check.erl:1372`, refused by
   `compiler_known_redeclared/1`, `:1832`).
2. **`bs@` is already unspellable**, so the question ticket 87 handed here ("is `bs@` a reserved export prefix?")
   answers itself: the lexer refuses `@`. It can be closed by a sentence.
3. **A real hole the ticket never considered: the module atom's root.** `module Elixir.Enum` compiles and writes
   `Elixir.Enum.beam`. Loading that beam into an Elixir VM replaces `Enum` and the VM dies
   (`65-p3`: after the load, `Elixir.Enum:reverse/1` is undefined inside Elixir's own code and the runtime terminates).
   The ticket 62 argument that the three namespaces are "disjoint by shape" holds for every B# module name *except* a
   dotted path that starts with `Elixir`. This is the same class as Elixir's own `defmodule Map` (below), reached
   from the other side.

## What neighbours do when user code takes a standard name (`65-p2`, run)

- **Elixir 1.18.4**: `defmodule Map` → warning "redefining module Map"; afterwards `function_exported?(Map, :get, 2)` is
  `false`, and `Enum.into/2` crashes with `Map.update!/3 is undefined or private`. The ticket's claim holds. The
  caller is not Elixir's runtime but its own type checker: `lib/elixir/lib/module/types/descr.ex:1824, 2608` call
  `Map.update!`. Warning emitted at `elixir_module.erl:624`.
- **Erlang**: OTP 25 refuses `-type map() :: …` ("type map() is a builtin type; it cannot be redefined"); OTP 28 compiles
  it with a warning ("local redefinition of built-in type", `erl_lint.erl:546-547`, raised at `:3361`).
- **Gleam 1.12**: `pub type Result` / `pub type Bool` shadow the prelude without complaint; and a user
  `src/gleam/list.gleam` beside the dependency's `gleam/list` builds **two** `gleam@list.beam` files
  (`build/dev/erlang/g/ebin/` and `…/gleam_stdlib/ebin/`). `g:main()` returned `1` or `99` depending only on code-path
  order. "User names win" is a compile-time statement; the BEAM module namespace is flat, so a shadowing *module*
  needs the emitted atom to differ, which B# already guarantees (a dotted path, not a bare short name).
- Scala/Rust/Haskell/Elm rows from the ticket's research file were not re-run (no toolchains installed here;
  Elm is installed but cannot build offline).

## What is genuinely open, asked as one question

> **When a later feature reserves a name a program already declares, what happens to that program?**

The reserved set has grown one name per feature so far (Map by 48, List/Term by F32, Float by F51) and 96 plans
`Int`, `String`, `Process`, `System`, `Task` (and `GenServer`/`Supervisor`/`Logger`). Measured on the 163 `.bs` files in
the repo: 121 `module` lines, **0** use a planned reserved short name; two use names a later feature might want —
`Stream` (`compiler/examples/Stream/stream.bs:22`, relevant to ENG-283) and `Atom`. Pre-1.0 and one author, the cost of a
reservation is a rename; the question is what the rule says once someone else has programs.

### Option A — refuse at the declaration, forever (what F32 does), plus the `Elixir` root

```csharp
module Stream            // before a Stream qualifier ships: compiles.   After: error, "`Stream` is a reserved qualifier"
module Elixir.Enum       // new: error, "`Elixir` is the root of Elixir's module namespace"
```
Compiler delta: one clause beside `reserved_module_name/2` (`F32`: it runs before `module_matches_path/3`) refusing a
first path segment of `Elixir`; each new qualifier already adds itself to `reserved_qualifiers/0`.
*Strongest counterargument:* a reservation made after a program exists breaks that program with no warning period;
there is no migration story, and `Stream`/`Atom` in the corpus show the cost is not hypothetical.

### Option B — a reservation is a warning for one release, then a refusal

```csharp
module Stream            // release N:   warning: `Stream` will be reserved in N+1 (rename, or write the dotted path)
```
Compiler delta: a `reserved_since` field per qualifier and a severity switch in the same refusal; the message prints the
rename. Rust's edition mechanism and OTP's `redefine_builtin_type` warning (OTP 28, above) are the neighbours with this
shape. *Strongest counterargument:* needs a release cadence B# does not have; for a single-author pre-1.0 language it
is machinery for a population of one.

### Option C — user names win at the call site (the ticket's option 3, narrowed)

```csharp
module Stream            // allowed; `Stream.Take(xs, 3)` resolves to the USER's module and warns "shadows the standard Stream"
```
Compiler delta: F32's third clause already errors on a call-site collision between a user module and a reserved
qualifier (`using Shop.Collections` beside `List`); this turns that error into a resolution rule for every qualifier.
*Strongest counterargument:* it is the shape that failed in Elixir (above) when the shadowed name is one the
runtime itself calls, and the standard operations are *inlined* (67), so a user `Stream` and the compiler-known
`Stream` would both be live under one word in one file.

## Recommendation

**A, with the `Elixir` root refusal added now** — the root refusal is the only item here that prevents a measured
failure (a compiled module that kills an Elixir VM when loaded) and it costs one clause. Treat B as the answer to
adopt *when* a second author's programs exist, not before: the repo's own rule (CLAUDE.md, "a check needs a second
occurrence of the failure it names") says one occurrence gets a sentence, and the one occurrence of "a reservation
broke a program" would be `Stream`, which has not happened. Close `bs@` and the "unreachable namespace" question by
recording that both are already true (items 1–2 above). **C** is the option I would reject: the Elixir and Gleam
probes both show the failure it invites, and the closed-by-construction environment (67) is what makes A cheap.

## What I could not measure

- Scala, Rust, Haskell: no toolchains here; the ticket's research table was not re-run.
- Whether any *external* B# program already declares a planned reserved name; only this repo's 163 files were counted.
- Elm: installed, cannot build offline (registry blocked).
