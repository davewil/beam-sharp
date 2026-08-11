# 03 — Prior art: static typing plus multi-clause heads on the BEAM

Type: research
Status: open

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

## Notes

AFK. Feeds tickets 11 and 12.
