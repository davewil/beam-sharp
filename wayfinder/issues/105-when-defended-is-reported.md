# 105 — When does the compiler report what it defended?

Type: grilling
Status: resolved 2026-09-25 — [ENG-468](https://linear.app/davewil/issue/ENG-468). Raised and
answered 2026-09-25 out of [ENG-296](https://linear.app/davewil/issue/ENG-296) (ticket 23 §3);
one question, one round
Blocked by: —

## Why this is raised

[23](23-what-the-language-owes-an-agent.md) §3 answered ticket 18's question, *may an agent ask
what the compiler defended?*, with **yes, as an informational diagnostic on this channel, at the
moment the agent is compiling**, and §4 put `defended` among the descriptors whose payload shape
is frozen. Nothing shaped it, and it is unbuilt: `defended` appears nowhere in `compiler/src`, and
the `bs_diag` comment ticket 23 quoted about it was removed in `6e5b96a`. ENG-296 carried the
question of when it is reported and what it names.

## The program

Measured at `5e06c5e`:

```csharp
module Net

type Port = int where value >= 1 and value <= 65535

public atom Listen(Port p)
Listen(80)  -> :http
Listen(443) -> :https
Listen(p)   -> :other
```

- `bsc Net` prints nothing, exit 0. The emitted `Listen` carries a boundary guard on `p` (the
  integer kind test and the range 1..65535, since the last clause proves neither) and nothing
  says so.
- `bsc --api Net` prints `atom Listen(1..65535)`: the declared domain, not the checks emitted.
- `Listen(70000)` fails with `crashed: error:function_clause`.

## Q1 — When is `defended` reported?

Three answers were put: on every compile on the machine channel only; on every compile in the
human text as well; or only under `--api`. David asked which would help an LSP most, and whether
the range belongs in it.

The LSP ENG-305 designs shells out to `bsc --diagnostics json` on every save and maps it to
`publishDiagnostics`, so an entry on that channel reaches the editor with no second call. LSP's
Information and Hint severities are the right register for *"the compiler checks this at run
time"*, shown as an inlay hint after the parameter or a hover. That needs the parameter's position
(F35 already gives every descriptor one) and the checks as data, not prose. And it should report
the checks **emitted**, not the type declared: ticket [46](46-refined-parameter-at-the-boundary.md)
made the guard the part of the refinement the clauses do not already prove, which `--api`, printing
the declared domain, cannot show.

**A1 (David, 2026-09-25):** *"Yes, record it"*, on the combined answer: **on every compile, on the
machine channel only; one `defended` entry per guarded parameter, carrying its position and the
emitted checks as fields; the human text stays silent.**

## The compiler delta

- The guards are computed in `bs_emit:boundary_guards/6`, which runs after the checker. The
  emitter returns, beside the forms, the list of guarded parameters with the checks it emitted for
  each, and `bsc` hands them to `bs_diag` for the term channel. Recomputing them in `bs_check`
  would be a second copy of the rule that could drift from what is emitted.
- One `bs_diag` tag, `defended`, info severity, with a map payload: `function`, `parameter`,
  `line`, `column`, and `checks`, a list of maps such as `#{kind => int}` and
  `#{lo => 1, hi => 65535}`. It joins `contractual/0`, as §4 said it would.
- The human renderer prints nothing for this tag. `--diagnostics term` and `--diagnostics json`
  carry it; ticket 77's mapping and F47's JSON encoding apply unchanged.
- A parameter whose clauses prove the whole refinement has no guard and gets no entry.

## Not decided here

- How ENG-305 maps the entry (Information or Hint, inlay hint or hover). That is the server's
  choice when it is built.
- Ticket 23 §6, the `error_info` `cause` map at run time, which still owes its emitted-size
  number before it is built (ENG-296).

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [When does the compiler report what it defended?](issues/105-when-defended-is-reported.md)
  — **on every compile, on the machine channel only: one `defended` entry per guarded parameter
  on `--diagnostics term` and `json`, carrying its position and the emitted checks as fields; the
  human text stays silent.** Raised and resolved 2026-09-25 in one round on one question, out of
  [ENG-296](https://linear.app/davewil/issue/ENG-296), shaping ticket
  [23](issues/23-what-the-language-owes-an-agent.md) §3's *"yes, as an informational diagnostic
  on this channel"*, which had decided the answer and never its moment. Chosen for the LSP
  (ENG-305), which reads that channel on every save: position anchors an inlay hint, and the checks
  are the ones emitted, which after ticket [46](issues/46-refined-parameter-at-the-boundary.md) can
  be narrower than the declared domain `--api` prints. The guards come from
  `bs_emit:boundary_guards/6` and are handed back rather than recomputed in the checker. `defended`
  joins `contractual/0`. Unbuilt — ENG-296.
```
