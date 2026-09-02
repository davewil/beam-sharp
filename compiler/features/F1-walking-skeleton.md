# F1 — Walking skeleton: `.bs` in, callable `.beam` out

**Status**      done (2026-08-13), with three named gaps below
**Implements**  [ticket 01](../../wayfinder/issues/01-sample-code.md) (the sample the language
                had to compile), [04](../../wayfinder/issues/04-crossclause-exhaustiveness.md)
                (cross-clause exhaustiveness),
                [08](../../wayfinder/issues/08-head-and-guard-syntax.md) (head and guard syntax),
                [09](../../wayfinder/issues/09-union-representation.md) (union representation),
                [10](../../wayfinder/issues/10-atoms-in-a-csharp-skin.md) (atoms in a C# skin),
                [12](../../wayfinder/issues/12-totality-vs-let-it-crash.md) (totality vs
                let-it-crash), [13](../../wayfinder/issues/13-compilation-target-decision.md)
                (the compilation target) and
                [20](../../wayfinder/issues/20-untheorised-term-shapes.md) (untheorised term
                shapes)
**Unblocks**    `examples/Math/math.bs`, `examples/Readings/readings.bs`
**Depends on**  nothing

Written retrospectively, to fix the baseline the later features move from. Every scenario below was
run against `./_build/default/bin/bsc` on OTP 28.5 and records **observed** output, not intended
output.

## Why this one first

Same reason magic-lisp's B1 is its walking skeleton: the pipeline has to exist end to end before
any capability can be added to it. `.bs → lex → parse → exhaustiveness check → abstract format →
erlc +from_abstr → .beam`, with nothing in it that the map had not already closed.

## Scenarios

### F1.1 — a multi-clause function compiles and is callable from Erlang

```
$ bsc -o /tmp/f1 examples/Readings/readings.bs
$ ls /tmp/f1
Readings.abstr  Readings.beam
```

```erlang
'Readings':'Classify'({ok,5})       %% => positive
'Readings':'Classify'({ok,0})       %% => zero
'Readings':'Classify'({error,boom}) %% => unknown
```

Exit code `0`, no output on success. Four beam-sharp clauses become four native Erlang clause
heads — ticket 01's hand-verified finding, produced by a compiler.

### F1.2 — an inexhaustive function is a hard error, and the residual is the clause you must write

```
$ bsc -o /tmp/f1 bad.bs
bad.bs:5: error: Pick is not exhaustive
  no clause matches:
    Pick(:b) -> ...
$ echo $?
1
```

This is ticket 23's central claim working: the compiler **synthesises the clause head** from the
residual and offers no body. Ticket 04's exhaustiveness guarantee and ticket 12's no-opt-out are
both visible in one message.

### F1.3 — guards are credited as type operations

`examples/Math/math.bs`'s `Fib` is exhaustive **only** because the checker sees that `n <= 1` and
`n > 1` partition `int`. Neither clause is unguarded. Without interval arithmetic in the algebra
this is rejected. Compiles clean — ticket 08 and ticket 20 §3, together.

### F1.4 — a `-spec` is emitted and is precise, not widened

`Classify` emits `{ok, integer()} | {error, atom()}` rather than a widened `any()`. Checked by
`bin/spec-check.sh`, which corrupts a real emitted `.abstr` in exactly one respect and requires
Dialyzer to catch it — a clean run proves nothing unless a wrong spec would fail it.

### F1.5 — the emitted artefact is portable across the pinned OTP range

The `.abstr` builds unchanged on OTP 24–28 with byte-identical specs. The **`.abstr`** is the
portable artefact, not the `.beam` — a 28-built `.beam` is `{error,badfile}` on 26.

## Named gaps — observed, not yet fixed

These are the honest edges of "done", and each is a candidate small feature.

### F1.G1 — the diagnostic contract is half-implemented

Ticket 23 §2 decided **the term is the diagnostic and the prose is a pure function of it**. The
exhaustiveness path does that (F1.2). The parse and I/O paths do not — they print the raw Erlang
term:

```
$ bsc -o /tmp/f1 oops.bs
oops.bs: {parse,{3,bs_parser,["syntax error before: ",[]]}}

$ bsc -o /tmp/f1 nope.bs
nope.bs: {cannot_read,enoent}
```

Ticket 23's whole finding was that `erlc` *"publishes none of its own structured form — the
platform builds the value and destroys it exactly where the consumer stands"*. Half of `bsc`
currently reproduces the failure it was written to avoid.

### F1.G2 — every failure class shares exit code 1

Parse error, inexhaustiveness and a missing file all exit `1`. magic-lisp's B1 assigns **distinct
exit codes per failure class**, which is what lets a script — or an agent in a loop — branch
without parsing text. Ticket 23's standing constraint (diagnostics are consumed by an agent in a
loop) argues for the same thing and did not reach the exit code.

### F1.G3 — `bs_emit:int_part/1`'s bounded branches are unreachable from the surface

Intervals are in the algebra and the checker uses them, but they arise only from **guards**, and a
guard refines a clause rather than a signature — so a parameter declared `int` emits `integer()`
whatever its clauses test. **This is F2.**

## Out of scope

Records, angle brackets, modules and imports, FFI, OTP behaviours, refinements, binaries, `switch`,
pipes. See `examples/exemplars/README.md` for which exemplar each blocks. Note two entries in that
list are **stale rather than open** — tickets 26 (records) and 28 (angle brackets) were open when
this slice was cut and both closed on 2026-08-13.

## Done when

Met. `rebar3 eunit` is green (17 tests, all at the boundary), `bin/spec-check.sh` passes including
its deliberate corruption, and both examples compile and run.
