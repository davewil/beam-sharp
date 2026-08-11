# PROTOTYPE 01d — source-only sub-modules vs real BEAM modules

> Measured on this machine, Erlang/OTP 28.5 (`erts-16.4`), against ticket
> [01](../issues/01-sample-code.md) §01c. Every performance claim below is `local` evidence —
> commands and outputs given — not citation.

The question: when `Order.Apply` and `Order.Total` are separate sub-modules in source, does each
become **its own BEAM module**, or do they compile into **one BEAM module per aggregate**?

---

## 1. What the compiler actually emits

Two forms of the same code, disassembled with `beam_disasm:file/1`:

```erlang
%% split_caller.erl calling split_callee:total/2
{call_ext_only,2,{extfunc,split_callee,total,2}}

%% joined.erl calling its own total/2
{call_only,2,{joined,total,2}}
```

`call_ext_only` versus `call_only` — a different instruction, resolved through the export table.
**Erlang does not inline across module boundaries**, so a cross-module call can never be
collapsed, whatever optimisation flags are set.

## 2. What that costs, in nanoseconds

20,000,000 iterations, best of five runs, tight loop calling a two-argument `add`:

| | total | per call | |
|---|---|---|---|
| local call | 34,684 µs | **1.73 ns** | baseline |
| remote call | 36,831 µs | **1.84 ns** | **6.2% slower** |
| local call, `-compile(inline)` | 15,902 µs | **0.80 ns** | remote is **2.3× slower** |

**The remote call itself is nearly free — 6%.** The real cost is the *inlining opportunity*, and
an inlined trivial function in a tight loop is 2.3× faster than a remote one.

But note the qualifier that decides how much this matters: **`-compile(inline)` is opt-in in
Erlang, not the default.** So for ordinary code compiled with ordinary settings, splitting a
module costs about 6% on the call, and nothing at all on anything that isn't call-dominated. For
a domain command handler, this is not a consideration. For an inner loop, it is.

## 3. The upgrade argument, corrected

A tempting argument for one-module-per-aggregate is that splitting operations across modules
allows a **torn upgrade** — `Order.Apply` loaded new while `Order.Total` still runs old code
against a changed `Order` shape.

**That argument is weaker than it looks**, and it should not be used: `code:atomic_load/1` and
`code:prepare_loading/1` exist (verified present on OTP 28) and load a set of modules atomically.
Consistency across a split aggregate is achievable.

What survives is an *ergonomic* cost, not a correctness one: release upgrade tooling
(`appup`/`relup`) works per module, so any change spanning several operations of one aggregate
must name the whole set. That is bookkeeping someone has to get right, repeatedly.

---

## 4. The comparison

### Real BEAM modules — one `.beam` per operation

**For**

- **Per-function hot code loading.** Swap one operation without touching its siblings. Finer than
  Erlang has ever offered, and `atomic_load` covers the cases where you need a set.
- **Incremental recompilation per operation** — change one command handler, rebuild one small
  module.
- **The runtime knows the structure you wrote.** Stack traces, crash reports, `code:which/1`,
  `m/1` and observer all name the operation. Under source-only these would name the aggregate and
  the mapping back is the compiler's problem.
- **Per-operation attributes** — docs, `-spec`, metadata, all naturally scoped.

**Against**

- **No cross-module inlining, ever** (§1). 6% on a call, 2.3× against inlined code.
- **OTP behaviours need a facade.** `gen_server` calls `Mod:handle_call/3`, and the export is now
  in the wrong module. Requires generated delegation, which is machinery to build, test and
  explain.
- **Erlang callers need the same facade** to see a normal module (ticket 06).
- More atoms, more `.beam` files, wider dialyzer PLT.
- `appup`/`relup` must name module sets (§3).

### Source-only — one `.beam` per aggregate

**For**

- **OTP behaviours work with no machinery at all.** The exports land exactly where OTP looks. The
  §01c problem does not get solved, it stops existing.
- **Erlang callers get a normal module for free** — `'Shop.Orders.Order':apply(O, E)` — which is
  what ticket 06 asked for.
- **Local calls, inlinable.** Whatever optimisation is available stays available.
- **The upgrade unit matches the consistency unit.** An aggregate's operations share its type
  contract; making the aggregate the module makes `relup` trivial and torn upgrades impossible by
  construction rather than by discipline.
- Fewer atoms, fewer files, and a `.beam` layout that matches what BEAM programmers expect.

**Against**

- **No per-function hot swap.**
- Recompilation granularity is the whole aggregate.
- **The structure is a source fiction the runtime does not know about.** Unless the compiler maps
  back deliberately, a crash names `'Shop.Orders.Order':apply/2` rather than the sub-module the
  programmer wrote — which is *nearly* the same string, so the cost here is small.
- You are building a module system the runtime has no concept of. That burden sits in the
  compiler forever.

---

## 5. Recommendation: source-only

Four reasons, in order of weight.

1. **It deletes the §01c problem instead of solving it.** OTP callbacks stop being a special case;
   no facade, no delegation, no second convention for behaviour modules. The single hardest
   objection to module-as-focus evaporates.
2. **The performance argument does not decide it** — 6% on a call that a command handler makes
   once. It is close enough to a wash that it should not drive the choice, and where it *does*
   matter (inner loops) that code is intra-module recursion anyway.
3. **The aggregate is the consistency boundary**, so it should be the deployment boundary. This
   makes `relup` simple and torn upgrades structurally impossible.
4. **Per-function hot swap is a capability nobody has asked for** in forty years of the BEAM, and
   the DDD value of this structure is *organisational* — which is a source-level property that
   source-only delivers in full.

One thing would flip it: wanting the **operation** to be the unit of deployment or observability.
Observability is already covered — `dbg:tpl(Mod, Fun, Arity, …)` traces a single function without
needing it to be a module — so the flip would have to be about deployment specifically.

→ tickets 13 (what the compiler emits) and 14 (OTP callbacks).
