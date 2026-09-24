# PROTOTYPE 25g — exemplar: a B# Jev.Server

> **Throwaway.** Ticket [25](../issues/25-exemplar-programs.md), exemplar 7. Written against the
> surface after F59 (2026-09-24).
> The run is [`25g_replay.erl`](25g_replay.erl), which drives the modules `bsc` builds from this
> write-up and from 25f's. The compiler measurements are [`25g_surface_probe.sh`](25g_surface_probe.sh).
> Everything claimed below was executed.

[Jev](https://github.com/dannote/jev) (Danila Poyarkov, `003417f`, 2026-09-22) is an Elixir library
for TypeSafe's Jev decision model, and its argument is this language's: *"Clause order is the
routing. Thresholds are guards."* `Jev.Server` is a GenServer with one extra callback,
`handle_answer(reply, tag, state)`. A callback sends a request by returning
`{:reply, {tag, state, questions}, s}`; the request runs under a `Task.Supervisor`, so any number
are in flight and a crashed one arrives as `{:error, reason}`; the answer is a plain map that
`handle_answer` clauses match with guards.

This is that library written in B#, with Jev's own README example written against it. **It does
not call or depend on the Elixir package.** Its transport is 25f's module, `Support.Triage`, which
already posts questions to Jev and decodes the reply; 25g adds the process half.

It takes ticket 25's *async processing* slot: work in its own process, many requests in flight,
supervision of a failed one.

## Result

**It compiles and runs behind two walls.** Measured by `25g_surface_probe.sh` in directories
matching each `module` line, with 25f's module built beside it:

1. **`Down` is not built.** Ticket 14 §6 decided the OTP message shapes are compiler-known types;
   nothing builds them. `Triage`'s `HandleInfo` stops on `no type named Down`.
2. **Behind it, a compiler crash**, from F58 the night before: a string-keyed brace handed to a
   type that includes `map<term, term>` crashes `bs_types:fields_fit/5` in `atom_lit(<<"title">>)`.
   The request state `{ "title" = issue.Title, "body" = issue.Body }` goes to 25f's `Json`, which
   includes `map<term, term>`. See friction 6.

With `Down` spelled as the raw tuple and the state built by `:maps.from_list`, nothing else is
refused, and [`25g_replay.erl`](25g_replay.erl) sends Jev's four README issues at once, plus one
whose transport crashes:

| Issue | Labels | Clause |
|---|---|---|
| App crashes on launch | `[:bug, :'priority:high']` | a bug, confidence 0.93, severity 2.4 |
| Passwords visible in debug log | `[:security]` | security 0.91, first clause, before the bug |
| Dark mode? | `[:feature]` | confidence 0.8 |
| hmm | `[:other, :'needs-triage']` | confidence 0.3, the fall-through |
| Crash the request | `(:error, …)` | the request process died; `Down` answered the caller |

The server is alive afterwards. Every issue takes the clause Jev's README says it does.

**The routing itself needed no workaround.** Jev's four `handle_answer` clauses become four
`Route` clauses matching a string-keyed open field set, `{ "kind": Chosen { Choice: "bug",
Confidence: c }, "severity": Scored { Score: sev } } when c > 0.85 and sev >= 2.0`. That was a
syntax error two days ago. It is spellable because of F58 (string keys) and F59 (the open `..`,
since the reply carries `Model` and `Usage` and answers not asked for), both built from ticket 78.

---

## The layout

```
lib/jev/             ← module Jev: the library
  index.bs           its transport (25f) and the process primitives
  ask.bs             one request, in its own process
lib/triage/          ← module Triage: Jev's README example
  index.bs           state, the reply type, the messages
  server.bs          the GenServer callbacks
  questions.bs       the three questions
  answer.bs          the routing
  crash.bs           a crashed request answers its caller
```

The extractor writes one flat directory per write-up, so the sections carry a module prefix
(`jev_ask.bs`) and the probe splits them into `Jev/` and `Triage/`, dropping it. `FRONTIER`
records the flat directory's wall; the probe measures the program's.

---

## `jev_index.bs`

```csharp
module Jev

// Jev.Server's transport is 25f: `Evaluate` posts the questions and decodes
// the reply. This module adds what Jev.Server adds on top: the request runs in
// its own process, and its answer comes back as a message.
using Support.Triage

using :erlang {
    (term, term) spawn_monitor(fn() -> term f)
    term send(term to, term msg)
}
```

## `jev_ask.bs`

```csharp
// Jev.Server's `{:reply, {tag, state, questions}, s}`. The request runs in a
// monitored process, so the caller never blocks and any number can be in
// flight; the answer arrives as `(:jev, tag, result)`. Returns the monitor
// reference, which a crash comes back under.
public term Ask(Send send, string token, string spec, term owner, term tag, Json state, list<(string, Question)> questions)

Ask(send, token, spec, owner, tag, state, qs) ->
    var (_, ref) = :erlang.spawn_monitor(() =>
        :erlang.send(owner, (:jev, tag, Evaluate(send, token, spec, state, qs))))
    ref
```

**This is the library, and it is one function.** `Jev.Server` owns the GenServer callbacks and
calls the user's, the way `GenStage` does, so a user returns `{:reply, {tag, state, questions}}`
from any callback and the library sends it. B# cannot write that: there is no user-declared
behaviour (friction 1). So `Ask` is called from the user's own callback, and the answer comes back
to the user's own `HandleInfo`. `spawn_monitor` takes the place of `Task.Supervisor`: the request
cannot take the server down, and its death arrives as a `Down`.

A function value crosses into `:erlang.spawn_monitor`, and the lambda captures `owner`, `tag` and
the rest: F46 doing Task's job.

---

## `triage_index.bs`

```csharp
module Triage

behaviour GenServer

using Jev
using Support.Triage

record Issue  { Title: string, Body: string }
record Config { Send: Send, Token: string }

// The pending requests, by monitor reference, so a crashed one can still be
// answered. `map<term, term>` because `Map.Get` is not built.
record State  { Send: Send, Token: string, Pending: map<term, term> }

// The answers this server asks for, by the names it asked them under. Open,
// because the model may answer more than it was asked and 25f's `Answers`
// list is turned into a map before it arrives here.
type TriageReply = { "kind": Chosen, "severity": Scored, "security": Likely, .. }

type Answer  = result<Evaluation, EvalError>
type Message = (:jev, term, Answer) | Down

using :gen_server {
    term reply(term from, term msg)
}

using :maps {
    map<term, term> from_list(list<(string, Answer)> pairs)
    map<term, term> put(term key, term value, map<term, term> m)
    map<term, term> remove(term key, map<term, term> m)
    (:ok, term) | :error find(term key, map<term, term> m)
}
```

## `triage_server.bs`

```csharp
public (:ok, State) Init(Config c)

Init(c) -> (:ok, State { Send = c.Send, Token = c.Token, Pending = :maps.from_list([]) })

// Jev.Server's `{:reply, {from, issue, questions}, s}`, as a call.
public (:noreply, State) HandleCall((:labels, Issue) req, term from, State s)

HandleCall((:labels, issue), from, s) ->
    var ref = Ask(s.Send, s.Token, "typesafe:jev-latest", Self(), from,
                  { "title" = issue.Title, "body" = issue.Body }, Questions())
    (:noreply, s with { Pending = :maps.put(ref, from, s.Pending) })

public (:noreply, State) HandleCast(term msg, State s)

HandleCast(msg, s) -> (:noreply, s)

// The answer is a message. A crashed request is a `Down` for its reference,
// and becomes `(:error, reason)` for the caller, as Jev.Server makes it.
public (:noreply, State) HandleInfo(Message m, State s)

HandleInfo((:jev, from, answer), s) ->
    var _ = :gen_server.reply(from, HandleAnswer(answer))
    (:noreply, s)
HandleInfo(Down { Ref: ref, Reason: :normal }, s) ->
    (:noreply, s with { Pending = :maps.remove(ref, s.Pending) })
HandleInfo(Down { Ref: ref, Reason: reason }, s) ->
    Crashed(ref, reason, s)
```

**`Down` is the wall**, and the field names `Ref` and `Reason` are this exemplar's guess: ticket 14
§6 made the type compiler-known and did not spell its fields.

**The request state is a string-keyed brace**, `{ "title" = issue.Title, "body" = issue.Body }`,
which is what the model reads. Passing it to 25f's `Json` crashes the compiler (friction 6).

---

## `triage_questions.bs`

```csharp
// Jev's README questions, the shorthand spelled out: a choice, a score, a
// yes/no.
private list<(string, Question)> Questions()

Questions() -> [
    ("kind", Choice { Instructions = "What kind of issue is this?",
                      Criteria = [("bug", "Something is broken or behaves unexpectedly"),
                                  ("feature", "Request for new behavior or an enhancement"),
                                  ("question", "Asks how to do something or for help"),
                                  ("other", "")] }),
    ("severity", Score { Instructions = "How severe is this issue for users?",
                         Criteria = ["Cosmetic", "Workaround exists",
                                     "Blocks a common use case", "Data loss or crash"] }),
    ("security", YesNo { Instructions = "Does this issue describe a security vulnerability?" })
]
```

## `triage_answer.bs`

```csharp
type Labels = list<atom> | (:error, term)

// Jev's own words: clause order is the routing, thresholds are guards.
private Labels HandleAnswer(Answer a)

HandleAnswer((:error, reason)) -> (:error, reason)
HandleAnswer(e) -> ValidateAs<TriageReply>(:maps.from_list(e.Answers)) switch {
    (:error, v) => (:error, v),
    reply       => Route(reply)
}

private list<atom> Route(TriageReply r)

Route({ "security": Likely { Probability: p } }) when p > 0.5
    -> [:security]
Route({ "kind": Chosen { Choice: "bug", Confidence: c }, "severity": Scored { Score: sev } })
    when c > 0.85 and sev >= 2.0
    -> [:bug, :'priority:high']
Route({ "kind": Chosen { Choice: k, Confidence: c } }) when c > 0.6
    -> [Label(k)]
Route({ "kind": Chosen { Choice: k } })
    -> [Label(k), :'needs-triage']

type Kind = :bug | :feature | :question | :other

private atom Label(string k)

Label(k) -> ParseAtom<Kind>(k) switch {
    :nothing => :other,
    kind     => kind
}
```

**`Route` is Jev's README, clause for clause.** The library cannot type the reply by the caller's
question names: `ValidateAs<T>` in a polymorphic function is refused, since an obligation needs a
ground type (25f friction 3). So the library returns 25f's `Evaluation`, whose answers are a list of
`(name, Answer)`, and `HandleAnswer` makes it a map and validates it once against this server's own
`TriageReply`. That is the seam, and it is one line.

`ParseAtom<Kind>` turns the model's choice into a label, and a label the model invents is
`:other`, where Jev's own parser makes the criteria keys the only atoms it can produce. The same
guarantee, reached the same way.

## `triage_crash.bs`

```csharp
using :erlang {
    term self()
}

private term Self()

Self() -> :erlang.self()

// A request that crashed answers its caller with the reason.
private (:noreply, State) Crashed(term ref, term reason, State s)

Crashed(ref, reason, s) -> :maps.find(ref, s.Pending) switch {
    (:ok, from) => Answered(from, (:error, reason), ref, s),
    :error      => (:noreply, s)
}

private (:noreply, State) Answered(term from, Labels labels, term ref, State s)

Answered(from, labels, ref, s) ->
    var _ = :gen_server.reply(from, labels)
    (:noreply, s with { Pending = :maps.remove(ref, s.Pending) })
```

---

## Friction

Each item ends with what the compiler would need, or the decision it waits on.

### 1. No user-declared behaviour, so the library cannot own the callbacks

`Jev.Server` is `use Jev.Server` plus `@behaviour Jev.Server`: it declares `handle_answer/3` as a
callback and delegates to the user's module. B# knows five behaviours (`GenServer`, `Supervisor`,
`Application`, `GenStatem`, `GenEvent`), and `behaviour Jev` is `no behaviour named Jev`. So the
B# library is a function the user's server calls, and the user writes the `HandleInfo` clause that
Jev.Server writes for them. The cost is two lines per server and one convention (`(:jev, tag,
answer)`), and a user who forgets the clause gets a server that ignores its answers.

- **Waits on a decision.** Ticket 22 asked whether a domain-shaped language fights a gateway; 25f
  met it as a closed provider union. Here it is sharper: a library cannot add a callback to a
  process. Unasked. What a yes would need: a `behaviour` declaration form naming callbacks with
  signatures, checked at the using module the way F10 checks OTP's table; and for Jev's delegation,
  a way for a library module to be the GenServer and call a user module by atom, which is
  `:erlang.apply` over a `term` today.

### 2. `Down` is decided and unbuilt

The front wall. Ticket 14 §6 put `Down`, `Exit` and `Timeout` in the compiler-known stratum and
[`14g`](14g_handle_info_blind_spot.erl) showed why; nothing builds them. Behind the wall the
exemplar spells the tuple, `(:'DOWN', term, :process, term, term)`, which works: quoted atoms lex.

- **Compiler delta:** three compiler-known records in the stratum table (`bs_check`), each a tag
  and a value builder, as F49 did for `ValidationError`, and a pattern that reads the BEAM tuple
  into them. Unbuilt, and its field names are not decided.

### 3. A narrowed `HandleInfo` is admitted, and one stray message kills the server

`HandleInfo(Message m, State s)` with `Message = (:jev, term, Answer) | Down` compiles. Measured
(`25g_surface_probe.sh` §3): a `GenServer` whose `HandleInfo` takes `(:jev, int)` handles its
message, then dies with `function_clause` on one stray atom. `Jev.Server` logs an unexpected message
and carries on. Ticket 14 §4 called narrowing a callback's argument the unsound direction, and
LANGUAGE.md §13 says the callback type check is unbuilt. So the language admits what 14 said it
should not, and the failure is the one 14g described.

- **Waits on the behaviour type check** (LANGUAGE.md §13, *"not started"*), or a decision that a
  narrowed `HandleInfo` is the author's declared crash policy, which ticket 12 would read it as.

### 4. `pid` is not a type

LANGUAGE.md §13 and ticket 14 §1 both say *"a process identifier is a `pid`"*. `bsc` answers
`pid is not a builtin type`. The exemplar writes `term` for every process and reference.

- **Compiler delta:** `pid` and `reference` as builtin names, `is_pid/1` and `is_reference/1` as
  their guards and their `-spec`s. A shipping document says something the compiler does not do,
  which is a status-claims matter as much as a feature.

### 5. The ref-to-tag table is `map<term, term>` and three foreign calls

A crashed request has to answer its caller, so the server keeps its pending requests by monitor
reference. `Map.Get` is unbuilt (ticket 48), so the table is `:maps.put`, `:maps.find` and
`:maps.remove`, declared in a `using :maps` block. It is five lines, and it works.

### 6. A compiler crash in F58

```csharp
public map<term, term> Go(string t)
Go(t) -> { "title" = t }
```

crashes `bsc`: `no function clause matching bs_types:atom_lit(<<"title">>)`, in `fields_fit/5`
(`bs_types.erl:901`). The same program with `{ Title = t }` compiles. `fields_fit/5` asks whether a
closed field set fits a dictionary type by turning each key into a type with `atom_lit/1`; a
string key is a binary. F58's sweep for atom-only key handling looked for printers and abstract
format and missed this one.

- **Compiler delta:** in `fields_fit/5`, a binary key's type is `string()` (a string key is valid
  UTF-8 by the lexer). A defect in F58, which is still in progress.

### 7. What is not written

Jev's recursive workflow, a `handle_answer` clause that replies again with the tag carrying the
depth (tree descent, bisection), and its cascade from a local model to Jev. Both are clauses that
call `Ask` again from `HandleAnswer`; neither needs anything the table above does not.

## What this says to the tickets

- **Ticket 14 (processes).** `spawn_monitor` with a lambda does Task's job, and a crashed request
  reaches its caller. Its three gaps are here: `Down` unbuilt, `pid` not a type, narrowing
  admitted unchecked.
- **Ticket 17 job 1 (ladders).** Jev's routing is four clauses with guards over a reply, none a
  ladder, and the fall-through is a clause, not an `else`.
- **Ticket 22 (a gateway).** A library cannot add a callback. 25f met the closed-union cost; this is
  the other half.
- **Ticket 12 (closed residuals).** `Route`'s last clause is a catch-all over an open field set,
  legal and wanted: an answer that clears no threshold still needs a label.
