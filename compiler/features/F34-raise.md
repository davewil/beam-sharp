# F34 — `raise`: the producing half of the error model

**Status**      **done 2026-09-05** — 11 new tests, 633 in the suite, up from
                622. No new gate: `check-language.sh` already compiles every
                `csharp` block and already judges a `diagnoses:` claim, so the
                demonstration and the refusal are checked by the gate that was
                there
**Implements**  [ticket 12](../../wayfinder/issues/12-totality-vs-let-it-crash.md) §5,
                resolved 2026-08-12, and
                [ticket 15](../../wayfinder/issues/15-error-model.md) §3, which
                12 §5 deferred the payload to. 12 §5 settled the spelling and
                that it is a keyword, 15 §3 settled that it takes any term, and
                this file builds them
**Decides**     **one thing, and it is named here rather than left in the
                grammar**: `raise` sits at the LOWEST precedence, so its reason
                extends to the end of the expression. No ticket asked the
                question. It is a build-level call on the reading that no
                alternative survives scrutiny — a reason is whatever expression
                the author wrote, and a raise that stopped early would need a
                bracket in the common case. It is measured (below) and pinned by
                two tests whose wrong parse is a different raised value, not a
                compile error. If David wants it decided elsewhere, this is the
                line to overrule
**Closes**      [ENG-293](https://linear.app/davewil/issue/ENG-293)
**Depends on**  F5 (the body check, which is where a clause's type meets its
                declared return), and the set-theoretic algebra's empty type,
                which has been in `bs_types` since the beginning under the name
                this feature finally lets a program reach
**Leaves**      `none` **still unwritable in a signature**
                ([ENG-328](https://linear.app/davewil/issue/ENG-328)). 12 §4
                decided the bottom is first-class and `builtin/1` does not have
                it, so `public none Reject(term r)` is refused today. `raise`
                does not need it — see *What the bottom did not need* below —
                so it is a separate unbuilt decision rather than a hole in this
                one

## What shipped

`raise <expr>` is an expression. It lexes as a keyword, parses at the lowest
precedence in the table, types as `none`, and emits `erlang:error/1`.

```csharp
public int Unwrap(Fetched r)
Unwrap((:error, e)) -> raise e
Unwrap(v)           -> v
```

`Unwrap` returns `int` and means it. That sentence is the feature: the raising
clause contributes nothing to the type the clauses justify, so F25 never asks
the author to widen `int` to admit a crash, and the signature stays true.

Five sites, all small: a lexer rule, one production plus one precedence line, a
`type_of/3` clause, a `guard_diags/2` refusal with its prose, and an `expr/2`
clause in the emitter.

### The class is the decision

`raise` lowers to `erlang:error/1` and to nothing else, because 12 §5 chose
Elixir's word over C#'s `throw` **on semantics rather than on taste**: the BEAM
already uses `throw` for the catchable non-local-return class, so emitting a
`throw` would make a crash the language calls fatal recoverable by any
enclosing wrapper — including the one F19 writes. `a_raise_produces_the_error_class_test`
catches all three classes and compares the tag, rather than asserting the reason
alone, because a `throw` carrying the same reason would satisfy a reason-only
assertion and violate the decision.

### The lowest precedence, measured

`raise` sits at 40, below `=` at 50 and below every operator. Every operator's
precedence therefore exceeds it and yecc shifts rather than reducing, so
`raise (:bad, n + 1)` needs no bracket and `raise x switch { … }` raises the
switch's value instead of switching on a crash. There is no reading in which a
raise should stop early: its operand is a reason, and a reason is whatever the
author wrote.

`yecc:file/2` with `{report, true}` was run on the grammar **before and after**,
per the rule that conflicts are measured and not inferred: zero conflicts both
times. A quiet `rebar3` build is not that evidence and was not accepted as it.

**Zero conflicts is not the same claim as the right precedence**, though, and
the first draft of this feature stopped at it — which would have shipped an
untested surface decision. Two tests now pin the reading through behaviour, each
built so the wrong parse compiles and raises something else: `raise n + 1` must
raise `6` from `5` and not `5` (the tighter parse never reaches the addition),
and `raise a switch { … }` must raise the arm's value and not the subject.

## What the bottom did not need

**No special case anywhere in the return check.** `is_subtype(A, B)` is
`is_none(subtract(A, B))`, and subtracting anything from the empty set leaves it
empty, so `none <: T` holds for every `T` by the algebra that was already there.
A build that had added a rule saying "a raising clause always satisfies the
return type" would have been writing down a theorem the type system proves.

**The machinery was already in use, under another name.** `bs_check:reported/0`
— the type handed back after a diagnostic so the author gets one error and not a
cascade — is `bs_types:none()`. The suppression path has always relied on the
bottom passing every containment check silently. `type_of/3`'s `e_raise` clause
calls `bs_types:none()` directly rather than borrowing `reported/0`, because the
two mean different things: there the bottom hides a consequence, here it is the
honest type of an expression that does not return.

## What the build found that the plan did not have

### Two grammar-enumerating walks fell through in silence, and one emitted a name the author never wrote

`bs_emit:used_vars/2` and `bs_check:expr_vars/1` both enumerate the expression
grammar clause by clause and end in a catch-all returning nothing. A node they
do not name is not a crash and not a warning — it is simply invisible.

The emitter's is the one that bites. `used_vars/2` decides whether a head binder
is emitted as `E` or as `_E`, so with `e_raise` unlisted,
`Unwrap((:error, e)) -> raise e` emitted `_E` in the head and `E` in the body:

    variable 'E' is unbound
    %    4| Unwrap((:error, e)) -> raise e

An `erlc` diagnostic, naming a variable the author never typed, against the
author's own `.bs` file. The checker's `expr_vars/1` is the quieter half: a
misspelled name inside a reason would have been accepted without a word.

The guard refusal had the mirror problem, in the same file. `wildcards/1` and
`switches/1` were already two copies of one walk, and `wildcards/1` carried a
note saying a *third* copy would be the wrong answer — so `raises/1` was written
and then deleted in favour of `nodes_of(Tag, Expr)`, which all three refusals
now call. It works because every node carries its line second, and that is
stated where the function is, so a node shape that broke it has somewhere to be
noticed.

**Both files already carry a comment warning about exactly this**, written when
`e_valve` hit it — *"this walk enumerates the grammar and falls through to `[]`,
so without this clause a misspelled name inside a valve stage would be accepted
in silence"* — and the emitter's `e_switch` clause records the same failure in
the same words. `e_raise` is the third node to walk into it. The trap is that
adding an expression form is not one edit in `bs_parser.yrl` and one in
`bs_check`: it is those plus every generic-looking walk that is not generic.

The two escript profiles hid it for one cycle. `rebar3 eunit` rebuilds
`_build/test/bin/bsc` and the gates read `_build/default/bin/bsc`, so the suite
went green on the fix while `check-language.sh` still failed on the same
program, compiled by a stale escript.

### §7 had no `not-yet` block to promote

`ENG-293` expected one and named promoting it as the failing test. There is
none: §7's `not-yet` blocks are the prelude aliases (`option`, `result`, then
`foreign_error`), held back because the prelude namespace is lowercase while
`type` declares a PascalCase name — nothing to do with `raise`, whose only §7
line was prose. So the failing test is a **new** gated block, and the issue was
corrected rather than followed.

### A guard is a place the word parses and must not run

A guard shares the whole expression grammar, so `when raise :boom` parses. Left
alone it reaches the author as `illegal guard expression` from `erlc` —
`erlang:error/1` is not a guard BIF — against a file they did not write. That is
the fault `switch_in_guard` already exists to prevent, so `raise_in_guard` is
built as its twin: the same walk shape, stopping at the raise rather than
descending, because a reason nested inside a refused raise is not a second
mistake. Its message names the body as the repair, since a guard chooses a
clause and a clause that should crash is one whose body is the raise.

## The editor knows the word

`check-tokens.sh` went red on the lexer rule alone and named the two grammars
missing it, which is the gate working: `raise` is now `keyword.control.exception`
in the VS Code TextMate grammar and its own `bsException` group in the Neovim
syntax, so it colours as the word that leaves without returning rather than as
another declaration keyword.

That gate does not read the tree-sitter grammar; `check-corpus.sh` does, and it
parses `compiler/examples` — so the `raise_expression` rule is gated only
because this feature also ships an example. It did not, at first: the rule was
verified by hand against a fixture and the feature file said gating it "would
mean an example, and an example is a larger change than this unit."

That was wrong on the standard rather than on the cost. `compiler/features/README.md`
makes an example the price of a shipped surface form — *"a capability cannot
ship with nothing to look at"* — and `corpus_tests:demonstrated_surface/0` is
where the price is paid. `examples/Escalate/escalate.bs` pays it, adds the row
`{"a deliberate crash", "raise "}`, and closes the tree-sitter gap in the same
move, since the corpus is what that grammar is checked against.

Its header invocations were **run before being written down**, which is the
habit ENG-308 exists to enforce: the flagship record example's own "here is how
you run it" line does not run. Both of these do. So does the claim in its
comments that deleting the `raise` makes the compiler hand back
`public int | atom Unwrap(Fetched f)` — that string was copied from the
compiler's output, not composed.

## What is demonstrated where

The reference gains a §7 subsection: a compiled block for the shape above and a
`<!-- diagnoses: raise_in_guard -->` block for the refusal. §7 is deliberately
**outside** the audition packet — `build-packet.py` copies sections 2, 3 and 5
— so this closes the specification's gap without touching the clean-room
artifact, which is the placement `check-switch-diagnostics.sh` documents as the
correct one for a rule that is not part of the switch slice.
