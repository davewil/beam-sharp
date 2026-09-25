# 99 — Protocols revisited: may a user's type join `Enum`?

Type: grilling
Status: open — [ENG-451](https://linear.app/davewil/issue/ENG-451). Raised 2026-09-25 by David
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
