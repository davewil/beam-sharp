# PROTOTYPE 25d — exemplar: database querying (PostgreSQL via epgsql)

> **Throwaway.** Ticket [25](../issues/25-exemplar-programs.md), exemplar 4 of 6.
> Written against the surface as it stands after F25 (2026-08-24).
> The lowering is [`25d_db_lowering.erl`](25d_db_lowering.erl) and it **compiles with no
> warnings and runs on OTP 28**. The result-set terms it runs on were **captured from a live
> PostgreSQL 16 through real epgsql 4.7.1** ([`25d_live_capture.escript`](25d_live_capture.escript)),
> not written by hand — this exemplar's whole subject is what another system chooses to send,
> so synthetic rows would have been the exact failure 25a recorded, a shape constructed to
> answer a question. The compiler measurements are [`25d_surface_probe.sh`](25d_surface_probe.sh),
> run against `compiler/` as of today. Everything claimed below was executed.

The **doubly owed** exemplar: 25a nominated it for the `|?>` question, 25c re-nominated it for
untyped result sets, and both nominations are now spent. What it stresses, per the candidate-set
table: **untyped result sets crossing a boundary; comprehension/pipeline over rows; connection
processes**. The `22` in its Decides column was spent when ticket 22 resolved (2026-08-23);
tickets 17 and 18 are what it still owes, and both get answers below.

**Why the rows are real.** `create table orders (id serial, customer text, total_cents int4,
total_legacy numeric(10,2), status text check (status in ('placed','shipped','cancelled')),
shipped_at timestamptz null, meta jsonb)` — three rows inserted through the binary protocol,
then read back. The traps are deliberate: a `numeric` money column, a nullable timestamp, a
`jsonb` document, a CHECK-constrained status. Every one of them turned out to carry a finding.

---

## What epgsql actually hands back — measured, not read

The full transcript is in [`25d_live_capture.escript`](25d_live_capture.escript)'s header; the
five facts the exemplar is built around:

```
{ok,[{column,<<"id">>,int4,23,4,-1,1,16390,1}, ...],
    [{1,<<"ada">>,1999,<<"19.99">>,<<"placed">>,null,<<"{\"gift\": true}">>},
     {2,<<"grace">>,125000,<<"1250.00">>,<<"shipped">>,{{2026,8,20},{9,30,0.0}},<<"{}">>},
     {3,<<"alan">>,0,<<"0.00">>,<<"cancelled">>,null,<<"{\"reason\": \"test\"}">>}]}
```

1. **A row is a tuple, not a map.** A B# record erases to a tagged map, so `ValidateAs<OrderRow>`
   can never accept a wire row. The boundary type is a *tuple* type, and the record is built one
   conversion later. No other exemplar met this, because no other exemplar received structured
   values some library had already decoded.
2. **The `numeric` column arrives as text.** Its column record says `{unknown_oid, 1700}` — epgsql
   does not even *name* the type — and the value is `<<"19.99">>`. A money column crosses as a
   string, and B# has no float and no string arithmetic. The schema advice falls straight out:
   **money is `int4` cents or it does not cross**. `total_legacy` exists in the capture schema to
   prove this and is deliberately absent from the exemplar's own `select` list.
3. **A `timestamptz` carries a float.** `{{2026,8,20},{9,30,0.0}}` — the seconds field is `0.0`,
   and `is_float` on it returns `true` (measured in the lowering). B# has no float *literal
   syntax*, so this value that flows through the program **cannot be written down in the language
   that handles it**. It lives as `term` and nothing else.
4. **SQL NULL is the atom `null`**, not `:nothing` — see the option finding below.
5. **`jsonb` rewrites its own bytes.** `{"gift":true}` went in; `{"gift": true}` — with a space —
   came back. The document was decoded and re-encoded by the server, so a `jsonb` column is not
   binary-stable and nothing downstream may compare it byte-wise. What *type* a decoded JSON
   document would even be is ticket 48's question, met here for the second time (25a's map literal
   was the first).

Two more shapes from the same capture, both load-bearing below: `equery` for an *update* returns
`{ok, 1}` — a two-tuple — where a *select* returns a three-tuple, so **one function's return type
is a union over the SQL verb**, which the type system cannot see; and a failed query returns
`{error, {error, error, <<"42P01">>, undefined_table, <<"relation ...">>, [...]}}` — epgsql's
`#error{}` record, whose record tag is *also* the atom `error`, trailing a proplist whose keys
vary by error class.

---

## The layout

```
lib/shop/reports/                  ← one module: the report server
  index.bs          types, records, the foreign declarations, behaviour
  opts.bs           connection config — as a proplist, measured to work
  init.bs           the connection process opens its connection
  handle_call.bs    one request: (:by_status, status, min, customer)
  handle_cast.bs    nothing to cast
  api.bs            the client wrapper — and the reply-channel finding
  sql.bs            query building over optional filters
  fetch.bs          the seam and the chain
  shape.bs          count-or-rows, then ValidateAs over the whole set
  rows.bs           tuple → record, status parse, the hand-written traverse
  summary.bs        totals by status — the group-by that needs no map
```

The connection lives in a `gen_server` (the "connection processes" of the candidate table): the
process owns the connection for its lifetime, `Init` opens it, and a crashed request crashes the
server for its supervisor to restart — which is also the whole resource-cleanup story. There is
no `try`/`finally` and no `defer`, and a valve chain that fails mid-pipeline runs no further
stage, so nothing in a request's own code path could close what it opened. **Ownership by a
process is what the language has instead of RAII**, and here it is the right thing rather than a
workaround.

---

## `index.bs`

```csharp
behaviour GenServer

using :epgsql {
    ConnectOutcome connect(list<term> opts)
    QueryOutcome   equery(term conn, string sql, list<term> params)
}

using :gen_server {
    term call(term ref, term msg)
}

type OrderStatus = :placed | :shipped | :cancelled

type ConnectOutcome = (:ok, term) | (:error, term)
type QueryOutcome   = (:ok, int) | (:ok, term, list<term>) | (:error, term)
type QueryOk        = (:ok, int) | (:ok, term, list<term>)
type InitOutcome    = (:ok, term) | (:stop, term)

type WireRow  = (int, string, int, string, term, term)
type Shipment = :never | (:at, term)

record OrderRow {
    Id: int, Customer: string, TotalCents: int,
    Status: OrderStatus, ShippedAt: Shipment, Meta: term
}

record Totals { Placed: int, Shipped: int, Cancelled: int }

type FetchError = (:pg, term)
                | (:not_rows, int)
                | (:unknown_status, string)
                | ValidationError

type Request = (:by_status, OrderStatus, option<int>, option<string>)
```

Three declarations here carry findings.

**`QueryOutcome` is the union over the SQL verb.** `equery` returns `{ok, Count}` for an update
and `{ok, Cols, Rows}` for a select (both measured), and a foreign declaration types the
*function*, not the call site. So every consumer of a select must still write the count clause —
`shape.bs` below pays it — because nothing can say "this string was a select". The type is
honest, exact, and one case wider than any single call can produce. → tickets 56, 09.

**`FetchError` wraps the pg reason, and the wrapper is forced.** epgsql's error payload is typed
`term` — it is a foreign record this language will never declare. `term` is the top, so an
unwrapped union `term | (:unknown_status, string)` *is* `term`: the member you wrote disappears
into the one beside it. `(:pg, term)` is the wrapper constructor 25c celebrated never needing —
its errors were distinct tuples and unified as a set; **a `term`-typed member re-imposes the
wrapper on everything it joins**. Same finding one line down: `Shipment` exists because
`option<term>` normalises to `term` (`term | :nothing` absorbs the `:nothing`), so a nullable
column of an unconstrained type cannot use `option<T>` at all. → tickets 09, 15.

**`WireRow` is positional.** Six columns, six components, and the correspondence to the `select`
list in `sql.bs` is checked by nothing — reorder the SQL and every row validates into the wrong
fields, `int`-vs-`string` collisions aside. The column metadata that would catch it (`Cols`, with
names) is right there in the three-tuple and is discarded by `shape.bs`. A checked
`select`-list-to-tuple correspondence is a thing no ticket has asked for.

## `opts.bs`

```csharp
private list<term> Config()

Config() -> [(:host, "localhost"), (:port, 5499), (:username, "probe"),
             (:password, "probe"), (:database, "shop"), (:timeout, 4000)]
```

epgsql's documented `connect/1` argument is a **map**, and B# has no map literal (25a's front
wall, ticket 48). This exemplar compiles because epgsql *also* accepts a proplist — **measured
live**, `connected_ok` — and a proplist is just a list of tuples, which the language spells
fine. The finding is the shape of the escape, not the escape itself: the idiomatic form of every
modern BEAM library's configuration is the one literal B# does not have, and this exemplar got
lucky that a legacy form survives. → ticket 48.

## `init.bs`

```csharp
public InitOutcome Init(list<term> opts)

Init(opts) -> :epgsql.connect(opts) switch {
    (:ok, conn) => (:ok, conn),
    (:error, e) => (:stop, (:cannot_connect, e))
}
```

`(:stop, reason)` is `gen_server`'s own vocabulary for a failed init — no `raise` needed, and the
supervisor owns the retry policy. The state is the bare connection pid, typed `term` throughout.

## `handle_call.bs`

```csharp
public (:reply, result<list<OrderRow>, FetchError>, term) HandleCall(Request req, term from, term conn)

HandleCall((:by_status, s, min, cust), from, conn) -> (:reply, Fetch(conn, s, min, cust), conn)
```

One request shape, so one clause, proved to cover `Request`. The reply's type is written out in
full here — hold that thought for `api.bs`.

## `handle_cast.bs`

```csharp
public (:noreply, term) HandleCast(term msg, term conn)

HandleCast(msg, conn) -> (:noreply, conn)
```

Mandatory, so present; nothing to say.

## `api.bs`

```csharp
public result<list<OrderRow>, FetchError> ByStatus(term pool, OrderStatus s, option<int> min, option<string> cust)

ByStatus(pool, s, min, cust) -> :gen_server.call(pool, (:by_status, s, min, cust))
```

**This function is the exemplar's sharpest finding, and it does not compile.** Ticket 14 §1's
answer to "where does the message type live" was: *on the client API function's signature*. For
the **request** direction that works and is what this file does — `OrderStatus`, `option<int>`
and `option<string>` constrain every request this module can build. But the **reply** comes back
through `:gen_server.call`, whose honest foreign type is `term` — and a body returning a `term`
where the signature declares `result<list<OrderRow>, FetchError>` is a containment error at the
return site. The language has no cast to paper over it, deliberately.

The two spellings that do compile are both wrong: declare the return `term` and the client API
stops being typed at all — 14 §1's promise evaporates exactly where it was made; or call
`ValidateAs<list<OrderRow>>` on the reply and **pay the full foreign-boundary traversal to
distrust your own server**, per call, on a value that `HandleCall`'s signature already proved.
The gap is structural: `gen_server:call` is the one place a typed value round-trips through
`term` *inside* the trust boundary, and nothing decided owns it. **Ticket 14 typed the request
direction and nobody ever typed the reply.** → tickets 14, 24, 18.

## `sql.bs`

```csharp
private (string, list<term>) Compose(OrderStatus s, option<int> min, option<string> cust)

Compose(s, :nothing, :nothing) ->
    ("select id, customer, total_cents, status, shipped_at, meta from orders where status = $1 order by id",
     [s])
Compose(s, :nothing, c) ->
    ("select id, customer, total_cents, status, shipped_at, meta from orders where status = $1 and customer = $2 order by id",
     [s, c])
Compose(s, min, :nothing) ->
    ("select id, customer, total_cents, status, shipped_at, meta from orders where status = $1 and total_cents >= $2 order by id",
     [s, min])
Compose(s, min, c) ->
    ("select id, customer, total_cents, status, shipped_at, meta from orders where status = $1 and total_cents >= $2 and customer = $3 order by id",
     [s, min, c])
```

**Ticket 17 job 1, third data point: the boolean ladder did not occur here either — but what
replaced it has its own cliff.** Query building over optional filters is not a ladder of
unrelated conditions; it is a dispatch over *presence*, and clause-order subtraction spells it
beautifully at small k: match `:nothing` first and the name that remains **is** the value —
`min` is an `int` in clause three because clause one subtracted the `:nothing` (measured; the
probe's clause multiplies by it). No `cond` case for the third exemplar running. → ticket 17.

The cliff is combinatorial rather than readable: **k optional filters is 2^k clauses**, and the
SQL string is near-duplicated in every one because the language has no way to build it — no
string concatenation (`+` is `int` only, binary construction is expression-position and unbuilt),
and no way to number the placeholders dynamically, since `$2` means *min* in one clause and
*customer* in the next. Every neighbouring language solves this with string/iolist building, not
with a conditional construct. At k=2 the duplication is ugly and honest; at k=4 nobody would
write this file. The missing thing is **iolist construction in the prelude**, not `cond`.
→ tickets 17, 48, and the stdlib-shape fog patch.

An asymmetry worth one sentence: the *outbound* status parameter is the atom itself — epgsql
encodes an atom as text (measured live, `[placed]` matched a `text` column) — while the
*inbound* status needs the four-clause parse in `rows.bs`. Encoding is free and decoding is
work, which is 25a's serialisation finding meeting its mirror image.

## `fetch.bs`

```csharp
public result<list<OrderRow>, FetchError> Fetch(term conn, OrderStatus s, option<int> min, option<string> cust)

Fetch(conn, s, min, cust) ->
    var (sql, params) = Compose(s, min, cust)
    :epgsql.equery(conn, sql, params) switch {
        (:error, e) => (:error, (:pg, e)),
        good        => good |> Shaped() |?> Checked() |?> Rowed()
    }
```

**25a's valve question, answered at the fourth data point — and the first link is not a valve.**
The chain wants to be `equery |?> Shaped() |?> Checked() |?> Rowed()`, and it cannot be, for a
reason 25c did not meet: the raw failure is `(:error, term)`, and `FetchError` wraps it as
`(:pg, term)` — but *"the only way to turn one error into another is the operator's absence"*
(the valve forwards errors unchanged), so the wrap forces a `switch` at the seam. After that
seam the error member is *subtracted*, and the compiler itself closes the door on `|?>`:

```
error: this |?> in Run is over a value that cannot fail
  (:ok, int) | (:ok, term, term) has no (:error, _) member, so the valve would never stop.
  Write |> instead.
```

(Measured today; the probe's control.) So the shape is `switch`, then `|>`, then `|?>` for the
rest — which composes and short-circuits correctly on every path (all measured in the lowering:
pg error, count shape, bad row, unknown status, clean set). **The valve earns its keep from the
second stage onward; the first stage after a foreign call belongs to `switch` whenever the
error needs a new name.** 25c hit the same wall for a different reason (the parser's remainder);
between them: the valve composes *interior* stages, and both ends of a real chain keep
falling out of it. → tickets 17, 49, 15.

The `var (sql, params) = ...` line is the destructuring bind doing honest work — a two-tuple
cannot fail to be a two-tuple, so no ceremony.

## `shape.bs`

```csharp
private result<list<term>, FetchError> Shaped(QueryOk q)

Shaped((:ok, n))          -> (:error, (:not_rows, n))
Shaped((:ok, cols, rows)) -> rows

private result<list<WireRow>, FetchError> Checked(list<term> rows)

Checked(rows) -> ValidateAs<list<WireRow>>(rows)
```

**`Shaped`'s success type is `list<term>` because `result<term, E>` does not exist.** The first
draft declared `result<term, FetchError>`, term being the honest width of a foreign payload —
and `term | (:error, E)` *is* `term`: the same absorption law §10 of the reference states for a
`ValidateAs` instantiation, except that at a hand-written signature nothing refuses it. The
union self-absorbed silently, the valve downstream then forwarded an `(:error, term)` the
declared `FetchError` does not cover, and the compiler reported **`fetch.bs` and `api.bs`** —
two files away from the signature that caused it. The repair is that the foreign declaration
promises `list<term>` (one `is_list` guard, exactly what the boundary rule prices at O(1)), and
the absorption never starts. Worth a rule somewhere: **a hand-written `result<term, E>` should
be refused at the declaration the way the `ValidateAs<term>` instantiation already is** — it can
only ever mean `term`, and the diagnostic for that lands nowhere near it. → tickets 15, 09.

`Shaped` is the count-clause tax from `index.bs` being paid: two clauses, proved exhaustive over
exactly the two ok shapes because the seam's `switch` subtracted the third (measured — drop the
count clause and the residual answers `Shaped((:ok, int)) -> ...`). The subtraction machinery is
doing real, visible work in a five-line function, and it is the best advertisement for the valve
design in any exemplar so far.

`Checked` is ticket 18's per-row question answered at set scale, with a measured surprise:

- **Affordable: yes.** One `ValidateAs<list<WireRow>>` call validates the whole set. The
  lowering measures 100,000 rows in the low tens of milliseconds — fine for a report server,
  and 25c's per-message worry does not compound at result-set scale.
- **The pathed error under-delivers on tuples.** Handed a two-row set whose second row has an
  atom where text belongs, the error is `(:error, (["[1]"], "(int, string, ...) | (int, string,
  ...)"))`. The row index is there — at 100k rows that is the part that matters — but the
  **component segment is missing**: the reference promises `"(2)"` for a tuple component, and
  the descent stops at the row. Worse, the *expected* string renders `term` as an expanded
  six-way union and **prints the same union member twice**. Raised as its own defect ticket
  (61) rather than argued here. → tickets 18, 23, and 61.

## `rows.bs`

```csharp
private result<list<OrderRow>, FetchError> Rowed(list<WireRow> rows)

Rowed([])          -> []
Rowed([w, ..rest]) -> Build(w) switch {
    (:error, e) => (:error, e),
    row         => Prepend(row, Rowed(rest))
}

private result<OrderRow, FetchError> Build(WireRow w)

Build((id, cust, cents, status, shipped, meta)) -> ParseStatus(status) switch {
    (:error, e) => (:error, e),
    s           => OrderRow { Id = id, Customer = cust, TotalCents = cents,
                              Status = s, ShippedAt = Shipped(shipped), Meta = meta }
}

private result<OrderStatus, FetchError> ParseStatus(string s)

ParseStatus("placed")    -> :placed
ParseStatus("shipped")   -> :shipped
ParseStatus("cancelled") -> :cancelled
ParseStatus(s)           -> (:error, (:unknown_status, s))

private Shipment Shipped(term v)

Shipped(:null) -> :never
Shipped(v)     -> (:at, v)

private result<list<OrderRow>, FetchError> Prepend(OrderRow row, result<list<OrderRow>, FetchError> rest)

Prepend(row, (:error, e)) -> (:error, e)
Prepend(row, rows)        -> [row, ..rows]
```

**Mapping a fallible function over a list costs three hand-written functions, and this is the
comprehension finding the candidate table promised.** `Rowed` recurses, `Build` converts one
row, `Prepend` threads the short-circuit — together they are a *traverse*, the
`list<result<T,E>>` → `result<list<T>,E>` collapse every functional language keeps in its
prelude. B# has no lambda yet, no `List.Map`, and the valve composes **stages, not elements** —
`|?>` cannot step *inside* a list. So every fallible per-element conversion in every program
will be these same three functions with different nouns. The prelude needs a traverse, and it
needs the polymorphic-signature half of §9 first (`fn(T) -> result<U, E>` is an arrow type).
→ tickets 17, 15, and the stdlib-shape fog patch.

Two smaller things, both already introduced: `ParseStatus`'s catch-all is legal because `string`
is open — the wire can say anything, so ticket 12 §2 has nothing to object to — while its three
success clauses are the inbound half of the free outbound atom. `Shipped` is the `option<term>`
collapse made concrete: `:null` is an ordinary atom the type system rightly refuses to conflate
with `:nothing` (measured: `Has(:null)` over `option<atom>` answers `:present`), so the nullable
column gets a purpose-built two-member union and every future nullable column of an open type
gets its own. → tickets 15, 48.

## `summary.bs`

```csharp
public Totals Summarise(list<OrderRow> rows)

Summarise(rows) -> Tally(rows, Totals { Placed = 0, Shipped = 0, Cancelled = 0 })

private Totals Tally(list<OrderRow> rows, Totals t)

Tally([], t)          -> t
Tally([r, ..rest], t) -> Tally(rest, Add(t, r))

private Totals Add(Totals t, OrderRow r)

Add(t, { Status: :placed } r)    -> t with { Placed = t.Placed + r.TotalCents }
Add(t, { Status: :shipped } r)   -> t with { Shipped = t.Shipped + r.TotalCents }
Add(t, { Status: :cancelled } r) -> t with { Cancelled = t.Cancelled + r.TotalCents }
```

**The group-by that needs no map — because the key is closed.** Revenue by status is a fold into
a record whose *fields are the groups*: `OrderStatus` has three members, `Totals` has three
fields, and the compiler proves `Add` exhaustive over the property patterns with no catch-all
(measured today — and dropping the `:cancelled` clause goes red). Ticket 12 §2's enforcement is
pulling *for* the program here: a fourth status added to the type finds every fold that forgot
it. This is also where records finally reappear in a non-aggregate exemplar — 25b and 25c
reported them absent; a database row is the record-shaped workload, and `with` earns its place
in the accumulator.

The boundary of the trick is one word wide: group by **customer** — an open `string` — and there
is no record to write, no map type in the prelude, and an assoc list of pairs as the only honest
spelling, O(n) per lookup and built by hand. **A closed key is a record; an open key is ticket
48, and nothing in between exists.** The map's fog patch for 48 says it waits on "no exemplar
declares one" — this exemplar *wanted* one and worked around it, which is the sharper datum.
→ ticket 48.

One diagnostic note from the probe's control: the missing-clause residual for `Add` prints
`Add({ Kind: :'P5b.Totals' }, { Kind: :'P5b.OrderRow' }) -> ...` — the record *tags*, without
`Status: :cancelled`, which is the one field that distinguishes the hole. The residual is exact
and the printed head is pasteable, but pasting it writes a catch-all-shaped clause, not the
missing case; the agent loop of ticket 23 would paste the wrong thing. Second family member of
25c's "the residual does not scale" — there it was too wide, here it is too shallow.
→ tickets 23, 04.

---

## Where the compiler stops today — measured, and it is not where the others stop

`check-exemplar-frontier.sh` records 25d's front wall as:

```
25d-database-querying   -   error: this directory holds `.bs` files and no `module` line
```

**The front wall is not a language construct.** 25a stops on a map literal, 25b on a lambda,
25c on binary construction — 25d gets past the parser whole, and the first refusal is the
**module-name decision this ticket recorded on 2026-08-17 and deliberately did not make** (the
directory names are dialect-illegal, so naming the exemplars' modules is a real choice). The
fourth exemplar's wall is an open decision, not a missing capability.

Behind it (measured in a scratch copy with `module Reports` inserted): **exactly one error** —
`api.bs`, the reply-channel finding, refused precisely as §`api.bs` above records. And behind
*that* (the reply untyped to `term` in the same scratch): **the module compiles**, `erlc` exit
0, every other file passing — the 2^k SQL dispatch, the seam-and-chain, the subtracted
two-clause `Shaped`, the hand-written traverse, the closed-key fold, all of it. One residual
warning, `Config/0 unused`, and even that is downstream of the same fog: wiring `Config` up
means calling `gen_server:start_link`, whose first argument is the module's own atom — the
exact name that is undecided.

So the database exemplar is **one decision and one design question away from compiling clean**,
which no other exemplar is within sight of. That is also the strongest statement yet of how far
the compiler has come under ticket 25's standing resource: the walls that remain are the map's,
not the parser's.

---

## What writing this actually surfaced

Seven things, ordered by how much they should worry you.

0. **The reply channel of a `gen_server` call has no type, and the language refuses the
   workaround.** `api.bs` written as ticket 14 §1 intends is a containment error — the reply is
   a `term` and no cast exists. Declaring `term` untypes the client API; `ValidateAs` on your own
   reply pays the foreign-boundary tax against a value the callee's signature already proved.
   The request direction was decided and the reply direction never was. → tickets 14, 24, 18.

1. **Ticket 12 §2 is enforced now, and 25c's "the skeleton does not implement the rule at all"
   is stale.** Measured today: a `_` over a closed three-atom residual is refused, naming
   `:cancelled | :shipped`, in exactly the words the map decided. F2 built it (2026-08-16) as
   the interval/refinement coupling demanded, and nothing on ticket 25's trail was ever
   corrected — 25c §6, this ticket's own results section, and LANGUAGE.md §5 all still said
   "not enforced". All three corrected today, dated. In this exemplar the rule bites *for* the
   program (`summary.bs`) and never against it — the deliberate-close count ticket 12 asked
   these exemplars to keep is still **zero**. → tickets 12, 4.

2. **A fallible per-element map is three hand-written functions, every time.** The valve
   composes stages, not elements; no lambda, no `List.Map`, no traverse. `rows.bs` is the
   exhibit. The prelude owes a traverse and the traverse needs §9's second half (an arrow type).
   → tickets 17, 15, stdlib fog.

3. **`term` poisons every union it joins, so the boundary re-imposes the wrapper constructor.**
   `(:pg, term)` because a bare `term` member absorbs its siblings; `Shipment` because
   `option<term>` *is* `term`; SQL NULL is `:null`, which `option<atom>` counts as present
   (measured); and a hand-written `result<term, E>` self-absorbs **silently**, with the
   containment error surfacing two files away from the signature that caused it (measured —
   this exemplar's first draft hit it, and the repair was promising `list<term>` at the foreign
   declaration instead). 25c's "no wrapper constructor" finding inverts at any boundary that
   hands back an unconstrained value. → tickets 09, 15.

4. **The valve loses both ends of a real chain.** The first link after a foreign call is a
   `switch` whenever the error needs a new name (the valve forwards errors unchanged), and the
   compiler then *requires* `|>` for the next link because the seam subtracted the error member
   (measured, including the diagnostic that says so). Interior stages compose perfectly, and
   `Shaped`'s two-clause exhaustiveness over the subtracted union is the design at its best.
   Fourth exemplar, fourth different edge of the same operator. → tickets 17, 49.

5. **`ValidateAs` at result-set scale: affordable, and the pathed error stops one level too
   high.** 100k tuple rows validate in tens of milliseconds, but the error names the row and
   not the component, renders `term` as a six-way expansion, and prints a union member twice.
   Raised as ticket 61 — the first compiler-defect ticket this exemplar series has produced.
   → tickets 18, 61.

6. **What the wire really carries, measured live:** `numeric` is `{unknown_oid, 1700}` plus
   text; a `timestamptz`'s seconds field is a float, a value B# cannot even write as a literal;
   `jsonb` rewrites its own bytes; `equery`'s ok-shape depends on the SQL verb; the error
   payload is a record-tagged tuple trailing a variable proplist. Schema advice falls out of
   the type system's shape: money in `int` cents, timestamps as `term` until a decision exists,
   and the `select` list is a contract nothing checks (`WireRow` is positional). → tickets 48,
   the float row of LANGUAGE.md §17, stdlib fog.

### What ticket 17 can take

Three jobs closed here. **Job 1 (the ladder):** third exemplar, still no `cond` case — query
building is presence-dispatch, not a boolean ladder, and its real cost is `2^k` clauses of
near-duplicate SQL, cured by iolist building, not by a conditional. **The `|?>` question:** the
valve is confirmed at three interior stages and confirmed *not* to reach either end of the
chain. **The comprehension question:** "comprehension/pipeline over rows" from this ticket's own
candidate table turns out to mean *traverse*, and the language does not have one.

### What ticket 18 can take

The untyped result set behaves exactly as designed at the entry — `term` until matched, one
`ValidateAs` for the deep check, affordable at scale — and the two places it leaks are both
*after* the entry: the reply channel (finding 0) and the positional `WireRow`/`select`
correspondence (nothing checks it). 18's boundary held; the trust boundary *inside* the
application is where this exemplar found the holes.

### Note for whoever writes the next exemplar

Two remain: **async processing** and the **dynamic web page**. The web page is the last of the
three binary-accumulation exemplars ticket 17 job 2 asked for, and after F13/F14 it would be the
first written with binary *construction* against a compiler that has binary *patterns* only —
its front wall is predictable from here. Async processing is the only exemplar with no decided
tickets left in its row (14 and 15 are both resolved), so it tests rather than informs, and
25c's `handle_info` findings already cover part of its ground.
