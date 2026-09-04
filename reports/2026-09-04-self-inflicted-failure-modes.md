# The failure modes this repository keeps re-committing, and the nine detectors that catch them

**2026-09-04.** An audit of the last 100 commits (`9b9c62b`..`b70c9a3`) and of
`reports/2026-09-01-compiler-review.md` for **self-inflicted** defects — the ones this project
made, found itself, wrote down, and then made again. The output is `detectors/`: nine executable
checks, each carrying the commits it came from and a `--self-test` with both halves.

This is the same exercise `ci.yml` records for 2026-08-18 — *"Added 2026-08-18 from an audit of the
last twenty commits for self-inflicted defects"*, which produced `check-gates-wired.sh`,
`check-cwd-independence.sh`, `check-shell.sh` and `check-no-silent-skip.sh` — run again at five
times the window.

A snapshot, like the 2026-09-01 review. It will go stale; the detectors will not.

---

## 0. The verdict strip

| | |
|---|---|
| Commits read | 100, in full — 3,344 lines of commit body |
| Distinct classes found | 11 |
| Classes with a detector | 9 |
| Classes named without one | 2, each with the reason |
| Defects in the repository, found by the detectors | 23 — 18 on the first run, 5 more once the resolver stopped asking a case-folding filesystem |
| Defects in the detectors themselves, found afterwards | 5 — two while building, one by review, two by CI. Listed at §6 rows 19–22, because a check that was wrong is evidence about checks |
| Of those 28, fixed | 28 |
| Detectors that fire on their own historical commit | 9 of 9 |
| Detectors green on the tree after the fixes | 9 of 9 on macOS **and** 9 of 9 on a Linux host with a case-sensitive filesystem and an `/usr/bin/editor`. Two CI reds were needed to get there — §6 rows 21 and 22 |

---

## 1. The taxonomy

Ordered by how often the class recurs in the window, not by severity.

### 1.1 The stale suite count — `detect-stale-suite-count.sh`

A number in prose that counts something the repository can recount, written where nothing
recounts it.

The most-repeated class in the window, and every instance was found by a person reading:
`80eb902` (the session list said TWENTY-FOUR, wrong by one for most of a day), `619b4b9` (the same
count stale again inside one session — *"a fifth surface no gate reads"*), `910ed93` (F28's Status
line said "36 verify stages"), `6eee4e9` ("eleven days" against thirteen), `c7c99be`
(`bs_diag.erl`'s heading said 24 against 69 clauses), `1cb1fd6` ("four positive controls" against
twelve), `0c231ae` ("Fourteen shapes" while pinning seventeen), `d6c889c` (a self-test comment
saying three controls while running seven).

**The scoping is the finding.** The first rule read every count of gates *or* stages and reported
48 lines, of which 2 were the class. Measuring that surfaced a line the repository had already
drawn and I had not seen — and it runs between the two words rather than around both:

- **A gate count is corrected.** `80eb902` and `619b4b9` both recounted and fixed it, and
  `check-gates-wired.sh` keeps the *names* honest on four surfaces beside it.
- **A stage count is deleted.** `910ed93`, in as many words: *"the test count is dated by the
  Status it sits in, but a stage count is re-staled by every gate added. Deleted rather than
  updated."*

So the detector owns the half with no owner. `ENG-290` is still open against `stage.sh` for
exactly it.

### 1.2 The vacuous control — `detect-swallowed-status.sh`

A control inside a `--self-test` whose verdict cannot fail.

`be6307b`: *"check-tour.sh's negative control went through a helper ending in `|| true`, so 'the
document as committed was accepted' could never fail"* — vacuous until 2026-09-02. `d67ab38`: the
self-test captured `judge`'s exit status and discarded it, *"which is what every green control
looks like"*. `a923fe6` states the rule: *"Nothing reads a launcher's `$?`… A control that never
wrote a status is red."* `1cb1fd6`: a control launched and never judged.

`check-shell.sh` cannot see any of this, and should not: `|| true` on a `grep` allowed to match
nothing is correct. What makes it a defect is *what it is attached to*.

### 1.3 The unmanifested tool — `detect-unmanifested-tool.sh`

A gate shells to a command that no manifest declares and no guard tests.

`aeb4fd8`: python3 was a hard dependency of a gate in CI and appeared *"in no manifest, no workflow
step, no gate and no README"*, while `.tool-versions` opened by calling itself the only record of
what the repository is built with. Every build was green, because the runner image and the Xcode
command line tools each ship a python3. `e517349` is the same class one step on: no guard, so the
failure arrives as a bare `command not found` under a comment about packet staleness.

`check-toolchain.sh --env` asks whether every **declared** tool is present. Nothing asked whether
every **invoked** tool is declared, and that is the direction the defect travels in.

### 1.4 The stale citation — `detect-stale-citation.sh`

A document cites `file:line` and the line moved.

`9f4590c`: *"All eighteen of F29's source-line references had drifted, and several were wrong
rather than merely stale."* `cd61280`: three TOUR.md transcripts named lines the compiler reports
two and three further down — *"captured at three separate times and none was re-read"*.
`check-links.sh` checks that a cited **path** exists; the number after the colon is read by
nothing.

### 1.5 The unenumerated directory — `detect-unenumerated-shell-dir.sh`

A directory of shell scripts that no enumeration reaches.

`check-shell.sh`'s own header: *"The audition's four scripts sat unlinted from the day they were
written, because they live in `handoff/` and nothing added it to this list… A directory missing
from this loop does not fail — it reports success over a smaller repo than you think it read."*
`check-gates-wired.sh`'s: *"`editor/bin/` held TWO gates the workflow had never mentioned… An
unmentioned check is not outside the rule; it is the rule's blind spot."*

Both gates now enumerate. Neither asked whether its enumeration was complete.

### 1.6 The shared scratch path — `detect-shared-scratch.sh`

Two runs writing to one directory.

`15ab27e`: *"check 6 compiled all sixteen example modules into ONE `-o` directory… A second module
emitting a beam under a first module's name would overwrite it with both compilations exiting 0,
and the count would still read sixteen."* `a923fe6` / `ENG-318`: `bsc`'s scratch name comes from
`erlang:unique_integer`, which repeats across VMs — *12 distinct values from 30 fresh VMs* — so two
concurrent replays shared one `Fib.beam`.

Not hypothetical for this project's own bar: two clean-clone runs, sequential, and a fixed scratch
path means run 2 can read run 1's leftovers.

### 1.7 The split table — `detect-split-table.sh`

A blank or prose line closes a markdown table, and the rest renders headerless.

`910ed93`: the blank at `features/README.md:112` sat there thirteen days. *"`check-status-claims.sh`
section B stayed green throughout, because it asks whether a row for each F-file EXISTS, and a row
in the second table exists."* The same commit records why the obvious rule is not enough: a check
written as `prev == ""` passes the blank-line control and is blind to a prose line doing the same
damage.

`910ed93` closed it for one file inside one gate. This widens it to every markdown file.

### 1.8 The dead repo-internal path — `detect-dead-repo-path.sh`

A document points at a file this repository does not have, outside the region `check-links.sh`
reads.

`check-links.sh` was written for exactly this and is scoped to the shipping package, where it
found *25 citations of `examples/<name>.bs` paths that had not existed since F15 made a module a
directory*. The design record was left out deliberately and has never been covered — `5abb590`:
*"nothing under `wayfinder/` is gated, so nothing noticed"*; `caa3c52`: *"two guessed ticket
filenames were caught and fixed"* by hand. `ENG-304` records that nothing under `handoff/` is
link-gated either.

### 1.9 The inherited runner environment — `detect-inherited-runner-env.sh`

A self-test that reads an environment variable the CI runner also sets, without constructing both
halves.

`43771f0`: *"`verify.sh --self-test` has failed on every push since aba3fb0, taking master red for
two commits, and it fails for a reason that cannot be seen from a developer machine."* The CI
control set `GITHUB_ACTIONS=true`; the local control set nothing, so on the runner it inherited
`true` and **the gate accused the feature of working**.

Zero live instances — `43771f0` fixed the only site and swept for others. This is a regression
guard, and its `--self-test` is where the evidence lives.

---

## 2. The two classes named without a detector

Both are real and both are in the window. Neither got a detector, and the reason is stated rather
than left as an omission.

### 2.1 The silent skip in a loop

A loop that steps past an item without counting it, so a green run reports over a smaller set than
you think it read.

`83472eb`: `check-status-claims.sh` did `[ -n "$status" ] || continue`, so an entry with no row was
*"neither probed nor reported"* — `map<K, V>` sat in that hole for nine days and the gate printed
its usual count throughout. `728f439`: `[ "$form" = "type" ] || continue` silently skipped a probe
form the gate's own legend documented. `5f37397`: `bs_emit`'s `map_cases/1` built its worklist from
comprehensions that **filter**, so a third member kind was dropped rather than crashing, and
`ValidateAs<map<atom, term>>` returned ok for any term at all.

**No detector, because no rule survived measurement.** `[ -d "$dir" ] || continue` and
`[ -x "$script" ] || continue` in `check-gates-wired.sh` are the same shape and correct. The three
real cases share something narrower — a `continue` on an extraction that came back empty, inside a
loop that also prints a count — and I could not express that without either missing two of the
three or reporting most of the suite. `83472eb`'s own fix is the better remedy and is already the
convention: print `probed: N of M`, so a skip shows as a gap rather than having to be inferred.

### 2.2 The `sed` edit that mangles what it rewrites

`e517349`: *"sed expands a bare `&` in the replacement to the whole match, so the mutated condition
was malformed, the run went green and the control proved nothing."* It also left two empty files
named `command` and `if` in `compiler/`. `check-shell.sh`'s header records a second instance: *"a
`sed` edit mangled a paragraph of prose it was only supposed to retarget."*

**No detector, because the tree is clean and the rule cannot see the live case.** A sweep for a
`sed` replacement carrying an unescaped `&` returns zero across all 42 gate scripts. The instances
on record were both in *ad-hoc* edits made during a session — a one-off `sed -i` a session runs by
hand — which is precisely the code a repository-scanning detector never sees. A detector here would
be green forever and prove nothing, which is the failure `check-shell.sh` describes about severity
`warning`.

---

## 3. The suggestions that did not survive measurement

Three classes were proposed for this audit and are recorded as **checked and absent**, because a
class that was looked for and not found is a finding rather than a gap.

| Proposed class | Measured | Verdict |
|---|---|---|
| Shell word-splitting under zsh | `b70c9a3` already records it: *"zsh does not word-split, so quoting advice premised on it is inverted."* Every gate here is `#!/usr/bin/env bash` under `set -euo pipefail` | **Premise false.** The bash case is SC2086, which `check-shell.sh` catches at severity `info` — and its header says that is exactly why the threshold sits there |
| `&&` chains swallowing errors | `check-shell.sh` runs at `info`, where SC2015 lives, and its header records the two real instances it found in `check-map.sh` and `check-surface.sh` | **Already covered** — though see §5, because a *different* shape of the same hazard bit this session three times |
| Artifacts using `<div>` instead of `<pre class="mermaid">` | All 17 HTML artifacts under `wayfinder/` grepped: 17 use `<pre class="mermaid">`, 0 use a `<div>` wrapper | **Absent.** No instance, and no commit in the window records one |

---

## 4. Detector coverage

Each detector was run against the commit that made the defect, in a scratch checkout of that SHA,
and against the current tree.

| Detector | Historical SHA | Fires there | Live hits | After fix |
|---|---|---|---|---|
| `detect-unmanifested-tool.sh` | `aeb4fd8^` | ✅ `python3` | 3 tools, 5 sites | 0 |
| `detect-stale-suite-count.sh` | `910ed93^` | ✅ "36 verify stages" | 2 | 0 |
| `detect-stale-citation.sh` | `9f4590c^` | ✅ F16 citing bsc.erl past its end | 1 | 0 |
| `detect-swallowed-status.sh` | `be6307b^` | ✅ `check-tour.sh:135` | 1 | 0 |
| `detect-inherited-runner-env.sh` | `aba3fb0` | ✅ `verify.sh` / `GITHUB_ACTIONS` | 0 | 0 |
| `detect-unenumerated-shell-dir.sh` | `2b41db9^` | ✅ `handoff/audition-switch` | 2 | 0 |
| `detect-shared-scratch.sh` | `15ab27e^` | ✅ | 1 | 0 |
| `detect-split-table.sh` | `910ed93^` | ✅ `features/README.md:113` | 1 | 0 |
| `detect-dead-repo-path.sh` | `728f439^` | ✅ 6 there, 7 now | 7 | 0 |

**`detect-shared-scratch.sh`'s reconstruction is a partial and is recorded as one.** It fires at
`15ab27e^`, but on `run.sh`'s fixed workdir rather than on the one-`-o`-directory-for-sixteen-modules
shape that commit fixed. It catches the *named path* form of the class and not the *reused output
directory* form.

**Running `detect-unmanifested-tool.sh` against `aeb4fd8^` found a defect in the detector.**
`required_unpinned` was added *by that commit*, so on any older tree the grep matched nothing,
`pipefail` failed the pipeline and `set -e` killed the detector — exit 1 with not one word of
output, on the one tree it most needed to work on. Fixed, and the reason is in the function's
comment.

---

## 5. What the detectors cost, and what building them found

**Six of the nine rules reported 25 to 48 findings in their first form and 0 to 7 after
measurement.** The scoping was most of the work, and in three cases it changed the rule rather
than trimming it — §1.1 is the clearest, where measuring 48 findings surfaced a distinction the
repository had already made.

`detectors/lib/shell-code.sh` is shared rather than copied, which is the opposite of the call the
three document gates made about their four-line manifests. The reasoning there was that a reader
meets the duplication and can see all of it; a forty-line tokeniser copied four times cannot be
read that way. **Its two earlier drafts failed in opposite directions and both are controls now:**
resetting quote state at each newline reported 22 English words as commands (`say`, `more`, `open`,
`last`, `split`, `write`, `machine`, `quota`, and a B# type variable called `W` eight times over),
and blanking everything inside double quotes then lost `perl` and `shasum` — two of the three real
findings — because a command substitution inside a quoted span is code, not prose.

**The `&&`-list hazard bit this session three times, in a shape shellcheck does not flag.** Not
`A && B || C`, but a bare `test && continue` or `[ a ] || [ b ] && break` as the last command of a
function: when the test fails the list returns non-zero, and under `set -e` — in some calling
contexts and not others — the whole function dies silently. In `detect-stale-citation.sh` it
produced exactly the symptom a broken regex would: the real run printed findings and the self-test
reported none, from one line written two ways. Each site is now an explicit `if`, with the reason
at the line.

---

## 6. Live hits fixed

| # | Class | Site | Fix |
|---|---|---|---|
| 1–3 | unmanifested tool | `perl` ×3 in `check-recursive-types.sh`; `shasum` in `build-handoff.sh`, `check-handoff-package.sh`, `check-tour.sh`; `tar` in `check-links.sh` | Declared in `.tool-versions` and in `check-toolchain.sh`'s `required_unpinned` call, unpinned for the reason python3 is |
| 4 | vacuous control | `check-reserved-qualifiers.sh` ran `called_modules … \|\| true`, and an unreadable beam produces the same empty import list as a correctly inlined operation | A `BEAM-UNREADABLE` sentinel and its own arm in `judge` |
| 5 | stale citation | `F16` cited `bsc.erl` at a line 442 past the end of a 932-line file — and the sentence it quotes has never been in that file | Cited by name (`bs_diag.erl`'s module comment), per `9f4590c` |
| 6 | split table | A blank line split `F23`'s scenario table between F23.8 and F23.9 | Line removed |
| 7–13 | dead repo path | `bin/spec-check.sh` (×2, lives in `compiler/bin/`); `compiler/examples/math.bs` (×2, F15 made it a directory); `Shop/Collections/List/List.bs` (renamed to `Ints` by `728f439`, two days earlier); `aoc/bench/bench_bs.bs` | Corrected. `F30`'s `check-valve.sh` is marked `dead-path: planned` — a spec naming the gate it owes is not rot |
| 14–15 | stale suite count | `stage.sh` and the audition README both said "stage 12 of 34" | Deleted rather than corrected, per `910ed93` |
| 16 | shared scratch | The audition harness defaulted its workdir to `/tmp/bsharp-audition`, so two runs shared a directory | `mktemp -d`, printed on start |
| 17–18 | unenumerated directory | `wayfinder/prototypes` (34 scripts) and `.claude/skills/frontier` were in no enumeration and no exclusion list | Both excluded, each with its reason — `5abb590` decided the first deliberately, and the state the detector refuses is the third one: never considered |
| 22 | *(found by CI, 2026-09-04)* | `detect-dead-repo-path.sh` reported five citations of `aoc/2019/day01/…` and `aoc/2025/day01/…`. The tracked directory is `Day01`, so the citations name files this repository does not contain — genuine findings, invisible here because the resolver asked `[ -e ]` and **APFS is case-insensitive** | `exists_exact()` matches each segment against the real entries of its parent by name, case-exact on every filesystem. Controls `casewrong` / `caseright`; with the fix reverted, `casewrong` is red on macOS, so the gate no longer needs Linux to prove it can fail |
| 21 | *(found by CI, 2026-09-04)* | `detect-unmanifested-tool.sh` reported `editor` in two detectors — a case-arm alternation member, `_build/*\|editor/node_modules/*)`, read as a command because a word after `\|` is a command position. **Only on Linux**: the detector suppresses parse artefacts with `command -v`, and `/usr/bin/editor` is a Debian alternatives symlink that macOS has no equivalent of, so a green local pair sat under a red master | `case_labels()` — the arm class had no `/`, was anchored to `^` so an inline `case … in` arm was invisible, and did not reduce a path member to the first segment the extractor reports. A seventh control, `casearm`, covers both spellings |
| 19–20 | *(found while building)* | `detect-unmanifested-tool.sh` died silently on any tree older than `aeb4fd8`; `check-shell.sh` did not reach `detectors/lib`, which no `-perm -u+x` test can ever match | Both fixed in place |


**Row 21 is the one to read.** This detector's findings depend on the host, in one
direction: a word that is a parse artefact is reported only if `command -v` finds a binary of
that name, so the machine with more binaries reports more. That is the fail-loud direction and
CI is the strictest host, which is the good half. The bad half is that the local clean pair —
the whole twice-from-clean bar — cannot see a false positive that needs a Linux binary to
appear, so *for a lexical rule with a `command -v` filter, a green pair is not the last word
and master CI is*. The audit that wrote this row also committed a `mktemp -d -t` that works on
BSD and fails on GNU and busybox, in the same push. Two instances, one afternoon, of the class
*this machine's shell is a different language from CI's* — bash 3.2 and BSD sed here, bash 5 and GNU sed on the runner — already had a card for.


**How to reach the other host without pushing.** Both reds were host divergences, and both are
cheap to reproduce — the detectors need `git`, `bash` and coreutils, so this costs seconds where a
clean pair costs three minutes and cannot see either defect. Two things have to be true or the
probe is theatre, and the first draft of it got both wrong:

```sh
git clone --no-local . /tmp/probe && git -C /tmp/probe checkout <sha>
docker run --rm -v /tmp/probe:/mnt/src:ro ubuntu:24.04 bash -c '
  apt-get update -qq && apt-get install -y -qq git nano   # nano registers /usr/bin/editor
  cp -a /mnt/src /work && cd /work                        # onto overlayfs, NOT the bind mount
  for d in detectors/detect-*.sh; do "./$d" --self-test && "./$d" || echo "RED: $d"; done'
```

A **bind mount from macOS carries APFS case-folding into the container**, so a tree left on
`/mnt/src` reports `case-sensitive: no` and row 22 is unreachable; the `cp -a` onto the container's
own filesystem is what makes the probe mean anything. And `/usr/bin/editor` is an
update-alternatives symlink that **bare `ubuntu:24.04` does not have** and the GitHub runner image
does, so row 21 is unreachable without installing an editor. Verified on `0118e9b`: the probe
prints `editor present` and `case-sensitive yes`, and all nine are green.

---

## 7. Wiring

Nine detectors on six surfaces. `check-gates-wired.sh` insists on four — the script, `ci.yml`,
`.claude/end-session.md` and `bin/verify.sh` — and it went red naming all nine until they were
there. The other two are the enumerations that would otherwise have skipped the directory in
silence, which is §1.5's own class:

| Surface | Change |
|---|---|
| `.github/workflows/ci.yml` | one `--self-test` step for all nine, then one step each |
| `bin/verify.sh` | one stage for the nine self-tests, then one stage each |
| `.claude/end-session.md` | a section in the itemised list |
| `bin/check-shell.sh` | `detectors/` added to `scripts()`, **and `detectors/lib` enumerated without the executable test** — a sourced tokeniser four detectors read through is never executable and is still shell that decides verdicts |
| `bin/check-gates-wired.sh` | `detectors/` added to all four enumerations |
| `bin/check-cwd-independence.sh` | `detectors/` added to the static-anchor sweep, and two detectors added to the roster that is *run* from two directories — one that resolves against `$ROOT` only, and one that shells to `git ls-files`, which answers relative to the CWD |

---

## 8. Claim → source

| Claim | Source | How checked |
|---|---|---|
| 100 commits read in full | `9b9c62b`..`b70c9a3`, 3,344 lines of body | read |
| Each class is named in a commit message | the SHAs cited throughout §1 | quoted from the message |
| Every detector fires on its historical defect | §4 | `git archive <sha>` into a scratch tree, detector copied in, run |
| Every detector is silent on the fixed tree | §4 | run after the fixes |
| Every detector's `--self-test` discriminates | each file's `--self-test` | run; both halves required |
| 48 → 2 and 40 → 3 scoping | §1.1, §1.8 | both rules run in both forms |
| 17 artifacts use `<pre class="mermaid">`, 0 use `<div>` | `wayfinder/*.html` | grepped |
| zsh does not word-split | `b70c9a3` | the commit records the measurement |
| Gates are shellcheck-clean at `info` | `./bin/check-shell.sh` | 52 scripts |

---

Written from a read of the commit bodies and the review, plus direct runs. Its own claims about
counts are deliberately few, and the two that would re-stale — how many gates, how many stages —
are absent, which is what `detect-stale-suite-count.sh` exists to keep true.
