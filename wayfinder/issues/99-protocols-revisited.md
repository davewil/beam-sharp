# 99 — Protocols revisited: may a user's type join `Enum`?

Type: grilling
Status: resolved 2026-09-25 — [ENG-451](https://linear.app/davewil/issue/ENG-451). Raised and resolved 2026-09-25 by David, three rounds and ticket 91 Q2
Blocked by: —

## Why this is raised

David, answering ticket 96 Q4: *"We should revisit protocols, losing Enum is a maintenance burden to
double (for now) function surface. Again I wonder why protocols were rejected."*

Ticket 16 refused protocols on 2026-08-12 on two grounds, and three amendments have worn them down:

1. *Dispatch cannot key on a name that is not in the term.* **Withdrawn 2026-08-14**: ticket 26
   put a minted tag in every record, which David said records were introduced for. The refusal
   narrowed to *open* protocols.
2. *Open extension needs whole-program consolidation.* Re-derived 2026-08-27. Hot loading was never
   the ground; it rests on 13 §3, that *"the consistency unit and the deployment unit coincide"*.
   Consolidation makes A's `.beam` depend on B's source. That amendment's leading ground, *"a type
   name does not cross the module boundary"*, was **withdrawn 2026-09-11** when ticket 73 let record
   names cross `using`.

So one ground stands, 13 §3, and it is a ground against **consolidation**, not against protocols.
Elixir runs protocols unconsolidated too, dispatching on the value at run time. A B# record's tag
already names the module that declared it (`:'Shop.Tree.Node'`). An implementation that must live
in the type's own module is therefore found from the tag, with no table built across modules.

Ticket 96 Q5 gives `Enum` over `list` and `map` without any of this. This ticket is what it would
take for a user's type to join.

## Round 1

**Q1. May a record's own module declare that it implements a compiler-known protocol, with a call
dispatched at run time from the value's tag to that module, and no consolidation?**

```csharp
module Shop.Tree

record Node { Value: int, Kids: list<Node> }

implements Enumerable<int> for Node {
    Reduce(Node n, acc, f) -> List.Fold(n.Kids, f(acc, n.Value), (a, k) => Reduce(k, a, f))
}

// in any module with `using Shop.Tree`
public int Total(Node tree)
Total(t) -> Enum.Sum(t)
```

Today `implements` is not a word the language has. Under yes this compiles. `Enum.Sum` over `Node`
emits a call to `'Shop.Tree':'bs@Enumerable@Reduce'/3`, found from the tag the record carries, so
`Total`'s module depends on nothing but its own source and `Shop.Tree`'s exports. 13 §3 holds.
Under no, `Enum` stays over the compiler's collections only (ticket 96 Q5), and a user's type
becomes a list first (`Enum.Sum(Tree.ToList(t))`).

Compiler delta: an `implements P for T` declaration, allowed only in the module that declares `T`;
the protocol's signatures, compiler-known for `Enumerable` (the one `Enum` needs); the checker
accepts `T` where `Enum` takes a collection when `T`'s module exports the implementation; the
emitter writes the `bs@`-prefixed export (ticket 87 set the precedent for an export the author did
not name) and, at a call, a remote call whose module is read from the tag.

What the answer leaves for later rounds: whether a user may declare a protocol of their own (it
meets ticket 91's user-declared behaviour), and what a function taking "any `Enumerable`" is typed
as, since the set of implementations is open and exhaustiveness cannot range over it.

**Round 1 answered 2026-09-25 (David): Q1 yes.** A record's own module may implement a compiler-known
protocol, and a call finds the implementation from the value's tag at run time. Nothing is
consolidated, and 13 §3 holds.

## Round 2

**Q2. What is a parameter that takes "anything `Enumerable`"?**

```csharp
public int Total(Enumerable<int> xs)
Total(xs) -> Enum.Sum(xs)

// callers
Total([1, 2, 3])         // a list
Total(tree)              // a Shop.Tree.Node, which implements it
```

Proposed: a protocol's name is a type whose members are `list`, `map` (where the protocol covers
them) and every record whose module implements it. The set is open, so a clause head may not
destructure an `Enumerable<int>`, and exhaustiveness is never asked over it. Inside `Total`, the
protocol's operations are the only thing it can do. Where the argument's type is known at the call
(`Node`), the checker emits the direct call; only here, where it is not, is the dispatch read from
the value (`is_list`, `is_map`, else the tag's module). Under no, a function takes one concrete
collection type and the caller converts.

**Q3. May a user declare a protocol of their own, or are protocols compiler-known only?**

```csharp
module Shop.Geometry

protocol Shape {
    float Area(Self s)
}

// module Shop.Geometry.Circle
record Circle { R: float }
implements Shape for Circle {
    Area(Circle c) -> 3.14159 * c.R * c.R
}
```

Under yes, `protocol` is a declaration, and its operations are called as `Shape.Area(c)`, dispatched
on the tag as `Enumerable` is. It meets ticket 91 (ENG-432), a user-declared behaviour: a behaviour
names what a *module* supplies, and a protocol names what a *type's* module supplies. Under no,
`Enumerable` and any others are the compiler's, and a user's open extension is ticket 91's
behaviour or nothing.

**Round 2 answered 2026-09-25 (David): Q2 yes, Q3 yes.**

- **Q2.** `Enumerable<T>` is a type: `list`, `map`, and every record whose module implements it. The
  set is open, so a clause head may not destructure it and exhaustiveness never ranges over it.
  Only the protocol's operations apply. A call whose argument type is known is emitted direct, and
  only an `Enumerable<T>` parameter dispatches at run time.
- **Q3.** A user may declare a protocol (`protocol Shape { float Area(Self s) }`), dispatched on the
  tag as `Enumerable` is. Its spelling is decided beside ticket 91's user-declared behaviour, so
  the two declarations read alike.

## Round 3

**Q4. May an implementation live anywhere but the type's own module?**

```csharp
// module Shop.Reports, not the module that declares Node
implements Enumerable<int> for Shop.Tree.Node { … }      // refused under the round 1 rule
```

Round 1 put an implementation in the type's own module, which is what lets the tag find it. Under
that rule, a type you did not write cannot join a protocol, including a foreign struct (ticket 50
made one a `map<atom, term>`, which has no tag module) and a tuple. Proposed: **no, own module only**,
and a type from elsewhere joins by being wrapped in a record of your own. Under yes, the tag no
longer finds the implementation, so a table is needed, and ticket 13 §3's consolidation comes back.

**Q5. Which protocols does the compiler ship beside `Enumerable`?**

Proposed: **only `Enumerable`**, since it is the one a program here needs, and the others Elixir has
(`String.Chars`, `Inspect`, `Collectable`) wait for a program that wants them, each as its own
question. Ticket 97's conversions are total functions over known types and need no protocol.

**Round 3 answered 2026-09-25 (David): Q4 no, Q5 yes.**

- **Q4.** An implementation lives in the type's own module and nowhere else. A type from elsewhere,
  a foreign struct or a tuple, joins by being wrapped in a record of the author's own.
- **Q5.** The compiler ships `Enumerable` only. `String.Chars`, `Inspect` and `Collectable` wait for
  a program that wants them, each as its own question.

What remains is the spelling of `protocol` and `implements`, decided beside ticket 91 (ENG-432) so
that a protocol and a user-declared behaviour read alike.

**The spelling is asked as ticket 91 round 2, Q2**, after David answered 91 Q1 yes on 2026-09-25:
one declaration shape for a behaviour and a protocol.

**The spelling was answered 2026-09-25 as ticket 91 Q2 (David, yes):** `protocol Shape { float
Area(Self s) }` in `index.bs`, satisfied by `implements Shape for Circle { … }` in the type's own
module, and called as `Shape.Area(c)`, never `c.Area()`. The frontier is empty.

## Decisions entry

```decisions-entry
- **Protocols revisited** — [ticket 99](issues/99-protocols-revisited.md), raised and resolved
  2026-09-25 by David, amending [ticket 16](issues/16-ad-hoc-polymorphism.md). **A record's own
  module may implement a protocol, and a call finds the implementation from the value's tag at run
  time, so nothing is consolidated and ticket 13 §3 holds.** Of 16's two grounds, the first went
  2026-08-14 (records carry a tag). The second stood only on 13 §3, which is a ground against
  consolidation and not against protocols. An implementation lives in the type's own module and
  nowhere else; a foreign struct or a tuple joins by being wrapped in a record. `Enumerable<T>` is
  a type (`list`, `map`, every implementing record), open, so a clause head may not destructure it
  and exhaustiveness never ranges over it; only such a parameter dispatches at run time. A user may
  declare a protocol, `protocol Shape { float Area(Self s) }`, satisfied by `implements Shape for
  Circle { … }` and called `Shape.Area(c)`, never `c.Area()` (ticket 91 Q2 and Q3: the dot would
  suggest OOP semantics). The compiler ships `Enumerable` only.
```
