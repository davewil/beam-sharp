# 82 — a failed encode at run time: probes

## 2026-11-08

**Toolchain: Erlang/OTP 28 built from `otp_src_28.5.tar.gz` (the pin in `.tool-versions` is 28.5),
rebar3 3.27.0 from its GitHub release.** `compiler/` at `8bf1516`, built with `rebar3 escriptize`;
the repo's test suite and gates were not run. The apt rebar3 and OTP 25 cannot build the compiler
(leex there lacks `error_location`), so a from-source OTP was used.

Module `Orders/Orders.bs`:

```csharp
module Orders

record Line  { Sku: string, Qty: int }
record Order { Id: int, Total: int, Lines: list<Line> }

public string OrderBody(Order o)
OrderBody(o) -> ToJson<Order>(o)
```

Run as `bsc Orders OrderBody "<term>"`:

| input | output |
|---|---|
| valid `Order`, `Lines = []` | `"{"Kind":"Orders.Order","Id":1,"Total":5,"Lines":[]}"` |
| extra top-level `Secret = 7` | `crashed: to_json {Kind = :'ValidationError', Expected = "Id \| Lines \| Total", Path = [".Secret"], Reason = :unknown_key}` |
| extra `Cost = 9` inside `Lines[0]` | `crashed: to_json {Kind = :'ValidationError', Expected = "Qty \| Sku", Path = [".Lines", "[0]", ".Cost"], Reason = :unknown_key}` |
| a `Line` tag where `Order` is wanted | `crashed: error:function_clause` |

The ticket's printed output (`Expected = "{ Kind: :'Orders.Order', ... }"`, `Path = []`, no
`Reason`) predates the current shape: the validator now reports the unknown key and its path. The
question is unchanged by this.

Code: the single site is `compiler/src/bs_emit.erl:1889` (`json_form/2`); its comment at 1887 says
invalid values "crash with `ValidationError` before reaching the wire".

Sibling decision: ticket 74's answer (crash, the guard wraps the wrapper) at
`wayfinder/issues/74-a-failed-guard-under-a-declared-channel.md`, section *Answer*.
