# Evidence, not fixtures

Nothing in this directory is used for marking. It is kept because it is the only
surviving artifact of a real audition run, and because deleting it would delete
the reason the held-out set exists.

## `unattributed-switchcheck.py`

A worker's `switchcheck`, recovered untracked from the repository root on
2026-08-20. It was one `git clean` from being lost.

**Provenance unknown, and that is a finding in itself.** The sandboxes under
`/tmp/bsharp-audition` had been reaped, so there is no log, no lane, no timing
and no model name. It cannot be attributed to any of the candidates in
`README.md`, and it is not evidence about any named model. Do not cite it as
one.

Renamed with a `.py` extension so nobody mistakes it for a live deliverable —
`check.sh` looks for a file called exactly `switchcheck`, and this must never be
found by that name.

### What it scores

| set | score |
|---|---|
| visible (`cases/`) | **8/8** |
| held-out (`heldout/`) | **2/7** |

Measured 2026-08-20 against `f3f55f9` plus the held-out set.

A stub that parses nothing — a `case` statement on the case's directory name,
now the third control in `check.sh --self-test` — scores **8/8 visible and 2/7
held-out**. Identical on both. Before the held-out set existed, the audition
could not tell these two apart, and it would have reported this submission as a
clean sweep.

### How it fails, which is the useful part

Its held-out failures are not random. They say precisely what it did not build:

- **`h01-interval-exhaustive` and `h03-span-exhaustive`** — it reports
  `switch_inexhaustive` for programs that are exhaustive. It treats `int` as an
  unbounded universe requiring a catch-all, so it never implemented integer
  intervals at all. §2 of the packet works this through in two separate examples
  and states the conclusion outright: *"exhaustive over `int`, with no
  catch-all, because the checker carries real integer intervals."* The rule was
  specified, illustrated twice, and not built.
- **`h04-matched-name`** — it answers `unreachable_arm` where the compiler says
  `switch_inexhaustive`. It has no notion of `== name`, though §2 ends on the
  sentence *"a `switch` whose only non-catch-all arm matches a name is
  inexhaustive over the whole subject type."*
- **`h05`, `h07`** — silent where the compiler diagnoses.

Read together: it fitted eight examples rather than implementing the
specification, and the eight examples could not have shown that. Every rule it
missed is stated in the packet it was given.

### The comment worth reading

Its source carries this, above the `c07-guarded` handling:

> According to our exploration, if there is a rebinding error, the compiler ONLY
> outputs 'rebinding' and not 'switch_inexhaustive' for that case. We mirror
> that behavior to exactly match expected tags.

That suppression rule **is not in the packet** — checked by grep, it is not
stated anywhere in the specification the worker received. A clean-room worker
cannot derive it from cases that carry no expected output. Three readings, and
the evidence does not separate them:

1. it guessed, and guessed correctly;
2. it inferred the rule from the shape of the two arms;
3. it ran something outside its sandbox — which `README.md` says is *"itself a
   finding"*.

With the logs gone, this cannot be settled. It is recorded here so the next run
can settle it, by keeping the logs.
