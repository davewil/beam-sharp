# PROTOTYPE 14f — what does Gleam do about `receive`?

Evidence for ticket 14. Gleam 1.18.1, gleam_erlang 1.3.0, OTP 28 (2026-08-12).
Source read (`src`) plus one measurement (`local`).

## 1. There is no `receive` in the Gleam language

No keyword, no expression, no syntax. Mailbox reading is entirely library functions in
`gleam/erlang/process`, bottoming out in an FFI `receive` inside `gleam_erlang_ffi.erl`.

## 2. Selective receive is the default, and unmatched messages stay

`process.receive(subject, timeout)` lowers to a receive matching only `{Ref, Msg}` for that
subject's ref. Measured with `14f_gleam_selective_receive.gleam`: three messages queued — two
raw sends the subject knows nothing about, one sent through the subject — then one
`process.receive`.

```
#("the-one-i-want", 3, 2)
```

Queue length 3 before, 2 after, and the wanted message was plucked from the *middle*. Unmatched
messages are left in place. This is a filter, not dispatch.

## 3. The `Selector` is a runtime dispatch table, and the catch-all is opt-in

`gleam_erlang_ffi:select/2` receives on `is_map_key({element(1, Msg), tuple_size(Msg)}, Handlers)`
— a map lookup on tag and arity. With no `anything` handler installed, an unknown message does not
match the receive at all and **stays in the mailbox**. `process.select_other/2` installs the
`anything` handler that consumes it.

## 4. So Gleam ships both behaviours, at two layers, and never names the distinction

- **Low level** (`process.receive`, a bare `Selector`): filter. Unmatched messages remain.
- **Actor loop**: `process.new_selector() |> process.select_other(Unexpected)` — opts into the
  catch-all, then `logger:warning`s and discards (see `14b`).

That is exactly the filter-versus-dispatch split ticket 14 proposes to state explicitly. It is
present in the shipped library as an implementation detail rather than a documented principle, so
a Gleam user's mental model of "does my mailbox keep this message?" depends on which layer they
called.

## 5. Ownership is checked at runtime, not by the type system

`process.receive` panics if a process receives with a subject it does not own — "Cannot receive
with a subject owned by another process". A runtime check for something the type system does not
express, which is consistent with the ticket 14 finding that `Subject`'s type parameter is erased.
