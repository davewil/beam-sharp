# Decision brief: ticket 66 (ENG-309), can a union name a pattern? `Handle(C c)` where `type C = A | B`

Not resolved here. Nothing under `wayfinder/` or Linear was touched. Measured at HEAD `1429fdc`
(the ticket measured at `6728799`) with `bsc` built from `compiler/src` at HEAD (diff against
`bsc-build/src` empty), OTP 29, elixir 1.20.4, gleam 1.19.1. All probes are under `probes/`;
paths below are relative to it. Where a probe needed a modified compiler, it ran on a **copy** of
the sources in scratch and the patch is kept as a `.diff` beside the probe. The repo compiler was
never modified.

## 0. The five exemplars re-run at HEAD (`run_exemplars.sh` -> `run_exemplars.out`)

| # | exemplar | ticket said | HEAD |
|---|---|---|---|
| 1 | `Take(C c)` signature, `Take(c) -> c.Id` | compiles | compiles, rc=0, silent. **Holds** |
| 2 | `Take(5)` | refused | refused: `Bad hands Take an argument it does not accept ... 5`. **Holds** |
| 3 | `Handle(D d)` + `Handle(C c)` | refused, `C is not a record` | refused, rc=1, same headline. **Holds, but the wording moved again**: the F53 line `a part is named by the part: Post(int n) beside Post(float f), one clause each` is now `a part is named by the part itself, lowercase - one clause taking int beside one taking float` (`bs_diag.erl:1896-1904`, reworded so `check-advice-compiles.sh` need not vouch for a printed clause). The ticket's second quote is stale |
| 4 | `Handle(A a)` / `Handle(B b)` duplicated | compiles | compiles, rc=0. **Holds** |
| 5 | `Bad(C c)` + `Bad(E e) -> :e` | warning, rc=0 | `warning: clause 3 of Bad matches no value of its input`, rc=0. **Holds** |

Two ticket details that no longer hold as written: `bs_diag.erl:952` is not the site any more
(`not_a_record` is built at `bs_diag.erl:562` and rendered at `:1896`; the raise sites are
`bs_check.erl:1874,1876` and `bs_emit.erl:543`); and the ticket's "OTP 28" is OTP 29 here.
Exemplar 5's message still prints the union in erased notation (`{ Kind: :'E5.A' } | ...`), as
the ticket says (ENG-307).

## 1. The sub-decisions, in dependency order

1. **(Gating) Which names may stand in the type-prefix position?** Only a union all of whose members
   are records, or any named type whose membership one emitted guard decides. This is ticket 66's #2.
   It also decides whether 66 and [85](../../wayfinder/issues/85-which-names-may-wear-the-type-prefix.md)
   resolve together (85 explicitly does not re-ask the record union, and says "if either is answered
   as a rule about names, the other is inside it").
2. *(follows)* Does the residual print `C c` or the members (66 #1)? It only matters once 1 says yes.
3. *(independent, separable)* Severity of exemplar 5's `vacuous_clause` (66 #3). It does not read
   from 1: exemplar 5 names `E`, a record outside `C`, and nothing about it needs a union name.
   It can be asked in the same round or later. See section 5.
4. *(a measurement, not a decision)* Interaction with ticket 15 section 1's collapse refusal (66 #4).
   Answer: none. See section 6.
5. *(not a ticket decision)* Nested position. `(C c, n)` in a tuple. It rides ENG-586, the work that
   lifts `type_prefix_nested` for parts. See section 4.

Ask 1 alone. The rest follow or are independent.

## 2. What is measured about the mechanism

**The grammar already parses `Handle(C c)`.** `bs_parser.yrl:508` is `pattern -> uident lident`,
producing `{p_bind, L, c, {p_rec, L, 'C', []}}`, the same node `Order o` makes. The refusal is
entirely in the checker/emitter: `record_of/3` (`bs_check.erl:1860-1876`) raises `not_a_record`
unless the name resolves to exactly one closed map carrying a singleton `Kind` atom. No yecc work.

**The emitter already has the slot a union-name needs.** A type prefix over a part (`Post(float a)`)
is stripped in `bs_emit:strip_rels/3` (`bs_emit.erl:629-637`) into `p_var` plus a guard conjunct, and
`tag_test/3` (`bs_emit.erl:590`) already builds `map_get('Kind', V) == Tag` as a surface node.
`fold_or/2` (`bs_emit.erl:465`) already ORs surface nodes. So `C c` is: a `p_var` and
`tag_test(V, A) or tag_test(V, B)` in the guard list.

**Prototype 1 (records-only), `prototype_union_name.diff`, 36 changed lines, scratch copy only:**
`bs_check.erl` gains `union_record_tags/2` (the record_of check, over a union: every member a
closed map with a singleton `Kind`) and one `pattern_type` branch returning the union of the members'
open-map types, exact; `bs_emit.erl` gains one `desugar` clause (`p_bind` over such a `p_rec` becomes
`{p_tags, L, Tags, V}`) and one `strip_rels` clause. Exhaustiveness needs nothing: it subtracts the
union (P2 below names the residual correctly).

Generated Erlang (`pp_abstr.escript` over the `.abstr`; exemplar 3 under the prototype, against exemplar 4
on stock, `out/proto/E3.abstr`, `out/stock/E4.abstr`):

```erlang
%% prototype, Handle(C c) + Handle(:none)           %% stock, exemplar 4 (A a / B b duplicated)
'Handle'(C)                                         'Handle'(_A = #{'Kind' := 'E4.A'}) -> c;
    when map_get('Kind', C) =:= 'E3.A'              'Handle'(_B = #{'Kind' := 'E4.B'}) -> c;
         orelse map_get('Kind', C) =:= 'E3.B' -> c; 'Handle'(none) -> none.
'Handle'(none) -> none.
```

`erlc -S` of both (`out/asm/E3.S`, `out/asm/E4.S`): with a trivial body both become one
`select_val` on `Kind` jumping to the same label. The union form costs one `bif map_get` where the
duplicated form has `is_map` + `get_map_elements`. At a trivial body the runtime is equivalent. This is why
the lowering is the same family as the existing record prefix: **one discriminant read, N literal
outcomes**.

Behaviour on values (`run_proto_values.sh` -> `.out`; every probe has a control that must be
`:other`): `term` parameter, `H(C c) -> :member; H(_) -> :other`: A -> `:member`, B -> `:member`,
**E record -> `:other`, `5` -> `:other`, `:none` -> `:other`**. Mixed `H(A a) / H(C c) / H(:none)`
(P6): A=11, B=22, none=0, and `c.Id` typechecks in the `C c` clause. Switch arm
`d switch { C c => :c, :none => :none }` (P9) works, since arms share the head's lowering. P4 (`C c`
then `A a`) gets `warning: clause 2 of H is unreachable` and P3 (`A a` then `C c`) compiles, because
the residual is `B` by then. `run_proto_cases.out` has the lot.

**Cost of the ticket's gap, measured (`measure_scale.sh` -> `measure_scale.out`).** A union of N
records, wider parameter `D = C | :none`, a four-line body, three shapes: `dup` (exemplar 4, N
clauses), `union` (prototype), `sig` (parameter typed `C`, today's plain case).
`handle` = abstract-form size of the function in words (`erts_debug:flat_size`), `beam` = bytes,
`ms` = median of 15 in-VM `bsc:status/2` runs.

| N | dup handle / beam / ms | union handle / beam / ms | sig handle / beam / ms |
|---|---|---|---|
| 2 | 639 / 1780 / 12.4 | 439 / 1624 / 9.6 | 269 / 1468 / 8.9 |
| 5 | 1545 / 2448 / 16.4 | 658 / 1736 / 14.1 | 269 / 1532 / 9.6 |
| 10 | 3055 / 3580 / 25.6 | 1023 / 1968 / 18.3 | 269 / 1640 / 13.6 |
| 20 | 6075 / 5824 / 48.6 | 1753 / 2392 / 46.3 | 269 / 1844 / 28.2 |

Slope per extra member: dup about 300 words and 225 bytes; union about 73 words and 43 bytes (a tag
test, not a body). The compile-time win is modest and noisy (min/med/max at N=20: dup 45.6/48.6/108 ms,
union 35.7/46.3/84 ms, medians overlap); only at N>=10 is it clearly outside the spread. The honest
headline is source and `.abstr` size, not speed. The body here is four lines. The duplicated cost
scales with the body, which is the author's cost: five members is five copies to keep in step.

Prototype 1 changes **nothing already shipped**: `corpus_proto.sh` compiles all 28 example modules on
stock and prototype and byte-compares diagnostics, exit codes and all 28 `.abstr` files: 0 differences.

## 3. The gating decision (66 #2) as programs

Ask this one question alone. A program that compiles under one answer and is refused under the other:

```csharp
record A { Id: int }
record B { Id: int }
type C = A | B
type D = C | :none            // C plus an atom

public atom H(term t)
H(C c)    -> :record          // (i)  union of records
H(:none)  -> :none
H(_)      -> :other

public atom G(term t)
G(D d)    -> :member          // (ii) a named type that is not a union of records
G(_)      -> :other
```

(i) compiles under B and C. (ii) compiles only under C. Under B it is refused, and the advice is
"write `C c` and `:none` as two clauses".

### Option A: leave it refused (status quo, with the cost above)

Exemplar 3 stays an error, exemplar 4 is the answer, and the duplication table is the price.
Compiler work: none, except the diagnostic should stop saying `C is not a record` about a name the
author correctly knows is a union (`bs_diag.erl:1896`). Counterargument for A, stated fairly: nothing
is wrong with the language, the plain case (a signature that types the parameter `C`) is already served
(exemplars 1, 2, `sig` column), and ticket 84 already chose "the cost of leaving every name refused is
one line of diagnostic" for the part analogue. Against A: that argument was made for parts, where two
clauses is the whole cost; here it is N clauses and N identical bodies.

### Option B: a union of records may wear the prefix (prototype 1)

Rule: `U x` is legal when `U` resolves, through aliases and flattening, to two or more records and
nothing else. `x` binds the whole value, typed by the residual. The test is the tag disjunction.

Compiler delta (the sites): `bs_check.erl:4924` `pattern_type({p_rec,...,[]})` gains the union branch
(`union_record_tags/2`, 17 lines); `bs_check.erl:5095` `child_type/3` must refuse the nested form (see
section 4); `bs_emit.erl:536-587` `desugar/2` one clause; `bs_emit.erl:629` `strip_rels/3` one clause;
`bs_diag.erl:1896` message reworded (a union of records is now accepted). Refused under B, with the
existing message (`run_proto_cases.out`: P7 `type U = A | B | int`, P10 `type D = C | :none`, P11
`type Amount = int | float`, P12 `type C = A | B | map<atom, term>`). Accepted under B: P8, `type C2 = C | F`
with `F` a record (aliases flatten to the member tags).

Evidence: sections 2 above and 6 below. The rule is the existing record prefix generalised from
"one tag" to "one of these tags", so it sits inside ticket 84's reading "one test decides" if that
test is read as one discriminant read. That reading is mine, not 84's text.

Strongest counterargument: **it is a rule about a kind of name, and 85 is about the same grammar
position.** After B, `Handle(C c)` is legal and `Post(Amount a)` (an alias to `int | float`, 85 (a)) is
refused, for a reason ("no single test decides") that the record union also fails by the letter: N
equalities are not one BEAM test. The language would hold two answers for one production. Also
the pattern takes a name, not a type expression, so `Handle(A | B c)` stays unwritable while `Handle(C c)`
works, which sits awkwardly with CONTEXT.md's "the name never enters the type algebra".

### Option C: any named type whose membership one emitted guard decides (prototype 2)

Rule: `T x` is legal for any alias `T` for which a guard sequence decides membership. The emitter
already owns this builder: `bs_emit:type_test/3` (`bs_emit.erl:1269-1313`, F42's foreign-return guard),
which is also ticket 09 section 4's own discriminability criterion ("a member is discriminable iff the compiler
can synthesise a BEAM guard expression that decides it").

`type_test_probe.escript` on the existing builder (`type_test_probe.out`):

```
C = A | B           is_map(V) andalso is_integer(map_get('Id',V)) andalso map_get('Kind',V) =:= 'M.A' orelse ...B
D = A | B | :none   V =:= none orelse <the C test>
Amount = int|float  is_integer(V) orelse is_float(V)
Meters (range)      is_integer(V) andalso V >= 0
list<int>           V =:= [] orelse is_list(V) andalso V =/= [] andalso is_integer(hd(V))     <- head only
string              REFUSED error:{foreign_return_guard,string}
```

Prototype 2 (`prototype2_any_named_type.diff`, +19 lines over prototype 1, `run_proto2_cases.out`):
`G(D d)` over `term` works (A -> `:member`, `:none` -> `:member`, `:other` and `5` -> `:other`); ticket 85
(a) `H(Amount a)` over `Amount | :none` works (5, 2.5 -> `:amount`); 85 (b) `H(Meters m)` works
(3 -> `:m`, -3 -> `:neg`). So C answers 66 #2 and both of 85's named cases in one rule.

Two measured defects that decide how C would have to be built:

1. **`list<int>` is accepted and wrong.** `type Names = list<int>`; `H(Names n)` compiles, and
   `H([1, :x])` returns `:names` (`run_proto2_g3.out`). The builder tests the head only. This is
   exactly why ticket 84 refused `list<int>`. So C needs `bs_types:part_test/1`'s decidability
   predicate placed in front of `type_test/3`, not just `type_test/3`. The prototype has no such gate, so its
   `list<int>` acceptance is an artefact of the prototype, not a rule.
2. **A different test from the record prefix.** `type_test` checks field presence and value
   (`is_map_key`/`is_integer(map_get('Id',V))`), the record prefix `A a` checks the tag only. Under
   prototype 2, `{ Kind = :'G1.A' }` with no `Id` field is `:other`, under `A a` it matches. The same
   record union would test differently by whether it is named alone or inside a wider alias. C would have
   to special-case records to keep them tag-only, so **C does not subsume B's lowering**.

Strongest counterargument against C: ticket 85 wrote down why (a) is refused: `type Amount = int |
float` asked the prefix to match a whole union "which no single test decides", and CONTEXT.md's
**Type prefix** entry says so ("A type no single test decides cannot wear it"). C replaces "one test"
by "one guard sequence" and turns that glossary sentence false. It is the bigger decision and
85 should make it, with `term x` and refinements, not a record-union ticket.

## 4. Nested position (found, not asked)

Prototype 1 on `H((C c, n))` (P5) crashes the emitter: `function_clause` in `bs_emit:pattern/2` on
`{p_tags,...}`. Every new pattern node the checker admits must be refused nested until the lowering
exists, as F53's `child_type({p_type,...})` does (`bs_check.erl:5095`, `type_prefix_nested`). Ticket 89
Q8 decided, on 2026-10-04, that a part prefix may nest and removed that refusal's reason (ENG-586);
the nested lowering that lands for `p_test` ("a fresh variable in the pattern and the part's test in
the guard") is the same shape `p_tags` needs. So union-name nesting should ride ENG-586, and under
B or C the checker needs the nested refusal in the interim. CONTEXT.md's **Type prefix** entry still
says "never nested inside another pattern", already stale against 89 A8.

## 5. Severity of exemplar 5 (66 #3), separable from section 3

Raised as an error. The compiler's warnings are all one class, dead code. There are seven sites
(`bs_check.erl:3941,3943,3945` arms, `:4025` generator, `:4785,4786,4787` clauses: vacuous,
unsatisfiable guard, unreachable). Everything else is an error. Note that exhaustiveness is a hard
error with no warning level (ticket 12 section 1), and a catch-all over a closed residual is an error
(12 section 2); the precedent in the compiler for promoting a vacuity is `map_arm_deferred`
(`bs_check.erl:3939`: "a warning would allow a dead arm to compile", where the arm's semantics are not
built).

Prior decisions that bear (found by grep, not in the ticket): LANGUAGE.md:1159 says a dead arm "is a
**warning** rather than an error: the program still compiles, because the arm changes nothing";
LANGUAGE.md:2085 says the same for a vacuous generator; and **ticket 89 Q2/A2 (David, 2026-10-04,
after this ticket was filed)** decided a vacuous four-element `DOWN` clause "stays the
`vacuous_clause` warning", amending ticket 14 section 6's "a compile error": "naming the type is what
makes the mis-shape speak, and the warning is that speech". That is a close precedent against 3b below
and also the reason 3c may be consistent with it, since the `DOWN` clause names no type.

Three variants, all measured in scratch copies (`severity_matrix.sh` -> `severity_matrix.out`; the stock
column is the control and is rc=0 everywhere):

| variant | patch | E5 (`Bad(E e)`, names a type) | E6 (`Note((:some, s))`, structural) |
|---|---|---|---|
| 3a stock | none | rc=0 | rc=0 |
| 3b promote every `vacuous_clause` | `promotion_vacuous_clause.diff`, 2 lines | rc=1 | rc=1 |
| 3c promote it only when the head names a type | `promotion_vacuous_when_type_named.diff`, about 12 lines | rc=1 | rc=0 |

Does promotion break anything shipped? (`corpus_promo.sh`, `run_gates_both.sh`, `eunit_*`)
- **Examples: no.** 28 modules under `compiler/examples`, 0 warnings emitted at HEAD, so 0 diverge
  (`corpus_promo.out`; also for the all-seven variant, `corpus_promoall.out`).
- **Gates: no.** All 37 `compiler/bin/check-*.sh` give the same exit code on stock and promoted
  (`run_gates_both.out`; `check-helper-agrees.sh` is rc=1 on both, it needs the escript/rebar3 and
  says so). Same for all seven promoted (`run_gates_promoall.out`). Caveat: no gate reads severity,
  `check-language.sh` matches the `diagnoses:` tag only, so it would pass while LANGUAGE.md:1159 and
  F37's "checker says so as a warning" go false. The gate is blind there, not reassuring.
- **eunit (1508 tests, via a shim `bsc` because rebar3 is unavailable): 9 pre-existing environment
  failures on stock** (`eunit_full_failed_base.txt`). Promoting `vacuous_clause` alone adds exactly 4:
  `heads_tests` x3 and `down_view_tests:a_misshaped_down_clause_is_reported_test`, all asserting
  the warning (`eunit_full_failed_promo.txt`). Promoting all seven adds 18
  (`eunit_promoall.out`). 3c errors on a strict subset of 3b's clauses, and its run over every module that went red under 3b or all-seven (`eunit_promonamed_subset.sh` -> `eunit_subset_promonamed.out`) fails only the 2 environment failures that stock also has: **0 added** (the full-suite run under 3c was abandoned as too slow, so that is the subset, not the 1508).
- The message text hard-codes `warning:` (`bs_diag.erl:1167`), so a promoted diagnostic still prints
  "warning" while exiting 1 (seen in the probe). Any real promotion edits `message/1`, and
  `check-diagnostics.sh`/`diagnostic_term_tests` read these.

Counterargument against promotion: dead code is harmless and the project has one rule for it (seven
sites, 89 A2). Counterargument against leaving it: the ask is "pattern matching from `C` should error if not in the union",
and exemplar 5 is exactly a pattern naming a type that is not in the input; the compiler already
knows (`vacuous_clause` is the type-membership failure, distinct from `unreachable_clause` shadowing).

## 6. Interaction with ticket 15 section 1 (66 #4), measured

`run_collapse.sh` -> `run_collapse.out`, stock `bsc`.
- The collapse/absorption refusal fires at the **declaration**, before any pattern:
  `type C = A | B` then `type C2 = C | A` is refused (Q2: `A is absorbed by A | B ... Delete the
  absorbed member`). So a `C2 c` pattern cannot be reached with an absorbed member. The record-subtype
  case the brief asked about is only reachable that way: records are nominal by minted tag, so no record is a
  subtype of another, only a member of an alias that lists it twice.
- `type C = A | B | map<atom, term>` compiles (Q1). The records are not absorbed by the domain map,
  so `C` is not all-record and Option B refuses `C c` there, correctly (the map member has no tag).
- `type C = A | B | :ok` (Q3) and a union with a part (`A | B | int`, P7): legal types, refused as
  names by B, admitted by C.
- `C | (:error, binary)` (Q4, the 15 section 1 failure channel over a record union) is legal and
  collapses nothing.
Conclusion: no new interaction under B. A union name can only be written for a type that has already
been normalised, so the pattern sees the survivors. Under C the question is moot too: absorption is
declaration-time.

## 7. Residual printing (66 #1), what moves

Today (`run_residual.sh` -> `run_residual.out`): with `H(:none)` the only clause over
`D = C | :none`, the diagnostic prints two lines, `H(A a) -> ...` and `H(B b) -> ...`
(JSON `pasteable`: `["H(A a) -> ...","H(B b) -> ..."]`; `residual` prints the erased
`({ Kind: :'R1.A' } | { Kind: :'R1.B' })`). The printer is `bs_check.record_names/1`
(`bs_check.erl:4690`, keyed by **tag**, with "multi-tag aliases are excluded") consumed by
`bs_diag:pasteable/3` (`bs_diag.erl:2230`) and `bs_types:head_combos/2`.

- **Members spelled out (status quo):** nothing moves. `check-residual-pasteable.sh`'s `RecordUnion`
  fixture (`bin/fixtures/residual/RecordUnion`) leaves one member (`Which(Invoice i) -> ...`), which no
  alias can name either way, so the roster row and `refused_spelling` are untouched, and each printed
  head pastes into the pre-feature and post-feature compiler. The `C c` form is available to the
  author who sees two lines.
- **Print `C c`:** a second table keyed by tag **set** (not tag), an arbitrary pick among aliases over the
  same set (CONTEXT.md **Alias**: "two names over the same set are the same type"; `type C2 = A | B`
  next to `C` makes it ambiguous), a partial residual (`A` only) still printed as a member, and a
  new roster row with a two-member residual because the existing fixture cannot exercise it. The diagnostic would
  depend on which aliases are in scope.
Recommendation: members spelled out. It is gate-neutral and keeps the printer free of alias identity.

## 8. Neighbours

Install note: Elixir's installed tree has `ebin` only (no `.ex` sources), so "real lib grep" is
unavailable (tried `find -name '*.ex'`, and grep of the docs chunks, `elixir/docs_grep.out`: nothing
relevant). Elm cannot compile here (`package.elm-lang.org` returns 403 through the proxy, the package cache is empty;
`elm_make.out`), so **no Elm claim is made**.

- **Erlang** has no or-pattern. `orpat_bad.erl`: `f(#{kind := a, id := I} | #{kind := b, id := I})` is
  `syntax error before: '|'` (`erlang/orpat_bad.out`). The idiom is a guard disjunction with the whole
  value bound: `erlang/guard_idiom.erl` runs (A,B -> member, E and `5` -> other). Real sources:
  `ssl-11.7.8/src/tls_dtls_client_connection.erl:146-150` (`is_record(Msg, server_key_exchange) orelse
  is_record(Msg, hello_request) orelse ...`) and `compiler-10.0.7/src/beam_types.erl:63-66`
  (`?IS_LIST_TYPE`, `?IS_NUMBER_TYPE`: the union spelled once as a macro, which is what `type C` is for B#).
  That is also exactly what prototype 1 emits.
- **Elixir** runs it (`elixir/union_idiom.out`): `when is_struct(x, A) or is_struct(x, B)` and
  `%module{} = x when module in [A, B]` both give A,B -> `{:member, id}` and E, `5` -> `:other`; a third
  clause for `E` after the disjunction is not diagnosed. `Kernel.is_struct/2` docs (installed docs chunk,
  `elixir/docs.out`): "does not check that name exists and is a valid struct". Elixir has no named
  union and no check that the guard's modules are inhabitants.
- **Gleam 1.19.1** has alternative patterns with a shared binding (`gleam/p1_variants.out`):
  `A(id: i) | B(id: i) -> i` compiles. The control: alternatives binding `i` at `Int` and `String` is
  `error: Type mismatch`; a missing variant is `error: Inexhaustive patterns ... E(id:)`; a repeated
  pattern is `warning: Unreachable pattern` (**a warning, relevant to 66 #3**). Whole-value binding
  needs `A(..) as c | B(..) as c`; the first attempt `A(..) | B(..) as c` fails with `Extra
  alternative pattern variable` (`gleam/attempts/`, kept). **`c` is typed `Shape`, the whole custom
  type**, so `take_ab(c: Shape)` must still handle `E`: Gleam has no sub-union to name. Gleam solves the
  duplicated-body cost with a pattern-level or, B# would solve it with a type-level name. Its type-level
  answer is to split the custom type.
- **Elm:** source unavailable (above).

## 9. Recommendation

1. **Gating (66 #2): Option B, records-only.** Ask: "may `C c` name a union of records?" Reasons:
   the whole feature is 36 lines over mechanisms the compiler already has; it changes no example or
   `.abstr`; the cost it removes is measured and linear (300 words and 225 B of duplicated body per member);
   it is the record prefix's own mechanism (tag equality), while C replaces ticket 84's "one test"
   criterion and falsifies a CONTEXT.md sentence, and C's general guard builder is not safe on
   `list<int>` and tests records more deeply than the record prefix does. B is not a dead end:
   C would need B's tag-only lowering as its record case. Note the coupling the task asked about: **85 is
   not resolved by B**; its (a) and (b) stay refused with their current advice, and 85 can adopt C's
   generalisation later with no rework of B. If David would rather settle both names at once, C is the
   program in section 3 (ii), and 85 should then be asked with `list<int>`'s predicate in front.
2. **Residual (66 #1): members spelled out.** Gate-neutral.
3. **Severity (66 #3), independent: 3c**, error only when the head names a type. It honours "pattern
   matching from C should error if not in the union", breaks 0 examples and 0 gates, and is consistent with
   89 A2 (the `DOWN` tuple names no type). Cost to state: the eunit tests that assert the
   warning (4 for 3b, 0 for 3c), the `message/1` text, and LANGUAGE.md/F37 prose that no gate checks. If David prefers one
   rule for all dead code, 3a (keep) is the cheap answer and 89 A2 is its precedent.
4. **Collapse (66 #4): no interaction.** Nothing to decide.

## Probe index (all under `probes/`)

| file | re-run | supports |
|---|---|---|
| `run_exemplars.sh` / `.out` | `probes/run_exemplars.sh` | section 0: the five exemplars at HEAD |
| `pp_abstr.escript`, `out/` | `escript pp_abstr.escript out/proto/E3.abstr` | generated Erlang, prototype vs exemplar 4; `out/asm/*.S` are the `erlc -S` of both |
| `prototype_union_name.diff` | read | prototype 1 (36 changed lines) |
| `run_proto_cases.sh` / `.out`, `proto_cases/` | `probes/run_proto_cases.sh` | P1..P9: fallthrough, residual, overlap, nested crash (P5), refusals (P7), switch arm |
| `run_proto_values.sh` / `.out` | same | behaviour on member / non-member values |
| `gen_union_n.sh`, `measure_scale.sh` / `.out` | `probes/measure_scale.sh` | section 2 size and compile-time table (dup / union / sig, N=2,5,10,20) |
| `corpus_proto.sh` / `.out` | same | prototype 1 changes 0 of 28 examples |
| `type_test_probe.escript` / `.out` | `escript ... $S/bsc-build/ebin $S/66/te` (see header) | Option C: existing `type_test/3` shapes, `list<int>` head-only |
| `prototype2_any_named_type.diff`, `run_proto2_cases.sh` / `.out`, `run_proto2_g3.out`, `proto2_cases/` | `probes/run_proto2_cases.sh` | Option C prototype, 85 (a)/(b), `list<int>` unsoundness |
| `run_residual.sh` / `.out` | same | section 7 |
| `run_collapse.sh` / `.out`, `collapse_cases/` | same | section 6 |
| `severity_matrix.sh` / `.out`, three `promotion_*.diff` | same | section 5, 3a/3b/3c |
| `corpus_promo.sh` / `.out`, `corpus_promoall.sh` / `.out` | same | 0 examples diverge when promoted |
| `run_gates_both.sh` / `.out`, `run_gates_promoall.sh` / `.out` | same (about 6 min each) | 0 gates diverge |
| `eunit_promoall.sh`, `eunit_promonamed_subset.sh`, `eunit_full_failed_*.txt`, `eunit_promoall.out`, `eunit_subset_promonamed.out` | same | tests that fail under each promotion |
| `erlang/`, `elixir/`, `gleam/` (`p1`, `p2`, `attempts/`), `elm_make.out`, `elm/` | each file's header | section 8 |
| `side/` | n/a | a body ending `(:ok, d + 1)` after a `var` line parses as a call `a (...)`: a newline quirk I hit writing the scale generator; not pursued |

Probes that failed or were redone, kept: `gleam/attempts/p2_first_attempt*` (wrong `as` placement);
the first `measure_scale.sh` crashed (it used `bsc:main`, which halts the VM) and was changed to
`bsc:status/2`; the first eunit pass without an escript shim hid 499 environment failures, so the
shim-based `eunit_full_*` runs are the ones reported; `severity_matrix.sh` first printed `rc=0` in
every cell because `$?` was read after a command substitution, and was fixed (the stock column is the control).

Scratch artefacts (compiler copies, trees) are in `scratchpad/66/`. Stray `compiler/_build` and
`*.abstr`/`*.beam` that the test runs wrote into the repo were removed (gitignored, mine).

## Errata from independent verification (verification.md)

The verifier rebuilt stock from HEAD and applied each `.diff` to a fresh copy. No probe is patched-to-pass, hard-coded or filtered. Corrections:

- **"0 of 37 gates" is overstated.** With the compiler shim replaced by `exit 7`, 34 of 37 gates go red; `check-feature-scenarios`, `check-no-silent-skip` and `check-record-idiom` stay green and cannot see any compiler change, and `check-helper-agrees` is red at baseline. Effective count: **0 of 33 informative gates**. "No gate reads severity" is not measured; 10 gates mention "warning".
- **"28 examples byte-identical" is vacuous for union-versus-duplicated equivalence.** Stock refuses `C c`, so no example uses the new syntax and any additive patch would pass. It supports only "changes nothing shipped"; section 9 leaning on it as a reason for B is weak. The corpus run also skips `compiler/examples/exemplars/` (46 files, none compile on stock). The harness itself is sensitive (a renamed variable prefix reports 2 differences).
- **Mild circularity in the 3c matrix** (E5 vs E6 use two inputs the predicate was written to separate). The scale table uses byte-identical bodies, the best case for the union; a shared-helper alternative was not measured.
- **Section 9's "0 for 3c" drops a qualifier** that section 5 states: the full 1508-test suite run for 3c was abandoned, and the figure is for the nine affected modules only. 3b adds exactly 4 failures; 3c adds 0 in those modules; promoting all seven warnings adds 19 newly failing tests (the brief's 18 is a net figure).
- **Scale numbers:** at N=20 the verifier got 5844 vs 2416 bytes against the brief's 5824 vs 2392 (longer scratch path; ratios unchanged).
- **Option C's `list<int>` unsoundness** was re-derived independently: `[1, :x]` returns `:ints` on the prototype, because it lacks `part_test` gating. Record prefix versus `type_test` depth also confirmed.
- **Citations:** `map_arm_deferred` is at `bs_check.erl:3933-3935`, not 3939. The quote "if either is answered as a rule about names, the other is inside it" is ticket 66 line 145, not 85 (85 line 74 says the equivalent).
- Elm: no claim is made (registry blocked); Gleam `c: Shape` probe and Elixir idiom 3 do not discriminate what they are cited for.
