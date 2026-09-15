# F47 — the diagnostic term on the wire: `--diagnostics json`

**Status**      **done 2026-09-15** · [ENG-298](https://linear.app/davewil/issue/ENG-298) —
                14 tests in `diagnostic_json_tests`, a `json` entry in the batch manifest test
                and one pin in `api_tests`; 945 in the suite, up from 931.
                `check-diagnostics.sh` gained check 5 and controls 6, 7 and 8; check 5 and
                control 6 seen red on the tree before the encoder existed, control 7 and F47.12
                red against the first cut's encoder
**Implements**  [ticket 23](../../wayfinder/issues/23-what-the-language-owes-an-agent.md) §5, the
                JSON encoding of the diagnostic term, under the mapping
                [ticket 77](../../wayfinder/issues/77-what-goes-on-the-wire.md) wrote on
                2026-09-15: **the wire form is the platform's** — `json:encode` of the term with
                its charlists as binaries. 23 §5 said the encoding reuses 16 §4's mapping so that
                `(:ok, 5)` has one rendering, and 77 is that mapping
**Owns**        two rules the mapping does not reach, both about the Erlang term rather than a
                B# value: **which lists are text** (the roster and the list rule below), and
                **`unclassified`'s `detail` as printed text** on the lost path. Neither is a row
                of the mapping and both are named here so that they are not mistaken for one
**Closes**      [ENG-298](https://linear.app/davewil/issue/ENG-298), the second of `ENG-205`'s
                LSP prerequisites. Unblocks [ENG-305](https://linear.app/davewil/issue/ENG-305),
                the server: F35 gave it a position, ENG-299 a parse that survives a broken buffer,
                and this gives it a form a non-BEAM process can read
**Depends on**  F16 (the term exists and is published per line on stdout) and F29 (every
                residual and every head is a string, so the term carries no tuple — measured in
                ticket 77, finding 1: `json:encode` on today's term already succeeds, and emits
                integer arrays where the strings are)
**Leaves**      `bs_diag:json/1` is a function over the descriptor, not `ToJson<T>`. The
                obligation itself, over a B# value, is [ENG-375](https://linear.app/davewil/issue/ENG-375)
                and is built against the same mapping

## What ships

A third value for the flag F16 introduced. `--diagnostics json` prints one JSON object per line
on stdout, with the prose still on stderr, so a consumer that is not a BEAM process reads the
same term F16 publishes:

```
$ bsc --diagnostics json Rank 2>/dev/null
{"function":"Rank","line":3,"tag":"inexhaustive","file":"Rank/Rank.bs","column":12,"severity":"error","heads":{"kind":"products","products":[[[":amber"]]],"pasteable":["Rank(:amber) -> ..."]},"residual":"(:amber)"}
```

Beside `bsc --diagnostics term Rank`:

```erlang
#{function => 'Rank',line => 3,tag => inexhaustive,file => "Rank/Rank.bs",column => 12,severity => error,heads => #{kind => products,products => [[[":amber"]]],pasteable => ["Rank(:amber) -> ..."]},residual => "(:amber)"}
```

The JSON is the term and nothing else: every key, every value, in the mapping 77 measured —
an atom is a string of its name, an integer a number, a map an object, a list an array. The
`--api` answer travels on the same channel, since it is published on whatever encoding the flag
selected (F17), and a batch entry may carry the flag like any other.

## The compiler delta

- **`bs_diag:json/1`**, exported: the descriptor to JSON iodata. It converts the term's charlists
  to binaries and calls the platform's `json:encode/1`. Nothing else: no diagnostics-only
  spelling, which was the reason 23 §5 and F16 kept the encoding out until the mapping was written.
- **`bs_diag:set_channel/1`** accepts `json`, and `emit/2` prints `json/1` of the descriptor
  under it, one object per line, the newline still the frame.
- **`bsc`** parses `--diagnostics json`; the usage line, the refusal for any other value, and the
  REPL's refusal (a prompt prints values on stdout, so no descriptor channel can hold there)
  name the third value.
- **`bs_api:publish/5`** gains the `json` clause, since it dispatches on the channel and would
  otherwise crash the query mode under the new flag.

**The list rule, and the one fact the term does not carry.** An Erlang string is a list of
integers, so a list of integers in the term is text or an array by the schema alone, and the term
does not say which; `~0p` faces the same question and answers it by printability, which is the
wrong answer for `[2, 3]`. Two payloads carry a list of integers that is not text: `declared`
under `name_arity_unfixed` and under `arity_not_declared`, the arities a name is declared at. The
same key holds a type string under F25's tags, so the fact is per tag *and* key, and
`bs_diag:integer_list/2` is the roster, beside the descriptors that build them. The rule, on
`wire/3` in `bs_diag` and nowhere else: `[]` is an array (`arms => []` and `behaviours => []`
exist, an empty string does not); a non-empty list of integers is an array where the roster
names it, text where it is printable, and otherwise a crash naming the tag and key — a new
integer-list payload cannot ship looking as if it had an encoding, as a tag cannot ship without
a message clause (F16.7). What the crash cannot see is a new integer list whose members all fall
in the printable range; that goes out as text, and a tag carrying one owes a fixture under
`bin/fixtures/wire/`, which is where the gate would catch it.

**This rule was not the first cut's.** The first said every non-empty integer list is text and
claimed the term carried no other, and the review's probe found `"declared":"\u0002\u0003"` on
the wire: two control characters where the term has two arities, under a tag none of the
residual fixtures reach. A grep of `built/2` for the claim would have refuted it twice. The
roster, the `wire` fixtures, control 7 and F47.12 are what that cost.

**`unclassified` carries an arbitrary term.** That tag is the lost path — `bsc:publish/2`
reports a shape `bs_diag` does not know rather than printing a stack trace — and its `detail` is
the raw diagnostic, which may hold a tuple the platform refuses. On this channel `detail` goes out
as its printed text, exactly what the prose prints after the path, so the lost path stays a
diagnostic on every channel. Ticket 77's mapping has no row for it because `detail` is an Erlang
term and not a B# value; the alternative was the platform's `unsupported_type` on exactly the path
F16 built `unclassified` to keep from crashing. This is the feature's one rendering of its own,
and it is named here so that it is not mistaken for a row of the mapping.

## The scenarios

| | what is exercised | what it establishes |
|---|---|---|
| F47.1 | `bsc --diagnostics json` on an inexhaustive function | one JSON object per line on stdout; `json:decode` gives `tag` as `"inexhaustive"`, `pasteable` as an array of strings, `line` as a number, and the file as a string rather than an integer array |
| F47.2 | the same program, `json` and the default | the prose on stderr is byte-identical: a third channel changes nothing a consumer of the first two can see |
| F47.3 | **the same program under `term` and under `json`** | `json:decode` of the JSON equals the term with every atom and every charlist a binary — F16.3's shape restated: not "both exist" but "one is the other, computed". This is the central one, and a normaliser written in the test rather than borrowed from `bs_diag` is what keeps it from agreeing only with itself |
| F47.4 | a raised condition (`unknown_type`) and a warning (`unreachable_clause`) | the raise path and the severity travel on this channel too, and the warning still compiles |
| F47.5 | a file named `café.bs` | the path goes out as UTF-8 text — `"caf\303\251.bs"` on the byte stream — never as codepoints |
| F47.6 | `--repl` with `--diagnostics json` | refused, exit 2, for F16's reason |
| F47.7 | `--diagnostics nonsense` | the refusal names all three values |
| F47.8 | `--api` under `json` | the module map and each operation, one object per line, decodable |
| F47.9 | a `json` entry in a batch manifest | byte-identical to the standalone run on every stream, like the `term` entry beside it |
| F47.10 | an `unclassified` descriptor whose `detail` holds a tuple, through `bs_diag:json/1` | encodes rather than crashing; `detail` is the printed term. Driven through `bs_diag` directly because the lost path is unreachable from a program on purpose |
| F47.11 | `check-diagnostics.sh` over every module in `bin/fixtures/residual` and `bin/fixtures/wire` | the JSON channel round-trips the term (check 5); a copy of the sources whose encoder drops a key is reported (control 6), one whose encoder sends the declared arities as text (control 7), and one whose encoder leaves a string as integers, the platform's own output before this feature (control 8) |
| F47.12 | `Add(1)` beside `Add/2` and `Add/3`, and a bare `Double` between `Double/1` and `Double/2` | `"declared":[2,3]` and `"declared":[1,2]` on the wire — arrays of numbers, not the control characters the first cut printed. Pinned as bytes, not through the normaliser, so the schema fact is asserted once by hand |
| F47.13 | an integer list under a tag and key the roster does not name, through `bs_diag:json/1` | crashes naming the tag and key rather than encoding it as text |

## The gate

`check-diagnostics.sh` gained check 5: for every module in `bin/fixtures/residual` and
`bin/fixtures/wire`, the built `bsc` publishes the term, the gate compiles the tree's own
`bs_diag.erl` into a scratch directory, encodes each term through it, decodes with `json:decode`,
and requires the result to equal the term normalised by a function written inside the gate. The
normaliser is the gate's, not `bs_diag`'s, so a dropped key or a string left as integers is a
mismatch and not an agreement — with one honest exception: the fact that `declared` is a list of
integers under the arity tags is a fact about the schema, which no normaliser can derive, so the
gate states it by hand. Control 6 drops `tag` before encoding; control 7 makes the encoder forget
the roster, which is the first cut's defect exactly, and is red only because the `wire` fixtures
reach the two tags; control 8 removes the charlist conversion, so the encoder emits what the
platform emitted before this feature. All three require the red to name the round trip.

## What the build found

**The term channel had carried a tuple since F35, and only a consumer that cannot read one
noticed.** F35 splits the lexer's `{Line, Column}` pair into `line` and `column` at
`descriptor/2`'s exit, so no descriptor clause can forget to. `bs_api`'s operation map is not a
descriptor: it is built in `operation/4` and published straight to the channel, and from
2026-09-05 it carried `line => {16, 19}` — the pair whole, no `column`. F17's example shows
`line => 15`, F17.8's test matched `params` and `result` and never `line`, and `~0p` prints a
tuple as happily as an integer, so nothing was red. `bsc --diagnostics json --api examples/Counter`
was refused by the platform on its first run: `{unsupported_type, {22, 14}}`.

The repair is F35's rule applied where it was missed: `operation/4` matches the pair and writes
both keys, F17.8 pins both, and F17's example carries the column. A rule enforced at one exit is
only as wide as the paths through that exit, and the query mode had its own.

## Out of scope

- **`ToJson<T>`**, the obligation over a B# value — [ENG-375](https://linear.app/davewil/issue/ENG-375).
- **The decode direction** — [ticket 78](../../wayfinder/issues/78-the-decode-direction.md),
  [ENG-373](https://linear.app/davewil/issue/ENG-373).
- **A schema.** The keys and their shapes are ticket 23 §4's, unchanged: payloads are maps and
  evolve additively. A JSON Schema document would be a second statement of them.
- **LSP framing.** `Content-Length` headers and the `PublishDiagnostics` shape are the server's
  (ENG-305); this channel is the term, one object per line.
