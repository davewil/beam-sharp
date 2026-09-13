# F46 — a function as a value

**Status**      **done 2026-09-12** — 31 tests in `function_value_tests` and one roster pin in
                `corpus_tests`; 891 in the suite, up from 859. No new gate: the ticket's program
                is `examples/Shop/Pricing/`, which `check-examples.sh` refused at the `fn(` in
                its first signature before the build and compiles after it,
                `editor/bin/check-corpus.sh` reported an ERROR node on the same token before
                the grammar change and parses after, and the corpus roster gained four rows.
                Five `diagnoses:` blocks and two must-compile blocks in `LANGUAGE.md` §9 seen
                red on the tree first. `./bin/verify.sh` green **twice from a clean clone**
**Amended**     **2026-09-13, twice, by [ticket 76](../../wayfinder/issues/76-the-bare-name-lambda-and-the-arrows-extent.md)**
                ([ENG-368](https://linear.app/davewil/issue/ENG-368)) — 18 tests more, 909 in the
                suite, and `examples/Shop/Discounts/`: `n => e` is an expression everywhere and
                a guard is parsed below the lambda; a polymorphic call's arguments are
                re-checked under a solution chosen by each variable's variance in the declared
                return. See *Amended by ticket 76* below. `./bin/verify.sh` green **twice from
                a clean clone** at `2be9edc`, 40 stages each
**Implements**  [ticket 75](../../wayfinder/issues/75-a-function-as-a-value.md), resolved
                2026-09-12 in two rounds: the arrow `fn(T) -> U` as a type of the language,
                the lambda `(a, b) => e` in C#'s spelling, a name in value position, and a call
                through a bound name; [ticket 27 §(c)](../../wayfinder/issues/27-parametric-polymorphism.md)'s
                `Map<T, U>`, which F45 left at `not-yet`; [ticket 67](../../wayfinder/issues/67-stdlib-shape-as-a-principle.md)'s
                `List.Map`, `List.Filter` and `List.Fold`, one walker per module per operation
**Closes**      [ENG-365](https://linear.app/davewil/issue/ENG-365)
**Decides**     nothing the ticket settled. Two things the ticket's measurement did not reach
                are taken here as the build found them, recorded below and raised as
                [ENG-367](https://linear.app/davewil/issue/ENG-367) for David to confirm or
                overrule: the bare-name lambda is an **argument** and not a general expression,
                and a polymorphic callee's maximal extent is **variance-aware**. Ticket 76
                reversed the first and confirmed the second, which was unsound without a check
                beside it; both are built under *Amended by ticket 76*
**Depends on**  F45 (the polymorphic signature the arrow parameter sits in), F32 (the reserved
                qualifiers' lowering table), F5/F8 (the destructuring bind's irrefutability
                check, which a lambda parameter reuses), F25 (the corrected signature, which
                now prints an arrow), F18 (`ValidateAs<T>`, which now refuses one)

## What was there

`=>` lexed and opened a switch arm only; `ty()` had six parts and none was an arrow; a
lowercase name followed by `(` was a syntax error; a bare PascalCase name was not an
expression. `LANGUAGE.md` §9 shipped `Map<T, U>` as `not-yet` and the exemplar README's
*Lambdas* row read *out — the wall 25b stops on*. Ticket 75 measured eleven candidate
productions with yecc and priced the compiler delta seam by seam; ENG-365 restated that
delta and named the four refusals owed.

## The program

Ticket 75's program B, at `examples/Shop/Pricing/Pricing.bs`:

```csharp
module Shop.Pricing

public fn(int) -> int Rule(atom tier)
Rule(:standard) -> (cents) => cents
Rule(:member)   -> (cents) => cents - 100
Rule(:staff)    -> Free
Rule(_)         -> (cents) => cents

public int Charge(fn(int) -> int rule, int cents)
Charge(rule, cents) -> rule(cents)

public int Charged(atom tier, int cents)
Charged(tier, cents) -> Charge(Rule(tier), cents)

private int Free(int cents)
Free(_) -> 0

public int Owed(list<(atom, int)> pairs)
Owed(pairs) -> pairs |> List.Fold(0, (acc, (_, n)) => acc + n)

public list<int> Doubled(list<int> xs)
Doubled(xs) -> List.Map(xs, Double/1)

public list<int> Large(list<int> xs)
Large(xs) -> xs |> List.Filter(n => n > 100)

private int Double(int n)
Double(n) -> n * 2
```

```
$ bsc --src-root examples examples/Shop/Pricing/Pricing.bs Charged :member 250
150
$ bsc --src-root examples examples/Shop/Pricing/Pricing.bs Owed "[(:a, 3), (:b, 4)]"
7
$ bsc --src-root examples examples/Shop/Pricing/Pricing.bs Doubled "[1, 2, 3]"
[2, 4, 6]
```

It compiles to `'Rule'(standard) -> fun(Cents) -> Cents end`, `'Rule'(staff) -> fun 'Free'/1`
and `'Charge'(Rule, Cents) when is_integer(Cents) -> Rule(Cents)`, with `-spec 'Rule'(atom()) ->
fun((integer()) -> integer())`, the form every function's own spec was already built from
(read back through `erl_pp` on 2026-09-12). The exported `int` parameter carries its boundary
guard (F24, F37); the arrow parameter carries none, because a call through a non-function
raises `badfun`, which is the body objecting — 18 §1's rule for where a guard is owed.
`List.Fold` lowers to `bs@List@Fold@3(Pairs, 0, fun(Acc, {_, N}) -> Acc + N end)`, one walker
in this module, and `List.Map(xs, Double/1)` to `bs@List@Map@2(Xs, fun 'Double'/1)`.

And `LANGUAGE.md` §9's `Map<T, U>`, promoted from `not-yet` to shipped:

```csharp
public list<U> Map<T, U>(list<T> xs, fn(T) -> U f)
Map([], _)       -> []
Map([h, ..t], f) -> [f(h), ..Map(t, f)]

public list<atom> Tagged(list<int> xs)
Tagged(xs) -> Map(xs, (n) => n switch { 0 => :zero, _ => :some })
```

`Tagged` instantiates `T` at `int` from the list and `U` at `:zero | :some` from what its
lambda returns.

The four refusals ticket 75 owes, each as `bsc` prints it at the final SHA, from
`LANGUAGE.md` §9's `diagnoses:` blocks:

```
$ … Later(n) -> var twice = (k) => k * 2 / twice(n)
Later/Later.bs:4:29: error: a lambda in Later has no arrow to take its type from
  a lambda's type is the arrow its site expects — a call argument, a
  clause return, a record field — and nothing here expects one.
  Hand it to the site that expects it, or write a private function.
$ … Later(n) -> var f = Double / f(n), beside Double/1 and Double/2
Two/Two.bs:10:21: error: Later uses Double as a value, and nothing fixes which one
  Double is declared at /1, /2. A bare name reads its arity from the arrow
  its site expects; where nothing does, write it: `Double/1`.
$ … Oks(rs) -> rs |> List.Fold(0, (acc, (:ok, n)) => acc + n), over list<result<int, string>>
Oks/Oks.bs:4:47: error: a lambda in Oks can fail to match its parameter 2
  the pattern does not match:
    int | (:error, string)
  a lambda's parameter is one irrefutable pattern. Bind it, and
  switch on it in the body.
$ … Charge(rule, cents) -> rule(cents), with rule declared int
Bad/Bad.bs:4:24: error: Charge calls rule with 1 argument, and it is not a function of that arity
  rule has the type:
    int
  only a value whose type is an arrow of this arity can be called.
```

The third residual is the whole domain: `result<int, string>` is `int | (:error, string)`, and
`(:ok, n)` is a member of neither half — the value of a `result` is bare, and the pattern
that takes it apart is `n`. Two more, fixed by earlier tickets and enforced here:

```
$ … Check(x) -> ValidateAs<fn(int) -> int>(x)
Val/Val.bs:4:13: error: Check asks ValidateAs to check a function
  `fn(int) -> int` holds an arrow, and a function's type is not recoverable
  from the value at run time, so there is nothing to check.
  Take the function through a signature instead.
$ … public int Pick() / Pick() -> Free, with Free/1 private
Pick/Pick.bs:7:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    fn(int) -> int
  If `int` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public int | fn(int) -> int Pick()
```

```
$ bsc --src-root examples --api examples/Shop/Pricing/Pricing.bs
module Shop.Pricing
int Charge(fn(int) -> int, int)
int Charged(atom, int)
list<int> Doubled(list<int>)
list<int> Large(list<int>)
int Owed(list<(atom, int)>)
fn(int) -> int Rule(atom)
```

## What shipped

**The algebra.** A seventh part, `funs`, beside atoms, ints, tuples, lists, maps and bins: a
union of arrows `{[Domain], Codomain}`, or `top`, every function of every arity, which is what
`term` holds. Containment is pairwise — domain contravariant, codomain covariant, arity equal —
and stays pairwise because ticket 08 gives a function one arrow per arity. Subtraction is
all-or-nothing: an arrow contained in some arrow of the subtrahend leaves nothing, and one that
is not is kept whole, the over-approximation the map domain already takes. Union absorbs a
contained arrow; intersection answers with the arrows each side contains of the other, which
is exact whenever one contains the other and reachable today only through a pattern's type,
which has no fun part. Every site that enumerated six parts enumerates seven — the two
emptiness heads, openness, substitution, `components/1`, the three printers, `constituents/1`,
`guard_buckets/1` — plus the shape matches in `bs_check` and `bs_emit` that recognise a
record or an atom set by every other part being empty. An arrow is always inhabited; any
non-empty fun part is open; the description channel prints `fn(int) -> int`; the head channel
offers a binder, since an arrow has no pattern; the bucket is `{'fun', Arity}`, because
`is_function/2` decides an arity and nothing else, so two arrows of one arity in a bare union
are refused as `indiscriminable_union` and two of different arity stand — ticket 70's rule
applied.

**The grammar.** `fn` joins the keywords. `type_prim` gains `'fn' '(' type_list ')' '->'
type_expr` and its zero-arity form; the codomain runs as far as the type expression does
(ticket 75 Q6), one shift/reduce at the `|` resolved as the shift. `expr` gains `'(' expr_list
')' '=>' expr`, `'(' ')' '=>' expr`, `uident` and `uident '/' integer`; `call` gains `lident
'(' expr_list ')'`, the fourth form, which the pipe reaches through a new `bs_lower:pipe_into/3`
clause. `=>` enters the precedence table at 45, below every operator and above `raise`, so a
lambda's body runs as far right as it can. Lambda parameters parse as an `expr_list` and lower
through `to_param/1`, `to_match/1` with the one clause that lets a bare name introduce.
`yecc:file/2` with `{report, true}` measured **0 conflicts before and 4 after**, each named in
the grammar and each the intended shift: the `|` after a codomain, `rule(`, `Double(` and
`Double{`; `Double/`, `Double<` and the guard cases are settled by precedence. `binary_tests`'
zero-conflict assertion now pins the four, so a fifth is red by count. *Ticket 76's tier
split made the count five, all still named; see below.*

**The bare-name lambda is an argument.** *Reversed 2026-09-13 by ticket 76, below: the form is
an expression everywhere, and the guard is what moved.* Ticket 75 Q2 took `n => e` as a general expression and
priced two collisions on a switch arm's guard, `x when (n > 3) =>` and `x when flag =>`, on the
measurement that no guard in the corpus ends so. The second collision is wider than the round
saw: as an expression, `n =>` reads **every guard that ends in a name** as a lambda — `x when
x > m => 0` is F7's own test, and the shift left the arm with no `=>`. So the bare-name form
lives in an `arg` nonterminal reachable only inside an argument list, where the round's own
table measured it conflict-free and where every program in the record writes it,
`List.Filter(n => n > 100)`; the parenthesised form stays a general expression, and `x when (n
> 3) =>` stays the syntax error the round accepted. The editor grammar draws the same line with
an `_argument` rule.

**`not (n > 100)` is still taught.** It has exactly the shape of a call through a bound name,
and used to be a parse error `bs_diag` read the hint off. The `call -> lident '('` action
refuses the name `not` by name, so ticket 63's `no_negation` is raised as it always was.

**The checker.** An expression is synthesised by `type_of/3` as before; the sites that DECLARE a
type — a call argument, a clause return, a switch arm under one, a block's final expression, a
tuple or list component, a record field — hand it down through a new `expected/4`, which falls
through to `type_of/3` for every form but the three that need it. Threaded as an argument and
not a `#ctx` field, because every existing clause passes `C` to its operands and an expectation
in it would leak into every subexpression. A lambda against an arrow: each parameter is a
pattern checked irrefutable against the domain by `pattern_type/3` and `subtract/2`, the
destructuring bind's own rule, the residual as the refusal; the body is typed against the
codomain; the lambda's type is `fn(Domain) -> Body`, so the site's containment decides the
codomain half and a body outside it is reported by the site's own diagnostic,
`arg_not_accepted` or `return_not_declared`. A bare name at a fixed arity is its declared
signature read as an arrow, keyed `{Name, Arity}` in the callee table through
`unqualified_key/4`, local first then imports; with an expectation the arity is the arrow's,
without one it is the single declared arity or a refusal naming them all and the `Double/1`
spelling. A call through a bound name requires the name's type to be arrows of that arity and
nothing else — the top arrow `fn(none) -> term` is what a `term` holds, so a `term` is never
callable, ticket 11's rule falling out — with each argument contained in the meet of the
domains and the result the join of the codomains. The resolved key of every bare name rides
out on the diagnostic channel as an `{fname, Loc, Key}` note, partitioned off with the valve's
prune notes into a `fnames` table keyed by the token's position, and the emitter writes `fun
Name/Arity` or `fun Mod:Name/Arity` from it without resolving a second time.

**The polymorphic call.** `vars_in/2`, `tpl1/5`, `extent/1`, `solve/3`, `subst_tpl/2` and
`subst/2` each gained the arrow: a domain and a codomain are positions a share is read from,
and every arrow of the template's arity in the argument contributes, joined. The arguments are
typed in two passes: those that need no expectation first, solved; then each lambda, bare name
or form holding one is handed the template position with that partial solution substituted
and every open variable at `term`, so `Map(xs, (n) => n * 2)` types the lambda against
`fn(int) -> term` and `U` is read from what the body returns.

**The maximal extent is variance-aware.** F45 checked a caller's arguments against the callee's
signature with every variable erased to `term`, which ticket 37 measured as exact. An arrow
breaks that measurement: `fn(T) -> U` erased to `fn(term) -> term` is contained by nothing but
itself, and `Map`'s own recursive `Map(t, f)`, whose `f` is `fn('T') -> 'U'` under the opaque
binding, was refused at argument 2. `erased_sig/4` erases a variable to `term` in a covariant
position and to `none` in a contravariant one — the largest arrow of `fn(T) -> U`'s shape is
`fn(none) -> term` — and `extent/1` does the same for a template position. Every other position
erases as it did. *Alone this was unsound — the top arrow is an extent no arrow argument fails —
and ticket 76 confirmed it with the re-check it was missing; see below.*

**The reserved operations.** `List.Map`, `List.Filter` and `List.Fold` join the lowering table.
Each types the list first and hands the fun the element type as its expectation — `fn(Elem) ->
term`, `fn(Elem) -> bool`, `fn(Acc, Elem) -> term` — and reads its own result off the fun the
author handed over: `Map` returns a list of what it returns, `Filter` the list it was given,
`Fold` the accumulator. The accumulator is the seed joined with the fun's result, and the fun's
result depends on it, so `fold_fun/6` iterates: `List.Fold(0, (acc, n) => acc + n)` types `acc`
as `0` and returns `int`, so `acc` is `int` and the fun is typed once more; the least fixpoint
is reached in a step or two, and a fun still growing after three is typed over `term`. The
emitter's walkers take the fun as an argument, one per module per operation as `List.Sum` is,
`Map` and `Filter` accumulating reversed and turning the list round at the end.

**Scope and guards.** A lambda's parameters are readable in its body and nowhere else;
`expr_vars/1` subtracts them and `rebinds/3` refuses a parameter that reuses a name in scope or
repeats another, ticket 34's rule. A call through a bound name reads the name. `guard_call/1`
refuses a call through a bound name in a guard as `call_in_guard` and a lambda there as
`lambda_in_guard`, in the language's voice rather than `erlc`'s (F41).

**Fixed before the arrow existed, and now enforced.** `ValidateAs<T>` over a `T` holding an
arrow anywhere a validator would walk is refused as `validate_over_arrow` (ticket 11); the
emitter's `ty_clauses/4` raises if one reaches it. A foreign return holding an arrow is refused
by F40's `beyond_one_guard/1` with `why => arrow` (ticket 18 §2); the emitter's `type_test/3`
raises if one reaches it. `term`'s own fun part, `top`, passes both as `term` does.

**The printers.** `type_source/1` and `written/1` render `fn(int) -> int`, so the corrected
signature (F25) and `--api` (F17) print an arrow as the author writes it: `public int | fn(int)
-> int Pick()` pastes back and parses, and `--api` prints `fn(int) -> int Rule(atom)`.

**The record.** `LANGUAGE.md` §9 promotes `Map<T, U>` to shipped and gains *A function as a
value — shipped* with the corpus program, five `diagnoses:` blocks and the bare-name rule; §8's
pipe prose and the reserved-qualifier section stop saying the form is unbuilt; §18's row reads
shipped. `TOUR.md` chapter 9 quotes the corpus program, the appendix carries the four roster
rows and its count moves from 56 to 60, and two *Decided but not built* rows retire.
`CONTEXT.md`'s *Lambda* entry says where the bare form lives. The exemplar README's *Lambdas*
row closes and its spelling row is struck; `FRONTIER` re-measured 25b's wall past the lambda
to a bare PascalCase name in a tuple pattern. The compiler README's feature table gains the
row.

## Amended by ticket 76 (ENG-368, 2026-09-13)

Ticket 76 ruled on the two calls this build took. Both amendments were built test first: four of
F46.14's eight tests and four of F46.13's first six were red on the tree before either change, and
the rest hold what the ticket said must not move. The two `LANGUAGE.md` blocks the amendment adds
were run through `check-language.sh` against the compiler at `ec1046f`, where the `Bare` block was
BROKEN and the `diagnoses: instantiation_conflict` block published nothing, and are ok after.

**The guard is parsed below the lambda.** `expr` holds the three lambda productions — `(a, b) =>
e`, `() => e`, and `n => e` — over `expr_low`, which holds every production `expr` held before.
A body, a lambda's body, a switch arm's body, a `var` initialiser, a list item, a record field and
an `expr_list` take `expr`; a guard, `raise`'s operand, a refinement and the left of a bare `=`
take `expr_low`, as C# puts a `when` clause and a `throw` operand below its lambda. `arg` is gone.
`Right 45 '=>'` is removed, and the count did not move without it, so it was inert. `yecc:file/2`
with `{report, true}`: **4 before, 5 after**, the fifth `rule(` shifted from a second LALR state;
`binary_tests` pins five. The one-line variant `expr -> expr_low '=>' expr` counts four and reports
`1 + n => n` as a malformed lambda parameter; this grammar says `syntax error before: '=>'` there,
and says the same for `raise (k) => k`, where `raise ((k) => k)` parses. A lambda in a guard needs
a bracket of its own and is then refused as `lambda_in_guard`, so F46.12's program gained one.

The editor grammar has the same two tiers: `_expression` is the two lambdas over
`_expression_low`, and a guard, both operands of an operator, a pipe's left side, a switch's subject,
`with`'s receiver and `raise`'s reason take the lower tier, so `1 + n => n` is an ERROR node where
`bsc` says `syntax error before: '=>'`. The two pattern/expression conflicts move to
`_expression_low`, and no conflict is declared for the lambda. Two attempts were wrong on the way,
and neither was visible to `check-corpus.sh`: a precedence on the whole `bare_lambda` rule generated
cleanly and parsed `x when x > m => :above` as an ERROR, because a rule's precedence settles the
conflict before GLR can keep the reading that survives; and a guard-only lower tier left the
operands of an operator at the top, which accepted `1 + n => n`. The corpus now carries the forms:
`examples/Shop/Discounts/` returns `cents => …` from a clause, lists two bare lambdas, and guards
an arm with `c when c > floor =>`, so `check-examples.sh` compiles them and `check-corpus.sh` parses
them — 23 of 23.

**Arguments are re-checked under a solution chosen by the return's variance.** `solve/5` records,
per variable, lower bounds from covariant occurrences and upper bounds from occurrences under an
arrow's domain, each tagged with its argument; the polarity flips at every domain, so a nested
`fn(fn(T) -> U, T)` puts the inner `T` back at a lower bound. `solution/3` reads each variable's
polarity in the declared return and takes the join of its lower bounds where the return is
covariant in it or does not mention it, and the meet of its upper bounds where it is contravariant.
That is Pierce and Turner's minimal substitution (*Local Type Inference*, TOPLAS 22(1), 2000, §3
and §5.7, read from the paper for this amendment), taken as the paper takes it where a set is
empty: no lower bounds join to `none`, no upper bounds meet at `term`. An erased variable is `term`.
Each lower bound is compared with each upper bound on its own, so the refusal names the value an
argument supplies rather than a union it is part of.
Where the join of the lower bounds is not inside an upper bound, the call is refused:

```
$ bsc … Incs.bs          (Map<T, U> over list<string>, handed Inc/1)
Incs/Incs.bs:11:13: error: Incs calls Map with arguments that disagree about T
  argument 1 supplies T as:
    string
  argument 2 accepts T only as:
    int
  no T satisfies both, so a value from one would reach a function
  that does not take it.
```

Where one argument supplies the variable and bounds it — `Same(Len/1)`, whose result is not a
value its parameter takes — the message says `an argument that disagrees with itself` and names it
once. On the term channel it is `instantiation_conflict` with `callee`, `type_variable`,
`lower_argument`, `lower`, `upper_argument` and `upper`. It hands the author nothing to paste, so
it is not in `contractual()`. A refused call's result is `none`, so no `return_not_declared`
follows it. Otherwise each argument is checked against the extent first, which keeps every existing
residual as it was, and an argument that passes is checked again against the parameter the solution
instantiates: one diagnostic per argument.

**The arguments that need an expectation are typed in rounds.** `poly_args/4` types every other
argument against the extent, then hands each lambda, bare name or form holding one its position
under a PARTIAL solution — what every argument typed so far supplies, the lower bounds first,
`term` where nothing does — and `retype/8` types them again while that solution moves, at most
three rounds, then at the extent. It is not a result type and follows no variance. The rounds are
the code review's finding: typed once, over the singleton a literal supplies,
`Twice(3, (n) => n + 1)` handed its lambda `fn(3) -> …`, whose `int` result then escaped that `3`,
and a user-written `Fold(0, xs, (acc, n) => acc + n)` was refused the same way. Both compiled and
ran at `ec1046f` (probed on that commit's `bsc`) and do again; typed a second time over `int` the
lambda agrees with itself. It is the least fixpoint `fold_fun/6` already reaches for `List.Fold`.
The first version also bounded a variable at `none` from an argument not yet typed, so a lambda
beside a `switch` at a bare `T` was typed over nothing.

**What the build did not decide.** A variable the declared return holds in *both* positions,
`fn(T) -> T Same<T>(fn(T) -> T f)`, is the case ticket 76 left silent. It joins every occurrence,
lower and upper — the answer the compiler gave before ticket 76 — and a lower bound escaping an
upper one is refused as anywhere else. F46.13 asserts only that a call whose arguments agree is
accepted and one whose arguments disagree is refused, which every candidate rule gives. The paper's
invariant case differs — it takes a bound only when the two coincide and otherwise finds no
substitution — and a program whose meaning depends on the difference raises a ticket. None has met
it yet.

## Four things the build found

1. **A grammar measurement counts conflicts, not corpus shapes.** Ticket 75's table was
   right that `n => e` as an expression adds one shift/reduce, and wrong about what the shift
   reaches: every switch-arm guard ending in a name, not the two forms it listed. The suite
   found it in F7's test on the first run, which is the argument for running the whole suite
   after a grammar change rather than reading the conflict count. **Ruled by ticket 76**: the
   collision is C#'s too, and C# resolves it in the guard rather than in the lambda.
2. **Erasure has a variance.** Ticket 37's *"an argument is refused exactly when it escapes
   the maximal extent"* was measured over positions that are all covariant. An arrow's domain
   is the first contravariant position the algebra has had, and the extent there is the
   bottom. The recursive `Map(t, f)` was the probe that found it. **Ruled by ticket 76**: right,
   and not enough — 37's equivalence between the extent check and a successful instantiation
   held only under covariance, so the arguments are now re-checked under the solution.
3. **A `term` carries a fun part, and two walkers had to learn to pass it.** F40's
   foreign-return walk and `ValidateAs<T>`'s arrow refusal both first fired on `result<int,
   foreign_error>`, because `foreign_error` holds a `term` and `term`'s fun part is `top`.
   The top promises nothing and passes; an explicit arrow is what is refused.
4. **A guard refusal is wired in two places, and the second is a list of tags.** `guard_call/1`
   gained clauses for the two new nodes and both were unreachable: the walk that hands it
   subtrees names the node tags it stops at, and a clause for a tag not in that list is dead
   code that compiles. The code review asked for the two guard tests the build had not
   written, and both were red on the first run. Same class as F41's finding that a
   pattern refusal must cover the switch arm too.

## What is asserted, and where

`function_value_tests.erl`, at the boundary:

| Id | Asserts |
|---|---|
| F46.1 | ticket 75's program B: a lambda and a name as clause bodies, an arrow parameter called through; a tuple-pattern parameter takes a pair apart |
| F46.2 | `Double` bare and `Double/1` written, both lambda spellings, `Map`, `Filter` and `Fold` run |
| F46.3 | `Map<T, U>` solves `U` from the lambda's result at two types; declared narrower, refused |
| F46.4 | the four owed refusals by tag: `lambda_without_expectation`, `name_arity_unfixed` with both arities, `lambda_param_refuted` with the residual, `not_callable` for an `int` and for a wrong arity; one declared arity needs no expectation |
| F46.5 | an `int` where an arrow is declared is refused (the must-refuse that sees a forgotten seventh part); a wider domain is accepted and a narrower one refused; a body outside the codomain and a non-`bool` predicate are refused by the site |
| F46.6 | the corrected signature and `--api` print `fn(int) -> int` |
| F46.7 | a lambda closes over the clause; a parameter reusing an enclosing name is `rebinding`; an unbound name in the body is `unbound_variable` |
| F46.8 | `xs \| > Sum` stays a syntax error; `n \|> f()` is a call |
| F46.9 | a switch arm hands the clause's expected arrow to its lambda; the codomain absorbs a union |
| F46.10 | `ValidateAs<fn(int) -> int>` is `validate_over_arrow`; a foreign return declared as an arrow is `foreign_ret_beyond_one_guard` with `why => arrow`; two same-arity arrows in a bare union are `indiscriminable_union`, two of different arity are not |
| F46.11 | the corpus program runs through the CLI at two entry points |
| F46.12 | a call through a bound name in a guard is `call_in_guard`; a lambda in a guard, bracketed, is `lambda_in_guard` |
| F46.13 | `Map(xs, Inc/1)` over `list<string>` and `Map(xs, Len/1)` over `list<int>` are `instantiation_conflict` naming arguments 1 and 2; `Twice("a", Inc/1)` is refused and `Twice(3, Inc/1)` returns 5; `Compose(Inc/1, Double/1)` runs, its `A` the meet of its upper bounds; `Pick(prices, Cheap/1)` with `Cheap` over `int \| :free` returns `option<int>`; a variable in both positions of the return is accepted when its arguments agree and refused when they do not, and `Same(Len/1)` prints the one-argument message; `Twice(3, (n) => n + 1)` returns 5, a user-written `Fold` from a literal seed sums, and a `switch` beside a lambda at a bare `T` runs |
| F46.14 | ticket 76 round 1's programs: `n => e` as a clause body, a list element, a tuple component and an argument run; `x when (n > 3) =>`, `x when flag =>` and `x when x > m =>` guard their arms; `var twice = k => k * 2` reaches the checker as `lambda_without_expectation` |

`corpus_tests.erl`: four roster rows and the lambda probe's negative pin. `binary_tests.erl`:
the conflict count, now five. `check-examples.sh` and `editor/bin/check-corpus.sh`:
`examples/Shop/Discounts/`. `check-examples.sh` and `editor/bin/check-corpus.sh`:
`examples/Shop/Pricing/`. `check-language.sh`: §9's blocks, five of them `diagnoses:`.

## Out of scope, and what is owed

- **The corpus's `Rowed` and `Checked` are not respelled through `List.Map`.** ENG-365 asked
  for it and the shapes refuse it: `Rowed` is a *fallible* traverse that stops at the first
  error and threads it through `Prepend`, and `List.Map(rows, Build)` would return
  `list<result<OrderRow, FetchError>>` with no short-circuit — a different function, and F45's
  corpus program besides, which the tour quotes. `Checked` is one `ValidateAs<list<WireRow>>`
  call with no traverse in it. The brief's third line was written before either shape was
  looked at; the lambda spellings the corpus gained are `examples/Shop/Pricing/`'s `Owed`,
  `Doubled` and `Large`. A short-circuiting traverse over a fun — a `List.TryMap`, or a fold
  through `result` — is breadth under ticket 67 and not asked.
- ~~**The bare-name lambda as a general expression, and the variance-aware extent**~~ — no
  longer owed: ruled by ticket 76 and built under *Amended by ticket 76* above. Kept as it was
  written: both taken here as the build found them and raised as ENG-367 for David's
  confirmation. The first narrows ticket 75 Q2 by one position; the second amends ticket 37's
  measured rule at the one position it did not measure. **Ruled 2026-09-13, ticket 76
  (`wayfinder/issues/76-the-bare-name-lambda-and-the-arrows-extent.md`): the first is
  reversed** — `n => e` is an expression everywhere and the switch arm's guard is parsed at the
  tier below the lambda, C#'s own resolution of the same collision, measured in yecc at the
  four intended shifts — **and the second is confirmed and found unsound alone**: with the top
  arrow as the extent no arrow argument can fail `call/6`'s check, so `Map(xs, Inc/1)` over a
  `list<string>` compiles at `cd79a57` and crashes; arguments are re-checked under a solution
  chosen by each variable's variance in the declared return. Both built the same day —
  [ENG-368](https://linear.app/davewil/issue/ENG-368), failing tests first.
- **A typed-parameter lambda**, `(int n) => n * 2`, refused by ticket 75 Q5 and not built.
- **A lambda with a body of bindings** — the switch arm's lookahead reason, verbatim; a
  private function is the spelling.
- **Substituting a lambda's body at a `List.Map` site** — ticket 75 Q7 (ii), an optimisation
  `erlc` is free to make and this compiler does not, until an exemplar measures the difference.
- **An imported function's name in value position through a module path**, `Ints.Double` as a
  value — not asked by the ticket; the unqualified imported name resolves through
  `unqualified_key/4` and emits the remote fun form.
- **A lambda parameter over a record pattern**, `(Order o) => …` — `Order o` is not an
  expression, so the parameter grammar cannot reach it; `(o) => o switch { … }` is the
  spelling, and a ticket only if a program needs the head form.
- **The intersection of two unrelated arrows of one arity** is under-approximated, recorded
  in `bs_types` and unreachable while no pattern has a fun part.
