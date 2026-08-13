# PROTOTYPE 18a — what a defensive guard on an exported function costs

> Measured on this machine, Erlang/OTP 28.5 (`erts-16.4`, compiler `9.0.6`, 64-bit, JIT,
> `smp:10:10`, arm64 Darwin), for ticket
> [18](../issues/18-boundary-defence.md). Every claim below is `local` evidence,
> produced by [`18a_guard_cost.erl`](18a_guard_cost.erl) — no citation, no estimation.
>
> ```
> erlc -o /tmp/18a 18a_guard_cost.erl
> erl -noshell -pa /tmp/18a -eval "'18a_guard_cost':go(), halt()."
> ```
>
> Sizes, emitted assembly and violation behaviour are **byte-identical across runs** (verified
> over three runs; only log timestamps and the harness's own stack-frame paths differ), as are
> the §1b arm totals (two runs). **Timings are not**, and are reported as three separate runs
> below rather than as one number — §2 says which of them are inside this method's noise.

Compared, on the same source shape, over four widths and one record-shaped discriminator:

```erlang
add(A, B) -> A + B.                                     %% unguarded
add(A, B) when is_integer(A), is_integer(B) -> A + B.   %% guarded
```

---

## 0. Two controls the brief did not ask for, which change how the numbers read

**Control 1 — `add/2` is a confounded benchmark.** The guard does not only cost; it also
*informs*. In the guarded module the emitted addition carries proven operand types the
unguarded module does not have:

```erlang
%% v_a2_u (unguarded)
{gc_bif,'+',{f,0},2,[{x,0},{x,1}],{x,0}}.

%% v_a2_g (guarded)
{gc_bif,'+',{f,0},2,[{tr,{x,0},{t_integer,any}},{tr,{x,1},{t_integer,any}}],{x,0}}.
```

So any `add/2` delta is *guard entry cost plus whatever body optimisation the guard unlocked*.
Every pair is therefore measured alongside `id(A) -> A.`, which has no body to optimise and
isolates the entry cost. The two are reported separately and neither is labelled as the other.

**Control 2 — a noise floor.** Two byte-identical unguarded `id/1` modules under different
names (`v_id_x`, `v_id_y`) run through the identical generate → compile → drive → time
pipeline. A delta smaller than their difference has not been measured, only bounded.

Module names are equal-length within every pair (the name lands in the atom table and the
`CInf` chunk), and everything is compiled `deterministic`. Each variant module holds exactly
one exported function plus the synthesised `module_info/0,1`, so **the `Code` chunk delta is
that function's own bytecode delta exactly** — this is not an estimate, and per-function bytes
did not need to be disclaimed as inseparable.

---

## 1. Code size on disk

```
module       file     Code     AtU8     ImpT   instrs
------       ----     ----     ----     ----   ------
v_id_u        520       67       49       28        5
v_id_g        524       70       49       28        6
v_id_x        520       67       49       28        5
v_id_y        520       67       49       28        5
v_a1_u        540       74       52       40        6
v_a1_g        544       79       52       40        7
v_a2_u        540       74       52       40        6
v_a2_g        548       84       52       40        8
v_a4_u        556       92       52       40        8
v_a4_g        580      114       52       40       13
v_tp_u        548       73       58       40        6
v_tp_g        544       86       56       28       10
```

| pair | `.beam` file | **`Code` chunk** | AtU8 | ImpT | instrs |
|---|---|---|---|---|---|
| `id/1` 1 guard *(entry cost only)* | +4 (+0.8%) | **+3 (+4.5%)** | 0 | 0 | +1 |
| `id/1` **noise floor** (identical pair) | 0 (0.0%) | **0 (0.0%)** | 0 | 0 | 0 |
| `add/2` 1 guard | +4 (+0.7%) | **+5 (+6.8%)** | 0 | 0 | +1 |
| `add/2` 2 guards | +8 (+1.5%) | **+10 (+13.5%)** | 0 | 0 | +2 |
| `add/4` 4 guards | +24 (+4.3%) | **+22 (+23.9%)** | 0 | 0 | +5 |
| `amt/1` tuple discriminator | **−4 (−0.7%)** | **+13 (+17.8%)** | −2 | −12 | +4 |

The size control is exact: the two identical modules differ by zero in every column, so the
equal-name-length precaution worked and none of these deltas is name-length pollution.

Scaling is roughly per-test on the bytecode: one `is_integer` costs 3–5 bytes of `Code` and
one instruction; two cost 10 bytes; four cost 22 bytes. On the whole `.beam` a single guard is
4 bytes — but note chunks are 4-byte padded, which is why the `Code` column is the primary
number and the file column the secondary one.

These bytecode figures are the **complete measured size story**. Whether JIT-emitted native
code scales the same way is open: §1b attempted it and did not resolve it.

### 1a. The tuple case is the most expensive on the primary metric and the only one that shrinks the file

`amt/1` is the realistic beam-sharp shape, and it moves in two directions at once.

```erlang
%% v_tp_u — unguarded
{bif,element,{f,0},[{integer,3},{x,0}],{x,0}}.
return.

%% v_tp_g — guarded
{test,is_tuple,{f,1},[{x,0}]}.
{test,test_arity,{f,1},[{x,0},3]}.
{get_tuple_element,{x,0},0,{x,1}}.
{test,is_eq_exact,{f,1},[{x,1},{atom,order}]}.
{get_tuple_element,{x,0},2,{x,0}}.
return.
```

Note what the three source guards lower to: `is_tuple(X), tuple_size(X) =:= 3` **fuses** into
`is_tuple` + `test_arity`, and `element(1,X) =:= order` becomes `get_tuple_element` +
`is_eq_exact`. **Three tests plus two element fetches** — not the naive six tests. (§2's table
calls this "4 tests" as shorthand for the four guard operations before the body.)

On `Code` this is the **largest** delta in the set: **+13 bytes, +17.8%, +4 instructions**.
The file nonetheless shrinks by 4 bytes, and that is an import-table side effect, not the
guard being free: with the shape proved, `element(3, X)` lowers to an unchecked
`get_tuple_element` instead of the checked `element` BIF, so the `erlang:element/2` entry
leaves `ImpT` (−12 bytes = exactly one 3-word import entry) and the atom `element` leaves
`AtU8` while the shorter `order` enters (−2 bytes, which the length difference accounts for
exactly).

### 1b. Loaded code — the probe did **not** resolve a per-module cost

`.beam` bytes are not what a guard costs in a running node: the JIT emits native code at load
time, so this is a different number and worth trying to get. Loading 100 identical modules per
arm and reading `erlang:memory(code)` between arms — **alternating** unguarded, guarded,
unguarded, guarded, so that "this batch is guarded" is separable from "this is the third batch
of 100 modules loaded":

```
arm    kind             before        after      delta delta/module
1      unguarded       8541495      8748666     207171       2071.7
2      guarded         8748666      8955966     207300       2073.0
3      unguarded       8955966      9190786     234820       2348.2
4      guarded         9190786      9398085     207299       2073.0

same-kind, different position:
  unguarded arm3 - unguarded arm1 : +27649 bytes (+276.5/module)
  guarded   arm4 - guarded   arm2 : -1 bytes (-0.0/module)
adjacent U->G steps:
  arm2 - arm1 : +129 bytes (+1.3/module)
  arm4 - arm3 : -27521 bytes (-275.2/module)
```

Every delta above is identical to the byte across two runs. The alternation is what makes this
readable, and what it says is: **the counter's positional variation swamps the guard.** Two
byte-identical unguarded batches differ by **+27,649 bytes** depending only on load order,
while the two guarded batches — measured in different positions — agree to **1 byte**. The two
adjacent unguarded→guarded steps disagree with each other by more than 27 kB and by sign.

So no loaded-code cost per guard is claimed here. The nearest thing to a signal is the
arm1→arm2 step, +129 bytes per 100 modules (+1.3 bytes/module), but a same-source arm elsewhere
in the same run moves the counter by 200× that for reasons that have nothing to do with guards
— almost certainly an allocator carrier boundary crossed at batch three. **This measurement
failed to separate the guard, and the honest output is the raw table, not a derived number.**

*(An earlier three-arm U,U,G version of this probe produced "+339 bytes/module" and it was
entirely an artefact of that ordering — the arm-3 positional step attributed to the guard
because the guarded batch happened to be loaded third. It is retracted; the alternating design
above exists because of it.)*

The `Code`-chunk figures in §1 stand on their own — they are exact and byte-reproducible. What
remains unmeasured is what the guard costs in JIT-emitted native code, and `erlang:memory(code)`
at this granularity is the wrong instrument for it.

---

## 2. Call overhead — mostly below the resolution of this method

N = 200,000,000 calls per rep (≈0.45 s), 6 reps per variant, first discarded as warmup,
variants interleaved U,G,U,G so drift hits both arms. Each variant is driven by its own
generated module holding a **static remote call** (`call_ext`), which cannot be inlined or
elided across the module boundary; the argument derives from the loop counter and the result
is folded into a returned accumulator, so nothing in the chain is dead. Elapsed time tracks N:

```
N =     50000000  elapsed =     120.0 ms    2.401 ns/call
N =    100000000  elapsed =     241.2 ms    2.412 ns/call
N =    200000000  elapsed =     482.9 ms    2.415 ns/call
N =    400000000  elapsed =     991.2 ms    2.478 ns/call
```

Unguarded baselines ranged 2.19–2.77 ns/call across runs. **Minimum, not mean, is the
estimator** — run 1 was disturbed mid-benchmark (raw reps of `2.200 2.227 6.891 6.878 6.848`
in one block, and a 400M linearity point at 6.648 ns/call), and min survived that while median
did not.

**Delta of the minima (guarded − unguarded), ns/call, three independent runs:**

| pair | run 1 | run 2 | run 3 | verdict |
|---|---|---|---|---|
| **noise floor** (identical modules) | +0.033 | +0.015 | −0.003 | — |
| `id/1` 1 guard | +0.063 | −0.069 | +0.014 | sign flips — **not resolved** |
| `add/2` 1 guard | −0.054 | +0.035 | −0.062 | sign flips — **not resolved** |
| `add/2` 2 guards | +0.104 | +0.139 | −0.000 | at the floor |
| `add/4` 4 guards | **+0.870** | **+0.435** | **+0.864** | resolved — **confounded, §0** |
| `amt/1` tuple (4 tests) | +0.084 | +0.055 | +0.055 | at the floor, consistent sign |

**Delta of the medians, same runs:**

| pair | run 1 | run 2 | run 3 |
|---|---|---|---|
| noise floor | +0.027 | −0.005 | −0.001 |
| `id/1` 1 guard | −0.014 | −0.067 | +0.068 |
| `add/2` 1 guard | +0.016 | +0.068 | −0.014 |
| `add/2` 2 guards | +0.044 | +0.167 | +0.038 |
| `add/4` 4 guards | +0.878 | +0.555 | +0.868 |
| `amt/1` tuple | +0.081 | +0.107 | +0.065 |

**There is a second, stricter noise floor in this data.** `v_a1_u` and `v_a2_u` are
byte-identical source compiled to identically-shaped modules, and they are timed in *different
interleaved blocks*. Their minima differ by 0.048, 0.088 and 0.054 ns across the three runs.
That across-block drift — call it **±0.09 ns/call** — is the honest resolution of this method,
not the ±0.03 the adjacent-block floor suggests.

Against that floor:

- **One guard is free, or below 0.09 ns/call.** Both single-guard pairs flip sign between runs.
- **Two guards, and the four tuple tests, sit at the floor.** The tuple delta is positive in
  every run and in every median, which is weak evidence of a real cost, but its magnitude
  (+0.055 to +0.084) is inside the across-block drift. The most that can be claimed is
  **< 0.1 ns/call on a ~2.4 ns/call baseline**.
- **Four guards is the only clearly resolved cost: +0.44 to +0.87 ns/call**, 16–35% of the
  unguarded call. This is confounded (§0 control 1) — it includes the type information the
  guards fed into three `+` operations.

**Do not read a per-guard nanosecond figure out of this.** The deltas are not monotonic in test
count and not linear in it: one test is free, two are at the floor, four `is_integer` cost
0.44–0.87, and four *tuple* tests cost under 0.1. Even the one resolved figure varies by 2×
between runs (+0.435 to +0.870). Whatever produces the step is likely code layout or branch
structure, which was not measured here.

---

## 3. What happens on violation — the qualitative half

### 3.1 A float where an integer is declared

Unguarded, `v_a2_u:add(1.0, 3)` returns **`4.0`** silently. Guarded, `v_a2_g:add(1.0, 3)`:

```erlang
caught class  : error
caught reason : function_clause
top frame     : {v_a2_g,add,[1.0,3],[{file,"v_a2_g.erl"},{line,4}]}
offending arg 1.0 present in top frame? {yes,[1.0,3]}
```

**The offending argument is in the frame.** Shell rendering
(`erl_error:format_exception/3`, in-process — not a race with the logger):

```
exception error: no function clause matching v_a2_g:add(1.0,3) (v_a2_g.erl:4)
```

Process exit reason, from `spawn_monitor`:

```erlang
{function_clause,[{v_a2_g,add,[1.0,3],[{file,"v_a2_g.erl"},{line,4}]}]}
```

and the crash report the default logger writes:

```
=ERROR REPORT==== 13-Aug-2026::01:05:48.817642 ===
Error in process <0.238.0> with exit value:
{function_clause,[{v_a2_g,add,[1.0,3],[{file,"v_a2_g.erl"},{line,4}]}]}
```

### 3.2 A wrong-shaped tuple — the sharper contrast

Both versions crash here, so this is not silent-versus-loud. It is **whose fault the crash
report names**. Unguarded, `v_tp_u:amt({customer, 7})`:

```erlang
caught class  : error
caught reason : badarg
top frame     : {erlang,element,[3,{customer,7}],[{error_info,#{module => erl_erts_errors}}]}
```
```
exception error: bad argument
  in function  element/2
     called as element(3,{customer,7})
     *** argument 1: out of range
  in call from v_tp_u:amt/1 (v_tp_u.erl:4)
```

The blamed argument is **argument 1 — the literal `3`**, which is compiler-generated, not
anything the caller wrote. The top frame is `erlang:element/2`, one level *below* the
programmer's function. Guarded, `v_tp_g:amt({customer, 7})`:

```erlang
caught class  : error
caught reason : function_clause
top frame     : {v_tp_g,amt,[{customer,7}],[{file,"v_tp_g.erl"},{line,4}]}
offending arg {customer,7} present in top frame? {yes,[{customer,7}]}
```
```
exception error: no function clause matching v_tp_g:amt({customer,7}) (v_tp_g.erl:4)
```

Caller's term, caller's function, right line, and the error class changes from `badarg` to
`function_clause`. Without the guard the diagnostic points at the compiler's own codegen; with
it, at the value that was actually wrong.

---

## 4. Elision — never at the exported boundary, sometimes below one

The discriminator is **exported vs local-only**, not local-call vs remote-call: a BEAM function
has one entry label shared by both call kinds.

**(a) `e_ex` — exported guarded `f/1`, called locally with a proven integer. Guard paid.**

```erlang
{function, f, 1, 2}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.        %% <- present
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.

{function, caller, 1, 4}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.
    {call_only,1,{f,2}}. % f/1                %% <- targets label 2, which IS the test
```

The local caller's `call_only` jumps to `{f,2}` — the label carrying the test. An exported
function pays its guard on every call, from any caller, because an external caller could always
pass anything.

**(b) `e_lo` — same code, `f/1` *not* exported. Guard elided.**

```erlang
{function, f, 1, 2}.
  {label,2}.
    {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}.   %% <- test GONE, only an annotation
    {gc_bif,'+',{f,0},1,[{tr,{x,0},{t_integer,any}},{integer,1}],{x,0}}.

{function, caller, 1, 4}.
  {label,4}.
    {test,is_integer,{f,3},[{x,0}]}.        %% <- caller/1's own guard, at the boundary
    {call_only,1,{f,2}}. % f/1
```

**(c) `e_un` — `f/1` not exported, caller passes an unknown-type argument. Guard paid.**

```erlang
{function, f, 1, 2}.
  {label,2}.
    {test,is_integer,{f,1},[{x,0}]}.        %% <- present
```

Taken together: the check happens **once per entry into the module, at the exported boundary**,
and OTP's module-level type propagation drops redundant re-checks below it — but only for
functions it can see every call site of, which excludes anything exported.

---

## What this shows

- Bytecode cost is small and roughly per-test: 3–5 bytes of `Code` per `is_integer`, +13 bytes
  (+17.8%) for the tuple discriminator, which is the most expensive case in the set. These
  figures are exact and byte-reproducible. What the guard costs in JIT-emitted native code is
  **not** established here — the probe that tried failed (§1b).
- Call-time cost is at or below this method's ±0.09 ns/call resolution for one guard, two
  guards, and the four-test tuple discriminator; only four `is_integer` on `add/4` resolves,
  at +0.44 to +0.87 ns/call, and that figure is confounded by body optimisation the guards
  enabled.
- A guard converts a silent `4.0` into a `function_clause` naming the offending argument, and
  in the tuple case moves the blame from a compiler-generated literal inside `erlang:element/2`
  to the caller's own term in the caller's own function.
- Interior functions do not pay for guards that a caller has already established; exported ones
  always do.

---

## What was *not* measured

- **Any release other than OTP 28.5.** Only 28.5 is installed here; both the JIT's native code
  size and the type-propagation behaviour of §4 are release-specific.
- **Loaded native-code size.** §1b tried and failed; `erlang:memory(code)` varies by tens of
  kilobytes with load order alone. Getting this would need a per-module native-code size from
  the JIT itself, not a whole-node allocator counter.
- **Any architecture other than arm64 Darwin.** The +0.44–0.87 ns/call `add/4` result is a
  native-codegen figure; the `.beam` sizes in §1 are not and should port unchanged.
- **Why the timing deltas are non-monotonic in test count.** Code layout, branch prediction and
  instruction alignment are all plausible; none was instrumented.
- **Guards other than `is_integer` and the tuple discriminator** — no `is_binary`, `is_map`,
  map-shape or `is_function` costs here, and no multi-clause dispatch where the guard *selects*
  a clause rather than admitting one.
- **Cost under a realistic call mix.** Every measurement here is a tight monomorphic loop with a
  warm cache; nothing says what the guard costs when the call site is cold or megamorphic.
