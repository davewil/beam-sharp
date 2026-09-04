# 03 — Prior art: static typing plus multi-clause heads on the BEAM

Type: research
Status: resolved

## Question

Which BEAM languages have combined static typing with Erlang-style multi-clause function
heads, and how did they do it?

Cover at minimum: **purerl / PureScript**, **Alpaca**, **Caramel**, **Hamler**, and the
paper [NVLang: Unified Static Typing for Actor-Based Concurrency on the BEAM](https://arxiv.org/pdf/2512.05224).

For each, establish:

- Type system family (HM, Haskell-style with classes, set-theoretic, other).
- Whether multi-clause function heads are supported, and if so how exhaustiveness is
  handled across them.
- How the actor model and message passing are typed, if at all.
- Project status and activity, and — where a project stalled — the stated or evident
  reason. **This is the most valuable part of the ticket**: the failure modes of "language
  X on the BEAM" efforts are the risks this effort inherits.

Separately, establish **Gleam's stated rationale for refusing multiple function heads** —
from its docs, issues, or the maintainers' writing — rather than the inferred one. If the
reason is compiler simplicity, that is a different risk than if the reason is a soundness
or exhaustiveness problem.

Write findings to `wayfinder/research/03-prior-art-static-multiclause.md` and link here.

## Answer

Findings: [wayfinder/research/03-prior-art-static-multiclause.md](../research/03-prior-art-static-multiclause.md)

- **The combination is proven.** Alpaca shipped multi-clause heads on an HM BEAM language
  with message-typed PIDs. Not blocked on type theory.
  **Correction (ticket 19):** this bullet also claimed purerl's successor backend compiles
  PureScript equations to native Erlang clause heads. **It does not** — it emits exactly one
  clause per function, always, with no guard. The claim misread commit `1be3f06`, which reports
  a *bug* caused by all source clauses sharing one head. Alpaca's half stands unaffected.
- **Gleam has no stated rationale — because multi-clause heads were never proposed, so
  never rejected.** The rule landed pre-v0.1 as a bare premise (issue #64: empty body, zero
  comments); all 143 `suggestions` issues contain no request for it; `DuplicateName` has no
  explanatory comment. Hypothesis (c), a soundness/exhaustiveness problem, is *affirmatively
  weakened*: Gleam's shipped Jules Jacobs exhaustiveness checker already handles nested
  multi-column patterns. lpil's "no function overloading" quote is about arity/type
  overloading and must **not** be cited as the rationale.
- **Nothing died of a type-theory wall.** Caramel's author: *"why is Erlang hard to type? –
  and as it turns out, it is not!"* The discriminator between survival and death is
  **commercial dependency** — purerl lives because id3as ships on it; Hamler, Caramel and
  Alpaca had no internal consumer. Secondary causes: bus factor of one, and the ecosystem
  tail (stdlib, CLI, LSP, formatter) carried alone.
- **NVLang is close to a null result and its credibility is questionable** — plain HM,
  single-headed functions, a rule that *unifies* branches to one type, an exhaustiveness
  check that is asserted but never specified, a fabricated-looking citation, and no
  locatable implementation. Its one usable idea is `Pid[τ]`.
- **Mechanisms worth carrying**: PureScript's exhaustiveness-as-a-propagating-`Partial`-
  constraint (→ 12); purerl's compile-time rejection of runtime-ambiguous unions and
  Alpaca's whole-call-graph inference of a process's message type (→ 14); Alpaca's
  never-fixed constructor-pattern-in-head parse ambiguity (→ 08).
- Gleam's actor typing was **not** established from primary sources — deferred to ticket 14.

## Provenance upgrade from ticket 10 — 2026-08-12

**Gleam is now installed locally** (1.18.1, via `mise use -g gleam@1.18.1`), so Gleam claims in
this file that were `doc` or `src` can be re-checked by measurement rather than citation.
Prefer measuring. Two claims already re-checked and confirmed
([`prototypes/10c_gleam_atoms.gleam`](../prototypes/10c_gleam_atoms.gleam)):

- Fieldless variants compile to bare atoms, variants with fields to tagged tuples, PascalCase
  to snake_case — `-type colour() :: red | green | blue.`
- Gleam has **no atom literal**: `pub fn f() { :ok }` is a syntax error. Atoms exist only as
  fieldless variants, with a built-in carve-out for `ok`, `error` and booleans.

## Notes

AFK. Feeds tickets 11 and 12.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Prior art: static types plus multi-clause heads](issues/03-prior-art-static-multiclause.md)
  — **Gleam never rejected multi-clause heads; it never considered them.** No rationale
  exists, and the soundness hypothesis is affirmatively weakened (Gleam's shipped checker
  already runs Jules Jacobs' algorithm over nested multi-column patterns). Projects stall on
  **commercial dependency**, not type theory — purerl survives because a company ships on it;
  Hamler, Caramel and Alpaca each had zero internal consumers. The core bet is proven
  feasible: Alpaca shipped multi-clause heads on an HM BEAM language. **NVLang is a citation
  hazard** — see the ticket before citing it anywhere. *(One claim in this ticket was later
  retracted by ticket 19 — see there.)*
```
