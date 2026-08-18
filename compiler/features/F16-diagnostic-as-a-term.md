# F16 — The diagnostic is a term, and prose is a pure function of it

**Status**      in progress · [ENG-224](https://linear.app/davewil/issue/ENG-224)
**Implements**  [ticket 23](../../wayfinder/issues/23-what-the-language-owes-an-agent.md) §1 (the
                split), §2 (the compiler synthesises the head), §4 (a named subset is contractual,
                payloads are maps). It **decides nothing** — 23 closed on 2026-08-13.
**Unblocks**    23 §10 (`bsc --api`), which is specified *on this channel* and has no output shape
                until the channel exists; and 23 §5's JSON encoding, which is separately blocked
**Depends on**  nothing. Every diagnostic it moves is already built.

## Why this one now

**The feature queue is empty for the fourth time and the only row left, F13, is blocked on ticket
30.** The features README already names what is takeable instead: three of an LSP's four
prerequisites are *decided and simply unbuilt*, and the table there marks this one **decided,
unbuilt** with the reason — *"`bsc:report/2` writes prose directly with `io:format`; there is no
term today and so no way for the two to be kept from drifting."*

It goes before `bsc --api` because **§10 is specified on top of §1**. §10 reads *"`bsc --api
<Module>` reads source and answers **on this channel**"*, and §3 says the same of the boundary
answer. The only channel the ticket defines is §1's. Building `--api` first means either inventing
a provisional shape §1 then replaces, or building a second descriptor for the API path — which is
the failure `bsc.erl` already names about `resolve/2`: *a classification rule with two
implementations has two answers*. `bsc.erl:1374` and `F2-interval-refinements.md:180` both describe
`--api` as **the full-fidelity channel** against ticket 43's truncated form, and fidelity is a
property of the channel.

## Measured before this file was written, not assumed

Counted in `src/bsc.erl` at `53693ec`:

| | Count |
|---|---|
| `report/2` clauses — diagnostics the checker **returns** | 24 |
| `resolve_error/2` clauses — conditions the checker **raises** | 32 |
| Sites that call `io:format(standard_error, …)` with prose | **56** |
| Sites that build a term any consumer can read | **0** |

The internal shapes are *already* terms — `{error, Line, Fn, {inexhaustive, Residual}}`. What does
not exist is a **published** descriptor and a prose function derived from it. So this is not
"invent a diagnostic model"; it is "stop destroying the one that is already there at the boundary
where the consumer stands" — which is verbatim the defect ticket 23 measured in `erlc` [L2] and
the same defect as Elm's, one layer out.

## What is being built

A new module, **`bs_diag.erl`**, owning three things and nothing else:

- **`descriptor/2`** — `(Path, Diagnostic)` → the map. The diagnostic tuples stay exactly as the
  checker raises and returns them; this is the only place that knows their shape.
- **`format/1`** — descriptor → prose iodata. Every one of the 56 format strings moves here
  **verbatim**. This is the pure function §1 requires.
- **`emit/2`** — descriptor → the channel. Prose to stderr as today; the descriptor term to
  **stdout** under `--diagnostics term`.

`bsc:report/2` and `bsc:resolve_error/2` keep their clause heads and their comments — the reasoning
attached to each message is worth more than the format string — and their bodies become one call.

### The descriptor shape (23 §4)

**A map, not a tuple**, because a map gains a key without breaking a matcher and a tuple cannot —
so additive-only evolution is expressible in the data rather than promised in prose.

```erlang
#{ tag      => inexhaustive,      %% the atom the consumer dispatches on
   severity => error,             %% error | warning
   file     => "examples/Shop/shop.bs",
   line     => 12,
   function => "Classify",
   residual => Type,              %% tag-specific from here down
   heads    => ["Classify(:cancelled) -> ..."] }
```

`heads` is the load-bearing key and it is **§2 doing the work**: the compiler synthesises the head,
never the body, so the descriptor hands over pasteable source rather than a type expression the
consumer would have to invert for itself. Where the residual is not guard-expressible, `heads` says
so and offers nothing — an approximation there is the Elm defect in its most dangerous form.

### What is contractual, and what is merely structured

§4's test is §2's: **does it hand the agent something to write?** Frozen here:
`inexhaustive`, `catch_all_over_closed`, `switch_inexhaustive`, `arg_not_accepted`,
`unreachable_clause`, `unreachable_arm`. Every other tag is structured and renderable and carries
**no shape promise** — narrower than OTP's position (which documents nothing beyond the envelope)
and wider than nothing.

`defended` is named contractual by §4 and **does not exist**: it is §3's informational boundary
answer, which was never built. It is not in this feature. Recorded here rather than in prose
somewhere else, because this repo has twice learned that a prose-only blocker is an invisible one.

### The CLI spelling is not decided by the ticket, and this is the assumption

§1 says only *"the CLI publishes both"*. No flag is named anywhere in ticket 23. Taken here:

**`bsc --diagnostics term`** — prose to **stderr** exactly as today, the descriptor to **stdout**,
one `~p` per line. Default stays `prose`, which prints nothing new. Chosen to match the existing
`--src-root DIR` spelling, and split by stream so a consumer redirects rather than parses.

Known cost, stated rather than hidden: a **warning** does not stop the run, so under
`--diagnostics term` a warning's descriptor and the program's own output share stdout. Errors do
stop the run, so the contractual subset is unaffected.

## The gate, and why this feature owes one

F11, F12, F14 and F15 each found a gate that reported something without looking at the thing. This
feature's version of that failure is specific: **once prose is derived from the term, nothing stops
the next report site from calling `io:format` directly** and silently re-opening the drift §1 exists
to close. It would pass every test — the prose would be right.

So `bin/check-diagnostics.sh` asserts that `io:format(standard_error, …)` appears in **`bs_diag.erl`
and nowhere else**, against a named allowlist of non-diagnostic sites with their reasons (the usage
text, the REPL's echo, the crash reporter). Per the CI file's rule, an exclusion carries its reason.

The second half is a **totality test**: `format/1` has no catch-all that renders something generic.
Every tag the compiler can produce has a clause or the call crashes, and a roster test walks the
`report/2` and `resolve_error/2` clause heads in the **source** rather than trusting a hand-kept
list — the lesson from `demonstrated_surface()` being read as a grammar inventory.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F16.1 | an inexhaustive function | `bsc --diagnostics term …` | a `#{tag := inexhaustive}` map on **stdout**, carrying `residual` and pasteable `heads` | 1 |
| F16.2 | the same file | `bsc …` (no flag) | byte-identical prose to today, and **nothing** on stdout | 1 |
| F16.3 | the same file | both of the above | the prose equals `bs_diag:format/1` of the term F16.1 printed | 1 |
| F16.4 | a **raised** condition (`unknown_type`) | `bsc --diagnostics term …` | a descriptor too — the raise path is not a second channel | 1 |
| F16.5 | a warning (`unreachable_clause`) | `bsc --diagnostics term …` | `severity := warning`, and the run still succeeds | 0 |
| F16.6 | a residual that is **not** guard-expressible | inspect the term | `heads` offers nothing, and says so | 1 |
| F16.7 | every tag in the source roster | `rebar3 eunit` | each has a `format/1` clause; a tag with none crashes rather than rendering generic prose | 0 |
| F16.8 | the whole tree | `bin/check-diagnostics.sh` | green, and measured **failing** first against a deliberately re-added direct `io:format` | 0 |
| F16.9 | the corpus | `rebar3 eunit` | all 321 existing tests still pass — the prose moved, it did not change | 0 |

## Out of scope

- **23 §5, the JSON encoding.** Blocked, and it will look in scope the moment a term exists —
  emitting JSON feels like the obvious next line. It inherits ticket 16 §4's language-published
  serialisation mapping, which the map lists as **owed and unwritten**, and OTP's `json` refuses
  tuples outright. Inventing a diagnostics-only spelling would leave beam-sharp with two renderings
  of `(:ok, 5)`.
- **23 §10, `bsc --api`.** The next feature, and cheaper once this lands.
- **23 §3's `defended`**, per above; and **23 §6's `error_info` on generated code**, which lands in
  emitted code rather than in the compiler and owes a size number first.
- **Columns.** No decision owed and genuinely independent — the lexer writes `TokenLine` by choice.
  Not bundled, because it touches every format string and every Abstract Format annotation, and
  mixing it with a 56-site move would make both unreviewable.
- **Changing any message.** The prose is preserved to the byte. 321 tests assert on it, and that is
  the safety net this refactor is steered by.

## Done when

`bsc --diagnostics term` prints a descriptor map for every diagnostic the compiler can produce,
error and warning, returned and raised; the prose is `bs_diag:format/1` of that same map at every
site; `bin/check-diagnostics.sh` is in CI and was seen failing before it was believed; and the
suite is green with the prose unchanged.
