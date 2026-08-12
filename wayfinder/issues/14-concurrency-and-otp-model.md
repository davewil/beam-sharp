# 14 — Concurrency and the OTP model

Type: grilling
Status: resolved
Blocked by: 05, 06 — both resolved

## Question

What concurrency vocabulary does the language expose?

Decide:

- **Does `async`/`await` survive?** C# developers arrive fluent in `Task` and `await`, but
  the two models are genuinely different: `Task` is a future over a thread pool with
  implicit continuation capture; a BEAM process is an isolated, supervised, addressable
  entity with a mailbox. Mapping `await` onto a process wrapper is possible and may be a
  trap — it would make the most important thing about the platform look like the least
  important thing about C#. The alternative is dropping it for explicit
  `spawn`/`send`/`receive`.
- **How are OTP behaviours expressed?** GenServer, Supervisor, Application — as some
  declaration form, or as plain modules plus attributes?
- **How do multi-clause heads meet OTP callbacks?** This is the feature's best showcase:
  one clause per message shape in `handle_call`/`handle_cast`/`handle_info`. Make the
  ergonomics here excellent; it is the demo.
- **How are message types declared** so that `handle_info` clauses can be checked
  exhaustive over the set of messages a process can receive? Gleam invented typed
  `Subject`s for this. What is the equivalent here, given messages can also arrive from
  untyped Erlang code, from monitors, from timers, and from `:EXIT` signals?
- Links, monitors, and process identity in the type system, if at all.

## Constraint from ticket 06 — the easy route is closed

**Gleam's answer to typed OTP was to not implement the behaviour contract at all.** It emits
no `-behaviour` attribute and builds its own typed abstractions instead. That option is
unavailable here: ticket 00 makes `handle_call/3` and `handle_info/2` the headline feature's
showcase, so this language must actually inhabit the OTP callback contract — which makes
**mailbox defence unavoidable** rather than deferrable to a library.

Useful and cheap: `-behaviour` has **no runtime effect**, verified locally on OTP 28. A module
with no such attribute starts and answers calls under `gen_server:start_link/3`; one that
declares it but omits `handle_cast/2` still compiles. `gen_server` dispatches via
`fun Mod:handle_call/3` and gates optional callbacks with `erlang:function_exported/3` — it
never reads behaviour metadata. Only exports matter. Neither Gleam nor purerl/Pinto emits
`-behaviour` anywhere.

**The alternative shape, from purerl/Pinto**: closures-as-messages through one generic callback
module. Rather than the user's module implementing the callbacks, a single generic module does,
and messages carry the closure that handles them. Worth weighing against per-module callbacks
with multi-clause heads — it is the other end of the design space and it ships today.

**A free guarantee worth knowing about**: the violation channel runs both ways. OTP *validates
the shapes you return* from callbacks and kills the process if they are wrong. So return
positions are already runtime-checked by the platform, at no cost to this language.

## Prior art to consult first (from ticket 03)

- **Alpaca typed process messages by whole-call-graph inference** — it worked out the message
  type of a process from every send site, rather than requiring a declaration. That is a real,
  shipped answer to this ticket's hardest sub-question and should be understood before
  designing an alternative.
- **`Pid[τ]`** — a process identifier parameterised by the message type it accepts. Simple and
  probably necessary in some form.
- **The Uniform-Reply rule is recorded as a *rejection*, not a candidate.** It requires every
  reply from a process to have one type — the explicit opposite of the union-of-clause-types
  approach ticket 00 committed to. Useful precisely as the thing this language does not do.
- **Gleam's actor and message typing is a known gap in the evidence.** Ticket 03 could not
  establish it from primary sources and deferred it here rather than filling it from memory.
  Establish it properly as part of this ticket — Gleam's typed `Subject` machinery is the
  closest existing answer to exhaustive `handle_info` and must not be characterised second-hand.

## Notes

HITL. The layer where the headline feature best justifies itself, which is why OTP is inside
the destination rather than deferred.

## Constraints from ticket 12 — resolved 2026-08-12

**This ticket now carries the crash decision.** Ticket 12 settled that the boundary stance is
**signature-directed**: write the honest value your return type admits, `raise` only where it
admits none. That makes the callback return types decided here the thing that determines where
crashing is the only honest answer.

Worked, from ticket 12 §3:

- `(:reply, int, Account) HandleCall(term, From, Account);` admits **no honest value** for an
  unrecognised request — fabricating an `int` is a lie the type system accepts — so the boundary
  clause must `raise`.
- `(:noreply, Account) HandleInfo(term, Account);` makes `(:noreply, a)` completely honest: the
  message was not addressed to you. No crash needed, and this is *not* silence.
- Widening to `(:reply, int | :bad_request, Account)` makes the value channel appear and the crash
  disappear. **The decision moves into the signature**, where a caller can see it.

So: when specifying `HandleCall`, `HandleCast`, `HandleInfo` and `Init` return types, decide
deliberately whether each admits a failure alternative. That choice *is* the crash policy, and
"crash in a call, ignore in a loop" is only the shadow it casts — ticket 12 rejected the positional
rule for exactly this reason.

Two further inheritances:

- **Every callback taking a `term` gets a mandatory catch-all**, per ticket 11, and it is legal
  because the residual is open (ticket 12 §2). Mailbox defence is unavoidable, as this ticket
  already noted — but the checker now *forces* the clause rather than merely recommending it.
- **`raise` exists** (ticket 12 §5) and produces the BEAM error class, so a callback that crashes
  dies with `function_clause`-shaped information intact and the supervisor sees a well-formed exit
  reason (ticket 12 §6).

## Constraints from ticket 13 — resolved 2026-08-12

**There is no OTP facade to design. The problem stops existing.**

Ticket 13 §3 settled that **sub-modules are source-only** — one `.beam` per aggregate, not one per
operation. So `gen_server`'s `Mod:handle_call/3` lands in the aggregate module, exactly where OTP
looks for it, with no generated delegation. Prototype 01c's facade problem is not solved here; it
is deleted. Erlang callers likewise get a normal module for free (`'Shop.Orders.Order':apply(O, E)`),
which is what ticket 06 asked for.

What this ticket still owns is unchanged: the concurrency and OTP model itself. But it should not
budget for facade machinery, and it should assume **the aggregate is the unit of hot code loading**
— consistency unit and deployment unit coincide, so `relup` is per aggregate and torn upgrades are
impossible by construction rather than by discipline.

One inherited nuance worth keeping: the sub-module a programmer wrote **is still named in crash
reports**, because repeated `{attribute, ANNO, file, …}` forms re-point source attribution within
one module ([`prototypes/13b_aggregate_attribution.erl`](../prototypes/13b_aggregate_attribution.erl)).
Supervisor and crash-report legibility therefore does not pay for source-only sub-modules.

## Answer — resolved 2026-08-12

> Decision brief: [`../beam-sharp-eng-180.html`](../beam-sharp-eng-180.html)

**The concurrency vocabulary is OTP's, and nothing about it is parameterised by a message
type.** Six decisions. The load-bearing one is that ticket 03's `Pid[τ]` recommendation is
declined — the type belongs on the client API function's signature, where it was going to be
written anyway, and process identity stays a bare `pid`.

The ticket's known evidence gap is also closed: Gleam's actor and message typing was **measured,
not characterised** — see §7 and prototypes [`14a`](../prototypes/14a_gleam_actor.gleam),
[`14b`](../prototypes/14b_gleam_mailbox_probe.erl),
[`14c`](../prototypes/14c_gleam_named_forgery.erl),
[`14f`](../prototypes/14f_gleam_selective_receive.md).

### 1. Process identity is untyped — `pid` is `pid`

Ticket 03 recommended `Pid[τ]`, a process identifier parameterised by the message type it
accepts. **Declined**, for three reasons that compound.

**It is not expressible.** Ticket 09 settled that types are sets of values, a name never enters
the algebra, and two names over the same set are the same type. A pid is one runtime value class
with the payload erased, so `pid<Order.Msg>` and `pid<Payment.Msg>` denote the identical set and
are therefore the same type. Gleam gets a phantom parameter because its type system is nominal
(`subject(τ)` lowers to `{subject, Pid, Ref}` with τ erased — `src`). beam-sharp has no
nominality to spend.

**It is not needed.** Nobody writes `Pid ! {apply, Id, E}` in OTP; they call
`orders:apply(Server, Id, E)`. Prototype 01e already has that shape, so the message
`(:apply, string, Event)` is constructed inside a client function whose own signature is checked,
and the `Request` union `HandleCall` proves exhaustive over is the same union the client API
constructs. Both ends typed, at the two places a type was going to be written, with the pid left
alone.

**And it would not buy soundness.** Ticket 21 established no foreign caller can be ruled out, so
`pid<Msg>` constrains only this language's senders while raw `!` from Erlang goes through
regardless. It is a lint on code the client API already covers, paid for with a projection at
every OTP call, every monitor and every interop point — Gleam's `{subject, Pid, Ref}` tax.

**The worry it was meant to address is mostly not a worry**, measured on OTP 28
([`14d`](../prototypes/14d_wrong_pid_outcomes.erl)). Five ways a client function can be handed a
pid that is not the server it expects:

```
1 right server                  {ok,<<"an order">>}
2 dead pid                      {'EXIT',noproc}
3 wrong server, no such clause  {'EXIT',unhandled}    (the SERVER died too)
4 not a gen_server at all       {'EXIT',timeout}
5 shape collision               {ok,4200}   <-- an integer where a binary was declared
```

Four of the five are exits, which ticket 12's signature-directed stance already accepts and which
no type could have prevented. Only case 5 returns a wrong value, and it needs two servers to
accept the **same request shape** and reply with **different types** — ticket 06's third outcome
(silent unsoundness) reappearing in the reply channel, already owned by ticket 18.

**A tier-3 alternative was considered and is recorded rather than taken**: a tagged handle
`(:order_msg, pid)`, distinguishable as a *set* because ticket 10 makes `:order_msg` a singleton
type. It works within tickets 09/10 with no new machinery and is O(1) guard-decidable, so it stays
available if a later ticket finds the client-API answer insufficient.

### 2. There is no `async`/`await`, and no `Task`

Dropped, and the spec must **say so explicitly** — a C# reader will go looking, and silence
reads as an oversight.

The models are not variations on a theme. A `Task` is a future over a thread pool with implicit
continuation capture; it exists because blocking a pooled thread is expensive. A BEAM process is
a supervised, addressable entity with a mailbox, and blocking one is free and idiomatic —
`gen_server:call` blocks, and that is how OTP is written. Mapping `await` onto a process wrapper
would make the most important thing about the platform look like the least important thing about
C#, and it would teach the await-everything reflex where the BEAM reflex is to decide
deliberately whether a thing is a process at all.

There is also a mechanical objection: C#'s `async` colours functions and the colour propagates up
the call graph, which is a second effect system beside a checker ticket 04 found has no complexity
bound — the same ground on which ticket 12 rejected PureScript's `Partial`.

### 3. Callbacks are per-module functions with multi-clause heads

**purerl/Pinto's closures-as-messages is inadmissible**, and not only because ticket 00 makes
`handle_call/3` the showcase. Ticket 11 settled that arrow types are unvalidatable at a boundary —
`erlang:fun_info` yields identity, never types — so foreign funs are holdable and returnable but
never callable, and the boundary is MFA. A message carrying a closure through the mailbox is
exactly that rejected case: you could guard-match `is_function(F)` and its arity, then call it,
and at that point the headline guarantee is void, because unknown code with unknown types has run
inside a construct that claims exhaustiveness.

Note this is *not* a rejection of MFA-carrying messages. `{M, F, A}` is guard-decidable data and
ticket 11 already blessed it; OTP's own child specs are built from it (§6).

### 4. The behaviour contract is a type, and the user narrows it

`[module: GenServer]` — C#'s own module-targeted attribute syntax, from prototype 01e — names a
contract **the compiler knows as a type**. The user writes a narrower callback signature and the
compiler checks **containment**. This is ticket 21's finding cashed in: Roc's `requires` clause,
recorded there as "directly stealable as a typed, compiler-checked OTP behaviour contract,
strictly better than Erlang's `-callback`".

It is not an invention. **Dialyzer already performs this check**, measured on OTP 28.5
([`14e`](../prototypes/14e_callback_contract_containment.md)):

| variant | `-spec` written | Dialyzer |
|---|---|---|
| narrowed **return** — ticket 12's exact signature | `{reply, integer(), state()}` | **passed** |
| narrowed **argument** | `request()` instead of `term()` | **passed** — silently |
| return outside the contract | `{bogus, integer()}` | **warned**, naming the gen_server callback |

So beam-sharp's version is the same containment, run by the compiler that already builds the code
(ticket 21's discriminator), as an error rather than an opt-in analysis someone may decline to run.

**And it fixes the direction Dialyzer misses.** Narrowing the *argument* is the unsound move — OTP
calls the callback with whatever a sender chose — and Dialyzer says nothing; at runtime you get
`function_clause` with the message in the report. beam-sharp catches it for free, because
containment here **is** function subtyping, contravariant in arguments — the relation ticket 11
already relies on when rejecting arrows in `ValidateAs<T>`. One relation, both directions, no
special case.

**This corrects prototype 01e.** It wrote `(Reply<Outcome>, State) HandleCall(Request, From,
State);`. The argument position must be `term`, exactly as ticket 12's example already has it:

```csharp
(:reply, int, Account) HandleCall(term, From, Account);
```

**Why narrowing is the whole point.** OTP's real contract is six alternatives wide, with `Action`
a further seven-way union (`src`, `stdlib-7.3/src/gen_server.erl`). If a callback carried that
union, `(:noreply, s)` would always be available and always type-correct on an unrecognised
request — and always a lie, since nobody will call `reply/2`. The caller then sits until its
timeout and exits with `{timeout, ...}`: the failure reported in the wrong process, at the wrong
time, with the wrong reason. That is ticket 06's "silence is the enemy" in pure form, and it is
why the wide contract was rejected. Ticket 12's worked example is unwritable without narrowing, so
the alternatives were reversals of ticket 12 rather than repairs to it.

**Reversibility, and it is why this is safe.** Option 1 strictly contains the alternatives: a user
who writes OTP's full union as their signature gets the wide behaviour exactly, and a project
wanting a fixed narrow subset sets its scaffolding generator (ticket 23) to emit it. Neither needs
a language change. The reverse is a language change — under a fixed contract nobody ever wrote a
narrowed signature, so adding narrowing later means adding the check *and* rewriting every
callback.

**`-behaviour` is emitted.** Ticket 06 verified it has no runtime effect, but it is free on the
abstract-format target (ticket 13), it documents intent to an Erlang reader, and it is what turns
Dialyzer's own callback check on for downstream consumers. Neither Gleam nor purerl emits one;
this language has no reason to copy that.

**The obligation this creates**: a typed model of OTP's behaviour contracts, tracking the release
range ticket 13 pinned (current plus previous two majors), proven by that ticket's CI corpus. Only
OTP 28.5 was installed here, so **whether the contracts differ across that range is unmeasured**.
User-defined and library behaviours (gen_statem aside, Ecto-style contracts in Elixir libraries)
are not covered until `requires` generalises to a user-declarable contract — purely additive.

### 5. `receive` exists, and it is a filter rather than dispatch

`receive` is a clause-headed expression, and it is **exempt from exhaustiveness**. No catch-all is
forced.

The reason is semantic, not an escape hatch. A callback is **dispatch**: the message was delivered
to you and not handling it is a defect. `receive` is **selective** — it scans the mailbox, takes
the first message matching any clause, and leaves everything else in place — so an unmatched
message is not unhandled, it is *not yet*. Forcing a catch-all would delete selective receive, and
with it the correlate-a-reply idiom that `gen_server:call` itself runs on (OTP 28 uses alias-based
correlation, visible as `{<0.10.0>, [alias|#Ref<...>]}` in [`14d`](../prototypes/14d_wrong_pid_outcomes.erl)).

**The spec must state the distinction**, because Gleam demonstrates the cost of leaving it
implicit: it ships *both* behaviours at two layers and names neither (§7).

Removing `receive` was the live alternative and was rejected on consequences: without it `spawn`
can only produce processes that never read their mailbox, so the language would have exactly one
way to make a concurrent thing, and it would be OTP or nothing.

`receive` is **syntax**, not a library function. Gleam can make it a library because its selector
is a runtime map from `{tag, arity}` to closures; ticket 11 closed that route here, and ticket 00
makes clause heads the dispatch mechanism.

### 6. The prelude is stratified, and OTP's message shapes are compiler-known

The prelude has **two strata**, and it already did without saying so. Ordinary aliases —
`type bool = true | false;`, `type option<T> = T | :nothing;` — are definitions a user could have
written. `ParseAtom<T>`, `ToExistingAtom` (ticket 10) and `ValidateAs<T>` (ticket 11) are
type-directed **codegen**, which a user could not. The model for the second stratum is Elixir's
`Kernel.SpecialForms` (David, 2026-08-12): forms the compiler implements directly, which win
resolution — verified locally on Elixir 1.19.5, where a module defining its own `receive/1` macro
still gets the special form at the call site.

**OTP's system-message shapes join the second stratum**: `Down`, `Exit`, `Timeout` and friends are
compiler-known types, not aliases that ship.

This exists to close a hole this ticket found, which nothing else in the design catches
([`14g`](../prototypes/14g_handle_info_blind_spot.erl)):

```
a real DOWN message arrived:  true
the DOWN clause fired:        false      <-- swallowed by the catch-all
the catch-all ran:            1 time(s)
```

That server's `:DOWN` clause has **four** elements; the real message has five. The clause can never
fire, the mandatory catch-all absorbs the notification, and the process carries on believing the
worker is alive. **Neither check saves you**: exhaustiveness cannot, because ticket 11 makes the
argument `term` and ticket 12 makes that residual open, so nothing is missing; redundancy cannot,
because against `term` every clause is reachable, so ticket 04's warning has nothing to say. The
headline guarantee has a blind spot exactly at the showcase, and the failure mode is silence.

Naming the type instead of spelling the tuple turns a mis-shape into a compile error. And because
the compiler *knows* what produces a `Down`, **calling `Monitor` in an aggregate with no `Down`
clause is an error** — the blind spot closed rather than mitigated.

**This is not a second effect system.** Nothing propagates through signatures and no constraint
travels up a call graph; it is a local query over one compilation unit, which ticket 13 made the
aggregate. It is ticket 04's residual pattern applied to a call rather than a type: the compiler
already has both facts and merely has to report the pair.

**Supervisors and applications need no separate answer.** They are behaviours, so §4 covers them:
`[module: Supervisor]` names a contract, the child spec is data — a map carrying `{M, F, A}`,
guard-decidable and already blessed by ticket 11 — and ticket 13's aggregate-as-BEAM-module puts
the callbacks where OTP looks with no generated delegation.

### 7. What Gleam actually does — the evidence gap, closed

Ticket 03 deferred this rather than fill it from memory. Measured on Gleam 1.18.1 / gleam_otp
1.3.0 / gleam_erlang 1.3.0 / OTP 28.

- **`Subject(msg)` is a send-side handle only.** It lowers to `{subject, Pid, Ref}`; `send` wraps
  as `{Ref, Message}`; the type parameter is erased (`src`).
- **The receive side is a runtime map lookup** keyed on `{element(1, Msg), tuple_size(Msg)}`
  (`src`, `gleam_erlang_ffi:select/2`) — a dispatch *table*, doing at runtime what a beam-sharp
  clause head does at compile time, and keyed on precisely ticket 09's discriminability
  vocabulary.
- **There is no exhaustiveness over the mailbox.** The actor installs `select_other(Unexpected)`;
  unmatched messages are `logger:warning`-ed and discarded, process survives (`local`, `14b`).
- **Ticket 06's silent unsoundness reaches the mailbox.** With the right ref and a wrong payload,
  `12345` entered a `List(String)` and came back out of a function spec'd `-> binary()` (`local`,
  `14b`).
- **The ref is a real capability — and Gleam's own remedy removes it.** `sys:get_state` returns
  user state only, so an anonymous subject's ref could not be recovered. But `process.new_name/1`
  + `actor.named` replaces it with a registered atom that `registered()/0` enumerates; discovering
  it by registry diff and forging a well-typed message took four lines (`local`, `14c`).
- **Gleam ships both mailbox behaviours and names neither** (`local`, `14f`). Low level:
  `process.receive` is a filter — three messages queued, one plucked from the middle, queue length
  3 → 2. Actor level: dispatch, via the opt-in catch-all. A Gleam user's answer to "does my
  mailbox keep this message?" depends on which layer they called.
- **Ownership is a runtime panic, not a type** — receiving with a subject you do not own raises,
  consistent with the erased parameter.

**Why none of it transplants**: beam-sharp cannot use the ref trick even in principle, because
ticket 00 makes `handle_call/3` the showcase and `{'$gen_call', From, Request}` is a public shape
by construction. The mailbox is open, so the declared union plus a mandatory catch-all is the only
available shape — which tickets 11 and 12 had already forced. **Alpaca's whole-call-graph inference
is excluded by a decision already made**: ticket 04 requires a *declared* input type, because a
type built from the program makes the check vacuous — and inference over send sites cannot see the
foreign sender ticket 21 says cannot be ruled out.

## Consequences for other tickets

- **[15 — Error model](15-error-model.md)** (unblocked by this): §4's narrowing *is* the crash
  policy at the OTP boundary; §1 means a failed call surfaces as an exit from `gen_server:call`,
  not as a typed value, in four of the five wrong-pid cases.
- **[18 — Boundary defence](18-boundary-defence.md)**: §1 case 5 (shape collision) is 18's, not
  14's — a reply-channel instance of ticket 06's silent unsoundness. §4 adds that the
  argument-contravariance check is a *compile-time* answer to part of what 18 was considering
  runtime guards for.
- **[23 — What the language owes an agent](23-what-the-language-owes-an-agent.md)**: §4 makes the
  scaffolding generator the knob controlling default callback signatures — a project's narrow-vs-
  wide policy is generator configuration, not language semantics. §6 asks it to generate system
  message clause heads.
- **[24 — Testing story](24-testing-story.md)**: §5's filter semantics mean a test that drains a
  mailbox and one that selectively receives are different operations; §1 means test doubles are
  bare pids.
- **[25 — Exemplar programs](25-exemplar-programs.md)**: the `handle_call`/`handle_info` showcase
  is now specified enough to write, with the 01e correction from §4 applied.
- **[27 — Parametric polymorphism](27-parametric-polymorphism.md)**: §1 **removes** a motivating
  case. `Pid[τ]` was one of the clearest demands for a type parameter and it is declined, so 27
  decides generics on the remaining evidence — `option<T>`, `ParseAtom<T>`, `ValidateAs<T>` —
  which ticket 11 already flagged as codegen rather than generics.
- **[26 — Data modelling](26-data-modelling.md)**: §6's compiler-known stratum is a second
  category of prelude entry that 26's records-and-aliases story must accommodate.
- **[13 — Compilation target](13-compilation-target-decision.md)**: §4 and §6 both add obligations
  to 13's CI corpus — behaviour contracts and system-message shapes must be proven across the
  pinned release range.

## Costs, stated honestly

- **The language ships a model of OTP.** Behaviour contracts (§4) and system-message shapes (§6)
  both track releases. Their failure mode is being *out of date*, not being wrong, and they live
  in a data file rather than in language semantics — but the pinned range is **unmeasured**, since
  only OTP 28.5 was installed here.
- **Honesty is still not a compiler check.** Ticket 12 said so and nothing here changes it. Its
  sharpest instance is deferred replies: a user who honestly writes
  `(:reply, R, S) | (:noreply, S)` can then type-check a catch-all as `(:noreply, s)` while lying
  in fact. What the language guarantees is that the shrug was deliberate.
- **`receive` is a second clause-headed construct with different rules.** Two constructs that look
  alike and differ in whether the mailbox keeps the message is a thing to be taught, which the
  borrow heuristic exists to avoid. Accepted because deleting it costs `spawn` and reply
  correlation.
- **A tagged process handle stays available** (§1) if the client-API answer proves insufficient.
