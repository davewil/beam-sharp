# 62 — the outbound ABI: probes

## 2026-11-10

**Toolchain: Erlang/OTP 28.5 built from `otp_src_28.5.tar.gz` (the pin in `.tool-versions` is 28.5),
rebar3 3.27.0 from its GitHub release, Elixir 1.19.5 (the `elixir-otp-28.zip` release build), gleam
1.18.1.** None of the four came from mise, so `bin/check-toolchain.sh --env` would not accept this
sandbox; the versions match the pin. `compiler/` at `68a4f3f`, built with `rebar3 escriptize`; the
repo's test suite and gates other than `check-links.sh` were not run.

Every number below is printed by
[`62b_the_quoted_call.sh`](../prototypes/62b_the_quoted_call.sh), run from the repo root against
`compiler/examples/Shop`.

### 1. `62a` still reproduces

[`62a_from_the_outside.sh`](../prototypes/62a_from_the_outside.sh) was rerun unchanged. Its Erlang
and Elixir sections print what the ticket records: `:Shop.New(1)` is a syntax error under every
module prefix, a record arrives as `%{Kind: :"Shop.Order", Id: 7, Total: 0}`, and a wrong tag is
`FunctionClauseError`. The export list has gained one entry since the ticket was written,
`bs@type_atoms: 0` (ticket 87). Its Gleam section fails here for a reason that is the sandbox's:
`gleam new` declares `gleam_stdlib` and hex is unreachable. `62b` builds a Gleam caller with no
dependencies instead.

### 2. Elixir has a second way in that `62a` did not try

```
:Shop.New(1)                              {:raised, SyntaxError}
apply(:Shop, :New, [1])                   %{Kind: :"Shop.Order", Total: 0, Id: 1}
:Shop."New"(1)                            %{Kind: :"Shop.Order", Total: 0, Id: 1}
1 |> :Shop."New"() |> :Shop."Pay"()       %{Kind: :"Shop.Order", Total: 500, Id: 1}
(&:Shop."New"/1).(4)                      %{Kind: :"Shop.Order", Total: 0, Id: 4}
s = :Shop; s."New"(1)                     %{Kind: :"Shop.Order", Total: 0, Id: 1}
:Shop.new(1)                              {:raised, UndefinedFunctionError}
```

The quoted remote call is ordinary Elixir syntax. It pipes and it captures, which `apply/3` does
only by wrapping it in a function. The ticket's sentence *"Callers are pushed to `apply/3`"* and
`LANGUAGE.md` §12's *"`apply(:Shop, :New, [1])  # the way in`"* (line 3325) both name the longer of
two working spellings as the only one.

`Code.format_string!/1` keeps the quotes where the name needs them and removes them where it does
not, so a formatted Elixir file holds this form stably:

```
x = 1 |> :Shop."New"() |> :Shop."Pay"()      (unchanged)
:lists."reverse"([1])   ->   :lists.reverse([1])
```

### 3. The quoted call is checked at compile time; `apply/3` is not

A module compiled with `elixirc -pa <ebin>` against `Shop.beam`:

```elixir
defmodule Caller do
  def ok(id), do: id |> :Shop."New"() |> :Shop."Pay"()
  def typo(id), do: :Shop."Nwe"(id)
  def arity(id), do: :Shop."New"(id, 2)
end
```

```
warning: :Shop."Nwe"/1 is undefined or private
warning: :Shop."New"/2 is undefined or private. Did you mean:
```

Elixir's own diagnostics spell a B# function in the quoted form. So does its stack trace (§6).

### 4. The same cost runs the other way, and Elixir never paid it down

```
'Elixir.String':upcase(<<"a">>) -> <<"A">>
```

An Erlang caller quotes every Elixir module atom. Elixir emits no unquoted second module for
Erlang's benefit; the quoting is where that boundary settled.

### 5. Gleam, run end to end

`62a` compiled `@external(erlang, "Shop", "New")` and did not run it. Run here:

```
-export([shop_new/1, shop_pay/1, paid_order/1]).
-type colour() :: dark_red.
    'Shop':'New'(Id).
caller:paid_order(5) -> #{'Kind' => 'Shop.Order','Total' => 500,'Id' => 5}
```

(`caller.erl` as gleam 1.18.1 emits it, and the call run from `erl`.) Gleam names the foreign
function as a string and emits a quoted Erlang call. Its own functions are lowercase in source and
are exported as written, so it has no second name to emit. What it downcases is a type constructor,
`DarkRed` to the atom `dark_red`: the *"PascalCase becomes snake_case"* this ticket borrows from
ticket 10 is that, and is not a precedent for a second function export.

### 6. A lowercase second export, added by hand

`62b` reads the `Shop.abstr` that `bsc` writes, adds one forwarder per author export
(`new(A1) -> 'New'(A1).`), and compiles both. The lowering is first-letter only, chosen to have
something to measure.

```
8 author exports; beam 1232 -> 1504 bytes (+272, 34 per function)
1 |> :Shop.new() |> :Shop.pay()         %{Kind: :"Shop.Order", Total: 500, Id: 1}
** (FunctionClauseError) no function clause matching in :Shop."Band"/1
    examples/Shop/shop.bs:63: :Shop."Band"(:x)
```

The byte counts are `compile:forms/2` output without debug info, both sides. The forwarder is a
tail call, so it is not on the stack: a caller who wrote `:Shop.band(:x)` is told about
`:Shop."Band"/1`, a name that is not in their source.

### 7. Census

```
117 public declarations, 96 distinct names, 84 of them a single word
```

Over `compiler/examples`. For 84 of 96 names, lowering the first letter and snake-casing give the
same atom; for the other 12 (`HandleCall`, `EncodeAck`, `RunLength` and nine more) they differ, which is where a
derivation rule would have to be chosen.
