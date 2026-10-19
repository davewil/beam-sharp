# Brief — ticket 62 (ENG-252): the outbound ABI, and what remains: function-name casing

Status of the ticket: **open, left open.** The `Kind` contract and the no-prefix answer are already settled in the ticket
(`LANGUAGE.md` §12); what remains is how an Elixir caller reaches a PascalCase export.

## Sub-decisions
1. Does B# emit anything besides the PascalCase export for foreign callers? (the three candidates the ticket lists)
2. If it emits a second spelling, what is the derivation rule, and what happens on a collision?
3. If it does not, is "Elixir callers write `:Shop."New"(1)`" an acceptable documented answer?

## What the probes found that the ticket did not

**The ticket's friction table is incomplete.** It lists `apply(:Shop, :New, [1])` as the only way in from Elixir. Elixir's
quoted-call form works directly, with no `apply`:

```
:Shop.New(1)                -> SyntaxError (as the ticket says)
:Shop."New"(1)              -> %{Id: 1, Kind: :"Shop.Order", Total: 0}      <- not in the ticket
f = :Shop; f."New"(1)       -> works
&:Shop."New"/1              -> inspected in probe.sh, not called there (verifier called it in a compiled module: works)
:"Elixir.Shop"."New"(1)     -> UndefinedFunctionError (module is Shop, not Elixir.Shop) — the module name, not the syntax
```
Probe: `probes/62/probe.sh` (OTP 25, Elixir 1.14.0). So candidate 1 ("accept it") costs one pair of quotes per call site,
not an `apply/3` rewrite. That is a different price from the one the ticket recorded.

**Gleam is a precedent for constructor names, not function names.** The ticket cites Gleam as downcasing PascalCase on
emission. Measured (`probes/62/gl/`, Gleam 1.12.0): `OrderCreated(id)` emits `{order_created, Id}` and `OrderShipped` emits
`order_shipped`, so values and types are downcased. But Gleam *functions* are written snake_case in source (`new_order`) and
emitted unchanged; `pub fn NewOrder()` is a syntax error, so Gleam rejects PascalCase function names outright. Gleam has no PascalCase functions and so never derives a function alias. It is evidence for "BEAM
convention is snake_case atoms", not for "a neighbour ships alias exports".

**B# has a fixed callback table, not a naming rule.** `bs_otp.erl:42` is one row mapping `HandleCall` to `handle_call`, applied only when the module declares the behaviour (ticket 35); without a `behaviour` line it stays `'HandleCall'`. A general alias rule would derive the same atom for a callback; the emitter must not export it twice.

## Measurements
| What | Result | Probe |
|---|---|---|
| Public functions in the repo's `.bs` corpus | 256 (file, name) pairs in 142 files (a first version of the regex missed 12 tuple/atom-union signatures; fixed) | `corpus_alias.py` |
| Alias collisions inside one module under `PascalCase -> snake_case` | **0** | same |
| Names where an acronym-aware rule and a naive rule disagree | **0** (corpus has no `HTTPServer`-shaped name) | same |
| BEAM bytes per alias (cheapest form, `new(X) -> 'New'(X).`) | **~39 B** without `debug_info` (N=100: 9188 -> 13084 B); **~70 B with `+debug_info`** (verifier: 15912 -> 22940 B); a `-spec` per alias ~12 B more; exports double | `alias_cost.sh` (compiles without `debug_info`) |
| `erlc` time with aliases | not distinguishable from noise (261–313 ms across all runs) | same |

The alias form measured is hand-written Erlang, not `bsc` output; `bsc`'s emitter may add a `-spec` per alias, which would
cost more. Not measured.

## Options

**A. Accept it; document the quoted call.** `:Shop."New"(1)` from Elixir; `LANGUAGE.md` §12 gains one line.
- Evidence: the form works today on Elixir 1.14.0 with no compiler change; 0 B.
- Strongest counterargument: every call site reads as odd Elixir. Quoted function names are rare enough that a reader
  may take them for a bug. The Elixir formatter preserves the quoted form (verifier); the one measured cost is that `elixirc` warns `:Shop."New"/1 is undefined` when the beam is not on the compile path, which fails under `--warnings-as-errors`. Not measured on Elixir newer than 1.14.

**B. Emit a snake_case alias beside each public function.** `:Shop.new(1)` works.
- Evidence: 0 corpus collisions; ~39 B per alias; none for the rule itself: **ticket 32 settled that there is no snake_case⇄PascalCase rule anywhere in the language** (`wayfinder/issues/32-*.md:204`), and ticket 35 repeats it, so B reopens that decision. The `bs_otp` table is a fixed lookup, not a rule.
- Strongest counterargument: it doubles the export surface and makes every public name a pair that must be kept
  collision-free forever. A user who writes `public int New` and `public int new` is impossible today (`uident` is
  PascalCase by construction, ticket 35), but a *foreign* module that exports `new/1` beside `'New'/1` is not, and no
  corpus entry exercises that. The alias also becomes part of the ABI the clean-room spec must state.

**C. Change B#'s function-naming convention to snake_case.** Rejected by the ticket for blast radius; not re-measured.

## Recommendation
**A now, B only if a real Elixir adopter appears.** A costs nothing and the `Kind` contract is already published; B adds an
ABI surface the spec must carry before anyone has asked for it. If B is later wanted, the rule is the plain
split-at-lowercase-to-uppercase one (0 corpus collisions, no acronym cases to adjudicate).

## Not measured
Elixir newer than 1.14; `bsc`-emitted alias size with specs; whether Dialyzer accepts the alias specs; a real B#-built beam called from Gleam
(Gleam 1.12.0 `@external(erlang, "Shop", "New")` emits `'Shop':'New'(Id)` and returns the map, per the verifier, against a hand-written `Shop.erl`).
