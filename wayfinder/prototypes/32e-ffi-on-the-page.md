# 32e — What a foreign call looks like on the page

> **Throwaway.** Ticket [32](../issues/32-ffi-surface.md). 32a–32d priced the options; this one
> writes them out so they can be *read*. Same program three ways.
> **Verdict: shape A, David — "A clearly reads better."**

The program: a **session cache over ETS**. Ordinary on purpose — three foreign calls
(`ets:lookup/2`, `erlang:system_time/1`), a narrowing, and nothing contrived. Syntax follows the
skeleton's examples (`compiler/examples/*.bs`): `module X;` header, `ReturnType Name(Type name);`
signature, clauses repeating the function name.

---

## Shape A — declare it, carrying both names — **CHOSEN**

```csharp
module Sessions;

[external: erlang, "ets"]
module Ets {
    list<term> Lookup(atom table, term key);
}

[external: erlang, "erlang"]
module Erlang {
    int SystemTime(atom unit);
}

option<term> Fetch(atom table, binary id);

Fetch(table, id) -> Ets.Lookup(table, id) switch {
    [(_, row), ..] => row,
    []             => :nothing
};

bool Live(int expiresAt);

Live(expiresAt) when expiresAt > Erlang.SystemTime(:second) -> true;
Live(_)                                                     -> false;
```

**Reads:** call sites are invisible — `Ets.Lookup(table, id)` is an ordinary qualified call, and
`Erlang.SystemTime(:second)` sits inside a guard without announcing itself. Every seam the program
has is listed in one place.

**Grates:** the *flat* version of this shape invents a beam-sharp name per foreign function and
collides at once, so you prefix — `EtsLookup`, `EtsInsert` — which is Hungarian notation reinvented
and a name that lies about where the function lives. **Binding the module removes it**, which is why
the ticket adopted the block form above rather than the flat one first drafted.

---

## Shape B — declare nothing (Elixir's)

```csharp
module Sessions;

option<term> Fetch(atom table, binary id);

Fetch(table, id) -> :ets.lookup(table, id) switch {
    [(_, row), ..] => row,
    []             => :nothing
};

bool Live(int expiresAt);

Live(expiresAt) when expiresAt > :erlang.system_time(:second) -> true;
Live(_)                                                       -> false;
```

**Reads:** shortest, no invented vocabulary, and the `:` sigil marks every crossing for free — every
foreign call is visibly foreign with no rule saying so.

**Grates:** everything foreign comes back as `term`, so it must be narrowed before use. **The cost is
regressive**: nearly free on values you were going to validate anyway, most annoying on
`system_time`, `byte_size`, `length` — the trivial calls made most often, and the guard above is
exactly such a case.

---

## Shape C — the name matches the foreign symbol (C#'s). **Closed by writing it.**

```csharp
[foreign: "ets"]
list<term> lookup(atom table, term key);
```

**Ticket 26 disambiguates the dot lexically by casing** — `o.Status` projects a field, `List.Map`
calls a function. So `Sessions.lookup(table, id)` lexes as *projecting a field named `lookup`*, not
as a call. A lowercase foreign name is unspellable at the call site, so the override becomes
mandatory on every declaration, at which point this **is** shape A with a longer attribute.

**One of the three was not a live option, and no measurement found that — writing the code did.**

---

## What the page said that the numbers did not

**1. The real axis was never naming.** It is whether the seams are listed in one place or scattered
through the code. Shape A yields a manifest of every foreign dependency for free; shape B cannot
have one without scanning every file.

**2. Shape B's cost is regressive**, per above — a fixed declaration per function against a narrowing
per *use*.

**3. The name-mapping census in [32b](32b_name_census.md) answered a question nobody had.** Shape A
writes the Erlang name in quotes, shape B writes it in the call; neither derives anything. The
1,920-of-1,924 figure only ever mattered to the shape ticket 26 has now closed.

**4. The chosen shape is the one the standing constraint already implied.** Declaring up front is
write cost, priced near-free; narrowing a `term` at each use is read cost, which carries full
weight. The answer was available before any of the four measurements were taken and nobody derived
it — the measurements ruled out shape C and priced the lowering, neither of which the constraint
could have told you.
