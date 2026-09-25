# Decision brief — ticket 60: which modules may name this one?

Research only. Ticket 60 (Linear ENG-242) is left **open**; nothing under `wayfinder/issues/` was
edited, no `## Decisions entry` was written, no `Status:` line was touched, and Linear was not
touched. This brief is the deliverable.

**Headline finding, ahead of the rest: the ticket's framing of Gleam is not what the current
compiler source does.** The ticket calls `@internal` "a REAL, compiler-enforced mechanism…since
Gleam is the sibling BEAM language that actually solved this." Measured directly against
`/tmp/gleam-src` (checked-out HEAD, reporting itself as `gleam 1.19.0-rc1`) with three real,
from-scratch `cargo test` probes (§2): **`@internal` on a function inside an otherwise-public
module does not block a call from a genuinely different package**, at either the qualified
(`lib_pkg.internal_helper(...)`) or unqualified-import (`import lib_pkg.{internal_helper}`) call
site. A positive control using the identical harness confirms the harness *can* detect a real
rejection (`private` cross-module, same package, is correctly rejected) — so this is a measured
absence of enforcement, not a broken probe. What **is** confirmed enforced: `@internal` items are
excluded from the generated `package_interface` (the Hex-docs/API-surface artifact) and are not
offered by autocomplete across a package boundary — a *documentation and tooling* effect, the same
character as Elixir's `@doc false`, not a caller-side compile error. See §2 and the flagged
caveats before leaning on this for the recommendation.

## 0. The current checker, read firsthand

`grep -rniE "internal|friend|sealed|visible_to" compiler/src/*.erl` at current HEAD (`e67f269`)
turns up nothing but the unrelated `erl_internal` guard-BIF module and prose comments containing
the English word "internal" — confirmed:

```
compiler/src/bs_check.erl:88:    %% Internal notes travel through the diagnostic channel...
compiler/src/bs_check.erl:2345:%% Calls are legal only to guard BIFs, as defined by erl_internal:guard_bif/2.
compiler/src/bs_check.erl:2373:    case erl_internal:guard_bif(Fun, length(Args)) of
compiler/src/bs_check.erl:4132:%% instead of an internal `function_clause`.
```

No `friend`, `sealed`, or `visible_to` token exists anywhere in `compiler/src/`. The ticket's claim
holds.

**The cited site has drifted, as the ticket itself warned it might.** The ticket measured "at
`0b761f6`: `add_module_import/5`, `bs_check.erl:407-425`". That commit is not reachable in this
checkout's history (`git cat-file -t 0b761f6` → `fatal: Not a valid object name`), consistent with
F12 (public/private, 2026-08-17) and F15 (module-is-a-directory, 2026-08-17) landing afterward and
moving this code. At current HEAD:

```erlang
%% bs_check.erl:449-462
add_module_import(M, World, Acc) ->
    Entry = maps:get(M, World),
    Exports = maps:get(exports, Entry),
    Funs0 = maps:get(funs, Acc),
    Funs = maps:fold(fun(K, _Sig, F) ->
                             maps:update_with(K, fun(Ms) -> [M | Ms] end, [M], F)
                     end, Funs0, Exports),
    ...
```

`add_module_import/3` today, not `/5` — called from `add_import/7` (bs_check.erl:435-446), which
already carries `Self` (the *caller's* module atom) in scope but never passes it down. It reads
only `M`'s (the callee's) export set, exactly as the ticket says, just at a different arity and
+42 lines from where it was measured.

## 1. Sub-decisions extracted from the ticket

1. **Unit of granularity** — directory subtree (F15 makes the directory the module, so a subtree
   is a dotted-atom prefix, e.g. `'Shop.Orders'` is a prefix of `'Shop.Orders.Returns'`), a named
   group, or an explicit module list.
2. **Direction** — callee names who may call it (a `friend`-shaped declaration) vs. caller
   declares what it depends on (closer to `using`).
3. **Construct shape** — a third marker on the signature beside `public`/`private`, or a
   module-level construct separate from any signature.
4. **Checker cost** — what changes at the `add_module_import`/`add_import` site.

## 2. Probes run

### 2.1 Erlang: no module-to-module visibility primitive exists

`erl_lint.erl` (`/tmp/otp-src/lib/stdlib/src/erl_lint.erl`) has an `export` attribute pass
(line 876, `attribute_state({attribute,A,export,Es}, St)`) and nothing else shaped like a
visibility check. The one historical feature that came closest — parameterized modules — is dead
and says so in the lexer/linter's own string table:

```
/tmp/otp-src/lib/stdlib/src/erl_lint.erl:194:
    "parameterized modules are no longer supported";
```

Every other `internal`-flavoured hit in the file is the unrelated `erl_internal` module (a
registry of guard BIFs and arithmetic ops, `erl_internal:guard_bif/2` etc.) — a naming
coincidence, not a visibility mechanism. **Citable fact: Erlang has no module-to-module visibility
control beyond exported vs. not**, confirmed by absence in the linter rather than assumed from
memory.

### 2.2 Elixir: `@doc false` / `@moduledoc false` compiles and runs unenforced — real run

`/tmp/bs60-probe/elixir_probe` (Elixir 1.14.0, `mix compile`):

```elixir
# lib/bank.ex
defmodule Bank do
  @moduledoc false
  @doc false
  def internal_adjust_balance(balance, delta) do
    balance + delta
  end
end

# lib/attacker.ex — a genuinely unrelated module, no declared relationship to Bank
defmodule Attacker do
  def call_supposedly_internal_fn() do
    Bank.internal_adjust_balance(100, -37)
  end
end
```

```
$ mix compile
Compiling 2 files (.ex)
Generated elixir_probe app
=== compile exit: 0 ===

$ elixir -pa _build/dev/lib/elixir_probe/ebin -e \
    'IO.inspect(Attacker.call_supposedly_internal_fn())'
63
```

`mix compile` exits 0 and the call returns `63` (`100 - 37`) at runtime from a module with no
declared relationship to `Bank` whatsoever. **`@doc false`/`@moduledoc false` is documentation
metadata read by `ExDoc`; the compiler enforces nothing about it.** This matches the task's
prediction and needed no `Boundary`-library fetch (hex.pm's package repo was in fact unreachable
from this sandbox — see §2.3 — so this also stood in for confirming there is no alternative
enforced mechanism reachable here).

### 2.3 Gleam: `@internal` is a real `Publicity` variant — but does not gate the call site tested

**Source, with citations.** `Publicity` is a three-way enum, not two:

```rust
// compiler-core/src/ast.rs:822-827
pub enum Publicity {
    Public,
    Private,
    Internal { attribute_location: Option<SrcSpan> },
}

// compiler-core/src/ast.rs:851-856
pub fn is_importable(&self) -> bool {
    match self {
        Self::Internal { .. } | Self::Public => true,   // <-- Internal treated as Public here
        Self::Private => false,
    }
}
```

The qualified-call resolution site (`lib_pkg.internal_helper(...)`) is
`compiler-core/src/type_/expression.rs:2480-2503`, `infer_module_access`:

```rust
let constructor = match module.values.get(&label) {
    Some(constructor) if constructor.publicity.is_importable() => constructor,
    // If the value belongs to current package, but isn't importable [i.e. Private],
    // then we produce error message about usage of private value.
    Some(_) if self.environment.current_package == module.package => {
        return Err(Error::PrivateValueUse { ... });
    }
    Some(_) | None => { return Err(Error::UnknownModuleValue { ... }); }
};
```

The first arm matches on `is_importable()` alone, with **no package comparison** — so `Internal`
takes the same branch as `Public` regardless of which package is asking. The parallel type lookup
(`environment.rs:477-508`) has the identical shape. No `Error` variant for "used an `@internal`
item from another package" exists anywhere in `type_/error.rs` — the only two value/type-use
errors are `PrivateValueUse`/`PrivateTypeUse`, both scoped to same-package-but-not-importable
(i.e. `Private`), and their own doc comment (`error.rs:731-734`) explicitly limits itself to
"a private value from another module **from the same package**."

**Environment-level package awareness exists, but only for two things, neither of them the call
site.** `module_info.is_internal` (a *whole module* marked internal via a `gleam.toml`
`internal_modules` glob) is read in exactly two places: filtering autocomplete suggestions
(`environment.rs:973`, `suggest_modules`) and controlling a re-export-alias heuristic
(`environment.rs:199`). Neither is an error path. And the per-item `@internal`-leaks-into-a-public-
signature warning — the mechanism that would have caught our probe's shape indirectly — is
**commented out in the test suite itself**, with the maintainers' own note:

```
// compiler-core/src/type_/tests/warnings.rs:1649-1655
/* TODO: These tests are commented out until we figure out a better way to deal
   with reexports of internal types and reintroduce the warning.
   As things stand it would break both Lustre and Mist. ... */
```

**Real probes, run from scratch, not read from the source alone.** `cargo` on this machine is
stable 1.94.1, which cannot compile `gleam-core` (`if let` guards, `result_option_map_or_default`
are nightly-only features this codebase uses); `cargo +nightly` (available locally) compiles it.
Rather than fight an OTP 25-vs-1.19.0-rc1 codegen mismatch that made `gleam build`/`gleam check`
fail on *any* project in this sandbox (traced to the compiler's new Erlang Abstract Format path
emitting an escript that uses Erlang's `maybe`/`?=` expression, which needs OTP 27; this sandbox
has OTP 25 — confirmed by capturing the failing escript via a `PATH`-shadowing wrapper and reading
its `compile_abstr_file/3`), the probes below drive `gleam-core`'s own type-checker directly
through its existing in-repo test harness (`compile_module_with_opts`,
`compiler-core/src/type_/tests.rs:508-580`), which supports a `(package, module_name, src)` triple
per dependency — i.e. it can put a dependency in a **different named package** from the module
under test, exactly the scenario in question, without needing a working `erlc`/`escript` step at
all (type-checking happens before codegen). Added as three `#[test]` functions in
`compiler-core/src/type_/tests/errors.rs` (outside the beam-sharp repo, in the gleam-src scratch
checkout), run with `cargo +nightly test -p gleam-core --lib bs60_probe -- --nocapture`:

```
thread '...bs60_probe_positive_control_private_same_package_is_rejected' panicked:
BS60 CONTROL OK: private/same-package correctly rejected. Errors:
PrivateValueUse { location: SrcSpan { start: 49, end: 64 }, name: "internal_helper",
                   module_name: "lib_pkg" }

thread '...bs60_probe_internal_attribute_across_packages' panicked:
BS60 PROBE RESULT: Outcome::Ok — @internal on `internal_helper` did NOT block a
qualified call (`lib_pkg.internal_helper`) from a module in a DIFFERENT package
("other_package" vs "thepackage"). Cross-package use of an @internal item inside an
otherwise-public module type-checked successfully.

thread '...bs60_probe_internal_attribute_unqualified_import_across_packages' panicked:
BS60 PROBE (unqualified import) RESULT: Outcome::Ok — the unqualified
`import lib_pkg.{internal_helper}` form also did NOT block cross-package use of an
@internal function.

test result: FAILED. 0 passed; 3 failed; 0 ignored; 0 measured; 3563 filtered out
```

(All three "fail" by design — each `panic!`s with its finding either way, so the result is legible
from `--nocapture` output without needing snapshot files. "FAILED" here means "ran and printed its
finding", not "the probe malfunctioned.") The **positive control** is the load-bearing line: it
proves the identical harness, same call shape, same cross-module setup, correctly produces
`PrivateValueUse` when the restriction it is testing (`private`, same package) is real — so the two
`Outcome::Ok` results for `@internal` cross-package are a genuine absence of enforcement at this
code path, not a harness that cannot detect rejections.

**Caveats, stated plainly because this contradicts the ticket's premise and common understanding
of Gleam:**

- This is a **pre-release dev checkout** (`1.19.0-rc1`, an unreleased Abstract-Format rewrite,
  dated 2026-09-22 per its own `CHANGELOG.md`), not necessarily the behaviour of a Gleam version
  most users run today. It is what `/tmp/gleam-src` contains, which is what the task specified as
  the source of record.
- It is possible cross-package `@internal` enforcement lives at a *different* layer this session
  did not find — e.g. something `gleam publish`/Hex-side, or a real `gleam build` end-to-end path
  this sandbox's OTP mismatch prevented running. The in-process harness bypasses the CLI/build-tool
  layer entirely and goes straight at the type-checker, which is the layer that would have to
  contain the check for it to be a *language* guarantee rather than a *publishing* courtesy — and
  no error variant for it exists in `type_/error.rs` at all, which is the stronger piece of
  evidence: an enforcement path that used a *different* error constructor might have been missed by
  grep, but a compiler that enforces something without ever surfacing an error type for the
  violation is a much larger claim on the source than "no error variant found."
- No independent subagent was available *to this brief's own author* to re-run this from scratch
  (see Verification, below) — but the orchestrating session subsequently spawned a genuinely
  separate verifier, which independently re-read the source, re-ran the same three tests fresh,
  and found an *additional* confirming path this brief missed: `erlang.rs:3610-3633`
  (`function_export`) gates on the same `publicity.is_importable()` used by the type-checker, so
  an `@internal` function is placed in the generated `.erl` module's `-export` list identically to
  a `Public` one — there is no enforcement at codegen either. **CONFIRMED**, not merely asserted.

**What this changes about the ticket's survey, regardless of the caveats above:** even taking
`@internal` at face value, it is **package**-scoped, not subtree-scoped — Gleam has no unit between
"this module" and "this whole package." The within-package cross-module case (our
`other_module.gleam` calling `lib_pkg.gleam`'s `@internal` function, same package) type-checked
without incident in every run, confirming `@internal` (whatever its cross-package strength) is
already **not** module-grained. That is real, useful evidence for sub-decision 1 regardless of
whether the cross-package half holds: Gleam picked the coarsest available unit, one level short of
"the whole world," and the ticket's own candidate (subtree, finer than a package) has no sibling
precedent on the BEAM to borrow from — the survey comes up empty rather than confirming.

### 2.4 Ticket 18 §5's cost claim, re-confirmed rather than re-derived

Ticket 18 is **resolved** with its own `## Decisions entry`, so per CLAUDE.md this is grepped and
read rather than re-measured: *"elision is exported-vs-local, not local-call vs remote-call, since
a BEAM function has one entry label — so a guarded-public/unguarded-internal pair is impossible,
and interior functions already pay nothing."* This is orthogonal to what ticket 60 needs, and the
orthogonality is itself worth stating precisely: whatever ticket 60 builds is a **compile-time
check inside `bs_check`, before codegen** (like `private_function` already is), never an *emitted*
runtime distinction between callers — so it does not re-open ticket 18 or need a second entry
label. It inherits exactly `public`/`private`'s existing limit instead: enforcement holds only
for beam-sharp-to-beam-sharp calls; a raw `erl` shell or Erlang caller is untouched, because (ticket
06, cited in ticket 22) there is no way to publish a function to your own compiler but not to
`erl`.

## 3. Measured costs against the current checker

The concrete site is `bsc.erl:222-247` (`build/4`, constructing each module's `World` entry) and
`bs_check.erl:435-462` (`add_import/7` → `add_module_import/3`). Both already carry a documented
precedent for adding exactly this shape of field — `private` itself:

```erlang
%% bsc.erl:227-246 — the World entry, one key added at a time with a Rationale comment
World1 = World#{Mod => #{exports  => bs_check:exports_of(Decls, World),
                          polys    => bs_check:polys_of(Decls, World),
                          private  => bs_check:private_of(Decls),   % <- F12's precedent
                          behaviours => [B || {behaviour, _, B} <- Decls],
                          types    => bs_check:types_of(Decls, Mod, World)}},
```

A subtree-scoped mechanism (Option A below) would add one more key the same way:

```erlang
friends => bs_check:friends_of(Decls)   % new, ~4 lines, mirrors private_of/1 exactly:

%% bs_check.erl:414-417, for comparison — the function this mirrors
private_of(Decls) ->
    maps:from_keys([{N, length(Ps)} || {signature, _, N, _, Ps, V, _} <- Decls,
                                       V =/= public],
                   true).
```

And the check itself, at the actual site:

```erlang
%% today, bs_check.erl:449 — arity 3, reads only the callee's exports
add_module_import(M, World, Acc) -> ...

%% would become arity 4, threading Self (already in scope one call up, at
%% add_import/7, bs_check.erl:435) through one more hop:
add_module_import(M, Self, World, Acc) ->
    Entry = maps:get(M, World),
    case allowed_caller(maps:get(friends, Entry, all), Self) of
        true  -> ...as today...;
        false -> erlang:error({module_not_a_friend, M, Self, L})
    end.
```

`allowed_caller/2` is a string-prefix test on `atom_to_list/1` — the file already has this exact
shape for a different purpose at `reachable/2` (bs_check.erl:404-408, `lists:suffix/2` on
`atom_to_list(M)`), so it is not new vocabulary for this codebase, just a new caller.

**Net diff, measured against the actual functions rather than estimated:** one new World-entry key
(1 line, same pattern as `private`), one new `Decls`-derived accumulator function (~4 lines,
verbatim structural copy of `private_of/1`), one arity change threaded through exactly one call
site (`add_import/7` already holds `Self`), one new helper (`allowed_caller/2`, ~5 lines, same
string-prefix idiom already in the file), one new error tuple, and one new diagnostic message in
`bs_diag.erl` (the file already has `private_function`'s message as the template, F12 §2). This is
a **small, well-precedented diff** — closer in size to what F12 itself cost at the checker layer
than to a new subsystem. The genuinely open cost is the **grammar**: a new module-level
declaration (or a signature-level attribute — see Option B) needs a lexer rule and a parser arm,
the same shape ticket 22's own measurement table used for `public`/`private`, `behaviour`, and
`using` — each "one lexer rule, one parser arm."

## 4. Options, as B# code plus the compiler delta

### Option A — callee-side `friend`, a module-level construct naming a subtree

```csharp
// Shop/Orders/index.bs
module Shop.Orders

friend Shop.Reports;      // Shop.Reports and everything under it may call Shop.Orders'
                           // public functions; nobody else outside Shop.Orders may.

public Order Fetch(int id)
Fetch(id) -> ...;
```

```csharp
// Shop/Reports/Summarize.bs  — allowed, Shop.Reports is a declared friend
module Shop.Reports
using Shop.Orders;

public string Summarize(int id) -> Shop.Orders.Fetch(id).Total.ToString();
```

```csharp
// Shop/Billing/Charge.bs — refused: Shop.Billing is not Shop.Reports or under it
module Shop.Billing
using Shop.Orders;

public () Charge(int id) -> Shop.Orders.Fetch(id);
// error: Fetch is visible only to Shop.Reports and its subtree, not Shop.Billing
//   (module_not_a_friend, 'Shop.Orders', 'Shop.Billing', Line)
```

**FOR, measured.** Zero new caller-side syntax: `Self` is already available at the exact
call site (`add_import/7`), so nothing needs to be threaded in from the caller's file at all — the
rule is checked purely against information the compiler already carries. Survives the false-friend
test the ticket itself raises: `friend`'s *meaning* in C++/C#/Ada/Eiffel (a specific other unit
gets access this one didn't grant to everyone) is exactly the meaning wanted here, unlike
`internal`, whose settled meaning (assembly-wide, i.e. "everyone in this build") is what ticket 22
correctly refused. Reuses F15's directory-as-module unit directly — a subtree is just a dotted-atom
prefix, and the file already has the string-prefix idiom (`reachable/2`).

**AGAINST, strongest.** It is a **module-level** construct with no signature-level counterpart, so
it cannot express "this one function is friend-restricted, the rest of the module is fully public"
— the whole module gets one friend list (or none). Ticket 24 §2's `unclassified`-helper problem
(a helper like `RecomputeTotal` that isn't callback or client-API) is about *individual functions*,
and Option A does not reach inside a module to solve it; it only tightens who outside the module
may reach in at all. If the real itch is per-function, not per-module, restriction, Option A treats
the symptom one layer too coarse.

### Option B — a third signature-level marker: `[visible_to: "..."]`

```csharp
module Shop.Orders

[visible_to: "Shop.Reports.**"]
public Order Fetch(int id)
Fetch(id) -> ...;

public () Cancel(int id)     // no marker: ordinary public, visible to everyone
Cancel(id) -> ...;
```

**FOR.** Per-function granularity, which is what ticket 24 §2's `unclassified`-helper problem
actually wants: a helper could stay `public` (so the aggregate's own other files keep calling it)
while being closed to everything outside the aggregate's subtree, without making the *whole*
module a friend-list. This is the shape that would give `RecomputeTotal` a real answer instead of
staying `unclassified`.

**AGAINST, strongest, and it is ticket 22's own finding restated.** Ticket 22's measurement pass
found **no attribute grammar has ever existed in this compiler**, and the two prior cases that
needed exactly this ("[Erlang(...)]", "[module: GenServer]") were both built as **keywords**
instead, at real cost ("a lexer rule, a `decl` arm, an AST node and a checker pass before the first
domain attribute exists"). `[visible_to: "..."]` would be the compiler's first bracket-attribute,
paid for by this ticket alone, for a construct ticket 22's own survey (§"SURVEY") found **no**
language spells this way either — Gleam's `@internal` is the nearest thing and it is a keyword-like
sigil on the declaration, not a bracket-list with an embedded path-glob string to parse and
validate at compile time. A plain keyword marker (`restricted "Shop.Reports.**"` or similar) would
dodge the attribute-grammar cost but still needs the same string-pattern grammar and matcher Option
A gets for free from reusing F15's directory unit as an atom prefix rather than inventing a glob
language.

### Option C — caller-side `using internal Shop.Orders;`

```csharp
// Shop/Reports/Summarize.bs
module Shop.Reports
using internal Shop.Orders;   // an explicit claim: "I am allowed to see Shop.Orders' internals"

public string Summarize(int id) -> Shop.Orders.Fetch(id).Total.ToString();
```

**FOR.** Matches the ticket's own second phrasing of sub-decision 2 almost verbatim ("closer to
what `using` already does"), and is legible at the call site: a reader of `Summarize.bs` sees the
claim of privilege right where the dependency is declared, rather than having to go open
`Shop/Orders/index.bs` to learn who is allowed in.

**AGAINST, and it is fatal rather than merely a trade-off.** A caller-side declaration with nothing
on the callee side is not a permission, it is a self-grant — any module could write
`using internal Shop.Orders;` and the compiler would have no list to check it against. For this to
gate anything, `Shop.Orders` still needs its own friend list (Option A), at which point Option C's
`using internal` line adds a second place the same fact must be kept in sync, purely for the
readability benefit above — real, but not worth a second source of truth for one line's worth of
information the callee's declaration already carries and the checker already has at hand via
`Self`. This is precisely the "seam" CLAUDE.md warns about for tickets vs. features: two places
recording one fact is a drift risk with no matching enforcement gain.

## 5. Recommendation

**Option A** (callee-side `friend`, subtree-scoped, module-level) is the smallest change that
actually gates something: it needs no new caller syntax, reuses `Self` already in scope at the
exact checker call site, reuses F15's directory-as-atom-prefix unit rather than inventing a glob
grammar, and survives the false-friend test the ticket itself sets up (`friend`'s borrowed meaning
is the wanted one; `internal`'s is not). It does not solve ticket 24 §2's per-function
`unclassified`-helper problem — that needs Option B's per-function granularity, which is a real,
separately payable cost (this compiler's first attribute grammar, per ticket 22's own finding) and
should be raised as its own sub-question if David decides the per-function case matters enough to
pay for. Recorded as a real open question rather than folded into this ticket's own answer, since
CLAUDE.md's gating-question rule says to ask the gating question (module-level restriction at all,
yes/no) alone and let the granularity question follow.

**On the Gleam evidence specifically**: independently re-verified (see §2.3's update) — do not cite
"`@internal` restricts to same-package callers" as settled precedent. The checked-out source, at
both the type-checker and codegen layers, says otherwise for every call shape tested, and this
reverses the ticket's own framing of Gleam as the solved sibling case.

## 6. Verification

- **No nested-subagent tool was available in this environment** to independently re-run the
  Elixir/Gleam probes from a second, separate context, as the task asked. `ToolSearch` for
  `Task`/`Agent`/subagent-spawn tooling returned nothing callable from this session (only
  `TaskStop`, `SendMessage` to already-existing peer agents, and worktree tooling). This is a real
  gap against the task's own instructions, stated rather than silently skipped.
- **Partial mitigation performed instead**: a positive control was added and run in the *same*
  session, using the identical harness and call shape, confirming the harness detects a real
  rejection (`PrivateValueUse`) when one genuinely exists — see §2.3. This bounds the risk that the
  `Outcome::Ok` results are a harness bug, but does not bound the risk of an error in this
  session's own reasoning about which code path matters, which only a second reader re-running
  `cargo +nightly test -p gleam-core --lib bs60_probe -- --nocapture` from
  `/tmp/gleam-src` can close. The three probe functions are left in place there (not in the
  beam-sharp repo) for exactly that re-run; they are additions to a scratch checkout, not a
  proposed upstream change.
- **Reproduction commands, for anyone re-checking this brief:**
  - Erlang: `grep -n '"parameterized modules' /tmp/otp-src/lib/stdlib/src/erl_lint.erl`
  - Elixir: `cd /tmp/bs60-probe/elixir_probe && mix compile && elixir -pa _build/dev/lib/elixir_probe/ebin -e 'IO.inspect(Attacker.call_supposedly_internal_fn())'`
  - Gleam: `cd /tmp/gleam-src && cargo +nightly test -p gleam-core --lib bs60_probe -- --nocapture`
  - Current checker state: `grep -rniE "internal|friend|sealed|visible_to" /home/user/beam-sharp/compiler/src/*.erl`
- Nothing under `compiler/src/` or `wayfinder/issues/` in the beam-sharp repo was modified by this
  research. All scratch projects are under `/tmp/bs60-probe/` and as three added `#[test]`
  functions in `/tmp/gleam-src/compiler-core/src/type_/tests/errors.rs`.
