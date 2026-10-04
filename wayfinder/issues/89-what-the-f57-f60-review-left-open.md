# 89 — What the F57–F60 review left open

Type: grilling
Status: open — [ENG-417](https://linear.app/davewil/issue/ENG-417). Raised 2026-09-24 by the `/code-review` of F57–F60 (`0e51c9a..01c4a56`)
Blocked by: —

## Why this is raised

The review found defects, fixed in `baf421b`, `0c3f5b9`, `e48e9ea`, `cabead1` and `f7345ed`, and
six findings that are not defects, because fixing any of them means deciding something no ticket
has decided. They are independent: no answer here changes another question. Each is a program,
what `bsc` does with it today (measured at `f7345ed`, every program below compiled and, where it says so, run), and what the other answer costs the
compiler.

Two review findings were already on the record and are **not** asked here: a brace that writes
`Kind = :'M.Reply'` is that record (ticket 73 Q1, the `__struct__` reading), and a mismatch
residual printing `{ Status: _ }` is ENG-350's printer decision.

## Round 1

**Q1. Is `Exit`'s first part `pid`, or `pid | port`?** Ticket 88 Q5 wrote `Exit { Pid: pid }`. A
process that traps exits and owns a linked port receives `{'EXIT', #Port<0.3>, Reason}` when the
port closes:

```csharp
public (:noreply, State) HandleInfo(Exit | :tick msg, State s)
HandleInfo(Exit { Pid: p, Reason: :normal }, s) -> (:noreply, s)
HandleInfo(Exit { Pid: p, Reason: why }, s)     -> Restart(p, why, s)
HandleInfo(:tick, s)                            -> (:noreply, s)

private (:noreply, State) Restart(pid p, term why, State s)
```

Today this compiles, and a real port exit, `{'EXIT', #Port<0.2>, normal}`, reaches `Restart`
through a parameter declared `pid`: a `public pid Who(Exit e)` beside it returns `#Port<0.2>`.
`ValidateAs<Exit>` refuses the same message (`Expected = "pid"`, `Path = ["(2)"]`). Under
`pid | port`, the call to `Restart` is refused (`arg_not_accepted`, residual `port`) until the
author narrows `p` or widens `Restart`. (Over `term msg` the question does not arise: the view
pattern does not test a part's type, so `p` is `term` and the call is refused today.) Compiler delta: `stratum_two`'s `Exit` and `bs_types:view_parts('Exit')` gain `port`
in that position; the validator tests `is_pid` or `is_port`. Whether the part keeps the name `Pid`
is part of the answer.

**Q2. Is a four-element `DOWN` clause over a `Down` parameter an error, or a warning?**
Ticket 14 §6 wrote *"a compile error"*. F60 ships the warning every vacuous clause gets and did not
decide against 14 §6 on its own:

```csharp
public (:noreply, State) HandleInfo(Down | :tick msg, State s)
HandleInfo((:'DOWN', ref, _, reason), s) -> (:noreply, s)
HandleInfo(Down d, s)                    -> (:noreply, s with { Crashes = s.Crashes + 1 })
HandleInfo(:tick, s)                     -> (:noreply, s)
```

Today: `warning: clause 1 of HandleInfo matches no value of its input` (`vacuous_clause`), and the
module builds.
As an error, the module does not build. Compiler delta: a `vacuous_clause` whose pattern is a tuple
with a view's tag, over a parameter holding that view, is raised at error severity; every other
vacuous clause stays a warning.

**Q3. May a program write a `Down` out as its tuple?** Ticket 88 says a view is *"never constructed
by a user"*, and F60 refuses `Down { … }` and `with`. The tuple is not refused:

```csharp
// A test double for a monitored worker that died.
public Down Died(reference r, pid p)
Died(r, p) -> (:'DOWN', r, :process, p, :killed)
```

Today this compiles and returns a real `DOWN` message. Ticket 73 Q1 made a record's raw tag legal
everywhere and refused nowhere; if that reading holds here, nothing changes and the F-file says so.
If it does not, a tuple value whose tag is a view's, reaching a position typed as the view, is
refused (`view_constructed`). That refusal would then have to tell a tuple the program built from
a message it received as `term` and narrowed with a `(:'DOWN', …)` pattern, which have the same
type; nothing has measured how.

**Q4. May one field set name both `"Id"` and `Id`?** F58 made them different keys, which they are:
one is a binary, one an atom.

```csharp
type Both = { "Id": int, Id: int }

public string Encode(int a, int b)
Encode(a, b) -> ToJson<Both>({ "Id" = a, Id = b })
```

Today this compiles, and `Encode(1, 2)` returns `{"Id":2,"Id":1}`, JSON with a repeated key.
Refusing it at the declaration is one new refusal in `bs_check:declared/4`, for a field set whose
string key equals a name key's text; refusing it only at `ToJson` leaves the type legal and refuses
the encode, a new `unencodable_member` kind.

**Q5. What does `with` over a field set produce?** A brace's type is the exact values it was built
from, so a field built as `0` has the type `0`:

```csharp
type Tally = { Count: int, Last: atom }

public Tally Count(list<atom> events)
Count(events) -> Step(events, { Count = 0, Last = :none })

private Tally Step(list<atom> es, Tally t)
Step([], t)          -> t
Step([e, ..rest], t) -> Step(rest, t with { Count = t.Count + 1, Last = e })
```

This compiles today, because `t` is a `Tally`. The same update on an unannotated binding does not:
`var t = { Count = 0 }` then `t with { Count = n }` is refused, `not covered by the declared type
of Count: int <= -1 | int >= 1`, a type nobody wrote. Two readings: `with` keeps each field's type
(today, the record rule), or `with` over a field set is a map update and the result's field takes
the new value's type. Ticket 78 decided the brace and never mentions `with`, and F58 made `with`
take a string key with no ticket behind it. Compiler delta for the second reading: `with_subject`
builds the result type from the updated values for a field-set subject, and leaves records as
they are.

**Q6. Does `duplicate_field` stand?** F57 refuses `{ Status = n, Status = 200 }`; an Erlang map
literal would keep the last value without a word. Record construction already refuses a repeated
key, though misleadingly: `R { A = n, B = n, B = 2 }` is `Go builds an R with the wrong fields /
not declared by R: B`. Ticket 78 Q7 says the brace is *"record construction's `=`
with no type name in front"*, which covers it on one reading, and no ticket says so outright.
Today: refused, `duplicate_field`. The other answer deletes one clause in `brace/4` and the
diagnostic.

**A2 to A6 (David, 2026-10-04).** Q1 is not answered: David asked what `pid | port` gains, and the
ticket stays open on it.

- **A2: *"Warning"*.** A four-element `DOWN` clause over a `Down` parameter is the `vacuous_clause`
  warning every vacuous clause gets, as F60 ships. This amends ticket 14 §6's *"a compile error"*:
  naming the type is what makes the mis-shape speak, and the warning is that speech. No compiler
  delta.
- **A3: *"Keep it legal"*.** A program may write a `Down` or an `Exit` out as its tuple, on ticket
  73 Q1's reading of a record's raw tag. `Down { … }` and `with` over a view stay refused
  (`view_constructed`). No compiler delta; F60 owes the sentence.
- **A4: *"Refuse"*.** A field set may not name both `"Id"` and `Id`. Recorded as the refusal at the
  declaration, the form recommended when the question was put: one new refusal in
  `bs_check:declared/4`, for a field set whose string key equals a name key's text. David's word
  was *"Refuse"* alone, so the site is the recommendation's, not a second answer of his.
- **A5: *"New value's type"*.** `with` over a field set is a map update: the result's field takes
  the new value's type. `with` over a record keeps each field's declared type, as today. Delta:
  `with_subject` builds the result type from the updated values for a field-set subject.
- **A6: *"Refuse"*.** `duplicate_field` stands: `{ Status = n, Status = 200 }` is refused. No
  compiler delta.

Owed as builds, each a feature amendment rather than a decision: A4's refusal (F58) and A5's
`with_subject` change (F58). A2, A3 and A6 are sentences in F60 and F57.

**A1 (David, 2026-10-04):** *"pid | port then"*, after asking what it gains. `Exit`'s first part
is `pid | port`: a process that traps exits and owns a linked port is sent `{'EXIT', Port, Reason}`,
and under `pid` that port reached a parameter declared `pid` with the program proved correct. The
call below is refused (`arg_not_accepted`, residual `port`) until the author says what a port's
exit means. Delta, an F60 amendment: `bs_types:view_parts('Exit')` and `stratum_two`'s `Exit` gain
`port` in that position; `ValidateAs<Exit>` tests `is_pid` or `is_port`. This amends ticket 88
Q5's `Exit { Pid: pid, Reason: term }`.

## Round 2 (asked 2026-10-04)

Q1 said the part's name was part of the answer, and A1 settled the type alone.

**Q7. Does the part keep the name `Pid`, now that it may hold a port?** The program A1 asks for:

```csharp
public (:noreply, State) HandleInfo(Exit | :tick msg, State s)
HandleInfo(Exit { Pid: who, Reason: why }, s) -> Exited(who, why, s)
HandleInfo(:tick, s)                          -> (:noreply, s)

private (:noreply, State) Exited(pid | port who, term why, State s)
Exited(pid p, why, s)   -> Restart(p, why, s)
Exited(port sock, _, s) -> (:noreply, Closed(sock, s))
```

`Exit { Pid: who }` binds a value that may be a port out of a part called `Pid`. Under the other
answer the first clause reads `HandleInfo(Exit { From: who, Reason: why }, s)`, and nothing else
changes.

**Corrected the same day.** This round first wrote the dispatch inside the view,
`Exit { Pid: pid p, … }` beside `Exit { Pid: port sock }`, and David asked what syntax that was.
It is not B#: measured at `19054c1`, a type prefix inside a view's part is refused
(`type_prefix_nested`, *"a type prefix goes where a whole argument goes … Inside a tuple, a list
or a record pattern it is not built yet"*), as it is inside a tuple. The whole-argument form over
`pid | port` compiles today (`Kind(pid p) -> :process` beside `Kind(port s) -> :port`). So A1's
price is a helper function per handler that tells the two apart, not a second clause, until the
nested prefix is built.

`From` is the name OTP's own documentation gives that position (`{'EXIT', From, Reason}`), and
`Down`'s part that may hold a pid or a port is already `Object`, not `Pid`. Compiler delta for the
rename: the atom in `bs_types`' view table
(two sites), `down_view_tests`' one `Exit` pattern, F60.8, `STANDARD-ENVIRONMENT.md`'s row, and
the sentence in ticket 14 §6 and 25g's write-up. No shipped example names the part.
