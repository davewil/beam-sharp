# PROTOTYPE 01b — Variant A, at length

> **Throwaway. Not a commitment.** The first prototype chose Variant A on the strength of one
> four-clause function while writing everything substantial in Variant B. This is the correction:
> a realistic module set written **entirely in Variant A**, long enough to judge the rhythm
> rather than infer it. Ticket [01](../issues/01-sample-code.md).
>
> Read it for *feel*. Every token is negotiable. The friction list at the end is the honest part —
> it records what writing this actually surfaced, including three things that don't work.

---

## Module 1 — `Orders`, pure domain logic

No processes, no OTP. This is where you find out whether the language is pleasant for ordinary
code, which is most code.

```csharp
module Orders;

type Money = int;                     // minor units, always

type Status = :draft | :placed | :paid | :shipped | :cancelled;

type Line = {
    Sku:  string,
    Qty:  int,
    Unit: Money,
};

type Order = {
    Id:     string,
    Status: Status,
    Lines:  list<Line>,
    Paid:   Money,
};

type Event =
    (:add_line, Line)
  | (:remove_line, string)
  | :place
  | (:pay, Money)
  | (:ship, string)
  | :cancel;

type Rejected =
    (:not_allowed, Status, Event)
  | (:no_such_line, string)
  | (:underpaid, Money)
  | :empty_order;

type Outcome = (:ok, Order) | (:error, Rejected);
```

### The transition table

The reason the language exists, at the size it actually occurs.

```csharp
Outcome Apply(Order o, Event e);

Apply(o, (:add_line, l))     when o.Status == :draft
    => (:ok, o with { Lines = [l, ..o.Lines] });

Apply(o, (:remove_line, sku)) when o.Status == :draft
    => RemoveLine(o, sku);

Apply(o, :place)             when o.Status == :draft, o.Lines != []
    => (:ok, o with { Status = :placed });

Apply(o, :place)             when o.Status == :draft
    => (:error, :empty_order);

Apply(o, (:pay, amt))        when o.Status == :placed, amt >= Total(o)
    => (:ok, o with { Status = :paid, Paid = amt });

Apply(o, (:pay, amt))        when o.Status == :placed
    => (:error, (:underpaid, Total(o) - amt));

Apply(o, (:ship, _))         when o.Status == :paid
    => (:ok, o with { Status = :shipped });

Apply(o, :cancel)            when o.Status != :shipped
    => (:ok, o with { Status = :cancelled });

Apply(o, e)
    => (:error, (:not_allowed, o.Status, e));
```

**This is Variant A at its best.** Nine clauses, aligned guards, and it reads as a specification
of the state machine rather than as code that implements one. The repeated `Apply(o, …)` is not
noise here — it is the left margin of a table, and the eye stops seeing it by the third row.

Note the last clause. It is the total-function catch-all, and whether it should be *required*,
*forbidden*, or *inferred* is ticket 12's question. Here it converts "no clause matched" from a
crash into a value, which is a choice, not an obligation.

But notice what it costs: `Apply(o, e) => (:error, (:not_allowed, o.Status, e))` makes the
function total, so **the compiler can no longer tell you when you have forgotten a case.** The
exhaustiveness guarantee this language is built on is switched off by the catch-all that makes
the function safe. That tension is real and this prototype does not resolve it.

### Recursion and list work

```csharp
Money Total(Order o) => Total(o.Lines, 0);

Money Total(list<Line> lines, Money acc);

Total([], acc)                            => acc;
Total([{ Qty: q, Unit: u }, ..rest], acc) => Total(rest, acc + q * u);
```

`Total/1` and `Total/2` are **different functions** — BEAM identity is name *and* arity, so this
is not overloading, it is two functions that happen to share a name. That falls out naturally and
matches Erlang exactly.

The second clause is the one to look at: `[{ Qty: q, Unit: u }, ..rest]` is a C# list pattern
containing a C# property pattern, in the parameter position. Nothing was invented for it.

```csharp
list<Line> Merge(list<Line> lines);

Merge([])                                       => [];
Merge([l])                                      => [l];
Merge([a, b, ..rest]) when a.Sku == b.Sku       => Merge([a with { Qty = a.Qty + b.Qty }, ..rest]);
Merge([a, ..rest])                              => [a, ..Merge(rest)];
```

Four clauses, no `case`, no scrutinee named, and clause order carrying the logic. This is the
shape that is genuinely tedious to write as a nested `case`.

### Where it stops being pretty

```csharp
Outcome RemoveLine(Order o, string sku);

// ILLEGAL. HasSku is a user function, and BEAM guards permit only guard BIFs.
RemoveLine(o, sku) when HasSku(o.Lines, sku)
    => (:ok, o with { Lines = o.Lines.Reject(l => l.Sku == sku) });

RemoveLine(_, sku)
    => (:error, (:no_such_line, sku));
```

**This does not compile and cannot be made to.** Erlang restricts guards to a closed set of
BIFs — no user function calls, at all, ever. It is the single hardest constraint the platform
imposes on this syntax, because the natural way to write a guarded clause is to ask a question,
and asking a question usually means calling something.

The legal version has to move the test into a body, which costs the clause structure:

```csharp
Outcome RemoveLine(Order o, string sku);

RemoveLine(o, sku)
{
    var kept = o.Lines.Reject(l => l.Sku == sku);

    if (kept.Length == o.Lines.Length)
        return (:error, (:no_such_line, sku));

    return (:ok, o with { Lines = kept });
}
```

Two clauses became one, and the dispatch that was going to be the language's selling point
turned into an `if`. **Every predicate a programmer wants in a guard and cannot have pushes code
out of the clause table and into a body.** How often that happens in real code is the question
this prototype cannot answer alone — but it is the thing most likely to decide whether the
syntax is a joy or a tease.

---

## Module 2 — `OrderServer`, the OTP layer

```csharp
module OrderServer : GenServer;

type Request =
    (:apply, string, Event)
  | (:fetch, string)
  | :stats;

type State = {
    Orders:   map<string, Order>,
    Applied:  int,
    Rejected: int,
};

State Init(:no_args) => { Orders: #{}, Applied: 0, Rejected: 0 };
```

### `handle_call` — the showcase

```csharp
(Reply<Outcome>, State) HandleCall(Request req, From from, State s);

HandleCall((:apply, id, e), _, s)   => ApplyTo(s, id, e);

HandleCall((:fetch, id), _, s)      when s.Orders.HasKey(id)
    => (Reply((:ok, s.Orders[id])), s);

HandleCall((:fetch, id), _, s)
    => (Reply((:error, (:no_such_order, id))), s);

HandleCall(:stats, _, s)
    => (Reply((:ok, (s.Applied, s.Rejected))), s);
```

Delete the `:stats` clause and the compiler says:

```
error: clauses of HandleCall/3 do not cover Request
  missing: :stats
    --> order_server.bs:14:1
```

`s.Orders.HasKey(id)` **is** guard-legal, but only because `is_map_key/2` happens to be a guard
BIF. `HasSku` above was not. **Nothing in the syntax distinguishes them** — both read as a method
call on a value. The language would need a known set of guard-legal names, the way
`purescript-backend-erl` carries a hardcoded 36-name whitelist (ticket 19). A programmer will
have to learn which of its own standard library calls are permitted in a guard, and the syntax
gives no clue.

### `handle_info` — where the mailbox is honest

```csharp
type Known =
    (:DOWN, Ref, :process, Pid, dynamic)
  | (:timeout, Ref, :sweep);

(:noreply, State) HandleInfo(Known | dynamic msg, State s);

HandleInfo((:DOWN, _, :process, pid, reason), s)
    => (:noreply, DropWorker(s, pid, reason));

HandleInfo((:timeout, _, :sweep), s)
    => (:noreply, Sweep(s));

HandleInfo(other, s)
{
    Log.Warn("unexpected message", other);
    return (:noreply, s);
}
```

`Known | dynamic` in the signature is the whole argument in one line: exhaustiveness is proved
over `Known`, and the `dynamic` arm is what the platform forces — visible in the type rather than
hidden in a catch-all. A reader can see exactly which half of this function is guaranteed.

### `handle_cast`, and a two-clause function

```csharp
(:noreply, State) HandleCast(:flush | (:preload, list<Order>), State s);

HandleCast(:flush, s)          => (:noreply, s with { Orders = #{} });
HandleCast((:preload, os), s)  => (:noreply, s with { Orders = IndexById(os) });
```

**Here Variant A is at its worst.** Two clauses, and `HandleCast` is written three times in five
lines — once in the signature, once per clause. At this size the repetition is pure overhead and
the table effect never arrives. Most functions in a real codebase are this size, not nine clauses.

---

## Module 3 — supervision, and interop

```csharp
module OrderSup : Supervisor;

(SupFlags, list<ChildSpec>) Init(:no_args) =>
    ( { Strategy: :one_for_one, Intensity: 3, Period: 60 },
      [ Child(:orders, OrderServer.StartLink, :permanent, :worker) ] );
```

```csharp
[Erlang("erlang", "system_time")]
int SystemTime(:millisecond | :second unit);

[Erlang("lists", "keyfind")]
(string, Order) | :false KeyFind(string key, int n, list<(string, Order)> haystack);
```

The second declaration is worth pausing on. `lists:keyfind/3` returns a tuple **or the atom
`false`** — an untagged union of a tuple and an atom, which is exactly the shape a nominal type
system cannot describe without wrapping, and exactly what structural set-theoretic types are for.
It is also an **unverified claim**: nothing checks that `lists:keyfind/3` actually behaves this
way (ticket 18).

And the chained form, which ticket 05 established is the same static rewrite as `|>`:

```csharp
list<string> ActiveSkus(list<Order> orders) =>
    orders.Filter(o => o.Status == :placed || o.Status == :paid)
          .FlatMap(o => o.Lines)
          .Map(l => l.Sku)
          .Distinct();
```

---

## Module 4 — recursion, which is Variant A's strongest case

Header once, implementation as equations. This is the shape ML, Haskell and Erlang all
converged on, and it is where the repeated function name stops being repetition and starts
being structure.

### Structural recursion over a tree

```csharp
type Tree = :leaf | (:node, Tree, int, Tree);

Tree Insert(Tree t, int x);

Insert(:leaf, x)                        => (:node, :leaf, x, :leaf);
Insert((:node, l, v, r), x) when x < v  => (:node, Insert(l, x), v, r);
Insert((:node, l, v, r), x) when x > v  => (:node, l, v, Insert(r, x));
Insert((:node, _, _, _) t, _)           => t;              // already present
```

Four equations, no `case`, no scrutinee named, and the recursive calls sit inside the
constructed result where you can see them. The last clause uses a **designation** —
`(:node, _, _, _) t` binds the whole node while matching its shape. That is C#'s existing
pattern-designation syntax doing the work of Erlang's `T = {node,_,_,_}`, and it is the third
thing C# turned out to already have.

### The public/private accumulator pair

The most common recursive idiom on the BEAM, and the one that shows the header cost honestly.

```csharp
list<int> ToList(Tree t) => ToList(t, []);

list<int> ToList(Tree t, list<int> acc);

ToList(:leaf, acc)             => acc;
ToList((:node, l, v, r), acc)  => ToList(l, [v, ..ToList(r, acc)]);
```

`ToList/1` and `ToList/2` are different functions sharing a name — BEAM identity is name *and*
arity, so the pair costs nothing conceptually. But count the lines: **four occurrences of
`ToList` to express two equations.** For a two-clause helper the header is pure overhead, and
almost every accumulator helper is two clauses.

### Mutual recursion

```csharp
bool IsEven(int n);
bool IsOdd(int n);

IsEven(0)             => true;
IsEven(n) when n > 0  => IsOdd(n - 1);

IsOdd(0)              => false;
IsOdd(n) when n > 0   => IsEven(n - 1);
```

Variant A has a layout question here that Variant B could not have had: **do the two headers
group at the top, or does each sit above its own clauses?** Grouped, as above, the mutual
relationship is visible at a glance and the clauses read as one system. Separated, each function
is self-contained but the mutual dependency is invisible until you read the bodies. Neither is
obviously right, and nothing in the syntax forces either.

### Merge sort — where guards do real work

```csharp
list<int> MergeSorted(list<int> a, list<int> b);

MergeSorted([], b)                                 => b;
MergeSorted(a, [])                                 => a;
MergeSorted([x, ..xs] a, [y, ..ys] b) when x <= y  => [x, ..MergeSorted(xs, b)];
MergeSorted([x, ..xs] a, [y, ..ys] b)              => [y, ..MergeSorted(a, ys)];
```

This is the prototype's prettiest function and it is worth saying why. Both arguments are
destructured *and* bound whole in the same head — `[x, ..xs] a` gives you the first element, the
tail, and the original list at once — so the recursive calls can pass whichever they need without
rebuilding anything. In Erlang this is `MergeSorted([X|Xs] = A, [Y|Ys] = B)`; here the designation
carries it.

### The friction recursion exposes: intermediate values

```csharp
list<int> Sort(list<int> xs);

Sort([])  => [];
Sort([x]) => [x];
Sort(xs)  => ???                      // Split(xs) returns a pair. Now what?
```

**You cannot pattern-match the result of a call in the parameter position** — the head matches
arguments, and `Split(xs)` is not an argument. Erlang solves this in the body with
`{L, R} = split(Xs),`. Variant A has two answers, and neither is free:

```csharp
// (a) a block body, using C# tuple deconstruction
Sort(xs)
{
    var (l, r) = Split(xs);
    return MergeSorted(Sort(l), Sort(r));
}

// (b) a helper function that exists only to destructure
list<int> SortHalves((list<int>, list<int>) halves);
SortHalves((l, r)) => MergeSorted(Sort(l), Sort(r));

Sort(xs) => SortHalves(Split(xs));
```

(a) is what a C# programmer will write and it is perfectly readable — but the moment a function
needs one intermediate value, it leaves the equation style entirely and becomes a block. (b)
keeps the equation style at the cost of a function nobody wanted, named for nothing.

**The equation form is only available for functions that never need an intermediate.** That is a
sharper constraint than it first appears, and it is the reason ML languages have `let … in`.
Whether beam-sharp needs a binding form that keeps you inside an expression — a `let`, or C#'s
`switch` expression, or something else — is now a real question. → ticket 08 or 17.

### Error propagation, and the feature paying off

Recursion over a type that can fail is where multi-clause heads justify themselves outside a
dispatch table.

```csharp
type Expr =
    (:num, int)
  | (:var, string)
  | (:neg, Expr)
  | (:add, Expr, Expr)
  | (:let, string, Expr, Expr);

type Env    = map<string, int>;
type Evaled = (:ok, int) | (:error, (:unbound, string));

Evaled Eval(Expr e, Env env);

Eval((:num, n), _)                    => (:ok, n);
Eval((:var, name), env) when env.HasKey(name)
                                      => (:ok, env[name]);
Eval((:var, name), _)                 => (:error, (:unbound, name));
Eval((:neg, e), env)                  => Negate(Eval(e, env));
Eval((:add, l, r), env)               => Combine(Eval(l, env), Eval(r, env));
Eval((:let, name, bound, body), env)  => Bind(name, Eval(bound, env), body, env);
```

The three helpers do the error propagation *in their heads*, which is the whole argument for the
feature in one place:

```csharp
Evaled Negate(Evaled v);

Negate((:ok, n))        => (:ok, -n);
Negate((:error, _) e)   => e;

Evaled Combine(Evaled a, Evaled b);

Combine((:ok, x), (:ok, y))  => (:ok, x + y);
Combine((:error, _) e, _)    => e;
Combine(_, (:error, _) e)    => e;

Evaled Bind(string name, Evaled bound, Expr body, Env env);

Bind(name, (:ok, v), body, env)  => Eval(body, env.Put(name, v));
Bind(_, (:error, _) e, _, _)     => e;
```

`Combine` is the clearest three lines in this document: two successes combine, either failure
short-circuits, and the ordering of the last two clauses *is* the left-biased choice. No `case`,
no `match`, no monad, no `?` operator — the dispatch is the head.

But note what it cost: **`Eval` needed three helper functions purely to sequence results.** A
language with a binding form, or a `Result`-aware operator, would fold all three into `Eval`
itself. Whether that is a virtue (every step named and independently testable) or a tax (three
functions where one would do) is genuinely arguable, and it is ticket 15's decision as much as
ticket 08's.

---

## Module 5 — `Fib`, and the guard that breaks the guarantee

No builtins, no `reduce`, no library. The simplest recursive function anyone writes, and the
sharpest test in this document.

```csharp
int Fib(int n);

Fib(0)            => 0;
Fib(1)            => 1;
Fib(n) when n > 1 => Fib(n - 1) + Fib(n - 2);
```

**This does not compile, and the reason is structural rather than incidental.**

Ticket 04 established exhaustiveness as `t \ (Acc(p₁)|…|Acc(pₙ)) ≃ 0`, where `Acc(p)` is the type
a **pattern** accepts. A guard is not a pattern. A checker reading patterns alone sees the third
clause accepting all of `int` but cannot see that `when n > 1` is what makes it safe — and
conservatively, a guarded clause contributes *nothing provable* to coverage.

Two distinct failures follow:

1. The declared domain `int` includes negatives, which no clause handles.
2. Narrow the domain to non-negative and the residual is still everything `≥ 2` — covered only by
   a clause whose guard the checker will not credit.

**So no function can be total if its totality rests on a guard** — and that describes most
arithmetic recursion: `Fib`, `Fact`, `Gcd`, every bounded countdown. The headline guarantee would
be unavailable in the first program anyone writes.

### The fix, and the inversion it produces

```csharp
type Nat = 0..;                       // an interval type, not an alias

int Fib(Nat n);

Fib(0)            => 0;
Fib(1)            => 1;
Fib(n) when n > 1 => Fib(n - 1) + Fib(n - 2);
```

Two things must hold for this to check. The type language needs **integer interval types** — and
CDuce has them, so this is not hypothetical. And the exhaustiveness checker must read
`when n > 1` as **refining** `Nat` to `2..`, leaving residual zero.

Guard-aware exhaustiveness is hard in general. It is tractable here for a reason peculiar to this
platform: **BEAM guards are a closed set of BIFs with no user function calls.** Friction #1 —
named below as the biggest threat to the design — is precisely what makes this decidable. A
small, closed, mostly-comparison guard language is the one you *can* build refinement for.

That inversion is the most useful thing in this prototype. The platform restriction everyone
treats as the language's wound is also its enabling condition, and the two cannot be separated:
open the guard language up for ergonomics and you lose the ability to check `Fib`.

→ tickets 04 (does the residual account for guards?), 08 (what may appear in a guard), 11
(does the type language have intervals?), 12 (what totality means when guards carry it).

### The same function, three more ways

Tail-recursive, threading two accumulators:

```csharp
int Fib(Nat n) => Fib(n, 0, 1);

int Fib(Nat n, int a, int b);

Fib(0, a, _)            => a;
Fib(n, a, b) when n > 0 => Fib(n - 1, b, a + b);
```

The first `n` values as a list, built by hand rather than by any library function:

```csharp
list<int> FibList(Nat count) => FibList(count, 0, 1);

list<int> FibList(Nat remaining, int a, int b);

FibList(0, _, _)            => [];
FibList(n, a, b) when n > 0 => [a, ..FibList(n - 1, b, a + b)];
```

Both read cleanly, and both are two equations under a header — the accumulator-pair shape again,
with its four occurrences of the name to express two rules.

Memoised, which walks straight back into the intermediate-value problem. Two sequential calls
each thread the map, so the result of the first is an argument to the second:

```csharp
(int, map<int, int>) Fib(Nat n, map<int, int> memo);

Fib(0, m)                   => (0, m);
Fib(1, m)                   => (1, m);
Fib(n, m) when m.HasKey(n)  => (m[n], m);

Fib(n, m)
{
    var (x, m1) = Fib(n - 1, m);
    var (y, m2) = Fib(n - 2, m1);
    return (x + y, m2.Put(n, x + y));
}
```

Three equations and then a block, in a nine-line function. That is the shape of the tax the
equation form charges the moment a function needs an intermediate value — and note that this is
not an exotic case. Threading state through sequential calls is ordinary BEAM code.

Also note the arity collision: `Fib/1`, `Fib/2` and `Fib/2` again — the tail-recursive
`Fib(Nat, int, int)` is `Fib/3`, but the memoised `Fib(Nat, map)` is `Fib/2`, which is the same
arity as nothing here yet would be if the accumulator version took one accumulator. **Name-plus-
arity identity means a function's name is only half its identity, and two unrelated helpers can
collide silently.** → ticket 08.

---

## Module 6 — two proposals about elision, and what they turned up

### 6a. Module-as-focus: the module declares the function, clauses drop the name

```csharp
module OrderServer.HandleCast : (:noreply, State) HandleCast(:flush | (:preload, list<Order>), State);

(:flush, s)         => (:noreply, s with { Orders = #{} });
((:preload, os), s) => (:noreply, s with { Orders = IndexById(os) });
```

Fixes friction #3 outright — the two-clause case stops paying three occurrences of a name for two
rules — and the left margin becomes patterns rather than repetition.

**Fits modern C# better than a conventional module does.** C# has drifted toward
single-responsibility types with one public entry point; "one module, one function, same name" is
closer to a 2026 C# codebase than "a module with thirty functions". And it buys something novel:
a module is the BEAM's unit of hot code loading, so module-per-function gives **per-function hot
swap**, finer-grained than Erlang has ever offered.

Three objections, none fatal, none free:

1. **The name returns in the recursive call.** You can elide it in the head, never in the body:
   `(n) when n > 1 => Fib(n - 1) + Fib(n - 2);`. A recursive function saves nothing. A
   `recur(…)`/`self(…)` keyword closes it (Clojure precedent) at the cost of a construct that
   reads worse than the name.
2. **A one-argument head becomes ambiguous.** `(0) => 0;` is visually a parenthesised expression.
   `Fib(0)` was not.
3. **Helpers.** Either separate modules — and a BEAM module is a real atom, code-server entry and
   purge unit, so thousands is an operational question — or helpers keep their names in the focal
   module, making named-vs-unnamed the marker for helper-vs-focus. C# local functions are a third
   answer (ticket 05 found them portable).

And the resemblance worth naming: **a signature declared once with unnamed clauses beneath it is
Variant B, with a module where the braces were.** The heavier container genuinely changes the
trade — a file boundary makes signature-clause drift impossible, and gives the type declarations
somewhere to live — but it is the same shape.

### 6b. Eliding the subject argument — and why the answer runs the other way

If `Apply`'s left argument is always an `Order`, can it be implicit too?

**It could, and it shouldn't** — because the subject is where the most valuable patterns belong,
and eliding it removes them.

Every clause in the original `Apply` tested `o.Status` in a **guard**, and friction item 0 says
guards contribute nothing provable to exhaustiveness. Pushing the opposite way:

```csharp
Outcome Apply(Order o, Event e);

Apply({ Status: :draft } o, (:add_line, l))           => (:ok, o with { Lines = [l, ..o.Lines] });
Apply({ Status: :draft } o, (:remove_line, sku))      => RemoveLine(o, sku);
Apply({ Status: :draft, Lines: [_, .._] } o, :place)  => (:ok, o with { Status = :placed });
Apply({ Status: :draft }, :place)                     => (:error, :empty_order);
Apply({ Status: :placed } o, (:pay, amt)) when amt >= Total(o)
                                                      => (:ok, o with { Status = :paid, Paid = amt });
Apply({ Status: :placed } o, (:pay, amt))             => (:error, (:underpaid, Total(o) - amt));
Apply({ Status: :paid } o, (:ship, _))                => (:ok, o with { Status = :shipped });
Apply({ Status: not :shipped } o, :cancel)            => (:ok, o with { Status = :cancelled });
Apply(o, e)                                           => (:error, (:not_allowed, o.Status, e));
```

**Eight of nine guards became patterns.** `o.Lines != []` became `Lines: [_, .._]`. The catch-all
is now the only clause the checker cannot credit, instead of the entire table.

#### The finding this produced

`{ Status: not :shipped }` is a **negation type in pattern position**, and it is checkable
because set-theoretic types are closed under negation by construction. Gleam cannot express it —
a nominal ADT gives constructors, and "every constructor but one" must be enumerated or fall to a
catch-all. C# 15's closed unions cannot either.

So a chain runs through the whole design:

> set-theoretic types → negation and interval types are expressible **as patterns** → more of
> each clause's condition moves out of guards and into patterns → **exhaustiveness can prove more
> of the program**.

This is the first place the type system and the syntax reinforce each other rather than trading
off, and it materially raises the value of the ticket 00 typing decision: it is not only about
describing raw Erlang terms, it determines how much of any program the compiler can check.

It also reframes friction item 0. Guard refinement is still needed for arithmetic recursion
(`Fib`), but for *data* dispatch the better answer is to stop using guards at all and put the
condition in the pattern where the checker can see it. → tickets 08, 11, 12.

#### The other reason not to elide

An implicit subject bound at module level still needs a name in guards and bodies, and that name
is `this`. A module fixing a receiver, with functions dispatching on the remaining arguments, is
a class — ruled out in the opening brief.

What the instinct does buy, kept as **subject-first by convention** rather than elision:
`Orders.Apply(order, event)`, `order.Apply(event)` and `order |> Orders.Apply(event)` are the same
static rewrite (ticket 05), so fixing the subject as the first parameter yields all three call
forms free. That is Elixir's design, and the reason `|>` works there at all. → ticket 17.

---

## What writing this actually surfaced

Nine things, ordered by how much they should worry you.

0. **Guards must participate in exhaustiveness, or the guarantee is unavailable in `Fib`.** A
   guard is not a pattern, so a checker reading patterns alone credits a guarded clause with
   nothing — and no function can be total if its totality rests on a guard. That is most
   arithmetic recursion. Needs interval types in the type language *and* guard refinement in the
   checker. **This outranks everything below it: it is the guarantee failing on the first
   program anyone writes.** → tickets 04, 11, 12.

1. **Guards cannot call user functions, and nothing in the syntax shows which calls are legal.**
   `s.Orders.HasKey(id)` works because `is_map_key/2` is a BIF; `HasSku(o.Lines, sku)` does not,
   and they look identical. Every predicate you want and cannot have pushes code out of the
   clause table into an `if`. **This is the biggest threat to the everyday ergonomics** — but see
   item 0: the same restriction is what makes guard-aware exhaustiveness decidable. The two
   cannot be separated, and loosening the guard language for ergonomics costs the guarantee.
   → ticket 08.

1b. **The equation form is unavailable to any function needing an intermediate value.** Matching
   the result of a call is impossible in the parameter position, so `Sort`, memoised `Fib`, and
   anything threading state through sequential calls must drop into a block body or invent a
   helper that exists only to destructure. This is ordinary BEAM code, not an exotic case, and it
   is why ML languages have `let … in`. → ticket 08 or 17.

2. **The catch-all clause switches off the guarantee.** `Apply(o, e) => (:error, …)` makes the
   function total and therefore unfalsifiable — the compiler can never again tell you a case is
   missing. Safety and exhaustiveness pull against each other, in the same function. → ticket 12.

3. **Variant A is excellent at nine clauses and poor at two.** `HandleCast` writes its own name
   three times in five lines. The table effect that justifies the repetition needs a table.
   Whether most functions are big enough is an empirical question about real code.

4. **`==` is ambiguous and the platform cares.** Erlang has `==` (arithmetic: `1 == 1.0` is true)
   and `=:=` (exact). Every `o.Status == :draft` above silently picks one. C# programmers expect
   exact; C#'s `==` on doubles is arithmetic. → ticket 08 or 11.

5. **The ternary is gone, and it shows.** The legal `RemoveLine` wanted `cond ? a : b` and had to
   use `if`/`return` because `:` is the atom sigil. That is the `:atom` decision's real cost, now
   visible in code rather than described. → ticket 10.

6. **Map literals versus record literals are unresolved.** `{ Orders: #{}, Applied: 0 }` uses
   `{ }` for a record and `#{}` for an empty map in the same expression. Records are maps with
   atom keys, so the language needs one story here, not two syntaxes. → fog.

7. **Signature-to-clause distance is unenforced.** Nothing above stops two hundred lines
   appearing between `Outcome Apply(Order o, Event e);` and its first clause. Erlang requires
   clauses to be contiguous; this syntax should probably require the signature to be too. → 08.

8. **Parameter names in the signature are decorative.** `HandleCall(Request req, From from,
   State s)` names three parameters that no clause uses — every clause rebinds them. Either they
   document intent, or they are a lie the reader has to ignore. → ticket 08.

9. **Arity overloading is free and idiomatic.** `Total/1` and `Total/2` sharing a name is not a
   special case; it is what BEAM identity already means. This one is a genuine win.

### What did not appear

No binary patterns anywhere, again, and this module set would use them in reality — order IDs,
serialisation, anything on a wire. Ticket 04 found binaries are *untheorised* in the
set-theoretic literature. **The largest gap in this design is the one it is not yet possible to
prototype.** → ticket 20.

---

## SUPERSEDED IN PART — ticket 17, 2026-08-13

[Ticket 17](../issues/17-pipeline-and-comprehension.md) changed the surface this prototype is
written against. What is superseded here:

- **Dot-chaining is gone.** `xs.Filter(f).Map(g)` required type-directed resolution of an
  unqualified name — closed by ticket 08 (one arrow per arity, no overload set) and ticket 16 (one
  dispatch mechanism). The chaining form is `|>` with **qualified** names:
  `xs |> List.Filter(f) |> List.Map(g)`. The dot survives only as a candidate for *projection*
  (`o.Total`), which is ticket 26's to settle; it is **never a call**.
- **The three-spelling equivalence loses a member.** `Orders.Apply(o, e)` and
  `o |> Orders.Apply(e)` remain one rewrite. `o.Apply(e)` does not exist.
- **There is no `if`.** `switch` is the only branching construct, taking a **tuple subject** for a
  ladder of unrelated conditions. So any expression-`if` proposed here — including the one-armed
  case ticket 10 routed to 17 — has no spelling. Ticket 17 §6 and
  [`prototypes/17c`](17c_else_in_the_neighbourhood.md) carry the measurement: Gleam refuses `if`
  outright, and `else` is an `if`-only keyword on this platform.
- **There is no comprehension syntax**, and none is needed: ticket 17 §2 measured that the
  precision a comprehension buys is available from the compiler's *lowering* choice instead.

Everything else in this file stands. The patterns, the atom decision, the module structure and the
lowerings are unaffected — only the chaining and branching surface changed.
