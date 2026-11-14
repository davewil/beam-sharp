# 66 — A union name in pattern position, re-measured

## 2026-11-14

**Toolchain: Erlang/OTP 28.5 (erts 16.4, JIT) built from `otp_src_28.5.tar.gz` (the pin in
`.tool-versions`), rebar3 3.27.0 from its GitHub release, on x86_64 Linux.** Neither came from
mise, so `bin/check-toolchain.sh --env` would not accept this sandbox, but the versions match the
pin. `compiler/` at `f8fa100`, unmodified, built with `rebar3 escriptize`. Elixir and Gleam are
not installed, and nothing below was run on either.

`LANG` is unset in this sandbox, so the escript prints `—` as `\x{2014}`. That comes from the
locale, not the compiler. The ticket quotes the dash.

### 66a — the exemplars, at `f8fa100`

[`66a_union_name_in_pattern.sh`](../prototypes/66a_union_name_in_pattern.sh) writes each case as
its own module directory, because F15 takes a module's name from its directory. The shared
declarations are three records with identical fields, `Payment = CardPaid | BankPaid` and
`Event = CardPaid | BankPaid | Refunded`, plus a fourth record, `Voided`, that neither union
holds.

| case | ticket exemplar | rc | verdict |
|---|---|---|---|
| `union_in_head` — `Delta(Payment p)` under `Event` | 3 | 1 | `Payment is not a record, so it cannot name a pattern` |
| `one_clause_per_member` | 4 | 0 | three clauses, the `Amount` body twice |
| `union_is_the_input` — `Delta(Payment p)`, `Delta(p) -> p.Amount` | 1 | 0 | `'Delta'(P) -> map_get('Amount', P).` |
| `non_member_call` — `Delta(Refunded {…})` into `Payment` | 2 | 1 | `Bad hands Delta an argument it does not accept` |
| `unreachable_clause` — `Delta(Voided v)` under `Payment` | 5 | 0 | `warning: clause 3 of Delta matches no value of its input` |
| `residual_today` — `Refunded` clause dropped | — | 1 | `Delta is not exhaustive` / `Delta(Refunded r) -> ...` |

Exemplar 3's refusal has been reworded since the F53 note in the ticket. Its part line now reads
*"a part is named by the part itself, lowercase — one clause taking `int` beside one taking
`float`"*. Exemplar 5 still prints the declared input in erased notation, as
`({ Kind: :'L….BankPaid' } | { Kind: :'L….CardPaid' })`.

The Erlang emitted for `one_clause_per_member`, from the `.beam`'s abstract code:

```erlang
'Delta'(P = #{'Kind' := 'Loneclausepermember.CardPaid'}) ->
    map_get('Amount', P);
'Delta'(P = #{'Kind' := 'Loneclausepermember.BankPaid'}) ->
    map_get('Amount', P);
'Delta'(R = #{'Kind' := 'Loneclausepermember.Refunded'}) ->
    0 - map_get('Amount', R).
```

### 66b — the target under yes

[`66b_yes_target.erl`](../prototypes/66b_yes_target.erl) is a hand-written module holding what the
emitter would produce for `Delta(Payment p)`: one clause with `#{'Kind' := K}` and the guard
`K =:= 'L.CardPaid'; K =:= 'L.BankPaid'`. It compiles under `erlc +warnings_as_errors`. Run:

```
card 5, bank 7, refunded -4
voided {'EXIT',{function_clause,[{'66b_yes_target','Delta',[#{'Kind' => 'L.Voided',…}],…}
```

Erlang has no or-pattern, so the membership test has to be a guard. The emitter already
produces one beside a pattern: `guard_one/7` (`compiler/src/bs_emit.erl:274`) emits `tag_test`
for a record-typed parameter, and that is the channel the yes delta reuses.

### Where the surface has no or-pattern either

`rel_pattern -> rel_pattern 'or' rel_pattern` (`compiler/src/bs_parser.yrl:460`) is the only
`p_or` the grammar builds. It joins relational tests such as `>= 0`, and `child_type/3`
(`compiler/src/bs_check.erl:5099`) refuses it below the top of an argument. So
`Delta(CardPaid p or BankPaid p)` is not available as a workaround either. The per-member clause
is the only spelling today.
