# 15 — Error model

Type: grilling
Status: resolved 2026-08-12
Blocked by: 06, 14 (both resolved)

## Question

How are errors represented and propagated?

Weigh: C#-style **exceptions** with `try`/`catch`; **tagged-tuple or `Result` values** as in
Elixir and Gleam; the BEAM's own **`throw`/`error`/`exit`** trio; or a defined combination.

Decide, and state:

- Whether error types appear in a function's return type, and what that does to the
  ergonomics of the multi-clause head — an `Ok`/`Error` union is exactly the shape clauses
  dispatch on, which may be an argument for values over exceptions.
- How this interacts with the totality stance from ticket 12 and with supervision. If
  let-it-crash is the primary error strategy, an elaborate error-value discipline may be
  the wrong instinct imported from a platform without supervisors.
- What happens with **Erlang callers and callees that will throw and exit regardless** —
  the language cannot opt out of the platform's three exception classes, only decide how it
  presents them.
- Whether `try`/`catch` exists at all, and if so what it may catch.

## Notes

HITL. Blocked by ticket 14 because the answer differs sharply depending on whether the
language leans on supervision or on in-process error handling.

## Constraints from ticket 11 — resolved 2026-08-12

**The language now has its first error-*shaped* commitment, and this ticket owns whether it
generalises.** `ValidateAs<T>` — the generated deep validator for a value arriving as a `term` —
returns **`T | :error`**. So the one boundary construct decided so far **fails as a value, not a
crash**, and it does so with a bare atom rather than a structured error.

Three things to settle here that follow directly:

- **Does `:error` carry a payload?** A bare `:error` says validation failed and nothing about
  *where* — which under the standing constraint is a diagnostics problem, since the consumer is an
  agent in a loop (→ [ticket 23](23-what-the-language-owes-an-agent.md)). Gleam's decoders return
  `Result(t, List(DecodeError))` with a path into the term; ticket 11 did not decide whether
  beam-sharp owes the same.
- **Does the `T | :error` shape generalise to every fallible operation**, or is it specific to
  boundary validation? Ticket 10 already put `type option<T> = T | :nothing;` in the prelude, so
  there are now **two** failure spellings in play — `:nothing` and `:error` — and no rule saying
  which is used when.
- **How does this sit against ticket 12?** That ticket owns totality versus let-it-crash;
  `ValidateAs<T>` has effectively voted "value, not crash" for one case. Whether that is precedent
  or exception is a joint question.

Note there is **no `dynamic`** and no exception-like escape: a `term` is narrowed by a clause head
or by `ValidateAs<T>`, so every boundary failure is reachable as ordinary control flow.

## Constraints from ticket 12 — resolved 2026-08-12

Ticket 12 settled the *mechanism* for failing-by-crashing and left this ticket everything about
the *shape* of failure.

**Decided there, binding here:**

- **`raise` is the spelling** for a deliberate crash — a tier-2 borrow from Elixir, verified to
  produce the **error** class (`{:error, %RuntimeError{}}`), the same class as `:erlang.error/1`.
  It is deliberately *not* C#'s `throw`, because the BEAM's `throw` is the catchable non-local-
  return class. Evidence: [`prototypes/12b_raise_classes.exs`](../prototypes/12b_raise_classes.exs).
- **`none` is the bottom type**, first-class and writable. So a user may declare
  `none Reject(Reason);` — a named, greppable, type-checked crash site. Any error-model design
  here can use `-> none` as its "does not return" marker without inventing one.
- **The stance is signature-directed**: fail through the channel your signature declares; `raise`
  where it declares none. So *whether* a function fails as a value is a property of its return
  type, not of a global error-model preference.

**Left open for this ticket:**

- **What `raise` takes.** Elixir's takes a message or an exception struct; beam-sharp has no
  structs decided (→ ticket 26). An atom? A tagged tuple? A structured value?
- **Whether `throw` and `exit` surface at all.** The language cannot opt out of the platform's
  three classes, only decide how it presents them. Ticket 12 committed only to the error class.
- **Whether `try`/`catch` exists**, unchanged.
- **The two failure spellings still have no rule.** `ValidateAs<T>` returns `T | :error` and
  `option<T>` is `T | :nothing`. Ticket 12 §3 explains *when* a failure value rather than a crash
  is used, but not *which* value.
- **A false friend to design around**: `none` is a type with no values; `:nothing` is a value
  meaning absence. They read as near-synonyms and are opposites.

## Constraints from ticket 14 — resolved 2026-08-12

**The crash policy at the OTP boundary is already decided; this ticket inherits it rather than
setting it.** Ticket 14 §4 settled that `[module: GenServer]` names a contract the compiler knows
as a *type*, and the user writes a **narrower** callback signature which the compiler checks for
containment. Per ticket 12 that narrowing *is* the crash policy, so the error model at the OTP
layer is a consequence of signatures, not a separate mechanism.

Three inheritances that bind this ticket:

- **A failed call surfaces as an exit, not as a typed value**, in four of the five ways a client
  function can be handed the wrong pid ([`14d`](../prototypes/14d_wrong_pid_outcomes.erl)):
  `noproc` for a dead pid, the callee's own crash propagated for an unrecognised request, and
  `timeout` for a process that is not a gen_server. Only a *shape collision* returns a wrong
  value, and that is ticket 18's. So an error model that assumes failures arrive as values will be
  wrong about the OTP boundary specifically.
- **The argument position of a callback is `term`, and narrowing it is unsound** — Dialyzer permits
  it silently and you get `function_clause` at runtime
  ([`14e`](../prototypes/14e_callback_contract_containment.md)). beam-sharp rejects it by
  contravariance. Any error-model construct that appears in an argument position inherits this.
- **`(:noreply, s)` is the evasion to watch for.** Ticket 14 §4 rejected the wide OTP contract
  because it makes an evasive `(:noreply, s)` always type-correct on an unrecognised request,
  producing a **five-second silent hang** and then a `timeout` exit *at the caller* — the failure
  reported in the wrong process, at the wrong time, with the wrong reason.

Also relevant: ticket 14 §5 makes `receive` a **filter**, so a message that no `receive` clause
matches is not an error condition — it stays in the mailbox. An error model must not treat an
unmatched selective receive as a failure; the failure is the *timeout*, if one is declared.

## Constraints from ticket 27 — resolved 2026-08-12

**`T` is now a real type variable, which changes what this ticket's central question is asking.**

This ticket reasons about `option<T>` and `ValidateAs<T>`'s `T | :error` as though both were
prelude aliases of the same kind. After 27 they are **different kinds of thing**, and the two
failure spellings question has to be re-read accordingly:

- **`option<T>` is an ordinary parametric alias** — a real type-level function over a real type
  variable, which a user could have written. 27 §4 fixes the spelling as declared and
  C#-`T`-conventioned.
- **`ValidateAs<T>` is a codegen obligation, and 27 §8 gives it a hard new rule: it requires a
  ground type argument.** `ValidateAs<TSource>` inside a polymorphic function is **rejected at
  compile time** — you cannot generate a structural check for a type nobody has chosen yet. This
  joins ticket 11's existing rule that it rejects arrows.

**The sharpest consequence for this ticket**: the two failure channels are not symmetric in where
they can appear. `option<TSource>` is writable anywhere, including inside a polymorphic function.
`ValidateAs<...> -> T | :error` is only writable where the type is ground — which means **a
polymorphic function cannot perform boundary validation at all**, and must take already-validated
values or take the validator as an argument. If this ticket wants a uniform rule for "when does a
failure become a value rather than a crash", that rule cannot be stated over `ValidateAs` alone,
because `ValidateAs` is unavailable in a region of the language where `option<T>` is fine.

**Also relevant**: 27 §6 measured that an emitted polymorphic `-spec` is not enforced by Dialyzer.
If this ticket's error model surfaces failure through the *type*, that surfacing is inert at the
Erlang boundary for any polymorphic function. → shared with ticket 18.

---

## Answer — resolved 2026-08-12

**The headline question was already closed before this session opened, and the ticket did not
know it.** "Exceptions, `Result` values, or the BEAM's trio?" was answered by
[ticket 12](12-totality-vs-let-it-crash.md) §3: the stance is **signature-directed** — write the
honest value your return type admits, `raise` where it admits none. There is no global error-model
preference to choose, because the choice is per-signature. What was genuinely open was the *shape*
of failure, and that turned out to have a defect in it.

### 1. The untagged failure channel collapses, and the collapse is a declaration error

**The prelude was already carrying a degenerate type and nobody had noticed.**

[Ticket 09](09-union-representation.md) §4 fixed the rule that a union is **normalised first**:
`:ok | atom` *is* `atom`, because a singleton absorbed by a cofinite top is not a distinct member.
[Ticket 10](10-atoms-in-a-csharp-skin.md) §5 then put `type option<T> = T | :nothing;` in the
prelude, and [ticket 11](11-type-system-shape.md) gave `ValidateAs<T>` the return type
`T | :error`. Turning 09's own rule on those two types is what this ticket found.

Measured against a shipping implementation of the same theory (Elixir 1.19.5,
`Module.Types.Descr` — the same instrument ticket 10 used), see
[`prototypes/15a_untagged_failure_collapse.exs`](../prototypes/15a_untagged_failure_collapse.exs):

| declared type | normalised | failure channel |
|---|---|---|
| `option<int>` = `int \| :nothing` | `%{atom: {:union, %{nothing: []}}, bitmap: 4}` | survives |
| `option<bool>` = `true \| false \| :nothing` | three literal atoms | survives |
| `option<atom>` = `atom \| :nothing` | `%{atom: {:negation, %{}}}` — i.e. `atom` | **absorbed** |
| `ValidateAs<atom>` = `atom \| :error` | `%{atom: {:negation, %{}}}` — i.e. `atom` | **absorbed** |
| `option<option<int>>` | identical to `option<int>` | **absorbed** |

Three consequences, in ascending order of how much they cost:

- **Ticket 10 §5 already wrote the degenerate line.** Its worked example is
  `a := ToExistingAtom(input); // atom | :nothing — honest weak residual`. That declared type
  *is* `atom`. A caller cannot write the failure clause, because there is no failure member left
  to match. The comment calling it an "honest weak residual" was true of the intent and false of
  the type.
- **Untagged `option` does not nest.** `option<option<int>>` is `option<int>`, so "key absent"
  and "key present, value absent" are the same value. This is the classic reason the ML family
  tags its option type, and it arrived here as a consequence rather than a choice.
- **It is silent.** Nothing in the pipeline reports it: the algebra is behaving correctly, and
  09's discriminability check never fires because after normalisation there is only one member to
  check.

**Decided: the shape stays untagged, and the collapse is rejected at the declaration.**

**The check is one predicate, not a list of cases.** Reject an instantiation when

> `T | <failure member>` ≡ `T`

Stated as absorption by an atom top it would cover only `option<atom>` and an implementer would
write the cofinite check alone. The equation covers all three measured cases with one criterion,
across both channels: `option<atom>` (`:nothing` ⊆ `atom`); `option<option<int>>` (`:nothing` ⊆
`int | :nothing` — literally `Descr.equal?(outer, inner)` returning true in 15a); and
`(atom, binary) | (:error, binary)` from the tagged measurements, where the collision is a tuple
shape rather than an atom. It is also decidable with the equality the algebra already provides.

```
type option<T> = T | :nothing;      // unchanged

option<int>  x;                     // ✓
option<bool> y;                     // ✓ — true | false | :nothing, three literal atoms
option<atom> z;                     // ✗ error at the declaration:
                                    //   `:nothing` is absorbed by `atom`; the failure
                                    //   channel does not survive normalisation
                                    //   hint: tag it — (:some, atom) | :nothing
```

**Why not simply tag both channels**, as Elixir and Gleam do. Tagging fixes every case and nests
correctly, and it is what sits on the other side of the interop boundary (`{ok, V} | {error, R}`).
It was rejected because the cost falls precisely on the language's showcase: [ticket
08](08-head-and-guard-syntax.md) settled `as T` yielding `T | :nothing`, and the untagged union is
what makes narrowing read well in a clause head. Paying a wrapper at every narrowing site to fix
a case that only bites at the atom top is the wrong trade — and the untagged union is one of the
few things the set-theoretic type system buys over a nominal ADT, so declining to use it in the
place it is most valuable would be spending the type system's advantage on nothing.

**This is [ticket 09](09-union-representation.md)'s own rule applied, not a new mechanism.** 09
rejects indiscriminable unions *at the declaration, not at the match site*, "so the diagnostic
lands where the fix is". The same argument decides where this check lives. It is also an **error,
never a warning** — 09 was emphatic about that, and [ticket 03](03-prior-art-static-multiclause.md)
found Caramel shipped output with Warning 8 let through.

**The check is affordable because of [ticket 27](27-parametric-polymorphism.md) §1**: instantiation
is *matching, not solving*, so deciding whether the failure member survives normalisation at
`option<atom>` is a normalisation of a known type, not a constraint problem.

**Honest cost**: `option<T>` becomes the first *partial* prelude type — legal for most `T`, rejected
for some. Every other prelude entry is total. An author meets a rule with no analogue elsewhere in
the language, which is exactly the tax the map's borrow heuristic exists to avoid. Accepted, because
the alternative is shipping a type that is quietly wrong.

### 2. Absence carries nothing; failure carries a reason

The two failure spellings had no rule. They have one now, and it is not arbitrary — the tag falls
out of the payload rather than being chosen alongside it.

```
type option<T>    = T | :nothing;          // absence — nothing to report
type result<T, E> = T | (:error, E);       // failure — a reason to report
```

**`:nothing` is bare because absence carries no information.** A lookup that finds nothing has
said everything there is to say. **`(:error, E)` is tagged because failure carries a reason**, and a
member with a payload is a tuple whether or not anyone wanted a tag.

Measured (extends 15a; `Module.Types.Descr`, Elixir 1.19.5):

```
atom | :error                        collapsed? true    ← bare atom absorbed
atom | (:error, binary)              collapsed? false   ← tagged member survives
term | (:error, binary)              collapsed? true    ← only the top absorbs everything
(atom, binary) | (:error, binary)    collapsed? true    ← and a matching 2-tuple shape
```

**So the payload is not only the diagnostics answer ticket 11 asked for — it is what moves the
failure member from absorbed to discriminable.** §1's check stays necessary (it still catches
`option<atom>` and the residual tuple-shape collision) but fires far less often on the `result`
channel than on the `option` one. The two decisions are load-bearing for each other.

**`result<T, E>` is named in the prelude, stratum 1.** Naming is aliasing under
[ticket 09](09-union-representation.md) — the name never enters the algebra, so
`result<int, atom>` and `int | (:error, atom)` are the same type and neither is more real. The name
buys readability only, and it is named for consistency with `option<T>`, which ticket 10 named on
the same grounds. Under [ticket 27](27-parametric-polymorphism.md) §4's rule it is an ordinary
parametric alias a user could have written, which is stratum 1's own test.

**This amends [ticket 11](11-type-system-shape.md).** `ValidateAs<T>` returns
**`result<T, ValidationError>`**, not `T | :error`. Ticket 11 flagged the payload question and left
it here; the collapse measurement settles it, because the bare form is degenerate for exactly the
`T` a deep validator is most likely to be generated over.

**`ValidationError` is a path into the term plus the expected type** — the shape Gleam's decoders
return (`Result(t, List(DecodeError))`), and the only precedent that hands an agent something
actionable rather than a fact it already knew. Spelled as a tuple for now; **if
[ticket 26](26-data-modelling.md) lands a record form, this is a candidate to become one** and is
noted there. A bare `:error` from a synthesised O(n) structural traversal tells the consumer
nothing except that the traversal ran, which under the standing constraint is the expensive kind of
diagnostic.

**Rejected: one channel only.** Collapsing to `option<T>` everywhere is the smallest surface and
one rule instead of two, but it discards the reason — and the standing constraint says the consumer
is an agent in a loop, for which the reason is the whole value of the diagnostic.

### 3. `raise` takes any term, and shares its vocabulary with `E`

[Ticket 12](12-totality-vs-let-it-crash.md) §5 settled the spelling and deferred the payload here.
Two things it decided narrow this question more than it appears:

- `raise` produces the **error** class, the same as `:erlang.error/1` — which accepts any term.
- The reason sits in the **argument position** (`none Reject(Reason);`), not in an effect on the
  signature. So beam-sharp has **no checked-exception surface to design**. A function that raises
  says so by returning `none`; what it raises is data it was handed.

**Decided: any term, with the spec recommending an atom or a tagged tuple, and the reason
vocabulary shared with `result`'s `E`.**

The sharing is the part that earns its place. Because a raised reason and a carried reason are the
same kind of thing, escalation between the two channels is an ordinary function — no `?`, no
`unwrap` primitive, no new construct:

```
T Unwrap<T, E>(result<T, E>);
Unwrap((:error, e)) -> raise e;
Unwrap(v)           -> v;
```

Note this typechecks under [ticket 27](27-parametric-polymorphism.md) §1's opacity rule: clause 1
matches *structure around* `E`, clause 2 binds the opaque `T`. And it exercises §1 of this ticket
honestly — if `T` were instantiated to something containing `(:error, _)`, clause 1 would fire on a
**success** value, which is precisely the instantiation the declaration check now rejects. The two
decisions are consistent for every non-pathological instantiation.

**A known limit, stated rather than claimed away.** The check is `T | failure ≡ T`, which a success
type that is *itself* an `(:error, _)` tuple with a **different payload type** escapes. Verified:
for `result<(:error, int), binary>`, the union `(:error, int) | (:error, binary)` normalises to
`(:error, int|binary)`, which is **not** `T` — so the declaration is accepted, and yet `Unwrap`'s
first clause matches a *success* value. Pathological, and it changes none of the six decisions;
recorded because every other limit in this map is.

**Rejected: restricting to atom or tagged tuple.** It would guarantee cheap logging and trivial
discrimination, and it matches what OTP itself does (`:noproc`, `{:badmatch, V}`). But it is a
tier-3 rule with a thin justification — the BEAM permits any term, every neighbour language permits
any term, and an author would meet a restriction that exists nowhere else on the platform. The
recommendation goes in the spec, not the grammar.

**Rejected: a declared error type.** The C#/Elixir-exception shape would give crash reasons a
structure an agent could rely on, but [ticket 26](26-data-modelling.md) has not settled what a
record *is*, so this ticket would be deciding on top of fog — and it would break the symmetry that
makes `Unwrap` free.

### 4. There is no `try` in the surface; the compiler emits it at declared foreign boundaries

This was the question that most needed measuring rather than arguing, and the measurement moved it.

**Ticket 14 (14d) established that four of five wrong-pid failures reach the caller as an exit.**
Ticket 12 accepts that — the caller dies, the supervisor restarts. But a client API that wants to
declare `result<T, E>` rather than die needs *some* way to convert an exit into a value, and the
obvious answer is `try`.

Measured on OTP 28, [`prototypes/15c_surviving_a_callee_crash.erl`](../prototypes/15c_surviving_a_callee_crash.erl):

```
1 plain call, server crashes          caller DIED: {deliberate_failure, ...}
2 try/catch, server crashes           caller SURVIVED, {error, {exit, ...}}
3 monitor+receive, server crashes     caller SURVIVED, {error, {down, deliberate_failure}}
4 monitor+receive, happy path         caller SURVIVED, {ok, 42}
5 monitor+receive, dead pid           caller SURVIVED, {error, {down, normal}}
6 local raise in caller's own code    caller DIED: my_own_bug
7 local raise, wrapped in try         caller SURVIVED, {error, {error, my_own_bug}}
```

**Case 3 is the finding: `try` is not needed for remote failure at all.** `monitor` + `receive`
converts a callee crash into a value using nothing but what [ticket 14](14-concurrency-and-otp-model.md)
already put in the language — `receive` as a filter (§5), with ordinary clause heads. It is also
what `gen_server:call` is *built from*, so this is the platform's own mechanism rather than a
workaround. And it yields a **strictly better reason**: case 3 gets `{down, deliberate_failure}`
where case 2 gets the same reason wrapped in a `gen_server:call` frame.

That leaves exactly one gap, cases 6–7: a failure in your **own** process, with no boundary to
observe it across. It splits in two, and only one half is a real gap:

- **Your own `raise`** means, per ticket 12, *my signature admits no honest value here*. Catching it
  back reverses a decision the author already made in the type. Not a gap.
- **A foreign call that throws** — `binary_to_integer("abc")` is `error:badarg`, in-process, and it
  is not the author's decision at all. This is the gap.

**Decided: no `try` in the surface. Declaring a foreign function's return type as `result<T, E>`
makes the compiler emit the wrapper.** The same codegen-obligation pattern as `ParseAtom<T>`
(ticket 10) and `ValidateAs<T>` (ticket 11): the author declares the type, the compiler generates
the check.

```
// the author writes only this
result<int, foreign_error> ParsePort(binary) = [Erlang("erlang", "binary_to_integer")];
```

**Gleam is the measured precedent, and it occupies this position rather than the stricter one.**
`gleam_erlang` v1.3.0 exposes **no `rescue`** in the surface language — no `Crash`/`Thrown`/
`Errored` types — while `gleam_erlang_ffi.erl` uses `try`/`catch` in **nine places**, doing exactly
one job:

```erlang
%% gleam_erlang_ffi.erl:13
try {ok, binary_to_existing_atom(S)}
catch error:badarg -> {error, nil}
```

and its remote-failure route is `ProcessDown(monitor, pid, reason)` — case 3.

**So the choice is not whether the `try` exists, but who writes it.** Gleam's is hand-written
Erlang *outside the type system*, where the mapping from `badarg` to `Error(Nil)` is a human's
assertion nobody verifies. beam-sharp's is generated from a declared signature, so it is checked
and inherits every rule already decided.

**Rejected: no exception surface at all.** Once Gleam was measured, this option had **no precedent
behind it** — no language examined declines a foreign-boundary catch. It would also leave
`ParsePort` unwritable without spawning a process to fail in, which is absurd for
`binary_to_integer`.

**Rejected: `try`/`catch` as general surface syntax.** It is the tier-1 borrow and both audiences
read it on sight. It was refused because it is a *general* escape hatch —
[ticket 21](21-escape-hatch-precedents.md) is the ticket that established these are the hard thing
to keep sound — and because it actively invites exceptions-as-control-flow, which fights ticket 12's
whole stance. **Chosen partly for reversibility**, on ticket 13's reasoning: adding a general `try`
later is purely additive, while removing one from a released language is not.

**A correction recorded against my own reasoning in this session.** The option above was first put
as "Gleam's and Elm's line". That pairing was rhetorical, not researched. Gleam was then measured
into the *opposite* position, and Elm — which was **descoped from ticket 21 by instruction**, with
its one surviving question moved to [ticket 18](18-boundary-defence.md) — was reached for to keep
the option standing. Elm is a poor analogue here regardless: it targets JavaScript, has no
processes, no supervision and no let-it-crash, so its answer to "what happens when a call fails"
comes from a different constraint set. Ticket 21's conclusion applies to it directly — mechanisms
from languages that control what a program may *reach* do not transplant to a platform whose
problem is what may reach the *program*. **No Elm claim is load-bearing in this decision**, and the
Elm question stays with ticket 18, which carries a standing instruction not to let it expand.

### 5. `throw` and `exit` have no spelling to produce; the class survives on catch

The language cannot opt out of the platform's three classes, only decide how it presents them. It
presents them **asymmetrically**: one way to produce, three ways to recognise.

**Producing.** `raise` is the only spelling, and the other two have no job left:

- **`throw`** is non-local return. Clause heads and the `result` channel replace it, and ticket 12
  §5 already ruled the spelling a false friend — the BEAM's `throw` is the *catchable* class, so a
  C# reader would read recoverable where the language means fatal.
- **`exit`** as *stopping yourself* is a return value under ticket 14 §4: `(:stop, Reason, State)`.
  As *killing someone else* it is concurrency vocabulary and belongs to ticket 14, not to the error
  model.

**Recognising: the generated wrapper catches all three.** The feared hazard was that a wide
`catch exit:` would swallow a supervisor's shutdown, turning an orderly kill into a value the code
ignores. Measured on OTP 28,
[`prototypes/15d_which_classes_a_wrapper_catches.erl`](../prototypes/15d_which_classes_a_wrapper_catches.erl):

```
--- locally raised, inside the wrapper ---
1 error raised locally                         SURVIVED  {caught,error,boom}
2 throw raised locally                         SURVIVED  {caught,throw,boom}
3 exit called locally                          SURVIVED  {caught,exit,boom}
4 call to a dead pid                           SURVIVED  {caught,exit,{noproc,...}}

--- exit SIGNAL from another process ---
5 linked process dies while wrapper is running DIED      killed_by_peer
6 explicit exit signal sent to us by pid       DIED      terminated_by_peer
7 exit(Pid, kill)                              DIED      killed
```

**The hazard does not exist.** A locally-raised `exit/1` and an exit *signal* are two different
mechanisms sharing a keyword: signals are not catchable, so cases 5–7 die regardless of the
wrapper, and no supervision decision can be swallowed by one.

**Case 4 is why narrowing would be a mistake.** `gen_server:call` to a dead process raises
`exit({noproc, …})` **in the caller's own process**, so it is catchable — which is exactly what
makes `try … catch exit:` around a call idiomatic and safe in Erlang today. An error-only wrapper
would fail to catch the commonest foreign failure on the platform.

**The class is carried, in a compiler-known prelude type:**

```
type foreign_error = (:error, term) | (:throw, term) | (:exit, term);
```

Stratum 2 alongside ticket 14 §6's `Down`/`Exit`/`Timeout`, because a user cannot mint it — it is
produced only by generated code. The three members are discriminable by their literal atom tags, so
§1's check never fires on them. And the class is then just another clause head:

```
Report((:error, :badarg))     -> "not a number";
Report((:exit, (:noproc, _))) -> "server is down";
Report((:throw, r))           -> $"library signalled {r}";
Report(n)                     -> $"port {n}";
```

**Rejected: flattening the class away.** A smaller and freer `E`, reading better at the call site —
but case 4 shows the reasons are not self-describing. `{noproc, {gen_server, call, […]}}` needs the
`exit` tag to be legible as *the callee is dead* rather than a value the callee returned. Under the
standing constraint those are different repairs.

**Cost, stated**: `E` is fixed for foreign calls rather than freely chosen, so an author writes
`result<int, foreign_error>` and adds a mapping step if they want a domain reason.

### 6. Sequencing is required, and its spelling is ticket 17's

This ticket's own framing asked whether the three helper functions ticket 01's evaluator needed were
"a virtue or a tax". **The example gets cheaper under §2 and the question survives anyway.** Written
against the untagged `result`, the combine needs no helpers at all — clause ordering *is* the
left-biased choice:

```
result<int, E> Combine<E>(result<int, E>, result<int, E>);
Combine((:error, _) e, _) -> e;
Combine(_, (:error, _) e) -> e;
Combine(x, y)             -> x + y;
```

The tax is real for **pipelines** of fallible steps, where each stage needs a named function to
unwrap before the next runs. Two findings constrain whoever spells it:

- **`with` is unavailable.** Elixir's sequencing construct is `with`; C#'s `with` is record update,
  which [ticket 26](26-data-modelling.md) owns and [ticket 05](05-csharp-functional-inventory.md)
  found becomes *more* central here than in C#, since there is no mutation at all.
- **LINQ query syntax is the leading candidate, and it is a tier-1 borrow.** Ticket 05 established
  the query translation is a pure syntactic rewrite bound before type binding, needing a rule for
  eleven names and no `IEnumerable<T>` — which is why C# programmers already use query syntax as
  do-notation over non-collection types. It would cost **nothing new** if ticket 17 adopts LINQ for
  collections anyway, and would be expensive if 17 chooses `|>` chaining and this construct exists
  solely for error sequencing.

**Decided: this ticket states the requirement and hands the spelling to
[ticket 17](17-pipeline-and-comprehension.md)** — open and unblocked on the frontier — because 15
owns the error *model* and 17 owns the sequencing *idiom*, and the two must match.

**A `?` operator was considered and not chosen here.** It is the smallest thing that removes the tax
and is independent of 17's choice, but it introduces early return into a language otherwise built
entirely from total clauses, putting a hidden exit in the middle of an expression. Recorded so 17
does not have to rediscover it.

### The guarantee, extended

Ticket 11 stated it as: *"Every case your types admit has a clause — and everything from outside is
a `term` until you match it."* This ticket adds the failure half without changing the shape:

> **Failure is a value where your signature declares one, and a crash where it does not — and
> which of those you chose is readable in the type.**

### Consequences propagated

- **[Ticket 11](11-type-system-shape.md) — amended.** `ValidateAs<T>` returns
  `result<T, ValidationError>`, not `T | :error`. The bare form is degenerate for exactly the `T`
  a deep validator is most likely to be generated over.
- **[Ticket 17](17-pipeline-and-comprehension.md) — inherits a requirement.** A sequencing
  construct for `result`; `with` unavailable; LINQ query syntax the leading candidate, free if 17
  adopts LINQ regardless. `?` recorded as the alternative.
- **[Ticket 26](26-data-modelling.md) — two.** `with` is spoken for by record update and cannot be
  the sequencing spelling. And `ValidationError` is a tuple today and a candidate to become a
  record if 26 lands one.
- **[Ticket 18](18-boundary-defence.md) — the foreign boundary now has a declared shape.**
  `foreign_error` and the compiler-emitted wrapper are a defence at *one* of the eight channels,
  emitted where beam-sharp already compiles — which is the mechanism ticket 21 concluded was the
  only one reaching all eight. 18 decides the other seven.
- **[Ticket 23](23-what-the-language-owes-an-agent.md) — the class tag is agent-actionable.**
  `(:exit, (:noproc, _))` and `(:error, :badarg)` are different repairs; a flattened reason is not.
  This is a concrete instance of 23's diagnostics-as-interface question.
- **[Ticket 24](24-testing-story.md) — one category retired, one added.** §1's check means a test
  asserting "the failure channel is reachable" tests the compiler. But `option<T>`'s partiality is
  a new thing worth a test at the boundary.
- **[Ticket 10](10-atoms-in-a-csharp-skin.md) — a line corrected.** §5's
  `ToExistingAtom(input) // atom | :nothing` is the degenerate case; the declared type is `atom`.
  Under §1 that instantiation is now rejected, so `ToExistingAtom` must be respelled.
- **The walking skeleton (map fog) — one measurement.** The generated foreign wrapper is a fourth
  codegen obligation whose cost is unmeasured, and it stacks with `ValidateAs<T>`'s traversal.
- **`CONTEXT.md`** gains `result`, `foreign_error`, `ValidationError` and the absence/failure rule.

### Evidence

| file | what it establishes | provenance |
|---|---|---|
| [`15a_untagged_failure_collapse.exs`](../prototypes/15a_untagged_failure_collapse.exs) | `option<atom>`, `ValidateAs<atom>` and `option<option<int>>` all normalise to their success type | local — Elixir 1.19.5 |
| [`15c_surviving_a_callee_crash.erl`](../prototypes/15c_surviving_a_callee_crash.erl) | `monitor`+`receive` replaces `try` for remote failure, with a better reason; local failure is the only gap | local — OTP 28 |
| [`15d_which_classes_a_wrapper_catches.erl`](../prototypes/15d_which_classes_a_wrapper_catches.erl) | all three classes are catchable when raised locally; exit *signals* are not catchable at all | local — OTP 28 |
| `gleam_erlang` v1.3.0 source | no surface `rescue`; nine `try`/`catch` in the FFI; `ProcessDown` for remote failure | src — read from the resolved package |

**A methodological note worth keeping.** The first run of 15c reported that *every* case survived,
including the unprotected one. The harness was wrapping each case in `catch` — supplying the very
protection the probe existed to measure. The correction is recorded in the file itself so it is not
repeated. A probe that returns the answer you expected is the one to re-read.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Error model](issues/15-error-model.md) — **the headline question was already closed and the
  ticket did not know it**: ticket 12 §3's signature-directed stance means there is no global
  error-model preference to pick. What was open was the *shape* of failure, and it had a defect in
  it. **The untagged failure channel collapses** — measured on Elixir 1.19.5, `option<atom>`,
  `ValidateAs<atom>` and `option<option<int>>` all normalise to their success type, because ticket
  09's own normalisation rule absorbs a singleton into a cofinite top before discriminability is
  ever asked. **Ticket 10 §5 had already written a degenerate line** (`ToExistingAtom // atom |
  :nothing` *is* `atom`). The shape stays untagged and **the collapse is an error at the
  declaration** — 09's rule turned on the prelude, diagnostic landing where the fix is; tagging both
  channels was refused because the cost falls on `as T`, the showcase narrowing. The rule for the
  two spellings is **absence carries nothing, failure carries a reason**: `option<T> = T |
  :nothing` bare, `result<T, E> = T | (:error, E)` tagged — **and the tag is a consequence of the
  payload, not a separate choice**, since `atom | (:error, binary)` does *not* collapse where `atom
  | :error` does. So the payload is what makes the channel survive, not merely what makes it
  informative. **Amends ticket 11**: `ValidateAs<T>` returns `result<T, ValidationError>`. `raise`
  takes **any term** (exactly `:erlang.error/1`) sharing its vocabulary with `E`, which makes
  escalation an ordinary three-line function rather than a `?` operator. **There is no `try` in the
  surface**: measured, `monitor`+`receive` replaces it for *remote* failure using only ticket 14's
  `receive`, and yields a **better** reason than `try` does — leaving foreign in-process throws as
  the only gap, closed by a compiler-emitted wrapper from the declared return type, the fourth
  codegen obligation. **Gleam was measured into this position, not the stricter one** — no surface
  `rescue`, nine `try`/`catch` in its FFI — so the question was never whether the `try` exists but
  whether it is *checked* or a human's unverified assertion. `throw` and `exit` get **no spelling to
  produce** (clause heads and `(:stop, …)` already do their jobs) and the wrapper catches all three
  classes into `foreign_error`, **safe because exit *signals* are uncatchable** — a locally-raised
  `exit/1` and a signal are different mechanisms sharing a keyword, so no supervision decision can
  be swallowed. Sequencing is **required and handed to ticket 17**: `with` is spoken for by ticket
  26's record update. *A methodological note kept in the file: the first run of 15c reported every
  case surviving, because the harness wrapped each in `catch` — supplying the protection the probe
  existed to measure.*
```
