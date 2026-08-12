# 13 — Compilation target decision

Type: grilling
Status: open
Blocked by: 02, 11

## Question

Given the survey in ticket 02 and the type system shape settled in ticket 11: which target
does the compiler emit — **Core Erlang**, the **Erlang Abstract Format**, or **BEAM
bytecode**?

State:

- The choice, and the decisive reason.
- What it costs in expressible semantics — particularly whether multi-clause dispatch is
  inherited from the target or must be synthesised by the frontend, and whether the
  frontend's clause-merging can be made to agree with the exhaustiveness checker.
- What it costs in tooling: stack traces, debugger, dialyzer, hot code loading, crash-report
  legibility.
- The exposure to OTP release churn, and the mitigation.
- Whether the choice is reversible later, and at what cost.

## What ticket 02 established

The survey is done; this ticket only has to choose. The decisive facts:

- **The Abstract Format expresses multi-clause heads natively** — a function form *is* a list
  of `{clause, ANNO, Patterns, Guards, Body}`, and the guard sequence keeps Erlang's full
  list-of-lists disjunction/conjunction structure. The frontend owes nothing.
- **Core Erlang costs a mechanical wrapper**, not a match compiler: one `fun` over fresh vars,
  one `case` over the value list, one clause each, order preserved, plus a synthesised failure
  clause. Perhaps fifty lines. Its `when` is also strictly *wider* than Erlang's.
- **BEAM bytecode costs a full match compiler.** That is the real cliff.
- **Choosing Core Erlang forfeits Erlang-side type publication.** A `-spec` survives the
  Abstract Format path by construction and is lost through `.core`; Dialyzer cannot read a
  `.core`-built beam at all, and fails *silently*. Ticket 06 recommends emitting `-spec`, so
  these two tickets must be decided together — or ticket 06's recommendation withdrawn.
- **Core Erlang is less stable than its reputation**: 2004 spec hosted outside OTP, OTP's own
  source saying the format can change between releases, spec-implementation drift (maps), and a
  wholesale backend replacement at OTP 27.
- **`from_abstr` allows an out-of-process frontend in any language** to emit `.abstr` text and
  shell out to `erlc` — which decouples this decision from the compiler's host language.

**A correction to an earlier note on this ticket.** It previously said "Gleam and LFE both
route through Core Erlang, so choosing the Abstract Format would be a departure from the
closest precedents." Ticket 02 contradicts both halves: **Gleam has never emitted Core Erlang**
(claim 15), and **LFE left Core Erlang for the Abstract Format in January 2018** (claim 19),
for `debug_info`. The Abstract Format is not the departure; it is where the neighbours went.

Ticket 02 could not establish a stated rationale for *any* project's target choice except
Gleam's, so precedent remains weak evidence either way.

## What ticket 19 established — the premise inverts

`purescript-backend-erl` was briefed as "the closest existing implementation of the codegen
beam-sharp needs". **It is the opposite: a counter-example.** It emits exactly one clause per
function, always, with no guard — and the cause is upstream and unreachable from any backend.
`purs` collapses N equations into a single CoreFn `ExprCase` before `corefn.json` is written,
and the optimiser then compiles the pattern matrix into a chain of boolean tests whose IR has
**no pattern node at all**. Its target choice is therefore not what constrains it; it would
emit identical single-clause functions targeting the Abstract Format.

Combined with ticket 02's survey: **no BEAM backend fed by a curried functional frontend emits
clause heads.** Gleam refuses them in the surface; Hamler and Alpaca flatten to one `c_fun`
plus `c_case`; purerl emits one clause plus `case`; its successor one clause plus an `if` chain.
**The only two that keep heads are LFE and Elixir — whose surface syntax has multi-clause heads
natively.**

Be careful with the causation: LFE and Elixir do not keep heads *because* they target the
Abstract Format. LFE preserved heads for years on Core Erlang and switched in 2018 for
`debug_info`. **The target enables preservation; the frontend decides whether there is anything
to preserve.** beam-sharp is in LFE's position — a native multi-clause surface with no
pattern-matrix flattening upstream — which is exactly why the backend-erl audit is a
counter-example rather than a template. Net: **no evidence against the Abstract Format.**

## Notes

## A codegen obligation from ticket 10 — resolved 2026-08-12

**Every atom appearing in a type position must be emitted into the module's atom chunk.** This
is an obligation Erlang does not have, and whichever target is chosen must be able to discharge it.

Verified ([`prototypes/10b_atom_interning.erl`](../prototypes/10b_atom_interning.erl), OTP 28):
an atom appearing **only** in a `-type`/`-spec` is absent from the compiled atom chunk, and
`binary_to_existing_atom` rejects it. Erlang tolerates this because its specs are documentation.
Ticket 09 made beam-sharp's types **erased aliases** while keeping them load-bearing, so a
`type Outcome = :ok | :error;` whose `:error` never reaches a pattern or expression would leave
that atom uninterned — and ticket 10 §4's `ToExistingAtom` would then reject a value the type
system says is legal. Type says yes, runtime says no: ticket 06's third outcome through an
unwatched door.

The exposure is narrow (atoms in clause heads are already value-position literals) and the cost
is bounded by source size. **But note how it compounds with ticket 02's sharpest finding**:
compiling from `.core` emits an empty abstract chunk *with no warning*. Both are silent failures
in the same layer, and a target chosen without checking either will fail quietly.

## Notes

HITL, but heavily fact-led — most of the work is in ticket 02. Blocked by ticket 11 because
a type system that erases entirely has different target needs than one wanting to emit
type-derived runtime checks at boundaries.

## Constraints from ticket 11 — resolved 2026-08-12

- **A second type-directed codegen obligation lands here.** Ticket 10 established `ParseAtom<T>`;
  ticket 11 adds **`ValidateAs<T>`**, which must synthesise an O(n) structural traversal from a
  type. Both require full type information *at codegen time*, which is an argument about the tier
  chosen — and it compounds ticket 02's finding that compiling from `.core` emits an empty
  abstract chunk **with no warning**, losing `-spec` silently.
- **Patterns over a `term` lower to guards.** Where a typed parameter needs no runtime test
  (the checker proved it), a `term` pattern does: `{:tick, int n}` needs `is_integer(N)`. So the
  backend must emit guards from pattern type annotations, and only for `term`-typed positions.
- **Arrow types are rejected by `ValidateAs<T>` at compile time**, so no fun-wrapping codegen is
  needed. If ticket 11's deferred option (a runtime type registry keyed by module, to validate an
  external fun against its declared `-spec`) is ever taken up, that lands here.
