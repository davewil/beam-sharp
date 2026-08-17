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
using Shop.Orders

type Method = :get | :post | :put | :delete | :patch

type Response = (int, term)

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
public Response Route(Method, list<string>, term)

Route(:get,    ["orders"],     _)     -> (200, Orders.All())
Route(:get,    ["orders", id], _)     -> Fetch(id)
Route(:post,   ["orders"],     body)  -> CreateOrder(body)
Route(:delete, ["orders", id], _)     -> Delete(id)
Route(_,       _,              _)     -> (404, #{ error = "no route" })
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
private Response CreateOrder(term)

CreateOrder(body) -> ValidateAs<CreateOrder>(body) switch {
                         (:error, e)  => (422, #{ error = "invalid", at = e }),
                         cmd          => (201, Orders.Place(cmd))
                     }
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

**What was written here first, and why it is no longer the code:**

```
Admit(r) -> (r.Authed, r.Verified, r.Quota > 0, r.Size <= 1048576, r.Beta) switch {
                (false, _,     _,     _,     _)     => (401, :unauthenticated),
                (_,     false, _,     _,     _)     => (403, :unverified),
                (_,     _,     false, _,     _)     => (429, :quota_exceeded),
                (_,     _,     _,     false, _)     => (413, :too_large),
                (_,     _,     _,     _,     false) => (404, :not_in_beta),
                (true,  true,  true,  true,  true)  => (200, :ok)
            }
```

Three costs, all visible above:

1. **The condition and its consequence are separated by the width of the tuple.** `:quota_exceeded`
   is on the same line as its test, but the test is `false` in the third column — you have to count
   columns to know which condition fired. At five wide, everybody counts.
2. **The `_`s carry no information and there are sixteen of them.** They are pure ceremony,
   and they grow as O(width²) down the ladder.
3. **The subject line is 70 characters** before a single arm is written, and it holds all five
   expressions far from the results they select.

~~**Recommendation to ticket 17's fog patch: the shape occurs, at width five, in the most ordinary
handler in the exemplar set.**~~

**RETRACTED 2026-08-13 (David). This function is contrived, and the criticism is correct.** *"In a
web server you'd basically have a pipeline and pluggable middleware, e.g. Plug in Elixir. So
something like the switch in that example is unlikely to be written."*

**And the code now matches the retraction, 2026-08-15 (David):** *"with middleware, Plug style, and
maybe pipe, exemplar 25a should be a lot cleaner than that horrific switch expression."* The ladder
above stayed in the file for two days after the finding it supported was withdrawn, which made the
exemplar argue against itself. This is the shape a web stack actually writes — a chain of
independent checks, each halting the flow on failure:

```csharp
public Response Admit(Request)

Admit(r) ->
    var outcome = r |?> Authenticated()
                |?> Verified()
                |?> WithinQuota()
                |?> WithinSize()
                |?> InBeta()
    outcome switch {
        (:error, response) => response,
        passed             => (200, :ok)
    }

private result<Request, Response> Authenticated(Request)
Authenticated(r) when r.Authed -> r
Authenticated(_)               -> (:error, (401, :unauthenticated))

private result<Request, Response> Verified(Request)
Verified(r) when r.Verified -> r
Verified(_)                 -> (:error, (403, :unverified))

private result<Request, Response> WithinQuota(Request)
WithinQuota(r) when r.Quota > 0 -> r
WithinQuota(_)                  -> (:error, (429, :quota_exceeded))

private result<Request, Response> WithinSize(Request)
WithinSize(r) when r.Size <= 1048576 -> r
WithinSize(_)                        -> (:error, (413, :too_large))

private result<Request, Response> InBeta(Request)
InBeta(r) when r.Beta -> r
InBeta(_)             -> (:error, (404, :not_in_beta))
```

**It is longer and it is better, and the reason is the one 25c already measured.** 25c found that
*lifting two of its four conditions into named functions to fit the tuple improved the code*; this
is the same finding at width five, where it is no longer marginal. Every condition now sits beside
its consequence, the sixteen ceremonial `_`s are gone, and each check is independently testable and
reusable across handlers — which is the actual reason Plug, Rack and ASP.NET Core are built this
way, rather than a stylistic preference.

**Two limits, stated rather than implied.** The valve `|?>` is **decided and not built** — ticket 17
§4, feature F9 — so this section still does not compile, and its first error moved from a missing
type to `syntax error before: '|'`. And this is a *fixed* chain, not **pluggable** middleware: a
runtime-composed list of stages is [ticket 31](../issues/31-composable-middleware.md), which is
open, and the map notes it lands in the same place as the GenServer question — a library written in
the language over a compiler-known contract.

**What this costs ticket 17's `cond` patch:** nothing it had not already lost. The width-five data
point was withdrawn in August; what is new is that the exemplar no longer *displays* a ladder while
its own prose says nobody would write one.

Admission control is not one function with five booleans in any web stack worth copying — Plug,
Rack and ASP.NET Core all distribute those five concerns across **separate middleware**, each
halting the pipeline on failure. Authentication does not know about quota; body-size limits do not
know about feature flags. **The architecture dissolves the ladder**, which is why nobody writes it.

So this section did the thing ticket 25 exists to prevent: it **constructed a shape to answer a
question** instead of writing the workload honestly and reporting what the workload demanded. The
five conditions were assembled because 17 asked for a ladder, and an invented ladder is evidence
about my invention, not about web servers. → 17's `cond` patch loses this data point entirely.

**What the criticism exposes is worse than the ladder, and it is the real finding — see friction 1.**

---

## `encode_response.bs`, and the finding

```csharp
public (int, binary) EncodeResponse(Response)

EncodeResponse((status, :no_content)) -> (status, "")
EncodeResponse((status, body))        -> (status, Json.Encode(body))
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

1. **The exemplar has no middleware layer, and that is the largest thing wrong with it.**
   *(Rewritten 2026-08-13 after David's criticism of `admit.bs`; the previous item claimed a
   width-five ladder as evidence for 17's `cond` patch and is retracted above.)*

   A web application on this platform is a **pipeline of composable middleware** — Plug is the
   reference, and Rack and ASP.NET Core are the same idea. Each stage takes the request, may
   modify it, and may **halt** it by returning a response. Routing is one stage near the end, not
   the whole program. **This exemplar wrote the router and skipped the pipeline**, which is why it
   needed an invented five-condition function to have anything to say about request admission.

   That is not a small omission, because **the pipeline is where the language's own constructs
   would have been exercised** and the router is where they aren't. It also explains the
   *"what did not appear"* note below, and corrects its reasoning: the absence of `|>` was not
   because request handling is dispatch rather than transformation. It was because the
   transformation layer is the part I did not write.

   **The sharp question it raises, which no ticket has asked: is `|?>` already the middleware
   mechanism?** Ticket 17 §4's valve short-circuits a pipeline on `(:error, _)` and runs no
   further stage, which is structurally what Plug's `halt/1` does. If so, a beam-sharp web stack
   is `req |?> Auth.Check() |?> Quota.Check() |?> Router.Dispatch()` and needs no new construct —
   a strong result for 17. If not, the gap is load-bearing, because middleware composition is how
   every serious web framework on this platform is built. **Two things have to be checked before
   claiming it**: Plug's halt carries a *`conn` with a response already written*, not an error, so
   the beam-sharp shape is `result<Request, Response>` and the "failure" channel is an ordinary
   200 — which ticket 15's `result<T, E>` admits but never anticipated; and Plug stages are
   **registered and composed at compile time** by a behaviour, which is ticket 14's territory and
   ticket 16's refused open extension. → tickets 17, 15, 14, 16; needs a ticket of its own.

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

8. **Every `string` field costs an O(n) UTF-8 traversal at the boundary, and a request is mostly
   string fields.** Ticket 20 §4 made `string` a `binary` refined by valid UTF-8 — an **opaque**
   refinement, established by generated code where a value enters, and the map's *sixth* codegen
   obligation. `CreateOrder` has two `string` fields (`Id`, and `Sku` on every `Line`), so
   validating one order with *n* lines is *n+1* full traversals **on top of** `ValidateAs<T>`'s own
   structural walk. The lowering makes this concrete — `is_utf8/1` is a real function doing a real
   pass. Ticket 20 noted the obligation *"lands on the language's most-passed value"* and asked the
   skeleton to measure it *"on a realistic string-handling path rather than in isolation"*.
   **An HTTP request parser is that path**, and it is now written. → ticket 20, and the skeleton's
   tenth measurement.

9. **`Json.Encode` is invented, like the map literal in item 6.** The exemplar needs a prelude name
   for serialisation and none is settled. This matters more than a naming quibble because ticket
   17 §2's two-tier rule makes prelude membership determine the **emitted type** — a compiler-known
   encoder inlines and keeps its precision, a user-level one degrades to `any()`. So "what is
   `Json.Encode`" is a question about the *type* of every response, not about spelling.
   → the stdlib-shape fog patch, tickets 16, 17.

### What did not appear

**No pipes.** Not one `|>` in the whole exemplar, and no `|?>` either. Request handling here is
dispatch and validation, not transformation — the shape 17 was designed for did not arise. The
valve's absence is the more surprising half: `CreateOrder` is exactly the "validate then act"
sequence 17 §4 wrote `|?>` for, and it came out cleaner as a two-arm `switch` on the
`ValidateAs<T>` result, because there is only one fallible stage. **`|?>` earns its place at three
stages, not one** — worth testing in the database exemplar, which has more.
