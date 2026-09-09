# F39 — `ParseAtom<T>`: a string to a member of a named set

**Status**      **done 2026-09-09** — 19 new tests in `parse_atom_tests`, 713 in
                the suite, up from 695 (one test left `validate_as_tests`, which
                was asserting that this feature did not exist). No new gate:
                `check-language.sh` gained a must-compile block and
                `check-status-claims.sh` section A now actually probes the
                `ParseAtom<T>` row, which it had never done. `./bin/verify.sh`
                green **twice from a clean clone**
**Implements**  [ticket 10](../../wayfinder/issues/10-atoms-in-a-csharp-skin.md)
                §4, the first of the two names it left, with the lowering it
                measured at
                [`prototypes/10d_parseatom_lowering.erl`](../../wayfinder/prototypes/10d_parseatom_lowering.erl)
**Closes**      [ENG-294](https://linear.app/davewil/issue/ENG-294) **in part
                only** — its `ToExistingAtom` half is *owed*, not unbuilt, and
                is untouched here
**Decides**     one thing ticket 10 §4 did not settle: **what the argument may
                be**. See §F39.7 — it is a refusal, and it is the only place
                this feature chose rather than implemented
**Depends on**  F18, which established that an instantiation bracket is a
                codegen obligation and not a call; F9, for `string` as a value;
                F25, whose corrected signature is what makes the residual
                pasteable

## What was there

Ticket 10 §4 decided this name on 2026-08-12 and nothing built it. The compiler
knew it — `bs_check:codegen_obligations/0` has carried `ParseAtom` since F18, so
`<` opened an instantiation bracket after it and the parser produced an
`e_inst` — and then refused it:

```
error: Go uses ParseAtom, which is decided and not built yet
  the instantiation bracket admits it — ticket 28 fixed the set of
  names it may follow — but this compiler generates nothing for it.
```

**That refusal was the failing test**, and flipping it is what this feature is.

## The program

```csharp
type Outcome = :ok | :error
type Parsed = :ok | :error | :nothing

public Parsed Parse(string s)

Parse(s) -> ParseAtom<Outcome>(s)
```

`Parse("ok")` is `:ok`; `Parse("nope")` is `:nothing`.

## What it compiles to

Inline, at the site — there is no generated function, which is the one place
this differs structurally from its sibling. `ValidateAs<T>` builds a traversal
worth sharing between two call sites; a `ParseAtom` body *is* the case
expression, so a per-type function would add a call and save nothing:

```erlang
case S of
    <<"ok">>    -> ok;
    <<"error">> -> error;
    _           -> nothing
end
```

**Every arm returns an atom literal.** That is the whole feature: no
`binary_to_existing_atom`, no call that could consult the atom table, so a
runtime-built string cannot grow it through this path. §F39.2 asserts this by
measuring `erlang:system_info(atom_count)` across a parse that misses, because
no return value can show it.

The second effect is the one ticket 10 §4 called *stronger than expected*: the
members are in **value** position, so they reach the emitted module's atom
chunk by construction. A union whose members appear only in a type has no such
guarantee, which is §6.2's interning gap — parsing a union cures it for that
union.

## The compiler delta

| Site | What |
|---|---|
| `bs_check:type_of/3` | a clause for `{e_inst, _, 'ParseAtom', [T], [Arg]}`, above the catch-all that produced `obligation_unbuilt`. Resolves `T`, admits it only as a finite atom union, checks the argument, and answers `T ∪ :nothing` |
| `bs_check:parse_atom_members/1` | the admission test, exported so the emitter builds its arms from the same list the checker admitted `T` on |
| `bs_check:built_obligations/0` | new. `ValidateAs` and `ParseAtom` |
| `bs_emit:expr/2` | a clause emitting the `case`, and `atom_name_pattern/2` for one arm |
| `bs_diag` | `parse_atom_not_finite` and `parse_atom_arg`; `obligation_unbuilt` now reads its roster from `built_obligations/0` |

`codegen_obligations/0` is **unchanged**. The set of names the bracket admits is
closed by ticket 28, and building one does not alter it.

## F39.1 — the decided case

A member's printed name comes back as that member, and a string naming none of
them is the residual:

```
Parse("ok")    ->  :ok
Parse("error") ->  :error
Parse("zzz")   ->  :nothing
Parse("okay")  ->  :nothing
```

The last line is worth a test of its own. The match is an equality on the whole
binary, not a prefix test — `examples/Frame`'s `Method` needs the opposite and
says so, which is what makes the distinction worth pinning here.

## F39.2 — it does not mint

```erlang
Before = erlang:system_info(atom_count),
?assertEqual(nothing, M:'Parse'(<<"zzz_never_seen_before_xyz">>)),
?assertEqual(Before, erlang:system_info(atom_count)),
?assertError(badarg, binary_to_existing_atom(<<"zzz_never_seen_before_xyz">>, utf8)).
```

The second assertion is the one that would catch a lowering that quietly reached
for the atom table: if the parse had interned the name, the third line would not
raise.

## F39.3 — the name matched is the printed name

`:'Sw.Invoice'` matches `<<"Sw.Invoice">>`. The quotes are source spelling and
never bytes, so `atom_to_binary/2` is the right source for the pattern and
`bs_types:atom_str/1` — which re-adds quoting for display — is not.

## F39.4 — `T` is asked as a whole, not for its atom part

`parse_atom_members/1` matches the type's shape: a finite atom part, and every
other part empty.

```erlang
parse_atom_members(#{atoms := {finite, As}, ints := [], tuples := [],
                     lists := [], maps := [], bins := []}) when As =/= [] ->
```

**The mixed case is why it is written this way.** `:a | int` has a perfectly
finite atom part. An implementation reading only that part would generate a
parse for `:a`, drop the `int` half in silence, and leave the declared type
promising a value the parse can never return. The shape match refuses it, and a
test pins it.

The same match excludes `atom` (cofinite — ticket 10 §4 in as many words: *"a
cofinite `T` is an error at the call"*), `term` (whose tuple and map parts are
`top`, not empty), and a recursive type, whose `mu` node has different keys
entirely.

**The members are the NORMALISED ones.** `type Colour = Warm | :blue` where
`Warm = :red | :orange` parses all three, because the type is resolved before
its parts are read. Nothing here pairs the members as written.

## F39.5 — the construct's shape

One type argument and one value, as for the sibling: `obligation_arity` is
about the shape of the construct and not about a signature anyone wrote, so
`ParseAtom<Outcome, int>(s)` is refused by the same rule that refuses
`ValidateAs<int, atom>(t)`.

**The declared return must admit `:nothing`.** A signature promising only the
union's members is a narrowing, and F25's corrected signature offers
`Outcome | :nothing` beside the refusal.

That test names its diagnostic tag deliberately. While `ParseAtom` was unbuilt
this same source was refused too — as `obligation_unbuilt` — so a test asserting
merely "some error" passed *before the feature existed* and would have gone on
passing if the result type were wrong in any other way.

## F39.6 — the pipe form

`bs_parser.yrl` admits an empty argument list after the bracket precisely so an
obligation can sit in a pipeline, and F14's rewrite fills the argument. It has
to fill it for this obligation and not only for the built sibling, so
`s |> ParseAtom<Outcome>()` is tested as a running program rather than assumed
from the grammar.

## F39.7 — the argument must be a string, and this was a choice

Ticket 10 §4 says nothing about the argument, so this feature decided it: the
argument must be a subtype of `binary`, which admits `string` and `binary` and
refuses everything else.

**The alternative was to accept anything and let it fall to the catch-all.** A
`term` argument would then compile and answer `:nothing`, which reads as *"no
member has that name"* when the truth is *"that was never a name"* — a residual
that is not wrong so much as unable to be right. `term` is the case that will
actually occur, since a value straight off a boundary is a `term` until a clause
head matches it; refusing it says so, and the author writes that head.

It is a refusal, so relaxing it later breaks nothing that compiles today. That
is the only reason it was safe to decide here rather than to raise a ticket.

## F39.8 — the sibling's diagnostic was lying

`obligation_unbuilt`'s prose ended *"ValidateAs<T> is the one that is built"* —
true when F18 wrote it, false the moment this feature landed, and nothing would
have caught it: the sentence is prose inside a message nobody probes for that
claim. It now prints `built_obligations/0`, so the next obligation to ship
cannot leave it stale.

## F39.9 — the gate that had never looked

`check-status-claims.sh` section A probes every row of the standard-environment
ledger through the public CLI: a row marked built whose entry does not resolve
is red, and so is a row marked decided whose entry does.

**`ParseAtom<T>`'s row had never been probed.** Its entry read
`ParseAtom<T>|type|ParseAtom<int>` — an obligation probed as a *parameter type*,
which is the exact mistake that gate's own legend warns about two paragraphs
above the entry list. It was invisible because the two answers coincided: an
obligation never resolves as a type, the row said `decided`, and *"does not
resolve"* is what a decided row wants. The row was green for a reason unrelated
to the truth.

Three things had to change before the ledger could tell the truth about this
feature, and each was silent on its own:

1. the entry's form, `type` → `codegen`, with an expression probe;
2. `probe_entry`, which had **no `codegen` branch** though the legend described
   one — an unknown form falls to `return 1`, so the row would have read as
   refused;
3. the form whitelist in the loop, `type|qualified`, which dropped the row
   **before** the `listed` counter — so `prelude entries probed: 10 of 10` read
   like a full sweep while the row went unexamined.

That third one is `ENG-320`'s and `ENG-325`'s sentence for a third time, and the
lasting fault is named in the script: the form vocabulary lives in three places
that must agree, and a form missing from any one of them fails silently in a
different way.

**Seen to fail.** With the row restored to `decided` and the feature built, the
gate is red and names it — and the count reads `11 of 11` where it read `10 of
10` while blind.

## Still owed

* **`ToExistingAtom`.** Owed, not unbuilt: ticket 10 §5 wrote it `atom |
  :nothing`, and ticket 15 §1 later made that shape an error at the declaration
  — the singleton is absorbed into the cofinite top, so `atom | :nothing` *is*
  `atom` and the failure channel does not survive. Two known-good answers exist
  and neither has been chosen, so it needs a ticket and not an implementation.
  [ENG-294](https://linear.app/davewil/issue/ENG-294) stays open for it.
* **`option<T>` in the printed result.** Ticket 10 §5 names `T | :nothing` as
  `option<T>`, and the corrected signature prints the union longhand. Cosmetic,
  and it belongs to whatever decides alias printing generally rather than to
  this feature.
