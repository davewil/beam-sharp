# PROTOTYPE 25e — exemplar: a dynamic web page (server-rendered HTML)

> **Throwaway.** Ticket [25](../issues/25-exemplar-programs.md), exemplar 5 of 6.
> Written against the surface as it stands after F27 (2026-08-26).
> The lowering is [`25e_page_lowering.erl`](25e_page_lowering.erl) and it **compiles with no
> warnings and runs on OTP 28**; its output is checked by parsing the rendered page with
> **`xmerl`**, so an escaping failure is a red rather than something a reader has to spot.
> The compiler measurements are [`25e_surface_probe.sh`](25e_surface_probe.sh). Everything
> claimed below was executed.

The last of ticket 25's six that meets **binary construction in expression position** — 25c's
current wall — and the one 17 job 2 nominated as its remaining binary-accumulation case.

**It did not get that far.** This exemplar is stopped by its own *type*, three lines into
`index.bs`, and it is the first of the five to be stopped by the **checker** rather than the
parser. The other four all die in the lexer or the grammar on a construct the language has not
grown. 25e dies on a construct the language has **decided** and the algebra cannot hold:

```csharp
type Iodata = binary | list<Iodata>
```

That is `iodata`. It is what every BEAM web stack passes to the socket, what `cowboy_req:reply/4`
takes, what `iolist_to_binary/1` consumes. A page is a tree of fragments, and the tree is
**recursive**. [LANGUAGE.md §"recursive types"](../../LANGUAGE.md) records the decision —
equirecursive and contractive, [ticket 09](../issues/09-union-representation.md) — and refuses it
by name, with a diagnostic that says so in as many words:

```
error: Iodata is a recursive type, and those are not built yet
  the definition is well formed -- the recursion passes through a
  constructor, so it describes a real set of values. The checker's
  algebra has no binder to hold it with, which is a gap in this
  compiler rather than a mistake in your type.
```

**So the finding arrives before the program does.** Four exemplars asked for constructs; this one
asks for a *binder*, and it is the first evidence outside `type Tree = :leaf | (:node, Tree, Tree)`
that recursion is not a textbook example the language can defer. The shape a web page has is the
shape the algebra cannot hold.

---

## The layout

```
lib/shop/page/                     ← compiles to ONE beam: Shop.Page
  index.bs        module, types, foreign declarations
  escape.bs       HTML escaping — the one function that must not be wrong
  rows.bs         the repeated section, one <tr> per order
  layout.bs       the page shell, a conditional section, an optional one
  render.bs       assembly, Content-Length, the response
```

**This is the first exemplar to declare a `module`**, and declaring it is *not* enough. The other
four do not, which [ticket 25 logged on 2026-08-17](../issues/25-exemplar-programs.md) and
deliberately left unfixed: naming them is one decision across all four, and their directory names
are dialect-illegal besides.

That second clause is the one that bites. F15 makes the declaration and the path the same name
written twice, so `module Shop.Page` inside a directory called `25e-dynamic-web-page` is:

```
error: `module Shop.Page` does not match its directory
  this directory says `module M`
```

Measured. So the declaration clears 25d's wall and lands on the next one, and **the exemplar
directories cannot compile under any module name while they are named after ticket numbers.** The
25e write-up ships the declaration anyway, because the write-up is the canonical program and
`lib/shop/page/` is where it would live; the extracted copy is what the frontier gate measures, and
it is measuring a tree the language cannot name. → ticket 25's 2026-08-17 note, which now has a
second half.

---

## `index.bs`

```csharp
module Shop.Page

// THE TYPE THIS WHOLE EXEMPLAR IS ABOUT. Refused: recursive, well formed,
// unbuilt. Everything below is written as if it existed, because writing it
// any other way would be writing a different program to flatter the compiler —
// which is the failure 25a recorded when it constructed its own evidence.
type Iodata = binary | list<Iodata>

using :erlang {
    int    iolist_size(Iodata d)
    binary iolist_to_binary(Iodata d)
    binary integer_to_binary(int n)
}

using :binary {
    // The escape hatch §"escape.bs" is about. One call per unescaped byte.
    binary encode_unsigned(int n)
}

type OrderStatus = :placed | :shipped | :cancelled

record OrderRow {
    Id: int, Customer: string, TotalCents: int, Status: OrderStatus
}

record PageModel {
    Title: string, Orders: list<OrderRow>, Note: option<string>, IsAdmin: bool
}

type Header   = (binary, binary)
type Response = (int, list<Header>, Iodata)
```

Three declarations carry findings before a single function is written.

**`Iodata` is the exemplar.** Its refusal is measured in
[`25e_surface_probe.sh`](25e_surface_probe.sh) §1, and it is worth being precise about *which*
refusal: LANGUAGE.md distinguishes two, and this is the well-formed one. The recursion passes
through `list<…>`, a constructor, so the definition describes a real set of values and the refusal
is the compiler's gap rather than the author's error. The diagnostic says exactly that, unprompted,
which is [ticket 23](../issues/23-what-the-language-owes-an-agent.md) working: the message
distinguishes "not yet" from "never" without being asked.

**The three `:erlang` declarations all take or return `Iodata`, so all three are unreachable
today.** That is not incidental. `iolist_size/1` is how a page gets a `Content-Length`, and there
is no other way — §`render.bs` returns to this.

**`PageModel.Note` is `option<string>`, and `option<T>` is `T | :nothing` with no tag.**
Measured. So the pattern a C#, Rust or F# reader writes first —

```
Note((:some, s)) -> ["<p>", s, "</p>"]
```

— matches no value of `option<string>` at all. Until 2026-08-27 **the diagnostic for that was
false**: it reported `clause 1 of Note is unreachable — every value it matches is matched by an
earlier clause`, when clause 1 has no earlier clause, and sent the author looking for a shadowing
clause that does not exist. Fixed in `95225ff`; it now reports `clause 1 of Note matches no value
of its input` and names the declared input. §"A diagnostic that names the wrong cause" below has
the controls and the issue number.

---

## `escape.bs`

The function a web page cannot get wrong. It is also the one this language currently writes worst,
and the two facts are the same fact.

```csharp
// HTML escaping.
//
// TAKES a `string` and RETURNS `list<binary>`, and the asymmetry is forced.
// `string` is `binary where valid_utf8` (ticket 20 §4), and taking one byte off
// a UTF-8 binary does NOT leave a UTF-8 binary — chop a byte off a multi-byte
// codepoint and the remainder is invalid. So the checker types the tail of
// every binary pattern as `binary \ string` and refuses the recursive call.
//
// It is right to. The consequence is that a character-level loop over a
// `string` cannot be written, the loop must widen to `binary`, and F9 records
// that the way back has no spelling — deliberately, because it costs an O(n)
// validity scan. The page is a `binary` from here outward.
public list<binary> Escape(string s)

Escape(s) -> Walk(s, [])

private list<binary> Walk(binary s, list<binary> acc)

// The base case. `<<>>` does not parse — `bin_segments` in the grammar is
// one-or-more, so the empty binary has no production. `<<"">>` is the spelling,
// via the string-literal segment, and it works. A wart, not a wall.
Walk(<<"">>, acc)           -> ReverseParts(acc, [])
Walk(<<0x26:8, rest>>, acc) -> Walk(rest, ["&amp;", ..acc])
Walk(<<0x3C:8, rest>>, acc) -> Walk(rest, ["&lt;", ..acc])
Walk(<<0x3E:8, rest>>, acc) -> Walk(rest, ["&gt;", ..acc])
Walk(<<0x22:8, rest>>, acc) -> Walk(rest, ["&quot;", ..acc])
// AND HERE IS THE COST. `c` is an int the segment refined to 0..255. To put it
// back on an iodata list it must become a one-byte binary, and the construct
// for that — `<<c:8>>` in expression position — does not exist: F13 built the
// consuming direction only, and F13 itself records that "building a binary from
// parts has no decision behind it yet". The only working spelling is a foreign
// call, once per unescaped byte.
Walk(<<c:8, rest>>, acc)    -> Walk(rest, [:binary.encode_unsigned(c), ..acc])
// A trailing partial byte. `_` over a binary is always legal (ticket 30) and
// absorbs silently — so this clause is where malformed input goes, and the
// compiler will never ask for it.
Walk(_, acc)                -> ReverseParts(acc, [])

// NOT `Reverse`. `rows.bs` needs the identical function over `list<Iodata>`,
// a module is ONE beam, and two signatures of the same arity are one function
// declared twice — so the two monomorphic copies COLLIDE and the compiler
// refuses the module. Finding 8; the names are invented to get around it.
private list<binary> ReverseParts(list<binary> xs, list<binary> acc)

ReverseParts([], acc)          -> acc
ReverseParts([x, ..rest], acc) -> ReverseParts(rest, [x, ..acc])
```

**This compiles and runs today** — §`escape.bs` is the only file of the five that does, once
`Iodata` is out of the way, and the probe runs it: `Escape("a<b&c")` gives
`["a", "&lt;", "b", "&amp;", "c"]`. Correct. And it makes one FFI call per ordinary character.

**Drop the foreign call and the escaper deletes the text it was protecting.** Write
`Walk(rest, acc)` instead — the obvious thing, when there is no way to put `c` back — and
`Escape("a<b&c")` returns `["&lt;", "&amp;"]`. Measured. The letters are gone. *That line is the
author's, not the compiler's*: the language forces a choice between dropping the byte and paying a
foreign call for it, and it is the absence of the third option that is the finding. But the wrong
branch of that choice is the one that type-checks, runs, and looks fine on a page with no `&` in it.

**What the language actually wants here is not per-byte at all.** An escaper should bind the *run*
of safe bytes and copy it whole — one segment, not one call per character. That needs a segment
sized by a bound variable in a clause head, which [ticket 30 §1 resolved](../issues/30-binaries-as-a-parsing-grammar.md)
as **erased** — `payload:size` runs and yields a `binary`. Measured here: it does not parse in a
head at all (`syntax error before: '<<'`), because binding `n` and using it in the same head is not
something the grammar admits. So the fast spelling is out twice over.

→ tickets 20, 30, 09; F13's own out-of-scope note.

---

## `rows.bs`

The repeated section, and the arithmetic every shop page does.

```csharp
private Iodata Rows(list<OrderRow> orders, list<Iodata> acc)

Rows([], acc)          -> ReverseRows(acc, [])
Rows([o, ..rest], acc) -> Rows(rest, [Row(o), ..acc])

private Iodata Row(OrderRow o)

Row(o) -> ["<tr><td>", :erlang.integer_to_binary(o.Id),
           "</td><td>", Escape(o.Customer),
           "</td><td>", Money(o.TotalCents),
           "</td><td>", Status(o.Status),
           "</td></tr>"]

// Cents to pounds. F26 shipped `/` and `%`, so this is expressible — and it is
// the one place in the exemplar where the language does the ordinary thing
// without complaint.
private Iodata Money(int cents)

Money(cents) -> ["£", :erlang.integer_to_binary(cents / 100),
                 ".", Pence(cents % 100)]

// The two-digit pad. There is no formatting anywhere in the language, so it is
// a clause head — which is, to be fair, exactly what this language is for.
//
// AND IT IS A GUARD, NOT A RELATIONAL PATTERN, because `Pence(<= 9)` binds no
// name and the body needs the value. Measured: `F(<= 9) -> n` is
// "F uses n, which nothing binds", while the same pattern with the value
// unused compiles. There is no as-pattern in any spelling. See finding 5.
private Iodata Pence(int p)

Pence(p) when p <= 9 -> ["0", :erlang.integer_to_binary(p)]
Pence(p)             -> :erlang.integer_to_binary(p)

// A closed union renders as a total function with no catch-all. This is the
// design at its best and it is worth saying so: three statuses, three clauses,
// add a fourth to `OrderStatus` and the compiler names this function.
private Iodata Status(OrderStatus s)

Status(:placed)    -> "placed"
Status(:shipped)   -> "shipped"
Status(:cancelled) -> "cancelled"

// The same six tokens as `escape.bs`'s `ReverseParts`, with one word of the
// signature changed — and a name invented purely so the two can coexist.
private list<Iodata> ReverseRows(list<Iodata> xs, list<Iodata> acc)

ReverseRows([], acc)          -> acc
ReverseRows([x, ..rest], acc) -> ReverseRows(rest, [x, ..acc])
```

**The two `Reverse`s collide, and the module system makes that an error rather than duplication.**
`escape.bs` wants one over `list<binary>`, this file wants one over `list<Iodata>`. A module is a
directory that compiles to one beam, so the compiler refuses outright:

```
error: Reverse/2 is declared more than once
  a name may carry MORE THAN ONE ARITY, so Reverse/2 and Reverse/3 would
  be two functions — but two signatures of the SAME arity are one
  function declared twice, and its clauses would merge silently.
```

Measured. So the workaround for a missing generic is **not** "write it twice" — it is "write it
twice under invented distinct names", `ReverseParts` and `ReverseRows`, neither of which describes
anything but the type it was cloned for. → [ticket 37](../issues/37-instantiation-by-matching.md);
third sighting after 25d's `Prepend`, and the first where the language *refuses the duplicate* and
so forces the naming.

**`Money` is the only comfortable function in the exemplar.** Worth recording, because a friction
list that finds nothing good is not measuring. F26's `/` and `%` land exactly where a real page
needs them, and `Pence`'s two clauses are a formatting rule expressed as dispatch rather than as a
format string — which is the language's argument, made without effort.

**`Row` returns a nested list, and that is the whole reason `Iodata` must be recursive.** Flatten it
by hand and the type is `list<binary>`; nest it once — which `Rows` does, because a row is a
fragment and a page is a list of rows — and the checker computes the union exactly:

```
not covered by the declared return type:
    [list<string>, ..] | [string, ..]
```

Measured. **The checker gets the type right and cannot be told it.** The algebra computes the
heterogeneous list precisely; naming it is what needs the binder. That is a sharper statement of the
gap than "recursive types are unbuilt", and it is the one an implementer wants: the work is a
*binder*, not a lattice.

→ tickets 09, 37, 17.

---

## `layout.bs`

The shell, and the two shapes every template has.

```csharp
public Iodata Layout(PageModel m)

Layout(m) -> ["<!doctype html><html><head><title>", Escape(m.Title),
              "</title></head><body><h1>", Escape(m.Title), "</h1>",
              Note(m.Note),
              AdminLink(m.IsAdmin),
              "<table>", Rows(m.Orders, []), "</table>",
              "</body></html>"]

// AN OPTIONAL SECTION. `option<T>` is `T | :nothing`, untagged — so the
// `:nothing` clause comes FIRST and the bound clause is the residual. Write it
// the other way, or write `(:some, s)`, and see §"A diagnostic that names the
// wrong cause".
private Iodata Note(option<string> n)

Note(:nothing) -> []
Note(s)        -> ["<p class=\"note\">", Escape(s), "</p>"]

// A CONDITIONAL SECTION, which is two clauses because there is no `if`
// (ticket 17 §6). It reads well. `[]` as the empty fragment is iodata's own
// identity element and needs no special case anywhere.
private Iodata AdminLink(bool isAdmin)

AdminLink(true)  -> ["<a href=\"/admin\">admin</a>"]
AdminLink(false) -> []
```

**The empty fragment is `[]` and it costs nothing.** No `option<Iodata>`, no sentinel, no
`""`-versus-null question: an absent section is an empty list and the flattener does the rest. This
is the one place iodata's recursion *pays* rather than costs, and it is why the type is worth the
binder.

**`Note` is where the false diagnostic bites**, because `option<T>` being untagged is not what a
reader arrives expecting and the compiler's reply to the expected spelling is untrue.

**No `|>` and no `|?>` anywhere in this exemplar, which is the second sighting of 25a's note.**
25a recorded that request handling is dispatch and never a pipeline; rendering is *composition* —
`Layout` calls `Rows` calls `Row` calls `Escape` — and a pipeline is a chain over one value. The
valve is for fallible stages and rendering has none: a page cannot fail. Four exemplars used
`|?>`; the two that did not are the two that are not moving a value through stages.

→ tickets 17, 09.

---

## `render.bs`

Assembly, and the one number a response cannot be sent without.

```csharp
public Response Render(PageModel m)

Render(m) -> Respond(Layout(m))

private Response Respond(Iodata body)

// `iolist_size/1` is the Content-Length, and it is a foreign call over the
// recursive type. There is no builtin: `ByteSize` does not exist, and the
// language has no size operator of any kind — measured, the name resolves to
// nothing and the diagnostic is "which nothing declares".
Respond(body) -> (200,
                  [("content-type", "text/html; charset=utf-8"),
                   ("content-length", :erlang.integer_to_binary(:erlang.iolist_size(body)))],
                  body)
```

**Every byte-counting and byte-joining operation in this exemplar is foreign.**
`iolist_size/1`, `iolist_to_binary/1`, `integer_to_binary/1`, `binary:encode_unsigned/1` — four
declarations, and between them they are the entire mechanism by which the page becomes bytes. The
language contributes the dispatch and none of the plumbing. That is a defensible place to be, and
[LANGUAGE.md puts string operations behind the module system](../../LANGUAGE.md) rather than
nowhere — but it should be recorded that a web page is **100% FFI at the boundary and 0% in the
middle**, where 25d's database work was the reverse.

**And `+` is not the escape.** A reader coming from C# writes `a + b` to join two strings. It
type-checks — `e_op` synthesises `int` for arithmetic whatever its operands are — and crashes at run
time with `badarith`. See §"`+` over two strings is a priced decision" below.

→ tickets 33, 16, 20.

---

## What is behind the wall

`bsc` stops at the first error, so a wall hides everything behind it — 25a's four hidden defects are
why this section exists at all. Measured the same way: a scratch copy, rooted at `Shop/Page` so the
path matches the declaration, with `Iodata` replaced by a stand-in.

**With `type Iodata = list<binary>` — a flat one-level stand-in — eight errors appear**, and every
one of them is a nested return the flat type cannot hold: `Layout`, `Note`, `Rows`, `Row`, `Money`
and `Status` all fail on `[list<binary>, ..] | [string, ..]` or a variant of it. They are the
recursive type doing its job, not independent findings.

**With `type Iodata = term` — a stand-in that admits everything — exactly one error survives**, and
it is `Pence` at finding 5. That is the measurement worth keeping: **behind the recursive-type wall
there is one genuine defect in the whole module and it is a pattern-binder gap.** The program is
otherwise written in a language this compiler already has.

So 25e is not a program blocked on a dozen missing things. It is a program blocked on exactly one
missing thing, which happens to be the type of every value it produces.

---

## What writing this actually surfaced

Ten, in the order they cost time.

### 1. A web page is a recursive type, and the algebra has no binder

The headline, and the first time an exemplar has been stopped by the checker. `iodata` is
`binary | list(iodata)` in Erlang's own type language, it is the argument type of every BEAM web
stack's reply function, and it is refused by name. Recursion is **decided** — equirecursive,
contractive, ticket 09 — so this exemplar tests an answer rather than inventing one, which is
ticket 25's own condition for being worth writing.

**What makes it more than "an unbuilt feature" is §`rows.bs`'s measurement:** the checker already
computes the exact heterogeneous type (`[list<string>, ..] | [string, ..]`) and simply cannot be
handed a name for it. The work is a binder in the type environment, not new machinery in the
lattice. → **ticket 09**, and it wants a line in the map's "not yet specified" index that names
`iodata` rather than `Tree`.

### 2. `string` is not closed under binary decomposition

The tail of a binary pattern over a `string` is typed `binary \ string`, so the recursive call is
refused. Measured at 8 bits and at 32, so it is the refinement and not the width; the control over
a bare `binary` type-checks. This is **correct** — ticket 20 §4 makes `string = binary where
valid_utf8` and a byte off a multi-byte codepoint leaves invalid UTF-8 — and the consequence is
that **no character-level loop over a `string` can be written at all.** Widen to `binary`, and F9
records the way back is deliberately unspelled.

So HTML escaping cannot return a `string`, and the page is a `binary` from the escaper outward. A
refinement that is sound and a traversal that is ordinary do not compose, and this is the first
program to need both. → **tickets 20, 09**.

### 3. Without binary construction the only escaper the language admits is one FFI call per character

`<<c:8>>` in expression position does not parse — F13 built the consuming direction and says so.
`:binary.encode_unsigned/1` works and is measured correct end to end. The alternative — dropping
the byte — also compiles, also runs, and silently deletes every unescaped character.
**Binary construction has no decision behind it**, and this exemplar is the case for making one:
not because a WebSocket frame needs it (25b, 25c) but because the language's most
security-sensitive ordinary function is unwritable without it. → **F13's out-of-scope note; a
ticket is owed.**

### 4. `<<>>` has no production; `<<"">>` is the empty binary

`bin_segments` is one-or-more in `bs_parser.yrl:410`, so the base case of every binary loop has no
literal spelling. The string-literal segment supplies one and it works. A wart with a workaround —
recorded because the workaround is not guessable and the diagnostic (`syntax error before: '>'`)
does not suggest it. → **F13**.

### 5. A relational pattern binds nothing, and there is no as-pattern in any spelling

`Pence(<= 9) -> ["0", integer_to_binary(p)]` is `error: Pence uses p, which nothing binds`. The
control — the same pattern with the value unused, which is `Wire.Classify`'s shape and the only
shape the corpus had — compiles. So the gap is precise: **a relational pattern can test a value or
you can name it, never both.** The guard spelling works and is what the exemplar ships.

Three spellings of the missing capability were tried and none exists: `p @ <= 9` (`illegal
characters "@"`), the C# postfix `<= 9 p` (`syntax error before: p`), and no other candidate is
suggested by any diagnostic.

**This is the second sighting of the same hole.** 25c's recorded frontier is `Frame { … } f` —
destructure-and-bind, where the write-up notes `p_alias` has no surface. Different pattern kind,
same missing binder, and now from two exemplars. → **tickets 42, 08**, and it wants naming as one
capability rather than two.

### 6. A diagnostic that names the wrong cause

**Fixed 2026-08-27 in `95225ff`.** Recorded here as measured, because this section is what raised
the issue.

A clause whose pattern matched **no value of the declared domain** was reported as
`unreachable — every value it matches is matched by an earlier clause`, **even when it was the only
clause in the function.** Controlled three ways in [`25e_surface_probe.sh`](25e_surface_probe.sh) §6:
a genuinely shadowed clause 2 (correct message), a vacuous clause 1 with two clauses after it, and
a vacuous clause that is the sole clause. All three got the shadowing wording.

The wrong one was the likelier: `Note((:some, s))` over `option<string>` is the first thing a
reader with C#, Rust or F# in their hands writes. They were told to look for a shadowing clause.
There is none. → filed as [ENG-259](https://linear.app/davewil/issue/ENG-259); no `issues/` file
and no map number, because a defect is not a design question.

**This section's own count was one short.** Building the fix found a *third* fault reaching the
same branch — a guard no value satisfies, which the two-way split would have mislabelled, since
its pattern *is* a member of the input. The tags are now `vacuous_clause`, `unsatisfiable_guard`
and an unchanged `unreachable_clause`. The switch-arm twin reproduces identically and is
deliberately still open as [ENG-269](https://linear.app/davewil/issue/ENG-269).

### 7. `+` over two strings is a priced decision, and this is the price

`a + b` where both are `string` type-checks and crashes at run time with `badarith`. Every
arithmetic operator does it, over every operand type — string, atom, record, all measured.

**This is decided, not broken.** [Ticket 33 §2](../issues/33-body-check-site.md) enumerates five
obligation sites and rules there is no sixth *because there is no sixth place a type is written*:
"`e_op`, `e_tuple`, `e_list` and `e_block` declare nothing, so they synthesise and never check."
`e_op` synthesises `int` for arithmetic. The rule is coherent and the enumeration is principled.

What this exemplar adds is the **price**, which was never named: F5's out-of-scope note illustrates
the rule with `:a + 1`, and nobody writes `:a + 1`. What people write is `a + b` to join two
strings, in the one program where joining strings is the entire job — and the language's answer is
a run-time crash from source the checker passed. It is the same failure shape the features README
calls "this project's worst": green source, `badarith` at run time. → **tickets 33, 16 §2**, and it
is a cost to weigh, not a bug to fix.

### 8. Iodata's empty fragment is free, and that is the argument for the type

`[]` is the absent section. No `option<Iodata>`, no sentinel, no empty-string special case, and the
conditional and optional sections in `layout.bs` both fall out of it with two clauses each. When
the binder lands, this is what it buys — recorded so ticket 09's cost side has a benefit beside it.

### 9. The two `Reverse`s collide, and the module refuses them

Third sighting of 25d's `Prepend`, and the first where the language **refuses the duplicate**.
`escape.bs` and `rows.bs` each want the same six-token accumulator reversal, differing only in one
word of the signature. A module is a directory compiling to one beam, so `Reverse/2` twice is
`error: Reverse/2 is declared more than once` — measured — and the only way forward is to invent
two names, `ReverseParts` and `ReverseRows`, that describe nothing except which clone they are.

**This sharpens ticket 37's case rather than repeating it.** 25d could describe the cost as
duplication; here duplication is not available, so the cost is paid in the *namespace*, and it
compounds with every further type the helper is needed at. → **ticket 37**, whose polymorphic
signature is the whole of the fix.

### 10. The page is 100% FFI at its boundary

Four foreign declarations — `iolist_size/1`, `iolist_to_binary/1`, `integer_to_binary/1`,
`binary:encode_unsigned/1` — and between them they are the entire mechanism by which the page
becomes bytes. The language contributes the dispatch and none of the plumbing.

**Counted against 25d, and the difference is in kind rather than in number.** 25d declares three
foreign functions (`epgsql:connect/1`, `epgsql:equery/3`, `gen_server:call/2` — its only two
`using` blocks), and all three are *driver* calls: talking to a server and to a process. Its row
validation, status mapping and totals are B#. 25e's four are all *byte manipulation*, and it has
no domain logic to speak of.

So the pair is the first evidence about where this language's contribution actually sits: it does
the dispatch and the domain, and it does not yet do the bytes. That is a defensible place to be —
[LANGUAGE.md puts string operations behind the module system](../../LANGUAGE.md) rather than
nowhere — but it should be recorded rather than discovered again. → **ticket 16**.

---

## What ticket 22 can take from this

[22](../issues/22-how-opinionated.md) closed with the domain arm dead on mechanism, so this is
confirmation rather than evidence, and it is worth one line: **the DDD constructs did not get in
the way and were barely present.** One `record` for a row, one for the model, one closed union for
status. A renderer is a tree walk, and the aggregate grammar neither helped nor hindered it. That
is 25b's answer for a third time, from the least domain-shaped program in the set.

**What was miserable was the type system's treatment of strings and sequences** — which is
orthogonal to how opinionated the language is about domains, and is the same sentence 25b wrote
about binaries. Three exemplars, one complaint, and it has never once been about DDD.

---

## Note for whoever writes the next exemplar

**One remains: async processing.** Both its tickets (14, 15) are resolved, so it tests and invents
nothing — the cleanest condition in the set. It is also the only remaining shape with **no long-lived
server and no wire format**, which every one of the five written so far has had. Fan-out, fan-in,
supervision of work, and the question of whether `async`/`await` survived or became `spawn`/`Task`.

**Do not write it as a sixth `gen_server`.** The value of the last one is that it is the only
program in the set whose structure is not a process holding state behind a protocol, and writing it
as one would give the map the same shape six times.
