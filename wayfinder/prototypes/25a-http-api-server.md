# PROTOTYPE 25a — exemplar: an HTTP API server

> **Throwaway.** Ticket [25](../issues/25-exemplar-programs.md), exemplar 1 of 6.
> Written against the surface as it stands after tickets 26, 27 and 28 (2026-08-13).
> The lowering is [`25a_http_lowering.erl`](25a_http_lowering.erl) and it **compiles and runs on
> OTP 28.5**. Everything claimed below was executed.

This is the exemplar ticket 25 calls *"the strongest practical case for ticket 09's structural
answer"* — a JSON document is structural, open and recursive. It also carries ticket 17's job 1
(does a ladder of unrelated conditions occur?) and ticket 12's count (how often is a closed
residual closed deliberately?).

---

## The layout

Ticket 13 makes the directory the module; ticket 08 makes the declarations file `index.bs`.

```
lib/shop/api/                       ← compiles to ONE beam: Shop.Api
  index.bs          module attributes and types
  route.bs          the route table
  create_order.bs   the POST handler
  admit.bs          request admission
  encode_response.bs
```

---

## `index.bs`

```csharp
using Shop.Orders;

type Method = :get | :post | :put | :delete | :patch;

type Response = (int, term);

record CreateOrder { Id: string, Total: int, Lines: list<Line> }

record Line { Sku: string, Qty: int }
```

Three things worth noticing before any code.

`Method` is a **closed** union of five atoms. A path is `list<string>` and is **open** — there are
infinitely many. So a route table's residual is open *on one axis and closed on the other*, which
turns out to matter (friction 2).

`CreateOrder` and `Line` are `record`s, so each mints a tag from its qualified name —
`:'Shop.Api.CreateOrder'`. Ticket 26 §1's DDD requirement is what makes `Update(Order)` reject an
`Invoice`; here it is what stops a `Line` being passed where a `CreateOrder` is wanted, which in a
request parser is a live risk because both arrive as bare maps from `json:decode`.

`Response`'s second member is `term`, not a type. That is honest and it is also the first friction:
a response body is genuinely heterogeneous, and the language has no way to say "anything I can
serialise" — ticket 16 refused capability bounds outright.

---

## `route.bs` — the route table

The showcase shape. Method and path destructured in the head, one clause per route.

```csharp
Response Route(Method, list<string>, term);

(:get,    ["orders"],     _)     -> (200, Orders.All());
(:get,    ["orders", id], _)     -> Fetch(id);
(:post,   ["orders"],     body)  -> CreateOrder(body);
(:delete, ["orders", id], _)     -> Delete(id);
(_,       _,              _)     -> (404, #{ error = "no route" });
```

This is the language at its best, and the lowering confirms it: five beam-sharp clauses become
five native Erlang clause heads, dispatching on an atom and a list shape with no guards at all.
Ticket 01's finding reproduced on a second shape.

**But the last clause is the interesting one.** Ticket 12 §2 permits `_` only over an *open*
residual. Here the residual is open, so `_` is legal — and it is legal for a reason that has
nothing to do with routing. It is legal because `list<string>` is infinite. Had the path been a
closed union of named routes, the same catch-all would be an **error**, and a real router wants
exactly that catch-all either way, because a 404 is not a missing case — it is the *specified*
behaviour for every unmatched request.

So ticket 12's rule permits the right thing here **by accident**. That is worth recording, because
it means the rule is not being tested by this exemplar so much as narrowly missed by it.

---

## `create_order.bs` — the boundary

`json:decode` returns a `term`. Ticket 11 says patterns over a `term` are O(1) guard-decidable
only, and deep validation is an explicit `ValidateAs<T>` returning `result<T, ValidationError>`.

```csharp
Response CreateOrder(term);

(body) -> ValidateAs<CreateOrder>(body) switch {
              (:error, e)  => (422, #{ error = "invalid", at = e }),
              cmd          => (201, Orders.Place(cmd))
          };
```

Five lines, and the boundary is completely explicit: the term from outside is either a
`CreateOrder` or a reason. Nothing narrows implicitly, and the arm order is forced — the tagged
`(:error, e)` member has to be discriminated before the bare success member, because
`result<T, E>`'s success side is untagged.

The lowering's hand-written `ValidateAs<CreateOrder>` is **~40 lines for two record types**, and
it is worth stating plainly: that is the cost the map lists as unmeasured, and it is per type, not
per program. It also produced the session's sharpest finding — see friction 0.

---

## `admit.bs` — ticket 17's job 1, answered

17 §6 made `switch` the only branching construct with a **tuple subject** for a ladder of unrelated
conditions, declined to pay a keyword for `cond` until the shape was shown to occur, and named the
HTTP exemplar as a likely site. **It occurs, and the width is five.**

Request admission is five unrelated booleans — authentication, verification, quota, body size, and
a feature flag. There is no way to express it as a pattern on one subject, because the five have no
structural relationship to each other.

```csharp
Response Admit(Request);

(r) -> (r.Authed, r.Verified, r.Quota > 0, r.Size <= 1048576, r.Beta) switch {
           (false, _,     _,     _,     _)     => (401, :unauthenticated),
           (_,     false, _,     _,     _)     => (403, :unverified),
           (_,     _,     false, _,     _)     => (429, :quota_exceeded),
           (_,     _,     _,     false, _)     => (413, :too_large),
           (_,     _,     _,     _,     false) => (404, :not_in_beta),
           (true,  true,  true,  true,  true)  => (200, :ok)
       };
```

**The honest report: this is worse than an `if`/`else if` ladder, and it is not close.**

Three specific costs, all visible above:

1. **The condition and its consequence are separated by the width of the tuple.** `:quota_exceeded`
   is on the same line as its test, but the test is `false` in the third column — you have to count
   columns to know which condition fired. At five wide, everybody counts.
2. **The `_`s carry no information and there are sixteen of them.** They are pure ceremony,
   and they grow as O(width²) down the ladder.
3. **The subject line is 70 characters** before a single arm is written, and it holds all five
   expressions far from the results they select.

Against that, one genuine win the `if` ladder does not have: **the last arm proves the ladder is
total.** `(true, true, true, true, true)` is the only remaining case, and the compiler knows it —
a fall-through `else` would not be checked at all. So the tuple subject buys exhaustiveness on
exactly the construct where an `if` ladder silently drops a case.

**Recommendation to ticket 17's fog patch: the shape occurs, at width five, in the most ordinary
handler in the exemplar set.** Whether that is worth a `cond` keyword is David's call — but the
evidence 17 asked for exists now, and it is not marginal.

---

## `encode_response.bs`, and the finding

```csharp
(int, binary) EncodeResponse(Response);

((status, :no_content)) -> (status, "");
((status, body))        -> (status, Json.Encode(body));
```

Two lines, and the second one **cannot compile**. See friction 0.

---

## What writing this actually surfaced

Six things, ordered by how much they should worry you.

0. **The language's own failure values are unserialisable, and an HTTP API is where that
   detonates.** `ValidationError` is *"a tuple today"* (CONTEXT.md) and `result<T, E>`'s failure
   member is `(:error, E)` — also a tuple. Ticket 16 §4 established that `json:encode/1` **refuses
   tuples at any depth**. So the 422 body carrying a `ValidationError`, and any response embedding
   a `result`, are both unencodable. **Measured, not argued** — the lowering returns
   `{crashed, error, unsupported_type}` for both:

   ```
   422 response term  -> {422,#{error => <<"invalid">>,at => {[lines,0],line}}}
   encode 422         -> {crashed,error,unsupported_type}
   encode result err  -> {crashed,error,unsupported_type}
   ```

   Ticket 16 §4 moves this from a runtime crash to a compile error, which is the right outcome —
   but the compile error then lands on *the single most common thing an HTTP handler does*, which
   is putting its own error reason on the wire. **The fix is already available and nobody has
   connected it**: CONTEXT.md says `ValidationError` is *"a tuple today; a record candidate if one
   is ever introduced"* — and ticket 26 introduced records the same day. A record erases to a map,
   and `json:encode` takes a map directly. **`ValidationError` should be respelled as a record.**
   That leaves `result`'s `(:error, E)` still a tuple, which is a genuine open question, since
   ticket 15 chose the tag *because* an untagged failure channel collapses. → tickets 15, 16, 26.

1. **A ladder of unrelated conditions occurs at width five, and the tuple subject is bad at it.**
   Ticket 17's job 1, answered above with the code. The `_` ceremony grows quadratically and the
   test is separated from its consequence by the tuple's width. → ticket 17's `cond` fog patch.

2. **Ticket 12's catch-all rule permits the right thing for the wrong reason.** A router's final
   clause is legal because `list<string>` is infinite, not because a 404 is the specified
   behaviour for an unmatched request. Both are true; only the first is the rule. A route table
   over a *closed* set of named routes would be refused a catch-all it still wants. **Count for
   ticket 12: one closed residual in this exemplar** — the `Method` union — **and it was never
   deliberately closed**, because no handler dispatches on method alone. → ticket 12.

3. **`Response`'s body is `term`, and the language cannot say "serialisable".** Ticket 16 refused
   capability bounds outright, so a response body's type is either `term` — which defers the
   serialisation failure to friction 0's compile error, at the far end of the program from the
   handler that chose the value — or a hand-maintained union of every shape the API returns. The
   exemplar takes `term` because the union is unwritable. This is the first place in the map where
   16's refusal of bounds has a visible cost in ordinary code. → tickets 16, 20.

4. **The minted tag reaches the serialiser.** A record erases to a map *including* its `Kind` field
   (ticket 26 §1: the name enters the term, as data). So the wire format carries
   `"kind":"Shop.Orders.Order"` unless the published mapping strips it — the lowering has to strip
   it by hand. Ticket 16 §4's mapping owes a rule here, and it is not obviously "always strip":
   a discriminated union on the wire is exactly what a tag is for. → ticket 16, 26.

5. **Route patterns are string literals, and nothing checks them against each other.** `["orders",
   id]` and `["orders", "count"]` overlap, and the second is unreachable if written after the
   first. Ticket 04's redundancy check should catch it — but only if string literals participate in
   the residual algebra, which ticket 20 settled for binaries as *types* (`<<_:M, _:_*N>>`) and not
   for literal values. → ticket 04, 20.

6. **I had to invent a map-literal separator, and the exemplar should say so rather than pick
   silently.** `#{ error = "invalid", at = e }` above uses `=`, by analogy with ticket 26's
   construction rule — but **26 settled record construction, not map literals**, and the only
   attested map syntax anywhere in the prototypes is the empty `#{}`. 01b's friction #6 is still
   open verbatim: *"map literals versus record literals are unresolved… the language needs one
   story here, not two syntaxes."* A response body is a map far more often than it is a record,
   so this is not a corner. → fog, or ticket 26's leftover.

7. **`CreateOrder` is a record type and a function name in the same module, and nothing
   disambiguates them.** `route.bs` calls `CreateOrder(body)`; `index.bs` declares
   `record CreateOrder`. Under ticket 26 §3's casing rule both are PascalCase, and the dot rule
   does not help because neither is a projection. This is exactly the colliding-short-names defect
   [ticket 23](../issues/23-what-the-language-owes-an-agent.md) §10 warns about — *"`Order.Server.Apply`
   beside `Order.Apply`"* — arriving unprompted in the first exemplar written after it. The
   standing constraint says read cost carries full weight, and a reader cannot tell which
   `CreateOrder` a bare occurrence means. **Also honest: `Request` is used in `Admit`'s signature
   and never declared** — I did not notice until reviewing, which is itself the finding, since an
   agent author would not have either. → tickets 23, 08, and the module/namespace fog.

### What did not appear

**No pipes.** Not one `|>` in the whole exemplar, and no `|?>` either. Request handling here is
dispatch and validation, not transformation — the shape 17 was designed for did not arise. The
valve's absence is the more surprising half: `CreateOrder` is exactly the "validate then act"
sequence 17 §4 wrote `|?>` for, and it came out cleaner as a two-arm `switch` on the
`ValidateAs<T>` result, because there is only one fallible stage. **`|?>` earns its place at three
stages, not one** — worth testing in the database exemplar, which has more.
