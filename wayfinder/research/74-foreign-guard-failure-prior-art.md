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
The three useful findings are off to the side: **Elm** generates the check and answers the fork
(the failure does *not* enter the declared channel, and the channelled declaration is refused
outright); **OTP's own `rpc` → `erpc` migration** is the value-vs-raise question decided on this
platform, with the reason documented and the older choice named as one OTP cannot fix; and
**C#/.NET P/Invoke** — the tier-1 source, §8 — checks the *declaration* and never the *value*,
distinguishes the runtime's own failure from the callee's by the exception hierarchy, and keeps a
foreign return's channel and its success shape out of the same declared type (`PreserveSig`), so it
never has beam-sharp's collision to resolve.

**Section order is the order the survey was run in, not the borrow heuristic's order.** C# is tier 1
and it is §8 because it was added in a second pass; read §8 first if reading for precedent rather
than for the BEAM.

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
| `dotnet/runtime` | tag `v10.0.12`, `src/libraries/System.Private.CoreLib/src/System/…` (re-checked against `v9.0.0`: identical) |
| .NET documentation | learn.microsoft.com, default moniker `net-10.0`; the P/Invoke source generator is .NET 7+ |
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

## 8 — C# / .NET: P/Invoke return marshalling (tier 1)

`[DllImport]` and `[LibraryImport]` are C#'s direct analogue of a beam-sharp foreign declaration: a
managed signature asserting a type over a value the runtime did not produce. The same fork is
posable, and .NET answers it four times over — but never in the place ticket 74 is standing.

**The one-line summary: .NET checks the declaration, never the value.** Every refusal found is about
a *directive the marshaller cannot implement*, detected when the stub is built. No documented
mechanism inspects what native code actually returned and compares it against the declared managed
type.

### 8.1 The refusals are all declaration-level

**`MarshalDirectiveException`**, which is the exception usually reached for here, is not a value
check. `dotnet/runtime` `v10.0.12`,
`src/libraries/System.Private.CoreLib/src/System/Runtime/InteropServices/MarshalDirectiveException.cs`
**src**:

> The exception that is thrown by the marshaler when it encounters a `MarshalAsAttribute` it does
> not support.

— on `public class MarshalDirectiveException : SystemException`.

A `MarshalAsAttribute` it does not support — a **declaration the marshaller cannot build a stub
for**, not a native value that failed a test. That much the doc comment states.

***When* it fires is unverified.** The natural reading is "when the stub is constructed", which for
`DllImport` is at run time because the IL stub is generated then (§8.5) — but no source read here
says so, and stub construction may be lazy, so the moment relative to the first call is not
established **infer**. Reading `src/coreclr/vm/dllimport.cpp`'s stub-generation path would settle
it. Nothing in §8 depends on the timing; what it depends on is that the thing refused is a
directive.

**Blittable returns get no check because they get no marshalling.**
learn.microsoft.com, *Blittable and Non-Blittable Types*, verbatim **doc**:

> Most data types have a common representation in both managed and unmanaged memory and don't
> require special handling by the interop marshaller. These types are called *blittable types*
> because they don't require conversion when they're passed between managed and unmanaged code.

The blittable list is `Byte`, `SByte`, `Int16`, `UInt16`, `Int32`, `UInt32`, `Int64`, `UInt64`,
`IntPtr`, `UIntPtr`, `Single`, `Double`, plus one-dimensional arrays of blittable primitives and
formatted value types containing only blittable types **doc**. **That is most of what a foreign
function returns**, and for all of it the declared managed type is an unchecked assertion.

**The one return-position refusal is also about the declaration, and it is return-specific** — the
same page, verbatim **doc**:

> Structures that are returned from platform invoke calls must be blittable types. Platform invoke
> doesn't support nonblittable structures as return types.

This is the shape of Elm's `checkPayload` (§5.1) and of ticket 74's out-of-scope third position:
**a closed admissible set at the return position, enforced against the declaration.** C# reaches it
for a different reason than Elm does — Elm's set is closed because it needs a decidable decoder,
C#'s because a nonblittable return has no defined ownership story for the native memory — but the
mechanism is the same, and it is two tier-ranked languages arriving at "refuse the declaration".

### 8.2 Where it corrupts silently — outcome 3 in C#'s vocabulary

Follow §8.1's two facts together. A `[DllImport]` declaring `static extern int Count();` over a
native function that returns a `double`, or a pointer, is a blittable-to-blittable declaration: no
conversion is performed, so nothing can refuse it. The caller receives whatever the calling
convention puts in the return position, typed as `int`.

**Nothing in the documentation read for this file names an exception for that case**, and the
marshalling rules are stated as conversions rather than as validations. If that entailment holds,
it **would be** ticket 06's outcome 3 — a value from outside breaking the types, silently — in the
tier-1 language, at the return position, as the *default* for the commonest return types.

*Unverified, and it matters*: I did not find a documentation sentence declaring this undefined
behaviour, and I did not run it. The claim above is what the cited marshalling rules **entail**, not
what a doc states **infer**. A ten-line C# program calling a `double`-returning native function
through an `int`-declared `DllImport` would settle exactly what arrives; that measurement was not
made here and should not be asserted without it.

### 8.3 The runtime's own failure *is* tagged apart from the callee's — by the type hierarchy

This is the `erpc` question (§4.1) restated, and .NET answers it the same way by a different
mechanism. Three class declarations, `dotnet/runtime` `v10.0.12`, all verbatim **src**:

```csharp
/// The base exception type for all COM interop exceptions and structured
/// exception handling (SEH) exceptions.
public class ExternalException : SystemException

/// Exception for Structured Exception Handler exceptions.
public class SEHException : ExternalException

/// The exception that is thrown by the marshaler when it encounters a
/// <see cref="MarshalAsAttribute" /> it does not support.
public class MarshalDirectiveException : SystemException
```

**The callee's failures and the runtime's own failure are siblings, not relatives.** Everything
coming *out of* native code — COM interop failures, structured exceptions — sits under
**Measured, not only cited** — reflected over the shipped assemblies on the .NET SDK installed on
this machine, `9.0.306`:

```
ExternalException          ExternalException -> SystemException -> Exception -> Object
SEHException               SEHException -> ExternalException -> SystemException -> Exception -> Object
COMException               COMException -> ExternalException -> SystemException -> Exception -> Object
MarshalDirectiveException  MarshalDirectiveException -> SystemException -> Exception -> Object

catch (ExternalException) catches MarshalDirectiveException?  False
catch (ExternalException) catches SEHException?               True
```

`ExternalException`. The marshaller's own complaint sits directly under `SystemException`, outside
that subtree. A `catch (ExternalException)` catches what the callee did and does **not** catch what
the marshaller refused.

So .NET and OTP answer the same question the same way by different means: OTP separates them **by
the shape of the reason** within one `error` class (`{erpc, _}` beside `{exception, _, _}`), .NET
separates them **by subtyping**. Two tiers, two platforms, one answer: *a boundary mechanism's own
failure must be discriminable from the callee's*. That is now the best-supported finding in this
file, and it is the thing neither of ticket 74's measured arms does.

*Unverified*: whether a native access violation is catchable as an `SEHException` on .NET Core, or
whether the process fails fast. .NET Framework had `legacyCorruptedStateExceptionsPolicy`; what
.NET 10 does was not confirmed and is not relied on above — the hierarchy claim stands on the three
class declarations alone, which is all §8.3 asserts.

### 8.4 `PreserveSig`: the channel is either the whole return or absent from it — never both

C# has the fork, and the important part is **not** that both arms ship. It is that the two arms are
**two different managed signatures**, not one signature with a switch. The declared return type is
either the failure channel entirely, or the success member with no failure channel in it at all.
learn.microsoft.com, `DllImportAttribute.PreserveSig`, Remarks, verbatim **doc**:

> Set the `PreserveSig` field to `true` to translate unmanaged signatures with `HRESULT` values
> directly; set it to `false` to automatically convert `HRESULT` return values to exceptions. By
> default, the `PreserveSig` field is `true`.
>
> When `true`, the managed method signature returns an integer value that contains the `HRESULT`
> value. In this case, you must manually inspect the return value and respond accordingly in your
> application.
>
> When you set the `PreserveSig` field to `false`, the managed method signature has a void return
> type or the type of the last unmanaged `[out, retval]` parameter. When the unmanaged method
> produces an `HRESULT`, the runtime automatically ignores a return value of `S_OK` (or 0) and does
> not throw an exception. For `HRESULT`s other than `S_OK`, the runtime automatically throws an
> exception that corresponds to the `HRESULT`.

and the field's own summary: *"Indicates whether unmanaged methods that have `HRESULT` return values
are directly translated or whether `HRESULT` return values are automatically converted to
exceptions"* **doc**. The defaults differ by spelling: the `DllImport` field defaults to `true`
(value), while `PreserveSigAttribute` defaults to `false` (exception) — *"in contrast to the
`PreserveSig` field, the default value for the attribute is `false`"* **doc**.

**Three things to take, and one not to.**

**Take: the two arms are two signatures, and neither holds both shapes.** Under `true` the declared
return **is** the channel — an `int` carrying the `HRESULT`, which the author must inspect, with
nothing generated. Under `false` the declared return is `void` or the `[out, retval]` type — **the
success member only** — and the channel has left the signature entirely, back into the callee's
protocol. **At no point does one declared return type contain both the success shape and the
failure shape.** That is exactly the configuration beam-sharp's `result<binary, foreign_error>`
creates, and it is what makes the guard's refusal collide with the callee's exceptions
(§*What none of them answers*, point 2). C# does not solve the collision; it never has it.

**Take: generated code does test the native return value and throw.** Under `PreserveSig = false`
the runtime compares the returned `HRESULT` against `S_OK` and throws on anything else. That is the
closest thing in the tier-1 language to F42's guard — generated code inspecting a foreign return and
raising. *Where* the exception surfaces is not stated: the Remarks say only that "the runtime
automatically throws an exception that corresponds to the `HRESULT`", and whether that lands in the
caller's own frame is **unverified**, not asserted here.

**Take: which arm you get is an author choice per declaration.** The docs give the criterion in one
sentence: *"You might decide to change the default error reporting behavior from `HRESULT`s to
exceptions in cases where exceptions better fit the error reporting structure of your
application"* **doc**.

**Take: the throw arm is Windows-centric and the current generated path has dropped it.**
`LibraryImport` has no `PreserveSig` equivalent — *"`PreserveSig` has no equivalent. This field was
a Windows-centric setting. The generated code always directly translates the signature"* **doc**
(§8.5's source page). So .NET 7+'s source-generated marshalling keeps **only the value arm** at the
return position: the `HRESULT` comes back as an `int` and the author inspects it. Tier 1's direction
of travel at this exact site is *away* from generated code converting a foreign return's failure
into a throw.

**Do not take: this is not a type check.** The `HRESULT` is a value the callee deliberately produced
under a documented convention, and the test is `== S_OK`. It is the callee's *declared failure
channel* being translated, not a *check refusing a wrong-shaped value*. So §8.4 is precedent for how
tier 1 arranges a foreign return's failure channel, and it is not precedent for what a guard's
refusal should become.

### 8.5 `LibraryImport` moves the refusal from run time to compile time

`DllImport`: *"the built-in interop system in the .NET runtime generates an IL stub—a stream of IL
instructions that is JIT-ed—at runtime… The IL stub handles marshalling of parameters and return
values"* **doc**.

`LibraryImport` (.NET 7+, source-generated): *"looks for `LibraryImportAttribute` on a `static` and
`partial` method to trigger compile-time source generation of marshalling code, removing the need
for the generation of an IL stub at runtime"*, and — the sentence that matters — *"Some settings for
`MarshalAsAttribute` aren't supported. The source generator will emit an error if you try to use
unsupported settings."* **doc**

The generator's diagnostics name the return position explicitly **doc**:

- **`SYSLIB1051`** "The specified type is not supported by source-generated p/invokes" —
  *"The generated source will not handle marshalling of the return value of method '{1}'."*
- **`SYSLIB1052`** "The specified configuration is not supported by source-generated p/invokes" —
  *"The specified configuration for the return value of method '{1}' is not supported by
  source-generated P/Invokes."*

**So the same refusal moved sites.** What `DllImport` delivers as a `MarshalDirectiveException` when
the stub is built, `LibraryImport` delivers as a build error against the declaration. This is the
direction of travel in the tier-1 language: an interop declaration the toolchain cannot honour is
refused **earlier**, and the thing being refused is still the declaration.

**It remains a declaration check, not a value check.** The generator emits marshalling code — the
docs describe it as generating *"an implementation … that handles marshalling of the `string`
parameter and return value"* **doc** — and nothing read here describes it emitting a test of what
came back.

*Unverified, and it is the one thing that would change §8's verdict*: whether generated
`LibraryImport` output contains any value-level test on the return beyond marshalling. Reading a
generated `*.g.cs` for a `LibraryImport` with a non-blittable return — or the generator's own
marshalling-shape source in `dotnet/runtime`
`src/libraries/System.Runtime.InteropServices/gen/LibraryImportGenerator/` — would settle it. The
compatibility differences are catalogued by the team at
`docs/design/libraries/LibraryImportGenerator/Compatibility.md` in `dotnet/runtime`, which was not
read.

### 8.6 `unsafe` and `Unsafe.As`: nothing checks

`dotnet/runtime` `v10.0.12`, `System/Runtime/CompilerServices/Unsafe.cs`, verbatim doc comment
**src**: *"Casts the given object to the specified type, **performs no dynamic type checking**."*
The method is `[Intrinsic]` and the body's commented IL is `ldarg.0; ret`. As expected, and one line
is all it is worth: C# has an in-language escape hatch that asserts a type over a value and emits
nothing, which is ticket 21's territory, not ticket 74's.

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
| 26 | `MarshalDirectiveException` is "thrown by the marshaler when it encounters a `MarshalAsAttribute` it does not support" — a directive, not a value | `dotnet/runtime` `v10.0.12`, `…/InteropServices/MarshalDirectiveException.cs`, doc comment verbatim | src |
| 27 | Blittable types "don't require conversion when they're passed between managed and unmanaged code"; the list includes every integer width, `IntPtr`/`UIntPtr`, `Single`, `Double` | learn.microsoft.com, *Blittable and Non-Blittable Types* (`ms.date` 2026-07-08) | doc |
| 28 | "Structures that are returned from platform invoke calls must be blittable types. Platform invoke doesn't support nonblittable structures as return types." | same page | doc |
| 29 | A wrong blittable return declaration is refused by nothing; no exception is documented for it | entailed by claims 26-28; **not measured, not stated by a doc** | infer |
| 30 | `ExternalException` is "the base exception type for all COM interop exceptions and structured exception handling (SEH) exceptions"; `SEHException : ExternalException`; `MarshalDirectiveException : SystemException` — a sibling outside that subtree | `dotnet/runtime` `v10.0.12`, `…/InteropServices/{ExternalException,SEHException,MarshalDirectiveException}.cs`, verbatim; re-checked identical at `v9.0.0` | src |
| 31 | `PreserveSig = true` returns the `HRESULT` as an `int` the author must inspect; `PreserveSig = false` makes the signature `void` or the `[out, retval]` type and the runtime "automatically throws an exception that corresponds to the `HRESULT`" for anything but `S_OK`. Field default `true`; `PreserveSigAttribute` default `false`. **The two arms are two different signatures**, not one with a switch | learn.microsoft.com, `DllImportAttribute.PreserveSig`, summary + Remarks, verbatim | doc |
| 31a | `LibraryImport` has no `PreserveSig` equivalent: "This field was a Windows-centric setting. The generated code always directly translates the signature" — so the source-generated path keeps only the value arm at the return position | learn.microsoft.com, *P/Invoke source generation*, "Differences from `DllImport`" | doc |
| 32 | `DllImport` generates a JIT-ed IL stub at run time; `LibraryImport` (.NET 7+) does "compile-time source generation of marshalling code" and "will emit an error if you try to use unsupported settings" | learn.microsoft.com, *P/Invoke source generation* | doc |
| 33 | `SYSLIB1051` and `SYSLIB1052` name the **return value** of the method as a refusable position for the source generator | learn.microsoft.com, *SYSLIB diagnostics for Microsoft.Interop.LibraryImportGenerator* | doc |
| 34 | `Unsafe.As` "performs no dynamic type checking"; `[Intrinsic]`, commented IL `ldarg.0; ret` | `dotnet/runtime` `v10.0.12`, `…/CompilerServices/Unsafe.cs:54-70`, verbatim | src |

**Marked unverified in the body**: whether an undocumented `TypeCheck` option alters failure
behaviour (§2); whether LFE's `deftype` reaches `-type` by the same path the `spec` route was read
on (§3); whether `sheriff` is still maintained (§4); whether Caramel's codegen emits any check (§6);
Zod's exception type name on a single page (§7); which gRPC status code a malformed response
produces and whether it shares the application's channel (§7); when exactly `MarshalDirectiveException`
fires relative to the first call (§8.1); what a wrong blittable `DllImport` return actually yields —
entailed by the cited rules but **not measured** (§8.2); whether a native access violation is
catchable as an `SEHException` on .NET 10 (§8.3); and whether `LibraryImport`'s generated output
contains any value-level test on the return (§8.5). Each says what would settle it.

### §8 closing item: the generated `.g.cs`, measured

The section's one open item — whether `LibraryImport`'s generated code contains a return-value
test beyond marshalling — was the only finding that could change its verdict. It is now measured
rather than entailed. Built with `EmitCompilerGeneratedFiles` on SDK `9.0.306`, generator
`Microsoft.Interop.LibraryImportGenerator 9.0.12.47515`, against two declarations:

**A blittable return gets no stub at all.** For `[LibraryImport("libc", EntryPoint = "abs")]
internal static partial int Abs(int v)` the generator emits only:

```csharp
[global::System.Runtime.InteropServices.DllImportAttribute("libc", EntryPoint = "abs", ExactSpelling = true)]
internal static extern partial int Abs(int v);
```

No body, no conversion, no test. The declared `int` is a claim about a value nothing inspects.

**A non-blittable return gets marshalling and nothing else.** For a UTF-8 `string` return the
generated body is setup, call, convert, free — the whole of the return handling being:

```csharp
__retVal = global::System.Runtime.InteropServices.Marshalling.Utf8StringMarshaller.ConvertToManaged(__retVal_native);
```

There is no verdict anywhere in the stub: nothing can fail the value, so nothing needs a class.
**§8's verdict stands as measured** — tier 1 generates a converter, never a checker.

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
| C# `DllImport` / `LibraryImport` | **declaration only, never the value** | yes | **kept out of the signature** (`PreserveSig`) |

**Tier 1 does not close it either, and the way it fails to is informative.** C# has the construct,
has both arms of value-versus-throw, and has a generated test that raises — and still never reaches
ticket 74's question, because it never checks a returned value against a declared type. Its
refusals are all about the declaration, and where it *does* convert a failure into a throw
(`PreserveSig = false`) the thing converted is the callee's own protocol, not a check's verdict.

**Five things the survey leaves open, in descending order of how much they cost ticket 74.**

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

**And tier 1 avoids the collision structurally rather than by choosing an arm.** Under
`PreserveSig = false` the C# signature is the *success member only* — `void` or the `[out, retval]`
type — and the failure channel stays in the callee's protocol, never in the declared type (§8.4).
Under `PreserveSig = true` the channel is the whole declared return, an `int` the author inspects,
and nothing is generated. Either way, **the declared type never contains both the success shape and
the failure shape at once**, which is exactly the configuration that produces beam-sharp's
ambiguity. That is not an answer to Q1, but it is the one structural alternative the survey found
to having the collision at all, and it costs the thing `result<T, foreign_error>` was built to buy.

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

**This is the survey's best-supported finding, because tier 1 reached it independently.** .NET puts
everything coming out of native code under `ExternalException` and its own marshalling complaint
outside that subtree, so `catch (ExternalException)` catches the callee's failures and not the
runtime's (§8.3). OTP does it by the reason's shape, .NET by subtyping; two platforms, two
mechanisms, one rule — **a boundary mechanism's own failure must be discriminable from the
callee's**. Both of ticket 74's measured arms break that rule, the channel arm visibly and the
crash arm by discarding the distinction along with the process.

**4. Refusing the declaration is a live third position with two precedents and no transplant.** Elm
refuses `Result String Int` at the port declaration, and C# refuses a nonblittable struct as a
P/Invoke return — *"Platform invoke doesn't support nonblittable structures as return types"*. Both
are closed admissible sets at the return position, enforced against the declaration, which is the
position ticket 74 filed under *"Not decided here"*. That it appears in tier 1 and tier 2
independently makes it more than an Elm curiosity.

**Neither supplies a reason beam-sharp could reuse.** Elm's set is closed because it needs a
decidable JSON decoder and `Result` is simply absent from a hard-coded list; C#'s because a
nonblittable return has no defined story for who owns the native memory. beam-sharp's
`result<binary, foreign_error>` is decidable by one BEAM guard per member, which is exactly the
criterion issue 18 used to admit it, and neither precedent's reason bites on it. And ticket 74's own
statement of the limit — the compiler cannot know which foreign functions throw — is untouched by
anything in this file.

**A fifth thing, raised by tier 1 and not by anything else: where the refusal fires.** `DllImport`
refuses a declaration it cannot honour at run time, when the IL stub is built; `LibraryImport`
refuses the same declaration at compile time, as `SYSLIB1051`/`SYSLIB1052`, naming the return
position (§8.5). The tier-1 language has been moving this refusal **earlier**, deliberately, across
a major version. beam-sharp's guard is emitted, so its refusals are run-time by construction —
but ticket 74's out-of-scope paragraph asks whether a channelled declaration whose members the
wrapper can never produce should be refused *at the declaration*, and that is the same move. The
survey does not answer it; it records that tier 1 made that move and thought it an improvement.
