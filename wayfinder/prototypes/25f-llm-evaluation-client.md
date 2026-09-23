# PROTOTYPE 25f — exemplar: an LLM evaluation client (ReqLLM's `evaluate/4` against Jev)

> **Throwaway.** Ticket [25](../issues/25-exemplar-programs.md), exemplar 6. Written against the
> surface as it stands after F55 (2026-09-24).
> The run is [`25f_replay.erl`](25f_replay.erl): it drives the module `bsc` compiles from this
> write-up, serving it the wire bodies ReqLLM's own test suite serves. The compiler measurements
> are [`25f_surface_probe.sh`](25f_surface_probe.sh). Everything claimed below was executed.

The program is a support desk's triage step. A customer message goes to TypeSafe's **Jev** model,
which answers named questions: which department, how severe, whether it is urgent. The answers
pick a queue and decide whether to page someone.

It is modelled on [ReqLLM](https://req-llm.hexdocs.pm/overview.html)'s `ReqLLM.evaluate/4`, read at
`agentjido/req_llm` commit `5a0735d` (2026-09-22), not at its overview page:
`lib/req_llm/evaluation.ex`, `lib/req_llm/evaluation/codec.ex`,
`lib/req_llm/providers/typesafe.ex`, the evaluation half of `lib/req_llm/providers/openrouter.ex`,
and the wire bodies in `test/req_llm/evaluation_test.exs`. Two providers serve Jev: TypeSafe's own
`/v1/systemone`, and OpenRouter's `/api/alpha/decisions`, which adds routing preferences. A
yes/no question goes on the wire as type `noul` and its answer comes back under a `noul` key;
ReqLLM's codec renames it to `boolean` in both directions.

**Why this exemplar.** Ticket 25's six are all servers: the program owns its wire format. An LLM
client is the other side. The schema belongs to someone else, it is JSON with lowercase keys, and
the program's first job is to write and read it exactly. None of 25a–25e does that, and it is now
one of the most common things a BEAM application does. 25f takes a seventh slot rather than
ticket 25's unwritten *async processing* one: `evaluate/4` makes one request and gets one reply.
ReqLLM's streaming path (`stream_text/3`, Finch, `StreamChunk`) is that workload, and it is not
written here.

## Result

**It compiles and runs behind one wall.** Measured in a scratch copy rooted at `Support/Triage`
so the path matches the declaration, the module stops on one error, reported once for each of the
two prefix clauses in `spec.bs`:

```
spec.bs: error: ParseSpec assigns Id a value Model does not accept
  not covered by the declared type of Id:
    binary \ string
```

Declare `Id: binary` and nothing else in the module is refused. It then builds to a `.beam` and
[`25f_replay.erl`](25f_replay.erl) runs five cases through `Evaluate`:

| Case | What comes back |
|---|---|
| `typesafe:jev-latest`, ReqLLM's TypeSafe fixture | an `Evaluation` with three answers; `Decide` gives `Queue = :billing`, `Page = true` |
| `openrouter:typesafe/jev-1.13`, ReqLLM's OpenRouter fixture (extra `id`, `provider`, `usage.cost`) | the same answers; the body sent carried `"provider":{"zdr":true}` |
| OpenRouter, `200` with `{"answers":{}}`, ReqLLM's own malformed case | `(:error, (:malformed, "model"))` |
| TypeSafe, `401` | `(:error, (:status, 401))` |
| `anthropic:claude-haiku-4-5` | `(:error, (:unknown_model, …))`, and nothing was sent |

The request body `Body` writes is the one ReqLLM writes, key for key, including `"type":"noul"`
for the yes/no question. The replay prints it, so a reader can compare it with
`ReqLLM.Providers.TypeSafe.build_body/1`.

So the verdict is different from 25a–25e's. The language can write this client today. The cost
is in *how*. 101 of the module's 206 non-blank lines are `decode.bs`, which reads one JSON
object; the domain logic, `route.bs`, is 24. The friction list below accounts for that gap.

---

## The layout

```
lib/support/triage/                ← compiles to ONE beam: Support.Triage
  index.bs      module, types, records, foreign declarations
  spec.bs       "typesafe:jev-latest" → a Model
  request.bs    the request body, per provider
  evaluate.bs   the call: parse the spec, send, read the status, parse the body
  decode.bs     the reply body → an Evaluation
  route.bs      the answers → a queue and a page decision
```

Like 25e, this declares its `module`, and the extracted copy under
`compiler/examples/exemplars/25f-llm-evaluation-client/` therefore stops on the directory check
before the compiler reaches the program. `FRONTIER` records that wall; the probe measures the
program's own wall in a correctly named directory.

---

## `index.bs`

```csharp
module Support.Triage

// Which service answers. ReqLLM reaches Jev two ways: TypeSafe's own
// System One endpoint, and OpenRouter's Decisions API.
type Provider = :typesafe | :openrouter

record Model { Provider: Provider, Id: string }

// The three things a Jev model can be asked. ReqLLM passes a map keyed by
// `type`; here the kind is the record's tag.
record Choice { Instructions: string, Criteria: list<(string, string)> }
record Score  { Instructions: string, Criteria: list<string> }
record YesNo  { Instructions: string }
type Question = Choice | Score | YesNo

record Chosen { Choice: string, Confidence: float }
record Scored { Score: float, Confidence: float }
record Likely { Probability: float }
type Answer = Chosen | Scored | Likely

record Usage      { InputTokens: int, OutputTokens: int }
record Evaluation { Model: string, Answers: list<(string, Answer)>, Usage: Usage }

// The transport is handed in, as ReqLLM's tests hand Req a plug.
record HttpRequest { Url: string, Token: string, Body: binary }
type HttpResponse = (int, binary)
type Send = fn(HttpRequest) -> HttpResponse

type EvalError = (:unknown_model, string) | (:status, int) | (:malformed, string)

// What `json:decode/1` can hand back. `term` is the honest answer and is
// refused: it absorbs the failure channel.
type Json = map<term, term> | list<term> | binary | int | float | atom

using :json {
    term encode(term value)
    result<Json, foreign_error> decode(binary text)
}

using :erlang {
    binary iolist_to_binary(term data)
}

using :maps {
    map<term, term> from_list(list<(binary, term)> pairs)
    list<term> to_list(map<term, term> m)
    (:ok, term) | :error find(binary key, map<term, term> m)
}
```

**The transport is a parameter.** ReqLLM's tests hand Req a plug (`req_http_options: [plug:
...]`); here `Evaluate` takes a `Send`, an arrow over two records. That is F46's function value
doing the job a Req plug does, and it is why the replay can drive the module with no network.
A production `Send` over `:httpc` is not written: `httpc` wants charlist header names, and that is
a separate exemplar's problem.

**`Json` is six members because `term` is refused.** `json:decode/1` raises on bad input, so
the declaration asks for the wrapper with `foreign_error`. The honest success type is `term`, and
`result<term, foreign_error>` is refused because `term` absorbs the failure member (§7, ticket
64). The fix is to list what the platform decoder can return. See friction 5.

---

## `spec.bs`

```csharp
// "typesafe:jev-latest" or "openrouter:typesafe/jev-1.13".
public result<Model, EvalError> ParseSpec(string spec)

ParseSpec(<<"typesafe:", id>>)   -> Model { Provider = :typesafe, Id = id }
ParseSpec(<<"openrouter:", id>>) -> Model { Provider = :openrouter, Id = id }
ParseSpec(spec)                  -> (:error, (:unknown_model, spec))
```

**This is the wall.** A string literal prefix in a binary pattern works: `ParseSpec` dispatches on
`"typesafe:"` and `"openrouter:"` and binds the rest (F13). The rest is typed `binary`, though:
the checker does not know that a valid UTF-8 string with a whole-character prefix removed is still
valid UTF-8. `Model.Id` is declared `string`, so the construction is refused. See friction 1.

---

## `request.bs`

```csharp
private string Url(Provider p)

Url(:typesafe)   -> "https://api.typesafe.ai/v1/systemone"
Url(:openrouter) -> "https://openrouter.ai/api/alpha/decisions"

public binary Body(Model m, Json state, list<(string, Question)> questions)

Body(m, state, qs) -> :erlang.iolist_to_binary(:json.encode(Envelope(m, state, qs)))

// OpenRouter takes routing preferences; zero data retention is the one a
// support desk asks for.
private map<term, term> Envelope(Model m, Json state, list<(string, Question)> qs)

Envelope(Model { Provider: :typesafe } m, state, qs) ->
    :maps.from_list([("model", m.Id), ("state", state), ("questions", Wire(qs))])
Envelope(Model { Provider: :openrouter } m, state, qs) ->
    :maps.from_list([("model", m.Id), ("state", state), ("questions", Wire(qs)),
                     ("provider", :maps.from_list([("zdr", true)]))])

private map<term, term> Wire(list<(string, Question)> qs)

Wire(qs) -> :maps.from_list(List.Map(qs, ((name, q)) => (name, WireQuestion(q))))

// A yes/no question goes out as `noul`. ReqLLM's codec renames it on the way
// out and back; here the rename is one clause each way.
private map<term, term> WireQuestion(Question q)

WireQuestion(Choice c) ->
    :maps.from_list([("type", "choice"), ("instructions", c.Instructions),
                     ("criteria", :maps.from_list(c.Criteria))])
WireQuestion(Score s) ->
    :maps.from_list([("type", "score"), ("instructions", s.Instructions),
                     ("criteria", s.Criteria)])
WireQuestion(YesNo y) ->
    :maps.from_list([("type", "noul"), ("instructions", y.Instructions)])
```

**Every key is built from a pair list.** The author would write the body as a record, or a map
literal, or `ToJson<T>`. None of those can produce `{"model": …}`, for three separate reasons
(friction 2). `:maps.from_list` over `(binary, term)` pairs is the spelling that works. It is
ReqLLM's own `build_body/1` shape with the map literal replaced by a list of pairs.

**`Envelope` dispatches on the record's field.** `Model { Provider: :openrouter } m` picks the
provider in the head. That is closer to ReqLLM's `prepare_request/4` per provider module than it
looks: each provider's clause is a separate head, and the checker proves the set covers `Provider`.

---

## `evaluate.bs`

```csharp
public result<Evaluation, EvalError> Evaluate(Send send, string token, string spec, Json state, list<(string, Question)> questions)

Evaluate(send, token, spec, state, qs) -> ParseSpec(spec) |?> Call(send, token, state, qs)

private result<Evaluation, EvalError> Call(Model m, Send send, string token, Json state, list<(string, Question)> qs)

Call(m, send, token, state, qs) ->
    send(HttpRequest { Url = Url(m.Provider), Token = token, Body = Body(m, state, qs) }) |> Read()

public result<Evaluation, EvalError> Read(HttpResponse r)

Read((status, body)) when status >= 200 and status <= 299 -> Parse(body)
Read((status, _))                                       -> (:error, (:status, status))

private result<Evaluation, EvalError> Parse(binary body)

Parse(body) -> :json.decode(body) switch {
    (:error, _) => (:error, (:malformed, "the body is not JSON")),
    doc         => Object(doc) |?> Decode()
}
```

The valve fits the outer chain. `ParseSpec` fails as a value, and `Call` is declared over `Model`,
not `result<Model, EvalError>`, because `|?>` has already removed the failure (§8). That is
ReqLLM's `with` chain in `evaluate/4`, one step shorter.

`Read`'s status test is a guard, because a relational pattern goes only where a whole argument goes
(§2); `(>= 200 and <= 299, body)` is not a pattern. The checker reads the guard: with the second
clause deleted it reports `Read((n, b)) when n <= 199` and `Read((n, b)) when n >= 300` as the
missing heads. The second clause is there because those two ranges are the error case.

---

## `decode.bs`

```csharp
// Reading a JSON object is one `:maps.find` per key and one validation per
// value, because B# has no spelling for a lowercase string key.
private result<Evaluation, EvalError> Decode(map<string, term> doc)

Decode(doc) -> (Text("model", doc), Obj("answers", doc), Obj("usage", doc)) switch {
    ((:error, e), _, _) => (:error, e),
    (_, (:error, e), _) => (:error, e),
    (_, _, (:error, e)) => (:error, e),
    (model, answers, usage) => Assemble(model, answers, usage)
}

private result<Evaluation, EvalError> Assemble(string model, map<string, term> answers, map<string, term> usage)

Assemble(model, answers, usage) -> (Answers(:maps.to_list(answers)), Tokens(usage)) switch {
    ((:error, e), _) => (:error, e),
    (_, (:error, e)) => (:error, e),
    (named, u)       => Evaluation { Model = model, Answers = named, Usage = u }
}

private result<Usage, EvalError> Tokens(map<string, term> usage)

Tokens(usage) -> (Int("input_tokens", usage), Int("output_tokens", usage)) switch {
    ((:error, e), _) => (:error, e),
    (_, (:error, e)) => (:error, e),
    (i, o)           => Usage { InputTokens = i, OutputTokens = o }
}

private result<list<(string, Answer)>, EvalError> Answers(list<term> pairs)

Answers([]) -> []
Answers([pair, ..rest]) -> (Named(pair), Answers(rest)) switch {
    ((:error, e), _) => (:error, e),
    (_, (:error, e)) => (:error, e),
    (one, more)      => [one, ..more]
}

private result<(string, Answer), EvalError> Named(term pair)

Named(pair) -> ValidateAs<(string, map<string, term>)>(pair) switch {
    (:error, _)    => (:error, (:malformed, "an answer is not an object")),
    (name, answer) => One(answer) |?> Tag(name)
}

private (string, Answer) Tag(Answer a, string name)

Tag(a, name) -> (name, a)

// The wire's `type` names the answer. `noul` is the boolean.
private result<Answer, EvalError> One(map<string, term> a)

One(a) -> Text("type", a) switch {
    "choice"    => ChosenFrom(a),
    "score"     => ScoredFrom(a),
    "noul"      => LikelyFrom(a),
    (:error, e) => (:error, e),
    other       => (:error, (:malformed, other))
}

private result<Answer, EvalError> ChosenFrom(map<string, term> a)

ChosenFrom(a) -> (Text("choice", a), Number("confidence", a)) switch {
    ((:error, e), _) => (:error, e),
    (_, (:error, e)) => (:error, e),
    (c, p)           => Chosen { Choice = c, Confidence = p }
}

private result<Answer, EvalError> ScoredFrom(map<string, term> a)

ScoredFrom(a) -> (Number("score", a), Number("confidence", a)) switch {
    ((:error, e), _) => (:error, e),
    (_, (:error, e)) => (:error, e),
    (s, p)           => Scored { Score = s, Confidence = p }
}

private result<Answer, EvalError> LikelyFrom(map<string, term> a)

LikelyFrom(a) -> Number("noul", a) switch {
    (:error, e) => (:error, e),
    p           => Likely { Probability = p }
}

// One getter per value type: `ValidateAs<T>` inside `Get<T>` is refused,
// because an obligation cannot be generated for a type nobody has chosen.
private result<map<string, term>, EvalError> Obj(string key, map<string, term> m)

Obj(key, m) -> :maps.find(key, m) switch {
    :error   => (:error, (:malformed, key)),
    (:ok, v) => Object(v)
}

private result<map<string, term>, EvalError> Object(term t)

Object(t) -> ValidateAs<map<string, term>>(t) switch {
    (:error, _) => (:error, (:malformed, "expected an object")),
    m           => m
}

private result<string, EvalError> Text(string key, map<string, term> m)

Text(key, m) -> :maps.find(key, m) switch {
    :error   => (:error, (:malformed, key)),
    (:ok, v) => ValidateAs<string>(v) switch {
        (:error, _) => (:error, (:malformed, key)),
        s           => s
    }
}

private result<int, EvalError> Int(string key, map<string, term> m)

Int(key, m) -> :maps.find(key, m) switch {
    :error   => (:error, (:malformed, key)),
    (:ok, v) => ValidateAs<int>(v) switch {
        (:error, _) => (:error, (:malformed, key)),
        n           => n
    }
}

// JSON writes 1.0 as 1, so a probability arrives as either part.
private result<float, EvalError> Number(string key, map<string, term> m)

Number(key, m) -> :maps.find(key, m) switch {
    :error   => (:error, (:malformed, key)),
    (:ok, v) => ValidateAs<int | float>(v) switch {
        (:error, _) => (:error, (:malformed, key)),
        n           => Widen(n)
    }
}

private float Widen(int | float n)

Widen(int i)   -> Float.FromInt(i)
Widen(float f) -> f
```

**This is where the 101 lines are.** Each value is read in two steps: `:maps.find` for the key,
and a `ValidateAs` for the type. Most of the file is failures being passed along by hand. See
frictions 2, 3 and 4.

`Widen` is the part that reads well. JSON writes `1.0` as `1`, so `confidence` can decode as an
`int`. `ValidateAs<int | float>` accepts either, and F53's type prefix takes the union apart in two
clauses with no catch-all.

---

## `route.bs`

```csharp
type Department = :billing | :support

record Route { Queue: Department, Page: bool }

public Route Decide(Evaluation e)

Decide(e) -> Route { Queue = Queue(Lookup("department", e.Answers)),
                     Page  = Page(Lookup("urgent", e.Answers)) }

private option<Answer> Lookup(string name, list<(string, Answer)> answers)

Lookup(name, [])                    -> :nothing
Lookup(name, [(== name, a), .._])   -> a
Lookup(name, [_, ..rest])           -> Lookup(name, rest)

// A department the model invents goes to support rather than crashing.
private Department Queue(option<Answer> a)

Queue(Chosen c) -> ParseAtom<Department>(c.Choice) switch {
    :nothing => :support,
    d        => d
}
Queue(Scored s) -> :support
Queue(Likely l) -> :support
Queue(:nothing) -> :support

private bool Page(option<Answer> a)

Page(Likely l) when l.Probability >= 0.8 -> true
Page(Likely l) -> false
Page(Chosen c) -> false
Page(Scored s) -> false
Page(:nothing) -> false
```

`ParseAtom<Department>` is the right tool for the model's `choice`: a department the model invents
becomes `:nothing` and goes to support, and the atom table does not grow (§10).

`Lookup` uses `== name` in a list pattern (§2), which is the only way to match a runtime value.

`Queue` and `Page` name every member instead of ending in `_`. That was the author's choice, not
the compiler's: see friction 6.

---

## Friction

Each item ends with what the compiler would need, as concrete work, or with the decision it waits
on. None is decided here.

### 1. A string's suffix after a literal prefix is `binary`, not `string`

The wall. `ParseSpec(<<"typesafe:", id>>)` binds `id : binary` when the subject is a `string`.
Removing a string literal prefix from valid UTF-8 leaves valid UTF-8, because a literal is whole
characters. The checker does not use that fact.

- **Compiler delta:** in `bs_check`, when a binary pattern's subject is `string` and every segment
  before an unsized tail is a string literal, type the tail `string`. One clause in the segment
  binder; no new syntax. A sized integer segment before the tail (`<<c:8, rest>>`) still gives
  `binary`, correctly: it can split a multi-byte character.
- It is the only error in the module, so building it is the whole remaining distance from
  "written" to "compiles and runs" for 25f.
- Unasked. No ticket covers the refinement of a pattern's tail; ticket 30 settled string literals
  in pattern position and said nothing about what the rest binds as.

### 2. B# cannot name a lowercase JSON key, either way

Every key in this protocol is lowercase: `model`, `state`, `questions`, `type`, `answers`, `usage`,
`input_tokens`. That holds for TypeSafe, OpenRouter, OpenAI, Anthropic and Google alike. Each thing
an author reaches for first was measured (`25f_surface_probe.sh` §2):

| What the author writes | What happens |
|---|---|
| `record Q { type: string }` | syntax error: a field name is PascalCase |
| `ToJson<Question>(Question { Type = "noul", … })` | compiles, and writes `{"Kind":"P.Question","Type":"noul",…}` — a body the API does not accept, from a program that type-checks |
| `{ "answers": a }` as a pattern | syntax error |
| `type Wire = { Model: string }` then `ValidateAs<Wire>` on `json:decode` output | `(:error, … Path = [])`: the field set is keyed by the atom `'Model'`, and the decoder gives `<<"model">>` |
| `#{ "type" => "noul" }` | `illegal characters "#"` (ticket 48: the language's spelling would be bare braces, and that has atom keys too) |

The second row matters most. It is not refused. It compiles, runs and sends the wrong bytes, and
the first report is a `400` from someone else's server.

What works today is the pair list and `:maps.find`, and it costs the 101 lines above.

- **Waits on a decision.** Ticket 77 decided the encode direction is the platform's encoding of
  the erased record, `Kind` and PascalCase field names included. Ticket 78 (open, ENG-373) is the
  decode direction, and its program is a B# server reading its own records back. 25f is the case
  neither has: **a schema the program does not own.** It is a second program for ticket 78, and
  it asks something 77 did not: whether a record can say what its fields are called on the wire.
- Until then, `Map.Get` (ticket 48, reserved and unbuilt) would halve `decode.bs`: every `Text`,
  `Int`, `Number` and `Obj` is a hand-written `Map.Get` plus a validation.

### 3. There is no typed getter, so there are four

The natural helper is `Get<T>(string key, map<string, term> m) -> ValidateAs<T>(...)`. It is
refused twice. With `T` only in the return it is `unrecoverable_type_variable`. With a witness
parameter added it is `obligation_over_type_variable`, because a codegen obligation needs a ground
type (§9). So `decode.bs` has `Obj`, `Text`, `Int` and `Number`, which are the same function four
times.

- Both refusals are correct as the rules stand. What would remove the duplication is `Map.Get`
  returning the found value, with one `ValidateAs` written at each call site. That is ticket 48's
  unbuilt operation again, not a new capability.

### 4. The valve threads one value, and a reply has three

`Decode` needs `model`, `answers` and `usage`, all of which can fail. `|?>` passes one value from
stage to stage, so combining three results is a tuple `switch` with one `(:error, e)` arm per
position and a final arm that binds all three. `Decode`, `Assemble`, `Tokens`, `Answers`,
`ChosenFrom` and `ScoredFrom` are all that shape. With `One` and `LikelyFrom`, `decode.bs` has 15
arms whose only job is `(:error, e) => (:error, e)`.

This is the shape ticket 17 job 1 asked about, a ladder. It is not a ladder of unrelated
conditions, though. Every arm is the same condition, *did this one fail*, so `cond` would not
help. What the program wants is Elixir's `with` over several bindings, or an applicative
combine.

- Unasked. Ticket 31 decided the valve is the middleware mechanism for a single threaded value;
  combining independent fallible values is a different question, and this is the first exemplar
  to ask it at width three.

### 5. `json:decode` cannot be declared honestly

`result<term, foreign_error> decode(binary)` is refused: `term` absorbs `(:error, _)`, so no caller
could write the failure clause. The declaration has to list the six things the decoder returns,
`map<term, term> | list<term> | binary | int | float | atom`. That is correct, and it is found by
reading OTP's `json` source rather than by being told.

- Ticket 64 (open, ENG-254) is this problem. 25f is a second program for it, and it is the most
  ordinary foreign call in the module.

### 6. A catch-all over a union of records is admitted when it should not be — a defect

This one is not about the exemplar. It was found while writing `Queue`, and it is a defect in the
compiler against a decided rule.

Ticket 12 §2's own worked example: `type Event = OrderPlaced | OrderShipped | OrderCancelled`,
two handled, and *"`_` here is an error: name the case."* Measured on that example
(`25f_surface_probe.sh` §6):

| The three records carry | `Handle(OrderPlaced p)`, `Handle(OrderShipped s)`, `Handle(_)` |
|---|---|
| `{ Id: :x }` | refused: *"Handle discards cases the compiler can name … `Handle(OrderCancelled o) -> ...`"* |
| `{ Id: int }` | **compiles, and returns `:other` for an `OrderCancelled`** |

With the catch-all removed, the `{ Id: int }` version is refused as inexhaustive and names
`Handle(OrderCancelled o)`, so the checker knows the case name. The "open residual" test is looking
for an unbounded part *anywhere* in the residual, including inside a record's fields, instead of
at the top of the union. Almost every real record has an `int` or `string` field, so the rule
ticket 12 §2 made the headline of exhaustiveness is almost never enforced over a union of records.
That is the case ticket 12 predicted would bite hardest (*"a large, closed domain event union"*).

In this module, `Queue(_)` over `Answer`'s residual compiles. The named clauses are there because
the author wrote them, and nothing would have asked.

- **Compiler delta:** the open/closed classification of a residual should look at the union's
  members, where a record member is closed by its tag whatever its fields hold. Filed as a defect
  against ticket 12 §2 as [ENG-402](https://linear.app/davewil/issue/ENG-402) rather than decided here: LANGUAGE.md §3 says *"any type with an unbounded
  part"*, which reads either way, and ticket 12's example is the tie-break.

### 7. A new provider is a union edit, and the compiler finds every site. One diagnostic is unreadable

ReqLLM adds a provider by writing a module that does `use ReqLLM.Provider`, a behaviour of its
own. B# has no user-declared behaviour (`behaviour Provider` → *"no behaviour named Provider"*;
§13 lists the five OTP ones). So a provider is a member of `Provider` and a clause in each function
that dispatches on it. That is closed where ReqLLM is open, which is ticket 22's question: does a
domain-shaped language fight a gateway? For two providers it does not. Adding `:vercel` to
`Provider` makes the compiler name both sites that need a clause, which ReqLLM cannot do.

One of the two diagnostics is poor:

```
request.bs: error: Url is not exhaustive
  no clause matches:
    Url(:vercel) -> ...
request.bs: error: Envelope is not exhaustive
  no clause matches:
    Envelope(Model m, a, []) -> ...
    Envelope(Model m, a, [(s, YesNo y), ..]) -> ...
    Envelope(Model m, a, [(s, Choice c), ..]) -> ...
    ... (25 more)
```

The missing clause is `Envelope(Model { Provider: :vercel } m, state, qs)`, and adding exactly that
clause makes the module compile, so the checker's residual is precise. What is wrong is how it is
rendered. `--diagnostics term` carries all 28 heads in `heads.pasteable`, and none of them
mentions `:vercel`: the residual string is `({ Kind: :'Support.Triage.Model' }, …)`, with the
narrowed `Provider` field dropped, and the other two parameters are split by shape although every
clause binds them as bare names. 25c recorded that *"the residual does not scale as a diagnostic"*;
this is a related failure with a different cause.

- **Compiler delta:** in the residual renderer, print a record member's narrowed field as a
  property pattern (`Model { Provider: :vercel } m`) instead of the bare type prefix, and stop
  splitting a parameter that every clause binds as a bare name. Both are in the head printer
  (`pattern_parts` / `head_parts`), not the algebra.

### 8. Floats are not a problem

Recorded because 25a–25e had no floats, and this protocol is full of them: every probability,
confidence and score. F51's `float`, `Float.FromInt` and a float guard (`l.Probability >= 0.8`)
covered all of it. The one wrinkle, `1` versus `1.0` on the wire, is `Widen`, which is four lines.

## What this says to the tickets ticket 25 serves

- **Ticket 12 (closed residuals):** zero forced closes, because of friction 6. Two deliberate ones
  (`Queue`, `Page`, three members named in each). Naming them read better, since a fourth `Answer`
  kind should make both functions fail to compile.
- **Ticket 17 job 1 (ladders):** six tuple switches of width two or three, all error forwarding.
  They are not the unrelated-conditions ladder 17 asked about. `cond` would not help; see friction
  4.
- **Ticket 22 (opinionated grammar vs a gateway):** a closed provider union reads well at two, and
  the compiler finding every site on an addition is a real advantage over ReqLLM's behaviour. The
  cost is that a third party cannot add a provider without editing `Provider`.
