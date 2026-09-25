# 92 — Combining several fallible values: fifteen arms that only forward an error

Type: grilling
Status: open — [ENG-433](https://linear.app/davewil/issue/ENG-433). Raised 2026-09-25 by the exemplar review (ENG-191)
Blocked by: —

## Why this is raised

25f friction 4. `Decode` needs a reply's `model`, `answers` and `usage`, each of which can fail.
`|?>` threads one value, so combining three is a tuple `switch` with one `(:error, e)` arm per
position. `decode.bs` has 15 arms whose only job is `(:error, e) => (:error, e)`. It compiles
today; the cost is the reading. Ticket 17 asked about a ladder of *unrelated* conditions, and
ticket 31 decided the valve for one threaded value; neither asked this.

```csharp
Decode(doc) -> (Text("model", doc), Obj("answers", doc), Obj("usage", doc)) switch {
    ((:error, e), _, _) => (:error, e),
    (_, (:error, e), _) => (:error, e),
    (_, _, (:error, e)) => (:error, e),
    (model, answers, usage) => Assemble(model, answers, usage)
}
```

## Round 1

**Q1. Is there a form that binds several fallible results and stops at the first failure?**

```csharp
Decode(doc) ->
    var model   = Text("model", doc)    |?
    var answers = Obj("answers", doc)   |?
    var usage   = Obj("usage", doc)     |?
    Assemble(model, answers, usage)
```

(The spelling is a placeholder for the question, not a proposal: ticket 34 owns local bindings,
ticket 26 owns `with` as record update, so Elixir's word is taken.) Under yes, each marked binding
stops the body with the `(:error, _)` or `:nothing` member it holds, as the valve stops (ticket 49's
fixed pair), and binds the value otherwise. Under no, the tuple switch above is the idiom and
LANGUAGE.md says so.

Compiler delta: a binding form in `bs_parser.yrl`; lowering to the nested two-armed `switch` F14
already emits for `|?>`, so the checker, the residual and the spec see nothing new; the refusal
F30 gives a valve over a value that cannot fail applies to each marked binding.
