# F60 — `Down` and `Exit` as named views of their tuples; `pid`, `reference`, `port` as types

**Status**      **in progress** — 14 tests in `down_view_tests`, 1118 in the
                suite; `check-language.sh` gained a must-compile block in §13,
                seen red first
**Implements**  [ticket 88](../../wayfinder/issues/88-how-down-is-written.md),
                resolved 2026-09-24, and the part of
                [ticket 14](../../wayfinder/issues/14-concurrency-and-otp-model.md)
                §6 it amends. Decides nothing
**Closes**      [ENG-416](https://linear.app/davewil/issue/ENG-416)
**Unblocks**    exemplar **25g**, whose only wall this was: it compiles and runs
                as written
**Depends on**  F22 (the record pattern grammar), F53 (`part_test/1`)

## Why this one now

Ticket 14 §6 made `Down`, `Exit` and `Timeout` compiler-known so a handler
names the message instead of spelling the tuple, and nothing built them.
Exemplar 25g, a B# version of Jev's `Jev.Server`, stopped on `no type named
Down`. Ticket 88 decided how it is written the same day.

## The program

```csharp
HandleInfo(Down { Ref: ref, Reason: :normal }, s) ->
    (:noreply, s with { Pending = :maps.remove(ref, s.Pending) })
HandleInfo(Down { Ref: ref, Reason: reason }, s) ->
    Crashed(ref, reason, s)

private (:noreply, State) Crashed(reference ref, term reason, State s)
```

## The rule

- `pid`, `reference` and `port` are types. `pid` carries no message type
  (14 §1). A public parameter of one is guarded as ticket 18 §1 guards any
  parameter, so an identity function passes its argument through as one over
  `binary` does; a foreign return and `ValidateAs` test each with its one guard.
- `Down` is `(:'DOWN', reference, :process | :port, pid | port | (atom, atom),
  term)` and `Exit` is `(:'EXIT', pid, term)`, ordinary tuple types. Their
  names are `Down { Ref, Type, Object, Reason }` and `Exit { Pid, Reason }`.
- `Down { Ref: r }` is a pattern for the tuple with `_` in the positions not
  named; parts may be named in any order, and an unknown part is refused as a
  record's unknown field is. A trailing binder works, `Down { Ref: r } d`, and
  so does a bare prefix, `Down d`, which tests the tag and the arity. The
  checker stays sound over a user tuple of the same tag and arity: a part of
  `Down | (:'DOWN', int, int, int, int)` reads as the union of both.
- `d.Reason` on a value of a view type reads its position.
- A view cannot be constructed or updated with `with` (`view_constructed`),
  or redeclared (`compiler_known_type`). The tuple written out,
  `(:'DOWN', r, :process, p, :normal)`, is not refused; whether it should be
  is [ticket 89](../../wayfinder/issues/89-what-the-f57-f60-review-left-open.md)
  Q3, beside ticket 73's reading of a record's raw tag.
- A residual over a view prints by name, in the diagnostic and the pasteable
  heads: `F(Down { Reason: n }) -> ...`, naming only the parts narrowed below
  what the view declares.
- `ToJson` refuses a process, reference or port (`unencodable_member`, kind
  `opaque`): it has no value outside the VM.

**A four-element `DOWN` clause** against a `Down` parameter, 14g's mistake,
is reported as `vacuous_clause`, a **warning**, as every clause that matches no
value of its input is. Ticket 14 §6 wrote *"a compile error"*; making this case
an error would be a new decision, and is not taken here: it is
[ticket 89](../../wayfinder/issues/89-what-the-f57-f60-review-left-open.md) Q2,
beside Q1, whether `Exit`'s first part is `pid | port`.

## What changed

- `bs_types`: an `opaques` part, an ordset of `pid | port | reference` beside
  `bins`, full in `term()`, at every site that enumerates parts; a non-empty one
  is open. `views/0` is the table of views and `view_parts/1` their declared
  part types; `view_of_tuple/1` recognises one; `to_string`, `to_pattern` and
  the head printer write a view by name.
- `bs_check`: the three builtins; `Down` and `Exit` in `stratum_two`;
  `view_pattern/3` turns a view pattern into its tuple for `pattern_type`;
  `view_projection/2` resolves `d.Reason` and leaves a `vproj` note, which the
  emitter reads as it reads `fdiv`; `view_constructed`; `ToJson`'s `opaque`.
- `bs_emit`: the same desugar; `element/2` for a noted projection; `is_pid`,
  `is_port`, `is_reference` in the foreign-return guard and the validator;
  `pid()`, `port()`, `reference()` in specs.
- `bs_diag`: `view_constructed`, `opaque`, and `unknown_builtin`'s list.
- From the 2026-09-24 review: `with` over a view is `view_constructed`, where
  it had said the view "has no Reason"; the unknown-part message lists the
  declared parts under its heading without the stray `:` line a record's had
  too; and `bs_types:is_view/1` replaces the names `Down` and `Exit` written
  out in `bs_check` and `bs_emit`.

The type algebra gained no view kind: a view is its tuple, and the names live
at the four sites that read them.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F60.1 | `pid P(pid p)`, `reference R(reference r)`, `ValidateAs<pid>` | round-trips; the validator refuses a reference with `Expected = "pid"` |
| F60.2 | `using :erlang { pid self() }` | compiles and returns the pid |
| F60.3 | `What(Down { Reason: :normal })`, `What(Down { Reason: why, Type: :process })` on real DOWN messages | `:normal`, `:crashed`, and a catch-all for others |
| F60.4 | `Why(Down { Ref: r } d) -> d.Reason` | the exit reason |
| F60.5 | a `Down` parameter covered by two view clauses; one missing | compiles; `inexhaustive` |
| F60.6 | a four-element `DOWN` tuple clause against `Down` | `vacuous_clause` warning |
| F60.7 | `Down { Pidd: p }` | `pattern_field_unknown` |
| F60.8 | `Exit { Pid: p, Reason: why }` on a real EXIT | the reason |
| F60.9 | `type Down = int` | `compiler_known_type` |
| F60.10 | constructing `Down { … }` | `view_constructed` |
| F60.11 | the residual over `Down`, as `bsc` prints it | `F(Down { Reason: … })`, no `'DOWN'` tuple |
| F60.12 | `ToJson<pid>` | `unencodable_member`, `opaque` |
| F60.13 | `F(Down d)` over `term`, on a real DOWN, `{'DOWN', x}` and a six-tuple | `:down`, `:other`, `:other` |
| F60.14 | the residual of `D(Down { Reason: :normal })` and of the same over `Exit`, as `bsc` prints it | names `Reason` only, no `Ref`, `Type`, `Object` or `Pid` |
| F60.15 | `d with { Reason = :x }` over `Down d` | `view_constructed` |
| F60.16 | a switch over `Down \| (:ok, int)` with a `Down { Reason: :normal }` arm and a `Down d` arm | `:normal`, `:down`, `:ok` |
| F60.17 | `I(Down { Info: i })` | `Info is not declared by Down`, the four parts listed under `Down declares:` |

## Out of scope

- The pairing check ticket 14 §6 decided and ticket 88 dropped.
- `HandleInfo` narrowing (25g friction 3), which is ticket 14 §4's.

## Done when

The scenarios pass, the LANGUAGE.md block compiles, 25g compiles and runs as
written (`wayfinder/prototypes/25g_surface_probe.sh` §1), and `./bin/verify.sh`
is green twice from a clean clone.

## Evidence — 2026-09-24

`./bin/verify.sh` twice from a clean clone of `4e78c91` (F60 rebased onto
`0207fdb`, another session's editor commit), one command per run: **All 46
stages passed**, 289 s and 274 s. The status stays *in progress* until David
calls it.
