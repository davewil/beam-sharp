# ENG-241 · Ticket 59 — the boundary guard applies two rules with different scopes

Decision brief, prepared by an unattended run. **Nothing is resolved or claimed.** Probes, sources and captured output are in `artifacts/probes/ENG-241/`; `run-all.sh` re-runs all of them.

## What this host could and could not run

| Item | Status |
|---|---|
| Erlang/OTP **25** (the repo pins 28.5) | ran; every number below is OTP 25 |
| Elixir 1.14 (compiled with OTP 24) | ran |
| Elm 0.19.1 | installed but **cannot compile**: it fetches `package.elm-lang.org`, unreachable here (`elm.out`). Not worked around. |
| Gleam | **not installed, not surveyed** |
| `bsc` | **not built**: `bs_lexer.xrl` needs OTP 26+ options and `bs_run.erl:351` uses `~kp`. Every claim about what `bsc` emits is *cited from repo, not re-executed*. The probes hand-write the Erlang that `bs_emit.erl:590-594` and `:502-503` build from, so they measure the BEAM's response to those guard shapes, not `bsc` itself. |

## What the code says (read, not run)

`bs_emit.erl:264-285` (`boundary_guards/6` → `guard_one/8`): the record branch `{ok, Tag}` never looks at `Public`. Only the `none when Public` branch (float/int kind) does. The comment at `bs_emit.erl:329-332`: *"Exported functions only … The record tag guard above is emitted on private functions too; that asymmetry is deliberate."* So the ticket's description of the code is accurate as read.

Prior decisions this must not contradict:
- **18 §4** (`18-boundary-defence.md:817-818`; :815 is the heading): analysis is function-local; *"a value handed to another function counts as unchecked, and is guarded."*
- **18 Answer, line ~438** (`:437-441`): elision is exported-vs-local, one entry label per function.
- **18 §2** (`:416`): a foreign declaration may promise only what one O(1) BEAM guard decides, so `list<Order>` cannot be checked element-wise at the boundary.
- **26 §1** (`26-data-modelling.md:379-381`): the tag test is unconditional because *no body ever checks which record a map claims to be*.
- **F24 §2/§3** (`F24-boundary-kind.md:115-125`) and scenario **F24.6** (`:229`), which pins "private `Inner(int n)` unguarded".

## Sub-decisions the ticket implies

1. **Does a guard follow the function's visibility, or the parameter's type?** This gates the rest.
2. Follows from 1 — the record tag test on a private function: keep or drop.
3. Follows from 1 — the int/float kind test on a private function: keep dropped or add.
4. Follows from 1 — whether "exported" is the right discriminator at all.
5. The one sentence stating the rule for both guards.

Per CLAUDE.md, only 1 is put to David. Probe results for 2-5 are given so the answer to 1 can be read off.

## What was measured

All on OTP 25, x86-64, 4 cores. `bench.out`, `sizes.out`, `elision.out`, `forge.out`, `leaf.out`, `labels.out`.

**Cost of one guard** (hand-written Erlang with the shape `bs_emit` builds; `+deterministic +no_line_info`):

| | Code chunk | .beam file | Per call (9 × 10M calls, min / median, two passes) |
|---|---|---|---|
| tag: `when map_get('Kind', M) == order` | +12 B | +40 B | 10.3 → 17.2-17.5 ns (**≈ +7 ns**) |
| int: `when is_integer(N)` | +5 B | +24 B | 4.6 → 4.8-4.9 ns (**≈ +0.2 ns**) |

Ticket 26/46 cite **+14 B** for the tag (`26-data-modelling.md:302`), 18 cites **+3-5 B** for `is_integer` and call time "below ±0.09 ns/call" (`18:438`). Sizes agree within a couple of bytes; the int call-time agrees in order of magnitude (my +0.2 ns is within my own run-to-run spread). **The tag test's call time was never measured before this run**: ≈ 7 ns, about 70% of a minimal call here. The loop calls through a `fun`, so absolute figures are inflated for both; the difference is what matters.

**The OTP compiler removes a redundant `is_integer` on a local function and does not remove the tag test.** (`elision.out`)
- `g_both:inner_int` (`inner_int(N) when is_integer(N)`, only caller already guarded): compiled body has **no `is_integer` test**, only `gc_bif '+'` on `{tr,{x,0},{t_integer,any}}`. The guard cost nothing.
- `g_both:inner_tag` (`when map_get('Kind', M) == order`, only caller already tag-tested): the compiled body **keeps** `map_get` + `is_eq_exact`.
- `g_unknown:inner` (caller passes `element(1, X)`): the `is_integer` test **is kept**. Elision happens only where the caller's type is provable.
- `leaf.S:bump_g` (argument comes out of a list comprehension): the `is_integer` test is kept (`leaf.S` is generated into `ebin/` by `run-all.sh`, not committed).
- **Verifier addition (not in the committed probes):** a callee with two callers, one proven and one not, **keeps** `{test,is_integer,…}`; elision needs every caller proven.

**18's entry-label claim holds** (`labels.out`): an exported function called from inside its own module jumps to the label *after* `func_info`, where the guard sits — local calls to an exported function pay its guard. A local function has the same `func_info`/label pair. Nothing distinguishes caller by module on the BEAM.

**A forged value reaches a private function when the exported function forwards it unchecked** (`forge.out`, `leaf.out`). *These rows are true by construction* — the hand-written private function has no guard, so it accepts anything; they illustrate the consequence if `bsc` emits no element guard, they do not test what `bsc` emits. That premise rests on reading `bs_emit.erl` (the verifier confirmed it for exported `list<int>`/`list<Order>`: `kind_only` returns `none` for a list, `record_tag` matches one closed map only). Whether a nested-field check exists (`ship_field`, 26 §1's "function by function") is **unverified**:

| call | result |
|---|---|
| `ship(Forged)`, exported, record-typed, tag-tested | `{error, function_clause}` — stopped at the door |
| `ship_all([Forged])`, exported `list<Order>`, private callee has **no** tag test | `[{shipped, #{'Kind' => not_an_order, …}}]` — silent |
| `ship_all_guarded_inner([Forged])`, same, private callee **has** the tag test | `{error, function_clause}` |
| `ship_field(Envelope{Order = Forged})`, nested record, private callee has no tag test | `{shipped, Forged}` — silent |
| `total([1, 2.5])`, exported `list<int>`, private `bump(int n)` unguarded | `5.5` — **a float out of an `int` function, silent** |
| `total_guarded([1, 2.5])`, private `bump` has `is_integer` | `{error, function_clause}` |

That the exported `list<Order>` / `list<int>` / nested-record parameter itself gets no element guard is from reading `record_tag/2` (single closed record only, `bs_emit.erl:508-515`) and `guard_one` (no list branch), plus 18 §2's O(1) rule — **not executed through `bsc`**.

## The question for David (sub-decision 1, alone)

Two functions, one exported, one private. The exported one takes a container, so its boundary cannot check the elements. Does the private function's own parameter get a guard?

```csharp
public int Total(list<int> xs) => Sum(xs |> Map(Bump));   // xs is only checked as "a list"
int Bump(int n) => n + 1;                                  // private
```

A call `Total([1, 2.5])`:

**Option "visibility decides"** (18 §4 read literally; the tag test on a private function is dropped to match the kind test).
```erlang
bump(N) -> N + 1.            %% Total([1, 2.5]) => 5.5, an int function returned a float, silently
```
and likewise `Inner(Order o)` under an exported `ship_all(list<Order>)` receives a forged map and ships it (`forge.out`).
Compiler delta: in `guard_one`, add `Public` to the `{ok, Tag}` branch (one `when Public`); check for any test pinning the private tag test (none pins the *tag* test — `grep "map_get('Kind'"` in `compiler/test` finds nothing — but three tests pin private-is-unguarded for the kind/range guards: `boundary_kind_tests.erl:88`, `boundary_range_tests.erl:122` (F37.5), `guard_kind_tests.erl:14`); amend `bs_emit.erl:329-332`'s comment. Cost saved: the tag guard's +12 B and ≈ 7 ns per call on every private record-taking function.

**Option "type decides"** (the kind test is also emitted on private functions; both guards now follow the parameter's type).
```erlang
bump(N) when is_integer(N) -> N + 1.     %% Total([1, 2.5]) => {error, function_clause}
```
Compiler delta: drop the `Public` argument from `guard_one`/`boundary_guards` and the `none when Public` guard; flip F24.6 (`Inner` becomes guarded) **and F37.5 and the three tests above**; note `int_guard` also emits the `owed_arms` range tests (`>= 0`, `=< 255`) for refined ints, so dropping `Public` puts *range* guards on every private refined-int function too — **unpriced** — and contradicts the comment at `bs_emit.erl:175-180`; amend 18 §4 and F24 §2 where they say "exported only". Cost: ≈ 0 only where **every** caller proves the integer (OTP drops the test, `elision.out`; the verifier's `two.erl` showed a callee with one proven and one unproven caller **keeps** the test — and a helper reached through `Map(Bump)` or a comprehension, the very leak case, is typically unproven). The 0.2 ns is also measured against a body (`N+1`) that already needs an integer; a pass-through body would pay the full test, +5 B and ≈ 0.2 ns where they cannot (list elements, results of calls into foreign code).

**Option "status quo, but say why"** (tag everywhere, kind exported-only). Compiler delta: none beyond a sentence in 18 §4. Leaves `Total([1, 2.5])` => `5.5` and keeps a ≈ 7 ns dead test on every private record function whose caller already proved the tag.

### Strongest counterargument to each
- *Visibility decides:* the container holes above. `ship_all` and `ship_field` show a forged record reaching a private function today only because the tag test happens to be there; removing it turns two measured `function_clause` crashes into silent success. 18's own guarantee (C) is *"never silently"*.
- *Type decides:* it contradicts the sentence in 18 §4 and F24 §2 that a private function's every call site is checked (`leaf.out` shows that sentence is false for container-delivered elements), so it reopens text two features cite; and for records the guard is *not* elided when dead, so a hot private helper pays ≈ 7 ns for nothing.
- *Status quo:* the asymmetry has no stated principle, and the one candidate — "a record can carry records, an int cannot" — fails: `list<int>` carries ints exactly as `ship_all` carries records (`leaf.out`).

## Recommendation

**"Type decides" — a weak recommendation, resting on a reading of `bs_emit.erl` rather than on the probes, and costlier than first stated (range guards, F37.5, three tests, the all-callers-proven condition).** The evidence removes the reason for the asymmetry: the leaf kind has the same container leak as the record tag, the two are caught (or missed) identically, and the OTP compiler already deletes the int guard wherever the caller proves it, so widening it costs nothing where it is dead and buys a crash where it is not. That matches the ticket's own cost heuristic (too narrow = silent hole; too wide = measurable and loud).

The one real cost lands on the tag test: not elided when dead, ≈ 7 ns. If that matters for hot private record helpers, the follow-up is a separate emit-side optimisation (skip the tag test when the call site is itself a literal record construction), not a reason to keep the split.

Sub-decisions 2-5 then follow: tag test stays on private; kind test is added on private; "exported" is not the discriminator for either (the entry-label finding makes it the wrong lever for elision, and the container finding makes it the wrong lever for safety); the rule in one sentence: **a parameter whose declared type is a record, `int` or `float` is guarded where the body would not object, in every function, and the Erlang compiler removes the guard where a caller has already proved it.**

## Neighbours

| Language | Evidence | What it shows |
|---|---|---|
| Elixir 1.14 | `ex_forms.out`, `ex_disasm.out`: private `defp inner(%Order{} = o)` compiles to `#{'__struct__' := 'Elixir.Order'}` and disassembles to `is_map` + `get_map_elements` + `is_eq_exact` against `Order`; `defp inner_plain(o)` (no pattern) has no check at all and falls to `error({badkey, total, _})` on field access | Elixir adds the struct check on private functions **only when the author wrote the pattern**; it never inserts one. The author chooses, and a forged map into `inner_plain` fails only by incidental `badkey`. The Elixir compiler sources (`elixir_map.erl`, `elixir_erl_pass.erl`) are **not installed** on this host (`/usr/lib/elixir` holds `ebin` only), so no file:line citation into the expander; evidence is beam-level. |
| Erlang | `-spec` emits no guard; `g_none.erl` is the "documentation only" case | The type is not a runtime check anywhere without hand-written guards. |
| Elm | `elm.out` — compile failed offline | No evidence gathered. 18's survey (`18:448`) already records Elm's boundary design; not re-run. |
| Gleam | — | **Not surveyed.** |

## Evidence limits
- All timings are OTP 25 on a shared 4-core container, via `timer:tc` over `fun` calls; treat the ns figures as ordinal. Two passes agree within ≈ 0.2 ns for int and ≈ 0.3 ns for tag.
- Nothing here ran through `bsc`. Whether `bsc` emits an element-level guard for `list<int>` or nested records beyond what I read in `bs_emit.erl`/18 §2 is unverified. If it does, the container holes above close and the argument for "type decides" weakens to the 18 §4 text alone.
- OTP 28's type pass may elide more than 25's; the tag test might become elidable. Re-run `run-all.sh` on OTP 28 before relying on the "tag test is not elided" row.
- Whether 18 intended `list<Order>` elements on an exported parameter to stay unchecked (rather than only on foreign declarations, `18:416`) I did not find stated.
- An independent verifier re-ran every probe: all reproduce; timing claims survive 5 further runs (tag ≈ 6.9–7.2 ns, int ≈ 0.2–0.3 ns by min). Corrections applied above: existing tests pin private-unguarded; range guards ride with `int_guard`; elision needs all callers proven; line citations. The "≈ 70% of a minimal call" figure was derived against a loop-plus-fun-call baseline, not a probe output.
- The ticket 59 file already contains the "forged record via an exported function" argument (its "It is not" paragraph); the probes measure it, they do not originate it.
