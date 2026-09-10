# F25's corrected signature, in code someone would write

Every example ENG-346 put to David was a minimal repro: `Pick(1) -> Ints()`, `Go(r) -> r`,
`Grow(term r)`. He could not see what the diagnostic would look like in an application
(2026-09-11), so these are the same cases as web, session and database code. Each was compiled
with `bsc`, and the output below is what it printed, paths trimmed.

Writing them in this form changed the diagnostic. In four of the six, the realistic fix is the
clause, and the message offered only a wider signature. David decided (F25's Round 3, *"all"*)
that every return mismatch leads with *"If `D` is what you meant, fix the clause, not the
signature."*, `D` being the declared return as the author wrote it, with any wider signature
after it. The outputs below are that form.

**Writing them also found a compiler crash.** The first drafts took the session cart and the
database row from foreign calls (`using :analytics_db { map<string, term> latest_row(binary site)
}`), and every one killed `bsc` with a stack trace: a foreign function returning `map<K, V>`
crashes `bs_check:opaque_refinement/1`. Filed as
[ENG-351](https://linear.app/davewil/issue/ENG-351). `ValidateAs<map<K, V>>` is refused too (its
walk over unbounded keys is not built), so in the programs below the maps arrive as parameters:
the web layer or the driver has already decoded them.

## 1. Checkout — two maps no clause head can tell apart

```csharp
module Checkout

// The checkout page needs the cart as SKU -> quantity.
// The web layer has already decoded both sources before this runs:
// a signed-in shopper's cart comes from the session, already numeric;
// a guest's cart comes from the posted HTML form, where every value is text.
public map<string, int> CartQuantities(bool signed_in,
                                       map<string, int> session_cart,
                                       map<string, binary> form_fields)

CartQuantities(true, session_cart, form_fields)  -> session_cart
CartQuantities(false, session_cart, form_fields) -> form_fields
```

```
Checkout.bs:12:1: error: CartQuantities returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  If `map<string, int>` is what you meant, fix the clause, not the signature.
  Widening the signature to cover what the clauses return would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  so if both are meant, tag them, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag.
```

The bug is that the guest's quantities are still text, and the first line after the residual
says to fix that clause. Tagging comes second, for a program that really does mean both
representations of a cart.

## 2. Checkout, where the session can expire — the tag shape shows only the pair

```csharp
module CheckoutResult

// The same page, but reading the session can fail: it may have expired.
public result<map<string, int>, atom> CartQuantities(bool signed_in,
                                                     result<map<string, int>, atom> session_cart,
                                                     map<string, binary> form_fields)

CartQuantities(true, session_cart, form_fields)  -> session_cart
CartQuantities(false, session_cart, form_fields) -> form_fields
```

```
CheckoutResult.bs:9:1: error: CartQuantities returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  If `result<map<string, int>, atom>` is what you meant, fix the clause, not the signature.
  Widening the signature to cover what the clauses return would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  so if both are meant, tag them, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag.
```

The declared type also carries `(:error, atom)`, the expired session, and the tag shape leaves it
out: it shows the two members to tag, not what the whole return type becomes. Open for David
(F25, *Left for David*).

## 3. Analytics — the line replaces the declared type (R3)

```csharp
module Analytics

// Page views per path, for the dashboard.
type ViewCounts = map<string, int>

// The database driver hands each row over as column name -> whatever the
// column held. This was meant to turn a row into view counts, and passes the
// raw row straight through instead.
public ViewCounts PageViews(map<string, term> row)

PageViews(row) -> row
```

```
Analytics.bs:11:1: error: PageViews returns a value its signature does not declare
  not covered by the declared return type:
    map<string, term>
  If `ViewCounts` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public map<string, term> PageViews(map<string, term> row)
  this replaces `ViewCounts`, which `map<string, term>` contains.
```

The lead is the right advice: convert the row. The offered line is legal and compiles, and the
last sentence says what pasting it costs, which is `ViewCounts`.

## 4. Analytics, where the site may be unknown — an absorbed member

```csharp
module AnalyticsMissing

type ViewCounts = map<string, int>

// Same dashboard, but the query can find no row for the site, and that is
// :not_found rather than an empty map.
public ViewCounts | :not_found PageViews(list<map<string, term>> rows)

PageViews([])          -> :not_found
PageViews([row, ..rest]) -> row
```

```
AnalyticsMissing.bs:10:1: error: PageViews returns a value its signature does not declare
  not covered by the declared return type:
    map<string, term>
  If `ViewCounts | :not_found` is what you meant, fix the clause, not the signature.
  no signature is offered: widening it would leave `map<string, int>` absorbed by
  `:not_found | map<string, term>`, and a declared type may not hold an absorbed member.
```

The lead names the type as written. The reason below it still names the absorbed member as the
algebra resolves it, `map<string, int>`, where the author wrote `ViewCounts`: one type, two names
in one message. Open for David (F25, *Left for David*).

## 5. Accounts — a declared type written inline

```csharp
module Accounts

// Look a user up for the account page. The query returns zero rows or one.
// The author wrote the user's shape inline rather than declaring a record, and
// forgot that no rows means :not_found.
public { Id: int, Email: binary } FindUser(list<{ Id: int, Email: binary }> rows)

FindUser([])            -> :not_found
FindUser([user, ..rest]) -> user
```

```
Accounts.bs:8:1: error: FindUser returns a value its signature does not declare
  not covered by the declared return type:
    :not_found
  If `{ Id: int, Email: binary }` is what you meant, fix the clause, not the signature.
  no signature is offered: the declared signature is written in a form
  this line does not reproduce.
```

Here the fix is the signature: a missing user should be declared. The lead names the inline type
in the author's field order. "A form this line does not reproduce" means the pasteable line:
F25 does not write inline maps into a signature (its Out of scope).

## 6. Orders API — a literal the line cannot spell (ENG-350)

```csharp
module OrdersApi

// Route an HTTP method on /orders. The handler answers with an outcome atom,
// and whoever wrote the last clause reached for a status code instead.
public atom Handle(binary method)

Handle("POST") -> :created
Handle("GET")  -> :ok
Handle(other)  -> 405
```

```
OrdersApi.bs:9:1: error: Handle returns a value its signature does not declare
  not covered by the declared return type:
    405
  If `atom` is what you meant, fix the clause, not the signature.
  no signature is offered: what the clauses return has no spelling as a type yet.
```

The likelier fix is `:method_not_allowed`, and the lead now says so. The spellable wider line,
`public atom | int Handle(binary method)`, is ENG-350.

## What the six have in common

In four of the six (1 to 4) the realistic fix is the clause. In 5 it is the signature. In 6
either is plausible. Minimal repros hid that, because in a repro neither side is the right one,
and it is what moved every message to lead with the clause.
