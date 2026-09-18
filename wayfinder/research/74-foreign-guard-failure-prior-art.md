# 74 — prior art: what a generated boundary check's failure becomes

Research for [issue 74](../issues/74-a-failed-guard-under-a-declared-channel.md) / ENG-362.

**The fork being surveyed.** A compiler generates a runtime check at a foreign-function boundary
from a declared return type. The same declaration also names a failure channel. When the generated
check refuses the value, does the program **crash**, or does the refusal arrive **as a value through
that declared channel**?

In beam-sharp the two arms are one line apart in `bs_emit`, both measured in the ticket:
`return_guard(L, foreign_wrapper(L, Call), Ty)` crashes; `foreign_wrapper(L, return_guard(L, Call, Ty))`
returns `(:error, (:error, (:case_clause, …)))`, which `examples/Foreign`'s `Diagnose` cannot tell
from a `badarg` the callee actually raised.

**Short answer: nobody on the BEAM has faced this, because nobody on the BEAM generates the check.**
Gleam is the only BEAM language with the declaration construct and it emits a bare forwarding call.
The two useful findings are off to the side: **Elm** generates the check and answers the fork
(the failure does *not* enter the declared channel, and the channelled declaration is refused
outright); and **OTP's own `rpc` → `erpc` migration** is the value-vs-raise question decided on this
platform, with the reason documented and the older choice named as one OTP cannot fix.

## Method and provenance

| Mark | Meaning |
|---|---|
| **doc** | Official language documentation or reference manual |
| **src** | Source code read at a pinned tag or commit |
| **pkg** | Package source downloaded from hex.pm at a pinned version |
| **repo** | Measurement already made in this repository; cited, not redone |
| **infer** | A one-step consequence of a cited fact, labelled as such |

Versions pinned. Everything fetched 2026-09-18/19.

| Artefact | Version / commit |
|---|---|
| `gleam-lang/gleam` | tag `v1.18.1` (released 2026-08-01) |
| `gleam_erlang` (hex) | 1.3.0 — the current and latest release |
| `lfe/lfe` | branch `develop`, commit `38150ec`, 2026-07-11 |
| `type_check` (Elixir, hex) | 0.13.7 |
| `erlang/otp` | tag `OTP-28.5`, `lib/kernel/src/rpc.erl` and `lib/kernel/src/erpc.erl` |
| `leostera/caramel` | archived; branch `main`; last push 2023-09-25 |
| `purescript/documentation` | branch `master`, `guides/FFI.md` |
| Zod | 4 (zod.dev/api, banner "Zod 4.6") |

**Every quotation below was taken from the raw source file or package tarball and grepped verbatim**,
not from a rendered documentation page. The `rpc` and `erpc` passages are `-moduledoc` text in the
OTP sources at the pinned tag, which is what erlang.org renders.

### What this file does not redo

- Gleam's `@external` publishing a false `-spec` — measured locally at Gleam 1.18.1 / OTP 28 in
  [issue 18](../issues/18-boundary-defence.md) (`prototypes/18c_gleam_ffi_trust.gleam`): declared
  `-> Int` returned `41.5`, declared `-> List(Order)` yielded a binary bound bare by the generated
  consumer's clause head.
- `gleam_erlang` v1.3.0's nine hand-written `try`/`catch` sites and the absence of `rescue` from the
  surface — [issue 15 §4](../issues/15-error-model.md).
- Which exception classes a wrapper catches, and why narrowing it is wrong —
  [issue 15 §5](../issues/15-error-model.md), `prototypes/15d_which_classes_a_wrapper_catches.erl`.
- That purerl validates nothing at an FFI boundary — [research 06](06-interop-surface.md), carried
  into [research 21](21-escape-hatch-precedents.md) and issue 18.
- Elm's admissible port payload set and generated decoders —
  [research 18](18-elm-port-validation.md). §5 below adds two readings of that file that the fork
  makes load-bearing and that 18 did not draw out.

---

## 1 — Gleam

**Does a generated check exist? No.** Read at tag `v1.18.1`, `compiler-core/src/erlang.rs`, the
`module_function` arm that handles an external: it opens a function of the declared arity, starts a
remote call to the external module and function, passes each argument through, and closes. That is
the whole body. There is no guard, no `try`, no wrapper **src**.

```rust
Some((module, external_function_name, _location)) => {
    let arguments = self.function_arguments_names(&function.arguments, true).collect_vec();
    let open_function = builder.start_function(&function_name, arity, arguments.clone());
    let call = builder.start_remote_call(ErlangModuleName::new(module), external_function_name);
    for argument in arguments { builder.variable(&argument); }
    builder.end_call(call);
    builder.end_function(open_function);
}
```

A search of the same file for emitted runtime type tests (`is_integer`, `is_binary`, `try`, `catch`)
finds none associated with external calls. The only `erlang:error` calls the backend emits are for
Gleam's own constructs — `todo`, `panic`, `assert`, `let assert` **src**. Issue 18's local
measurement at the same version agrees: the generated body is one line **repo**.

**So Gleam never reaches the fork.** It has the declaration construct — an `@external` whose declared
return type may be `Result(a, e)` — and it emits nothing that could refuse a value. A wrong-shaped
return therefore either fails **far from the site**, as a `case_clause` or `badarith` wherever
ordinary Gleam code first depends on the shape, or **never fails at all** — which is what issue 18's
probe measured: the generated consumer's clause head tested the tag and the arity, bound the payload
bare, matched, and handed a binary through where an `Int` was declared **repo**. Under either
outcome it does not become an `Error(…)` **infer, one step from the src and repo facts above**.

**Gleam states the position in its own library docs**, which is the useful part. `gleam_erlang` 1.3.0,
`src/gleam/erlang/atom.gleam`, the doc comment on `decoder()` **pkg**:

> You almost certainly should not use this to work with externally defined functions. They return
> known types, so you should define the external functions with the correct types, defining wrapper
> functions in Erlang if the external types cannot be mapped directly onto Gleam types.

Trust the declaration; where the shape does not match, hand-write an Erlang wrapper. That is
Gleam's answer to the whole problem beam-sharp's F42 guard exists for, and it is an instruction to
the programmer rather than a compiler behaviour.

**The one place Gleam does put a `try` under a declared `Result` is hand-written.** `atom.gleam`
declares `pub fn get(a: String) -> Result(Atom, Nil)` against `gleam_erlang_ffi:atom_from_string`,
whose body is **pkg**:

```erlang
try {ok, binary_to_existing_atom(S)}
catch error:badarg -> {error, nil}
```

This is the channel arm — an exception converted to a value inside the declared channel — but the
thing caught is an exception **raised by the callee**, never a check's own refusal. The mapping from
`error:badarg` to `Error(Nil)` is a human's assertion, as issue 15 §4 already recorded. Gleam has no
generated refusal to route anywhere.

## 2 — Elixir

**No language construct declares a foreign function's type**, so there is nothing to violate and no
check to generate. Issue 18 states this and gives the reason: `@spec` is Dialyzer-only; NIFs and
ports return arbitrary terms; Elixir 1.19's set-theoretic checker infers from code at compile time
and has no FFI declaration to enforce **repo**. The `!`-suffix versus tuple-return convention is a
convention about functions an Elixir author writes, not a declaration about a foreign one.

**The one generated-check system on the platform is a library, `TypeCheck`.** Version 0.13.7 **doc**:

- `@spec!` wraps the function "with a runtime check which will check the input to **and result
  returned from** the function" — this is the `:enable_runtime_checks` option's own documentation,
  default `true`.
- A failed check **raises `TypeCheck.TypeError`**.
- The documented option list is `:overrides`, `:default_overrides`, `:enable_runtime_checks`,
  `:debug`. **None of them changes what a failure becomes.** The only choice offered is on or off.
- Where TypeCheck *does* offer a channel, it is a **separate, explicitly-called function**:
  `conforms/2` returns `{:ok, value} | {:error, %TypeCheck.TypeError{}}`, `conforms?/2` returns a
  boolean, `conforms!/2` raises. The same triple exists as `dynamic_conforms/2` and friends.

This is the shape worth carrying: the **implicit** check generated from a declaration raises; the
**explicit** check the programmer writes at a call site returns a result. TypeCheck never mixes
them, and offers no way to make `@spec!`'s failure arrive as a value.

**It is not a foreign-boundary mechanism.** The `:enable_runtime_checks` text is the evidence:
*"functions that contain a `@spec!` will be wrapped with a runtime check"* — it wraps a function
defined in the module being compiled, so it checks your own return, not a remote call's. It is the
closest BEAM analogue of F42's generated return guard, and it is at the wrong site.

*Unverified*: that no `TypeCheck` option outside the documented four alters failure behaviour. The
`TypeCheck.Options` doc page lists four; reading `lib/type_check/options.ex` at 0.13.7 would settle
whether an undocumented one exists.

## 3 — LFE

**LFE has a type-declaration form and the compiler turns it into an Erlang attribute and nothing
else.** `lfe/lfe` at `38150ec`, `src/lfe_codegen.erl` **src**:

```erlang
%% comp_function_specs(Func, Spec, Line) -> [AST].
%%  Compile a function specification to an attribute.

comp_function_specs([Name,Ar], Specs, Line) ->
    Sdef = {{Name,Ar},lfe_types:to_func_spec_list(Specs, Line)},
    [make_attribute(spec, Sdef, Line)].
```

`defspec` / `define-function-spec` is collected at `collect_mod_def` (line 122), stored as a meta
(line 237), and emitted by `comp_meta` as a `-spec` attribute (line 375). There is no other consumer.
The module's own header comment (line 24) says it "keep[s] type/spec/record declarations in the"
collected metas, which is the same route; **only the `spec` path was read**, and whether `deftype`
reaches `-type` by that identical path is inferred from the comment rather than measured.

`src/lfe_types.erl` exports `check_type_def/3`, `check_type_defs/3` and `check_func_spec_list/3` —
these are **compile-time well-formedness checks on the type expression itself**, returning
`{ok, Tvs}` or an error; the `is_integer/1` occurrences in that module are Erlang guards in the
compiler inspecting its own AST, not tests emitted into generated code **src**.

**So LFE's answer is Erlang's answer, by construction**: a spec is a Dialyzer input. LFE has no
foreign-declaration form distinct from an ordinary call — calling into Erlang is just calling a
function — so there is no boundary at which a check could be generated, and the fork is unposable.
This closes the one BEAM language the repo had not previously surveyed for the error model.

## 4 — Erlang / OTP

**`-spec` is static only.** The typespec chapter of the system documentation lists the purposes of
type information as documenting function interfaces, feeding bug-detection tools such as Dialyzer,
and being leveraged by documentation tools **doc**. No compiler option enabling runtime enforcement
appears there.

*Unverified*: whether the `sheriff` parse transform (which generated runtime checks from `-type`)
is still maintained. It was not examined; a hex.pm release listing plus a read of its transform
would settle it. It would be a library precedent of the same class as Elixir's `TypeCheck`, not a
language one.

**Erlang's one built-in boundary check confirms the shape of the gap**, already measured here:
`binary_to_term/2` with `safe` refuses atom-table exhaustion and passes a wrong-shaped term straight
through — it protects a resource, not a claim **repo** (issue 18).

### 4.1 `rpc:call` → `erpc:call` — the fork, decided on this platform, with the reason on the record

This is the most useful thing in this file and it is not about a generated check. It is about the
**other half** of ticket 74's question: whether a boundary failure should arrive as a value in the
return channel or be raised, and what goes wrong when it arrives as a value.

**`rpc:call/4` is the channel arm.** On failure it returns `{badrpc, Reason}` as an ordinary value.
`rpc.erl`'s `-moduledoc`, verbatim at `OTP-28.5`, lines 34-40 **src**:

> `rpc:call/4` and related functions make it difficult to distinguish
> between successful results, raised exceptions, and other errors. This
> behavior cannot be changed for compatibility reasons.
>
> The `m:erpc` module was introduced in Erlang/OTP 23 to provide an API
> that allows clear distinction between these different outcomes.

and at `call/4`'s own doc, line 455 **src**: *"If you want the ability to distinguish between
results, you may want to consider using the [`erpc:call()`] function from the `erpc` module
instead."* The enumerated failure cases (lines 463-473) include *"The called function returns a term
that matches `{'EXIT', _}`"* and *"The called function `throws` a term that matches `{'EXIT', _}`"* —
legitimate outcomes indistinguishable from an actual failure, which is why the behaviour is frozen
rather than fixed.

**`erpc:call/4` is the raise arm, with a tag.** `erpc.erl` at the same tag, lines 34-36 **src**:

> This is an enhanced subset of the operations provided by the `m:rpc` module.
> Enhanced in the sense that it makes it possible to distinguish between returned
> value, raised exceptions, and other errors.

and lines 203-206 **src**: *"The `call()` function only returns if the applied function successfully
returned without raising any uncaught exceptions, the operation did not time out, and no failures
occurred. In all other cases an exception is raised."* The enumeration that follows (lines 208-245)
is the finding:

- **`throw`** — the applied function's own `throw(Value)`, reason `Value` unchanged.
- **`exit`** — `{exception, ExitReason}` for the function's own `exit/1`; `{signal, ExitReason}`
  when the applying process was killed by a signal.
- **`error`** — and this class carries **two members that differ only in the reason's tag**:
  `{exception, ErrorReason, StackTrace}` for a runtime error raised *by the applied function*, and
  **`{erpc, ERpcErrorReason}`** for *"The `erpc` operation failed"* — `badarg`, `noconnection`,
  `system_limit`, `timeout`.

**Read against ticket 74.** `Diagnose`'s inability to tell a callee that raised `badarg` from a
callee that returned the wrong shape is the `{badrpc, Reason}` ambiguity, and OTP's verdict on that
ambiguity is that it is a defect it cannot repair. But `erpc`'s answer is not simply "raise": it is
**three categories kept apart** — the value, the callee's exception with its class preserved, and
the *mechanism's own* failure. And the mechanism's failure is not put in a different class from the
callee's error; it shares the `error` class and is separated **by the shape of the reason**,
`{erpc, _}` beside `{exception, _, _}`.

That is a shape ticket 74 has not priced. Its two measured arms are value and raise. **Neither tags
the guard's refusal apart from the callee's.** The crash arm collapses the mechanism's failure into
"the process dies"; the channel arm collapses it into the callee's own `(:error, term)` member,
which is precisely what makes `Diagnose` wrong. `erpc` says the two can share a class and still be
discriminable, if the generated failure's reason is a shape the callee cannot produce.

**What this is not.** `erpc` is a library boundary with a hand-written failure model, not a check
generated from a declared type, and the failure being categorised is the mechanism's (the node is
gone, the call timed out), not a type check's. It is precedent for *how to keep a boundary's own
failure distinguishable from the callee's*, not for whether to generate the check at all.

## 5 — Elm

Elm is the only system surveyed that **both** generates the check from a declared type **and** has a
result channel in the language. [Research 18](18-elm-port-validation.md) measured the mechanism at
0.19.1; two of its findings answer this ticket's fork directly and are drawn out here.

### 5.1 The channelled declaration is refused at the declaration

`checkPayload` in `compiler/src/Canonicalize/Effects.hs`, tag `0.19.1`, is a closed whitelist:
`Int`, `Float`, `Bool`, `String`, `Json.Encode.Value`, `List a`, `Array a`, `Maybe a`, `()`, 2- and
3-tuples, closed records, aliases dealiased first. Everything else is `UnsupportedType` **repo/src**.

Measured locally in research 18 §1.2: `port p : Result String Int -> Cmd msg` is **rejected**,
`UnsupportedType` — alongside `Char`, `Dict`, `Set` and every custom union including a payload-free
enum **repo (local)**.

So Elm takes the position ticket 74 explicitly put outside its scope under *"Not decided here"*:
**you cannot declare a boundary type that names an error channel.** Elm can hold that line because
its whitelist is a closed set of structurally decidable shapes and `Result` is simply not on it;
beam-sharp's `result<T, foreign_error>` is decidable by one BEAM guard per member, so the same
reasoning does not refuse it. Elm is precedent that the position exists and was chosen, not that it
transplants.

### 5.2 The one declarable type with an absence member does not absorb the failure

`Maybe a` **is** admissible, and the compiler generates for it **repo/src**:

```js
$elm$json$Json$Decode$oneOf([
    $elm$json$Json$Decode$null($elm$core$Maybe$Nothing),
    A2($elm$json$Json$Decode$map, $elm$core$Maybe$Just, $elm$json$Json$Decode$int)
])
```

Research 18 §3.2 probed it, three build modes, and recorded **repo (local)**:

```
OK    takesMaybe <- null
OK    takesMaybe <- 7
THROW takesMaybe <- "x"
```

`"x"` does not become `Nothing`. The declared channel absorbs exactly the one value the decoder was
told means absence — `null` — and a value that fails the check **throws**. That is the fork, faced,
and answered: **the generated check's failure does not enter the declared channel.** It is the
narrowest possible version of the question (absence, not error) but it is a real instance of it.

### 5.3 The precise limit on quoting Elm here

The throw is `_Debug_crash(4, …)`, a JavaScript `Error` raised synchronously out of the
`app.ports.<name>.send(...)` call **repo/src**. Research 18 §3.1 is explicit: "the Elm program is
undamaged because nothing entered it. Elm code has no way to observe that it happened."

**It lands on the supplier's side of the boundary.** In beam-sharp the crash arm kills the
*consumer's* process. Elm is therefore precedent for **"a generated check's failure is not a channel
value"**, and it is not precedent for **"crash the receiver"**. It answers the first half of Q1 and
is silent on what the BEAM's process semantics should do with the second.

Research 18 also records that Elm's checking boundary is still unsound in a way beam-sharp does not
inherit — `1e300` through an `Int` port — so Elm's guarantee is narrower than the compiler's error
text claims **repo**.

## 6 — Purerl, Caramel, and the dormant BEAM languages

**Purerl / PureScript-on-Erlang: no check, and the language says so.** Research 06 established that
purerl validates nothing at an FFI boundary, carried into research 21 and issue 18 **repo**. The
PureScript FFI guide states the position for the upstream language: using the FFI will "void the
warranty" of the typechecker to a certain extent, and "you can enforce as little or as much type
safety as you like when using the FFI" **doc**. Its recommended remedy is `Foreign` plus an
explicitly-called read — the decoder shape of §7, whose failure lands in an error channel **because
the programmer wrote the call**. `foreign import`'s own declared type is never checked.

**Caramel: archived, and its claim is "zero cost".** `leostera/caramel`, archived, last push
2023-09-25 **src (repo metadata)**. Its README advertises "Zero-cost type-safe interop with most
existing Erlang and Elixir code" **doc** — zero cost is a claim of no emitted check, and nothing in
the README describes runtime validation at an external boundary.
*Unverified*: that the Caramel compiler emits no check. Only the README was read. Grepping the
archived tree's OCaml-to-Erlang codegen for emitted guards would settle it. Given the archive date
and research 03's finding that Caramel is dormant **repo**, it is not worth more.

**Hamler and Alpaca** are dormant and were surveyed for a different question in
[research 03](03-prior-art-static-multiclause.md) **repo**; neither was re-examined here and neither
is claimed as a precedent either way.

## 7 — Off-platform: explicit decoders, TypeScript / OCaml / F#

These are the analogue of beam-sharp's `ValidateAs<T>` (ticket 11), **not** of F42's generated guard.
The distinction matters or the section becomes padding: in every one of them the check runs because
the programmer wrote a call, and the failure's destination is chosen **at that call site, by picking
a function name**.

- **Zod 4**: `.parse()` throws on invalid input; `.safeParse()` returns `{ success: true, data }` or
  `{ success: false, error }` **doc**. The exception's type (`ZodError`) is stated across the API
  reference's error pages rather than on the parsing page, and was **not confirmed on a single
  page**; the throwing-versus-returning split is what this section relies on and that is documented.
- **Elixir `TypeCheck`**: `conforms!/2` raises, `conforms/2` returns `{:ok, _} | {:error, _}`,
  `conforms?/2` returns a boolean — §2 **doc**.
- **PureScript `Foreign`**: an explicitly-called read returning an error-carrying type — §6 **doc**.

The shape across all of them: **a library that generates or runs a check ships both endings and
makes the caller choose by name.** None hides the choice inside a declaration. That is the same
observation as §2's implicit-raises / explicit-returns split, from the other side, and it is what
makes beam-sharp's question hard: F42's guard is generated from a declaration, so there is no call
site at which an author could pick.

*Looked at and not used*: gRPC's status codes, on the theory that a generated decode failure and an
application error share one status channel with reserved codes. The public status-code
documentation defines `INTERNAL` as "some invariants expected by the underlying system have been
broken" and `DATA_LOSS` as "unrecoverable data loss or corruption" **doc**, but does not state which
code a malformed response produces or confirm that library-generated and application codes share one
channel. **Unverified**; reading the gRPC protocol specification or a generated stub's deserialisation
path would settle it. It is not cited as precedent.

## Claim → source

| # | Claim | Source | Mark |
|---|---|---|---|
| 1 | Gleam emits an external as a bare forwarding remote call — no guard, no try/catch | `gleam-lang/gleam` `v1.18.1`, `compiler-core/src/erlang.rs`, `module_function` external arm | src |
| 2 | Gleam's backend emits `erlang:error` only for `todo`/`panic`/`assert`/`let assert`, never around an external | same file, searched for `try`/`catch`/`is_integer`/`is_binary` | src |
| 3 | Gleam publishes the declared type as a `-spec`; `-> Int` returned `41.5` | [issue 18](../issues/18-boundary-defence.md), `prototypes/18c_gleam_ffi_trust.gleam`, Gleam 1.18.1 / OTP 28 | repo |
| 4 | Gleam's own docs tell you to trust the declaration and hand-write an Erlang wrapper when shapes do not match | `gleam_erlang` 1.3.0, `src/gleam/erlang/atom.gleam`, `decoder()` doc comment | pkg |
| 5 | `gleam_erlang`'s `try`/`catch` under a declared `Result` is hand-written and catches a callee exception, not a check | `gleam_erlang` 1.3.0, `src/gleam_erlang_ffi.erl:13-14`; issue 15 §4 | pkg, repo |
| 6 | `gleam_erlang` 1.3.0 is the current release and ships no `rescue` module | hex.pm API, package `gleam_erlang`; tarball module listing | pkg |
| 7 | Elixir has no construct declaring a foreign function's type | [issue 18](../issues/18-boundary-defence.md) | repo |
| 8 | `TypeCheck` `@spec!` wraps input **and result**; a violation raises `TypeCheck.TypeError` | `type_check` 0.13.7, `TypeCheck` and `TypeCheck.Options` doc pages | doc |
| 9 | `TypeCheck`'s documented options are `:overrides`, `:default_overrides`, `:enable_runtime_checks`, `:debug`; none changes what a failure becomes | `TypeCheck.Options` 0.13.7 | doc |
| 10 | `TypeCheck` offers the channel only via explicitly-called `conforms/2` vs `conforms!/2` | `TypeCheck` 0.13.7 | doc |
| 11 | LFE's `defspec` compiles to an Erlang `-spec` attribute and nothing else | `lfe/lfe` `38150ec`, `src/lfe_codegen.erl:122,237,375,415-418` | src |
| 12 | LFE's `lfe_types:check_*` are compile-time well-formedness checks on the type expression | `lfe/lfe` `38150ec`, `src/lfe_types.erl:27-34,247,257` | src |
| 13 | Erlang `-spec` is for documentation, Dialyzer and doc tools; no runtime enforcement option documented | erlang.org, System Documentation, Types and Function Specifications | doc |
| 14 | `rpc:call/4` returns `{badrpc, Reason}`; OTP documents that this makes results, exceptions and errors hard to distinguish, that it cannot be changed for compatibility reasons, and that `erpc` was introduced in OTP 23 for the distinction | `erlang/otp` `OTP-28.5`, `lib/kernel/src/rpc.erl:34-40,455,463-473` (`-moduledoc`), grepped verbatim | src |
| 15 | `erpc:call/4` raises instead of returning; re-raises the callee's exception with class preserved; puts its own failures in the `error` class as `{erpc, Reason}` beside the callee's `{exception, Reason, Stack}`; is described as enhanced for exactly this distinguishability | `erlang/otp` `OTP-28.5`, `lib/kernel/src/erpc.erl:34-36,203-245`, grepped verbatim | src |
| 16 | `binary_to_term/2` `safe` protects a resource, not a claim | [issue 18](../issues/18-boundary-defence.md), local, OTP 28 | repo |
| 17 | Elm rejects `Result String Int` as a port payload (`UnsupportedType`) | [research 18](18-elm-port-validation.md) §1.2, local, 0.19.1 | repo |
| 18 | Elm's admissible payload set is a closed whitelist in `checkPayload` | [research 18](18-elm-port-validation.md) §1.1; `elm/compiler` tag `0.19.1`, `Canonicalize/Effects.hs` | repo, src |
| 19 | A `Maybe Int` port decodes `null` to `Nothing`, `7` to `Just 7`, and **throws** on `"x"` | [research 18](18-elm-port-validation.md) §2.2, §3.2, local, 0.19.1, all three build modes | repo |
| 20 | Elm's failure is a JS `Error` out of `send()`, on the supplier's side; Elm code cannot observe it | [research 18](18-elm-port-validation.md) §3.1; `elm/core` `Elm/Kernel/Platform.js`, `_Debug_crash(4, …)` | repo, src |
| 21 | Purerl validates nothing at an FFI boundary | [research 06](06-interop-surface.md), carried into research 21 and issue 18 | repo |
| 22 | PureScript's FFI guide, verbatim: the FFI will "void the warranty" of the typechecker to a certain extent; "you can enforce as little or as much type safety as you like when using the FFI" | `purescript/documentation` `master`, `guides/FFI.md:11,74`, grepped verbatim | doc |
| 23 | Caramel is archived, last push 2023-09-25; README line 22, verbatim: "Zero-cost type-safe interop with most existing Erlang and Elixir code" | GitHub API for `leostera/caramel`; `main`/`README.md:22`, grepped verbatim | src, doc |
| 24 | Zod 4: `.parse()` throws on invalid input, `.safeParse()` returns a success/error object | zod.dev/api, Zod 4 | doc |
| 25 | gRPC `INTERNAL` = "some invariants expected by the underlying system have been broken"; `DATA_LOSS` = "unrecoverable data loss or corruption" | grpc.io, Status codes | doc |

**Marked unverified in the body**: whether an undocumented `TypeCheck` option alters failure
behaviour (§2); whether LFE's `deftype` reaches `-type` by the same path the `spec` route was read
on (§3); whether `sheriff` is still maintained (§4); whether Caramel's codegen emits any check (§6);
Zod's exception type name on a single page (§7); which gRPC status code a malformed response
produces and whether it shares the application's channel (§7). Each says what would settle it.

## What none of them answers

**The configuration itself is unprecedented.** No surveyed system generates an implicit runtime check
on a **foreign return** whose **declared type also names a failure channel**. The two properties are
never both present:

| | generates the check | declares a foreign type | declares a failure channel at that boundary |
|---|---|---|---|
| Gleam | no | yes | yes (`Result`) — but nothing to route |
| Elixir + `TypeCheck` | yes | no (own functions only) | no |
| LFE, Erlang | no | no | — |
| Purerl, Caramel | no | yes | no |
| Elm ports | **yes** | yes | **refused at the declaration** |

**Four things the survey leaves open, in descending order of how much they cost ticket 74.**

**1. What the consumer's process should do.** Elm answers "not the channel" and throws, but the
throw lands on the *supplier's* side of the boundary and the Elm program is untouched — research 18
§3.1 says so in as many words. beam-sharp's crash arm kills the **consumer's** process, under
supervision, on a platform with let-it-crash semantics Elm does not have. No surveyed system's
generated check fails *inside the calling process*. The half of Q1 that asks what a BEAM process
should do has no precedent at all.

**2. The vocabulary collision is beam-sharp's alone.** `foreign_error` is spelled in the *platform's*
exception classes — `(:error, term) | (:throw, term) | (:exit, term)`. Every other language's
foreign error channel is spelled in its own vocabulary: Gleam's is a hand-written `Result(Atom, Nil)`,
Elm's is a `Result` the programmer builds from `Json.Decode`, TypeCheck's is a `%TypeCheck.TypeError{}`.
That is why nobody else's channel arm produces an ambiguity: their check-failure member could not be
confused with a callee's exception, because the channel is not made of exceptions. beam-sharp's is.
The ticket's `(:error, (:error, (:case_clause, …)))` — a compiler-originated `case_clause` wearing
the callee's class tag — is a collision no surveyed design could have had, and no surveyed design
has ruled on it.

**3. The third arm nobody in the ticket has priced.** OTP faced value-versus-raise at a boundary,
ruled against the value (`{badrpc, Reason}`, "cannot be changed for compatibility reasons"), and
chose **raise with three categories kept apart**: the value, the callee's exception with its class
preserved, and the mechanism's own failure — the last of these sharing the `error` class with the
callee's error and separated by the reason's shape, `{erpc, _}` beside `{exception, _, _}`. Ticket
74's two measured arms are value and raise. **Neither tags the guard's refusal apart from the
callee's**, and the channel arm's whole cost is that it does not. Whether a distinguishable member —
something a `Diagnose` clause head could match and a callee cannot forge — changes that cost is a
question this survey raises and does not answer, because `erpc`'s categories separate a *mechanism*
failing from a callee failing, not a *type check refusing* from either.

**4. Refusing the declaration is a live third position with one precedent and no transplant.** Elm
refuses `Result String Int` at the port declaration — the position ticket 74 filed under *"Not
decided here"*. Elm can hold it because its whitelist is closed and `Result` is simply absent from a
hard-coded list. beam-sharp's `result<binary, foreign_error>` is decidable by one BEAM guard per
member, which is exactly the criterion issue 18 used to admit it. So Elm establishes that a language
has chosen this position; it does not supply a reason beam-sharp could reuse, and ticket 74's own
statement of the limit — the compiler cannot know which foreign functions throw — is untouched by
anything in this file.
