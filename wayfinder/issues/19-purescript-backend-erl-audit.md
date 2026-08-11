# 19 — Audit purescript-backend-erl's clause-head codegen

Type: research
Status: open

## Question

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

## Notes

AFK. Surfaced by ticket 06's open-questions section. Feeds tickets 08 and 13 directly, and
ticket 12 on the `Partial` constraint's fate in codegen.

Worth reading closely rather than skimming: this is a working, shipped implementation of the
exact thing the walking skeleton will have to do.
