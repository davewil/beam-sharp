# Independent verification of brief 62 (the outbound ABI)

Toolchain: PATH = /tmp/tools/otp27/bin, /tmp/tools, then system. `erl`/`erlc` = OTP 27; `elixir`/`mix` = /usr/bin Elixir 1.14.0 (built for OTP 24) running on the OTP27 erl. No mismatch problems seen. Scratch work is under this directory (`alias/`, `edge/`, `gl*/`, `mf/`).

## Re-runs of p1-p6
p1, p4, p5, p6 re-run in fresh shells: identical to the captured .out (rerun_p*.txt). p2 and p3 were not re-run verbatim; p2's claims were re-probed independently (below), p3 was regenerated independently.

## Central claim: `:Shop."New"(1)` works, `:Shop.New(1)` does not — CONFIRMED
On a beam bsc emitted from B# (Shop59, exports 'SumAll'/1 'Direct'/1), Elixir 1.14:
- `:Shop59.SumAll([])` SyntaxError; `:Shop59."SumAll"([])` -> 0; `Kernel.apply` -> 0.
- `alias :Shop59, as: S; S."SumAll"([])` OK (unquoted `S.SumAll(` fails); lowercase alias `as: S`, variable module `m = :Shop59; m."SumAll"([])`, `[] |> :Shop59."SumAll"()`, `Enum.map(xs, &:Shop59."SumAll"/1)` all OK. `&:Shop59.SumAll/1` fails.
- `defdelegate sum_all(x), to: :Shop59, as: :SumAll` OK.
- `Code.format_string!` and `mix format` round-trip the quoted form unchanged (idempotent; format does not "fix" it into the unquoted form, which would break); a formatted file ran.
- `Module.concat([:Shop59])` yields `:"Elixir.Shop59"`, NOT `:Shop59` (not a way in; irrelevant to the claim). `Shop59."SumAll"` without colon looks up `Elixir.Shop59` -> UndefinedFunctionError. Brief's "no prefix" point stands.
- `import :Shop59` cannot bring PascalCase functions in at all (`import :Shop59, only: [{:SumAll, 1}]` then `SumAll(x)` is a SyntaxError). The brief's p1 row "import ... works (for a lowercase name)" is only the hand-written lowercase alias; the brief's Option A text ("survives neither import") is correct and now measured on a bsc beam.
Verdict: true. The ticket's "cannot call" is wrong; the quoting tax is real.

## LANGUAGE.md §12 (lines 3115-3126) — brief's wording slightly unfair
Actual text: "This costs Erlang nothing and costs Elixir its call syntax:" then
```
:Shop.New(1)               # SyntaxError: Elixir reads .Capitalized as an alias
apply(:Shop, :New, [1])    # the way in
```
"No module naming scheme changes this — the blocker is the *function* name".
Fair: it implies apply/3 is the only route ("the way in"), which is false. Unfair: the brief puts `apply/3 is the way in` in quotation marks joined with an ellipsis as if one sentence; it is two separate lines. Say "§12 shows `apply(:Shop, :New, [1])  # the way in` and says Elixir loses 'its call syntax'". Ticket 62 line 112 says the same ("Elixir callers use apply/3").

## Gleam claims
- PascalCase function: hard syntax error ("I'm expecting a lowercase name here"), also with `@external` on it. Brief says "refused": true.
- PascalCase module file name: only a *warning* ("Invalid module name") and the file is silently not built (no .beam). Brief's "refuses ... module name" is loosely right; say "skips with a warning".
- `@external(erlang, "Shop", "New")` RUNS: `shop:foreign_new(3)` returned `{new,3}` from a PascalCase Erlang export (also p2.out). True.
- Constructor vs function: functions keep their snake_case names; constructors become snake_case atoms (`Plain` -> `plain`).
- **Acronym finding not in the brief:** Gleam turns `HTTPGet(url)` into `h_t_t_p_get`, `IPv4Addr` into `i_pv4_addr`, `OAuthTok` into `o_auth_tok`. The brief quotes only Elixir's `Macro.underscore` (`HTTPGet` -> `http_get`) and treats it as "the" derivation; the one neighbour that actually derives names does it differently, which sharpens the "rule becomes ABI" point.
- Ticket 10 §7 (line 335) said PascalCase->snake_case about *constructors*; the brief's reading ("no precedent for emitting two exports") is fair.

## Alias cost (independent generator, gen.py)
Same shape as p3 (2-clause map-match, debug_info) but my own generator: base/alias/dup bytes
N=10 2516/3216(+27.8%)/4228; N=50 9020/12504(+38.7%)/17704; N=200 34712/48200(+38.9%)/70116.
p3: +26/+36/+38%. Differences are 0-1.7 points (my clauses span two lines, so line annotations differ). Reproduced.

**Real bsc output** (alias/alias.escript, my own prototype: take bsc's real `.abstr` forms, add one lowercase export and a forwarding clause per public function, compile with debug_info; bs_emit.erl not touched). Note the forwarding clauses carry no -spec, whereas bsc emits a -spec for every function, so these are lower bounds:
- int-param functions: N=10 +23.2%, 50 +35.4%, 200 +40.2%
- record-param functions: N=10 +20.9%, 50 +31.7%, 200 +36.2%
- duplicate body: +33%..+96%.
Verdict: the brief's "+26% to +38%" is right in magnitude for B# modules but the honest range for real bsc forms is about +21% to +40%, and it grows with module size. Direction/size claim holds; p3 is circular only in that it is hand-written, and the bias is small (<=5 points).

## Circularity hunt
- **p5 regex undercounts.** Its pattern misses signatures whose return type has `:` / `|` (e.g. `public :ok | :error Pick(int n)`). Union with clause-head extraction gives 163 names, not 158; missed: Answered, HandleInfo, Pick, Rule, Steps (and `Direction` is matched but is not a function head). `bsc --api` lists 66 public names, 65 of them already in p5 (the 66th is Pick). Collisions over the 163-name union: still 0. So "all 158 distinct function names" should read "the 163 found by a wider extraction; 158 by the original regex (misses 5)". The conclusion (0 corpus collisions) survives.
- **"No collision with user names" (Option B) is overbroad.** (a) p6's lowercase refusal is general: B# rejects *every* lowercase function name in declaration position (`public int get(int x)` alone is a syntax error; a private `get` too; `_get` too), not just the Get/get pair. So a user cannot write a colliding lowercase name. True. (b) But collisions between derived names are real and p5 only tested the corpus: `Get` and `GET` both compile in one module and both derive `get`; `GetX` and `Get_x` both derive `get_x` (edge/L6, L7, compiled). (c) Generated/reserved Erlang names: a B# `public int ModuleInfo()` compiles today (edge/Edge) but its alias `module_info/0` would be "function module_info/0 already defined". Behaviour callbacks already export snake_case (`HandleCall` -> `handle_call`, `Init` -> `init`, 4 corpus names), so aliasing them would duplicate or redefine an existing export and needs a skip rule. Erlang auto-imported BIF names (Length, Now, Self, Size, Band) derive to legal exports (compiled fine as exports with forwarding clauses; local unqualified calls would be the hazard, none are generated).
- p3 call-time numbers: samples overlap on a busy box; only "no visible difference" is supportable, which is what the brief says.

## Corrections needed
1. §12 characterisation: quote the two real lines; do not splice them into one quotation.
2. Gleam row: add that the only deriving behaviour in Gleam splits acronyms letter by letter (`HTTPGet` -> `h_t_t_p_get`); module-name case is a warning plus a skipped file, function-name case is a hard syntax error.
3. "158 distinct names": correct to 163 (regex misses `:`-typed signatures); collisions still 0.
4. Option B "no collision with user names": limit to "no collision with user-written lowercase names (B# forbids them)"; add the derived-name collisions (`Get`/`GET`, `GetX`/`Get_x`) and the reserved names (`ModuleInfo` -> module_info/0, behaviour callbacks `HandleCall`, `Init`) as spec work.
5. Cost range: "+21% to +40% measured on real bsc forms (hand-written p3: +26..+38%)", forwarding clauses unspec'd so a floor.
6. Caveat that the alias prototype is hand-written Erlang can now be softened: a forms-level prototype on real bsc output agrees; bs_emit.erl itself was still not changed.
7. Add to Option A: `import :Shop` cannot expose PascalCase names at all, measured on a bsc beam; `mix format` preserves the quoted form.
