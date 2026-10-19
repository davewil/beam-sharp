# Brief — ticket 66 (ENG-309): can a union name a pattern? `Handle(C c)` where `type C = A | B`

Status of the ticket: **open, left open.** Ticket 85 (ENG-395) asks the same generalisation for a part union and a refinement;
the ticket says the two resolve together if either is answered as a rule about names.

## Sub-decisions
1. **Gating:** is a named type in pattern position allowed at all beyond `record` and a lowercase part? (items 1 and 2 follow it)
2. Only all-record unions, or any named union (`D = A | B | :none`)?
3. Does the residual print `C c` or the members?
4. Is exemplar 5 (a clause no call can reach) an error or a warning? **This is independent of 1 and can land alone.**
5. Does it interact with ticket 15 §1's collapse refusal?

## The programs (re-run at HEAD with a `bsc` built on OTP 28: `probes/66/probe.sh`)

```csharp
record A { Id: int }   record B { Id: int }   record E { Id: int }
type C = A | B         type D = A | B | :none

public atom Handle(D d)
Handle(C c)   -> :ab        // proposed: matches A or B, c bound to the whole value
Handle(:none) -> :none
```
Today this is refused (exemplar 3), and the author writes:
```csharp
Handle(A a)   -> :ab
Handle(B b)   -> :ab        // body repeated once per member
Handle(:none) -> :none
```
which compiles. All five of the ticket's exemplars reproduce at `019533d`: 1 compiles; 2 refused (`Bad hands Take an argument
it does not accept`); 3 refused (`C is not a record, so it cannot name a pattern`); 4 compiles; 5 **warns, rc=0**
(`clause 3 of Bad matches no value of its input`). Diagnostic wording has drifted from the ticket's quoted text (exemplar 3
now also says "a part is named by the part itself, lowercase"), as the ticket predicted.

## Measurements

**Decision 5 is answered.** `type U = atom | :none` followed by `Take(U u)` is refused **at the declaration**, before any
pattern is reached: `error: `:none` is absorbed by `atom``. A named union that reaches pattern position is therefore already
collapse-free. No interaction (`probes/66/T66f`).

**Decision 3 is half-answered.** For a union *parameter* the residual already spells the members: deleting `Handle(B b)` from
`Handle(C c)` prints `no clause matches: Handle(B b) -> ...` (`probes/66/T66g`), pasteable, with `C` never appearing. Only the
**warning** of exemplar 5 prints erased notation (`{ Kind: :'T66e.A' } | { Kind: :'T66e.B' }`, `bs_diag.erl:1162`).

**Cost of the lowering** (`probes/66/lowering_cost.escript`, OTP 28; hand-written Erlang of the three shapes, same body):
| members N | duplicated clauses | one clause + guard disjunction | heads sharing one body fn |
|---|---|---|---|
| 2 | 984 B | 888 B | 924 B |
| 5 | 1292 B | 908 B | 948 B |
| 20 | 2972 B | 1040 B | 1080 B |

Run time at the *last* member, N=20, four runs: 40.9-46.0 ns/call for all three, **indistinguishable**, except that the
first run's `dup` read 56.6 ns (the first form timed; I take it as warm-up, and the three later runs read 42.2-46.0). Duplication grows
~100 B per member; the guard form ~7 B. So the cost of today's workaround is **size, not speed**, and the compiler can
lower `C c` to the guard form or the shared-body form with no run-time penalty measured.

**What neighbours do with the same two questions** (`probes/66/nbr/`):
- Gleam 1.12.0: `Circle(..) as c | Square(..) as c -> c.id` **compiles** — an alternative pattern binding the whole value, the
  closest existing spelling to `C c`. Gleam has no named union *alias*; the union is the type. An unreachable clause
  (`_ -> 1` then `Square(..) -> 2`) is a **warning**, rc=0 (`Unreachable pattern ... can be safely removed`).
- Elixir 1.14.0: the same is a **warning** (`this clause for f/1 cannot match because a previous clause at line 3 always matches`),
  rc=0; a union of two structs is `when is_struct(c, P) or is_struct(c, Q)`.
- Erlang/OTP 25: warning, rc=0 (`this clause for f/1 cannot match ... always matches`).
- Elm: **not measured** (its package host is unreachable; `elm make` stops at a missing `elm/json`). I believe Elm refuses a
  redundant pattern, but that is recollection, not a probe, and is excluded from the evidence.

**Checker delta** (from the ticket, not re-derived): `not_a_record` is raised at `bs_check.erl:1800` and `:1802` and rendered at
`bs_diag.erl:1879`; supporting `C c` means resolving the alias there and lowering to a disjunction of the members' minted tags.

## Options

**A. Allow any named type in pattern position, lowered to the guard-disjunction form; make the dead-clause diagnostic an error.**
- Evidence: all three BEAM lowerings are within noise at run time; the guard form is 2.9x smaller at N=20; Gleam already
  compiles the equivalent alternative pattern; absorption is refused at declaration so no collapse hazard (T66f).
- Strongest counterargument: three neighbours measured (Erlang, Elixir, Gleam) all **warn** on an unreachable clause, so an
  error departs from the field, and raising severity makes a currently green program red (exemplar 5 compiles today).
  Against that, the project's own standing rule points the other way: ticket 12 §1 (`wayfinder/issues/12-*.md:119`) holds
  that *"a warning is something an agent in a loop steps over; an error is a task"* — so the counterargument is the field's
  habit, not the project's.

**B. Allow only unions of records** (`C c` where every member is a record), `D = A | B | :none` still refused.
- Evidence: the smallest delta — ticket 55's record prefix generalised by one step, the residual already spells members.
- Strongest counterargument: the ticket's own framing says this is the wrong cut, because F53 already shipped a second
  special case (the part prefix), and 85 asks for a third. Stopping at records guarantees the next ticket.

**C. Change nothing in patterns; make only exemplar 5 an error** (decision 4 alone).
- Evidence: independent of the rest, one severity change; the compiler already detects the case with a precise reason.
- Strongest counterargument: it leaves exemplar 4 (body duplicated per member) in place, which is the author-visible cost the
  ticket opened with, and which scales linearly with the union.

## Recommendation
**A, and ask decision 4 on its own first.** Decision 4 does not need 1 to be answered and every other language measured treats
the same finding as a warning while the project's own rule (12 §1) favours an error, so it is the one place David's taste is the deciding input. Ask it as two programs: one
with the dead clause compiling with a warning, one refused. Decide 1 and 2 together with ticket 85, as that ticket proposes.

## Not measured
Elm. `check-residual-pasteable.sh`'s `RecordUnion` shape under a lowered `C c` (the gate was not run). Run-time cost on a
non-last member and with N > 20. The lowerings are hand-written Erlang, not `bsc` output, because `bsc` does not yet accept `C c`.
