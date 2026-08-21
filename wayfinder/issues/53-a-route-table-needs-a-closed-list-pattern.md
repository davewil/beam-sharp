# 53 — A route table needs a closed list pattern, and ticket 08 refused one

Type: grilling
Status: open — [ENG-235](https://linear.app/davewil/issue/ENG-235)

Raised 2026-08-21 out of the first run of `compiler/bin/check-exemplar-frontier.sh`, which compiled
[exemplar 25a](../prototypes/25a-http-api-server.md) with the real compiler for the first time.

## Question

25a's route table is the exemplar set's headline case — ticket 25 introduces it as *"routing as
multi-clause dispatch on method and path"*, the shape the whole design was supposed to flatter:

```csharp
Route(:get,    ["orders"],     _)     -> (200, Orders.All())
Route(:get,    ["orders", id], _)     -> Fetch(id)
Route(:post,   ["orders"],     body)  -> CreateOrder(body)
Route(:delete, ["orders", id], _)     -> Delete(id)
```

`bsc` refuses all four heads, and not as a gap:

> `route.bs:13: error: a list pattern needs a rest` — *write `[h, ..t]`. Prefix-plus-rest is the
> only list pattern.*

That is [ticket 08](08-head-and-guard-syntax.md) working exactly as decided. The consequence is the
part nobody costed: **there is no spelling for "a path of exactly two segments."** `["orders", ..t]`
matches `/orders`, `/orders/42` and `/orders/42/lines/7` alike, so the first clause swallows every
route beneath it and the arity distinction a router is *made of* cannot be written in a head.

**Does the language get a closed list pattern, and if not, what does a route table look like?**

## Why this was not visible until now

Ticket 08 was settled on the page. 25a was written on the page. Neither had ever been through the
compiler — 25a's front wall is the map literal in `create_order.bs`, three files earlier, and the
route table sits behind it where `bsc` never reached. The measurement that surfaced this only
became possible when F11/F15 built the module system and F3 built records, and only became
*routine* with the frontier gate.

**So this is not a regression and nothing broke.** It is a decision that has been owed since
2026-08-12 and could not be seen, which is the failure mode the map's own tracker-arithmetic bullet
keeps recording in a different costume: a thing is owed, nothing holds it, and no query can find it.

## The candidates, none costed

1. **A closed list pattern** — `[a, b]` meaning exactly two. Tier 1 for both audiences: C# list
   patterns (`[1, 2]`) and TypeScript tuple types both mean exactly-this-many. The cost is the one
   ticket 08 weighed and refused; read that ticket before re-litigating it, because the refusal has
   a reason and this is evidence against it rather than a discovery that it was arbitrary.
2. **A length guard** — `Route(:get, segs, _) when Length(segs) == 2 ->`. Costs nothing new and
   moves the discriminator out of the head, which is the one place this language exists to put it.
   Also defeats exhaustiveness: a guard leaves the residual open, so the router loses the check.
3. **Routes are not lists.** A path could arrive as a record, a tuple, or a type the boundary mints
   — 18's two-tier boundary already decides what a foreign request looks like on the way in. This is
   the candidate that makes the problem disappear rather than solving it, and it should be taken
   seriously for that reason rather than dismissed for it.
4. **A pattern over a refined `list<T>`** where the refinement fixes the length. Ticket 20 §5's
   machinery, pointed at a shape it was not built for; unknown whether the algebra closes.

## What it must not become

**Do not re-open ticket 08's `&&`/`||`, its guard syntax, or prefix-plus-rest as the general rule.**
The general rule is fine and this is one shape it does not serve. Ticket 42's precedent is the model
to follow — *borrow the construct, or don't borrow the glyph* — where a refused spelling was
replaced by a relational family rather than by an exception.

**And weigh candidate 3 first.** [Ticket 31](31-composable-middleware.md) has just resolved by
finding that a web stack writes a pipeline rather than a ladder, which dissolved 25a's other
headline friction instead of building a construct for it. The same move may be available here, and
this ticket would be the second time the exemplar's shape, not the language, was what was wrong.

## Notes

Blocks nothing. Most valuable resolved **before** 25a's pipeline rewrite rather than after, since
the rewrite will touch `route.bs` and would otherwise bake in whichever spelling the author reached
for. That makes it the inverse of tickets 48 and 49, which both want the rewrite to have happened
first.

The exemplar also has three defects that are **not** this ticket and want fixing in the write-up
directly: no `module` line, a `using` in `index.bs` that the other files expect to inherit, and a
`Request` record the valve chain reads five fields from and nobody declared. All three are recorded
in `compiler/examples/exemplars/README.md` under "Behind the wall".
