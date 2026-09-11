# F43 — the key walk over `map<K, V>`

**Status**      **done 2026-09-11** — 18 tests in `map_validate_tests`; F33's
                `validate_as_over_a_domain_map_is_refused_test` flipped to a compiles
                assertion; 816 in the suite, up from 798. No new gate: the ticket's program
                is a must-compile block `LANGUAGE.md` §4 gained, marked BROKEN by
                `check-language.sh` before the build and ok after it. `./bin/verify.sh`
                green **twice from a clean clone**
**Implements**  [ticket 18](../../wayfinder/issues/18-boundary-defence.md) §2's crossing for a
                structured foreign return — *`term`, then `ValidateAs<T>`* — for the one `T`
                that route was refused for; [ticket 48](../../wayfinder/issues/48-a-map-type-in-the-prelude.md)'s
                type, which F33 shipped with the validator deferred and nothing tracking it
**Closes**      [ENG-356](https://linear.app/davewil/issue/ENG-356). Unblocks
                [ENG-323](https://linear.app/davewil/issue/ENG-323) (the pattern form) and
                [ENG-324](https://linear.app/davewil/issue/ENG-324) (`Map.Get`), which both
                named this walk as their prerequisite
**Decides**     one thing, the one the ticket delegated: **the path segment for a map entry
                is the key in brackets, spelled as the language writes it** — `["views"]`,
                `[:views]`, `[7]` — and a key with no literal is not spelled at all. See
                *The segment* below for why that second half is a rule and not a gap
**Depends on**  F18 (the validator, its internal `{ok, V} | {error, {Path, Expected}}`
                protocol, and the blame rule); F33 (the `{dom, K, V}` member); F40 and F42,
                which together are why a foreign `map<string, int>` return now has exactly
                one route and this is it

## What was there

Ticket 18 §2 sends anything one guard cannot decide across as `term` and then through
`ValidateAs<T>`. F40 built the refusal at the declaration and made that route the edit line:
*declare it `map<term, term>`, then `ValidateAs<map<string, int>>` where it is used*. At the
other end of the route, `ValidateAs` over a `map<K, V>` was refused by name — F33 shipped the type
and found that `bs_emit`'s `map_cases/1` built its worklist from two comprehensions that *filter*,
so a domain member was dropped and the generated validator certified every term it was handed.
The refusal was the honest stopgap; ENG-354's own text recorded that building the refusal
*"leaves a program that receives `map<string, int>` from Erlang with no way to establish it"*.

On `f5b971f`:

```csharp
module Analytics

type ViewCounts = map<string, int>

using :analytics_db {
    map<term, term> latest_row(binary site)
}

public result<ViewCounts, ValidationError> PageViews(binary site)

PageViews(site) -> ValidateAs<ViewCounts>(:analytics_db.latest_row(site))
```

```
Analytics.bs:11:20: error: PageViews validates against a map type whose keys are not
  a fixed list
```

## The program

The same one, after. Read through the CLI with `:maps.from_list` standing in for the database:

```
$ bsc Analytics.bs PageViews '[("views", 3)]'
#{<<"views">> => 3}
$ bsc Analytics.bs PageViews '[("views", :many)]'
(:error, (["["views"]"], "int"))
$ bsc Analytics.bs PageViews '[(:views, 3)]'
(:error, (["[:views]"], "string"))
$ bsc Analytics.bs PageViews '[((1, 2), 3)]'
(:error, ([], "map<string, int>"))
```

The well-formed map prints in Erlang's spelling because a map with a non-atom key has no
beam-sharp one (ticket 48, ENG-351). The first payload is what `bsc` prints, quotes unescaped;
the first draft of the §4 prose had `[\"views\"]` from memory, which is ENG-248's lesson
arriving on schedule.

## What shipped

**A domain member is one more `map_case`.** `map_cases/1` partitions `{dom, K, V}` out before
anything groups by field set — `map_key/1` and `shape_case/1` read a 2-tuple and a 3-tuple
would crash them, which is the F33 hazard from the other side — and yields `{one, none, D}` for
it. The clause is `is_map` and `not is_map_key('Kind', …)`, ticket 48 Q3 as a guard, then the
walk where either half is narrower than `term`. `map<term, term>` is the guard alone, the same
test F42 emits for it at a foreign return.

**The walk is a second walker beside the list's.** `Name@d(Iter, Path)` takes an **ordered**
iterator and one entry at a time checks the key against `K`'s validator and then the value
against `V`'s, under the entry's segment, returning the first failure unchanged so the deepest
blame wins, as `chain/3` does for fields. Ordered costs O(n log n) where the list walker is
O(n) — ticket 11 §2's cost is still one the sender's `n` controls — and buys a blame that can be
stated: *the first offending entry in key order*. Unordered, two runs over equal maps could
blame different entries, and a test could not say which.

**The segment.** `bs@validate@key/1` is emitted once per module that walks a domain and spells
an integer as digits, an atom bare after the sigil exactly when `bs_types:atom_str/1` would
print it bare and quoted otherwise, and a binary as a string when it is UTF-8. **Anything else
is `none`.** A tuple has a spelling as a *value* and no spelling as a place the author could
write in a path; a binary that is not text has none at all. Rendering an arbitrary term to a
`string` inside generated code is ticket 16 §4's language-published serialisation mapping,
owed and unwritten, and F18 (b) recorded that inventing a validator-only spelling would leave
the language with two renderings of one term. So the segment is computed before the entry is
checked and only *read* on failure: an entry under an unspellable key passes when it is
well-formed, and when it fails the blame stops at the map with the map's type expected — the
rule the list walker already applies to an improper tail, *the blame is the list, not an
element of it*.

## Three things the build found

**A brace map beside a domain is ambiguous, and the F33 refusal had been hiding it.** F18's
blame rule descends only where exactly one candidate can match. `{ X: string } | map<atom, int>`
both admit `#{}`, and `#{X => 1}` is in the domain while matching the brace shape, so a
pattern-first walk would have refused it at `.X` — a false refusal of a member of the type.
Named-field members without `Kind` beside a domain therefore become one `{any, …}` case: every
candidate is tried and the blame stays at the node with the whole type expected. A **record**
carries `Kind` and the domain excludes it, so the two are disjoint and each keeps its own clause
and its own blame — `Order | map<atom, term>` is the realistic mixed union, and it loses nothing.

**Two domains in one type never reach the emitter.** `map<string, int> | map<atom, atom>` is
refused at its declaration as an `indiscriminable_union` (F29): no pattern reaches either member
and no guard separates them. The test written for it went red on that refusal and was replaced
by a note. `dom_cases/1` still answers alternatives for the shape rather than crashing, for the
reason `components/1`'s comment gives.

**The segment must be lazy or `map<term, int>` refuses valid maps.** The first design of the
walker spelled the key first and treated `none` as a failure on sight. `map<term, int>` admits
`#{{1, 2} => 3}`, and that shape would have refused it — caught on paper before the walker was
written, not measured, and the case has its own test so the next rearrangement measures it. The
`none` is carried in the path and consulted only when a check fails, which is the difference
between *cannot name this entry* and *this entry is wrong*.

## What is asserted, and where

`map_validate_tests.erl`, at the boundary — source in, a loaded `.beam` called, the value it
returns compared:

| | asserts |
|---|---|
| F43.1 | a well-formed map comes back unchanged; `#{}` passes; a non-map blames the term itself |
| F43.2 | a bad value is blamed at its key with the value type expected; a bad key at itself with the key type; the first offender in key order; the path composes through a map and through a record field into a map |
| F43.3 | the three spellings — digits, a bare atom, a quoted atom — and that a tuple key or a non-text binary key blames the map |
| F43.4 | an unspellable key under a well-formed entry passes; the same key under a bad one blames the map |
| F43.5 | `Kind` is excluded; `map<term, term>` is one test and admits any `Kind`-less map |
| F43.6 | a record beside a domain keeps its own blame; a bare brace map beside a domain is an alternative, so a value in either passes and a value in neither blames the node |
| F43.7 | the ticket's program, through `:maps.from_list`, both arms |

Nothing pins the emitted abstract code. Rearranging the walker must not turn the file red.

## What it leaves

Nothing of its own. The pattern form (ENG-323) and `Map.Get` (ENG-324) were waiting on this and
are not blocked now; ENG-324 still owes David the naming call for the assertive form, which this
does not touch.
