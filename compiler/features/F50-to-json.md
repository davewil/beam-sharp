# F50 — `ToJson<T>`, a value on the wire

**Status**      **done 2026-09-15** · [ENG-375](https://linear.app/davewil/issue/ENG-375) — 18 tests in
                `to_json_tests` and one in `api_tests`, 972 in the suite, up from 953; new gate
                `check-to-json.sh`, seen red on the tree before the build, with four stubs in its
                `--self-test`; `verify.sh` 43/43 twice from a clean clone (266 s, 257 s)
**Implements**  [ticket 77](../../wayfinder/issues/77-what-goes-on-the-wire.md): the wire form is the
                platform's, and `ToJson<T>` refuses at the declaration what the platform refuses at
                run time, naming the member. It **decides nothing**
**Depends on**  F18 (`ValidateAs<T>` and the generated validator this reuses as its guard), F49
                (`ValidationError` is a record, so the 422 body encodes), F3 (a record erases to a
                map carrying `Kind`), F47 (the same mapping, applied to the diagnostic term)
**Unblocks**    nothing recorded. The decode direction is [ticket 78](../../wayfinder/issues/78-the-decode-direction.md)
                ([ENG-373](https://linear.app/davewil/issue/ENG-373)) and is not this feature's

## What ships

```csharp
module Orders

record Order  { Id: int, Total: int }
record Parcel { Id: int, Note: option<int> }

public string OrderBody(Order o)
OrderBody(o) -> ToJson<Order>(o)

public string ParcelBody(Parcel p)
ParcelBody(p) -> ToJson<Parcel>(p)
```

```
$ bsc Orders OrderBody "{ Kind = :'Orders.Order', Id = 1, Total = 5 }"
"{"Kind":"Orders.Order","Id":1,"Total":5}"
$ bsc Orders ParcelBody "{ Kind = :'Orders.Parcel', Id = 1, Note = :nothing }"
"{"Kind":"Orders.Parcel","Id":1,"Note":"nothing"}"
```

Refused at the declaration, naming the member and the path to it:

```
$ bsc Refused
Refused/refused.bs:6:15: error: Outcome calls ToJson over a type with no wire form
  `(:error, { Kind: :'ValidationError', Expected: string, Path: list<string> })` is a tuple, and JSON has no encoding for one
  the type is: (:error, { Kind: :'ValidationError', Expected: string, Path: list<string> }) | { Kind: :'Refused.Order', Id: int, Total: int }
  Encode what the tuple holds instead: take a `result` apart in a switch
  arm and encode the value each arm has, or declare a record where the
  tuple is.
```

`ToJson<ValidationError>` is **not** refused, which is what F49 bought: the 422 body a handler
most wants on the wire goes out as `{"Kind":"ValidationError","Path":[".Total"],"Expected":"int"}`.
`ToJson<result<Order, ValidationError>>` is still refused, on the outer tuple, exactly as ticket 77
wrote it.

## The compiler delta

Ticket 77's four seams, and no others:

1. **`bs_check`** — `ToJson` joins `codegen_obligations/0` and `built_obligations/0`. `type_of/3`
   gains the clause: `T` ground (27 §8), the argument contained in `T` through the same
   `arg_diags/7` a call's argument uses, result `string`. `unencodable/1` is the walk, over the
   **resolved** type.
2. **`bs_diag`** — one new tag, `unencodable_member`, carrying the obligation, the type, the
   member, the path and the kind of member it is; four repairs, one per kind.
3. **`bs_emit`** — a generated encoder per distinct `T`, named `…@j`, reached by a bare local call
   the way `ValidateAs<T>`'s root wrapper is.
4. **`STANDARD-ENVIRONMENT.md`** — the row, **built**, so `check-status-claims.sh` has a status to
   read and probes the entry.

### The refusal runs from the declaration pass, and that is new

`ToJson<T>` sits in a clause body, and a body is typed by `check_dir1/3` alone — `bsc --api` runs
`exports_of/2`, which reads declarations. So a refusal met in `type_of/3` would be a refusal
`--api` never meets. Measured on the tree before this feature: a module whose body writes
`ValidateAs<fn(int) -> int>` — refused by a compile since F18 — was answered by `bsc --api` with
`term Check(term)` and status 0.

Whether `T` has a wire form is a fact about `T` alone, so `to_json_refused/2` walks the clause
bodies for `ToJson` nodes and raises, and **both** `check_dir1/3` and `exports_of/2` call it.
`--api` on a module this refuses now prints nothing and exits 1 (F50.11). The two older refusals
with the same gap, `name_redeclared/1` and `compiler_known_redeclared/1`, are
[ENG-371](https://linear.app/davewil/issue/ENG-371) and are untouched here.

### The walk is over the resolved type

`result<T, E>` hides its tuple behind a parametric alias, and `type Slot = Pair | :empty` over
`type Pair = (int, int)` hides one behind two plain aliases and a record field. A walk over the
members **as written** accepts both and crashes in `json:encode` at run time, which is what the
gate's `written_walk` stub is. Reading `bs_types` parts after `resolve/2` finds them by
construction — the same reason *written union members are not normalised members*.

Refused: a tuple part, an arrow part, a `bins` part holding `other` (so `binary`, while `string`
is `[utf8]` and passes), and any position where `term` is the type — `term` holds all three. A
recursive type terminates on a `Seen` list of binder names, as `has_arrow/2` does.

### The guard at the site, and why it is the validator

Ticket 18 §1(c) makes a guard unconditional where generated code consumes a value, and 26 §4 puts
the **exact field-set test** at this exact site, because an encoder would otherwise serialise
fields no type declares. A public `Order` parameter is guarded on its tag alone (F3.9), so a map
carrying `Secret` reaches the body already.

The guard emitted is the validator `ValidateAs<T>` would generate for the same `T`: it tests a
closed map's exact key set with `map_size/1`, every field's type, and a `string`'s UTF-8. So the
encoder is handed a value that inhabits `T` or nothing at all:

```erlang
'bs@validate@1@j'(Bs@x) ->
    case 'bs@validate@1'(Bs@x, []) of
        {ok, _}        -> iolist_to_binary(json:encode(Bs@x));
        {error, Bs@er} -> erlang:error({to_json, Bs@er})
    end.
```

Two consequences, both taken knowingly:

- **It is deeper than 26 §4's `map_size` alone**, and it costs a second walk of the value beside
  `json:encode`'s own — O(size), the same order, twice. The narrower test would leave an
  undeclared field *inside* a nested record on the wire, and `json:encode` is what publishes it,
  so the narrow test would keep the promise only at the top.
- **The crash reason is this feature's, not a ticket's**: `{to_json, ValidationError}`, so a
  reader gets the path and the expected type rather than `badarg`. `bsc` prints it as
  `crashed: to_json {Kind = :'ValidationError', Expected = "…", Path = []}`.
  **It is provisional, and it is the one decision this feature had to take to ship.** 18 §1(c) and
  26 §4 both say a guard is emitted and neither says what the failure is, so the shape — and the
  depth above it — are [ticket 82](../../wayfinder/issues/82-a-failed-encode-at-run-time.md),
  [ENG-382](https://linear.app/davewil/issue/ENG-382). `bs_emit:json_form/1` is the single site and
  F50.8's pair is what changes when it is answered.

## What the build found

**Key order on the wire is the VM's atom-creation order, not the declaration's.** Measured on OTP
28.5: `json:encode(#{'Kind' => …, 'Id' => 1, 'Note' => nothing, <<"x">> => 1})` wrote `Kind` first
although `'Id'` sorts before it. Ticket 77's mapping row reads *"`Kind` carrying the minted tag,
then the declared field names"*, which describes the object's **members**, and the order it
implies is not a property the platform has — the same effect ENG-349 records on the term channel.
The decision stands (the wire form is the platform's, order and all); the ticket carries a dated
note, and every test here compares `json:decode` of the output rather than its text. A program
that needed a fixed key order would be the language owning the mapping, which ticket 77 refused.

**The refusal names the expansion, not the type the author wrote.** `ToJson<result<Order,
ValidationError>>`'s member prints as `(:error, { Kind: :'ValidationError', Expected: string, Path:
list<string> })`. That is [ENG-353](https://linear.app/davewil/issue/ENG-353)'s class, already
filed against the absorbed-member refusal, and this diagnostic inherits it rather than adding a
printer of its own.

**Exemplar 25a cannot take the spelling yet.** ENG-375 asked for `ToJson` in 25a's handler *where
the mapping admits it*; it does not. `encode_response.bs` encodes a `Response`, which is
`(int, term)` — a tuple holding a `term`, and both are refused. The prototype's `Json.Encode(body)`
stands, and its friction 0 is now half repaired: the 422 body encodes, the `result` and the
`term` body do not.

## The scenarios

| | what is exercised | what it establishes |
|---|---|---|
| F50.1 | `OrderBody` on a good order | a record is an object carrying `Kind` and its fields |
| F50.2 | `ParcelBody` with and without a note | `:nothing` is the string `"nothing"`, key present — 26 §4's `null`-or-omit question, answered by the platform |
| F50.3 | `Outcome`, the validator's own failure | the 422 body on the wire, which F49 made possible |
| F50.4 | `Flags`, `Batch`, `Counts` | `:null`/`:true`/`:false` are JSON literals, a list is an array, `map<K, V>` stringifies its key |
| F50.5 | `ToJson<result<Order, ValidationError>>` | refused, naming the tuple member, at the top of the type |
| F50.6 | a tuple two aliases and a field down | the walk is over the resolved type — the pair that matters, beside F50.5 |
| F50.7 | an arrow, `binary`, `term`, a tuple map key; `list<string>` beside them | each kind refused at its path, and `string` accepted |
| F50.8 | an order carrying `Secret`, and one whose `Total` is text | the value is guarded before it is encoded: neither goes on the wire |
| F50.9 | `ToJson<T>` under a polymorphic signature | a codegen obligation needs a ground `T` |
| F50.10 | `ToJson<Order>(n)` where `n` is an `int` | the argument is held to the containment a call's argument is |
| F50.14 | a recursive record, and a tuple inside one | the walk terminates on a `Seen` list of binder names — without it a self-referential record neither refuses nor accepts, it hangs — and still finds the tuple, at `.Value` |
| F50.11 | `bsc --api` on a refused module | status 1, nothing on stdout — the declaration pass runs the walk |
| F50.12 | the prose for the tuple behind the aliases | the message names the obligation, the member and the path, and `bs_diag` computes all of it from the term |
| F50.13 | `check-to-json.sh` | the wire, the two refusals, the crash and `--api`, each asserted on a run |

## The gate

`check-to-json.sh` compiles ticket 77's program and two refused modules, runs six probes and
matches the wire **by fragment** — `"Kind":"Orders.Order"`, not the whole object, because the key
order is not a fact about the program. Its four `--self-test` stubs are `written_walk` (the walk
reads the members as written), `check_only` (the refusal reaches a compile and not `--api`),
`unguarded` (the site encodes without the guard, so `Secret` goes out) and `broken` (nothing
compiles, so an absence is never read as a pass). The `check_only` and `unguarded` stubs carry
output measured on the tree before the build, not text written to agree with the gate.

## Out of scope

- **The decode direction** — [ticket 78](../../wayfinder/issues/78-the-decode-direction.md),
  [ENG-373](https://linear.app/davewil/issue/ENG-373). `json:decode` returns binary keys and a
  binary tag, which `ValidateAs<T>` refuses; nothing here changes that.
- **`float`** — [ENG-378](https://linear.app/davewil/issue/ENG-378). Ticket 77 measured its row
  (`json:encode(1.5)` is `1.5`); the walk gains nothing when the part lands, since a number has a
  wire form.
- **`found`**, F18 (b)'s third field — rendering an arbitrary foreign term is this mapping applied
  to `term`, which is refused, so it stays absent for the reason F18 gave.
- **The two older `--api` gaps** — [ENG-371](https://linear.app/davewil/issue/ENG-371).
- **A corpus example and a roster row** — [ENG-384](https://linear.app/davewil/issue/ENG-384).
  `demonstrated_surface/0` gives `ValidateAs<T>` and `ParseAtom<T>` a row each, so that the corpus
  cannot quietly drop them; the third obligation has none, and nothing in `compiler/examples/`
  writes `ToJson`. A row is not a line: `check-tour.sh` part 2 requires the appendix to name the
  capability and part 4 then requires the page to be republished and restamped, and TOUR §15 —
  *the two constructs that cross the boundary* — is a title with three constructs under it now.
  That is a unit of its own, and this feature ships a `LANGUAGE.md` block and a gate instead.
