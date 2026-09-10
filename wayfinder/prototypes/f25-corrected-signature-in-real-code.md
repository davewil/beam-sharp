# F25's corrected signature, in code someone would write

Every example ENG-346 put to David was a minimal repro: `Pick(1) -> Ints()`, `Go(r) -> r`,
`Grow(term r)`. He could not see what the diagnostic would look like in an application
(2026-09-11), so these are the same cases as web, session and database code. Each was compiled
with `bsc`, and the output below is what it printed, paths trimmed. The outputs are the compiler
after F25's Round 3 (David: *"all"*), where every return mismatch leads with *"If `D` is what you
meant, fix the clause, not the signature."* The notes under each were written against `bc4740b`,
before that line existed. That is why several of them point at the missing sentence.

**Writing them found a compiler crash.** The first drafts took the session cart and the database
row from foreign calls (`using :analytics_db { map<string, term> latest_row(binary site) }`), and
every one killed `bsc` with a stack trace: a foreign function returning `map<K, V>` crashes
`bs_check:opaque_refinement/1`. Filed as [ENG-351](https://linear.app/davewil/issue/ENG-351).
`ValidateAs<map<K, V>>` is refused too (its walk over unbounded keys is not built), so in the
programs below the maps arrive as parameters: the web layer or the driver has already decoded
them.

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
  Widening the signature to cover both would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  so if both are meant, tag them, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag.
```

The bug is that the guest's quantities are still text. The fix is to turn them into numbers. The
advice offers only the other repair, tagging, which would leave every caller of
`CartQuantities` handling two representations of a cart.

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
  Widening the signature to cover both would be refused:
    no clause head can tell `map<string, int>` from `map<string, binary>`
  so if both are meant, tag them, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag.
```

The declared type also carries `(:error, atom)`, the expired session, and the shape leaves it out.

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

R3's last sentence is the right advice here. The offered line is legal and compiles, and pasting
it throws `ViewCounts` away.

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

The sentence names `map<string, int>` where the author wrote `ViewCounts`, and it says nothing
about the fix, which is the same as in 3: convert the row.

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
  If `{ Email: binary, Id: int }` is what you meant, fix the clause, not the signature.
  no signature is offered: the declared signature is written in a form
  this line does not reproduce.
```

"A form" does not say which. The form is the inline `{ Id: int, Email: binary }`.

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

The spellable line is `public atom | int Handle(binary method)`. The likelier fix is
`:method_not_allowed`.

## What the six have in common

In four of the six (1 to 4) the realistic fix is the clause, not the signature. In 5 it is the
signature: a missing user should be declared. In 6 either is plausible. F25 only ever widens, and
23 §8 accepted that risk (*"widening becomes frictionless"*). Minimal repros hid how often the
widened line is the wrong advice, because in a repro neither side is the right one.
