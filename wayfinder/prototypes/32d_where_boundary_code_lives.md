# 32d — Where the boundary code lives, priced

Measured 2026-08-14. `local`, OTP 28.5. Source:
[`32d_where_boundary_code_lives.escript`](32d_where_boundary_code_lives.escript).

Ticket 15 gives a foreign call a compiler-emitted `try` wrapper; ticket 18 gives its result a
guard. Both need somewhere to live, and [`32a`](32a_gleam_external.md) found Gleam picks *erase the
declaration and inline at the call site*. This prices the fork. Whole-module `Code` chunk, same
program at N call sites, four variants:

- **bare** — no boundary code at all (what Elixir emits)
- **thin** — a forwarding wrapper, no `try`, no guard (**the control**)
- **wrapped** — the declaration is a function carrying the `try` and the guard
- **inlined** — the declaration is erased, `try` and guard repeated per call site

```
N          bare     thin  wrapped  inlined   thin-bare   wrap-thin inline-bare
1            93      109      168      145          16          59          52
2           117      130      189      239          13          59         122
5           186      190      249      467           4          59         281
10          297      286      345      883         -11          59         586
20          559      519      579     1823         -40          60        1264
40         1119     1019     1079     3703        -100          60        2584
```

## Findings

**1. As a function, the boundary code costs ~60 bytes once — flat at every N.** `wrap-thin` is
59–60 bytes from 1 call site to 40. Ticket 15's `try` and ticket 18's guard are a fixed,
one-time cost when the declaration is a real function.

**2. Inlined, it costs ~65 bytes per call site.** `inline-bare` grows linearly: 2,584 bytes over 40
call sites, 64.6 per site. At 40 call sites the inlined module is **3.3× the size of the unchecked
baseline**, against the wrapper's flat 60 bytes — a 43× difference in the cost of the same
guarantee.

**3. The control earned its place: the naive comparison lands negative and would have been
believed.** `wrapped - bare` goes to **−40 bytes at N=40**, i.e. the *checked* module reads as
smaller than the *unchecked* one. That is real but it is not the boundary code being free — it is
`thin-bare`, the saving from replacing a repeated remote-call sequence with a local call, worth
about 2.5 bytes per call site and reaching −100 at N=40. Ticket 12's benchmark was misread once in
exactly this way (the optimiser folding clauses, recorded on the map); the `thin` variant exists so
the two effects are attributed separately rather than netted.

## What this does not settle

This is a **lowering** measurement and ticket 32 decides **syntax** — the ticket states it adds no
checking rule and weakens none. The number says what the fork costs, not that the fork is 32's to
close. It also measures code size only: call-time cost is not measured here, and ticket 18's own
timing work found a boundary guard's call cost sits below the ±0.09 ns/call resolution, with the
cold and megamorphic cases still unmeasured.
