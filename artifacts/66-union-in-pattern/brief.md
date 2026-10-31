# Decision brief: ticket 66 (ENG-309), may a union name stand in pattern position?

Prepared for human review. Nothing here resolves the ticket, edits a ticket file or touches Linear.
Probes live in `probes/`; outputs are captured beside them as `*.out`.

## Read this first: what this brief could and could not execute

- **bsc could not be built here** (needs OTP 27+ leex; this box has OTP 25, Elixir 1.14.0). Every verdict about B# source
  (the five exemplars, "compiles" / "refused") is **INHERITED from ticket 66 at `6728799`, not re-executed**. The B#
  snippets under each option below are my *reasoning from the compiler source*, not outputs. Treat "compiles under this
  answer" as a design claim until the feature's own failing test exists.
- The probes model what bsc *would emit* using hand-written Erlang. They measure the BEAM-side cost of lowerings. They do
  not measure bsc's checker, residual printer or yecc grammar.
- Gleam, Elm, Scala, C#, Rust, OCaml: not installed, no sources on disk. Everything about them is `UNPROBED (cited from memory of the language reference)`.
  Elixir 1.14.0 is installed as beams only (`/usr/lib/elixir/lib/elixir/ebin`, no `.ex` sources), so I can capture its output but cannot cite file:line in it.

## 1. The ticket's four sub-decisions, and which gates which

| # | sub-decision | role |
|---|---|---|
| **S2** | all-record unions only, or any named type? (reframed by ticket 85 as: *which names may wear the prefix*) | **the gate.** It decides whether a feature exists and how wide it is. |
| S1 | does the residual print `C c` or the members? | follows S2. Moot if S2 = "no". Its only gate effect is `check-residual-pasteable.sh` `RecordUnion`. |
| S4 | interaction with ticket 15 §1's collapse refusal | follows S2. A reading, not a choice (section 5). |
| **S3** | exemplar 5, error or warning | **independent.** And partly already answered, see below. |

**Ticket 85 and 66 resolve together.** Ticket 85 Q1 asks which *names* may wear the type prefix, covering (a) an alias to a part union, (b) a
refinement, (c) a record union, and explicitly defers (c) to 66 while saying "if the answer here is a rule about names in general, 66 is inside
that rule". `CONTEXT.md` **Alias** says "the name never enters the type algebra, so two names over the same set are the same type". So `Handle(C c)` is
`Handle(A | B c)` after resolution (`bs_check.erl:1886-1915`: `resolve/3` returns a structural type, no provenance). The
question is therefore really "may a *union* wear the prefix", and the name is incidental. 66(c) and 85(a) are one question
(a union whose members are each decided by a test); 85(b) (refinement) is a different member kind and can ride separately.
Ticket 84 Q2 / F53 stopped at "one BEAM test decides the type named" (`bs_types:part_test/1`; F53 section "The criterion"); a union of records is decided by
one *tag membership* test, not one BIF, so it is a deliberate widening of that criterion, not an application of it.

**S3 is probably already decided.** Greps before claiming otherwise:
- ticket 04 Answer, finding 3: *"Redundancy must warn, never error."*
- ticket 89 Q2/A2 (David, 2026-10-04): a clause that matches no value of its input "is the `vacuous_clause` warning every vacuous clause gets"; the
  error alternative was written out ("every other vacuous clause stays a warning") and declined; reasoning: "naming the type is what makes the
  mis-shape speak, and the warning is that speech". That is exemplar 5's mechanism exactly (`vacuous_clause`, `bs_check.erl:4785`).
- Ticket 66 was raised 2026-09-02, **a month before A2**. Its "raised as an error" predates David's own ruling on the same tag.
- Pulling the other way: ticket 12 §1's standing constraint ("a warning is something an agent in a loop steps over; an error is a task"), and F53 (line ~119)
  recording that a vacuous *arm* "is only a warning, so that program compiled with the dead arm in it".

So S3 is not "undecided"; it is "decided as warning, and David may want exemplar 5 distinguished from A2". Section 4 gives the one narrow form
that would distinguish them.

## 2. The options for S2 (with S1 and S4 hanging off it)

### Option A. Refuse every name but a record; teach the helper (status quo plus a sentence)

```csharp
record A { Id: int }  record B { Id: int }
type C = A | B

public int Take(C c)
Take(c) -> c.Id                     // compiles today (exemplar 1)

public atom Handle(C | :none d)
Handle(A a)   -> Take(a)            // one line per member, body shared in Take
Handle(B b)   -> Take(b)
Handle(:none) -> :none
```
Refused (unchanged): `Handle(C c) -> ...` with `error: C is not a record, so it cannot name a pattern`.
(Verdicts INHERITED: ticket 66 exemplars 1, 3, 4. The `Take` workaround is my inference from exemplar 1 and ticket 84's `Area(Circle c)`/`Area(Rect r)` example, not executed.)

**Compiler delta:** none, beyond optionally one more sentence in `bs_diag.erl:1896` `not_a_record` ("a union of records: one clause per member, sharing a helper").
S1 and S4 vanish.

**Evidence:** the author-side cost is one line per member, not one RHS per member, *because the helper takes the union* (exemplar 1). The emitted-code cost
of the duplicated-body shape (probe 01) is only paid if the author copies the RHS.

**Strongest counterargument:** the exemplar-3 diagnostic then teaches a workaround that costs a call per member and loses the one-binding-of-the-whole-value
property (`c` is rebound per member with a narrower type, so a body needing the *union* type, e.g. passing `c` on as a `C`, must widen again). It also
leaves 85(a) refused and `Post(Amount a)` unwritable except as two clauses, which is where ticket 84 started.

### Option B. A name for a union of records wears the prefix (66 as asked, narrowly)

```csharp
public atom Handle(C | :none d)
Handle(C c)   -> Describe(c)        // c : A | B ; test = Kind in {T.A, T.B}
Handle(:none) -> :none
```
Refused under B: `Handle(D d)` where `D = A | B | :none` (mixed with an atom; S2 = records only), and `Post(Amount a)` over `int | float`.

**Compiler delta (concrete, from the source):**
1. `bs_check:record_of/3` (`bs_check.erl:~1860-1876`) today demands one closed map with a single-atom `Kind` and raises `not_a_record` otherwise. Add
   `record_tags/3` returning `[Tag]` for a union whose every member passes that same test; keep `record_of/3` for the singleton.
2. Checker: `pattern_type/3` for the prefixed pattern returns the union of the member record types, exact, binding the whole value (as `{p_rec, ...}` does at `bs_check.erl:~4925`, but unioned).
3. Emitter: `bs_emit:desugar/2` (`bs_emit.erl:~548`, the `p_type` clause) gains a union case that emits `#{'Kind' := K} = V when K =:= t1; K =:= t2 ...`, i.e. the
   pattern-bound-`Kind` plus guard shape that probe 04 verified. It goes in the same `p_test`/`strip_rels` slot the part prefix uses (`bs_emit.erl:182`), so it inherits the part
   prefix's rule of **argument position only, never nested** (`CONTEXT.md` Type prefix, last sentence). A record prefix nests today (F22.9); a union prefix would not. That is a visible asymmetry.
4. Arm and head: raise any refusal in `pattern_type/3`, not at a call site (F53 lesson, `compiler/features/F53-numeric-union-dispatch.md` ~l.119), so `switch` arms are covered by construction.
5. S1: printer unchanged (members). See S1 below.
6. The gate: `check-residual-pasteable.sh` `RecordUnion` stays green on members. Plus a new failing test and gate first, per `CLAUDE.md`.

**Evidence (probe 01, 03, 04):**
- Guard disjunction costs **~5 bytes and 0 instructions per added member**, at every body size; duplicating clauses costs **17.6 / 50.3 / 194.5 bytes and 8 / 38 / 134 instructions per member** at body sizes 1 / 8 / 32 operations (stripped `.beam`; `probes/01_lowering_size.out`).
  At 20 members and a 32-op body: 4385 bytes stripped for duplicate vs 812 for guard disjunction (5.4x).
- `erlc` keeps **one** body under a guard disjunction: 8 `phash2` calls for an 8-op body vs 160 under duplication at 20 members (`probes/03_*.out`, part A).
- **erlc does not rescue the duplicate shape**: compiling the duplicated version with `no_share_opt` changes nothing in stripped size or instruction count (probe 01 derived verdicts), although `beam_ssa_share.erl` exists in this OTP. Limitation: my bodies are `erlang:phash2` chains; a body shape erlc can share might fare better.
- **Run-time cost is not distinguishable**: at 20 members, 25 reps, medians within ~5% across all four lowerings, spread 34-84% on a shared 4-core box. I do not claim any run-time difference either way (`probes/03_*.out`, part B).
- The lowering is **semantically safe on hostile inputs** (non-maps, a map with no `Kind`, a foreign `Kind`, `:none`), including a no-`is_map` guard that fails silently, not crashes (`probes/04_*.out`).
- Therefore the "duplicated RHS scales with union size" cost in the ticket is real *only for the duplicate lowering*. Whichever option is chosen, bsc is free to emit the cheap one. The measurement settles an emission choice, **not** the language question.

**Strongest counterargument:** `CONTEXT.md` says "the name never enters the type algebra", so B admits a record-union *name* while the form it really
accepts is a *union*; it adds a third, nesting-restricted prefix kind (record: tag match, nests; part: one BIF, argument-only; union: tag set, argument-only) to a feature whose glossary entry currently
reads as two. And it settles 66 while leaving 85(a) open, so the next session raises the same question for `int | float` and the rule is written twice.

### Option C. One rule about names: an alias of a union wears the prefix when every member is a record or a part (66 and 85(a) together)

```csharp
type Amount = int | float
type C = A | B

public Side Post(Amount a)                       // 85(a)
Post(Amount a) -> ...                            // lowers to is_integer(a) orelse is_float(a); exhaustive with no catch-all

public atom Handle(C | :none d)                  // 66 exemplar 3
Handle(C c)   -> Describe(c)
Handle(:none) -> :none
```
Refused under C: `type Xs = list<int> | list<binary>` then `Count(Xs xs)` (member not separable: ticket 84 Q2's own `list<int>` refusal, same words); and, as a *separate* ruling, `Far(Meters m)` (85(b), not decided here).

**Compiler delta:** B's items 1-4 plus: a member-kind dispatcher over the resolved union's members (record: `Kind` equality; part: `bs_types:part_test/1` BIF) producing one
`orelse`-joined test; the `not_a_record` message at `bs_diag.erl:1896` is reworded since the rule is no longer "records only"; `pattern_type/3` refusal when any member is neither. Note the existing `p_or` machinery (`bs_check.erl:4905`, `bs_emit.erl:664-671`) is
interval-only (`rel_combine`); this is a new kind of disjunction, not a reuse.

**Evidence:** probe 01/03/04 as for B; the lowering for a *mixed* union (record tags plus a bare atom) was verified for the record-plus-`:none` case only (`04`, the `is_map`-guarded variant). A part union's lowering (`is_integer(X) orelse is_float(X)`) is **not probed** (UNPROBED; it is `erlc`-trivial but I did not run it, and I did not run it inside bsc).

**Strongest counterargument:** ticket 85 itself notes "the cost of leaving every name refused is one line of diagnostic, not a form nobody can express" for the part case. Option C commits the language to
disjunction-in-a-prefix for two member kinds at once, on the strength of two exemplars that nobody has yet written in a corpus program (the ticket cites `shop.bs:28`, which already works under today's
signature form). It is the largest compiler delta of the three and no program is currently blocked.

## S1. Does the residual print `C c` or the members? (only if B or C)

Today the printer already spells a record per member: `check-residual-pasteable.sh` line 804, `RecordUnion` -> `Which(Invoice i) -> ...`. For `C c` to print, the diag path must
recover an alias from a residual: `record_names(Env)` already travels to the printers (`bs_check.erl:2095, 3914, 3953`), so the delta would be a sibling `union_names(Env)` and a printed
`Handle(C c)` when `Resolve(C)` **equals** the whole residual. Problems: (i) two aliases over the same set are "the same type" by the glossary, so the choice between `C` and `C2` is arbitrary;
(ii) a partial residual (`B` left over) cannot print an alias; (iii) it moves the gate's expectation. Members always paste correctly. (Reasoned from source; the printer was not run.) Smallest answer: **members stay**;
revisit if an author complains. This is the cheap half of ENG-307 and should not be taken in this ticket.

## 4. S3, exemplar 5: error or warning

Precedent, captured (`probes/02_unreachable_precedent.out`):
- `erlc` 25: shadowed clause is `Warning: this clause cannot match because a previous clause at line 4 always matches`, **exit 0**; with `+warnings_as_errors` exit 1 (`sys_core_fold.erl:2878-2887` format_error, `compile.erl:545,1786` for the flag).
- Elixir 1.14.0: the same message, exit 0; exit 1 only under `--warnings-as-errors`.
- **A clause outside the declared spec has no precedent at all.** `erlc` is silent (it does not read `-spec`); Elixir 1.14 is silent; `dialyzer` with default flags and with `-Wunderspecs` is silent too (it warns on the success typing, not on the contract). So exemplar 5 has no BEAM-ecosystem analogue to copy; any severity is B#'s own invention. (Limitation: Elixir 1.14 predates the type-checker work in later releases; ticket 04 cites Elixir 1.20 "redundancy only, a warning" as INHERITED from that ticket, not re-executed.)

Compiler delta if David wants it as an error: one line, `bs_check.erl:4785` `{warning, ...vacuous_clause...}` to `{error, ...}`, **and** the parallel arm site (`vacuous_arm`, `bs_diag.erl:1053`), or a vacuous `switch` arm compiles with a dead branch (F51/F53 trap). `bs_diag:message` for `vacuous_clause` (`bs_diag.erl:1165`) changes "warning" to "error".

The narrow form that would *distinguish* exemplar 5 from ticket 89 A2 (so A2 stands for the 4-tuple `DOWN` case):

```csharp
public atom Bad(C c)
Bad(A a) -> :a
Bad(B b) -> :b
Bad(E e) -> :e         // E is a record disjoint from C: a *named type* that cannot be a member
```
Error only when a **type-prefixed** pattern's named type is disjoint from the declared parameter; a structural vacuous pattern (the 89 case) stays a warning. Raised from `pattern_type/3`, where `not_a_record` is raised (`bs_check.erl:1874`) and where F53 raises its refusals, so heads and arms are both covered. Rationale to weigh: the prefix is something the author *chose to name*, so it is always a mistake (ticket 89 A2's own wording), whereas ticket 04's non-compositionality objection concerns derived arrows; B# gives each function one declared input (`redundancy/4`, `bs_check.erl:4812`, tests against `Declared`). I did not verify there is no overloading interaction (`LANGUAGE.md:3791` mentions arity overloading, which is distinct from type overloading); flag for review.
Strongest counterargument: it is a second severity for one tag, `vacuous_clause`, splitting a rule David just made uniform; and ticket 04 says the checker should never error on redundancy.

## 5. S4. Does a named union interact with ticket 15 §1's collapse refusal?

15 §1 rejects an instantiation where `T | <failure member> == T` (absorption into a cofinite top). Reading, not measured with bsc:
- A union of distinct records cannot absorb anything: records carry disjoint minted tags, so `A | B | :none` has no member that contains `:none`. No interaction for all-record unions (Options A, B).
- Under Option C, an alias like `type Id = atom | :none` already normalises to `atom` (CONTEXT: alias never enters the algebra) and is refused or erased at *declaration*; the prefix never sees it as a union. A part alias that survives normalisation (`int | float | :none`) has three separable members and is fine.
- I could not re-measure 15's table: it was run on Elixir 1.19.5 `Module.Types.Descr` (INHERITED from `15a`); Elixir 1.14.0 here has no `Descr`. The "no interaction" claim is a derivation from tickets 09/15 plus the source, **UNMEASURED in bsc**, which is precisely the habit the ticket warns against. The cheap measurement once bsc exists: compile `D = A | B | :none`, `type Id = atom | :none` and `Handle(Id i)` and record all three verdicts.

## 6. Recommendation

1. **Decide S2 first and alone**, and decide it together with ticket 85 Q1 as one rule about *which unions* may wear the prefix (they cannot be answered separately; 85 says so).
2. My lean is **Option C restricted to records and parts, deferring refinements**, because B is a strict subset that leaves 85(a) to be re-asked, and A leaves ticket 84's own motivating program (`Post(Amount a)`) unwritable. The evidence does **not** force this: it shows the lowering is cheap (5 B/member) and safe (probe 04), nothing more. Option A is a perfectly defensible answer if no corpus program is blocked. If David wants the smallest step, B.
3. **S1: members stay.** Do not take alias printing here.
4. **S3: record "warning, per ticket 89 A2" unless David wants the narrow type-prefix error** of section 4. Do not change `vacuous_clause` wholesale (it would overturn A2 and ticket 04 finding 3).
5. **S4:** treat as a measurement to schedule with the feature's gate, not a decision.

## Decision left open for human review

- Which names/unions may wear the type prefix (A, B or C), resolved together with ticket 85 Q1.
- Whether exemplar 5 stays a warning (ticket 89 A2 / ticket 04) or becomes an error for a type-prefixed disjoint pattern only.
- Whether a union prefix nests (the part prefix does not; the record prefix does).

## Claims table

| claim | status / source |
|---|---|
| Five exemplar verdicts (1-5) at `6728799` | INHERITED from ticket 66, not re-executed |
| B# snippets under options A/B/C "compile"/"are refused" | design reasoning from compiler source; NOT executed |
| `not_a_record` raised at `bs_check.erl:1874,1876`, `bs_emit.erl:543`, rendered `bs_diag.erl:1896` (ticket says 952; line has moved) | source read |
| `resolve/3` returns structural types, alias name not retained | `bs_check.erl:1886-1915` |
| Alias never enters the algebra; type prefix glossary (argument position only) | `CONTEXT.md` Alias, Type prefix |
| Part prefix emits `p_test` through `strip_rels`; criterion is `bs_types:part_test/1` | `bs_emit.erl:548-566`, F53 |
| `p_or` machinery is interval-only | `bs_check.erl:4905`, `bs_emit.erl:664-671` |
| `record_names(Env)` already reaches printers | `bs_check.erl:2095,3914,3953` |
| Residual prints a record per member (`Which(Invoice i) -> ...`) | `compiler/bin/check-residual-pasteable.sh:804` (gate text, not run) |
| Ticket 04: redundancy warns, never errors | ticket 04 Answer finding 3 (INHERITED reasoning) |
| Ticket 89 A2: vacuous clause stays a warning (2026-10-04) | ticket 89 text |
| Ticket 12: warnings are stepped over by agents; closed-residual catch-all is an error | ticket 12 §1/§2 text; `bs_check.erl:4826` |
| Dup lowering costs 17.6/50.3/194.5 B and 8/38/134 ins per member (B=1/8/32) | `probes/01_lowering_size.out` |
| Guard-disjunction costs ~5 B, 0 ins per member | `probes/01_lowering_size.out` |
| `;` and `orelse` guard forms are equal in size/instructions, `orelse` core text is larger (core lines grow faster) | `probes/01_lowering_size.out` |
| One body under disjunction (1 / 8 phash2) vs duplicated (20 / 160) | `probes/03_*.out` part A |
| erlc does not dedupe the duplicated bodies (`no_share_opt` identical) | `probes/01_*.out` derived verdict; `beam_ssa_share.erl` exists (`compile.erl:864`) |
| No run-time difference distinguishable (spread 34-84%) | `probes/03_*.out` part B |
| Guard disjunction safe on non-maps / no-Kind / foreign Kind | `probes/04_*.out` |
| erlc/Elixir 1.14 warn exit 0 on shadowed clause, error only when opted in | `probes/02_*.out`; `sys_core_fold.erl:2878-2887` |
| erlc, Elixir 1.14, dialyzer silent on clause outside the spec | `probes/02_*.out` (default and `-Wunderspecs`) |
| Elixir 1.14 warning source file:line | UNPROBED: only `.beam` installed |
| Elixir 1.20 ships redundancy only, as a warning | INHERITED from ticket 04/12 |
| Gleam alternative patterns (`Circle(_) \| Square(_) -> ..`, bound variable must appear in every alternative) | UNPROBED (cited from memory of the Gleam language tour) |
| C# 9 `or` patterns (`A or B`), no designation inside the alternatives; bind with `and var c` | UNPROBED (cited from memory of the C# spec) |
| Rust `A(x) \| B(x)`, OCaml `(A _ \| B _) as c`, Scala `c @ (_: A \| _: B)` bind the whole value | UNPROBED (cited from memory) |
| Elm has no or-patterns | UNPROBED (cited from memory) |
| No interaction with 15 §1 | derived; UNMEASURED in bsc; 15's table INHERITED (Elixir 1.19.5) |
| Part-alias lowering `is_integer orelse is_float` | UNPROBED |

## Reproducing

From `probes/`: `escript 01_lowering_size.escript`, `escript 03_shared_body_and_runtime.escript`, `escript 04_mixed_union_lowering.escript`,
and `bash 02_unreachable_precedent.sh` (needs a PLT first: `dialyzer --build_plt --output_plt /tmp/p66.plt --apps erts kernel stdlib`; the
dialyzer section is skipped with a notice otherwise). Each exits non-zero on a failed assertion; `02` demonstrably failed twice during development
(wrong grep, then a wrong expectation about dialyzer) before the captured run.
