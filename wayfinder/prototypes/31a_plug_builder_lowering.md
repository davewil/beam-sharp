# 31a — What `Plug.Builder` actually lowers to

`local` — Elixir 1.19.5, OTP 28.5, **Plug 1.20.3** (fetched from hex), read out of the
`abstract_code` chunk of the compiled module. Source:
[`31a_plug_builder_lowering.ex`](31a_plug_builder_lowering.ex).

Ticket 31 asks whether `|?>` already expresses composable middleware. The reference implementation
is Plug, and every previous statement about it in this map is `doc`. This reads the emitted code.

## The pipeline

```elixir
use Plug.Builder

plug(:trace)
plug(:auth)                     # halts with a 401 when there is no authorization header
plug(:quota)
plug(Probe.Quota, limit: 13)    # a module plug, so init/1 is observable
```

## 1. It runs, and halt stops it

```
authed=true  -> status=nil halted=false ran=[:trace, :auth, :quota]
authed=false -> status=401 halted=true  ran=[:trace, :auth]
```

`quota` never ran on the halted path. Nothing surprising; it establishes the baseline.

## 2. The stage set is baked at compile time, as a nested `case` per stage

`call/2` delegates to a generated `plug_builder_call/2`. Reformatted from `:erl_pp` output, with
the error clause elided until §3:

```erlang
plug_builder_call(_@1, _@2) ->
    case trace(_@1, []) of
        #{'__struct__' := 'Elixir.Plug.Conn', halted := true} = _@3 -> nil, _@3;
        #{'__struct__' := 'Elixir.Plug.Conn'} = _@4 ->
            case auth(_@4, []) of
                #{'__struct__' := 'Elixir.Plug.Conn', halted := true} = _@5 -> nil, _@5;
                #{'__struct__' := 'Elixir.Plug.Conn'} = _@6 ->
                    case quota(_@6, []) of
                        #{'__struct__' := 'Elixir.Plug.Conn', halted := true} = _@7 -> nil, _@7;
                        #{'__struct__' := 'Elixir.Plug.Conn'} = _@8 ->
                            case 'Elixir.Probe.Quota':call(_@8, {limit, 91}) of
                                ...
```

**Three findings, and the first is the ticket's answer.**

**There is no list, no traversal and no function value.** The stages are *literal calls*, nested
one inside the next. `Plug.Builder`'s macro exists to write out, at compile time, a chain the
author could have written by hand — and the chain it writes is **a `case` per stage that
short-circuits on one member of the returned value**.

Ticket 18 §3 says beam-sharp's valve "emits a `case` per stage matching `(:error, _)`". That is the
same sentence. **The macro and the operator produce the same lowering**; Plug pays a macro for it
and beam-sharp pays one operator token.

**Halting is a field on a struct, not a distinct type.** The discriminator is `halted := true` on a
`Plug.Conn`. A halted conn and a live conn are the *same type*, so nothing in Elixir can state that
a stage always halts, or that a pipeline always produces a response. Ticket 09's structural union
puts that distinction in the type, which is a capability Plug does not have rather than one it has
and beam-sharp lacks.

**`init/1` is hoisted, and the hoisting is visible.** `Probe.Quota.init/1` computes `13 * 7`; the
emitted call is `'Elixir.Probe.Quota':call(_@8, {limit, 91})`. **91 is a literal in the BEAM
module** — the arithmetic ran at compile time and never runs again. This is the one thing in the
lowering that beam-sharp's `x |> F(a)` → `F(x, a)` rewrite does not reproduce: it passes `a` at
every call, so per-request work Plug pays once is work beam-sharp pays per request.

## 3. The third clause is a hand-generated runtime type check

The clause elided above:

```erlang
_@11 -> error('Elixir.RuntimeError':exception(
          <<"expected quota/2 to return a Plug.Conn, all plugs must receive a "
            "connection (conn) and return a connection, got: ", ...>>),
          none, [{error_info, #{module => 'Elixir.Exception'}}])
```

**Plug generates, per stage, a runtime check that the stage returned the right type** — and a
bespoke error message explaining the contract in prose, because the language cannot state it.

This is the sharpest thing in the file for the map. The `Plug` behaviour (`init/1`, `call/2`) and
this emitted check are two halves of one mechanism: an *unchecked* contract, asserted by a
behaviour that has no runtime effect (ticket 06), and enforced by a check the macro writes into
every caller. beam-sharp checks the stage's signature at compile time and emits nothing. So the
behaviour half of ticket 31 §2 does not need answering — **it dissolves**, and 31 does not become
ticket 21's `requires` mechanism's first consumer after all.

Note what that costs Plug at the boundary, per ticket 18's frame: this check fires on the *return*
of every stage, on every request, forever — the price of not having the signature.

## What this does not settle

`Plug.Builder`'s stage set is fixed when the module compiles, so this file says nothing about
whether anyone wants a pipeline assembled at run time. That is [`31b`](31b_aspnet_runtime_assembly.md),
and it lands the other way.
