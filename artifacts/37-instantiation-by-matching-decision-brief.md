# Decision brief — ticket 37 / ENG-204: the ordering question

**Prepared for David. Not a resolution — ticket 37 is left exactly as open as found; no ticket,
decisions.md, map.md, or Linear state was touched.**

Repo HEAD measured against: `b70c9a309d24652d0f24578c18f7d4b109ae4aff`, 2026-09-04.
Environment: Erlang/OTP 25.3.2, Elixir 1.14.0 (compiled w/ OTP 24), Elm 0.19.1 — see
**Environment caveats** at the end for what that does and doesn't cover.

---

## What is actually undecided

The ticket's algorithm question — *what does "instantiation is matching, not solving" mean,
precisely* — is resolved and re-confirmed in this session (all 6 measurements of
`37a_instantiation_by_matching.escript` still PASS against today's HEAD; see
`artifacts/37-instantiation-by-matching/probes/37a_rerun_2026-09-04.out`). That is **not** what
this brief is about.

What remains open is narrower and purely a **prioritization call**: should the compiler grow
**polymorphic function signatures** (ticket 27 §(c) — a `<T, U>` declaration list on a function's
own signature, e.g. `list<T> Reverse<T>(list<T> xs, list<T> acc)`) **now**, given that it is
measured **not technically blocked** (no arrow type, no lambda, no new algebra node needed for the
first-order case) but also measured **not clearly earned** by the current exemplar corpus (two
distinct shapes, three occurrences, both private helpers)? The algorithm to implement if built is
already settled; this is only about *when*, if ever, to spend the implementation cost.

---

## Fresh measurements (this session, 2026-09-04)

### 1. The algorithm still holds
Re-ran `wayfinder/prototypes/37a_instantiation_by_matching.escript` unmodified against today's
`bs_types`. All 6 measurements PASS, matching the ticket's write-up exactly — least-per-occurrence,
join-across-occurrences, solve-is-total/contain-can-still-fail. No drift. Full output:
`artifacts/37-instantiation-by-matching/probes/37a_rerun_2026-09-04.out`.

### 2. The corpus has NOT moved again since 2026-08-28
Re-ran the ticket's own sweep method ("a signature is a `public`/`private` declaration line
carrying no `->`") over all five exemplar directories (`25a`–`25e`; no `25f` or later exists).

| Directory | Signatures |
|---|---|
| 25a-http-api-server | 9 |
| 25b-websocket-handler | 5 |
| 25c-event-queue-consumer | 9 |
| 25d-database-querying | 17 |
| 25e-dynamic-web-page | 14 |
| **Total** | **54** |

Identical to the ticket's last count (9/5/9/17/14 = 54). Zero of the 54 signatures declare a
`<T>` type-parameter list. The two shapes the ticket identified are still the only two:

| Shape | Where | Occurrences |
|---|---|---|
| `Prepend<T, E>(T, result<list<T>, E>) -> result<list<T>, E>` | `25d/rows.bs:38` | 1 |
| `Reverse<T>(list<T>, list<T>) -> list<T>` | `25e/escape.bs:52`, `25e/rows.bs:54` | 2 (as `ReverseParts`/`ReverseRows`) |

**n = 3 occurrences, 2 shapes, one week later.** No new case appeared, no old case disappeared.
Full sweep: `artifacts/37-instantiation-by-matching/probes/corpus_sweep_2026-09-04.out` (script:
`corpus_sweep.sh`).

### 3. The compiler cost — confirmed, with one correction to "no grammar change"

Re-located the ticket's cited call sites (its line numbers are 12 days stale — the file has grown
by ~1470 lines since):

| Site | Ticket's line | Actual line today | Still the shape the ticket describes? |
|---|---|---|---|
| `sig/3` | `:574` | `:648` | Yes — one `resolve/2` call per param, unchanged |
| `type_env/1` | `:666` | `:879` | Yes — already branches `{parametric, Params, Body}` vs. pre-resolved, for aliases; `#fn{}` isn't fed through it yet |
| `resolve({t_ref, N}, ...)` | "`resolve/2` ~878" | `:1213` (the `t_ref` clause; `resolve/2`'s own head is `:1170`) | Yes — treats every `{t_ref, V}` as a user type reference today, no signature-variable case |
| `arg_diags/7` | `:2114` | `:2638` | Yes — plain `subtract` + `is_none`, exactly one failure branch (`:2649`) |

`bs_types.erl` exports everything the algorithm needs today — confirmed by reading the
`-export` list directly: `subtract/2`, `union/2`, `is_subtype/2`, `list_elem/1`, `list/1`,
`tuple/1`, `none/0`, `term/0` are all present (lines 27–39). No `ty()` part for a type variable
exists, and none would be added — confirmed by grep: `bs_check.erl` contains no `t_var`/`solve`
machinery, and the tree's only `unify/4` remains `bs_repl.erl`'s value-matcher (REPL pattern
matching, unrelated). **`bs_types` genuinely has no tuple-component projection** — confirmed no
`tuple_component`/`tuple_parts`/`tuple_elems` accessor exists; `37a`'s own `tuple_proj/3` reads
the raw `tuples` part directly and flags this as an assumption, exactly as the ticket says.

**Correction to "Grammar — nothing":** the ticket claims the grammar needs no change because
`Name<T, U>` already parses in type position. That is true of `type_prim` (confirmed:
`bs_parser.yrl:249-250`), but a **function signature's own `<T>` declaration list has no grammar
rule today.** Proven by direct measurement, not inference — I wrote
`private list<T> Reverse<T>(list<T> xs, list<T> acc)` into a fresh module and ran it through the
real `bsc`:

```
$ bsc /tmp/.../Reverse
Reverse/reverse.bs:1: error: syntax error before: '<'
```

(`artifacts/37-instantiation-by-matching/probes/bsc_polymorphic_signature_parse_attempt.out`). The
`type_params` nonterminal (`bs_parser.yrl:219-220`) exists and is exactly the three tokens needed
— but today it is wired **only** into `type_decl` (the `type Uident<T,U> = ...` alias form,
`:216`), not into `signature` (`:271-273`). So building §(c) is **one new yecc production reusing
an existing nonterminal**, not zero grammar work — cheap, but not the "nothing" the ticket states.
This is a correction to the ticket's cost accounting, in §(c)'s favor if anything (still small),
not against it.

Separately confirmed live: the duplicate-declaration friction the ticket cites for `Reverse` is
real today, not just asserted in a write-up. A minimal two-file module with `Reverse(list<binary>,
list<binary>)` and `Reverse(list<int>, list<int>)` gives:

```
error: Reverse/2 is declared more than once
  a name may carry MORE THAN ONE ARITY, so Reverse/2 and Reverse/3 would
  be two functions — but two signatures of the SAME arity are one
  function declared twice, and its clauses would merge silently.
```

(`artifacts/37-instantiation-by-matching/probes/bsc_duplicate_name_arity.out`). This is the
concrete cost of *not* building §(c): a compiler-refused module, not merely an ugly workaround.

### 4. Prior art on the ordering question

**Elixir — not applicable, confirmed by probe.** Elixir has no compile-time generics construct to
compare against; the honest measurement is that there is nothing to stage. Wrote a module shaped
exactly like the corpus's `Reverse` case with a `@spec reverse(list(a), list(a)) :: list(a) when
a: var`, plus a deliberately type-incoherent call mixing an integer and an atom inside one call to
the "generic" function:

```elixir
def mismatched, do: reverse([1, 2, :not_an_int, 3], [])
```

`elixirc` compiles it cleanly (exit 0) and the mismatched call runs with no diagnostic of any kind
— the `@spec`'s type variable is pure documentation, checked by nothing at compile time. This
reproduces, independently, the same shape of finding ticket 27 already recorded for `Enum.map/2`'s
real spec (type parameter discarded to `any()`). Output:
`artifacts/37-instantiation-by-matching/probes/elixir_generic_probe.out`. (Dialyzer was also
attempted as a secondary check but failed with an unrelated `debug_info` version-mismatch error
between this sandbox's Elixir 1.14/OTP-24-compiled beam files and OTP 25's dialyzer — a real
environment artifact, not a finding; not chased further since `elixirc`'s result alone already
answers the question.)

**Gleam — cited from this repo's existing local evidence, not re-probed (Gleam is not installed
here and cannot be installed — no apt package, github.com/api.github.com blocked).** Ticket 27
already measured Gleam 1.18.1 locally and recorded its real emitted spec for `List.map`:

```gleam
pub fn map(list: List(a), with fun: fn(a) -> b) -> List(b)
```
```erlang
-spec map(list(ACJ), fun((ACJ) -> ACL)) -> list(ACL).
```

The relevant fact for the ordering question: Gleam's generic type constructor (`List(a)`) and its
generic function (`map`) are **the same feature of one uniform, nominal-ish type system** — Gleam
does not stage "generic structs first, generic functions later" as two separable capabilities; a
function can be as parametric as a type from day one because the check is the same substitution
mechanism either way. This is the strongest same-target (BEAM, statically-typed) precedent
available, and it argues against staging — but see the caveat below on why beam-sharp's structural
algebra makes this less directly transferable than it looks.

**Elm — could not be run this session; cited as `doc` (training knowledge), unverified this
session.** Elm has parametric polymorphism on data types and functions uniformly since its first
release, with no observed staging between the two. I attempted a real, in-sandbox `.elm` probe
(`artifacts/37-instantiation-by-matching/probes/elm_reverse_probe.elm`, the same `Reverse`-shaped
generic function as the other probes) and it could not be compiled: `elm make` requires an
`elm.json`, and `elm init`/dependency resolution requires fetching `elm/core` from
`package.elm-lang.org`, which is blocked by the org's egress policy (confirmed via the proxy status
endpoint: `connect_rejected`, gateway 403, `package.elm-lang.org:443`, four separate attempts —
not a transient failure). No local cache of `elm/core` exists anywhere in this filesystem, and it
is not distributed via `apt` (`elm-compiler` is; the packages it depends on are not). Full attempt
and proxy evidence: `artifacts/37-instantiation-by-matching/probes/elm_probe_blocked.out`.

So the Elm fact above is asserted from training knowledge only, not measured in this sandbox. **Why
it would be weaker evidence even if it had been reproduced**: Elm has Hindley-Milner type
inference, so a generic function's variables are *inferred*, never *declared* — there is no
"decide whether to build the declaration-list feature" moment in Elm's design space at all,
because the same unification machinery that types every expression handles it for free. Beam-sharp
has mandatory signatures with no inference (ticket 04) and no unification engine — §(c) here is a
deliberately scoped, hand-written matching algorithm bolted onto specific call sites
(`resolve/2`, `type_env/1`, `sig/3`, `arg_diags/7`), which is exactly the kind of feature that
*can* be staged, because nothing else in the compiler depends on it existing. Elm's "no staging"
observation is evidence that a language *can* ship both together; it is not evidence that
beam-sharp's very different implementation strategy makes deferral costly the way it might for
Elm.

---

## Options

### (a) Build §(c) now, on today's evidence
**For:** Not blocked (measured: `bs_types` exports everything needed, no new `ty()` part). The
algorithm is fully specified and reproducibly measured. The cost is small and concrete: one grammar
production reusing `type_params`, and edits at `bs_check.erl:648`/`:879`/`:1213`/`:2638` "on paths
that already exist" (confirmed by reading each). The compiler currently **refuses a real module**
(`error: Reverse/2 is declared more than once`, reproduced live) rather than merely producing ugly
code — that is a harder failure mode than the ticket's own framing of "cost of not having §(c)"
suggests for `Reverse`, though not for `Prepend` (which only pays in style, not in refusal).

**Against:** n = 3 occurrences across 54 signatures in the whole corpus, unchanged in the week
since the ticket's last measurement — the corpus is not growing this need. Both shapes are private
helpers; nothing public needs this yet. Building a feature for 3/54 signatures (5.6%) risks
speculative machinery ahead of demand, which cuts against this project's general bias toward
measured need (CLAUDE.md's insistence on grounding every design question in real B# code, not
option menus).

**Strongest counterargument:** the corpus is an artifact of what the exemplar-writing sessions
happened to need, not a survey of what beam-sharp programs in general need — `Reverse`-shaped
accumulator functions and `Prepend`-shaped element-into-container functions are generic-programming
staples in essentially every language with real generics (`fold`, `map`, `filter`, list-building
helpers), so n = 3 today plausibly undercounts steady-state demand once more of the standard
library and more exemplar domains exist.

### (b) Defer until N more occurrences accumulate
**For:** Keeps the compiler's surface area matched to demonstrated need, consistent with the
project's working rule of grounding decisions in real code rather than anticipated need. Costs
nothing today; the workaround (duplicate names) is annoying but not silently unsound — it is a
loud compile error, not a miscompile, so nothing is at risk by waiting.

**Against:** Every occurrence that accumulates while deferred pays the *namespace* cost the ticket
already flags as the sharper one — "compounds once per further element type" — not a one-time
style cost. If David expects the standard library or more exemplar domains to add several more
`Reverse`/`Prepend`-shaped helpers, deferral is deferring a compounding tax, not a flat one.

**What N to name, and why:** the ticket's own history is the basis — n went from "not yet
observed" (F6, 2026-08-14) to 1 (`Prepend`, 25d, 2026-08-24) to 3 across 2 shapes (`Reverse`
duplicated, 25e, 51 minutes after a re-measure) to unchanged-at-3 one week later (this session).
That is roughly one new occurrence per exemplar-directory addition, and five exemplar directories
have shipped total. A reasonable trigger is **N = 5 occurrences, or a third distinct shape**,
whichever comes first — roughly one more exemplar-domain's worth of evidence at the observed rate,
and a third shape would mean the pattern is domain-general rather than an artifact of two adjacent
write-ups (`25d`/`25e` shipped two days apart).

### (c) Build only the narrow first-order case now; explicitly refuse the higher-order/lambda-dependent generalization until arrows exist
**For:** This is not really a third option so much as a scope note on (a) — the ticket's own
measurement already establishes that the corpus **splits** cleanly: `Prepend` and `Reverse` need
no arrow; `Rowed`/`Checked` (the traverses) do. Building only the arrow-free case is what "build
§(c) now" already *is*, since nothing in the compiler or grammar work above touches arrows or
lambdas at all — confirmed, no `=>`/lambda work appears in any of the four call sites. Naming this
as its own option mainly serves to make explicit that choosing (a) is **not** a commitment to
build `Map`/`Filter`/higher-order generics next; that remains gated on ticket 37's sibling
questions (arrow type, lambda syntax) and is untouched by this decision either way.

---

## Recommendation

**Option (b), with the trigger stated above (N = 5 occurrences or a third distinct shape) — lean
toward (a) if David's intuition from option (c)'s framing is that this is cheap enough not to
bother measuring further.**

The one piece of evidence that tips it: **the corpus has not moved in the week since the ticket's
last measurement** (54 signatures, same 9/5/9/17/14 split, same two shapes, same n = 3, confirmed
fresh this session) — for a project whose corpus was moving under this exact ticket every few days
in late August (twice in 51 minutes, per the ticket's own history), a full week of silence is
itself a data point, and it is the only one that changed since the ticket was last touched. Nothing
in this session's measurement changes the shape of the trade-off the ticket already laid out
correctly; it only confirms that trade-off is still current and adds one genuine correction (the
grammar is not literally free — a small, mechanical yecc addition is required) that mildly *raises*
the cost side of "build now" without changing its overall smallness. Given a genuinely small,
well-specified, unblocked cost against genuinely thin and non-growing demand, waiting for one more
confirming signal costs little and avoids building surface area three signatures currently justify.

---

## What I could not verify

- **Elm could not be compiled or run in this sandbox at all.** `elm/core` cannot be fetched
  (`package.elm-lang.org` is blocked by org egress policy, confirmed via the proxy status endpoint
  with four independent `connect_rejected`/403 entries, not a transient failure) and no local cache
  exists anywhere on the filesystem. The claim that Elm shows no staging between generic types and
  generic functions is asserted from training knowledge only and is **explicitly unverified this
  session** — I could not confirm it against a real Elm compile in this environment.
- **Gleam could not be installed or probed at all** (no apt package; github.com/api.github.com
  blocked). The Gleam evidence in this brief is entirely this repo's pre-existing local measurement
  from ticket 27 (Gleam 1.18.1, cited verbatim), not something re-verified this session.
- **Dialyzer's behavior on the Elixir generic-shaped probe could not be confirmed** — it failed
  with a `debug_info`/`elixir_erl` version-mismatch error, apparently from mixing this sandbox's
  Elixir 1.14 (compiled with OTP 24) beam output with OTP 25's dialyzer. This looks like an
  environment artifact rather than a real finding, but I did not chase it further since `elixirc`'s
  own result already answered the question the probe was for.
- **OTP-28-specific behavior is unverified.** Everything measured here ran on Erlang/OTP 25.3.2
  (erts-13.2.2.5); the project is pinned to OTP 28.5 (`.tool-versions`) and neither mise
  nor asdf are available to install it, nor is github.com reachable to fetch it another way. I have
  no specific reason to expect `bs_types`/`bs_check`/the parser to behave differently on 28, and
  none of this brief's findings depend on Erlang-version-sensitive behavior (map ordering,
  timing, NIF changes) as far as I can tell — but this is not independently confirmed on 28.
- **I did not attempt to actually implement §(c)** (that would be resolving the ticket, not
  briefing it) — the cost estimates above are read from the source at the named call sites and
  cross-checked against the ticket's own claim, plus one live grammar-rejection probe, not from a
  working prototype implementation of the checker changes themselves. The four `bs_check.erl` edit
  sites are confirmed to exist and be shaped as described; whether the actual edits are as
  mechanically simple as they look from reading is not proven the way `37a`'s algorithm claims are.
- **The exemplar corpus's representativeness is not something I can verify** — only that it hasn't
  grown in a week. Whether that week of silence reflects genuine stabilization or just that no one
  has been adding exemplars is not something the repo state can distinguish.
