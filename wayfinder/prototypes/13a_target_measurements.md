# PROTOTYPE 13a — measuring the two live compilation targets

> Measured on this machine, Erlang/OTP 28.5 (`erts-16.4`), for ticket
> [13](../issues/13-compilation-target-decision.md). Every claim below is `local` evidence —
> commands and outputs given — not citation. Ticket 02 established most of these by reading;
> this file observes them.

---

## 1. `erlc +from_abstr` works, with no `.erl` on disk

The `.abstr` file format is a **sequence of terms, one per form**, each terminated with `.` —
*not* a single list of forms. Feeding it a list crashes `erl_lint`:

```
q.abstr: internal error in pass lint_module:
exception error: bad argument
  in function  element/2
     called as element(2, [{attribute,{1,1},file,{"q.erl",1}}, ...])
     *** argument 2: not a tuple
```

Written correctly — `[io_lib:format("~p.~n",[F]) || F <- Forms]` — it compiles with the source
file removed from the directory entirely:

```
$ erlc +from_abstr +debug_info q.abstr
FROM_ABSTR OK
$ q:demo(1)
2
```

**This is what decouples the frontend's host language from the target.** A beam-sharp frontend
written in any language can emit `.abstr` text and shell out to `erlc`.

## 2. `-spec` survives the Abstract Format path; the Core Erlang path loses it silently

Same source, two routes, inspecting the compiled beam's abstract chunk.

**Abstract Format:**

```erlang
specs in abstract chunk: 1
[{attribute,{3,2},spec,
   {{demo,1},[{type,{3,11},'fun',
     [{type,{3,11},product,[{type,{3,12},integer,[]}]},
      {type,{3,26},integer,[]}]}]}}]
```

**Core Erlang** (`erlc +to_core q.erl` then `erlc +from_core +debug_info q.core`):

```erlang
exit=0
abstract_code chunk from .core build: {ok,{q,[{abstract_code,{raw_abstract_v1,[]}}]}}
demo(1) = 2
```

Three things matter here, and the third is the one ticket 02 understated:

- The build **exits 0 and emits no warning**.
- The module **works** — this is not a broken build.
- The abstract chunk is **present but empty**, not absent. A missing chunk is something a tool
  can notice and complain about; an empty one is something Dialyzer reads successfully and
  learns nothing from. Silent success is the worst available shape for a safety tool, and it is
  the same failure shape as ticket 10's uninterned-atom trap — both are silent failures in the
  codegen layer.

## 3. The choice is a one-way door, not a rung on a ladder

Ticket 02 framed the three targets as a ladder of increasing cost. The reversibility measurement
reframes it:

| Direction | Result |
|---|---|
| `.abstr` → Core Erlang | ✅ `erlc +from_abstr +to_core` — OTP performs the translation |
| `.core` → abstract forms | ❌ `{raw_abstract_v1,[]}` — unrecoverable |

Core Erlang generated *out of* the emitted `.abstr`, showing both the `file` attributes and
`erlc`'s synthesised failure clause:

```erlang
module 'Shop.Orders.Order' ['apply'/1, 'module_info'/0, 'module_info'/1, 'total'/1]
    attributes ['file' = [{"Order/Apply.bs",1}], 'file' = [{"Order/Total.bs",1}]]
'apply'/1 =
    %% Line 7
    ( fun (_0) ->
      ( case ( _0 -| [{'function',{'apply',1}}] ) of
          <1> when 'true' -> 'ok'
          ( <_1> when 'true' ->            %% <- erlc's match_fail arm, ticket 12 §6
```

**The Abstract Format strictly dominates Core Erlang on reversibility.** Choosing it forfeits
nothing that could not be recovered with a compiler flag; choosing Core forfeits the abstract
chunk irrecoverably.

## 4. `erlc` enforces module-name/filename matching on the `from_abstr` path

```
/…/agg.beam: Module name 'Shop.Orders.Order' does not match file name 'agg'
```

Renaming the input to `Shop.Orders.Order.abstr` compiles. A dotted atom module name is otherwise
fine — this is Elixir's convention and it works unchanged. Relevant to the map's open
**module and namespace system** question: whatever atom a module identifier lowers to, the
emitted filename must match it.

## 5. Dialyzer does not complain about a widened `-spec` by default

```
$ dialyzer --help
  -Wunderspecs ***
  -Wspecdiffs ***
*** Identifies options that turn on warnings rather than turning them off.
```

Both flags **turn warnings on**, so they are off by default. A `-spec` that is wider than the
true type — which ticket 13 §5 requires wherever a set-theoretic type has no Erlang spelling —
is silent unless a consumer explicitly opts in. Widening costs precision, not noise.

---

## What was *not* measured

- **`+from_abstr` on any release other than OTP 28.5.** Only OTP 28.5 is installed here. Ticket
  13 §6 pins support to the current and previous two majors, so the oldest supported release
  needs this confirming before that range is real.
- **Cross-release Abstract Format churn.** Cannot be observed from a single installed OTP; this
  is precisely what ticket 13 §4's CI matrix exists to catch.
