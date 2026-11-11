# 64 — `option<T>` at `T = term`: probes

## 2026-11-11

**Toolchain: Erlang/OTP 28.5 built from `otp_src_28.5.tar.gz` (the pin in `.tool-versions` is
28.5), rebar3 3.27.0 from its GitHub release.** Neither came from mise, so
`bin/check-toolchain.sh --env` would not accept this sandbox; the versions match the pin.
`compiler/` at `cd080fa`, unmodified, built with `rebar3 escriptize`; the repo's test suite and
gates other than `check-links.sh` were not run. Elixir and Gleam were not installed: their
sections below are read from source at a tagged release, and nothing in them was executed.

Every B# result below is printed by
[`64a_absent_at_term.sh`](../prototypes/64a_absent_at_term.sh), run from the repo root.

### 1. `option<term>` written out is refused, as F31 and F36 built it

```
Written/Written.bs:3:21: error: `:nothing` is absorbed by `term`
  in Trace
  the failure channel does not survive normalisation, so the type
  declared here IS `term`. No caller can write the failure clause,
  because no failure member is left to match.
  hint: tag it - (:some, term) | :nothing
```

`result<term, string>` is refused by the same tag. `result<int, term>` compiles clean, which
answers the ticket's open item 3: `(:error, term)` is absorbed by the success type or by nothing,
so `E = term` does not collapse on its own.

### 2. The same type, reached by solving a variable, is not refused

```csharp
private option<T> Find<T>(list<(string, T)> xs, string key)
```

called with a `list<(string, term)>` compiles with no diagnostic. `bsc --api` prints the call's
type where a caller returns it:

```
module Solved
term Raw(list<(string, term)>)
string Trace(list<(string, term)>)
```

The refusal walk never sees it. `collapse_decl/2` (`bs_check.erl:1109`) scans declarations, and a
signature over a type variable has no ground union to scan. The call is typed by
`checked_call_typed/7`'s template clause (`bs_check.erl:4416`), which substitutes the solution into
the return template with `subst_tpl/2`; at a union that is `bs_types:union/1`
(`bs_check.erl:1013`), which erases the member boundary without asking `absorbed/2`
(`bs_check.erl:3415`).

### 3. Run, the collapsed call gives a wrong answer

`Trace` switches on `Find(hs, "x-trace")` with a `:nothing` arm and a binder arm:

| headers | prints |
|---|---|
| `[("host", "a")]` | `"no trace header"` |
| `[("x-trace", "abc")]` | `"traced"` |
| `[("x-trace", :nothing)]` | `"no trace header"` |

The third row is a header that is present. The control, the same `Find` at `T = int`, prints
`"no port"` and `"has port"`: at `int` no value can be mistaken for the absent answer.

### 4. `Map.?Get` is not built, and will be typed by the same clause

```
Marked/Marked.bs:4:18: error: syntax error before: '?'
Plain/Plain.bs:4:17: error: Trace calls Map.Get/2, and `Map` has no operation of that name
```

[Ticket 108](../issues/108-the-second-forms-spelling.md) decided the `?` form of a lookup returns
`option<T>`, and F75 types every declared row *"as a call to a user's polymorphic function is
typed"* (`bs_check.erl:1716`). So when ENG-324 adds `Map.?Get` as a row,
`Map.?Get(headers, "x-trace")` over a `map<string, term>` reaches `checked_call_typed/7` and gets
the type section 2 measured, `term`, unless that clause changes first. The same holds for
`List.?First`, `?Last`, `?At` and `Map.?Find` over a `list<term>` or a `map<K, term>`.

### 5. What reports "absent" at a `term` value today

Both compile and both tell the three headers apart:

```csharp
using :maps {
    (:ok, term) | :error find(term key, map<term, term> m)
}

public string Trace(map<string, term> headers)
Trace(hs) -> :maps.find("x-trace", hs) switch {
    :error   => "no trace header",
    (:ok, v) => "traced"
}
```

| headers | `:maps.find` | `Map.Has` |
|---|---|---|
| `{ "host" = "a" }` | `"no trace header"` | `"no trace header"` |
| `{ "x-trace" = "abc" }` | `"traced"` | not run |
| `{ "x-trace" = :nothing }` | `"traced"` | `"traced"` |

`Map.Has` (F75, `bs_check.erl:1747`) answers presence and does not hand back the value; with
`Map.Get` unbuilt, the foreign `find` is the only route today that returns it.

### 6. Erlang, Elixir and Gleam

Read from source, not run.

- **Erlang.** `maps:find/2` returns `{ok, Value} | error`
  (`lib/stdlib/src/maps.erl:138`, OTP 28.5), tagged, so a stored `error` is `{ok, error}`.
  `maps:get/3` returns `Value | Default` (`maps.erl:686`), the untagged union, and the caller
  picks a default the map cannot hold.
- **Elixir.** `Map.fetch/2` is `{:ok, value} | :error` and is `:maps.find/2`
  (`lib/elixir/lib/map.ex:303-304`, v1.19.5). `Map.get/3` defaults to `nil`
  (`map.ex:531-532`), so `Map.get(%{a: nil}, :a)` and `Map.get(%{}, :a)` are the same value:
  the collapse section 3 measured, shipped and documented.
- **Gleam.** `dict.get` returns `Result(v, Nil)` (`src/gleam/dict.gleam:150`, gleam_stdlib
  v0.65.0), and `Option(a)` is `Some(a) | None` (`src/gleam/option.gleam:19-21`). Both wrap the
  value, so `Option(Option(a))` nests and there is no instantiation at which absent and present
  coincide.

B#'s `option<T> = T | :nothing` is Elixir's `Map.get/2` shape with a type on it. F31 and F36
refuse the collapse where the type is written; section 2 is the one place it is still reached.
