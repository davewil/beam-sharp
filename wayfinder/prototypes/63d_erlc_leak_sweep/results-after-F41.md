# 63d — results

bsc: `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/compiler/_build/default/bin/bsc`, tree `42b59c3`, 2026-09-11T16:04Z

| Probe | Verdict | First line of output |
|---|---|---|
| A01ArmCall | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/A01ArmCall/a01armcall.bs:8:12: error: Check calls IsAdmin in a guard` |
| B01ArmBind | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/B01ArmBind/b01armbind.bs:7:32: error: syntax error before: '='` |
| B02UnusedBind | CLEAN | `<none>` |
| B03UnusedPrivate | WARN-LEAK | `compile: /Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/B03UnusedPrivate/b03unusedprivate.bs:0: Warning: function 'Helper'/1 is unused` |
| B04Rebind | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/B04Rebind/b04rebind.bs:5:9: error: Check binds u twice` |
| G01Call | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/G01Call/g01call.bs:7:15: error: Check calls IsAdmin in a guard` |
| G02Qcall | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/G02Qcall/g02qcall.bs:4:21: error: Check calls Helper.IsAdmin in a guard` |
| G03ForeignBif | CLEAN | `<none>` |
| G04ForeignNonBif | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/G04ForeignNonBif/g04foreignnonbif.bs:7:15: error: Check calls :string.length in a guard` |
| G05Valve | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/G05Valve/g05valve.bs:8:18: error: Check has a switch in a guard` |
| G06Pipe | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/G06Pipe/g06pipe.bs:7:18: error: Check calls IsAdmin in a guard` |
| G07Proj | CLEAN | `<none>` |
| G08With | CLEAN | `<none>` |
| G09Record | CLEAN | `<none>` |
| G10Inst | REFUSED | `/Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/eng-256-guard-call/wayfinder/prototypes/63d_erlc_leak_sweep/G10Inst/g10inst.bs:4:15: error: Check calls ValidateAs in a guard` |
| G11Str | CLEAN | `<none>` |
| G12TupleList | CLEAN | `<none>` |
| G13Arith | CLEAN | `<none>` |
| G14Control | CLEAN | `<none>` |

Control G14Control: ran, returned `:admin`.

## Shipped examples

| Example | Verdict |
|---|---|
| Aliasing | CLEAN |
| Counter | CLEAN |
| Escalate | CLEAN |
| Fib | CLEAN |
| Foreign | CLEAN |
| Frame | CLEAN |
| Intake | CLEAN |
| Interop | CLEAN |
| Label | CLEAN |
| Levels | CLEAN |
| Math | CLEAN |
| Parcel | CLEAN |
| Pipeline | CLEAN |
| Queue | CLEAN |
| Readings | CLEAN |
| Shop | CLEAN |
| Wire | CLEAN |
