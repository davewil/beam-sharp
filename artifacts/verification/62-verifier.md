# Ticket 62 verification (independent re-run)

All work in /tmp/claude-0/verify62/. Nothing under the repo changed except this file.
F was rebuilt with `artifacts/build-variant.sh artifacts/patches/62-F-snake-aliases.diff /tmp/claude-0/verify62/F`.
Unpatched `$BSC` = compiler/_build/default/bin/bsc (existed).

## Step 1: re-run of stored probes

| probe | what I ran | result | vs stored |
|---|---|---|---|
| p1 (Elixir 1.14, PATH=/usr/bin:/bin, beam built by p0_mk.erl) | `:Shop.New(1)`, `:"BSharp.Shop".New(1)`, `:"Shop.Reports".Totals(1)`, `:"Elixir.Shop".New(1)` | all four SYNTAX_ERROR ("unexpected ( after alias New. Function names ... start with lowercase") | no divergence. `:Shop."New"(1)` -> {:ok,1}; `:Shop.new(1)`, apply/3, Kernel.apply, :erlang.apply all work |
| p3 (Elixir 1.19.5, REAL bsc beam of examples/Shop, unpatched) | as stored | identical to p3_result.txt: export list same, `:Shop.New(1)` SYNTAX_ERROR, `:Shop."New"(1)` and apply work, `:Shop.new(1)` UndefinedFunctionError, record-in -> :order, `%URI{}` -> FunctionClauseError | none |
| p3 against F beam | same script | adds exports amount/band/bump/new/pay/squared/total/which; `:Shop.new(1)` now returns the record | extra, consistent |
| p5 (F beam) | as stored | `:Shop.new(1)` -> %{Kind: :"Shop.Order", Id: 1, Total: 0}; `:Shop.which(record)` -> :order; alias == PascalCase: true | none. On unpatched beam p5 raises UndefinedFunctionError (so p5 does depend on F, correctly) |
| p4 | `python3 artifacts/probes/62/p4_derive_corpus.py` from repo root | byte-identical to p4_result.txt (114 names, 0 disagreement, 0 digits, 0 collisions; flagged HandleCall/HandleCast/Init) | none. NOTE: it uses repo-relative globs, so it scans nothing unless run from the repo root |
| Gleam (own project /tmp/claude-0/verify62/gl, gleam 1.12.0) | `pub type Shape { RoundThing(Int) UnitSquare }`, `pub fn make_it`, `@external(erlang,"Shop","New") pub fn shop_new`; `gleam build` | emitted: `-type shape() :: {round_thing, integer()} | unit_square.`, `make_it() -> {round_thing, 1}.`, `shop_new(A) -> 'Shop':'New'(A).`; build OK; running g:call() against the unpatched Shop beam returned `#{'Kind' => 'Shop.Order','Total' => 0,'Id' => 1}` | matches p2. `pub fn New(...)` in Gleam -> "Syntax error ... I'm expecting a lowercase name here. Hint: Variable and module names start with a lowercase letter". So Gleam never emits PascalCase function names; it downcases only variants/types |
| Gleam -> F alias | `@external(erlang,"Shop","new")` against F beam | runs, same map | new (not stored) |

Ticket 10 line 335: "Fieldless variants compile to atoms, variants with fields to tagged tuples, PascalCase to snake_case. The constructor *is* the declaration site." That is about constructors, so the claim (b) reading is correct.

Beam sizes, Shop (beam_lib chunks, bytes), unpatched -> F:

| | unpatched | F | delta |
|---|---|---|---|
| file | 2516 | 2916 | +400 (+15.9%) |
| Code | 398 | 529 | +131 (+33%) |
| ExpT | 136 | 232 | +96 (+71%) |
| AtU8 | 173 | 218 | +45 |
| Dbgi | 1302 | 1431 | +129 |
| .abstr | 13020 | 14535 | +11.6% |

All 22 non-exemplar example dirs: total beam bytes 54380 -> 58752 (+8.0%). Per-module: Signalbox 3180 -> 3460, Frame 2952 -> 3160. All 22 compile with F (exit 0) and unpatched.

## Step 2: critical read of F and the probes

Patch logic: for each public fn whose emitted name equals its written name (`N =:= element(2,F)`, so callback-renamed ones are skipped), snake-case it, and emit `snake(A1..An) -> 'Pascal'(A1..An)`; skip if `{snake,arity}` is already in the module's emitted names (`Own`).

- Arity > 1: correct. Base64Encode/3 -> base64_encode/3 works from Elixir (my probe). Signalbox Backoff/1 and Backoff/2 both get aliases (`backoff,backoff` in the diff of exports).
- GenServer: Counter (examples/Counter, declares GenServer) compiles with F and exports are IDENTICAL to unpatched: `handle_call/3, handle_cast/2, init/1, bs@type_atoms/0`; no `HandleCall`/`handle_call` double. `gen_server:start(Counter,5,[])` then `call({add,3})` -> 8, `call(get)` -> 8. So F skips callback-renamed functions. Only the "N =:= element(2,F)" test does this; it is not the reason for safety against collisions (see below).
- Non-callback helper in a GenServer module: my q4 module (Init/1, HandleCall/3, HandleCast/2 callbacks + `public Init(a,b)` helper + `public Handle_call(a,b,c)`): F exports `init/1` (callback), `init/2` (alias of helper Init/2, harmless) and `Handle_call/3`, but NO alias for `Handle_call/3`: the `Own` guard sees callback `handle_call/3` and silently drops the alias. No error, no warning; the alias set is therefore silently not total. Callback behaviour correct; documentation of the omission absent.
- Reserved word `band`: F emits `band/1` (Wire and Shop both export `'band'`). Elixir `:Shop.band(1)` works. Erlang: `'Probe':band(1)` is a SYNTAX ERROR (`syntax error before: 'band'`), as is `apply(M, band, [1])` in source; `'Probe':'band'(1)` (quoted) works -> returned 9 for Probe.Band(a)=a+8. So the claim "Erlang caller still works with the quoted atom" holds, and unquoted fails; but an Erlang caller already has `'Band'`, so the alias gives Erlang nothing.
- BIF names: aliases length/1, abs/1, self/0, spawn/1, float/1 compile with F and call correctly from Elixir (no auto-import clash error from compile:forms).
- p4 UNDER-COUNTS, confirmed. Its regex `public\s+[^\n(]*?\bName\s*\(` forbids `(` in the return type, so every function returning a tuple or fn type is invisible (e.g. `public (:ok, int) Init(...)`, `public (:reply, ...) HandleCall`, `public fn(int)->int Rule(...)`, `public (int, binary) EncodeResponse`, `HandleInfo`, `Handle`, `Steps`). My looser regex (/tmp/claude-0/verify62/p6_regex.py) on the same roots (compiler/examples, aoc, handoff): 118 names across 82 files vs p4's 114 names / 72 modules. Cross-check against compiled beams: 23 beams from the examples export 72 distinct names (non-Pascal: handle_call, handle_cast, init). Result unchanged: 0 digit-bearing names, 0 acronym/naive disagreement, 0 intra-module collision. With wayfinder/ included: 128 files / 154 names, still none. Only oddity: single-letter `F` in handoff/audition-switch/cases/c10-switch-in-guard (alias `f`). So the conclusion survives but the stored "114/72" figure is wrong.
- Ambiguity absent in corpus, present in language: grammar permits `Parse_json`, digits and acronyms; derivations are ambiguous (Base64Encode -> base64_encode vs base_64_encode; ParseJSON naive -> parse_j_s_o_n, which F does not produce: `:Probe.parse_j_s_o_n(1)` RAISED UndefinedFunctionError, `parse_json` works).
- p3/p5 hand-edited beams? No. p3 and p5 read beams written by bsc into my own output dirs (unpatched /u and F /f) via P62OUT. p1 uses the hand-built p0_mk beam but p1 only tests the PARSER (SYNTAX_ERROR happens before any module is touched), so the stand-in is irrelevant to its claim. Minor tautology: p5's "alias agrees with PascalCase export: true" holds by construction (alias just calls the Pascal function); it proves callability, not semantics.
- The stored probes dir still contains g/ (task said removed), ebin/, and erl_crash.dump. Irrelevant to results.

## Step 3: new probes (all under /tmp/claude-0/verify62/)

1. q1 (acronym/digit/BIF/multi-arity), module Probe compiled with F, called from Elixir 1.19.5 (q1.exs):
   `ParseJSON/1 -> :Probe.parse_json(1)=2`, `Utf8Length -> utf8_length`=3, `Base64Encode/3 -> base64_encode(1,2,3)`=6, `HTTPServer2 -> http_server2`=5, `F -> f`=6, `Length/Abs/Spawn/Float/Self` -> `length/abs/spawn/float/self` all correct, `band`=9. Exports list shows both Pascal and snake sets. On unpatched beam 12 calls RAISED (UndefinedFunctionError). PASS for F as described.
2. q2: `public int new(int a)` (lowercase fn name) -> `q2/Lower/x.bs:6:12: error: syntax error before: new` in BOTH unpatched and F. So a hand-written lowercase function that would clash with an alias cannot exist; the grammar rejects it. (Answers "if the grammar allows one": it does not.)
3. q3 (ParseJson + ParseJSON in one module): unpatched compiles; F FAILS: `compile: q3/Dup/x.bs:0: function parse_json/1 already defined`. **F turns a valid program into a compile error.**
4. q5 (`Parse_json` and `ParseJson`): unpatched compiles (Us.beam); F FAILS: `function parse_json/1 already defined`. Underscored Pascal names are legal, so a hand-written snake-ish name DOES clash with a derived alias, and F's `Own` guard misses it because `Own` holds the capitalised emitted names. Regression from the unpatched compiler.
5. q4 GenServer helper (above): Handle_call/3 alias silently dropped, Init/2 alias emitted, callbacks untouched; `Gs:handle_call(get,x,7)` -> {reply,7,7}, `Gs:init(1,2)` -> 3.
6. Erlang caller: `'Probe':parse_json(1)`, `'Probe':'band'(1)` work; unquoted `band` is a syntax error (see Step 2).
7. Gleam against F beam via `@external(erlang,"Shop","new")` works.

## Step 4: quoted-line claims

bs_otp.erl lines 7-8: "%%% These are tables, not a naming rule. A snake_case<->PascalCase derivation / %%% cannot spell `'PKCS-1'` or `'OTP-PKIX'`, so the language has no such rule." (Line 9: "Every row is written out by hand and nothing here is extended by inference.") Claim holds. Note this argues AGAINST F, which is a derivation rule.

LANGUAGE.md section 12 starts at line 3274 ("## 12. Being called from Erlang and Elixir"). "Function names are exported PascalCase, exactly as written" is the subsection at line 3291; it contains `:Shop.New(1)  # SyntaxError` and `apply(:Shop, :New, [1])` and says (line 3304) "No module naming scheme changes this". Line 3313 marks "ticket 62 holds the open decision on the casing; ENG-252". "### The `Kind` contract" is at line 3339 (key is the atom 'Kind' at 3343; example `%{Kind: :"Shop.Order", ...}` at 3364; FunctionClauseError for `:"MyApp.Order"` at 3365; the `__struct__` refusal around 3370). Claim holds. LANGUAGE.md does not mention the quoted-name form `:Shop."New"(1)` at all: it lists apply/3 as "the way in", so a documented gap that probe p1/p3 filled.

## Verdicts

- (a) CONFIRMED independently (1.14 and 1.19.5; real beams).
- (b) CONFIRMED (gleam 1.12.0).
- (c) CONFIRMED functionally; size measured above (+15.9% file, +33% Code, +71% ExpT on Shop; +8.0% across examples). Not a free feature, and F is not behaviour-preserving: it makes ParseJson+ParseJSON and Parse_json+ParseJson modules uncompilable (new probes 3 and 4).
- (d) PARTLY CONFIRMED: derivation does not clash with callback exports in F because of the `Own` guard and the callback skip, but the guard hides rather than reports the clash (Handle_call), and misses the capital-vs-snake clash case. The repo corpus has none of these cases.

CIRCULAR: no, for the evidence on claims (a)-(c). Reasons: the SYNTAX_ERROR results come from Elixir's own parser on any input; p3 uses real bsc output, not a hand-edited beam; p5 depends on F (fails on unpatched); Gleam emitted text reproduces independently; my independent probes agree. Residual weaknesses, not circularity: p4's regex under-counts (114 vs 118 names) so its "zero disagreements" is from an incomplete sample, though the conclusion holds on the larger set; p5's alias==Pascal equality is true by construction; F's own safety margin is not probed by any stored probe (the collision regressions above were absent from the stored set, so the stored set understates F's cost).
