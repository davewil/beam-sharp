# 53 — A route table needs a closed list pattern, and ticket 08 refused one

Type: grilling
Status: **resolved 2026-08-21, against its own premise** — [ENG-235](https://linear.app/davewil/issue/ENG-235).
See [Answer](#answer) at the end.

Raised 2026-08-21 out of the first run of `compiler/bin/check-exemplar-frontier.sh`, which compiled
[exemplar 25a](../prototypes/25a-http-api-server.md) with the real compiler for the first time.

> **THE CENTRAL CLAIM BELOW IS FALSE AND IS LEFT STANDING ON PURPOSE.** The ticket says there is
> no spelling for "a path of exactly two segments". There is: **`[a, b, ..[]]`** — prefix-plus-rest
> where the rest is `[]`, which is a pattern like any other. It compiles, it runs, and it was
> available the whole time. Measured in [prototype 53a](../prototypes/53a-closed-list-patterns.md)
> within hours of the ticket being raised.
>
> It is left in place because the ticket was written from reading `bs_parser.yrl`'s
> `bin_segment`-adjacent productions and one diagnostic, and *"a list pattern needs a rest"* reads
> like a refusal of closed lists when it is a refusal of a *missing* rest. That misreading is worth
> more on the record than a tidied ticket would be — it is the same failure as the exemplars
> README's clause-name paragraph, which pointed the wrong way for days because somebody read a
> summary of a decision instead of running the compiler.

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

---

## Answer

**No language change. The spelling exists, and 25a's route table was written wrong rather than
refused.** All of it is measured in [prototype 53a](../prototypes/53a-closed-list-patterns.md).

`[a, b]` is refused, exactly as ticket 08 decided. But **the rest of a prefix-plus-rest pattern is
itself a pattern**, and `[]` is a pattern, so the form closes itself:

```csharp
Dispatch(:get,    ["orders", ..[]])     -> :index
Dispatch(:get,    ["orders", id, ..[]]) -> :show
Dispatch(:post,   ["orders", ..[]])     -> :create
Dispatch(:delete, ["orders", id, ..[]]) -> :destroy
Dispatch(_,       _)                    -> :not_found
```

```
$ bsc … Dispatch ':get' '["orders"]'                 -> :index
$ bsc … Dispatch ':get' '["orders", "42"]'           -> :show
$ bsc … Dispatch ':get' '["orders", "42", "lines"]'  -> :not_found
```

`/orders/42/lines` falls through instead of being swallowed by `:show`, which is the property the
ticket said could not be expressed. Nothing was built and no rule was bent: this is ticket 08's own
grammar used twice.

### Of the four candidates

Candidate 1 (a closed list pattern) is **already true** and needed no decision. Candidates 2 and 4
are moot. Candidate 3 — *routes are not lists* — remains available and is now a smaller question
than it looked, since the list form works; it should be reopened only if an exemplar demands it,
not on the strength of this ticket.

### What survives, and what it is now behind

**The read cost.** `["orders", id, ..[]]` says "exactly two" in punctuation neither audience
recognises — C# and TypeScript both spell it `["orders", id]`. Whether the closed form deserves
sugar is a real question and is the only design question this ticket leaves.

**It is second in line.** Measuring the premise found that a closed-length clause is **invisible to
the exhaustiveness checker**, and that a multi-element prefix is credited with every non-empty list
— so `Shape([]) / Shape([a, b, ..t])` compiles clean and crashes on `[7]`. Raised as
[ticket 54](54-list-length-in-the-algebra.md) / [ENG-236](https://linear.app/davewil/issue/ENG-236).

The route table above is therefore exhaustive **only by virtue of its catch-all**; the compiler is
proving nothing about the routes themselves. Sugar over a form the checker cannot see would make
the surface read more like C# while the guarantee behind it stayed absent, so 54 comes first and
the spelling is decided after there is something real underneath it.

### The shape of this resolution is the reusable part

The ticket was raised from a diagnostic and a grammar file, and it was wrong. It took three probe
files and about twenty minutes to find out. **A ticket whose premise can be compiled should be
compiled before it is argued**, and this repo now has a `check-exemplar-frontier.sh` precisely
because a claim about the language that nobody executed is the failure mode it keeps meeting.
