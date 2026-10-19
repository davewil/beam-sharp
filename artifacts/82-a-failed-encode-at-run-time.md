# Brief — ticket 82 (ENG-382): what is a failed encode at run time?

Status of the ticket: **open, left open.** F50 ships a provisional shape; `compiler/features/F50-to-json.md` says so.

## Sub-decisions
1. **Q1 (gating):** what does a failed guard at `ToJson<T>`'s obligation site become: a crash carrying the `ValidationError`,
   a bare `function_clause`, or a value (`result<string, ValidationError>`, which reopens ticket 77)?
2. **Q2:** how deep is the guard: one `map_size` test (ticket 26's measured +29 B, `wayfinder/issues/26-data-modelling.md:300`; the ticket and F50 cite it as §4, the verifier found it elsewhere in 26) or the full validator?

Q2 can be answered first: if the shallow test is unsound, the depth is forced and Q1 is only about the shape.

## The program

```csharp
module Orders
record Order { Id: int, Total: int }

public string OrderBody(Order o)
OrderBody(o) -> ToJson<Order>(o)
```
Re-run at `019533d` on OTP 28 (`probes/82/probe.sh`):
```
{ Id = 1, Total = 5 }                    -> "{"Kind":"Orders.Order","Id":1,"Total":5}"
{ Id = 1, Total = 5, Secret = 7 }        -> crashed: to_json {Kind = :'ValidationError', Expected = "Id | Total", Path = [".Secret"], Reason = :unknown_key}
{ Id = "x", Total = 5 }                  -> crashed: to_json {Kind = :'ValidationError', Expected = "int", Path = [".Id"], Reason = :mismatch}
```
The crash text in the ticket predates ENG-615 (the `Reason` field); the shape is otherwise unchanged. The emitted function is
`case bs@validate@1(X, []) of {ok,_} -> iolist_to_binary(json:encode(X)); {error,E} -> erlang:error({to_json, E}) end`.

## Measurements

**Q2: the shallow test is unsound at depth** (`probes/82/shallow_leak.escript`). With `Order { Id, Line: Line { Sku, Qty } }` and
an undeclared `Secret` inside `Line`, a top-level `map_size(V) =:= 3` test **passes** and `json:encode` **publishes**
`"Line":{"Kind":"Nested.Line","Sku":2,"Qty":3,"Secret":9}`. The emitted deep validator refuses it at path `[".Line", ".Secret"]`.
So 26's +29 B test keeps its promise only at the top level, as the ticket says; this confirms it on a concrete value.

**Q2: what the depth costs** (`probes/82/guard_cost.escript`, two runs, `ToJson<list<Order>>`; `Body(Os)` is a direct call
into the validator, no extra entry guard, read from the emitted code):
| orders | deep vs bare `json:encode` | shallow (`is_map` + `map_size` per element) vs bare |
|---|---|---|
| 1 | 1.50x and 1.60x | 1.18x and 1.05x |
| 100 | 1.33x and 1.39x | 1.02x and 1.35x |
| 10 000 | 1.47x and 1.20x | 1.03x and 0.92x |
Run-to-run spread is as large as the differences between rows, so read this as **deep costs roughly 1.1-1.9x of the encode (verifier, six more runs: 1.38-1.86x at N=1, 1.11-1.47x at N=100, 1.08-1.33x at N=10000),
O(size), same order as the encode itself**, not as a precise figure. Size on disk: the `Orders` module is 4568 B with the guard.

**Q1: the crash shapes** (`probes/82/crash_shapes.escript`, `term_to_binary` size of the exit reason):
| shape | reason | size |
|---|---|---|
| shipped | `{to_json, #{Kind=>'ValidationError', Path=>[<<".Secret">>], Expected=>..., Reason=>unknown_key}}` | **110 B** |
| bare `function_clause` | `function_clause`; the offending argument rides in the stacktrace (verifier: 433 B for a 4-key map, unbounded for a list, vs 362 B for the shipped stacktrace) | **18 B** reason only |
| OTP's own `json:encode(#{a => self()})` | `{unsupported_type, <0.10.0>}` | 49 B |

**Neighbour and platform precedent**
- **OTP 28's `json` crashes with a reason, not a bare atom**: `error({unsupported_type, Other})` at
  `/tmp/dl/otp-src/lib/stdlib/src/json.erl:203` (the encoder; `:658` is the same error in `json:format`, not the encoder); decode raises `error({invalid_byte, Byte}, none, error_info(Skip))`
  at `:543`. The `error/3` form with `error_info` is a way to make the same crash print readably; B# does not use it.
- **Elixir 1.14.0** ships no JSON encoder. **Jason and `gleam_json` were not measurable**: `repo.hex.pm` is unreachable here.
  Their failure shapes (`Jason.encode` returns `{:error, _}`, `Jason.encode!` raises) are **recollection, not evidence**.
- **Elm** `Json.Encode`: not measured (package host unreachable).

## Options

**A. Keep the shipped shape: deep guard, crash with the `ValidationError`** (`error({to_json, E})`).
- Evidence: shallow is unsound on a concrete nested value; the reason (path + `Reason` atom) is what tells the author which
  field leaked; OTP's own encoder crashes with a reason too; costs ~1.1-1.9x of the encode and 110 B per crash.
- Strongest counterargument: the author cannot recover, because B# has no `try`; a crash that carries a rich reason is
  still a crash, and ~1.1-1.9x on a hot encode path is a cost the shallow test does not pay (it is measurably ~1.0-1.2x, but
  unsound at depth).

**B. Bare `function_clause`, deep guard.** One failure vocabulary for every guard the compiler emits (F42, ticket 18 §1).
- Evidence: 18 B reason against 110 B; one vocabulary. The size gap is not the whole crash: the bare form's stacktrace carries the whole argument (433 B for a 4-key map, more for a list), so the *total* crash can be larger than the shipped one.
- Strongest counterargument: it keeps the full deep walk (the cost) and throws away the only output the walk produces. The
  ticket's own argument stands: dropping the reason makes the deep walk harder to justify. The path is the diagnostic.

**C. Return `result<string, ValidationError>`.** The failure becomes a value the author can take apart.
- Evidence: the validator already computes `{error, E}` internally (`bs@validate@N` returns `{ok,_} | {error,E}`), so there is
  no second walk. The delta is not only "return instead of raise": `result<T,E>` is `T | (:error,E)` with no `:ok` wrapper (verifier), so the internal `{ok,_}` must be stripped.
- Strongest counterargument: it **reopens ticket 77's decision** (*"Returns `string`"*), changes the signature of the
  feature that shipped, and makes every `ToJson` call site handle a failure that, for a value the program itself built,
  can only be a bug in the program. Ticket 78 already gave the decode direction (`FromJson`) the result type; an asymmetry
  that is deliberate should be said so in the spec.

## Recommendation
**A, recorded as decided and the F50 "provisional" note removed.** Q2 is settled by evidence (shallow leaks at depth); Q1
then has one live alternative, C, which belongs in a reopened 77 and not here. Ask David the single question this brief
cannot answer by measurement: is a failed encode ever something an author should *handle* (C) or only *see* (A)?

## Not measured
Jason, `gleam_json`, Elm. The cost on payloads of mixed shape; the spread above is too wide to rank shallow against none.
`erlang:error/3` with `error_info` as an improvement to A. Behaviour under a `gen_server` crash report (size/readability).

## Verifier findings that qualify this brief
- **`shallow_leak.escript` is partly circular.** The nested value is built with three top-level keys, so the `map_size =:= 3` pass is
  true by construction, and the shallow guard never runs inside B#. What the probe shows is only that `json:encode` publishes
  a nested undeclared field and the real validator refuses it. Ticket 26 describes the exact-set check as `has_map_fields`
  plus `map_size`, which the probe does not model. The conclusion (a top-level-only test cannot see a nested field) is true
  by inspection of what such a test examines, not by this probe.
- Part of the deep cost is implementation, not necessity: the happy path allocates a path binary per list element.
- Module size read 4568 B on the original build and 4576 B on the verifier's; cause unexplained.
- Shallow vs none is noise at N >= 100; at N=1 shallow read 1.05-1.28x above none in every verifier run.
