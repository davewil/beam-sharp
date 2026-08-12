# PROTOTYPE 14e — is "user narrows, compiler checks containment" an invention?

Evidence for ticket 14. Observed locally on **OTP 28.5 / stdlib-7.3 / Dialyzer** (2026-08-12).

The proposal under test: `[module: GenServer]` names a typed contract, the user writes a
**narrower** callback signature, and the compiler checks containment. The question David asked was
what can go wrong and whether it is reversible. The prior question is whether anyone already does
it — and Dialyzer does, partially, which turns the proposal from an invention into a shipped check
made mandatory and immediate.

## The contract, read from source (`src`)

`stdlib-7.3/src/gen_server.erl`:

```erlang
-callback handle_call(Request :: term(), From :: from(), State :: term()) ->
    {reply, Reply, NewState}        | {reply, Reply, NewState, Action} |
    {noreply, NewState}             | {noreply, NewState, Action} |
    {stop, Reason, Reply, NewState} | {stop, Reason, NewState}.
```

`Action` is a further seven-way union (`timeout()`, `hibernate`, `{continue, _}`, and three
timeout/hibernate shapes carrying options). `handle_info/2`, `handle_continue/2`, `terminate/2`,
`code_change/3` and `format_status/1,2` are `-optional_callbacks`.

## Three variants, one Dialyzer run each (`local`)

| Variant | `-spec` written | Dialyzer |
|---|---|---|
| `narrow_ok` | return narrowed to `{reply, integer(), state()}` — ticket 12's signature | **passed** |
| `widen_arg` | **argument** narrowed to `request()` instead of `term()` | **passed** — silently |
| `bogus_ret` | return `{bogus, integer()}`, outside the contract | **warned**, quoting the full expected return type "for the callback of the gen_server behaviour" |

Two findings.

**1. The return-direction check already ships.** Dialyzer accepts a narrowed return and rejects one
outside the contract, naming the behaviour in the diagnostic. So beam-sharp's version is not a new
kind of check — it is the same containment, run by the compiler that already builds the code
(ticket 21's discriminator), as an error rather than an opt-in analysis.

**2. The argument-direction check does not.** `widen_arg` declares it accepts only `request()`,
which is unsound — OTP calls the callback with whatever a sender chose — and Dialyzer says nothing.
The runtime cost, measured:

```
call with an unlisted request: {exit, {function_clause,
  [{widen_arg,handle_call, [{deposit,5}, {<0.10.0>, [alias|#Ref<...>]},
                            #{balance => 100}], ...
```

beam-sharp gets this direction for free and Dialyzer does not, because containment here *is*
function subtyping, which is contravariant in arguments — the relation ticket 11 already relies on
when it rejects arrow types in `ValidateAs<T>`. One relation, both directions, no special case.

## Consequence for prototype 01e

01e wrote `(Reply<Outcome>, State) HandleCall(Request, From, State);`. The argument position is
**wrong post-ticket-11**: it must be `term`, since narrowing it is exactly the unsound move above.
Ticket 12's worked example already has this right — `HandleCall(term, From, Account)`.

## Reproduce

```
erlc +debug_info -o . narrow_ok.erl widen_arg.erl bogus_ret.erl
dialyzer --build_plt --apps erts kernel stdlib --output_plt ./b.plt
dialyzer --plt ./b.plt narrow_ok.beam    # passed
dialyzer --plt ./b.plt widen_arg.beam    # passed  <-- the gap
dialyzer --plt ./b.plt bogus_ret.beam    # warned
```

Note `+debug_info` is required: without it Dialyzer cannot get Core Erlang from the `.beam` and
refuses to analyse — the same abstract-chunk dependency ticket 02 found and ticket 13 decided on.
