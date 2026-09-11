# 63d — which Erlang-compiler refusals reach an author whose program cleared `bs_check`?

ENG-256's first owed item, measured 2026-09-11. Probe 63b (beside this directory) found one
leak — a user function call in a guard — and asked how big the class was. This directory is the
answer: one module per candidate, compiled with the built `bsc`, judged on whether a `compile:`
line (the relay in `bsc.erl` of OTP's own report) reached stderr.

- `make-probes.sh` writes the probe modules. Run it to regenerate them.
- `run.sh` compiles each and the shipped `compiler/examples` corpus, and writes `results.md`.
- `results.md` is the measurement **on the tree before F41**, taken with the `bsc` built at
  `30da2ee` (`bash run.sh /path/to/that/bsc`). It is the record of the class.
- `results-after-F41.md` is the same sweep on the tree that shipped F41.

## What the sweep found

**Every call form the grammar admits into a guard leaked**, in six spellings: a local call (G01),
the same call in a switch-arm guard (A01 — a different walk in `bs_check`, which is how a refusal
wired at the clause has missed the arm before), a qualified call to a sibling module (G02, as
`illegal guard expression`), a foreign call to a function that is not a guard BIF (G04, the same),
a pipe (G06, a local call by the time the checker sees it), and `ValidateAs<int>(t)` (G10), which
leaked the emitter's own mangled name `bs@validate@1@r/1`. F41 refuses all six.

**A foreign call to a BEAM guard BIF compiles** (G03, `:erlang.byte_size`), and stays legal: the
restriction is inherited from the BEAM (ticket 63 Q4), and the BEAM admits its guard BIFs.

**A valve in a guard was never a leak** (G05): `bs_lower:valves/1` turns it into a two-armed
switch before the checker runs, and a switch in a guard is refused as `switch_in_guard`. The
first draft of this probe returned `(:ok, u)` from a `result<int, atom>` — which is
`int | (:error, atom)` — and failed its own return check, so it measured nothing until the
advisor review caught it. Once measured, it exposed a second fault in F41's first build: the
call walk descended into the refused switch and reported two errors for one guard.

**Everything else the grammar lets into a guard is legal on the BEAM**: projection, record
construction and update (maps are guard-legal), strings, tuples, lists, `/` and `%` (G07–G13).

**One warning leaks and is not fixed here**: a private function nobody calls (B03) compiles at
exit 0 and prints `compile: …bs:0: Warning: function 'Helper'/1 is unused` — Erlang's voice, at
line 0. Whether this language warns on an uncalled private function is not decided by any ticket
(grepped 2026-09-11), so it is filed, not built: [ENG-359](https://linear.app/davewil/issue/ENG-359).

**Three body-level faults are unreachable**: a name bound inside one switch arm (B01 — an arm is a
single expression and a bare `=` cannot introduce a name there), an unused binding (B02 — the
emitter lowers it to a `_`-prefixed variable), and a re-bound parameter (B04 — refused by the
checker as `binds u twice`).

**The shipped examples corpus produces no `compile:` line.** The class is author-reachable, not
shipped.
