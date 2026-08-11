# 19 — Audit purescript-backend-erl's clause-head codegen

Type: research
Status: resolved

## Question

> **This question's premise was false, and the audit is what established that.** Left standing
> as written so the error is visible rather than tidied away. The repo is
> `id3as/purescript-backend-erl`; `purerl/purescript-backend-erl` does not exist.

`purescript-backend-erl` is purerl's recommended successor backend, and ticket 03 established
that it **compiles PureScript's multiple equations to native Erlang clause heads** — which
makes it the closest existing implementation of this language's headline codegen. Ticket 06
flagged explicitly that it was *not audited*.

Audit it. Establish, from source:

- **How multi-equation functions become Erlang clause heads.** Does it emit one Erlang clause
  per PureScript equation, or merge into a `case` and rely on the Erlang compiler? Where in
  the pipeline does the decision happen?
- **What it does with guards**, given the BEAM's severe guard restrictions and PureScript's
  unrestricted guard expressions. Guards that cannot be expressed as BEAM guards must go
  somewhere — where?
- **How pattern coverage is handled.** PureScript records partiality as a propagating
  `Partial` constraint (ticket 03); how does that survive into generated code, and does the
  backend emit anything for a partial function, or just let `function_clause` happen?
- **What it emits for arity**, given BEAM identity is name-plus-arity and PureScript is
  curried. Ticket 03 noted purerl applies to the right number of arguments based on export
  arity — confirm how, and what the cost is.
- **Which target form it emits** — Core Erlang, Abstract Format, or Erlang source — and why.
  This is a direct input to ticket 13.
- **Known limitations and open issues** in its clause-head handling.

Write findings to `wayfinder/research/19-purescript-backend-erl-audit.md` and link here.

## Answer

[Findings: `wayfinder/research/19-purescript-backend-erl-audit.md`](../research/19-purescript-backend-erl-audit.md)

**It does not emit native clause heads, and ticket 03 must be corrected.** A top-level
function from `purescript-backend-erl` has **exactly one clause, always, with no guard** —
asserted in its own source, and verified here: all 44 golden-output modules compile on OTP 28
and across **443** functions the max clause count is **1**. Five PureScript equations become
one `processE/3`; four two-column patterns become one `i/2` holding an `if` chain.

**The cause is upstream and irreversible from the backend.** `purs` merges equations into one
CoreFn `ExprCase`; `backend-optimizer` then compiles the pattern matrix into a `Branch` chain
of boolean tests — its IR has *no pattern node at all*. The backend never sees a pattern, so
its target choice (Erlang **source text**, no stated rationale) is not what constrains it.

**Guards**: it emits none — `when` appears zero times in every golden file. A 36-name
whitelist (`guardExpr`) routes guard-legal conditions into `if` and demotes everything else to
`case Cond of true -> …`. **`Partial`**: erased before CoreFn; the backend has no coverage
knowledge and always emits `erlang:error({fail, …})`. **Arity**: every declaration is emitted
and exported twice, `f/0` curried plus `f/n` uncurried, derived from *code not types* — which
the README itself calls "less predictable".

**The failure mode is the headline.** The HEAD commit fixes a demand-analysis leak that
stamped a conditional `{just,_}` refinement into the shared head, making the source `Nothing`
clauses unreachable and killing live paths with `function_clause` in id3as's shipped `norsk`.
**One clause per equation could not have had that bug.**

**For ticket 13 this inverts the premise**: no BEAM backend fed by a curried functional
frontend emits clause heads. The only two that do — LFE and Elixir — both target the Abstract
Format.

## Notes

AFK. Surfaced by ticket 06's open-questions section. Feeds tickets 08 and 13 directly, and
ticket 12 on the `Partial` constraint's fate in codegen.

Worth reading closely rather than skimming: this is a working, shipped implementation of the
exact thing the walking skeleton will have to do.
