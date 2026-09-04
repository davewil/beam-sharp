# 10 — Atoms in a C# skin

Type: grilling
Status: resolved
Blocked by: 01, 09

## Answer — an open universe of singletons, two keyword atoms, and no way to mint

The sigil was already settled (`:atom`, prototype 01g). What this session settled is the
**typing story**, and it fell out of ticket 09 more directly than the ticket anticipated: the
fork the ticket was built on ("declare atoms before use, trading ergonomics for leak safety
and better exhaustiveness") is **not available**, because it contradicts a closed decision.
Gleam, which took that fork, supplies the empirical case against it.

### 1. The universe is open; `:ok` is a singleton, `atom` is the cofinite top

**`:ok` is the singleton type containing exactly the value `:ok`. `atom` is the union of all
of them — an infinite set with a cofinite representation. Writing a literal is the only way an
atom comes into being; nothing declares one.**

This is not really a free choice. Ticket 09 §4 already leans on it: its normalisation rule
says `:ok | atom` *is* `atom`, which only type-checks if `:ok` is a set of one value and
`atom` is the union of all such sets. Half the answer was load-bearing elsewhere in the map
before this ticket was opened.

Verified against a shipping implementation of the same theory (Elixir 1.19.5,
`Module.Types.Descr`):

| Type | Internal representation |
|---|---|
| `:ok` | `%{atom: {:union, %{ok: []}}}` |
| `atom()` | `%{atom: {:negation, %{}}}` — literally "the negation of nothing" |
| `atom() and not :ok` | `%{atom: {:negation, %{ok: []}}}` |
| `:ok \| atom()` | `%{atom: {:negation, %{}}}` — i.e. `atom()` |
| `boolean()` | `%{atom: {:union, %{false: [], true: []}}}` |

So ticket 09's normalisation rule is **verified rather than asserted**, and the cofinite
residual is a real representation rather than a theoretical one.

**How a function says it accepts exactly `:ok | :error`:** it writes that, or a `type` alias
naming it. There is no other construct, per ticket 09 §2.

**The accepted cost.** Exhaustiveness residuals come in two strengths:

```
type Outcome = :ok | :error;

Handle(Outcome o) ->
  Handle(:ok) -> ...;
  // error: missing case :error              <- a LIST. The agent can write it.

Describe(atom a) ->
  Describe(:ok) -> ...;
  // error: missing case atom and not :ok    <- COFINITE. Needs a catch-all.
```

Ticket 04's promise — the residual *is* the missing case, handed to an agent in a loop —
holds over a declared union and degrades over bare `atom` to "you need a catch-all here."
That degradation is real and is accepted rather than mitigated. A warning on bare `atom`
parameters was considered and rejected: ticket 09 §4 was firm that warnings get ignored
(Caramel shipped output with Warning 8 live), and ticket 12 may want to make it an error.

#### Why declare-before-use is not available

It is not merely worse; it contradicts ticket 09. That ticket chose *"no syntax that declares
a union — only syntax that names a type"*, specifically so there is one exhaustiveness story
**by construction rather than by rule**. Declare-before-use would make `type Outcome = :ok |
:error;` load-bearing — the declaration would bring `:ok` into existence — where ticket 09
made it pure aliasing whose name never enters the algebra. Those are contradictory readings of
one line of source.

It also fails on ticket 09 §5's own argument, unchanged: a closed atom universe is
unenforceable across the Erlang boundary, so it would be compile-time-true and runtime-false —
ticket 06's third outcome reintroduced by design.

**And Gleam supplies the empirical case.** It took exactly this fork and needed a carve-out
immediately — see §7.

#### What the losing side costs

**Typo safety**, in principle: with no declaration, `:cancelled` and `:canceled` are unrelated
types and nothing objects. In practice this mostly evaporates, because **the function
signature is the declaration site for the permitted set** (ticket 04, restated in ticket 09
§7). Inside a function whose parameter is `Outcome`, a clause head matching `:okay` has empty
intersection with the declared parameter type — a type error from machinery already committed
to. The exposure is confined to positions where no declared type is in scope, i.e. `dynamic`
positions, which belong to ticket 11.

### 2. `true` and `false` are the only keyword atoms; `bool` is a ~~prelude alias~~ builtin *(corrected 2026-09-03)*

On the BEAM, booleans *are* atoms (`is_atom(true)` → `true`, `atom_to_binary(true)` →
`<<"true">>`). Elixir goes further and makes its keywords literal atom spellings: `nil ==
:nil` and `true == :true` are both `true`. So "some atoms get a bare-identifier spelling" is
tier 2 of the borrow heuristic with a shipped precedent, not an invention.

**`true` and `false` get the C#/TS spelling. Nothing else does.**

The discriminator is the heuristic's own tier-1 test — *semantics*, not syntax:

- **`true`/`false` pass.** C#'s `bool` is a two-valued type; the BEAM's booleans are exactly
  two atoms; `is_boolean/1` decides it. The semantics coincide completely.
- **`null` fails**, the same way `union` failed in ticket 09. C#'s `null` means *a reference
  pointing nowhere*. beam-sharp has no references, and ticket 05 dropped nullable reference
  types. Borrowing the spelling would promise semantics the language does not deliver, to
  exactly the audience primed to expect them.

`:true` and `:false` remain legal — under an open universe you cannot ban a literal without a
special case — and denote the same values. Diagnostics normalise to `true`/`false`.

**`bool` is a builtin** — *corrected 2026-09-03 by [ticket 67](67-stdlib-shape-as-a-principle.md),
David: "on bool correct ticket 10".* This paragraph read *"`bool` needs no builtin. It is a prelude
alias under ticket 09's single naming construct"*, and the compiler was built the other way from F1:
`bs_check.erl` has `builtin(bool) -> union(atom_lit(true), atom_lit(false))` beside `int`, `atom`,
`term`, `binary` and `string`. The type it names is unchanged — the two-atom union below — and so
is everything else in this section. What changed is *how it ships*: as a rule in the compiler, like
every other lowercase type name, not as a `type` line. C#'s `bool` is a keyword aliasing
`System.Boolean`, which is the same placement. `PRELUDE.md` had carried this as drift since
2026-08-15; the decision moved, not the compiler.

```
type bool = true | false;   // the type it names — not how it ships
```

Elixir's own type system represents `boolean()` as precisely that two-atom union (see the
table in §1), so this is the shape the theory already uses.

**No truthiness.** `if` requires `bool`; `if (count)` is a type error, not a test against zero.
Elixir's truthy/falsy split (only `nil` and `false` falsy; `0` and `[]` truthy) forces two
operator families — `&&`/`||`/`!` on any term, `and`/`or`/`not` strictly boolean, with `nil and
true` raising `BadBooleanError`. beam-sharp has effectively already declined this: ticket 01
settled `&&`/`||` as guard operators, which under `bool = true | false` are strictly boolean.
C# has no truthiness either, so this costs nothing with the audience.

**Consequence for ticket 09**: its Json example is written `type Json = null | bool | ...`.
Under this decision it is `:null` — which is also what OTP's own `json` module returns
(`json:decode(<<"{\"a\":null}">>)` → `#{<<"a">> => null}`). A one-token correction, made.

### 3. A module identifier in value position is a checked atom singleton

Module names are atoms on the BEAM (`is_atom(lists)` → `true`), and beam-sharp writes module
names as PascalCase identifiers, so `Spawn(MyModule, :init, [])` has to mean something.

**A module identifier in value position denotes the atom naming that module, typed as that
atom's singleton** — consistent with `true`/`:true` being one value. Elixir does the same
(`Foo.Bar` is the atom `:"Elixir.Foo.Bar"`, verified).

What this buys over writing the atom by hand is the one check that distinguishes a module name
from any other atom:

```
Spawn(MyModule, :init, []);       // ok
Spawn(NoSuchModule, :init, []);   // ✗ error: unresolved module
Spawn(:no_such_module, ...);      // compiles — open universe, a legal atom
```

Under the standing constraint (agents author, humans review) an agent naming a module that
does not exist is a live failure mode, and this is the only place the compiler can catch it.

**What atom is actually emitted** — a bare name, or something prefixed to avoid colliding with
Erlang modules — is **not decided here**. The map lists "Module and namespace system, and
function identity" under *Not yet specified*, and the emitted spelling belongs there.

### 4. The prelude cannot mint; the safe converters come in two shapes

Atoms are globally interned and never collected, with a bounded table — `atom_limit` is
1,048,576 by default and `atom_count` is already 10,449 at a bare boot (OTP 28, local). But
the hazard is narrower than "minting", for a reason §6.3 establishes: **`erlc` constant-folds
`binary_to_atom/1` on a literal binary**, so minting from a literal is indistinguishable from
writing the atom. The table is only ever exhausted by a **runtime-built string**.

That reframes the design. The prelude offers no minting function — **not because minting is
forbidden, but because the only safe form of it is already spelled `:foo`**, and the unsafe
form is reachable through the Erlang FFI regardless, which ticket 06's interop surface
requires. What is decided here is what the prelude offers:

```
type Outcome = :ok | :error;

o := ParseAtom<Outcome>(input);   // Outcome | :nothing   — narrows to a declared set
a := ToExistingAtom(input);       // atom | :nothing      — honest weak residual
b := :some_atom;                  // minting from a literal, spelled properly
c := Erlang.BinaryToAtom(input);  // runtime minting: FFI, visible in review
```

**`ParseAtom<T>` requires `T` to be a finite atom union** (a cofinite `T` is an error at the
call). It keeps §1's strong list-shaped residual, so the common case never degrades.

**It also needs no new mechanism, and touches the atom table not at all.** It lowers to a
binary match against the members' printed names, returning a compile-time-known atom literal:

```erlang
case Bin of
    <<"ok">>    -> ok;
    <<"error">> -> error;
    _           -> nothing
end
```

**Measured** ([`prototypes/10d_parseatom_lowering.erl`](../prototypes/10d_parseatom_lowering.erl),
OTP 28) — and the result is stronger than expected. A single module carrying both a type-only
union and a lowered one reports:

```
lowering members in chunk?    : true true      <- zzz_alpha, zzz_beta
type-only members in chunk?   : false false    <- qqq_gamma, qqq_delta
calls binary_to_existing_atom : false
```

So the lowering does not merely *avoid* the atom table — **it forces `T`'s members into value
position, which cures that union's §6.2 interning gap.** `ToExistingAtom` cannot do this: not
knowing the permitted set, it must ask the atom table, and therefore depends on §6.2's codegen
obligation actually being discharged.

The discriminator vocabulary is ticket 09 §4's, which ticket 09 §7 already routes to ticket
18's emitted-check machinery: *same mechanism, do not build it twice.*

`ToExistingAtom` is the genuine interop escape — a peer node's reply, a dynamically named
module — and must use `binary_to_existing_atom` with the badarg caught. It returns bare `atom`
and therefore forces the catch-all §1 accepted. That honesty is the point: you asked for an
atom you could not name in advance.

**Naming.** Erlang made the dangerous call short (`binary_to_atom`) and the safe call long
(`binary_to_existing_atom`), an ergonomic inversion that steers toward the footgun. Gleam
corrected it (`get` safe, `create` says what it does). Keep the correction.

**The honest limit.** beam-sharp cannot prevent atom minting in its VM: Erlang's distribution
protocol mints atoms, and `binary_to_term/1` mints unless passed `safe`. The guarantee is
"beam-sharp code does not mint", never "atoms cannot be minted here" — ticket 21's finding
that you defend the boundary you own.

### 5. `option<T>` names the absence shape without creating it

Ticket 08 settled that `as T` yields `T | :nothing`. The prelude names that shape:

```
type option<T> = T | :nothing;
```

Under ticket 09 this creates no type — `option<int>` and `int | :nothing` are the same set —
so it is purely a diagnostic and readability device, which is exactly what §1 of that ticket
says aliases are for. The compiler knows the alias and prints the name.

**Foreign absence atoms are ordinary data and are never silently translated.** Erlang's
`:undefined` (`:proplists.get_value(:missing, [])` → `:undefined`) and Gleam's `nil` (§7, and
`nil == :nil` in Elixir) arrive as themselves and are matched as themselves. Normalising them
to `:nothing` at the boundary was rejected: it destroys the distinction between "Erlang meant
undefined" and "a conversion failed", and what happens at the boundary is ticket 18's.

Note this is a parametric alias, which is a type-level function; ticket 11 owns whether the
alias mechanism admits parameters, and this assumes it does (ticket 09 already writes
`list<Json>` and `map<string, Json>`).

### 6. Findings the ticket did not anticipate

#### 6.1 The sigil objection is lexical, and it dissolves

The ticket recorded one surviving objection to `:atom`: *"`[module: GenServer]` sharing the
character in a positionally distinct place."* That is a visual collision, not a lexical one.
**The atom sigil precedes an identifier (`:draft`); every other use of `:` follows one
(`module:`, `Status:`, `name:`).** A lexer separates them with no lookahead.

The C# constructs that could genuinely collide do not survive into this language: `case X:`
labels are gone (ticket 01 moved patterns into the parameter position), there is no ternary
(prototype 01g), and C# ranges use `..`. The one thing to watch is `::` if module
qualification ever wants it, since `Foo::bar` and `Foo: :bar` would then differ by whitespace.

**The objection is withdrawn.** Nothing remains against the sigil.

#### 6.2 Type-position atoms are not interned — a codegen obligation Erlang does not have

Verified ([`prototypes/10b_atom_interning.erl`](../prototypes/10b_atom_interning.erl), OTP 28):
an atom appearing **only** in a `-type`/`-spec` is absent from the compiled module's atom
chunk, and `binary_to_existing_atom` rejects it.

```
type-position only, never a value : not_interned
type-only in atom chunk?          : false
```

Erlang gets away with this because its specs are documentation. **beam-sharp's types are
load-bearing and ticket 09 made them erased aliases**, so the combination is dangerous: a
`type Outcome = :ok | :error;` whose `:error` never appears in any pattern or expression would
leave that atom uninterned, and `ToExistingAtom("error")` would reject a value the type system
says is legal. The type says one thing, the runtime another — ticket 06's third outcome
arriving through an unwatched door.

**Obligation: emit every type-position atom into the module's atom chunk.** Cost is bounded by
source size. The exposure is narrow — atoms in clause heads are already value-position
literals — but it must be written down or it will be found as a bug.

This lands on **ticket 13** (compilation target), and note it interacts with ticket 02's
finding that compiling from `.core` emits an empty abstract chunk silently.

#### 6.3 `erlc` constant-folds `binary_to_atom`, so the hazard is narrower than minting

Same probe:

```
literal arg to binary_to_atom  : {interned, aaa_literal_arg_zzz}   ← at load, before any call
runtime-built, before the call : not_interned
literal-arg in atom chunk?     : true
runtime-built in atom chunk?   : false
```

Minting from a literal is a compile-time operation whose atom is interned at module load. The
atom table can therefore only be exhausted by a string built at runtime — which is why §4's
prelude omits a minting function rather than banning one.

It also implies a **testing trap worth recording for ticket 24**: a test of atom-minting
policy written with literal strings measures nothing, because `erlc` folds them. Any such test
must construct the string at runtime. This bit twice while producing the evidence — the probe
file carries a hygiene note about it.

**The rule that actually prevents exhaustion is about the string's provenance**, which is what
Gleam's own warning says (*"Never convert **user input** into atoms"*) and cannot enforce. No
BEAM language expresses it. Recorded as a note on **ticket 20**.

### 7. What Gleam does, now measured rather than read

Gleam was installed for this session (1.18.1, via `mise use -g gleam@1.18.1`), **closing the
map's standing provenance gap**. Claims in tickets 03 and 06 that were `doc` or inferred are
now `local`. Evidence: [`prototypes/10c_gleam_atoms.gleam`](../prototypes/10c_gleam_atoms.gleam)
and [`prototypes/10c_gleam_forge.erl`](../prototypes/10c_gleam_forge.erl).

**Gleam has no atom literal.** `pub fn f() { :ok }` → *"Syntax error … Found `:`, expected one
of: `}`"*. From the Erlang cheat sheet, verbatim: *"In Erlang atoms can be created as needed,
but in Gleam all atoms must be defined as values in a custom type before being used."*

**That is declare-before-use, and it needed a carve-out immediately** — the very next sentence
excepts *"atoms that are commonly used and have types built-in to Gleam …, such as `ok`,
`error` and booleans."* The concession this ticket's rejected option would have required is
present in the shipped language.

**But Gleam can afford it because it is nominal.** Fieldless variants compile to atoms, variants
with fields to tagged tuples, PascalCase to snake_case. The constructor *is* the declaration
site. Ticket 09 removed constructors from beam-sharp, so the mechanism is not merely unwanted
here — it is unavailable. This is also why Gleam needs no set-parameterised converter: decoding
into a custom type is the idiomatic path, and §4's `ParseAtom<T>` fills the hole nominality
fills for Gleam.

**Its escape hatch is a library with a comment.** `gleam_erlang` v1.3.0 exposes
`atom.create(String) -> Atom` (mints) and `atom.get(String) -> Result(Atom, Nil)` (safe,
implemented with `binary_to_existing_atom`, verified in the FFI source), carrying the warning:
*"There is a limit to the number of atom that can fit in the virtual machine's atom table.
Never convert user input into atoms as filling the atom table will cause the virtual machine
to crash!"* Strict language, permissive library, guarantee held by prose — ticket 21's finding
that marking is not containing.

**`Nil` is the atom `nil`** (`-spec nothing() -> nil.`), so Gleam libraries hand beam-sharp
that atom as ordinary data (§5).

#### The load-bearing observation: ticket 06's third outcome, demonstrated

Calling the compiled Gleam module from raw Erlang:

```
describe(red) from raw Erlang  : {ok,<<"r">>}          % foreign atom accepted as nominal Colour
describe(purple) forged        : {caught,error,case_clause}
area({circle, 2.0}) forged     : {ok,2.0}
area({circle, <<"str">>})      : {ok,<<"str">>}        % -spec says -> float()
```

The last line is **silent unsoundness**: a function spec'd `shape() -> float()` returned a
binary. Not a crash, not a wrong number — a wrong *kind of term* leaving a typed function.
Ticket 06 established the outcome analytically and noted *"neither Gleam nor purerl defends
against any of it"*; that is now observed rather than inferred from the absence of guard
emission, which is the gap the map's provenance note flagged.

Note the contrast between the second and fourth lines: forging the **tag** is caught, because
the tag is what a clause head tests; forging the **payload** is not. This is a sharper
statement of ticket 18's problem than the map currently holds.

And `colour()` erasing to `red | green | blue` is **ticket 09 §6's derived claim with a shipped
proof**: erased nominality *is* an alias, with no runtime witness of construction. That claim
was previously evidenced only against Elixir structs
([`prototypes/16a_elixir_protocol_dispatch.exs`](../prototypes/16a_elixir_protocol_dispatch.exs));
it now holds against the BEAM's flagship statically typed language too.

### 8. Consequences for other tickets

- **[Ticket 09](09-union-representation.md)** (closed): the Json example is corrected `null` →
  `:null`. Its §6 claim that erased nominality is an alias gains a shipped proof (§7).
- **[Ticket 11](11-type-system-shape.md)**: inherits `bool` as a prelude alias rather than a
  builtin, the singleton/cofinite atom representation (verified against Elixir's `Descr`), and
  the question of whether the alias mechanism admits type parameters (§5 assumes it does).
  Typo exposure in `dynamic` positions is its problem (§1).
- **[Ticket 13](13-compilation-target-decision.md)**: the atom-chunk obligation of §6.2 — emit
  type-position atoms — is a codegen requirement Erlang does not have, and it interacts with
  ticket 02's silent empty-abstract-chunk finding on the `.core` path.
- **[Ticket 17](17-pipeline-and-comprehension.md)**: `if` requires `bool`; there is no
  truthiness (§2). This ticket's own note routed expression-`if` to "ticket 08 or 17" and 08 is
  closed, so **17 also owns what a one-armed `if` evaluates to** — Elixir answers `nil`, which
  under §5 would make it `option<T>`, but that is 17's call.
- **[Ticket 18](18-boundary-defence.md)**: `ToExistingAtom` is a boundary operation; §4's
  `ParseAtom<T>` lowering is the same discriminator machinery ticket 09 §7 already assigned
  here. §7's tag-versus-payload contrast sharpens the problem statement.
- **[Ticket 20](20-untheorised-term-shapes.md)**: **value provenance / taint.** The only rule
  that prevents atom-table exhaustion is "this string came from outside" (§6.3). No BEAM
  language expresses it, and Gleam's documentation states it as prose precisely because it
  cannot be checked. Is this a type-system capability the language needs?
- **[Ticket 24](24-testing-story.md)**: the constant-folding trap of §6.3 — a test using literal
  strings cannot measure atom-minting behaviour.
- **[Ticket 03](03-prior-art-static-multiclause.md)** and
  **[Ticket 06](06-interop-surface.md)**: Gleam claims upgrade from `doc`/inferred to `local`.
  Ticket 06's third outcome now has a worked demonstration in Gleam.
- **Map Notes**: the "Gleam is not installed locally" provenance warning is retired.

## Question

C# has no atom literal. How are atoms written, and how do they relate to the union and enum
story?

Constraints that make this harder than it looks:

- Atoms are **values, not types** — `:ok` is a value that can be a map key, a message tag, a
  return tag, or a module name.
- They are **globally interned and never garbage collected**, so a language that mints them
  freely creates a resource leak.
- They are pervasive in Erlang APIs: no interop story works without them.
- Booleans and module names *are* atoms on the BEAM.

Candidate directions to weigh: a sigil literal borrowed from Elixir; promoting C# `enum`
members to atoms; treating singleton case types of a union as atoms; a distinct
string-adjacent literal type; or requiring atoms be declared before use (which trades
ergonomics for leak safety and better exhaustiveness).

Decide the literal syntax **and** the typing story — what is the type of `:ok`, and how does
a function say it accepts exactly `:ok | :error`?

## Evidence from prototype 01g — the case against `:atom` largely collapsed

Two objections were raised against Elixir's `:atom` sigil and **both fail on examination**:

- **"It costs the ternary operator."** No BEAM language has a ternary. Not Erlang, not Elixir, not
  LFE, and Gleam explicitly replaces it with `case`. The objection was imported from C#, not from
  the platform. And the replacement is better than the thing given up — **make `if` an
  expression**, as Rust and Kotlin do and as Elixir effectively already does (`if cond, do: a,
  else: b`). Expression-`if` takes blocks as well as expressions, is a more familiar keyword to a
  C# developer than the symbol lost, and partly relieves the intermediate-value friction from 01b
  since a conditional no longer forces a drop into a block body.
- **"`{ Status: :draft }` puts two colons adjacent."** That is exactly the shape Elixir writes as
  `%{status: :draft}` — the most-read syntax in that ecosystem. An aesthetic objection dressed as
  a technical one.

What remains against `:atom` is `[module: GenServer]` sharing the character in a positionally
distinct place. The alternatives fare worse: `#atom` collides with the `#{}` map literal, and
`'atom'` inherits Erlang's oldest confusion (`'ok'` the atom versus `"ok"` the binary).

*(**Resolved in §6.1**: the remaining objection is visual, not lexical, and is withdrawn.)*

**A consequence to decide with the sigil**: if `if` becomes an expression, that is a language-wide
change, not an atoms decision. It should be recorded wherever expression-versus-statement is
settled. → ticket 08 or 17. *(**Routed in §8**: 08 is closed, so ticket 17.)*

## Notes

HITL. Waits on ticket 01 for a concrete look, and ticket 09 because the answer differs
sharply depending on whether unions are nominal or structural.

Resolved 2026-08-12. Evidence: [`prototypes/10b_atom_interning.erl`](../prototypes/10b_atom_interning.erl),
[`prototypes/10c_gleam_atoms.gleam`](../prototypes/10c_gleam_atoms.gleam),
[`prototypes/10c_gleam_forge.erl`](../prototypes/10c_gleam_forge.erl). All claims marked
`local` were observed on OTP 28 / Elixir 1.19.5 / Gleam 1.18.1 on 2026-08-12; Gleam's
cheat-sheet and `gleam_erlang` documentation quotes are `doc`.

## Constraints from ticket 13 — resolved 2026-08-12

**§3's codegen obligation now has a defined home, and the adjacent silent failure is out of play.**

This ticket established that **every atom appearing only in a type position must still be emitted
into the module's atom chunk** — an obligation Erlang does not have, since its specs are
documentation. Ticket 13 chose the **Erlang Abstract Format**, so the compiler emits forms and can
add whatever forms discharge the obligation.

It also removes the failure this ticket paired the obligation with. Ticket 02's finding that
compiling from `.core` emits an empty abstract chunk *with no warning* is now measured rather than
cited ([`prototypes/13a_target_measurements.md`](../prototypes/13a_target_measurements.md) §2) —
and it no longer applies, because that path was not taken. Of the two silent failures in the same
layer this ticket warned about, one is closed by the target choice and one remains this ticket's
own.

**§3's open question is sharpened but still open.** What atom a module identifier lowers to now has
a build-layout consequence as well as a collision one: `erlc` **enforces module-name/filename
matching on the `from_abstr` path** (13a §4), so the emitted `.abstr` filename must equal the module
atom. A dotted atom — `'Shop.Orders.Order'`, Elixir's convention — works unchanged.

## Amendment from ticket 27 — resolved 2026-08-12

**§5's `type option<T> = T | :nothing;` is confirmed, and the assumption under it is now paid for.**

This ticket put a parametric alias in the prelude while ticket 11 flagged that doing so assumes an
alias may be a **type-level function** — an assumption neither ticket owned. Ticket 27 resolved it:
the language has real parametric polymorphism, aliases genuinely are type-level functions, and the
`T` spelling written here is the settled one. Variables are **declared** (forced — this language's
builtins are lowercase, so lowercase-implicit variables would be ambiguous where Gleam's are not)
and named by C#'s convention, which is what §5 already wrote.

**§4's `ParseAtom<T>` is unaffected but gains a rule.** It remains type-directed **codegen**, not a
generic function. 27 §8 adds that **a codegen obligation requires a ground type argument**, so
`ParseAtom<TSource>` inside a polymorphic function is rejected — consistent with this ticket's
existing requirement that `T` be a finite atom union, which a type variable can never be known to
be.

## Correction from ticket 15 — resolved 2026-08-12

**§5's worked example is degenerate, and the instantiation is now rejected.**

This ticket wrote:

```
a := ToExistingAtom(input);       // atom | :nothing      — honest weak residual
```

That declared type **is `atom`**. Measured (Elixir 1.19.5,
[`prototypes/15a_untagged_failure_collapse.exs`](../prototypes/15a_untagged_failure_collapse.exs)):
`atom | :nothing` normalises to `%{atom: {:negation, %{}}}`, identical to bare `atom()`, because
ticket 09's normalisation rule absorbs a singleton into a cofinite top. The comment was true of the
intent and false of the type — a caller cannot write the failure clause, because after
normalisation there is no failure member to match.

Ticket 15 §1 makes this instantiation an **error at the declaration**. So `ToExistingAtom` must be
respelled — a tagged failure member, or a narrower success type than the atom top.

This does not disturb §5's decision that `type option<T> = T | :nothing;` is the right shape; it
disturbs the assumption that the shape is total.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Atoms in a C# skin](issues/10-atoms-in-a-csharp-skin.md) — **the atom universe is open**:
  `:ok` is a singleton type, `atom` the cofinite top, and nothing declares an atom. Declare-
  before-use was not a live option — it contradicts ticket 09's "no syntax that declares a type"
  — and **Gleam supplies the empirical case against it**, having taken that fork and needed a
  carve-out for `ok`/`error`/booleans in the shipped language. **`true`/`false` are the only
  keyword atoms** (semantics coincide with C#'s `bool`; `null` fails the same test `union`
  failed), `bool` is a builtin *(corrected 2026-09-03 by ticket 67 — it read "a prelude alias not a builtin",
  and the compiler had been built the other way since F1)*, and there is **no truthiness** — so ticket
  09's Json example is corrected to `:null`. Module identifiers in value position are checked
  atom singletons. **The prelude cannot mint**, because minting from a literal is already
  spelled `:foo`. Three findings the ticket did not anticipate: the sigil's last objection is
  visual not lexical and is **withdrawn**; **atoms appearing only in type positions are not
  interned**, a codegen obligation Erlang does not have (→ 13); and **`erlc` constant-folds
  `binary_to_atom` on literals**, so the table can only be exhausted by a runtime-built string,
  which makes provenance — not minting — the real rule (→ 20). **Gleam is now installed and
  ticket 06's silent unsoundness is demonstrated**: a Gleam function spec'd `-> float()`
  returned a binary when called from raw Erlang.
```
