# 13 — The pinned OTP range, measured

Research for [issue 13](../issues/13-compilation-target-decision.md) §4–5, which pinned the
supported range at **current and previous two majors** and recorded it as **provisional**, because
`+from_abstr` had only ever been confirmed on OTP 28.5 — the only release installed here.

This is the walking skeleton's first payment against that debt. It is a *measurement* file: no
decision is taken, and any amendment to ticket 13 is recommended at the end for the map to make.

---

## The verdict, first

**The pinned range holds, and it is conservative by two majors.**

`erlc +from_abstr` exists and works on **OTP 24, 25, 26, 27 and 28**. The forms *this compiler*
emits build unchanged on every one of them, the resulting modules are callable and return the
right answers, and the emitted `-spec` survives **byte-identically** — equal `phash2` across all
five releases [L1].

Nothing found narrows the range. Two things sharpen it:

- **The range constrains the target runtime, not the build host.** An OTP 28-built beam-sharp
  `.beam` will not load on 26 or 27 (`{error,badfile}`), and neither will the compiler's own
  `.beam` files. **The portable artefact is the `.abstr`, not the `.beam`** [L2]. Ticket 13 never
  says otherwise, but "supported OTP range" invites the other reading and the spec should close it.
- **The committed examples do not exercise what the emitter can produce.** Between them,
  `readings.bs` and `math.bs` reach **6 of `bs_emit`'s type branches and 7 of its operators**;
  five type forms and four operators go unvisited [L3]. A corpus built only from the examples
  would have reported the range proved while a third of the emitter's output vocabulary was
  never compiled anywhere.

## Method and provenance

| Mark | Meaning |
|---|---|
| **doc** | Official documentation or the ticket's own text |
| **src** | Source code in this repo or in OTP |
| **local** | Observed directly on this machine |

Probe: [`13c_otp_range_corpus.sh`](../prototypes/13c_otp_range_corpus.sh). `.abstr` files are
generated once by the current compiler on the host (**OTP 28.5, erts 16.4**) and those exact files
are then carried to each older runtime — which is the thing ticket 13 §4 actually needs proved,
rather than "some abstract format builds".

Container images are **arm64-native** (`erlang:24`…`erlang:27`, `aarch64-unknown-linux-gnu`),
deliberately: [`research/29`](29-refinement-type-prior-art.md) gap [g3] found amd64 emulation on
this machine unreliable to the point that `debian:13` containers will not start at all. Every
image here ran first time. **This is Linux/arm64 only** — see [Gaps](#gaps).

---

## 1. Does `+from_abstr` exist on the oldest supported release?

**Yes, and well below it.** [L1]

First, a false negative worth recording so nobody repeats it: `erlc -h` does **not** list
`from_abstr` on *any* release, 28.5 included, where it demonstrably works. It is a compile option
passed through `+`, not a documented `erlc` flag, so the only honest test is to build with it.

| OTP | `+from_abstr` present | our forms build | modules callable | emitted `-spec` |
|---|---|---|---|---|
| 24 | yes | yes | yes | identical |
| 25 | yes | yes | yes | identical |
| **26** — ticket 13's pinned floor | yes | yes | yes | identical |
| 27 | yes | yes | yes | identical |
| 28.5 — host, reference | yes | yes | yes | identical |

Callable means the emitted modules were loaded and run, not merely compiled:
`'Readings':'Classify'({ok,5})` → `positive`, `'Math':'Fib'(10)` → `55`, and the synthetic
coverage module's operator and nested-tuple clauses all return the expected values on every
release.

## 2. Does the emitted `-spec` survive the older path?

**Yes, byte-identically.** Ticket 13 §6 established that a `-spec` is lost through the `.core`
path and survives the Abstract Format path *by construction*, measured forwards. Backwards had
never been checked. It survives.

Method: build on the target, then read the `-spec` attributes back out of the resulting `.beam`
via `beam_lib:chunks(F, [abstract_code])` and hash them [L1].

| Module | specs | `phash2` on 24 / 25 / 26 / 27 / 28 |
|---|---:|---|
| `Readings` | 1 | `9167320` on all five |
| `Math` | 2 | `4522108` on all five |
| `Coverage` | 8 | `43439134` on all five |

The `Readings` spec is the interesting one, because it is where ticket 13's widening rule shows:
a set-theoretic union of tuple types on the way in, a four-atom union on the way out, and the
whole thing lands in the abstract chunk verbatim on a runtime two majors older than the one that
emitted it.

## 3. What the corpus actually covers — and what it did not

This is the finding that changes how ticket 13 §4's CI corpus should be built.

`bs_emit` can produce these spec type forms: `fun`, `product`, `union`, `tuple`, `none`, `atom`,
`integer`, `range`, `neg_integer`, `non_neg_integer`, `pos_integer` — and maps beam-sharp
operators onto `=:=`, `=/=`, `=<`, `andalso`, `orelse`, `+`, `-`, `*`, `<`, `>`, `>=` [src,
`compiler/src/bs_emit.erl` `spec_type/1`, `int_part/1`, `erl_op/1`].

The two committed examples emit [L3]:

| | covered by `examples/*.bs` | **not** covered |
|---|---|---|
| type forms | `atom` `integer` `product` `tuple` `union` `fun` | **`none` `range` `neg_integer` `non_neg_integer` `pos_integer`** |
| operators | `+` `-` `<` `=<` `>` `>=` `andalso` | **`*` `=:=` `=/=` `orelse`** |

So the probe carries a second, synthetic module — `Coverage.abstr`, hand-written from a reading of
`bs_emit.erl` — exercising every uncovered form. **It builds and runs on all five releases too.**

Two honest limits on that:

- `Coverage.abstr` tests that *those forms are accepted by older `erlc`*. It does not prove the
  emitter produces exactly them; it is hand-written, not generated.
- **Four of the uncovered type forms are currently unreachable from the surface language.**
  `range`, `neg_integer`, `non_neg_integer` and `pos_integer` come from `int_part/1`, which reads
  an interval out of a *declared* type — and this slice's surface has no interval type syntax, so
  a parameter declared `int` always widens to `integer()`. Ticket 20 put intervals in the algebra
  and the checker uses them (that is what makes `math.bs` exhaustive without a catch-all), but
  they do not yet reach a signature. So these branches are **live code with no surface path**,
  which is worth knowing independently of the OTP question.

## 4. Which artefact is portable

Measured because it is easy to conflate with the range, and the consequence runs the opposite way
from what "supported OTP range" suggests [L2]:

| Artefact | on OTP 26 | on OTP 27 | on OTP 28 (control) |
|---|---|---|---|
| a beam-sharp `.beam` built on 28 | `{error,badfile}` | `{error,badfile}` | `{module,'Readings'}` |
| the compiler's own `.beam` | `{error,badfile}` | `{error,badfile}` | loads |

**The `.abstr` travels; the `.beam` does not.** This is ordinary BEAM behaviour — a newer file
format version is simply refused — but it fixes the shape of what ticket 13's range means:

- `erlc +from_abstr` must run **on the target**, and the pinned range is the set of runtimes where
  that is guaranteed to work.
- The **compiler host is unconstrained by the range**, which is exactly what ticket 13 §2 bought
  by giving up `erl_syntax`/`merl` — and confirms it, since the compiler's own beams demonstrably
  do not run across the range while its *output* does.
- Distribution of a beam-sharp library across the range means shipping `.abstr`, or building per
  target. Neither the ticket nor the README says which, and it is a real question the module
  system fog will inherit.

## 5. A defect found on the way, not fixed

**The built escript does not run.** `compiler/rebar.config` line 7 sets

```erlang
{escript_emu_args, "%%! -escript main bsc_cli\n"}.
```

while the module is `bsc` (`compiler/src/bsc.erl` line 13, exporting `main/1`). So the escript
built by `rebar3 escriptize` dies immediately [src, L4]:

```
escript: exception error: undefined function bsc_cli:main/1
```

This is the invocation `compiler/README.md` documents, so the README's own quickstart does not
work as written. Everything in this file was produced by calling `bsc:main/1` directly through
`erl -pa`, which is why the probe does that rather than using the escript.

**Not fixed here** — the compiler is outside this task's `write_scope`. It is a one-word change
(`bsc_cli` → `bsc`) and it wants a test that actually executes the built escript, since the unit
suite passes without touching it.

---

## Verdict on ticket 13's pinned range

**It holds.** The provisional marker can come off, on this evidence:

- `+from_abstr` is confirmed on the pinned floor (26) and on 27, not merely on 28.5 [L1].
- The forms this compiler emits build and run there unchanged [L1].
- The emitted `-spec` survives byte-identically, closing the backwards half of §6 [L1].

**It does not need narrowing.** Nothing found is version-sensitive at all — the emitter sits on
the format's stable core, which is what §5 hoped three columns would enforce.

**It could be widened, and probably should not be.** 24 and 25 pass the same corpus. But §5's
reason for three was never that older releases fail — it was that "three matches the BEAM
ecosystem norm for libraries and puts real pressure on the emitter to stay on the format's stable
core". That reasoning is unaffected by 24 and 25 passing, and a wider range is a larger CI matrix
and a larger promise for no gain. **Recommend recording that the floor is not a cliff** — useful
if a user on an older release asks — without moving the pin.

### Recommended amendments to ticket 13

Recommended, not made; `write_scope` for this task is this file and `prototypes/13c*`.

**A. Drop "provisional" from §5** and cite [`13c`](../prototypes/13c_otp_range_corpus.sh). The
open verification §5 names is discharged.

**B. Say in §4 that the range is a property of the *target runtime*.** The compiler host is
unconstrained — §2 already implies it and §4 does not say it, and §4's own artefact (`.beam`) is
the one that does *not* travel. One sentence.

**C. The CI corpus §4 asks for should be built from the emitter's vocabulary, not from the
examples.** §3 above is the argument: the examples cover about two-thirds of what `bs_emit` can
produce, and a corpus that grows only when someone writes a new `.bs` example will drift further
behind the emitter, silently. The cheap fix is a generated coverage module, regenerated from
`bs_emit`'s branches, alongside the hand-written examples.

**D. Not ticket 13's, but it should land somewhere**: `range`/`neg_integer`/`non_neg_integer`/
`pos_integer` in `int_part/1` are unreachable from the current surface (§3). Either the surface
owes interval type syntax, or those branches are speculative and should be marked as such.

## Gaps

- **[g1] Linux/arm64 only.** Every measurement is on `erlang:NN` arm64 images plus the macOS
  host. Ticket 13 §4's CI corpus presumably wants at least Linux/x86-64 as well; nothing here
  suggests architecture-sensitivity — the abstract format is architecture-neutral by
  construction — but it is untested and the ticket asks for a corpus, not a spot check.
- **[g2] Three modules is not a corpus.** Two examples and one synthetic module. The finding in §3
  is precisely that coverage is what matters rather than volume, but a real corpus would also want
  a *large* module, since nothing here tests whether anything degrades with size.
- **[g3] OTP 29 was not tested**, because it is not released. When it is, the range rolls to
  27–29 and 27 is already confirmed here, so the next roll costs nothing to verify.
- **[g4] Only `+debug_info` was used.** Other `erlc` options that a real build might pass —
  `+deterministic`, `+warnings_as_errors`, native compilation flags — were not exercised across
  the range.
- **[g5] Dialyzer was not run on the older releases.** Ticket 13 §6's widening is measured here as
  *the spec survives*; whether Dialyzer *reads* it identically on 26 as on 28 is a separate
  question, and ticket 27 already found an emitted polymorphic spec is documentation rather than
  enforcement.

## Claim → source

| # | Source | Mark |
|---|---|---|
| L1 | [`13c_otp_range_corpus.sh`](../prototypes/13c_otp_range_corpus.sh) — `+from_abstr` builds our `.abstr` on OTP 24/25/26/27/28; modules callable with correct results; `-spec` `phash2` equal across all five | **local** |
| L2 | [`13c`](../prototypes/13c_otp_range_corpus.sh), final section — a 28-built beam-sharp `.beam` and the compiler's own `.beam` both `{error,badfile}` on 26 and 27; the same file loads on the host | **local** |
| L3 | [`13c`](../prototypes/13c_otp_range_corpus.sh), coverage comparison — the type forms and operators the committed examples emit, against those `bs_emit` can produce | **local** |
| L4 | Observed running `rebar3 escriptize && ./_build/default/bin/bsc …` — `undefined function bsc_cli:main/1` | **local** |
| 1 | [Ticket 13](../issues/13-compilation-target-decision.md) §4 (pinned range, CI corpus, `raw_abstract_v1` as a version marker), §5 (current and previous two majors; the open verification), §6 (`-spec` emitted and widened) | **doc** |
| 2 | `compiler/src/bs_emit.erl` — `spec_type/1`, `parts/1`, `int_part/1`, `atom_parts/1`, `erl_op/1`, `to_abstr/1` | **src** |
| 3 | `compiler/rebar.config` line 7 versus `compiler/src/bsc.erl` line 13 — `escript_emu_args` names `bsc_cli`, the module is `bsc` | **src** |
| 4 | `compiler/README.md` — the documented quickstart, which uses the escript | **doc** |
| g1–g5 | Gaps — see [Gaps](#gaps) | gap |
