# 65 — Reserved names: what the compiler does today

## 2026-11-12

**Toolchain: Erlang/OTP 28.5 built from `otp_src_28.5.tar.gz` (the pin in `.tool-versions` is
28.5), rebar3 3.27.0 from its GitHub release.** Neither came from mise, so
`bin/check-toolchain.sh --env` would not accept this sandbox; the versions match the pin.
`compiler/` at `24e769f`, unmodified, built with `rebar3 escriptize`; the repo's test suite and
gates other than `check-links.sh` were not run. Elixir and Gleam were not installed and nothing
below was executed on either.

Every result below is printed by
[`65a_what_is_reserved_today.sh`](../prototypes/65a_what_is_reserved_today.sh), run on that
toolchain. The numbers in the headings are the script's.

### What the ticket asked, and when

[Ticket 65](../issues/65-reserved-names-policy.md) was written on 2026-08-25, the day ticket 48
made `Map` the first reserved name. It laid three policies side by side: refuse a module of the
reserved name at its declaration, put the standard names where the user's syntax cannot reach, or
let the user's name win. It named the question to put first: is the standard environment closed.

Three later answers bear on it. Each is quoted from the ticket's own `## Decisions entry` or dated
answer.

| When | Where | What it said |
|---|---|---|
| 2026-09-03 | [ticket 67](../issues/67-stdlib-shape-as-a-principle.md), Q1 | *"the standard environment is closed by construction — which answers 65's first question"* |
| 2026-09-03 | ticket 67, Q6 | *"(iii) — refused at the call site, 47's rule"*. The build that refuses `module Shop.Collections.List` was offered as (i) and declined: *"Burns `List` as a path segment everywhere; nobody has asked for that."* |
| 2026-09-25 | [ticket 96](../issues/96-standard-environment-breadth.md), Q6 | *"what the standard environment qualifies is reserved, and nothing else"*, each new qualifier on ticket 67 Q6's terms |

Ticket 67 added that *"its reservation policy stays its own to decide"*. That sentence is the
reason 65 is still open. The probes below measure whether anything is left under it.

### 1 and 2. A bare module of a reserved name is refused at the declaration

```
bare/List/List.bs:1:1: error: `List` is a reserved qualifier, so no module may be called it
  `List.` names operations the compiler knows and inlines at the site;
  no beam ships for it and no `using` is ever written. The name is
  taken only as a WHOLE module name — `Shop.List` is still legal, and
  so is any other path with `List` as a segment.
[rc=1]
```

`Map`, `Term` and `Float` get the same sentence. `Enumerable` gets *"`Enumerable` is a protocol,
so no module may be called it"*. The check is `reserved_module_name/2` (`bs_check.erl:241`) over
`reserved_qualifiers/0` (`bs_check.erl:1699`, four names) and the keys of `protocol_table/0`
(`bs_check.erl:1426`, one name).

This is the ticket's policy 1, for the bare name.

### 3, 4 and 5. A path segment is legal, and the ambiguous call is refused

`module Shop.List` compiles and `Sum([1, 2, 3], 0)` prints `6`. With `using Shop`, a call written
`List.Sum([n, n, n], 0)` is refused:

```
src/Short/Short.bs:6:14: error: Go calls List.Sum, and `List` means two things here
  `List` is a reserved qualifier — the compiler's own operations —
  and a `using` line also short-qualifies these to it:
    Shop.List.Sum(...)
  write the module's full path to reach it, or drop the namespace
  import to reach `List.Sum`.
[rc=1]
```

The same module called `Shop.List.Sum([n, n, n], 0)` prints `6`. The tag is
`reserved_qualifier_shadowed` (`bs_check.erl:3292`, rendered at `bs_diag.erl:1405`). This is
ticket 67 Q6 (iii), built by F32.

### 6. The user's name never wins

`Shop.List.Sum/2` is the user's and `List.Sum/1` is the compiler's. Under `using Shop`,
`List.Sum([n, n, n])` is refused with the diagnostic above, not resolved to either. With no
`using`, it prints `6`, the compiler's sum. No program was found in which a user module answers
to a reserved word. The ticket's policy 3 is not what is built.

### 7. Ticket 96's eight names are free until their rows land

| `module` | today |
|---|---|
| `Enum`, `String`, `Int`, `Process`, `GenServer`, `Supervisor`, `Logger`, `System` | compiles, `Go(1)` prints `1` |
| `Binary` | compiles, `Go(1)` prints `1` |

The first eight are the names ticket 96 Q6 lists. None is in `reserved_qualifiers/0`, because no
feature has built its rows. A program declaring `module String` compiles at `24e769f` and stops
compiling on the day the `String` rows land. The Linear issue that owns those rows says so in its
title: ENG-455, *"The `String` rows over `string` and `binary`, and `String` reserved"*.
`LANGUAGE.md:2160` gives the reason `Map` was not left to that: *"reserving it later would have
meant taking it away from a program that had already used it."* Ticket 96 Q6's sentence is
*"every qualifier the standard environment adds is reserved"*, which reads as reserved when
added.

`Binary` is in no decided list. Whether it is a reserved qualifier is
[ticket 93](../issues/93-binary-operations-under-a-reserved-qualifier.md)'s question, asked and
not answered.

### 8. `bs@` cannot be written

[Ticket 87](../issues/87-an-export-the-author-did-not-write.md) handed this ticket one entry:
whether `bs@` is a reserved export prefix.

```
at/At/At.bs:3:14: error: illegal characters "@"
```

The lexer has no rule that takes `@` in an identifier (`bs_lexer.xrl:150`, `{UPPER}{ALNUM}*`), so
neither `bs@x` nor `Bs@x` reaches the parser. A module that never wrote the prefix exports
`Go/1`, `bs@type_atoms/0`, `module_info/0` and `module_info/1`. The prefix is the compiler's by
the lexer's rule and needs no entry in a reserved list.

### 9. `not` is an identifier

`F(not) when not > 100` compiles and `F(101)` prints `:true`, as
[ticket 63](../issues/63-negation-has-no-spelling.md) left it when F27 declined to make `not` a
keyword without a decision from this ticket. Ticket 65's own question is about module names under
the standard environment and does not mention identifiers. Nothing since has asked for `not` to
be taken.

### 10. Erlang, on the same toolchain

A user module called `lists`:

```
erlc lists.erl: [rc=0]
loaded into a running VM, then lists:sum([1,2,3]):
  {error,sticky_directory}
  6
Can't load module 'lists' that resides in sticky dir
first on the code path at boot (erl -pa):
  (no logger present) unexpected logger message: {log,error,"Error in process ~p with exit value: ...
  [rc=1]
```

Erlang refuses nothing at the declaration. The running code server refuses the load
(`lib/kernel/src/code_server.erl:1342-1345`, OTP 28.5: `is_sticky/2`, then
`{error,sticky_directory}`), and the standard `lists` keeps answering. Put first on the code path
before boot, the user's `lists` is the one the kernel loads, and the VM does not start.

### Elixir and Gleam: not run

[Ticket 48](../issues/48-a-map-type-in-the-prelude.md) measured Elixir 1.19.5 on 2026-08-25:
`defmodule Map` warns, replaces the standard module, and Elixir's own type checker crashes
calling `Map.update!/3`. That was not rerun here. Gleam was not examined.

### Beside the question: the spec's list is two names short

`LANGUAGE.md:2100` heads the section *"Reserved qualifiers — `List`, `Term` and `Map`"* and
`LANGUAGE.md:2160` says *"Three names are reserved"*. The compiler refuses five: those three,
`Float` (F51) and `Enumerable` (F64). `LANGUAGE.md:584` does call `Float.FromInt` *"an entry under
a reserved qualifier"*. Not changed by this round.
