# F56 — a string pattern's tail after string-literal segments is a `string`

**Status**      **in progress** — 8 tests in `binary_tests`, 1064 in the suite;
                `check-language.sh` gained a must-compile block, seen red on
                the tree first
**Implements**  [ticket 30](../../wayfinder/issues/30-binaries-as-a-parsing-grammar.md)'s
                string literal in pattern position, and
                [ticket 20](../../wayfinder/issues/20-untheorised-term-shapes.md)
                §4's `string` as a refinement of `binary`. Decides nothing
**Closes**      [ENG-403](https://linear.app/davewil/issue/ENG-403)
**Unblocks**    exemplar **25f**, whose only error this was
                ([`25f-llm-evaluation-client.md`](../../wayfinder/prototypes/25f-llm-evaluation-client.md),
                friction 1)
**Depends on**  F9 (`string`), F13 (binary patterns and the literal segment)

## Why this one now

25f is an LLM evaluation client, and it parses a model spec the way every
client does:

```csharp
record Model { Provider: Provider, Id: string }

public result<Model, EvalError> ParseSpec(string spec)

ParseSpec(<<"typesafe:", id>>)   -> Model { Provider = :typesafe, Id = id }
ParseSpec(<<"openrouter:", id>>) -> Model { Provider = :openrouter, Id = id }
ParseSpec(spec)                  -> (:error, (:unknown_model, spec))
```

It was refused, once per prefix clause:

```
error: ParseSpec assigns Id a value Model does not accept
  not covered by the declared type of Id:
    binary \ string
```

`seg_type(rest)` typed every unsized tail `binary` and never looked at the
subject. That was the only error in the module: with `Id: binary` the rest
compiled and ran. So this is the whole distance from "written" to "compiles
and runs" for 25f.

## The rule

A literal is whole UTF-8 characters, and UTF-8 resynchronises at every
character boundary, so what follows literal segments in a valid string is
valid too. An unsized tail binder whose preceding segments are **all string
literals** (zero of them included) is read from the subject at its pattern
path: `string` when the subject's binary part is within `string`, `binary`
otherwise. An integer or `_` segment anywhere before the tail can split a
character, and the tail stays `binary` — including when a literal follows it
(`<<c:8, ":", id>>`).

## What it compiles to

Nothing changes in the emitter; the match is the one F13 emits. In
`bs_check`, `seg_bindings/2` records the tail's path as the pattern's own path
plus a `{str_tail}` step, and `at_path/2` resolves that step against the
refined domain. The step is opaque to guards, like `{seg, _}`.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F56.1 | `Parse(<<"typesafe:", id>>) -> Model { Id = id }` over `string` | compiles; `Parse("typesafe:jev-latest")` has `Id = "jev-latest"` |
| F56.2 | two literals, one non-ASCII: `<<"hé", ":", id>>` | compiles; the tail keeps its UTF-8 bytes |
| F56.3 | F56.1 over a `binary` subject | refused, `field_value_not_accepted` |
| F56.4 | `<<c:8, id>>` over `string` | refused, `field_value_not_accepted` |
| F56.5 | `<<_:8, id>>` over `string` | refused, `field_value_not_accepted` |
| F56.6 | `<<c:8, ":", id>>` over `string` | refused, `field_value_not_accepted` |
| F56.7 | the same at a `switch` arm | compiles and runs |
| F56.8 | nested in a tuple: `(int, string)` compiles, `(int, binary)` is refused `return_not_declared` | as stated |

All eight are in `compiler/test/binary_tests.erl`. F56.1, .2, .7 and .8's first
half were red on the tree before the change; the four refusals were green
before and after, and are there so the rule cannot pass by typing every tail
`string`.

## Out of scope

- A sized binary segment (`b:size`) before the tail. It keeps `binary`; a
  byte count read at run time says nothing about character boundaries.
- Typing the *matched* literal segments themselves; they bind nothing.
- The other direction, a `binary` checked into a `string` — the sixth codegen
  obligation, still unbuilt.

## Done when

25f's module compiles as written in a directory its `module` line matches
(`wayfinder/prototypes/25f_surface_probe.sh` §1), the eight scenarios pass,
the LANGUAGE.md block compiles, and `./bin/verify.sh` is green twice from a
clean clone.
