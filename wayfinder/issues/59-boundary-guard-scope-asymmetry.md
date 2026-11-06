# 59 — The boundary guard now applies two rules with different scopes

Status: open — [ENG-241](https://linear.app/davewil/issue/ENG-241)
Raised by: [F24](../../compiler/features/F24-boundary-kind.md), 2026-08-23, while building ticket 58
Blocks: nothing. Both rules are individually defensible; what is not defensible is that one
function applies them at different scopes with nothing saying why
Type: `wayfinder:decision`

## The measurement

`bs_emit:boundary_guards/5` emits two boundary guards, and they disagree about who gets one:

| guard | scope | authority |
|---|---|---|
| the record TAG test (F3, ticket 26 §1) | every function, **including private** | none — nothing consults `is_public/1` |
| the int KIND test (F24, ticket 58) | **exported only** | [ticket 18](18-boundary-defence.md) §4, explicitly |

Ticket 46 measured the first and declined to own it:

> **`boundary_guards/4` is not scoped to exported functions,** though its comment says
> *"unconditional on an exported record parameter"*. Nothing consults `is_public/1`; measured, a
> private `Inner(Order o)` receives the tag test. That is the record guard's business against
> 18 §4, not this ticket's.

F24 inherited the asymmetry **deliberately rather than silently** — it scoped its own test per
18 §4 and left the tag test exactly as it found it — but the result is one function applying two
rules, one of which contradicts the section the other cites.

## The question

**Is the record tag test on a private function a defect against 18 §4, or is 18 §4's "exported"
narrower than the tag test needs?**

There is a real argument on each side, which is what makes this a decision rather than a defect —
unlike ticket 58, where 18 had already answered and the compiler simply did not know.

**It is a defect.** 18 §4 is unambiguous: C *"looks at the exported function's own clause heads and
body, and no further"*. A private function's every call site is a checked beam-sharp call site, so
site 1 has already rejected a wrong tag and the test is dead weight on every call. 18's own cost
section measured that a non-exported function has the test **elided entirely**, and called that
*"the shape C wanted anyway"*.

**It is not.** 26 §1's argument for the unconditional tag is that *no body ever checks which record
a map claims to be* — a body projects fields, so it cannot object. That is a claim about the BODY
and says nothing about who calls it. And a forged record can reach a private function by being
passed through an exported one, which 18 §4's function-local analysis is explicitly designed **not**
to trace: *"a value handed to another function counts as unchecked, and is guarded"*. Read that way
the private tag test is 18 §4 working, not failing — the callee guards because the caller's analysis
stopped at its own boundary.

## What this owes

1. **Which scope is right, stated once, for both guards.** The cost of getting it wrong is
   asymmetric in the usual direction: too narrow is a silent hole, too wide is measurable and loud.
2. **Whether "exported" is even the right discriminator.** 18 §1's cost section found the BEAM's
   own discriminator is *exported vs local-only*, not local-call vs remote-call — one entry label
   serves both — so an exported function already pays its guard on calls from inside its own
   module. That much is priced. The open half is whether a private function should pay nothing.
3. **The cost if the answer widens rather than narrows.** 26a measured the tag test at **+14 bytes,
   flat in field count**, and 18 measured `is_integer` at +3–5 bytes with call time below its
   ±0.09 ns/call resolution. Neither is a reason on its own; both bound the argument.

## Cross-references

- **[Ticket 18](18-boundary-defence.md) §4** — function-local, exported, and the sentence about a
  value handed on counting as unchecked. §1's cost section for the BEAM discriminator.
- **[Ticket 46](46-refined-parameter-at-the-boundary.md)** — measured the asymmetry and named it as
  the record guard's business.
- **[Ticket 58](58-refined-int-admits-a-float.md)** / [F24](../../compiler/features/F24-boundary-kind.md)
  — inherited it rather than fixing it, and says so in §3.
- **Ticket 26 §1** — the two-tier record guard and the *"no body ever checks"* argument.

## Round 1 — 2026-11-06

Reproduced on `HEAD` `631b597` with a `bsc` built from `compiler/src` (OTP 28.5, the pinned
version). Probe and raw output: [research/59-boundary-guard-scope.md](../research/59-boundary-guard-scope.md).
The asymmetry the ticket describes still stands; `bs_emit:guard_one/7` (line 264 ff.) is unchanged
in shape.

### The program

```
module Guard

record Order { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

public int Public(Order o)
Public(Order o) -> Inner(o)

public int PublicByte(Octet n)
PublicByte(int n) -> InnerByte(n)

int Inner(Order o)
Inner(Order o) -> o.Total

int InnerByte(Octet n)
InnerByte(int n) -> n
```

It compiles. What it emits today:

| function | exported | boundary guard emitted |
|---|---|---|
| `Public(Order o)` | yes | record tag: head matches `#{'Kind' := 'Guard.Order'} = O` |
| `Inner(Order o)` | **no** | record tag: **the same** `#{'Kind' := 'Guard.Order'} = O` |
| `PublicByte(Octet n)` | yes | `is_integer(N) andalso N >= 0 andalso N =< 255` |
| `InnerByte(Octet n)` | **no** | none (only the clause's own `is_integer(N)` for the `int` head) |

So `Inner` is guarded and `InnerByte` is not, though both are private and both are reached only
from checked B# call sites. Ticket 18 §4 says the guard is on the exported function.

### The question

**Does the record tag test follow ticket 18 §4 and apply to exported functions only?**

### What each answer does to the program

**Yes — exported only.** `Public` and `PublicByte` emit exactly what they emit now. `Inner`
becomes `Inner(O) -> erlang:map_get('Total', O)` with no `'Kind'` match in its head. The program
compiles either way; the change is in the emitted head of `Inner` alone.
The compiler must gain: `guard_one/7`'s record branch (`{ok, Tag}`) gains the `Public` test the
`none when Public` branch already has; a new test asserting a private function's head carries no
`'Kind'` match (none exists today; `boundary_kind_tests.erl:88` covers only the int guard). Nothing else: no symbol-table entry, no new pass.

**No — every function.** The record tag stays on `Inner`, and by the same reasoning the int, float
and range guards move to every function: `InnerByte` gains
`N >= 0 andalso N =< 255`. The program compiles; `InnerByte` grows by the range test on every
call. The compiler must gain: remove `when Public` from the `none ->` branch of `guard_one/7` and
drop the `Public` argument from `boundary_guards/6`; rewrite `a_private_function_is_not_guarded_test`
(`boundary_kind_tests.erl:88`) and `a_private_function_carries_no_range_guard_test`
(`boundary_range_tests.erl:122`) to assert the opposite; and ticket 18 §4 / F24 §3 / F37.5 each
get the "exported" sentence amended, which a ticket must decide before a feature builds it.

### Recommended answer

Yes, exported only: a private function is reached only from call sites the checker has already
typed, so its guard re-tests a fact site 1 has proved, and 18 §4 already chose function-local
analysis for exactly that reason.
