# F64 — `implements Enumerable<int> for Node { … }`: a record's own module implements a protocol

**Status**      **done 2026-09-28** · [ENG-458](https://linear.app/davewil/issue/ENG-458) — 27 tests in `implements_tests`, 1228 in the suite; the first 13 seen red before the build, F64.13–14 red on the defect, F64.15–22 red on the first cut where the review measured it, and F64.19's wording and F64.23–24 red on the second cut where the second review did; a
                must-compile block and a `diagnoses: protocol_not_implemented` block in
                LANGUAGE.md §6, both seen red first
**Implements**  [ticket 99](../../wayfinder/issues/99-protocols-revisited.md) Q1 and Q4, with the
                block spelled by [ticket 91](../../wayfinder/issues/91-a-user-declared-behaviour.md)
                Q2. Decides nothing
**Closes**      [ENG-458](https://linear.app/davewil/issue/ENG-458), as split on 2026-09-28
**Depends on**  F46 (a function as a value: `f` is called in the block), F62 (the qualified
                call's shape, which a protocol call shares), F45 (polymorphic signatures)
**Fixes**       a defect found building F64.1: a recursive record could not name a type-prefix
                pattern (`Top(Node n)` over `record Node { …, Kids: list<Node> }` was refused as
                *not a record*), in `bs_check:record_of/3` and `bs_emit:record_tag/2`, both of
                which now unfold the binder once. The same fault left a public function over a
                recursive record without its boundary guard, so an untagged map ran as the
                record; `check-recursive-types.sh`'s R3 had been passing one, and now passes a
                tagged `Node`
**Leaves**      `Enumerable<T>` as a parameter type and `Enum` over an implementing record, which
                is [ENG-566](https://linear.app/davewil/issue/ENG-566), behind ENG-453; a
                user-declared `protocol` and `Self` in source, which is
                [ENG-459](https://linear.app/davewil/issue/ENG-459); `Formattable`, which is
                [ENG-565](https://linear.app/davewil/issue/ENG-565), behind ENG-562; the
                tree-sitter grammar for the block; `--api` listing a module's
                implementations (its stdout contract is F17's), where today only
                the empty-module message on stderr names them; and advice written for
                `Enumerable` alone — `protocol_type_args` and `protocol_not_implemented`
                say *"where T is the type of the elements it folds"*, which a protocol
                with no type parameter, such as `Formattable`, makes false

## The program

```csharp
module Shop.Tree
record Node { Value: int, Kids: list<Node> }
implements Enumerable<int> for Node {
    Reduce(Node n, acc, f) -> List.Fold(n.Kids, f(acc, n.Value), (a, k) => Reduce(k, a, f))
}

// module Shop.Report, with `using Shop.Tree`
public int Total(Node t)
Total(t) -> Enumerable.Reduce(t, 0, (a, v) => a + v)
```

## The rule

- `Enumerable<T>` is compiler-known, with one operation:
  `TAcc Reduce<TAcc>(Self s, TAcc acc, fn(TAcc, T) -> TAcc f)`. Ticket 99 decided the protocol
  and left its signature to the build. This one is read off 99 Q1's own program: the block folds
  with `f(acc, n.Value)` and returns the accumulator.
- An `implements P for T { … }` block holds clauses only, and the protocol supplies their
  signature (91 Q2), with `Self` as `T` and `T` bound by the written type argument. It is refused
  outside the module that declares the record `T` (99 Q4), for a protocol the compiler does not
  know, for a wrong number of type arguments, for an operation the protocol lacks, and when an
  operation is missing (91 Q5: nothing is optional).
- Inside the block, a call to the operation's own name is the implementation itself, so ticket 99's
  recursive `Reduce(k, a, f)` works. The implementation is exported as
  `'bs@Enumerable@Reduce@Node'/3`, an export the author did not write, on ticket 87's precedent.
  Ticket 99's delta wrote `'bs@Enumerable@Reduce'/3`, the one-record case. The record's name is in
  the export because a module may implement a protocol for two records at different element
  types, and one merged function would carry one signature for both, so each block's element type
  would be checked against both. `--api` publishes no `bs@` name, and a diagnostic, including one
  about a call to the implementation, names the operation as written.
- `Enumerable.Reduce(v, acc, f)` is typed as `List.Fold` is. Over one implementing record it is a
  direct remote call to the record's module. Over a union of implementing records it is a `case`
  on the tag, to each member's module. Each member must be a subtype of the implementing record,
  so a value wearing the tag without the record's fields is not dispatched on. A record whose
  module does not implement the protocol is refused at the call (`protocol_not_implemented`),
  naming the `implements` line it lacks.
- The block holds clauses, and `index.bs` holds none (F15), so an `implements` in `index.bs` is
  refused as a function is.
- A protocol's name qualifies its operations as a reserved qualifier does, so a module may not take
  it (`reserved_module_name`).

What the build read that no ticket spelled. On 2026-09-28, reviewing ENG-458, David accepted `for`
as a keyword, the block's naming (the first two bullets) and the per-record export name (the
last), and they are recorded in [ticket 99](../../wayfinder/issues/99-protocols-revisited.md)'s
Decisions entry. Shown the three refusals in the third bullet, he kept them, with merging a
second block deferred there:

- `for` is now a keyword, as it is in C#. No `.bs` file in the repository used it as a name.
- Inside a block, an operation's own name is the implementation, so a module function of the same
  name and arity is not reachable from inside the block under that name. A different written
  arity still reaches the module's function (`Reduce/2`, F64.24). Outside the block the name is
  the module's function, and nothing refuses a module function sharing the operation's name.
- `implements_duplicate`, `implements_op_arity` and `protocol_type_args` refuse the malformed
  blocks the tickets did not list.
- **The export is named per record: `'bs@Enumerable@Reduce@Node'/3`.** ENG-458 wrote
  `'bs@Enumerable@Reduce'/3`, and ticket 113's delta, which ENG-565 builds from, writes
  `bs@Formattable@ToString/1`; both predate this scheme. No B# program compiles or is refused
  differently under either name, since `--api` and every diagnostic hide it; it is visible to
  Erlang callers and stack traces, the outbound ABI that ticket 62 holds open. The one-name
  alternative is buildable: check each block against its own signature, then emit the blocks'
  clauses as one function, which a same-module union would reach by one remote call instead of
  a `case`.

## Scenarios

| Id | Scenario | Expected |
|---|---|---|
| F64.1 | ticket 99's tree, folded by a caller in another module | compiles, and `Demo` returns the sum, `10` |
| F64.2 | the implementing module and the caller, emitted | `Shop.Tree` exports `'bs@Enumerable@Reduce@Node'/3`; the caller makes a remote call to it |
| F64.3 | `--api` on the implementing module | no `bs@` name is published |
| F64.4 | `implements` for a record declared in another module | refused: not a record this module declares |
| F64.5 | `implements Shape for Circle`, a protocol the compiler does not know | refused, naming the protocols it knows |
| F64.6 | a block with an operation the protocol lacks, and an empty block | refused: `Count is not an operation of Enumerable`; `without Reduce` |
| F64.7 | `implements Enumerable for Leaf`, no type argument | refused: `Enumerable takes 1 type argument` |
| F64.8 | a block clause that passes `f` a string | refused, and the diagnostic names `Reduce`, never `bs@` |
| F64.9 | `Enumerable.Reduce` over a union of two implementing records | dispatches on the tag: `507` |
| F64.10 | `Enumerable.Reduce` over a record with no implementation | refused as `protocol_not_implemented`, naming the missing `implements` |
| F64.11 | `Enumerable.Count(t)` | refused: `Count is not an operation of Enumerable` |
| F64.12 | an `implements` block in `index.bs` | refused as a function in `index.bs` |
| F64.13 | `Top(Node n)` over a recursive record, no protocol involved | compiles and returns `7`; it was refused as *not a record* |
| F64.14 | an untagged `#{value => 1, kids => []}` passed to a public function over a recursive record | refused at the boundary, `function_clause`; it used to run |
| F64.15 | a hand-written `{ Kind: :'Q.Leaf', Name: string }`, and a tagged open field set, passed to `Enumerable.Reduce` | refused: no record that implements `Enumerable`; the first cut dispatched on the tag and crashed with `badkey` |
| F64.16 | a recursive call with its arguments swapped, and a guard calling `Reduce` | refused, and neither diagnostic prints `bs@` |
| F64.17 | a second block for one record; an operation of the wrong arity; `Enumerable.Reduce` over `term` | `a second time`; `takes 3 parameters, and this clause has 2`; `on term, which is no record that implements Enumerable` |
| F64.18 | `implements Enumerable<int> for Shop.Leaf.Leaf`, ticket 99 Q4's own spelling | parses, and is refused as not a record this module declares |
| F64.19 | `module Enumerable` | refused as a reserved module name, saying it is a protocol; the first cut gave a reserved qualifier's reason, *inlines at the site*, which a protocol call is not |
| F64.20 | `bsc --api` over `implements Enumerable<Nope>`, and over the tree module | the first refused as a compile refuses it; the second names `Enumerable for Node` and does not advise marking functions `public` |
| F64.21 | three of the new diagnostics on the term channel, in `--batch` and standalone | byte-identical (ENG-349's hazard; the keys are atoms no other module names) |
| F64.22 | `Reduce` passed as a value inside the block, with a return that does not fit | the name is the implementation; the return refusal withholds a signature because the protocol declares it |
| F64.23 | `implements Enumerable<atom \| :ok> for Leaf`, in a compile and in `--api` | refused: `` `:ok` is absorbed by `atom` `` in `Enumerable<T>`; the first cut compiled it and ran |
| F64.24 | `Ap(Reduce/2, l.Value)` inside the block, beside a module function `Reduce/2` | compiles and returns `10`: a written arity other than the operation's names the module function; the first cut renamed it to the implementation and refused the call |
