# F69 — `FromJson<T>`: JSON text to a wire value

**Status**      **in progress** — built 2026-10-09, 20 tests in `from_json_tests`;
                closing is David's call
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md)
                Q10. Decides nothing; see *One reading of the ticket*
**Closes**      [ENG-410](https://linear.app/davewil/issue/ENG-410), three of its
                four done-when clauses; see *Left*
**Unblocks**    the reply side of exemplar 25f; see *Left*
**Depends on**  F18 (`ValidateAs`), F50 (`ToJson`), F58 (string keys), F59 (open
                field sets), F61 (the absent option key), F68 (string-literal
                types)

## Why this one now

Every answer ticket 78 gave starts from a decoded term. The step before it,
text to term, was 25f's friction 5: the author declared `json:decode` by hand,
and because `result<term, foreign_error>` collapses, the declaration listed six
members. Then each call needed two arms, one for text that is not JSON and one
for JSON of the wrong shape.

## The program

```csharp
module Reply

type ReplyWire = { "id": option<string>, "model": string, "refusal": string | :null, .. }

public result<ReplyWire, ValidationError> Parse(string body)
Parse(body) -> FromJson<ReplyWire>(body)
```

## The rule

- `FromJson<T>(text)` takes a `string` and returns `result<T, ValidationError>`.
- It is the platform's `json:decode`, then what `ValidateAs<T>` does to the
  decoded term. It converts what `ValidateAs` converts and nothing else: an
  absent key at an `option<T>` field is `:nothing` (F61), `null` stays `:null`.
- Text that is not JSON is a value, not a crash: a `ValidationError` with
  `Path = []` and `Expected = "JSON"`.
- `T` must be ground, and must be a target `ValidateAs<T>` accepts: no arrow,
  no collapse, no pair of members a validator cannot tell apart.
- A `T` holding a record, at any depth, is refused at the call with
  `undecodable_member`, kind `record`, naming the record, its path and ticket
  78 Q4's deferral. A field set with a hand-written `Kind` key is not a record
  and is not refused.
- A `T` holding a tuple, an arrow, `binary`, `term` or a process, reference or
  port is refused with the same diagnostic, as `ToJson` refuses to write one.
- An open field set is read. `ToJson` still refuses to write one.

## One reading of the ticket

Q10 says *"`T` is any type `ToJson` accepts, except one containing a record"*.
`ToJson` refuses an open type (Q3), and Q10's own program is
`FromJson<ReplyWire>`, where `ReplyWire` is open because OpenRouter's reply
carries keys TypeSafe's does not. Taken to the letter, the sentence refuses the
program it was written under. This build reads an open type and keeps every
other refusal `ToJson` makes. `ToJson`'s reason for refusing one, that it would
publish keys no type declares, is about writing. David's answer line names the
record refusal alone. Reported to David with the build.

## What changed

- `bs_check`: `FromJson` joins `codegen_obligations/0` and
  `built_obligations/0`. Its `type_of` clause checks the argument against
  `string` and then shares `validated/4` with `ValidateAs`, which is that
  clause's target check moved into a function.
- `bs_check`: the declaration pass that refuses `ToJson` over a type with no
  wire form walks `FromJson` sites too, so `bsc --api` reports the refusal.
  `unencodable/4` takes a direction: `decode` lets an open member stand and
  refuses a record.
- `bs_diag`: `undecodable_member`, with a headline of its own for a record and
  a repair per kind written for the reading side.
- `bs_emit`: one `bs@validate@N@t/1` per distinct `T`: `json:decode` in a `try`
  whose `catch` returns the `ValidationError`, and whose success calls the root
  a `ValidateAs<T>` calls. Only the decode is under the catch.
- `bs_parser.yrl` needed no change: the bracket production takes any `uident`
  and the checker holds the closed set.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F69.1 | the program above on a reply with all three keys | the decoded value |
| F69.2 | truncated text, empty text, JSON followed by more text | `ValidationError`, `Path = []`, `Expected = "JSON"` |
| F69.3 | `"model": 7`; a JSON array | refused at `["model"]`, `Expected = "string"`; refused at `[]` |
| F69.4 | no `id`, an extra `cost`; `"id": null` | `"id" => :nothing`, `cost` kept; refused at `["id"]` |
| F69.5 | one exact `T` under `ToJson`, `FromJson` and `ValidateAs`; `body \|> FromJson<T>()` | what `ToJson` wrote, `FromJson` reads; an extra key is refused |
| F69.6 | `FromJson<Order>`; a record under `"usage"` in a list; `{ Kind: :invoice, .. }` | `undecodable_member`, `record`, `path = []`; `path = ["usage"][_]`; compiles |
| F69.7 | a tuple field; `binary`; `map<string, term>`; an arrow field; `list<pid>`; each one's prose; an open type read, then written | `tuple`, `binary`, `term`, `arrow`, `opaque`; the member, its path and what to read instead; read; `unencodable_member`, `open_map` |
| F69.8 | `FromJson<T>` over a type variable; a `binary` argument; two type arguments; `A \| B` open and untagged | `obligation_over_type_variable`; `arg_not_accepted`; `obligation_arity`; `validate_indiscriminable` |
| F69.9 | `int Read(string s) -> FromJson<int>(s)` | `return_not_declared` |
| F69.10 | the record refusal's prose | names the function, the record, its path and ticket 78 Q4 |
| F69.11 | the record program under `bsc --api` | refused, rc 1 |

## Out of scope

- Reading a record back from JSON: deferred by ticket 78 Q4, requirements in
  the ticket.
- `FromJson` over a `binary`. Q10 says `string`; 25f's `Parse` validates the
  body as a `string` first (25f write-up, friction 9).
- Which key an absent required key is blamed at. It is `[]`, as F61 recorded.
- A type no JSON can inhabit for a reason other than the refusals above: an
  atom other than `:null`, `:true` or `:false`, a name key, a `map<int, V>`.
  Each compiles and fails at run time, as ticket 78 Q9 decided for the atom.
  So `FromJson<T>(ToJson<T>(v))` gives `v` back for a string-keyed type and is
  an error for `type Level = :low | :high`, which `ToJson` writes as `"low"`.

## Found by the review, not fixed here

- A hand-written `{ Kind: :'P.Thing', "a": int }` is refused as "`Thing` is a
  record". `record_name/1` takes any dotted tag for a minted one.
- The `validate_indiscriminable` refusal says the function "validates into a
  union" and does not name `FromJson`.

## Left

ENG-410's done-when has four clauses. Three are met. The fourth is *"25f
compiles with its hand-declared `Json` union and `using :json` block removed"*,
and it is met in part:

- **Done.** `json:decode` is no longer declared, `Parse` is one `FromJson`, and
  `decode.bs` is 20 non-blank lines where it was 101. `25f_replay.erl`'s five
  cases run through the rewritten module.
- **Not done.** `type Json` and `using :json { term encode(term value) }` are
  still in `index.bs`, for the request side. Moving `Body` to `ToJson` needs a
  parameter of the recursive JSON value type, which hangs the compiler
  ([ENG-609](https://linear.app/davewil/issue/ENG-609), on master too), and
  whose validator refuses every JSON object
  ([ENG-552](https://linear.app/davewil/issue/ENG-552): `FromJson<Json>` on
  `{}` is refused at `[]`, where `[[1]]` is read), and a
  `map<string, QuestionWire>` built from pairs, which B# cannot do without a
  foreign call and a second validation
  ([ENG-454](https://linear.app/davewil/issue/ENG-454)). 25f's friction 9 has
  both, measured.

## Done when

The scenarios pass, `check-from-json.sh` is seen red before the build and green
after, and `./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-10-09

`check-from-json.sh` was red on `815b565` on all four cases, each printing
`FromJson is not a codegen obligation`. Its `--self-test` sees four defects
(`decode_only`, `crash`, `blames_type`, `record_admitted`) and accepts the
correct outputs.
