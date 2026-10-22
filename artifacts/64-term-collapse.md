# 64 — term-collapse: decision brief for ticket 64 (ENG-254)

Written 2026-10-22 against repo HEAD `c3d50b9`. Not a resolution: no ticket file, Linear issue or commit was touched. Everything under `artifacts/` is new.

**Toolchain actually used** (versions recorded by the probes themselves): Erlang/OTP 25 (erts 13.2.2.5), Elixir 1.14.0 (compiled with OTP 24), Gleam 1.5.0, rebar3 3.19.0, Elm 0.19.3 (could not compile anything: see Limits). The tickets cite OTP 28 / Gleam 1.18.1 / Elixir 1.19.5, so **every cross-version claim is flagged in Limits.**

## 1. Ticket summary

`option<T> = T | :nothing` and `result<T,E> = T | (:error, E)` put the bare value in the success slot, so at `T = term` the failure marker is a member of `term` and the union is `term`. Ticket 68 Q1 (answered 2026-09-06) already settled that the collapse is sound **and refused where written** (`M ⊆ union(others)`), and F31/F36 built it. What is left open is:

- **Q2** what a `map<string, term>` lookup (the shape all three of ticket 48's motivating cases carry) reaches for, given the refusal leaves `option<term>` unwritable;
- **Q3** whether the same reasoning reaches `result<T, E>` at `E = term` ("never measured").

Prior art I grepped before writing (per CLAUDE.md): `grep -ln` over `wayfinder/issues/*.md` for `ticket 64|ENG-254` hits only 64, 68, F31, F36. The related decided-but-unbuilt rows are in 96 Q3 / 108: *every* operation that can find nothing (`Map.Get`, `List.First/Last/At/Max/Min/Find`) has a non-crashing second form spelled `Map.?Get` that "returns `option<T>`" (108 header: *"a lookup's second form returns `option<T>` (`T | :nothing`)"*; 96:224: `Map` `Find` → `option<V>`). **None of those rows is built** (`Map.Get` → *"`Map` has no operation of that name"* in my run; `standard_table`/`declared_rows` at `compiler/src/bs_check.erl:1708-1747` has `Map.Has` but no `Get`/`Find`). So the return type of the whole lookup family is still free to choose.

## 2. Sub-decisions and gating order

1. **(gating) What type does the lookup family's non-crashing form return at `V = term`?** Everything else follows from it. Decided so far: `option<V>` (96 Q3, 108) — which is unwritable at `V = term` (68 Q1).
2. **Is the loud refusal complete?** 68 Q1 says "an absorbed member is an error *where it is written*". A generic function returning `option<T>` and called with `T` inferred as `term` writes nothing, so nothing refuses (Probe 03). Needed under every answer to (1) except "tag `option<T>`".
3. *(follows from 1)* If lookups are not `option<V>`: the shape and name of the always-tagged type. The compiler's own hint already prescribes a shape: `hint: tag it - (:some, ~s) | :nothing` (`compiler/src/bs_diag.erl:1973`); ticket 48 Q8 / F31 S10 use `(:ok, V) | :absent`.
4. **Q3 is a measurement, not a decision** — answered below by Probe 02 (no, it does not collapse at `E = term`).

## 3. Probes

All under `/home/user/beam-sharp/artifacts/probes/64/`. Each `run.sh` is self-contained: `lib/env.sh` builds the scratch compilers on first use into `/tmp/claude-0/ws64-*` (verified from an empty cache) and prints the toolchain. No expected output is hard-coded anywhere; every verdict column is a compiler exit status or a printed type.

**The reference compiler.** `rebar3 escriptize` on the repo's `compiler/` fails under OTP 25. I built a **scratch copy** (`lib/build-bsc-otp25.sh`; the repo is untouched, `git status` shows only `?? artifacts/`) with three patches, all to the copy:
1. `rebar.config`: delete `{xrl_opts, [{error_location, column}]}` — OTP 25's `leex` rejects it (`badarg` at `leex.erl:137`).
2. `src/bs_run.erl`: `~kp` → `~p` — the `k` modifier is OTP 26+ (`format string invalid (invalid control ~k)`, affects only map printing order).
3. `src/bs_lexer.xrl`: `TokenLoc` → `{TokenLine,1}` plus a stub `adjust_col/3` — OTP 25's `leex` has no `TokenLoc`. **Consequence: every token column is 1, so diagnostic columns are wrong** (lines are right). Type checker, emitter and prelude are unmodified.
The built escript reproduces the repo's refusals verbatim (Probe 01) and matches the repo's own `compiler/examples/exemplars/FRONTIER` record line for line on all seven exemplars (Probe 06 tail). Two further scratch builds add exactly one change each: `lib/build-bsc-tagged-option.sh` (Option 1's one-line prelude edit) and `lib/build-bsc-callsite-refusal.sh` (a ~25-line prototype of Option 2/3's refusal).

### P01 — the ticket's four signatures at HEAD
`artifacts/probes/64/01-four-signatures/run.sh`. Ticket claim: `FindR`/`FindT` "COLLAPSED" to bare `term`; `FindF` survives.
```
# erl OTP 25  repo HEAD c3d50b9  bsc=/tmp/claude-0/ws64-build/compiler/_build/default/bin/bsc (OTP-25 scratch build; diagnostic columns not faithful)
=== FindF: bsc --api ===
module FindF
:absent | (:ok, term) FindF(map<string, term>, string)
=== FindF: bsc (compile) exit/ output ===
exit=0
=== FindI: bsc --api ===
module FindI
:nothing | int FindI(map<string, int>, string)
=== FindI: bsc (compile) exit/ output ===
exit=0
=== FindR: bsc --api ===
/tmp/tmp.WXYJFFJhRn/FindR/FindR.bs:2:1: error: `(:error, atom)` is absorbed by `term`
  in FindR
  the failure channel does not survive normalisation, so the type
  declared here IS `term`. No caller can write the failure clause,
  because no failure member is left to match.
  The failure member already carries its tag, so tagging it again
  repairs nothing: narrow the success type until it cannot hold an
  `(:error, ...)` of its own.
=== FindR: bsc (compile) exit/ output ===
/tmp/tmp.WXYJFFJhRn/FindR/FindR.bs:2:1: error: `(:error, atom)` is absorbed by `term`
  in FindR
  the failure channel does not survive normalisation, so the type
  declared here IS `term`. No caller can write the failure clause,
  because no failure member is left to match.
  The failure member already carries its tag, so tagging it again
  repairs nothing: narrow the success type until it cannot hold an
  `(:error, ...)` of its own.
exit=1
=== FindT: bsc --api ===
/tmp/tmp.WXYJFFJhRn/FindT/FindT.bs:2:1: error: `:nothing` is absorbed by `term`
  in FindT
  the failure channel does not survive normalisation, so the type
  declared here IS `term`. No caller can write the failure clause,
  because no failure member is left to match.
  hint: tag it - (:some, term) | :nothing
=== FindT: bsc (compile) exit/ output ===
/tmp/tmp.WXYJFFJhRn/FindT/FindT.bs:2:1: error: `:nothing` is absorbed by `term`
  in FindT
  the failure channel does not survive normalisation, so the type
  declared here IS `term`. No caller can write the failure clause,
  because no failure member is left to match.
  hint: tag it - (:some, term) | :nothing
exit=1
```
**Shows.** `FindF` (`:absent | (:ok, term)`) and `FindI` survive. `FindR`/`FindT` can no longer be *measured* as collapsed: since F31 they are refused, so `--api` prints the diagnostic instead of `term`. The ticket's own numbers (taken 2026-08-25, before F31 on 08-28) are historical, not falsified. Note the `(:error, …)` variant has **no hint** ("tagging it again repairs nothing: narrow the success type") — at `T = term` there is nothing to narrow to.

### P02 — Q3: does `result<T, E>` collapse at `E = term`?
`artifacts/probes/64/02-result-matrix/run.sh`.
```
# erl OTP 25  repo HEAD c3d50b9  bsc=/tmp/claude-0/ws64-build/compiler/_build/default/bin/bsc (OTP-25 scratch build; diagnostic columns not faithful)
T                      E          verdict  first line / --api
int                    term       accept   int | (:error, term) F(int | (:error, term))
int                    atom       accept   int | (:error, atom) F(int | (:error, atom))
int                    binary     accept   int | (:error, binary) F(int | (:error, binary))
atom                   term       accept   atom | (:error, term) F(atom | (:error, term))
atom                   atom       accept   atom | (:error, atom) F(atom | (:error, atom))
term                   atom       REFUSE   M6/M6.bs:2:1: error: `(:error, atom)` is absorbed by `term`
term                   term       REFUSE   M7/M7.bs:2:1: error: `(:error, term)` is absorbed by `term`
term                   int        REFUSE   M8/M8.bs:2:1: error: `(:error, int)` is absorbed by `term`
(atom,binary)          binary     REFUSE   M9/M9.bs:2:1: error: `(:error, binary)` is absorbed by `(atom, binary)`
(atom,term)            binary     REFUSE   M10/M10.bs:2:1: error: `(:error, binary)` is absorbed by `(atom, term)`
(:error,int)           binary     accept   (:error, int) | (:error, binary) F((:error, int) | (:error, binary))
(:error,term)          binary     REFUSE   M12/M12.bs:2:1: error: `(:error, binary)` is absorbed by `(:error, term)`
list<term>             term       accept   (:error, term) | list<term> F((:error, term) | list<term>)
map<atom,term>         term       accept   (:error, term) | map<atom, term> F((:error, term) | map<atom, term>)
```
**Shows.** **No: collapse is a function of `T`, never of `E`.** `result<int, term>`, `result<atom, term>`, `result<list<term>, term>`, `result<map<atom,term>, term>` are all accepted and print as `int | (:error, term)` etc., because `(:error, term)` is a tuple and cannot be a subset of a non-tuple, non-`term` success. It refuses exactly when `T` can already hold an `(:error, E)`: `T = term`, `T = (atom, binary)`, `T = (atom, term)`, `T = (:error, term)`. Also reproduced: ticket 15 §3's "known limit" — `result<(:error,int), binary>` is **accepted** (row `(:error,int) binary`), so a success value can match the failure clause there.

### P03 — is the refusal complete? (ticket 68 Q1 says "where it is written")
`artifacts/probes/64/03-inferred-instantiation/run.sh`. A generic `option<T> Head<T>(list<T>)`, called with a `list<term>`; `T = term` is inferred, `option<term>` is never written. Then the same program under the prototype call-site refusal.
```
# erl OTP 25  repo HEAD c3d50b9  bsc=/tmp/claude-0/ws64-build/compiler/_build/default/bin/bsc (OTP-25 scratch build; diagnostic columns not faithful)
=== compile ===
exit=0
=== --api ===
module G
string DescribeFirst(list<term>)
string DescribeHead(list<term>)
string EmptyFirst()
string EmptyHead()
string ErrorFirst()
result<T, atom> First<T>(list<T>)
option<T> Head<T>(list<T>)
string IntFirst()
string IntHead()
string NothingHead()
EmptyHead    -> "absent"
NothingHead  -> "absent"
IntHead      -> "present"
EmptyFirst   -> "failed"
ErrorFirst   -> "failed"
IntFirst     -> "ok"

################ same program, bsc with the PROTOTYPE call-site refusal (Option 2's compiler delta) ################
/tmp/tmp.BU9wBkwcdl/G/G.bs:13:1: error: DescribeHead calls Head at a type where `:nothing` is absorbed by `term`
  the union it returns has one member at this instantiation, so no caller
  can tell the success value from the marker. Tag the result.
/tmp/tmp.BU9wBkwcdl/G/G.bs:19:1: error: DescribeFirst calls First at a type where `(:error, atom)` is absorbed by `term`
  the union it returns has one member at this instantiation, so no caller
  can tell the success value from the marker. Tag the result.
exit=1
=== controls (T = int; T = none) under the prototype ===
/tmp/tmp.BU9wBkwcdl/H/H.bs:13:1: warning: arm 2 of this switch in EmptyCase is unreachable
  every value it matches is matched by an earlier arm.
exit=0
0
```
**Shows.** **The loud refusal has a hole, and it is the same bug at runtime.** `DescribeHead([:nothing])` returns `"absent"` for a list that *has* an element; `DescribeFirst([(:error, :custom)])` returns `"failed"` for a *successful* first element. Zero diagnostics (`compile … exit=0`). The declaration-time check (`collapse_decl/2` → `scan_ty/5`, `bs_check.erl:1111`, `:1164`) never sees an instantiation that is inferred; the substitution happens at `checked_call_typed/7` (`bs_check.erl:4427-4433`, `subst_tpl(RetT, Sub)`, whose `t_union` clause at `:1015` re-unions and erases the boundary). The prototype checks the substituted members there (`absorbed/2`, `bs_check.erl:3424`, reused unchanged): it refuses both calls and stays quiet on the `T = int` control and on `Head([])` (`T = none`, exempted because `none ⊆ everything`).

### P04 — the same task written three ways, each compiled by three bscs
`artifacts/probes/64/04-three-programs/run.sh` (sources in `Opt1/ Opt2/ Opt3/`). Task: read key `k` of a `map<string, term>` whose value may itself be the atom `:nothing`; report absent / present / present-with-value-`:nothing`. `Map.Get` is unbuilt, so the programs call `:maps.find`/`:maps.get` through a `using :maps { … }` block, as the repo's own exemplar `25g-jev-server/triage_index.bs:38-40` does.
```
# erl OTP 25  repo HEAD c3d50b9  bsc=/tmp/claude-0/ws64-build/compiler/_build/default/bin/bsc (OTP-25 scratch build; diagnostic columns not faithful)
=== Opt1 under base ===
Opt1/Opt1.bs:8:1: error: `:nothing` is absorbed by `term`
  in Get
  the failure channel does not survive normalisation, so the type
(refused, exit=1)
=== Opt1 under tagged ===
compiles. --api:
string Describe(map<string, term>, string)
:nothing | (:some, term) Get(map<string, term>, string)
  Present         -> "present"
  PresentNothing  -> "present, the value is :nothing"
  Absent          -> "absent"
=== Opt1 under callsite ===
Opt1/Opt1.bs:8:1: error: `:nothing` is absorbed by `term`
  in Get
  the failure channel does not survive normalisation, so the type
(refused, exit=1)
=== Opt2 under base ===
compiles. --api:
string Describe(map<string, term>, string)
  Present         -> "present"
  PresentNothing  -> "present, the value is :nothing"
  Absent          -> "absent"
=== Opt2 under tagged ===
compiles. --api:
string Describe(map<string, term>, string)
  Present         -> "present"
  PresentNothing  -> "present, the value is :nothing"
  Absent          -> "absent"
=== Opt2 under callsite ===
compiles. --api:
string Describe(map<string, term>, string)
  Present         -> "present"
  PresentNothing  -> "present, the value is :nothing"
  Absent          -> "absent"
=== Opt3 under base ===
compiles. --api:
string Describe(map<string, term>, string)
:nothing | (:some, term) Get(map<string, term>, string)
  Present         -> "present"
  PresentNothing  -> "present, the value is :nothing"
  Absent          -> "absent"
=== Opt3 under tagged ===
compiles. --api:
string Describe(map<string, term>, string)
:nothing | (:some, term) Get(map<string, term>, string)
  Present         -> "present"
  PresentNothing  -> "present, the value is :nothing"
  Absent          -> "absent"
=== Opt3 under callsite ===
compiles. --api:
string Describe(map<string, term>, string)
:nothing | (:some, term) Get(map<string, term>, string)
  Present         -> "present"
  PresentNothing  -> "present, the value is :nothing"
  Absent          -> "absent"
```
**Shows.** Opt1 (`option<term>`, written in the prelude's own type) is refused today and works only when the prelude's `option` is tagged. Opt2 and Opt3 compile and are correct **on the unmodified compiler**, in all three variants, including the one value (`:nothing` stored) that the collapsed type cannot tell from absent.

### P05 — neighbours' lookups when the stored value looks like "absent"
`artifacts/probes/64/05-neighbours/run.sh` (Gleam project in `05-neighbours/gleam1`, dependency-free).
```
# OTP 25  Elixir 1.14.0 (compiled with Erlang/OTP 24)  gleam 1.5.0
=== Erlang: a value that IS the 'absent' atom, stored under k ===
maps:get(k, M, nothing)   = nothing   (present, value nothing)
maps:get(z, M, nothing)   = nothing   (absent)
maps:find(k, M)           = {ok,nothing}
maps:find(z, M)           = error
flat_size(nothing)=0  flat_size({ok,nothing})=3 words
=== Elixir: Map.get/2 vs Map.fetch/2 on %{k: nil} ===
Map.get(m, :k)   present, value nil: nil
Map.get(m, :z)   absent: nil
Map.fetch(m, :k): {:ok, nil}
Map.fetch(m, :z): :error
Map.fetch(%{k: :error}, :k)  (value is the failure atom): {:ok, :error}
=== Gleam: find returns Result(v, Nil); v itself a Result(Int, Nil) with value Error(Nil) ===
  Resolving versions
  Compiling gl1
   Compiled in 0.34s
gl1:main() = <<"present, value is itself Error(Nil)">>
--- emitted Erlang for find/2:
find(Xs, Key) ->
    case Xs of
        [] ->
            {error, nil};

        [{K, V} | _] when K =:= Key ->
            {ok, V};

        [_ | Rest] ->
            find(Rest, Key)
    end.

-file("/tmp/tmp.KM3UQoVD5S/g/src/gl1.gleam", 15).
-spec describe(list({binary(), {ok, integer()} | {error, nil}}), binary()) -> binary().
describe(Xs, Key) ->
```
**Shows.** The untagged forms (`maps:get/3` with a sentinel default; `Map.get/2`) cannot tell absent from stored-sentinel; the tagged forms (`maps:find/2`, `Map.fetch/2`, Gleam's `Result(v, Nil)`) can, and Gleam's emitted Erlang is literally `{ok, V}` / `{error, nil}`.

### P06 — cost of Option 1 (tag `option<T>`), by recompiling the tree
`artifacts/probes/64/06-tag-option-blast-radius/run.sh`.
```
# erl OTP 25  repo HEAD c3d50b9  bsc=/tmp/claude-0/ws64-build/compiler/_build/default/bin/bsc (OTP-25 scratch build; diagnostic columns not faithful)
DIR                                              baseline tagged   first tagged diagnostic
Levels                                           ok       REFUSED  Levels/levels.bs:50:1: error: Parse returns a value its signature does not declare
Parcel                                           ok       REFUSED  Parcel/parcel.bs:30:1: error: Weigh returns a value its signature does not declare
dirs=35  ok under both=25  ok-baseline-but-refused-tagged=2  failing at baseline already=8
--- .bs lines mentioning option< or :nothing under compiler/examples:
33
--- of those, in files that declare option<:
./Levels/levels.bs
./Names/names.bs
./Parcel/parcel.bs
./exemplars/25d-database-querying/api.bs
./exemplars/25d-database-querying/fetch.bs
./exemplars/25d-database-querying/index.bs
./exemplars/25d-database-querying/sql.bs
./exemplars/25e-dynamic-web-page/index.bs
./exemplars/25e-dynamic-web-page/layout.bs
./exemplars/25f-llm-evaluation-client/route.bs
--- exemplars/ (ticket 25's targets; the repo's own FRONTIER file records that they stop early, so they cannot show the tagged-option cost by compiling):
25a-http-api-server            baseline: error: this directory holds `.bs` files and no `module` line
25b-websocket-handler          baseline: 25b-websocket-handler/handle_info.bs:12:1: error: syntax error before: ','
25c-event-queue-consumer       baseline: 25c-event-queue-consumer/encode.bs:13:1: error: syntax error before: '<<'
25d-database-querying          baseline: error: this directory holds `.bs` files and no `module` line
25e-dynamic-web-page           baseline: 25e-dynamic-web-page/index.bs:10:1: error: `module Shop.Page` does not match its directory
25f-llm-evaluation-client      baseline: 25f-llm-evaluation-client/index.bs:10:1: error: `module Support.Triage` does not match its directory
25g-jev-server                 baseline: /home/user/beam-sharp/compiler/examples/exemplars/25f-llm-evaluation-client/index.bs:10:1: error: `module Support.Triage
--- does option<option<int>> (15 §1's nesting case) and option<atom> survive under each bsc?
[base]
N/N.bs:2:1: error: `:nothing` is absorbed by `:nothing | int`
[tagged]
:nothing | (:some, :nothing | (:some, int)) F(:nothing | (:some, :nothing | (:some, int)))
:nothing | (:some, atom) G(:nothing | (:some, atom))
:nothing | (:some, term) H(:nothing | (:some, term))
```
**Shows.** One-line prelude edit (`stratum_one`, `bs_check.erl:1351-1353`): of 25 example directories that compile at HEAD, **2 stop compiling** (`Levels`: `Parse -> ParseAtom<Level>(s)`, a built-in producer of a bare `T | :nothing`; `Parcel`: `Weigh(p) -> p.Note`). The seven exemplars that actually use `option<>` heavily (25d/25e/25f) **cannot be measured by compiling**: they stop earlier (the repo's `FRONTIER` file records the same first errors). Built-in bare producers of `T | :nothing` are two sites: type `bs_check.erl:3455`, value `bs_emit.erl:996` (`ParseAtom`). Bonus measured: under the tagged build `option<option<int>>`, `option<atom>` and `option<term>` are all accepted and nest (`:nothing | (:some, :nothing | (:some, int))`); at baseline the first is refused. (The "8 failing at baseline" are the 7 exemplars plus `Signalbox`, which dies with `compile: Function: 'ModelKey'/1` — I did not investigate; it may be an OTP 25 artefact of the template-string feature.)

### P07 — what a tagged success costs on the BEAM
`artifacts/probes/64/07-runtime-cost/run.sh`.
```
# erl OTP 25  repo HEAD c3d50b9  bsc=/tmp/claude-0/ws64-build/compiler/_build/default/bin/bsc (OTP-25 scratch build; diagnostic columns not faithful)
--- bsc --api
module Cost
:nothing | int GetBare(map<string, int>, string)
:nothing | (:some, int) GetTagged(map<string, int>, string)
int LoopBare(map<string, int>, int, int)
int LoopTagged(map<string, int>, int, int)
--- bytes: Cost.beam=2248  Cost.abstr=10142
--- emitted Erlang for the two lookups (erl_pp of the abstract code chunk):
                    element(1, bs@rv1) =:= ok
                    andalso
                    is_integer(element(2, bs@rv1)) ->
                bs@rv1
        end
    of
        {ok, V} ->
            {some, V};
        error ->
            nothing
    end.

--- heap words: erts_debug:flat_size of what each lookup returns on a hit (7), a binary hit, a miss
bare   7                           flat_size=0
tagged {some,7}                    flat_size=3
bare   100-byte binary             flat_size=6
tagged {some,<<100 bytes>>}        flat_size=9
bare   :nothing (miss)             flat_size=0
tagged :nothing (miss)             flat_size=0
--- 5,000,000 hit lookups, best of 5 (timer:tc, microseconds)
LoopBare   176773 us   result 70
LoopTagged 165581 us   result 70
tagged/bare = 0.94
```
**Shows.** Tag cost is 3 heap words per hit (`{some,V}`), 0 on a miss; the 5M-lookup loop is within noise (`tagged/bare` = 0.94-0.97 across four runs, the embedded one is 0.94; one machine, best of 5; tagged was never slower), because `maps:find/2` already allocates `{ok, V}` and the bare form has to unwrap it. A lookup row whose OTP target is `maps:find` could return the tuple it was handed. `Cost.beam` is 2248 bytes for both functions together; no per-function size difference worth reporting.

### P08 — two premises the ticket and 15 §1 lean on
`artifacts/probes/64/08-stale-premises/run.sh`.
```
# erl OTP 25  repo HEAD c3d50b9  bsc=/tmp/claude-0/ws64-build/compiler/_build/default/bin/bsc (OTP-25 scratch build; diagnostic columns not faithful)
=== (a) `d as int` ===
A/A.bs:3:1: error: syntax error before: as
grep for an 'as' token in the lexer/parser:
(no match)
=== (b) PRELUDE.md ===
(no PRELUDE.md anywhere in the tree)
=== (b) what ToExistingAtom returns: ask for an int and read the diagnostic ===
T/T.bs:3:1: error: F hands ToExistingAtom a binary, and it looks up a string
  the failure is `(:error, name)` with the name as a `string`, so the
  argument must be one: a `binary` that is not valid UTF-8 has no
compiler source: the failure member is a tagged tuple:
1697:     "  the failure is `(:error, name)` with the name as a `string`, so the~n"
```
**Shows.** (a) 15 §1 rejected tagging both channels because it taxes ticket 08's `as T` yielding `T | :nothing`. **`as` does not exist in the compiler at HEAD** (`syntax error before: as`; no token in `bs_lexer.xrl`/`bs_parser.yrl`). The cost is real as a *decision* and zero as *code*. (b) Ticket 64's paragraph "PRELUDE.md still records `ToExistingAtom` as owed … two known-good answers and neither chosen" is **stale**: there is no `PRELUDE.md` in the tree, and `ToExistingAtom` is built with a tagged failure `(:error, name)` (ticket 97:59 says the same).

## 4. Neighbour survey

All citations verified by `grep -n` / `sed -n` on installed files on this machine. **Not installed, so not cited:** Elixir's `map.ex` (only beams are installed), Gleam's `gleam_stdlib` (`dict.gleam`/`option.gleam`), Elm's `elm/core` (`Dict.elm`/`Maybe.elm`).

- **Erlang** `/usr/lib/erlang/lib/stdlib-4.3.1.3/src/maps.erl`:
  - `:60` `-spec find(Key,Map) -> {ok, Value} | error when` — tagged success.
  - `:285` `-spec get(Key, Map, Default) -> Value | Default when`, body `:288-291` (`#{Key := Value} -> Value; #{} -> Default`) — the sentinel form; P05 shows it ambiguous when the stored value equals the default.
  - `:53` `-spec get(Key,Map) -> Value when` — the crashing form.
  - `/usr/lib/erlang/lib/stdlib-4.3.1.3/src/lists.erl:77` `-spec keyfind(Key, N, TupleList) -> Tuple | false when` — **untagged**, and sound exactly because the success is always a tuple and the marker an atom: the same "survives unless absorbed" rule B# has, applied by hand. `proplists.erl:130` `-spec lookup(Key, List) -> 'none' | tuple() when` likewise.
- **Elixir 1.14** (`/usr/lib/elixir/lib/elixir/ebin/Elixir.Map.beam`; line numbers read from its `debug_info` chunk, whose recorded source file is `/build/elixir-lang-vfZvaj/elixir-lang-1.14.0.dfsg/lib/elixir/lib/map.ex`, not installed): `Map.fetch/2` defined at `map.ex:300`, `fetch!/2` at `:318`, `get/2,3` at `:525`, `has_key?/2` at `:281`. Docs chunk (`Code.fetch_docs(Map)`): *"If `map` contains the given `key` then its value is returned in the shape of `{:ok, value}`. If `map` doesn't contain `key`, `:error` is returned."* and for `get`: *"If `default` is not provided, `nil` is used."* (P05: `Map.get(%{k: nil}, :k)` and `Map.get(%{}, :k)` are both `nil`; `Map.fetch` distinguishes.) Elixir 1.14 has no set-theoretic types, so the `Module.Types.Descr` measurements in ticket 15 (Elixir 1.19.5) **could not be re-run**.
- **Gleam 1.5.0**: `Result` and `Nil` are in the compiler prelude, so a dependency-free project compiles (P05). A lookup is `Result(v, Nil)`; because Gleam has no untagged unions and no top type, `Result(Result(Int, Nil), Nil)` nests (P05 prints `"present, value is itself Error(Nil)"`). Emitted: `gl1.erl` `find/2` returns `{error, nil}` / `{ok, V}` (printed in P05).
- **Elm 0.19.3**: `elm make` fails to fetch `https://package.elm-lang.org/all-packages` (proxy 403); no Elm program was compiled. Nothing is claimed about `Dict.get`/`Maybe` beyond general knowledge, which I label as such: `Dict.get : comparable -> Dict comparable v -> Maybe v` with `Maybe` a tagged custom type.

**Pattern across all four:** where the success type can contain the marker (`term`, `dynamic`, `nil`-able), the standard lookup is tagged (`find`, `fetch`, `Result`, `Maybe`); the untagged/sentinel form exists beside it and is the documented footgun; the one untagged lookup that is sound (`keyfind`) is sound by disjointness.

## 5. Measurements

| What | Command | Result |
|---|---|---|
| Tag cost, hit | `erts_debug:flat_size/1` (P07) | `7` → 0 words; `{some,7}` → 3 words; 100-byte binary 6 → 9 words; miss 0 → 0 |
| Loop, 5M lookups | `timer:tc`, best of 5 (P07) | four runs: bare 175,590 / 176,199 / 176,773 µs, tagged 169,906 / 167,278 / 165,581 µs (ratio 0.94-0.97; noise level, tagged never slower) |
| Emitted shape | `beam_lib:chunks(…, [abstract_code])` + `erl_pp` (P07) | tagged lookup is `case maps:find(K,M) of {ok,V} -> {some,V}; error -> nothing end`; bare is `{ok,V} -> V` |
| Option 1 blast radius | recompile all example dirs with a tagged-prelude bsc (P06) | 2 of 25 compiling dirs break; 33 `.bs` lines under `compiler/examples` mention `option<` or `:nothing`, 10 files declare `option<`; exemplars unmeasurable |
| Option 2/3 refusal size | `lib/build-bsc-callsite-refusal.sh` | ≈25 lines in two files (`bs_check.erl` one clause + helper, `bs_diag.erl` one `built` + one `message`); one call site |
| Beam size | `stat` (P07) | `Cost.beam` 2248 bytes (both functions), `.abstr` 10142 |

Compile time was not measured: neither option changes an algorithm (an `is_subtype` per returned union member at one call site).

## 6. Options

Each is the same task (P04) as code, then the compiler work, the evidence, and the strongest counterargument. Options 2 and 3 share their refusal; they differ only in whether the author is handed a type.

### Option 1 — `option<T>` itself becomes `(:some, T) | :nothing`

```csharp
public option<term> Get(map<string, term> m, string k)          // refused today; compiles under Option 1
Get(m, k) -> :maps.find(k, m) switch { (:ok, v) => (:some, v), :error => :nothing }

public string Describe(map<string, term> m, string k)
Describe(m, k) -> Get(m, k) switch {
    :nothing          => "absent",
    (:some, :nothing) => "present, the value is :nothing",
    (:some, v)        => "present"
}
```
P04 ran this under the tagged build: `Present` → `"present"`, `PresentNothing` → `"present, the value is :nothing"`, `Absent` → `"absent"`. `option<option<int>>`, `option<atom>`, `option<term>` all accepted and nest (P06). Under it, `Levels`' `Parse(s) -> ParseAtom<Level>(s)` and `Parcel`'s `Weigh(p) -> p.Note` stop compiling and need `(:some, …)`; a user's `option<int>` return `n` becomes `(:some, n)`.

**Compiler delta.** `bs_check.erl:1351-1353` one line; `ParseAtom` (`:3455`, `bs_emit.erl:996`) either follows (two sites) or stays bare and stops being an `option`; `failure_channel/1` (`:1221`) and the `:nothing` hint (`bs_diag.erl:1973`) become dead for `option`; F31/F36 scenarios S1-S5 flip; the call-site hole (P03) disappears for `option` with no new check. `result<T,E>` is untouched (its tag already exists; P02).

**Strongest counterargument.** It reverses the one decision 15 §1 spent a section defending: *"Why not simply tag both channels … The cost falls precisely on the language's showcase"* (the untagged union is what makes `as T` read well), and ticket 64's own Notes warn that making `option<int>` more awkward to buy `option<term>` "may be a bad trade". Every `option<int>` anywhere pays a wrapper to repair a case that only bites at `term`/`atom`. (Mitigation that P08 found: `as T` is unbuilt, so the cost lands on a decision, not code — but the decision is David's, and `option<T> = T | :nothing` is also what every exemplar was written against.)

### Option 2 — keep `option<T>`; close the inference hole; at `term` the author asks `Map.Has`, then reads

```csharp
private string Show(term v)
Show(:nothing) -> "present, the value is :nothing"
Show(v)        -> "present"

public string Describe(map<string, term> m, string k)
Describe(m, k) -> Map.Has(m, k) switch {
    :false => "absent",
    :true  => Show(:maps.get(k, m))        // the decided crashing Map.Get, once built
}
```
Compiles and is correct on the unmodified compiler (P04, all three variants). With the prototype refusal, `Head(xs)` at `list<term>` is refused where it is called (P03), instead of returning `"absent"` for a present element.

**Compiler delta.** Only the refusal: `checked_call_typed/7` (`bs_check.erl:4427`) checks the substituted return union with `absorbed/2` (`:3424`); one `built/2` and one `message/1` clause in `bs_diag.erl`; the `none`-exemption (so `Head([])` is quiet) and a decision whether it applies to arguments/records built from generic calls (not measured). 68's "where written" needs to read "where written or inferred".

**Strongest counterargument.** The author is handed *nothing* at the type level: a function that wants to *return* "maybe a `term`" must invent its own tagged shape (they can: Option 3's `Found<T>` compiles today), generic helpers like `Head<T>` become unusable over `list<term>` altogether (refused at every such call), and the decided `Map.?Get` is refused at `V = term` — the ticket's first complaint, kept. Two lookups per read, and no way to compose "absent" as a value.

### Option 3 — keep `option<T>`; the lookup family returns an always-tagged prelude type; plus Option 2's refusal

```csharp
type Found<T> = (:some, T) | :nothing          // compiles today as a user alias (P04); Option 3 ships it in the prelude, name TBD

public Found<term> Get(map<string, term> m, string k)
Get(m, k) -> :maps.find(k, m) switch { (:ok, v) => (:some, v), :error => :nothing }

public string Describe(map<string, term> m, string k)
Describe(m, k) -> Get(m, k) switch {
    :nothing          => "absent",
    (:some, :nothing) => "present, the value is :nothing",
    (:some, v)        => "present"
}
// the decided Map.?Get / List.?First / … then read identically, at every V:
// Map.?Get(m, k) switch { :nothing => 0, (:some, n) => n }
```
P04: identical output to Option 1, on the **unmodified** compiler (`Opt3` under `base`: `Present`, `PresentNothing`, `Absent` correct); `option<int>` and `ParseAtom` untouched.

**Compiler delta.** Zero for the type (a parametric alias, `stratum_one`-shaped entry, or a doc'd user alias); the refusal as in Option 2; the `Map.?Get`/`List.?First`/… rows (not yet built) are declared with the tagged return instead of `option<V>` — amending 96 Q3 / 108's "returns `option<T>`" for the lookup family only (97's conversions already differ: `result<T, string>`); `maps:find`'s native `{ok,V}` can be reused as the tag if the tag atom is `:ok` rather than `:some` (the choice between `(:some, V) | :nothing` — the shape the compiler's own hint already prints — and 48's `(:ok, V) | :absent` is the naming question that follows).

**Strongest counterargument.** Two near-synonym "maybe" types with a rule for choosing, and the seam is exactly where code composes: the repo's own exemplar hand-writes a lookup returning `option<Answer>` (`25f-llm-evaluation-client/route.bs:19`, `Lookup`) and passes it to `Queue(option<Answer>)`; after this, the standard `List.?Find` returns `Found<Answer>` and the author's own helper returns `option<Answer>`, so a conversion appears at every join. Gleam/Elm/Erlang's `find` have one lookup shape; this has two.

## 7. Recommendation

**Option 3, with Option 2's refusal, and ask David only the gating question: *does `Map.?Get` return `option<V>` or a tagged `(:some, V) | :nothing`?***

Why, with the evidence next to it:
- The rows do not exist yet, so choosing the tagged return costs no migration (§1: `declared_rows` has no `Get`/`Find`), while Option 1 breaks two compiling examples (P06) and re-litigates 15 §1 for a feature (`as T`) with no code (P08).
- The tagged program already runs on today's compiler and is correct on exactly the value that defeats the collapsed type (P04 `Opt3`), at no measurable cost (P07, ratio 0.94-0.97).
- Every neighbour that has a `term`-like top tags the lookup that can be ambiguous (§4), and the one sound untagged lookup (`keyfind`) is sound by disjointness — the same rule B# already enforces. The compiler's own hint (`bs_diag.erl:1973`) already tells the author to write the tagged shape; this makes that sentence a name instead of homework.
- Option 2's refusal is not optional under 2 or 3: P03 shows the current guarantee ("an absorbed member is an error") is false for inferred instantiations and produces a wrong answer at runtime with zero diagnostics. That is a defect against 68 Q1's own intent, and its fix is ~25 lines at one call site.
- If David would rather one "maybe" type for the whole language, Option 1 is the coherent choice, and P06/P04 show it works; the price is paid by every `option<int>`.

Q3: **closed by P02** — `result<T,E>` at `E = term` does not collapse; the rule is `T ⊇ (:error, E)`, and 68's single rule already covers it. Ticket 64's "ToExistingAtom owed" paragraph is stale (P08).

## 8. Limits and what I could not verify

- **OTP 25, not 28.** The scratch `bsc` has diagnostic columns wrong (all 1) and prints maps with `~p` not `~kp`. Type-checking and emission are the repo's code, but I have not run `./bin/verify.sh`, the eunit suite or any gate, and the reference compiler's behaviour on OTP 28 is **inferred** from running the same source on 25. Emitted Erlang (P07) is OTP-25 `erl_pp`'d.
- `Signalbox` fails to compile in my build (`compile: Function: 'ModelKey'/1`); I did not determine whether that is OTP 25 or real.
- **Ticket 15's Elixir 1.19.5 `Descr` measurements** were not re-run (Elixir 1.14 has no set-theoretic types). My P02/P03 measure B#'s own `bs_types`, not Elixir's.
- **Elm** could not be exercised (package server blocked); Elm claims are labelled general knowledge. **Gleam stdlib** and **Elixir `map.ex`** are not installed; Elixir line numbers come from beam debug_info, not a source file I could open.
- The **call-site refusal is a prototype** (no tests, no scenario table, no F-file, one exemption). I did not check whether it fires on any program in the tree that now compiles (the example dirs were compiled only with the other two scratch builds); the exemptions needed for records/nested generics are not explored.
- The **tagged-prelude build** changes only `stratum_one`; `ParseAtom` still yields a bare `:nothing`, so `Levels` is expected to break and is not a finished Option 1.
- The performance numbers are one machine, one run of 5, a microbenchmark whose lookup is `maps:find/2`; they show "no cost large enough to see", not a cost of zero.
- I did not measure how many programs write `result<term, E>` vs `option<term>`; the tree has none (the exemplars that would are blocked earlier by the frontier).

## Verification errata (independent verifier, see 64-verification.md)

PASS WITH CAVEATS; P01–P08 reproduced. Corrections that supersede the text above:
- The call-site refusal prototype checks only a top-level union return. `list<option<T>>` and `(option<T>, int)` at `list<term>` still compile and give wrong runtime answers, so "~25 lines at one call site" is overstated.
- Q3 "answered/closed" is too strong: an inferred `Wrap<T>` returning `result<T, term>` called at `T = term` collapses silently (same hole as P03). The declaration rule held on 17 extra rows.
- P07: tagged/bare was 0.92–0.94 over 4 runs, a stable 6–8% tagged advantage, not "within noise". "No cost" survives; the explanation does not.
- P05 Gleam is circular (`gl1.gleam` defines its own `find`); "all four neighbours tag" rests on Erlang and Elixir only.
- The "2 of 25 examples break" count is misleading: Levels breaks only because the scratch build leaves `ParseAtom` bare; 7 option-heavy exemplars cannot be compiled here.
