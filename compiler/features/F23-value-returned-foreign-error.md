# F23 — A foreign error that arrives as a value

**Status**      **done 2026-08-22** · [ENG-228](https://linear.app/davewil/issue/ENG-228) —
                486 tests, and the first feature that **removes** a diagnostic rather than adding
                one. `file:read_file/1` is declarable; F19's recorded debt sentence is deleted
**Implements**  [ticket 56](../../wayfinder/issues/56-foreign-value-returned-error.md), resolved
                2026-08-22 — and **reverses** [F19](F19-foreign-try-wrapper.md) §2, which is a
                decided rule with a stated rationale, so the reversal is argued rather than assumed
**Unblocks**    most of OTP's IO surface as a declarable FFI target — `file`, `inet`, `gen_tcp`,
                `erl_tar`. It also **defuses the sequencing warning** ticket 52 raised over
                50/52/56: this answer extends the FFI declaration by nothing at all, so there is
                no construct for two sessions to design differently
**Depends on**  F19 (the wrapper and `foreign_error`), F6 (parametric aliases), F11 (the callee
                environment keyed by `{Module, Function, Arity}`)

## Why this one now

The queue of features with a file was empty, and this is the oldest *measured* defect left: F19
shipped a refusal that makes a large and ordinary class of Erlang function undeclarable, and said so
in its own Out of scope. The fix turned out to be a narrowing rather than an extension — one
predicate — which is the cheapest shape a feature can have.

## Measured before this file was written, not assumed

Everything below is `bsc` at `cf32e50`, OTP 28, run against `:file` and `:erl_tar`.

**Four of the ticket's own premises were checked. Two of the surrounding claims were false.**

**1. The refusal is real, and it keys on the resolved type.** `result<binary, atom>` on
`:file.read_file` is refused, and so is a user alias `type Contents = (:ok, binary) | (:error, atom)`
naming the same union — F19 §1's "the trigger is the type, not the spelling" holds through an alias.

**2. The gap is wider than the ticket's title says.** The title names
`(:ok, V) | (:error, R)`, but `erl_tar:extract/2` returns `ok | {error, Reason}` — a **bare** `:ok`
atom, not a tagged pair — and was refused identically. Any value-returned `(:error, R)` with
`R` other than `foreign_error` was undeclarable, whatever the success arm looked like. This is why
the answer could not be "recognise the `(:ok, V)` sibling": that rule would have mis-classified
`erl_tar`.

**3. F19 §1's worked example does not compile.** It offers

```
int | (:error, foreign_error) g(binary)   // wrapped — the same type
```

as proof that a hand-written union gets the wrapper too. `foreign_sig -> type_prim` in
`bs_parser.yrl`, and a union is not a `type_prim`, so this is `syntax error before: '|'`. The
**rule** is sound and `a_hand_written_union_gets_the_wrapper_too_test` pins it — through a
`type Parsed = ...` alias. Only the inline example was wrong. Corrected in F19 §1 and in
`bs_check.erl`'s header comment, and it decides §3 below.

**4. THE FORM THE DIAGNOSTIC RECOMMENDED WAS ITSELF A LIE, SILENTLY.** The refusal told the author
to *"declare it `result<T, foreign_error>`"*. Done over `file:read_file/1`, that compiles, runs, and
returns:

```
$ bsc --src-root . H Read '<<"/etc/hosts">>'   ->  (:ok, "## Host Database ...")
```

The declared type is `binary | (:error, foreign_error)`. The value is a 2-tuple `{ok, Bin}`, which
inhabits **neither arm**. So the refusal did not buy the safety F19 §2 claimed for it — it relocated
the lie from a shape the author chose to a shape the compiler recommended. This is the single
strongest fact behind the reversal, and **it is not fixed by this feature** — see Residual.

## What is being built

**One predicate changes.** `bs_check:wraps/5` became `wraps/2`:

```erlang
wraps(Ret, Env) ->
    Fe = maps:get(foreign_error, Env),
    lists:any(fun(P) -> same_type(P, Fe) end, error_members(Ret)).
```

The wrapper is requested by the **payload** `foreign_error`, not by the **tag** `:error`. Everything
else follows from that.

## The four things this feature decides, all mechanism

### 1. The channel is author knowledge, so it must be author-declared

F19 §2 inferred the channel from the shape of the return type: a type mentioning `(:error, R)`
belongs to a function that throws. For most of OTP that is false, and **the compiler cannot tell** —
it has no Erlang type database, and no amount of looking at `{Module, Function, Arity}` recovers
whether `read_file` raises. The only party who knows is the author.

So the declaration must carry it, and it already can: `foreign_error` is stratum-2, compiler-known,
and names an exception *class*, which nothing else spells. **Writing it is the declaration.** A
payload that is not `foreign_error` is an ordinary union describing an ordinary value.

### 2. Equality, not containment

`same_type/2` and not `is_subtype/2`, and this was measured rather than reasoned:
`result<int, term>` has payload `term`, `foreign_error` is a subtype of `term`, and a containment
test would have silently acquired a wrapper for it. The author who writes `term` names no class and
gets no `try`. Containment would have made the wrapper appear on the strength of a payload that
says nothing.

### 3. No new syntax, and therefore no new construct for 50/52 to collide with

The canonical declaration is an ordinary alias plus an ordinary `using` block:

```csharp illustrative
type Contents = (:ok, binary) | (:error, atom)

using :file {
    Contents read_file(binary p)
}
```

The union goes in the `type` declaration because it cannot go in the `using` block — measurement 3.
That is a **restriction being respected, not a gap being papered over**: the alternative was
widening `foreign_sig -> type_prim` to a full `type_expr`, which is a grammar change owing
`yecc:file/2` before and after, and it buys only inline spelling of something a `type` line already
says more legibly. Ticket 52's warning — that 50, 52 and 56 each extend one construct and risk being
designed apart — is answered by extending it by nothing.

### 4. The two channels compose, which had no form at all before

The algebra keeps `(:error, atom)` and `(:error, foreign_error)` as **separate products** — measured,
because the refusal printed `(:error, atom)` rather than a merged payload. So a function that returns
an error value *and* can throw declares both, and gets the wrapper over the arm that needs it while
the other stays an ordinary value:

```csharp illustrative
type Opened = (:ok, term) | (:error, atom) | (:error, foreign_error)
```

`both_channels_in_one_declaration_test` pins it.

## The reversal, stated as a trade

F19 §2 called refusing *"the reversible direction"*, and it was right that a shipped silence cannot
be retrieved. What it bought is nonetheless given up here, and the honest statement of the trade is:

| | before | after |
|---|---|---|
| `file:read_file/1` as values | **undeclarable** | ordinary union, no wrapper |
| `erl_tar:extract/2` (bare `:ok`) | **undeclarable** | ordinary union, no wrapper |
| both channels at once | **no form at all** | one union, wrapper on one arm |
| `result<int, atom>` over a **throwing** function | refused at the declaration | **compiles; dies at runtime** |
| `result<binary, foreign_error>` over `read_file` | compiles, returns a value inhabiting neither arm | *unchanged* — still does |

The last two rows are the cost. The fourth is the one F19 §2 was protecting, and it is now unguarded;
the fifth shows that the protection was never general, because the *recommended* declaration had the
same defect in the other direction and shipped silently. A wrong channel is now a wrong declaration
like any other, and wrong declarations are the boundary guard's business.

## Residual, with an owner

**A declaration that does not match the foreign function's real behaviour is not caught, in either
direction.** That is ticket 18's boundary guard — `LANGUAGE.md` §11's standing **Owed** paragraph,
which this feature extends to name the second direction explicitly. It is the emitted check that a
foreign value inhabits its declared type, and it catches both `result<int, atom>` over a thrower and
`result<binary, foreign_error>` over `read_file`, because both return a value the declared type does
not contain. Nothing smaller than that guard closes either.

## What this feature REMOVES

The `foreign_error_channel` diagnostic — the `descriptor/2` clause, the `message/1` clause, and both
tests that asserted it — because nothing can mint it any more. F19 anticipated whoever resolved
ticket 56 *editing* that prose; there is no refusal left to word, so it is deleted instead.

`check-diagnostics.sh` already guards this in both directions: a `message/1` clause that no
`descriptor/2` can mint is reported as *"message/1 renders tags descriptor/2 never mints"*. **No new
gate was written for this feature**, because the gate that covers it already existed and was
verified to cover it — leaving a half-deleted diagnostic behind goes red.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F23.1 | `type Contents = (:ok, binary) \| (:error, atom)` on `:file.read_file` | run on `/etc/hosts` | `{ok, Bin}` — an ordinary value | 0 |
| F23.2 | the same, on a path that does not exist | run it | `{error, enoent}` — the error arm, as a value | 0 |
| F23.3 | the same module's emitted abstract code | read it | `Slurp` is a `call`, **not** a `try` | 0 |
| F23.4 | `type Extracted = :ok \| (:error, atom)` — the bare-`:ok` shape | `bsc` it | compiles; no wrapper | 0 |
| F23.5 | `result<int, foreign_error>` beside them in one module | read the abstract code | still a `try` — the control that keeps F23.3 from passing vacuously | 0 |
| F23.6 | `(:ok, term) \| (:error, atom) \| (:error, foreign_error)` | read the abstract code | a `try` — both channels, one declaration | 0 |
| F23.7 | `result<int, atom>` on a foreign signature | `bsc` it | **compiles**, with no wrapper and no diagnostic — F19.7 inverted | 0 |
| F23.8 | a value-returned declaration through the CLI | `bsc` it | rc 0, and neither retired phrase appears | 0 |

| F23.9 | `examples/Foreign` gains the declaration; a probe row names it | `rebar3 eunit`, `bin/spec-check.sh` | green — and the emitted `-spec` for a value-returned union survives Dialyzer | 0 |

**F19.7 is retired and replaced by F23.7.** It asserted the refusal this feature removes.

**F23.9 is F19.11's obligation, met the same way.** A feature whose tests all build temporary
fixtures is green over a corpus that does not contain it: `spec-check.sh` would have passed without
ever emitting a `-spec` for the new shape. `examples/Foreign` therefore gains `Slurp` and `Readable`
beside the wrapped `Parse`, so the two declarations sit in one file and Dialyzer sees both — 16
modules compiled, `examples/Foreign` among them, negative controls still firing.

## Out of scope

- **The boundary guard.** See Residual. Ticket 18, and it is what is owed against the trade above.
- **Widening `foreign_error`.** Ticket 56 explicitly did not ask for it, and a `(:value, T)` member
  would have let the declaration type-check while still telling the author the error arrives by a
  channel it does not.
- **A union inline in a `using` block.** §3. A grammar change owing `yecc:file/2`, buying only a
  second spelling.
- **`raise`.** Still ticket 12 §5, still unbuilt — the *producing* half of the error model.
