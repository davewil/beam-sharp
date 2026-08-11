# PROTOTYPE — a page of idiomatic beam-sharp

> **Throwaway. Not a commitment.** This exists to be reacted to, and every token in it is
> negotiable. It answers one question: *what does this language look like when you read it?*
> Ticket [01](../issues/01-sample-code.md).
>
> **RESOLVED — read the ticket, not this file, for what was decided.** In short: **Variant A**
> (§1) was chosen; §1's argument for Variant B did not carry. Variant B also exposed that
> multi-clause heads are notationally rather than semantically distinct from Gleam's
> multi-subject `case`, which amended the differentiator in
> [ticket 00](../issues/00-charting-decisions.md). The atom sigil (§5) and guard punctuation
> (§2) remain open on tickets 10 and 08.

---

## The finding, before the code

**C# already has every pattern form this language needs.**

| beam-sharp needs | C# already has |
|---|---|
| destructure a map in a head | property pattern — `{ Balance: 0 }` |
| destructure a tuple in a head | positional pattern — `(:ok, n)` |
| guard a clause | `when` |
| a one-expression body | `=>` expression-bodied member |
| a multi-statement body | `{ … }` block body |
| copy-with-changes | `with` expression |

So the design is **not** "invent pattern matching in a C# skin". It is one structural move:

> **Take C#'s pattern grammar out of `switch` arms, put it in the parameter position, and
> allow N declarations where C# allows one.**

Everything below follows from that single move.

---

## 1. The headline: multi-clause heads

Two genuinely open variants. Same function, same semantics.

### Variant A — equations under a signature

```csharp
type Verdict = :positive | :zero | :negative | :unknown;
type Reading = (:ok, int) | (:error, string);

Verdict Classify(Reading r);

Classify((:ok, n)) when n > 0 => :positive;
Classify((:ok, 0))            => :zero;
Classify((:ok, _))            => :negative;
Classify((:error, _))         => :unknown;
```

### Variant B — a clause block

```csharp
type Verdict = :positive | :zero | :negative | :unknown;
type Reading = (:ok, int) | (:error, string);

Verdict Classify(Reading)
{
    ((:ok, n)) when n > 0 => :positive;
    ((:ok, 0))            => :zero;
    ((:ok, _))            => :negative;
    ((:error, _))         => :unknown;
}
```

**Why the signature is not optional in either.** Ticket 04 established that exhaustiveness is
only well-posed against a *declared* input type — check the union of clause domains against a
domain defined as that same union and you have proved nothing. The signature is what the clauses
are checked *against*. It is load-bearing, not decoration.

**Lean: B.** Three reasons, in order of weight:

1. **The signature and its clauses cannot drift apart.** In A they are separate top-level forms;
   a reader must scan to find which signature governs a clause, and nothing stops a hundred lines
   appearing between them. B makes the relationship structural.
2. **A looks too much like C# overloads.** Repeated `Classify(…)` declarations read, to a C#
   developer, as *different methods dispatched on static type*. That is the wrong mental model,
   and it is the one misconception most likely to stick.
3. **The check is per-arrow.** An interface may have several arrows and the checker runs once per
   arrow (ticket 04). B has an obvious place to put a second arrow; A does not.

**What A has that B doesn't**: each clause reads as a free-standing rule, which is exactly what
Erlang and Elixir programmers expect, and clauses can be reordered by moving one line. If the
audience is BEAM people rather than C# people, A wins.

B's cost is real and worth naming: `((:ok, n))` has doubled parentheses — the outer pair is the
parameter list, the inner is the tuple pattern. Single-argument functions will always look like
that. Variant A has the same problem. Neither is pretty; the multi-argument case below is where
it stops mattering.

---

## 2. Multiple arguments, destructuring, guards, `with`

Where the parameter position earns itself — dispatch on several arguments jointly, no tuple
built to carry them, no scrutinee named.

```csharp
type Account = { Id: string, Balance: int, Status: :open | :frozen };
type Command  = (:deposit, int) | (:withdraw, int) | :close;

Account Apply(Account, Command)
{
    ({ Status: :frozen } a, _)                       => a;
    (a, (:deposit, amt))  when amt > 0               => a with { Balance = a.Balance + amt };
    (a, (:withdraw, amt)) when amt > 0, amt <= a.Balance
                                                     => a with { Balance = a.Balance - amt };
    (a, (:withdraw, _))                              => a;
    (a, :close)                                      => a with { Status = :frozen };
}
```

Three things to notice.

**`{ Status: :frozen } a`** is a C# property pattern with a designation — already legal C#
syntax, doing exactly what it does in C#. Map destructuring came free.

**The comma in `when amt > 0, amt <= a.Balance`** is Erlang's guard conjunction, not C#'s.
This is where the platform intrudes: BEAM guards are a closed set of BIFs with no user function
calls, and Erlang's guard sequences are a list-of-lists (`,` for and, `;` for or) with
fail-to-false semantics that `&&` does not have. Ticket 08 has to decide whether to keep
Erlang's punctuation, spell it `&&`/`||` and accept a semantic mismatch, or restrict guards to
what maps cleanly. **Shown here as the honest version; it is the ugliest line on the page.**

**`with`** is C#'s, and ticket 05 found it becomes *more* central here than in C# — with no
mutation anywhere, it is how all state changes are written.

---

## 3. The showcase: OTP callbacks

The reason the feature exists. One clause per message shape, and the compiler proves the
clauses cover the declared message type.

```csharp
module Counter : GenServer;

type Request = :increment | :get | (:add, int) | (:set, int);

int Init(int start) => start;

(Reply<int>, int) HandleCall(Request, From, int)
{
    (:increment,  _, n)            => (reply(n + 1), n + 1);
    (:get,        _, n)            => (reply(n),     n);
    ((:add, m),   _, n) when m > 0 => (reply(n + m), n + m);
    ((:add, _),   _, n)            => (reply(n),     n);
    ((:set, m),   _, _)            => (reply(m),     m);
}
```

Delete the `(:set, m)` clause and the compiler says:

```
error: clauses of HandleCall/3 do not cover Request
  missing: (:set, int)
  example: (:set, 0)
    --> counter.bs:9:1
```

That message is not aspirational. Ticket 04 established that exhaustiveness is computed as
`t \ (Acc(p₁)|…|Acc(pₙ)) ≃ 0`, and **the residual is the missing case** — CDuce already prints
the residual type plus a sampled counter-value. Compute the difference instead of asking a
boolean and the diagnostic falls out of the algorithm.

Neither Elixir nor Gleam gives you this today. Elixir v1.20 ships redundancy detection only;
Gleam has no multi-clause heads to check.

### `handle_info` — where the honesty lives

`handle_call` is the easy case: only your own code sends those. The mailbox is not so tidy —
monitors, timers, `:EXIT` signals and any process that knows your pid can put anything in it.

```csharp
type Known = (:tick, Ref) | (:DOWN, Ref, :process, Pid, dynamic);

(:noreply, int) HandleInfo(Known | dynamic, int)
{
    ((:tick, _),           n) => (:noreply, n + 1);
    ((:DOWN, _, _, _, _),  n) => (:noreply, n);
    (other,                n) => { Log.Warn("unexpected message", other); (:noreply, n); }
}
```

The `Known | dynamic` input type is the whole argument in one line. Exhaustiveness over `Known`
is proved; the `dynamic` arm is what the platform forces, and it is *visible in the signature*
rather than hidden in a catch-all. A reader can see precisely which part of this function is
guaranteed and which is trusted.

Ticket 06 found that OTP already validates the shapes you **return** and kills the process if
they are wrong — so the return side needs no defence from this language. Only the input side
does.

---

## 4. Crossing into Erlang

```csharp
[Erlang("lists", "reverse")]
list<T> Reverse(list<T> xs);

[Erlang("erlang", "system_time")]
int SystemTime(:millisecond | :second unit);
```

C# attribute syntax, which every C# developer already reads. The type is an **unverified
claim** — nothing checks that `lists:reverse/1` matches it, which is exactly the sub-decision
ticket 18 holds open about whether such a declaration should emit a `-spec` at all.

Usage, showing the chained form (ticket 05: `xs.Where(f)` and `xs |> where(f)` are the *same*
static rewrite, so this is a pipeline wearing a dot):

```csharp
list<int> Evens(list<int> xs) =>
    xs.Filter(x => x % 2 == 0)
      .Map(x => x * 10)
      .Reverse();
```

---

## 5. The atom question, both ways

Genuinely open, and it touches every line above.

| | Variant 1 — `:atom` | Variant 2 — `#atom` |
|---|---|---|
| literal | `:ok`, `:error`, `:noreply` | `#ok`, `#error`, `#noreply` |
| in a union | `:open \| :frozen` | `#open \| #frozen` |
| as a map key | `{ Status: :open }` | `{ Status: #open }` |
| cost | collides with C#'s ternary `? :` — the language would have to drop ternary (pattern matching arguably replaces it) and with base-type lists (`module Counter : GenServer`) | `#` is C#'s preprocessor sigil, unused here; no collision at all |
| benefit | identical to Elixir, so every BEAM programmer reads it instantly | unambiguous, and `#` already signals "compile-time thing" to a C# eye |

Note the collision is visible in this very document: `module Counter : GenServer` and
`{ Status: :open }` both use `:` for something other than an atom.

**Lean: `:atom`**, and drop the ternary operator. Familiarity to the BEAM audience is worth
more than the parse simplification, and a language with pattern matching in the parameter
position does not need `?:`. But this is exactly the sort of choice that should be made by
someone who will have to read it for years.

---

## 6. The showcase, actually running

§3 is not a sketch. [`01_counter_lowering.erl`](01_counter_lowering.erl) is the Erlang that
Counter lowers to, hand-written and executed on local OTP 28 (`erts-16.4`):

```
init            -> 10
increment       -> 11
add 5 (guard T) -> 16
add -3 (guard F)-> 16          <- guard failed, fell through to the next clause
set 99          -> 99
after tick      -> 100
  [warn] unexpected message: {something,unexpected}
after junk msg  -> 100 (process alive: true)

clauses in handle_call/3: 5
clauses in handle_info/2: 3
```

Three things this establishes rather than assumes:

1. **One beam-sharp clause becomes one native Erlang clause head.** The last two lines read the
   `abstract_code` chunk out of the compiled `.beam`: five clauses in, five clauses out, order
   and guards intact. Ticket 02's claim that the Abstract Format expresses multi-clause heads
   natively holds for exactly the shape this language needs.
2. **No `-behaviour` attribute, and it still runs as a `gen_server`.** Ticket 06 found the
   attribute has no runtime effect; this is that finding exercised rather than cited.
3. **The `dynamic` arm behaves as designed.** An unexpected message is logged and the process
   survives — the `Known | dynamic` signature describes real behaviour, not an aspiration.

What it does **not** establish: nothing here was type-checked, because there is no checker. The
exhaustiveness error in §3 is the one thing on this page still taken on the authority of
ticket 04.

---

## 7. What this prototype did *not* try to settle

- **Nominal versus structural unions** (ticket 09). Every `type X = …` above is written as a
  structural alias, because that is what set-theoretic types are — but ticket 07 found the
  wrapper cost of nominality may be a CLR artefact that does not apply here, so a nominal
  reading of the same syntax is still live.
- **Ad-hoc polymorphism** (ticket 16). `list<T>` above quietly assumes generics exist and that
  `Filter` works over any list. Nothing here says how `Compare` or `Show` would work.
- **Binaries** (ticket 20). Not one binary pattern appears above, and binaries are the BEAM's
  string type and wire format. This is the largest gap in this page, and it is deliberate:
  ticket 04 found binaries are *untheorised* in the set-theoretic literature, so a plausible
  syntax here would have been fiction.
- **Modules, imports and function identity** — `module Counter : GenServer;` is a placeholder.
