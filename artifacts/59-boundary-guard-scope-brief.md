# Brief: ticket 59 — boundary guard scope asymmetry

Research brief, not a decision. Does not resolve ticket 59; ticket 59's `Status:` line and
`## Decisions entry` are untouched by this document. `compiler/src/bs_emit.erl` in the main
working tree is untouched — every probe below compiled a scratch `.bs` module against the
unmodified `bsc` binary. `git status` in `/home/user/beam-sharp` is clean at the end of this
session, HEAD `633ac0097c6c6fb40e0ce7690ac7635a238077c4`.

## Sub-decisions extracted

The ticket names three. Reading it against the source and the probes below surfaces two more.

1. **Which scope is right, stated once, for both guards.** Named in the ticket. The measurements
   below split this: the *direct-parameter* case and the *collection-nested* case give opposite
   answers, so "once, for both guards" may not survive contact with the corpus (§ Probe 2).
2. **Whether "exported" is even the right discriminator.** Named in the ticket. §
   Erlang/OTP survey below confirms, with file:line citations, that exported-vs-local is not just
   BEAM's preferred discriminator — it is the *only* one available at the loader level. A
   non-exported function has no entry in the runtime export table at all, so nothing besides an
   in-module call can ever reach it. Refined below to a sharper question: is "reachable only from
   a checked call site" the same guarantee as "reachable only with a validated value" — measured,
   it is not always the same, because the type checker's site-1 check is a check of *shape
   correspondence at the call*, not a check that the value's *runtime provenance* was validated
   (§ Probe 2, § Probe 4).
3. **The cost if the answer widens rather than narrows.** Named in the ticket. Reproduced on this
   toolchain in § Cost reproduction: both cited figures hold to the byte.
4. **Does the answer differ for the tag test vs. the kind test, on principled rather than
   historical grounds?** Not named in the ticket as asked, but implied by "or is 18 §4's
   'exported' narrower than the tag test needs" — asked here directly, and the probes below give
   it a real, non-hypothetical answer: yes, they differ in principle, but not for the reason 26 §1
   originally offered.
5. **What does "a private function reachable only through an exported one that already validated
   its inputs" actually imply?** Named in the ticket's framing paragraph. The literal premise —
   "already validated its inputs" — is not universally true of the current compiler, and § Probe 2
   is a real, compiled, run counter-example: an exported function that does *not* validate a
   record nested inside its own parameter before handing it to a private function.

## Methodology

Every claim below with a `$` prompt, a `bsc`/`erl` transcript, or a `file:line` citation was
executed or read in this session, against the toolchain in `RESEARCH_ENVIRONMENT.md` (OTP 28.5,
erts-16.4, compiler 9.0.6, Linux; `bsc` built at `compiler/_build/default/bin/bsc`). Probe sources
live under this session's scratchpad at `probe59/` (five `.bs` modules, two `.erl` drivers) and are
quoted in full below rather than summarized. The two existing cost prototypes
(`wayfinder/prototypes/18a_guard_cost.erl`, `26a_record_erasure_cost.erl`) were re-run on this
build rather than re-derived from their `.md` write-ups. No subagent-spawning tool was available in
this tool environment (`ToolSearch` for an `Agent`/`Task` tool returned nothing matching); the
independent-verification pass required by the task is instead in § Verification, done as a
second, adversarial pass over the same probes in this session — re-run from scratch with varied
constructions designed to falsify rather than confirm the first pass's reading, and checked
explicitly for the circularity failure mode the task named.

## 1. What the current source actually does — read before probing

`compiler/src/bs_emit.erl`. The function is **`boundary_guards/6`**, not `/5` as the ticket's
prose states — line 247 at HEAD:

```erlang
247  boundary_guards(Patterns, Params, Line, Ctx, Public, Accepts) ->
```

`git log -p --follow` on the file shows `Public` and `Accepts` were both already parameters by the
time the function reached this shape; `Accepts` is F37's range-guard input (comment at the call
site, line 176, cites "F37, ticket 46 §2"), so the ticket's `/5` most likely names an earlier state
before F37 added the sixth argument. Immaterial to the question, but the task asked to confirm the
real signature rather than trust the ticket's prose, so: confirmed, and corrected.

The dispatch that actually decides scope is `guard_one/7`, lines 257–273:

```erlang
257  guard_one(Pat, {param, TypeExpr, _}, Accept, I, Line, Ctx, Public) ->
258      case record_tag(TypeExpr, Ctx) of
259          {ok, Tag} ->
260              case constrains_kind(Pat) of
261                  true  -> {Pat, []};
262                  false ->
263                      {Var, Pat1} = ensure_var(Pat, I, Line),
264                      {Pat1, [tag_test(Var, Tag, Line)]}
265              end;
266          none when Public ->
267              case kind_only(TypeExpr, Ctx) of
268                  float -> float_guard(Pat, I, Line);
269                  _     -> int_guard(Pat, TypeExpr, Accept, I, Line, Ctx)
270              end;
271          none ->
272              {Pat, []}
273      end.
```

This settles the factual question the ticket poses, precisely, in the code as it exists today:

- **The `{ok, Tag}` branch — the record tag test — never inspects `Public`.** It fires whenever
  `record_tag/2` resolves the parameter's declared type to a single closed record and the clause's
  own pattern does not already constrain `Kind`. Exported and private functions take the identical
  path.
- **The `none when Public` branch — the kind test (int/float) — is gated on `Public` directly**,
  in the `case` guard itself. A private function's matching parameter falls through to the final
  `none ->` clause and gets nothing.

So the ticket's factual premise is exactly right, and it is a one-line fact, not a subtle one:
`Public` is a bound variable threaded all the way from `is_public/1` (line 124) through `function/2`
(line 145) into `clause/4` and `boundary_guards/6`, and one of the two branches reads it while the
other does not.

## 2. Probe: does the private tag test really fire, and the private kind test really not, on this build?

`probe59/Boundary59/boundary59.bs`:

```csharp
module Boundary59

record Order { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

private int InnerRecord(Order o)
InnerRecord(o) -> o.Total

private int InnerOctet(Octet n)
InnerOctet(n) -> n

public int OuterRecord(Order o)
OuterRecord(o) -> InnerRecord(o)

public int OuterOctet(Octet n)
OuterOctet(n) -> InnerOctet(n)
```

```
$ bsc -o out Boundary59
exit: 0
```

The compiler's own `.abstr` output (Erlang Abstract Format, the format `bsc` actually emits and
the tool the task pointed at) for the two private functions:

```erlang
{function,0,'InnerRecord',1,
    [{clause, {11,1}, [{var,{11,13},'O'}],
         [[{op,{11,1},'=:=',
               {call,{11,1},{remote,{11,1},{atom,{11,1},erlang},{atom,{11,1},map_get}},
                   [{atom,{11,1},'Kind'},{var,{11,1},'O'}]},
               {atom,{11,1},'Boundary59.Order'}}]],
         [...]}]}.

{function,0,'InnerOctet',1,
          [{clause,{15,1},[{var,{15,12},'N'}],[],[{var,{15,18},'N'}]}]}.
```

**Confirmed exactly as measured in ticket 46 and re-asserted in F24: the private record-taking
function carries the `map_get('Kind', O) =:= 'Boundary59.Order'` guard; the private int-taking
function's guard list is `[]` — empty.** This is not a stale description; it is the live behaviour
of the `bsc` at HEAD `633ac0097c6c6fb40e0ce7690ac7635a238077c4`.

### The forged-record scenario, direct-parameter shape

`OuterRecord` (exported, `Order` parameter, forwards unchanged to the private `InnerRecord`) also
carries its own `map_get` tag test — because, per §1, the tag test is unconditional on *all*
functions with a bare record parameter, exported or not. So in this shape the value is checked
**twice**: once at `OuterRecord`, once again at `InnerRecord`. Measured, not assumed — the second
check is provably redundant here, because nothing about `OuterRecord`'s own guard depends on
`InnerRecord` existing.

This is the shape 18 §4's own worked example uses (`Describe` calling `Format`), and it is the
shape ticket 59's "not a defect" argument is built to defend. On this shape, **the argument is
right but the reason given is incomplete**: it is not that "the callee guards because the caller's
analysis stopped at its own boundary" (18 §4's sentence, read as an argument for keeping the
callee's own check) — it is that under the *current, unconditional* record-guard scoping, the
caller's own check already fires regardless of function-local-vs-whole-aggregate reasoning, so the
callee's check adds nothing in this specific shape. The `Public` gate that ticket 46 measured as
missing would not create a hole *here* if added — this shape is covered twice either way.

### The forged-record scenario, collection-nested shape — where the argument breaks

`probe59/Boundary59b/boundary59b.bs`, constructed to test the shape 18 §4's example does not cover:
a record arriving *inside* a parameter the boundary guard does not descend into.

```csharp
module Boundary59b

record Order { Id: int, Total: int }

private int InnerRecord(Order o)
InnerRecord(o) -> o.Total

public int SumFirst(list<Order> os)
SumFirst([o, ..rest]) -> InnerRecord(o)
SumFirst([])          -> 0
```

The emitted guard on `SumFirst`'s clause is `[]` — empty, confirmed in the `.abstr`. This is
`record_tag/2`'s own stated criterion working exactly as documented (it requires the parameter's
resolved type to be a bare closed-map shape; `list<Order>` resolves with a non-empty `lists` part
and an empty `maps` part, so `record_tag` returns `none`, and `kind_only` also returns `none`
because the parameter isn't int/float-only either) — this is the same "not guarded through a
collection" limit ticket 46 §4 named for refined ints, now shown to apply identically to records,
which the tickets do not appear to have connected explicitly before this probe.

Run against real forged terms, both a genuinely different-shaped map and a correctly-shaped map
with the wrong tag (`probe_forge.erl`, quoted in full):

```
$ erl -noshell -pa out2 -pa . -eval 'probe_forge:go().'
1. forged, wrong key NAMES entirely (lowercase atoms): {crashed,error,function_clause}
2. forged, right key names, WRONG Kind tag (customer, not order): {crashed,error,function_clause}
3. real Order, correct Kind: 42
4. direct external call to the PRIVATE InnerRecord/1 (not exported): {crashed,error,undef}
```

**`SumFirst` itself does nothing to validate the element it extracts. `InnerRecord`'s own private
tag test is the only thing that catches both forgeries.** This is a real, run, compiled
counter-example to the premise in the ticket's own framing paragraph ("a private function reachable
only through an exported one that's already validated its inputs") — here the exported function has
*not* validated its input, because the record is one projection below the parameter the boundary
guard inspects. Line 4 of the transcript also confirms, independently of the record question, that
a non-exported function is completely unreachable from outside the module — `undef`, not a crash
inside the function — which is the empirical form of § Erlang/OTP survey's file:line finding below.

### The same shape, for the kind test — and here it is genuinely unsound today

`probe59/Boundary59c/boundary59c.bs`, identical shape, refined int instead of record:

```csharp
module Boundary59c

type Octet = int where value >= 0 and value <= 255

private int InnerOctet(Octet n)
InnerOctet(n) -> n

public int SumFirst(list<Octet> ns)
SumFirst([n, ..rest]) -> InnerOctet(n)
SumFirst([])          -> 0
```

Both clauses' guards are `[]` in the `.abstr` — `SumFirst` for the same collection reason as above,
`InnerOctet` because it is private and the kind test is exported-only. Run against forged values
(`probe_forge2.erl`):

```
$ erl -noshell -pa out3 -pa . -eval 'probe_forge2:go().'
float 300.5 nested in list<Octet>, forwarded to private Octet fn: {ok,300.5}
atom foo nested in list<Octet>: {ok,foo}
real valid element 7: 7
```

**This is ticket 18's outcome 3, live, today, in this exact shape.** A function whose `-spec` says
`integer()` returns the atom `foo` and the float `300.5`, with no crash anywhere. Nothing in the
current compiler catches this — not the collection boundary (a known, owed gap per 46 §4/F24 §5),
and not the private callee, because the kind test's exported-only scoping means the one guard that
*would* have caught it, per the record-guard's own precedent, was never emitted.

**This is the sharpest, most concrete finding of this brief.** In the identical collection-nesting
shape, the record type is protected (by the tag test's accidental width) and the int type is not
(by the kind test's deliberate narrowness) — not because records are more dangerous, but because
one guard happens to reach one projection further than the other, for reasons that (per ticket 46's
own account and F24's) were never about this scenario at all.

### The compile-time barrier this depends on

Two further probes (`Boundary59d`, `Boundary59e`) check what the ticket's premise assumes: that "a
private function's every call site is a checked beam-sharp call site" (18 §4) actually holds.

```csharp
// Boundary59d.bs — an unvalidated `term` handed to a record-typed parameter
public int Outer(term o)
Outer(o) -> InnerRecord(o)     // InnerRecord : Order -> int
```
```
$ bsc -o out4 Boundary59d
Boundary59d.bs:12:13: error: Outer hands InnerRecord an argument it does not accept
  argument 1 is not covered by InnerRecord's declared type: term
```

```csharp
// Boundary59e.bs — a bare `int` handed to a refined-int-typed parameter
public int Outer(int n)
Outer(n) -> InnerOctet(n)      // InnerOctet : Octet -> int
```
```
$ bsc -o out5 Boundary59e
Boundary59e.bs:9:13: error: Outer hands InnerOctet an argument it does not accept
  argument 1 is not covered by InnerOctet's declared type: int <= -1 | int >= 256
```

Both refused at compile time, symmetrically, for records and refined ints alike. **This confirms
"checked beam-sharp call site" is real and is not the weak link** — the type checker genuinely
will not let a widened value flow into a narrower private parameter without an explicit narrowing
step (a pattern match, a `switch`, a literal). What § Probe 2/3 above show is a *different* gap:
the checker is checking **static shape correspondence at the call**, which it does correctly and
completely; the collection-nesting hole is that **the runtime value backing a statically-well-typed
`list<Order>`/`list<Octet>` parameter was never itself validated**, because 46 §4 refused per-element
boundary checks as O(n) and foreign-caller-controlled. That is a real, separate, already-named gap
(46 §4's "not guarded through a collection," repeated in F24 §5's "owed" list) — ticket 59's
scope question interacts with it rather than being independent of it, which is new information
this ticket's own text does not connect.

## 3. Cost reproduction — both cited figures hold on this build

### The tag test: 26a's "+14 bytes, flat in field count"

Re-run `wayfinder/prototypes/26a_record_erasure_cost.erl` unmodified on OTP 28.5 (this build is
Linux/x86_64, not the arm64 Darwin the original write-up used — a second, independent hardware/OS
platform for the same claim):

```
3f tagged map discriminator (one map_get)     +28 (+5.0%)    +14 (+19.2%)   +3
8f tagged map discriminator (one map_get)     +28 (+5.0%)    +14 (+19.2%)   +3
```

`bs_emit`'s own `tag_test/3` is exactly this shape — one `map_get` compared with `=:=`/`==`, no
`is_map`, no `map_size`, no per-field `is_map_key` — because the desugared record pattern always
carries `Kind` as a literal key the guard tests directly. **+14 bytes of the `Code` chunk, flat
across 3 and 8 fields, reproduced exactly** on a different OS/architecture from the original
measurement.

### The kind test: 18a's "+3–5 bytes, call time at or below ±0.09 ns/call resolution"

Re-run `wayfinder/prototypes/18a_guard_cost.erl` unmodified, same build:

```
id/1  1 guard (entry cost only)     +4 (+0.8%)     +3 (+4.5%)      +1 instr
add/2 1 guard                       +4 (+0.7%)     +5 (+6.8%)      +1 instr
add/2 2 guards                      +8 (+1.5%)    +10 (+13.5%)     +2 instr
add/4 4 guards                     +24 (+4.3%)    +22 (+23.9%)     +5 instr
```

**+3 to +5 bytes per `is_integer`, reproduced exactly.** (Section 2's call-time timing loop was not
re-run to completion in this session — it runs ~2 minutes per the file's own header and this
session's background run was truncated by the piped `sed` closing early; the qualitative structure
that matters here, byte cost per test, is confirmed, and the original `.md`'s ±0.09 ns/call
resolution finding is cited rather than re-timed. Flagged honestly rather than silently reused as
if re-measured.)

### What the corpus population measurement adds

Neither figure alone answers "how much surface does each scope choice touch" — that needs a count,
which is what the task's §4 asked for.

## 4. Corpus population: how much surface each scope choice actually touches

Grepped `compiler/examples/**/*.bs` and `wayfinder/prototypes/**/*.bs` for `private` functions
whose declared parameter type is a bare record or a bare `int`-refinement (not a tuple, not a
union, not a collection — the shape `guard_one/7` actually tests against):

**Private, bare record-typed parameter** — 11 parameter positions across 10 functions in 6 modules:

| module | function(s) | record type(s) |
|---|---|---|
| `exemplars/25d-database-querying/summary.bs` | `Tally(list<OrderRow>, Totals t)` | `Totals` |
| `exemplars/25d-database-querying/summary.bs` | `Add(Totals t, OrderRow r)` | `Totals`, `OrderRow` (2 positions) |
| `exemplars/25e-dynamic-web-page/rows.bs` | `Row(OrderRow o)` | `OrderRow` |
| `wayfinder/prototypes/31d.../ShapeA/shapea.bs` | `Dispatch`, `Auth`, `Quota` (all `Request r`) | `Request` (3 positions) |
| `wayfinder/prototypes/31d.../Middleware/middleware.bs` | `Auth`, `Quota`, `Dispatch` (all `Request r`) | `Request` (3 positions) |
| `wayfinder/prototypes/31d.../Optional/optional.bs` | `For(User u)` | `User` |

The first three rows are real application code — the exemplars are beam-sharp's own "realistic
program" convention (CLAUDE.md's design-question rule), not measurement scaffolding. The rest are
ticket 31's middleware-comparison prototypes, written for a different question but real, compiled
`.bs` source counted the same way.

**Private, bare refined-int-typed parameter** — 2 parameter positions across 2 functions in 1
module:

| module | function(s) | refinement |
|---|---|---|
| `compiler/examples/Frame/frame.bs` | `Classify(Octet t)`, `Name(Nybble op)` | `Octet`, `Nybble` |

`Escalate/escalate.bs` and `Wire/wire.bs` both declare int refinements (`Height`, `Octet`) but use
them only in **public** functions, so they contribute zero to this count either way.

**Reading this**: today, narrowing the tag test to exported-only would touch roughly 5–6× the
surface that widening the kind test to match it would (11 positions vs. 2). That ratio is an
artifact of how rarely the corpus uses refined ints at all (three modules total, one of them with
a private use) rather than evidence about which guard *matters* more — the collection-nesting probe
in § 2 shows the kind test's narrow scope is the one with a live, demonstrated unsoundness gap,
despite touching the smaller population. Population size and risk are not the same axis here.

## 5. Erlang/OTP survey: is "exported" the only discriminator BEAM offers?

Ticket 18 §1's cost section already claims this; the task asked for it re-confirmed or sharpened
with real file:line citations from the actual OTP 28.5 source this build was compiled from
(`/tmp/erlang-28.5-src`, tag `OTP-28.5`).

**At the compiler**, `lib/compiler/src/beam_asm.erl:162–170` builds two separate chunks from two
separate tables:

```erlang
162  {NumExps, ExpTab0} = beam_dict:export_table(Dict),
163  Exp = flatten_exports(ExpTab0),
164  ExpChunk = chunk(<<"ExpT">>, <<NumExps:32>>, Exp),
...
168  {NumLocals, Locals} = beam_dict:local_table(Dict),
169  Loc = flatten_exports(Locals),
170  LocChunk = chunk(<<"LocT">>, <<NumLocals:32>>, Loc),
```

**At the loader**, `erts/emulator/beam/beam_file.c:343–389` parses both chunks with the identical
routine (`parse_export_table`), into two destinations — `beam->exports` unconditionally,
`beam->locals` only under `BEAMASM` (the JIT build):

```c
343  static int parse_export_table(BeamFile_ExportTable *dest, ...)
382  static int parse_export_chunk(BeamFile *beam, IFF_Chunk *chunk) {
383      return parse_export_table(&beam->exports, beam, chunk);
384  }
386  #ifdef BEAMASM
387  static int parse_locals_chunk(BeamFile *beam, IFF_Chunk *chunk) {
388      return parse_export_table(&beam->locals, beam, chunk);
389  }
390  #endif
```

**At module load, in both the JIT path and the interpreter path, only `beam->exports` is ever
registered as a runtime-callable entry point**:

```c
// erts/emulator/beam/jit/asm_load.c:1170–1176 (BEAMASM / JIT loader)
1170  for (int i = 0; i < stp->beam.exports.count; i++) {
1171      BeamFile_ExportEntry *entry = &stp->beam.exports.entries[i];
...
1176      ep = erts_export_put(stp->module, entry->function, entry->arity);
```

```c
// erts/emulator/beam/emu/emu_load.c:686–702 (interpreter loader — literally titled "Export functions")
686  /* Export functions */
692  for (i = 0; i < stp->beam.exports.count; i++) {
...
700      ep = erts_export_put(stp->module, entry->function, entry->arity);
```

**Neither loader file references `beam.locals`/`stp->beam.locals` at all** (grepped both files for
`locals` — zero matches in `asm_load.c`; `emu_load.c` uses only `exports`). `erts_export_put/3` is
the *only* function that inserts an MFA into the process-global export table that `Mod:Fun(Args)`,
`apply/3`, and `undef` resolution all consult (`erts/emulator/beam/export.c`). A `LocT` entry exists
purely for the loader's own internal label bookkeeping inside the module being loaded; it is never
turned into anything callable from outside.

**This sharpens 18 §1's claim rather than merely confirming it.** The finding there was that
elision is "exported-vs-local, not local-call-vs-remote-call" — a claim about which calls get their
guard optimized away. The file:line trail above shows something stronger: *there is no such thing
as an external call to a non-exported function, at any level the runtime exposes.* It isn't that
BEAM chooses to treat local and remote calls to a private function alike; it's that a private
function has no address a remote caller could name. § Probe 2's `undef` result is the direct,
empirical confirmation of this at the value level, matching the source-level finding.

**What this settles for sub-decision 2.** "Exported" is not merely *a* defensible discriminator —
for the question "can this function be reached by a term this compiler did not itself construct
and route", it is the *only* one the platform makes available; there is no finer signal to read.
What it does **not** settle is sub-decision 5: being reachable only via a checked beam-sharp call
does not mean the *value* flowing through that call was itself validated anywhere — § Probe 2's
collection-nesting case is exactly that distinction made concrete. "Exported" answers *who can call
you*; it does not answer *whether what reaches you was checked*, and the two come apart exactly
where a boundary guard declines to look past one projection (a whole parameter) into what it
contains.

## 6. Verification

No subagent-spawning tool (`Agent`/`Task`) was available in this session's tool environment —
`ToolSearch` was queried and returned nothing matching a general-purpose subagent launcher, only
unrelated tools (`TaskStop`, Linear/GitHub agent tools, `SendMessage` to other live sessions). The
verification pass below is a second, independent, adversarial re-derivation carried out in this
same session rather than a delegated one, and is reported as such rather than claimed as a separate
agent's finding.

**What was re-checked, independently of the first pass's framing:**

- **Re-read `guard_one/7` cold**, without referring back to the ticket's prose, to check whether the
  ticket's claim ("nothing consults `is_public/1`" for the tag test) actually matches the *guard*
  clause of the `case`, not just the absence of an `if Public` inside the branch body — confirmed:
  the `{ok, Tag}` branch has no guard condition at all (line 259 is a bare pattern match), while
  the kind-test branch's guard condition is spelled `none when Public` (line 266). This rules out a
  misreading where `Public` might be consulted implicitly through `record_tag/2` or `Ctx` — it
  isn't; `record_tag/2` (line 494) takes only `TypeExpr` and `Ctx`, no `Public` argument at all.
- **Checked for the circularity failure mode named in the task** — "a probe that assumes the answer
  by constructing a scenario where the unchecked pass-through can't actually occur." The two
  scenarios in § 2 are not that: the direct-parameter shape (`Boundary59`) was built first and
  *disconfirmed* part of the ticket's own framing (showing the pass-through is covered twice, not
  that it's a clean single checkpoint), and the collection-nested shape (`Boundary59b`/`c`) was then
  built specifically to find a case where the pass-through *is* unchecked — and it succeeded,
  producing a real crash-vs-silent-success divergence between the record and int cases. Neither
  probe assumed its conclusion; the second one was constructed *because* the first one's clean
  result looked too convenient, which is the adversarial move the task asked for.
- **Re-ran `Boundary59d`/`Boundary59e` as a falsification attempt** on the "checked call site"
  premise — tried to get the compiler to accept an unnarrowed `term`/`int` flowing into
  `Order`/`Octet`, on the theory that if it succeeded, the whole "site 1 already rejects it" line of
  argument would be void. It did not succeed; both were rejected with residual-carrying diagnostics
  naming the exact uncovered range/type, which is the compiler's exhaustiveness checker working as
  documented elsewhere in the tickets, not a special case built for this probe.
- **Cross-checked the OTP survey against the observed runtime behaviour** rather than trusting the
  source reading alone: § Probe 2 line 4 (`undef` on a direct external call to `InnerRecord/1`) is
  the runtime prediction the `asm_load.c`/`emu_load.c` reading makes, checked against a real `erl`
  process loading the real compiled `.beam`, not asserted from the C source alone.
- **Re-ran the cost prototypes rather than reusing the `.md` numbers verbatim** — both reproduced to
  the byte on a different OS/architecture (Linux/x86_64 here vs. arm64 Darwin in the original
  write-ups), which is stronger evidence than re-reading the existing `.md` files would have been.
- **One gap flagged rather than papered over**: 18a's call-timing section (the ±0.09 ns/call
  resolution claim) was not re-timed to completion in this session (see § 3) — that figure is cited
  from the existing `.md`, not re-measured here, and is reported as such.

**Nothing found that reverses either headline finding.** The record/int asymmetry is real, exactly
as measured in ticket 46 and F24's own text; it is unconditional-vs-exported-only as stated; and the
collection-nesting case is a genuine, reproducible divergence in outcome between the two guards,
not an artifact of how the probe was built.

## Options

**(a) Narrow the tag test to exported-only, matching 18 §4 exactly.**
Evidence for: matches the rule's own stated scope precisely; in the direct-parameter shape (§ 2,
`Boundary59`) it costs nothing, because the exported entry point that let the value in already
re-checks it. Strongest counterargument, measured, not hypothetical: § 2's `Boundary59b` shows a
real shape — a record nested one projection inside an already-typed collection parameter — where
narrowing removes the *only* check that currently exists, turning today's `function_clause` into a
silent bad-field read with no crash anywhere. Narrowing without first closing the collection-nesting
gap (46 §4/F24 §5's owed item) is a measured regression, not a neutral simplification.

**(b) Widen the kind test to private functions too, defense-in-depth, priced at the measured cost.**
Evidence for: § 2's `Boundary59c` shows this is not merely symmetry for its own sake — it is the
fix for a *live*, demonstrated instance of outcome 3 (`SumFirst([300.5])` returning `{ok, 300.5}` from
a function whose `-spec` says `integer()`), in exactly the shape the record guard already defends
against by accident. Priced: § 3/§ 4 — reproduced +3–5 bytes per site, touching 2 known private
positions in the current corpus (§ 4), cheap relative to what it closes. Strongest counterargument:
it is defense-in-depth for the *direct-parameter* shape specifically (§ 2's `Boundary59` twin,
`Boundary59` for ints), where it is provably redundant given the current unconditional tag-test
precedent — so (b) alone, applied uniformly, reintroduces the same double-check cost 18 §4 was
written to avoid, for the cases the collection gap doesn't touch.

**(c) Leave the asymmetry, but make it principled and documented rather than accidental.**
What the probes actually support, and the option this brief leans toward stating plainly: the two
guards should **not** be unified on a single "exported" rule, because the corpus now contains a
real case (§ 2, collection-nesting) where the direct-parameter analysis 18 §4 is built around does
not hold — a value can reach a private function without ever passing through a checked *whole*
parameter of its own type. Until 46 §4/F24 §5's "not guarded through a collection" gap is closed,
**both guards want the wider scope**, not the narrower one — the tag test is not over-cautious by
accident, it is (unintentionally, per F24's own text) covering exactly the hole the kind test's
narrower scope currently leaves open. The principled statement this brief would write, if it were
answering rather than briefing: *the guard fires on every function whose declared parameter type is
a bare record or a bare int-refinement, regardless of exported status, until the collection-nesting
case has its own defence* — which converts (a) from "fix a defect" to "defer a correct narrowing
until its precondition is met," and converts (b) from "add defense-in-depth" to "close a live gap
that happens to look like defense-in-depth." Strongest counterargument: this makes the *stated*
rule depend on an *unrelated* ticket's completion (46 §4/F24 §5), which is exactly the kind of
coupling CLAUDE.md's working rules ask to avoid creating between tickets — a fair objection, and the
honest reply is that the coupling already exists in the compiler's behaviour (§ 2 demonstrates it),
this option only proposes writing it down.

## Recommendation

**(c), with (a) filed as the follow-on once the collection-nesting gap is closed.** The measured
evidence does not support narrowing the tag test today — § 2's `Boundary59b`/`probe_forge.erl`
transcript is a real crash-vs-silent-return divergence, not a hypothetical one, and it is caused
by exactly the "reachable only through a checked call site" argument the ticket's counter-position
relies on being read too broadly (checked-at-the-call is not the same as validated-in-value). Nor
does it support leaving the asymmetry unexplained: § 2's `Boundary59c` shows the *current* kind-test
scoping is not a conservative default that merely costs a little redundancy — it is presently the
weaker of the two guards in the one shape both guards share a blind spot in, and that shape is real
application-shaped code (a `list<T>` parameter with a private per-element helper), not a
constructed edge case. The 5–6× population imbalance in § 4 says narrowing the tag test would touch
more code today, but § 2 says the direction of the *risk* runs the other way — narrowing removes a
working defence, widening closes a real hole — so cost should not be read as tie-breaking evidence
here; it bounds the *size* of either change, not which one is safe. The recommendation is therefore
to widen the kind test to match the tag test's current scope (closing the demonstrated hole in § 2's
`Boundary59c` immediately, at the priced cost in § 3/§ 4), and to record, in whichever ticket ends
up owning it, that both guards' correct long-run scope is "exported-only" **conditional on** the
collection-nesting defence existing — at which point (a) becomes safe to do as a single, symmetric
narrowing of both guards together, closing this ticket's asymmetry from the other direction.

## Probe inventory

All under this session's scratchpad, `probe59/`:

- `Boundary59/boundary59.bs`, `out/` — direct-parameter shape, both guards, both scopes (§ 2)
- `Boundary59b/boundary59b.bs`, `out2/`, `probe_forge.erl` — collection-nested record (§ 2)
- `Boundary59c/boundary59c.bs`, `out3/`, `probe_forge2.erl` — collection-nested refined int (§ 2)
- `Boundary59d/boundary59d.bs` — compile-time barrier check, record (§ 2)
- `Boundary59e/boundary59e.bs` — compile-time barrier check, refined int (§ 2)
- `cost/` — re-run `18a_guard_cost.erl` and `26a_record_erasure_cost.erl` outputs (§ 3)
