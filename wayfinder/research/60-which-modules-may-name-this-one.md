# 60 — Which modules may name this one, measured

## 2026-11-15

**Toolchain: Erlang/OTP 28.5 (erts 16.4, JIT), built from `otp_src_28.5.tar.gz` (the pin in
`.tool-versions`), and rebar3 3.27.0 from its GitHub release, on x86_64 Linux.** Neither came
from mise, so `bin/check-toolchain.sh --env` would not accept this sandbox, but the versions
match the pin. `compiler/` at `258368a`, unmodified, built with `rebar3 escriptize`. Elixir and
Gleam are not installed, and this session could not fetch their sources: the proxy refused
`repo.hex.pm`, and GitHub archives outside this repository's scope. No claim below rests on
either language.

`LANG` is unset in this sandbox, so the escript prints `—` as `\x{2014}`. That comes from the
locale, not the compiler.

### 60a — who may name `Shop.Orders`, at `258368a`

[`60a_who_may_name.sh`](../prototypes/60a_who_may_name.sh) writes one source tree,
`Shop/shop.bs`, `Shop/Orders/Orders.bs` and `Warehouse/Warehouse.bs`, and compiles each caller
with `bsc --src-root src`.

| case | what | rc | result |
|---|---|---|---|
| 1 | `RecomputeTotal` public; `Shop.Settle [3, 4]` | 0 | `7` |
| 1 | same; `Warehouse.Reprice [3, 4]`, outside the subtree | 0 | `7` |
| 2 | `Warehouse` calls `Shop.Orders.RecomputeTotal` qualified, with no `using` | 1 | `Shop.Orders is called but never imported` |
| 3 | `RecomputeTotal` private; `Shop.Settle` | 1 | `Settle calls RecomputeTotal/1, which Shop.Orders declares `private`` |
| 3 | same; `Warehouse.Reprice` | 1 | the same refusal |
| 4 | export chunk of `'Shop.Orders'.beam` | — | `[{'RecomputeTotal',1}, {bs@type_atoms,0}, {module_info,0}, {module_info,1}]`; an `erl -eval` caller gets `7` |
| 5 | `Warehouse.Reprice/1` from the `.beam`'s abstract code | — | `'Reprice'(Lines) -> 'Shop.Orders':'RecomputeTotal'(Lines).` |

Case 2 is the finding that places the check. A cross-module reference needs a `using` line even
when it is fully qualified, so `add_import/7` (`bs_check.erl:495`) sees every module a file
names. Any refusal goes there, at one site. Case 3 shows that `private` is the only lever today,
and it reaches every other module, the parent aggregate included.

### The corpus

Of the 120 `.bs` files under `compiler/examples` and `wayfinder/prototypes`, 34 lines start with
`using`. 8 of them name a native module; the rest are foreign `using :mod { … }` blocks. 5 of the
8 cross a top-level subtree:

| file | module | names |
|---|---|---|
| `compiler/examples/Pipeline/pipeline.bs:16` | `Pipeline` | `Shop.Collections` |
| `compiler/examples/exemplars/25a-http-api-server/index.bs:10` | (25a router) | `Shop.Orders` |
| `compiler/examples/exemplars/25g-jev-server/jev_index.bs:15` | `Jev` | `Support.Triage` |
| `compiler/examples/exemplars/25g-jev-server/triage_index.bs:14` | `Triage` | `Jev` |
| `compiler/examples/exemplars/25g-jev-server/triage_index.bs:15` | `Triage` | `Support.Triage` |

Each one names a module whose purpose is to be called from outside its subtree. None is a call
an author would want refused. The 25a row also rules out a default-on answer: a rule such as
"only your own subtree may name you" would refuse the router's legitimate `using Shop.Orders`.

### Erlang's own answer

OTP has no caller restriction. Visibility is the export list, which every module may call,
and case 4 calls it from `erl`. What OTP has instead is documentation-only hiding, in
`system/doc/reference_manual/documentation.md:374-380` of `otp_src_28.5`:

> An Erlang `m:application` normally consists of various public and private modules. That is,
> modules that should be used by other applications and modules that should not. By default all
> modules in an application are visible, but by setting `-moduledoc false.` specific modules can
> be hidden from being listed as part of the available API.

773 modules under `lib/*/src` in the same tree carry `-moduledoc false` (counted with
`grep -rln '^-moduledoc false' lib/*/src | wc -l`). That is the BEAM's settled practice: the
restriction is a convention the docs tooling honours, and the runtime does not enforce it.
