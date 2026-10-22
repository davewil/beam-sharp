# Decision brief: ticket 65 (ENG-255), reserved names

Prepared for David. Nothing is resolved, committed, or written to Linear. Probes: `artifacts/probes/65/NN-*/run.sh`; each has an `output.txt` with its raw output from this session.

Toolchain actually used: Erlang/OTP 25 (erts 13.2.2.5), rebar3 3.19.0, Elixir 1.14.0 (compiled with OTP 24), Gleam 1.5.0, Elm 0.19.3. The repo's tickets cite OTP 28.5, Elixir 1.19.5/1.20 and gleam 1.18.1. Every cross-version difference is flagged where it matters. Repo HEAD `c3d50b9`.

## 1. Ticket summary, and what has changed since it was raised

The ticket (raised 2026-08-25) asks what governs reserved names beyond `Map`, with three options: reserve per module, a namespace users cannot reach, or user names win. It names a gating question, "is the standard environment closed by intent?", and says to put that first.

**Three of its premises are stale or false against the tree at HEAD.**

- **"B# reserves no name today" is false.** All of the following are measured in probe 05, section A:
  - `module Map`, `module List`, `module Term` and `module Float` are each refused (`bs_check.erl:1701`, `reserved_module_name` at `:244-257`).
  - The protocol name `Enumerable` is refused (`:247`).
  - `ValidationError`, `Down` and `Exit` cannot be declared as records or types (`:1832-1840`).
  - `ToExistingAtom` cannot be declared as a function (`:3486-3492`).
  - 20 lexer words are already burned as identifiers (probe 06, M6). A parameter named `raise`, `fn`, `and`, `or`, `where`, `with`, `switch`, `var` or `record` is a syntax error (probe 05, A8).
  - Growth so far: `Map` on 2026-08-25 (48), `List` and `Term` on 2026-09-03 (67), `Float` by F51 on 2026-09-16 (`LANGUAGE.md:584`). That is 1 to 4 names in 22 days, with no policy ticket resolved.
- **The gating question is already answered, in one sense.**
  - 67 Q1: "the set is closed by construction, and nothing a user writes can accrete into it" (`67-stdlib-shape-as-a-principle.md:149-152`, `:270-271`).
  - 96 Q6 (`96-standard-environment-breadth.md:207-209`, `:252-253`): "what the standard environment qualifies is reserved, and nothing else". It says this "answers ticket 65's first question by rule".
  - Both tickets leave "its reservation policy its own to decide" (67 `:229`, `:388`).
- **The ticket's closedness argument is not safe as written.** Its line is "a closed, compiler-owned set does not have the problem at all". Closed to users is not closed in size. 96 (breadth is now in scope) queues about 11 more qualifiers: `Enum`, `String`, `Int`, `Binary`, `Process`, `GenServer`, `Supervisor`, `Logger`, `System`, `Task`, `Agent` (probe 06, M5, all "free today"). Erlang's own built-in type set is also closed and compiler-owned, and it is the set that forced OTP's shadowing machinery (probe 02, section 3.2). Closed to users does not prevent collision with a user's existing name.

**Other tickets that are waiting on 65, and their status here**

| Ticket | What it hands to 65 | Measured status |
|---|---|---|
| 63 (`:405-407`) | `not` was left a legal identifier, "reserving names is ticket 65". | Still legal (probe 05, A9: `Go(not) when not > 100`, exit 0). |
| 87 (`:168`) | whether `bs@` is a reserved prefix in emitted exports | Unspellable from user syntax. The lexer rejects `@` ("illegal characters"), so there is nothing to reserve (probe 05, A10; see section 7 for the scratch-build artefact in that output). |
| 98 (`:45`) | `Task` as a reserved qualifier | Unreserved today (probe 05, A4: `module Task` compiles and runs). |

## 2. Sub-decisions and gating order

1. **D0, the gating question, asked alone: is the standard environment closed by intent?**
   - Evidence says closed to users (67) but unbounded in size (96).
   - So D0 should be read as "closed to user accretion: yes, grows only by ticket". That does not by itself remove D1.
2. **D1, the live policy question (section 5): when the compiler later takes a name a program already uses, what happens to that program?** Options 1, 2 and 3 below answer this.
3. **D2, only if D1 is "refuse": is a name reserved when its ticket is decided, or when it is built?**
   - Precedent: `Map` was reserved before it had any operation, because "reserving it later would have meant taking it away from a program that had already used it" (`LANGUAGE.md:2160-2163`).
   - Live instances: `Binary` (93, open) and `Task` (98, open).
4. **D3, which follows D1 and takes one sentence each.**
   - Keywords and identifiers (`not`): a word is burned at the feature that adds it; `not` stays legal.
   - `bs@`: unspellable, so no reservation.
   - Option (d) from the ticket (a namespace users cannot reach): see section 5, "Foreclosed".

## 3. Probes

All raw output is in `artifacts/probes/65/<dir>/output.txt`. Excerpts below are verbatim.

### 3.1 Probe 01, Elixir: `defmodule Map` (`01-elixir-defmodule-map/run.sh`)

Elixir 1.14.0 on OTP 25. The ticket's measurement was on 1.19.5.

The warning reproduces (stderr; the script header printed `elixir 1.14.0 otp 25` first):

```
warning: redefining module Map (current version loaded from /usr/lib/elixir/bin/../lib/elixir/ebin/Elixir.Map.beam)
  shadow.exs:6
```

The user module clobbers the standard one, with only the user's own `get/2` left:

```
Map.get(%{a: 1}, :a)           => :mine_not_stdlibs
function_exported?(Map, put, 3) => false
function_exported?(Map, update!, 3) => false
```

Stdlib breakage on 1.14:

```
Map.new([a: 1])                          RAISED UndefinedFunctionError: function Map.new/1 is undefined or private
Kernel.update_in(%{a: 1}, [:a], & &1)    RAISED UndefinedFunctionError: function Map.get_and_update/3 is undefined or private
URI.parse("http://x/y")                  ok %URI{scheme: :mine_not_stdlibs, authority: :mine_not_stdlibs, userinfo: :mine_not_stdlibs, host: :mine_not_stdlibs, port: :mine_not_stdlibs, path: :mine_not_stdlibs, query: :mine_not_stdlibs, fragment: :mine_not_stdlibs}
```

Then the compiler's own checker dies:

```
** (EXIT from #PID<0.96.0>) an exception was raised:
    ** (UndefinedFunctionError) function Map.new/1 is undefined or private
        (elixir 1.14.0) Map.new([])
        (elixir 1.14.0) lib/module/parallel_checker.ex:373: Module.ParallelChecker.cache_from_module_map/2
```

Compiled mode (`elixirc map.ex`) printed the same crash and `elixirc exit=1`.

What this shows:
- The ticket's claim holds in kind on 1.14: warning, clobber, then Elixir's own compile-time checker crashes.
- The crash site differs. On 1.14 it is `Module.ParallelChecker` calling `Map.new/1`. The ticket's `Module.Types.local_handler` / `Map.update!/3` on 1.19.5 cannot be reproduced here, so I cannot confirm that exact line.
- New finding: stdlib calls can succeed with wrong values. `URI.parse` returned all fields as `:mine_not_stdlibs`. Elixir's failure mode is a silent wrong answer as well as a crash. This sharpens the ticket's "catastrophic rather than merely confusing".

### 3.2 Probe 02, Erlang: built-in type and BIF shadowing (`02-erlang-builtin-type-shadow/run.sh`)

OTP 25 only. The ticket cites OTP 26 and I could not measure that.

A user type with a built-in's name is refused:

```
shadow_integer.erl:3:2: type integer() is a builtin type; it cannot be redefined
shadow_map.erl:3:2: type map() is a builtin type; it cannot be redefined
```

Per-module opt-out, `-compile(no_auto_import_types)`: it compiles, with only an unused warning.

```
shadow_noauto.erl:4:2: Warning: type integer() is unused
erlc exit=0
```

The user's definition is unused, which is consistent with `integer()` in the spec still meaning the built-in. I did not run dialyzer, so that part is inference.

A function with a BIF's name is an error at the call site, and the opt-out is per name:

```
shadow_bif.erl:4:9: ambiguous call of overridden pre R14 auto-imported BIF length/1
 - use erlang:length/1 or "-compile({no_auto_import,[length/1]})." to resolve name clash
...
shadow_bif_optout:f([a,b]) = mine
```

The linter's machinery for newly introduced built-in types, with an empty list on 25:
- `erl_lint.erl:2985-2998` (`/usr/lib/erlang/lib/stdlib-4.3.1.3/src/erl_lint.erl`): a newly introduced built-in is a warning, an old one is an error.
- `:3187`: `is_newly_introduced_builtin_type({Name, _}) when is_atom(Name) -> false.`
- `:439-441`: the message is "its (re)definition is allowed only until the next release".

What this shows:
- Erlang on 25 is not "user names win". The built-in wins and the user opts out explicitly, per module or per name.
- Erlang has a one-release grace mechanism for a new built-in (a warning before it becomes an error). That is Option 3's precedent.
- "OTP 26 permitted shadowing" is unmeasurable here. Not confirmed, not contradicted.

### 3.3 Probe 03, Gleam 1.5.0 (`03-gleam-shadow/run.sh`)

Dependency-free projects only, because Hex is blocked. gleam_stdlib is not available, so nothing here is about `gleam/list` itself. The ticket's version is 1.18.1, so differences are possible.

User types and constructors named like prelude ones are accepted:
```
V1 user type Result            -> Compiled in 0.40s exit=0
V2 user constructor Ok         -> exit=0
V3 user type List              -> exit=0
```

`Bool` fails at the BEAM level:
```
V4: type bool() is a builtin type; it cannot be redefined
    ... -type bool() :: true | false | 'maybe'.     exit=1
```

Module names:
```
V5 (src/gleam.gleam)  error: Reserved module name  The module name `gleam` is reserved.
V6 (src/list.gleam)   Compiled  exit=0
V9 (src/lists.gleam)  error: Erlang module name collision
                      The module `.../lists.gleam` compiles to an Erlang module named `lists`.
                      By default Erlang includes a module with the same name so if we were to
                      compile and load your module it would overwrite the Erlang one...
V10 (src/string.gleam) the same error
```

The binary's own strings include `is a reserved module name in Gleam.`, `is a standard library module in Erlang.` and `has the reserved prefix 'gleam_'`.

What this shows:
- Gleam is a hybrid by namespace. Prelude types and constructors are user-wins. Module names are refused, both `gleam` and anything that would clobber an Erlang stdlib module.
- Gleam needs the second rule because its modules compile to lowercase atoms. B# modules compile to PascalCase atoms (probe 05, D), so that BEAM-level clash does not arise.

### 3.4 Probe 04, Elm 0.19.3 (`04-elm-shadow/run.sh`)

UNABLE TO ANSWER. `elm make` needs elm/core from package.elm-lang.org. Raw output:

```
ProxyConnectException "package.elm-lang.org" 443 (Status {statusCode = 403, statusMessage = "Forbidden"})
exit=1
```

The ticket's Elm row ("default imports small, very unlikely to overlap") is a documentation quote that I could not check. Elm's compiler source is not installed. I did not run it.

### 3.5 Probe 05, the B# reference compiler (`05-bsharp-reserved-surface/run.sh`)

**Build.** `bsc` does not build on OTP 25 with plain `rebar3 escriptize`. The script builds a scratch copy and applies `otp25-and-probe-switches.patch` to the copy only. The patch does three OTP 25 things:
- It drops `{xrl_opts,[{error_location,column}]}` from `rebar.config`.
- In `bs_lexer.xrl` it replaces `TokenLoc` with `{TokenLine, 1}` and adds a stub `adjust_col/3`. All columns read 1.
- In `bs_run.erl` it changes `~kp` to `~p`.

It also adds two probe-only environment switches in `bs_check.erl`, both off by default:
- `BS_PROBE_EXTRA=Logger` adds names to `reserved_qualifiers()`.
- `BS_PROBE_USER_WINS=1` makes a reserved name that the current module declares or `using`s not reserved in that module.

**Control.** The repo's own gate, `compiler/bin/check-reserved-qualifiers.sh`, run against the scratch build with both switches off, passes:

```
ok         List/Term/Map/Float are reserved qualifiers, lowered to OTP at the site and refused when shadowed; Map's rows lower to maps
gate exit=0
```

**Section A, what is taken today.**

```
module Map / List / Term / Float  -> error: `Map` is a reserved qualifier, so no module may be called it   exit=1
module Shop.List                  -> 1   exit=0
module Enumerable                 -> error: `Enumerable` is a protocol, so no module may be called it      exit=1
module Logger / String / Process / Task / Supervisor -> 2   exit=0   (all five accepted)
record ValidationError / Down / Exit -> "<N> is a compiler-known type and cannot be redeclared"   exit=1
record Timeout                    -> 1   exit=0   (ticket 88 amended 14 s6: Timeout is the atom :timeout, not a type)
record Map + record List + record Task + fn ValidateAs + fn Map in one module -> 101  exit=0
fn ToExistingAtom                 -> error: ToExistingAtom is a compiler-known function and cannot be declared
record result                     -> error: syntax error before: result   (lowercase is unspellable)
```

The lines above are condensed from `output.txt`; the quoted error texts are verbatim, and each refusal carries the repo's own multi-line explanation. The em dashes in that text print as `\x{2014}`. That is an escript encoding artefact on OTP 25, not a finding.

**Section A+, the other namespaces.**
- A parameter named `raise`, `fn`, `and`, `or`, `where`, `with`, `switch`, `var` or `record` gives `syntax error before: <word>`.
- A parameter named `not` is accepted (exit 0).

**Section B, growth under "refuse".** With `BS_PROBE_EXTRA=Logger`, a program that compiles today (a user `Logger` plus a `Caller` that does `using Logger` and calls `Logger.Info`) stops compiling.

Before (B0): `Caller -> user's Logger.Info`, output `2`, exit 0.

After (B1), `Caller` with unchanged source:

```
.../Logger/Logger.bs:1:1: error: `Logger` is a reserved qualifier, so no module may be called it
  `Logger.` names operations the compiler knows and inlines at the site;
  ...`Shop.Logger` is still legal...
exit=1
```

**Section C, "user names win" (an approximation, see the limits in section 7).**

```
module Map (user, has Get)             -> 2000   exit=0   (refused without the switch)
UsesMap  (using Map; Map.Get(2))       -> 2000   exit=0   (the user's)
Std      (no import; List.Sum([2,2]))  -> 4      exit=0   (still the standard's)
UsesList (using user List; List.Sum)   -> error: Go calls List.Sum/1, which nothing declares   exit=1
```

**Section D, the BEAM.**

```
out: Logger.beam
loaded logger and 'Logger' together; their file names differ only by case: logger.beam vs Logger.beam
OTP logger:info/1 exported? true; user Logger:Info/1 exported? true
```

### 3.6 Probe 06, measurements (`06-measure-sites/run.sh`)

See section 4.

## 4. Measurements

Command in each case: `artifacts/probes/65/06-measure-sites/run.sh` (greps over the tree at HEAD `c3d50b9`).

- **Sites that read the reserved set.**
  - `reserved_qualifiers()` appears 3 times in `bs_check.erl` (the definition at `:1701` and two readers, `:247` and `:3244`) and 2 times in `bs_emit.erl` (`:1050`, `:2102`), none in `bs_diag.erl`. That is 4 readers.
  - The refusal is `reserved_module_name` at `bs_check.erl:244-257`, called at `:342`. Its diagnostic is `bs_diag.erl:675` and `:1385`.
  - The call-site collision check is `bs_check.erl:3243-3250`.
  - So Option 1 touches 1 line to add a name. The policy-change sites are about 6 in total.
- **Modules in the tree.** 163 `.bs` files, 115 distinct module names, 106 of them single-segment, so whole-name refusal is the common shape. None has a roster word as its name or last segment today. One record is named `Task` (`Signalbox`); a record is not a module name, so it is not affected (probe 05, A6).
- **Rewrite bill for a different spelling of the already-built qualifiers** (the ticket's option (d), as a rewrite):
  - `List.X(`: 12 in `.bs`, 116 in `compiler/test`, 83 in docs, features and specs = 211.
  - `Map.X(`: 14 + 56 + 12 = 82.
  - `Term.X(`: 0 + 6 + 2 = 8.
  - `Float.X(`: 3 + 8 + 14 = 25.
  - Total 326 occurrences, plus every row of ticket 96's roster that has not been written yet. The patterns match `Q.X(` anywhere, so `Shop.Map.Get(` is included; treat the figures as upper bounds.
- **Names that would burn on arrival (96 roster):** 11 (`Enum`, `String`, `Int`, `Binary`, `Process`, `GenServer`, `Supervisor`, `Logger`, `System`, `Task`, `Agent`), all unreserved today.
- **Doc drift found on the way:** `LANGUAGE.md:2160` says "Three names are reserved: `List`, `Map` and `Term`", but `bs_check.erl:1701` reserves four (`Float` too).
- **Not measured:** BEAM term size and compile time. The policies differ only at the checker's name lookup, so these would not discriminate.

## 5. Options

The decision (D1): a program written today that is valid. Release N+1 gives the standard environment a name the program already uses. What happens?

The program, as measured in probe 05, section B:

```csharp
// src/Logger/Logger.bs
module Logger
public int Info(int n)
Info(n) -> n + 1

// src/Caller/Caller.bs
module Caller
using Logger
public int Go(int n)
Go(n) -> Logger.Info(n)       // compiles today, prints 2
```

### Option 1. Refuse, at the release that adds the name. Built; 96 Q6 reads this way.

After the release, both files are refused (probe 05, B1, quoted in 3.5). The fix is `module Shop.Logger`, which is legal because only the whole name is taken.

- **Compiler work:** append `'Logger'` to `reserved_qualifiers()` at `bs_check.erl:1701`, plus the table rows. The four reader sites follow with no change.
- **Evidence:** the repo's gate passes on this exact behaviour (probe 05, E). Gleam also refuses module names (probe 03, V5/V9/V10), as does Erlang for BIF ambiguity (probe 02).
- **Strongest counterargument:** this breaks every existing program that uses the name, at the release that adds it, and the only escape is renaming.
  - The 96 roster includes words an application would use: `Process`, `Task`, `Logger`, `System`, `Supervisor`, `Agent`.
  - The ticket's own table shows Haskell, Rust and Erlang all moved away from it after shipping.
  - Mitigation: the reserved set grows only by decision of a ticket, so it is not a surprise.
  - The cost today is zero: no module in the tree uses a roster word (probe 06, M2).

### Option 2. User names win where the user's module is in scope (Scala's rule).

The program above compiles unchanged after the release and means the user's `Logger`. The mirror case, with the switch on:

```csharp
module List   public int Zero(int n) ...         // the user's own List, no Sum
module UsesList  using List
Go(n) -> List.Sum([n, n])      // error: Go calls List.Sum/1, which nothing declares
```

The standard operation is unreachable in that module, and the message names no `List.Sum` and no standard (probe 05, C1). Another module that does not `using` the user's `List` still gets the standard `List.Sum` (result 4).

- **Compiler work:**
  - Remove `reserved_module_name` (`bs_check.erl:244-257`, `:342`) and its diagnostics (`bs_diag.erl:675`, `:1385`).
  - Resolve each qualified call against the module's imports before the reserved table (`bs_check.erl:3243-3250`).
  - Record the resolution on the AST. The emitter re-derives from the name alone today (`bs_emit.erl:1050`, `:2102`), so it would otherwise emit the wrong call. My prototype dodged this with a per-module global, which a real build cannot.
  - A spelling to reach a shadowed standard operation. B# has none, and this is the ticket's own "needs a spelling B# has not got".
- **Evidence:**
  - Scala's rule and the Gleam prelude-types result (probe 03, V1-V3).
  - There is no BEAM-level clash that would force a refusal, unlike Gleam: PascalCase atoms sit beside OTP's lowercase ones (probe 05, D).
  - Elixir's silent wrong answers (probe 01, `URI.parse`) do not apply, because B# lowers to OTP calls (`lists:`, `maps:`) and never calls a B# module for a standard operation.
- **Strongest counterargument:** `List.Sum` stops meaning one thing. A reader, the LSP, the tree-sitter grammar and the clean-room implementer each need the import graph to know what `List.` is. 67 Q6 rejected option (ii), "the reserved qualifier wins, silently", as Elixir's clobber reversed. This is its mirror. It also conflicts with the standing least-surprise constraint cited in 48's Q9.

### Option 3. Refuse, but one release late: the name warns first.

Release N (name in a `reserved_soon()` list):

```
warning: `Logger` will be a reserved qualifier in the next release; rename the module
```

Release N+1 is Option 1.

- **Compiler work:** a second list. A declaration-level warning channel is also needed, and it does not exist. The declared pass reports only by `erlang:error` (`bs_check.erl:256` and siblings); warnings exist only for body diagnostics (`bs_diag.erl:707`, `{warning,…}`). Not prototyped.
- **Evidence:** it is Erlang's mechanism, `new_builtin_type` (`erl_lint.erl:2985-2998`, `:439-441`). It is present in OTP 25 with an empty list (`:3187`), so I have not seen it fire.
- **Strongest counterargument:**
  - It is machinery for users who do not exist yet, in a project with no release cadence or version marker (grep: no "edition" anywhere in the tickets except 65 itself).
  - A grace period is calendar time, not code. OCaml's `Pervasives` to `Stdlib` took 4.5 years (research §6).
  - The failure it prevents (a real program broken by a new reservation) has not occurred once. The repo's own rule for new checks is to wait for a second occurrence.

### Foreclosed, not offered as a program: option (d), a namespace users cannot reach

- It already exists for types: the lowercase namespace (`bs_check.erl:1350`; probe 05, A7, where `record result` is a syntax error).
- For qualifiers, 48, 67 and 96 chose PascalCase. Switching now rewrites 326 call sites plus the whole 96 roster (section 4).
- Nothing in the survey argues for that cost.

## 6. Recommendation

**Option 1, ratified as the policy, with D2 answered "reserved when the ticket that decides the qualifier resolves, not when built".**

1. **D0.** Say it plainly: closed to user accretion, grown by ticket. That is what 67 and 96 already decided. This resolves the ticket's gating question without the "so reserving is free" step, which the evidence does not support. Reserving is cheap today only because no program uses a roster word.
2. **D1.** Option 1 is the built behaviour, and the repo's own gate passes on it. It is the least surprising of the three (a reader always knows `List.` is the standard's). The cost it names, breaking an existing program at a release, is one rename. Pre-release B# has no user base for it to hurt. Option 2 trades that rename for an ambiguous `List.` for ever. Option 3 adds machinery with no user to benefit.
3. **D2.** Follow the `Map` precedent: add a qualifier to `reserved_qualifiers()` in the commit that resolves its ticket (93 `Binary`, 98 `Task`). Do not reserve the 96 roster speculatively. 96 itself says its roster is "not a round of questions". Each of those words should be argued by its own ticket. This costs one line each.
4. **D3.** Close in one sentence each:
   - Keywords burn an identifier at the feature that adds them (20 already); `not` stays legal (63).
   - `bs@` needs no reservation, as the lexer rejects `@` (87).
   - Option (d) is foreclosed by section 4.
5. **One correction owed whichever option is chosen:** `LANGUAGE.md:2160` should say four names, not three.

**Re-open trigger:** the first time a user program, not an example, collides with a reserved name and the rename costs it something real. Then Option 3 is the answer, not Option 2.

## 7. Limits and what I could not verify

- **bsc claims are from a patched scratch copy, not the repo build.**
  - It runs on OTP 25 with columns forced to 1.
  - Probe 05, A10 (`bs@x`) crashed in `bs_diag:message/1` with a `lex_error` that has no column. That is the exact failure the repo's `rebar.config` comment describes for a lex error without a column, and it is an artefact of my patch. The refusal reason ("illegal characters \"@\"") is still visible in the crash output.
  - `stray_semicolon` also crashed `bs_diag:message/1` in an earlier trial. I did not determine whether that is also a patch artefact or a repo bug.
  - `compiler/examples/Signalbox` fails to compile in the scratch build with an `erl_anno` error, on both the unpatched-logic baseline and the switches, so it was not used.
  - Reserved-name logic is the repo's with both switches off, and the repo's own gate passes on it (probe 05, E).
- **Option 2's behaviour is an approximation:** a per-module `persistent_term` switch, not a resolved-AST design. A full build would need the AST change described in Option 2.
- **Option 3 was not prototyped.** Its warning channel does not exist in the declared pass.
- **Version gaps:**
  - Elixir 1.14 against the ticket's 1.19.5: the crash site differs, the 1.19.5 `Module.Types` line is unreproducible.
  - OTP 25 against the ticket's OTP 26: the claim that 26 permits shadowing a built-in type is neither confirmed nor refuted.
  - Gleam 1.5.0 against 1.18.1: a hybrid-by-namespace result here may have moved.
  - The repo cites OTP 28.5 for `bsc`; I could only run 25.
- **Not verified from primary sources:** the Rust, Scala, Haskell and Elm rows of the ticket's five-language table. They come from `wayfinder/research/prelude-the-word-across-languages.md` and I did not re-check them. Elm could not be run at all (probe 04). Elixir's own source is not installed (only ebin); I quoted its docs chunk indirectly via probe 01's behaviour and `Code.fetch_docs`, not `file:line`.
- **Case-insensitive filesystems:** `Logger.beam` and OTP's `logger.beam` differ only by case (probe 05, D). On Linux they coexist. On macOS or Windows file systems I could not test that, and it would matter for the 96 roster (`String`, `Binary`, `Supervisor`, `Logger` all have lowercase OTP modules). Treat as an untested risk, not a finding.
- I did not edit the ticket, touch Linear, or commit anything. Only `artifacts/` was written.

## 8. Probe index

| # | Dir | Run |
|---|---|---|
| 01 | `artifacts/probes/65/01-elixir-defmodule-map` | `./run.sh` (needs `elixir`) |
| 02 | `artifacts/probes/65/02-erlang-builtin-type-shadow` | `./run.sh` (needs `erlc`) |
| 03 | `artifacts/probes/65/03-gleam-shadow` | `./run.sh` (set `GLEAM=` if not at `/tmp/claude-0/gleamx/gleam`) |
| 04 | `artifacts/probes/65/04-elm-shadow` | `./run.sh` (will fail here; needs network) |
| 05 | `artifacts/probes/65/05-bsharp-reserved-surface` | `./run.sh` (builds a scratch bsc; applies `otp25-and-probe-switches.patch`) |
| 06 | `artifacts/probes/65/06-measure-sites` | `./run.sh` (grep only) |

## Verification errata (independent verifier, see 65-verification.md)

All 6 probes reproduced; Option 1 recommendation stands. Corrections that supersede the text above:
- Erlang row (probe 02) is wrong as a generalisation: only the pre-R14 BIF `length/1` was probed. For post-R14 `floor/1` a local definition compiles with a warning and the user's function wins. Erlang has a warn-then-user-wins path, which is evidence for Options 2 and 3.
- Option 1's cost is understated: after renaming to `Shop.Logger`, callers writing `Logger.Info` are still refused (67 Q6 iii); every call site must become `Shop.Logger.Info(...)`. Untested in probe 05.
- Section C ("user names win") is a by-construction simulation (persistent_term removes the name from the reserved set). The Option 3 warning-channel claim and the re-open trigger have no probe.
- Gleam's module-name refusal is a BEAM atom-collision rule: weak support for Option 1. Rust/Scala/Haskell/Elm table rows unverified.
