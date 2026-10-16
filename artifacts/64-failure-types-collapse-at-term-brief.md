# Decision brief — ticket 64: `option<term>` and `result<term, E>` collapse to bare `term`

**Linear**: [ENG-254](https://linear.app/davewil/issue/ENG-254) · **Ticket file**: `wayfinder/issues/64-failure-types-collapse-at-term.md`
**State**: OPEN. This brief resolves nothing. **Independent verification**: `artifacts/verification/64-verifier.md`.

## The question, as a program

After ticket 68, `option<term>` is *refused at the declaration*. What does an author write for a lookup in a `map<string, term>`?

```csharp
public option<term> Get(map<term, term> m, atom k)     // error: `:nothing` is absorbed by `term`
```

The ticket's remaining open half (its Q2) is "the author is left with nothing to reach for", and its Q3 asks whether `result<T, E>` has the same problem at `E = term`.

## Sub-decisions

1. Is anything missing from the language, or only from the prelude? (Q2)
2. Does `result<T, E>` collapse at `E = term`? (Q3, never measured before)
3. If the prelude should ship a tagged type, what is its shape and name?

## Findings (`probes/64/matrix.sh`, output `matrix_result.txt`, re-run byte-identical by the verifier)

| declaration | result | why |
|---|---|---|
| `option<term>` | refused | `:nothing` absorbed by `term` |
| `result<term, atom>` | refused | `(:error, atom)` absorbed by `term` |
| `result<term, term>` | refused | `(:error, term)` absorbed by `term` |
| `term \| :nothing`, `atom \| :nothing` | refused | absorbed |
| `option<option<int>>` | refused | `:nothing` absorbed by `:nothing \| int` |
| `option<int>` | **accepted** | `:nothing \| int` |
| `result<int, term>` | **accepted** | `int \| (:error, term)`: **Q3 answered: `E = term` does not collapse; only `T` at an absorbing type does** |
| `(:ok, term) \| :absent` (hand-rolled) | accepted | tagged success |
| `type Found<T> = (:found, T) \| :absent`, used at `Found<term>` | **accepted** | a user-written generic alias works today |
| `Found<Found<int>>` | accepted | the tag keeps "absent" distinct from "present and absent-looking" |

**The author is not left with nothing.** A one-line generic alias already compiles at `term`, nests, and a realistic caller works
(`probes/64/Assigns/assigns.bs`; compiled with the unpatched compiler, called with `#{a => nothing, b => 1}`: `a` → *present, and the atom nothing*, `b` → *present*, `c` → *absent*).
The shape is what `compiler/examples/exemplars/25g-jev-server/triage_crash.bs:21-24` already uses via `:maps.find` (`(:ok, from) => …, :error => …`).
What is missing is a *name in the prelude*, not an expressive capability.

The verifier found one soft spot to know about: a parametric alias `type Bad<T> = T | :nothing` declared and never instantiated is **accepted**; the check
(`bs_check.erl:1111`) runs only on non-parametric aliases, and the refusal fires at the first `Bad<term>`. Not a problem for this decision, but "refused at the declaration" is
not true for parametric aliases.

## Measured cost

`erts_debug:flat_size` (`probes/64/p1_size.erl`): a tagged success `{ok, V}` costs **+3 words on every present value** whatever V is (0 words for the bare atom `nothing`/`absent`).
Honest scope (verifier): `flat_size` counts a literal in full, so the +3 holds for tuples *built at run time*; a literal tuple costs no process-heap words.
The lookup wrapper builds `{found, V}` at run time, so it applies there. Note also this does not make `option<int>` any more expensive, since it stays bare.

## Survey

- **Elixir 1.14** (executed, `p2_elixir_lookup.exs`): `Map.get(m, :a)` is `nil` for a key *present with nil* and for an *absent* key (the bare-value ambiguity this ticket is about);
  `Map.fetch` is `{:ok, nil}` / `:error`. Source: `elixir/lib/elixir/lib/map.ex:299` (`fetch(map, key), do: :maps.find(key, map)`) and `:526` (`get/3` with default `nil`).
- **Erlang** (executed via `:maps.find`): `{ok, V} | error`; `maps.erl:141` declares `find/2` (a BIF stub). Tagged.
- **Gleam 1.12.0** (executed, `probes/64/gl`): `Ok(error)` → `{ok,error}`; a user-defined `Maybe(a)` gives `{some,none}` for `Some(None)` and `none` for `None`, so nesting is distinguishable.
  Caveat: `gleam/option` is a stdlib package I could not fetch (hex unreachable), so `Maybe` is hand-written; only `Result` is the real built-in.
- **Elm**: `Dict.get` returns `Maybe` (always tagged) per the language docs; **not executed** (package registry unreachable), cited from knowledge, not from source I ran.

Every neighbour that has a bare-success form (Elixir `Map.get`) has the ambiguity; every one that tags does not. B# is the only one of these with *both*, which is why it needs a rule at `T = term`.

## Options

### Option 1 — change nothing in the language; teach the idiom

No compiler delta. `LANGUAGE.md` states: at `term`, write `type Found<T> = (:found, T) | :absent` (or the `(:ok, T) | :error` Erlang shape). `Assigns.bs` is the worked program.
*Strongest counterargument:* every project reinvents its own spelling (`Found`, `Lookup`, `Maybe`), and the absorption diagnostic's hint (`(:some, term) | :nothing`, `bs_diag.erl:1949-1975`) already invents a fourth.

### Option 2 — ship one tagged generic in the prelude

```csharp
type found<T> = (:found, T) | :absent        // name is a guess; the prelude's existing names are option / result
```

Compiler delta: one prelude entry; `option<T>` unchanged. Measured: nothing new to build (the alias form compiles today); the cost is a name, a doc section, and
making ticket 48's `Map` operations return it (48 Q8 already chose `(:ok, V) | :absent` at one call site).
*Strongest counterargument:* two ways to say "maybe absent" (`option<T>` bare, `found<T>` tagged) is exactly the pair a beginner cannot choose between, and the ticket's own note warns against
anything that makes `option<int>` more awkward; this one does not, but it leaves the choice to the author with the rule "use `found` when `T` might be `term`".

### Option 3 — make the tagged form the diagnostic's repair

Keep `option<T>`; change the absorption error (`bs_diag.erl:1949`) so that for `option` it prints the exact `found`-style declaration to paste, as the residual-pasteable rule does for clauses.
Compiler delta: a diagnostic variant. Evidence: the verifier confirmed the current hint text `tag it - (:some, term) | :nothing`.
*Strongest counterargument:* it fixes the discoverability only; each author still ends with a differently named private type.

## Recommendation

**Option 2, with Option 3's pasteable repair pointing at it.** The expressiveness question is answered by measurement (a tagged generic already works, nests, and costs a known +3 heap words per
present value), so the only real decision left is the prelude name and shape. Do **not** change `option<T>` itself (the ticket's own warning stands, and `option<int>` remains the cheaper bare form).
Q3 is closed: `result<T, E>` is only affected through `T`.

## Caveats

- `matrix.sh` counts a row "accepted" when the exit code is 0 and the word `error` is absent from output (verifier: loose, but all 11 rows were checked individually and carry the claimed diagnostic).
- The matrix shows what this compiler does under its own subtype rule (`absorbed/2` is `bs_types:is_subtype`, `bs_check.erl:3282`); it does not show the tagged form is *the right* design, which is what the recommendation argues.
- Elm not executed. Local-variable annotations were not tested.

## Verifier (independent re-run; full report `verification/64-verifier.md`)

**CIRCULAR: partial.** Every stored result reproduces byte for byte and the REFUSED rows carry the claimed "absorbed by" diagnostic. The "partial" is the verifier's reading of method, accepted here:
the matrix checks the compiler against its own subtype rule; its accept test is a loose grep (rows individually inspected, none misread); `flat_size` +3 words applies to runtime-built tuples only; Elm was not run;
the Gleam `Maybe` is hand-written. The verifier's own probes found **no** accepted `T | :nothing` where `T` absorbs the tag, and refused the same shape in a record field, parameter, list/map element, function type, tuple element and a foreign signature;
the single soft spot is the uninstantiated parametric alias recorded above.
