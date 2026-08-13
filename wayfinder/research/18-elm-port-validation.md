# 18 — Does Elm validate values crossing a port at runtime?

Research for [issue 18](../issues/18-boundary-defence.md), answering the one question inherited from
[ticket 21](../issues/21-escape-hatch-precedents.md) when Elm was descoped there. Read against
[research 06](06-interop-surface.md), which established that the BEAM has **eight** violation channels
and that neither Gleam nor purerl validates anything at an FFI boundary, and against
[research 21](21-escape-hatch-precedents.md), which found that Roc and Unison do not validate either —
they control *who may be on the other side*, a property the BEAM denies.

**Scope, as instructed.** Four questions only: what types may cross a port; what the generated
JavaScript does to an incoming value; what happens when that fails; and how the `Json.Decode.Value`
convention differs. Nothing here about The Elm Architecture, the 0.19 history, or whether Elm is a
good language. Where a source started telling that story, only the mechanical facts were taken.

**Short answer: yes, and it is the only precedent found so far that does.** Elm's compiler generates a
JSON decoder from the declared port type and the runtime runs it on every incoming value before the
value reaches Elm code. But the qualifiers matter more than the headline: §5 and the closing section
are where the useful findings are.

## Method and provenance

| Mark | Meaning |
|---|---|
| **doc** | Official language documentation, guide, or error text emitted by the toolchain |
| **src** | Source code of the implementation, at a pinned tag |
| **local** | Observed directly on this machine, 2026-08-13 |

Unlike research 21, **most of this file is `local`**. Elm 0.19.1 installs from npm in about three
seconds, so the whole mechanism was compiled and run rather than read about.

Versions pinned for every `src` and `local` claim:

| Artefact | Version | Commit |
|---|---|---|
| `elm` binary (npm `elm@0.19.1-6`) | 0.19.1 | — |
| `elm/compiler` | tag `0.19.1` | `c9aefb6230f5e0bda03205ab0499f6e4af924495` |
| `elm/core` | tag `1.0.5` | `84f38891468e8e153fc85a9b63bdafd81b24664e` |
| `elm/json` | tag `1.1.3` | `063aaf05e0dc5a642bacbdaae59c33dcfd116898` |

**The probe sources and their full output are inlined below** rather than committed as prototypes,
because this session's `write_scope` is this one file. Everything marked `local` can be reproduced
from the code in §7.

---

## 1 — What types may cross a port

### 1.1 The admissible set, from the compiler

The check is `checkPayload` in `compiler/src/Canonicalize/Effects.hs` [1]. It runs at
canonicalisation, before the codec is generated at optimisation time [3], and it is a **closed
whitelist**, not an open recursion with escape hatches:

```haskell
checkPayload :: Can.Type -> Either (Can.Type, Error.InvalidPayload) ()
checkPayload tipe =
  case tipe of
    Can.TAlias _ _ args aliasedType ->
      checkPayload (Type.dealias args aliasedType)

    Can.TType home name args ->
      case args of
        []
          | isJson home name -> Right ()
          | isString home name -> Right ()
          | isIntFloatBool home name -> Right ()

        [arg]
          | isList  home name -> checkPayload arg
          | isMaybe home name -> checkPayload arg
          | isArray home name -> checkPayload arg

        _ ->
          Left (tipe, Error.UnsupportedType name)

    Can.TUnit ->
        Right ()

    Can.TTuple a b maybeC ->
        do  checkPayload a
            checkPayload b
            case maybeC of
              Nothing -> Right ()
              Just c  -> checkPayload c

    Can.TVar name ->
        Left (tipe, Error.TypeVariable name)

    Can.TLambda _ _ ->
        Left (tipe, Error.Function)

    Can.TRecord _ (Just _) ->
        Left (tipe, Error.ExtendedRecord)

    Can.TRecord fields Nothing ->
        F.traverse_ checkFieldPayload fields
```

So the admissible set, exactly [1]:

- `Int`, `Float`, `Bool` (from `Basics`), `String` (from `String`)
- `Json.Encode.Value` — note the module test is `isJson home name = home == ModuleName.jsonEncode && name == Name.value`; `Json.Decode.Value` is an alias of the same type
- `List a`, `Array a`, `Maybe a` — recursively, one argument each
- `()`, 2-tuples and 3-tuples — recursively
- **closed** records whose every field is admissible
- type aliases, dealiased first

Everything else is rejected. There is no user extension point: the whitelist is spelled out with
hard-coded module-and-name tests (`isIntFloatBool`, `isString`, `isJson`, `isList`, `isMaybe`,
`isArray` [1]).

The port *shape* is checked separately in `canonicalizePort` [1]: an outgoing port must be
`payload -> Cmd msg` with `msg` a free type variable, an incoming port must be
`(payload -> msg) -> Sub msg` with the two `msg` variables identical. Anything else is
`PortTypeInvalid`.

### 1.2 What it rejects — measured, not assumed

Nine payload types compiled against `elm make`, 0.19.1 (**local**). The brief asked to establish the
truth rather than assume it, so custom unions were tried both with and without constructor payloads:

| Declared port | Result | Error constructor |
|---|---|---|
| `port p : (Int -> Int) -> Cmd msg` | **rejected** | `Function` |
| `port p : Colour -> Cmd msg` where `type Colour = Red \| Green \| Rgb Int Int Int` | **rejected** | `UnsupportedType` |
| `port p : (Colour -> msg) -> Sub msg`, same union | **rejected** | `UnsupportedType` |
| `port p : Colour -> Cmd msg` where `type Colour = Red \| Green` (**payload-free enum**) | **rejected** | `UnsupportedType` |
| `port p : a -> Cmd msg` | **rejected** | `TypeVariable` |
| `port p : Dict String Int -> Cmd msg` | **rejected** | `UnsupportedType` |
| `port p : Set Int -> Cmd msg` | **rejected** | `UnsupportedType` |
| `port p : Char -> Cmd msg` | **rejected** | `UnsupportedType` |
| `port p : Result String Int -> Cmd msg` | **rejected** | `UnsupportedType` |
| `port p : { a \| age : Int } -> Cmd msg` | **rejected** | `ExtendedRecord` |

**A payload-free enum is rejected exactly like a union with payloads.** `Colour = Red | Green` has no
more structure than a `Bool`, and Elm still refuses it, because `checkPayload`'s `[]` branch tests
module-and-name identity against a fixed list and `Colour` is not on it [1]. There is no nominal-tag
encoding, no "sum types become `{tag: ...}`" convention. `Char` and `Result` — both core types, both
trivially JSON-representable — are refused for the same reason.

### 1.3 The compiler states the guarantee itself

The error text for the type-variable case is the clearest statement of intent found anywhere,
including the guide (**local**, verbatim from `elm make`):

```
-- PORT ERROR ------------------------------------------------------ src/Bad.elm

The `p` port is trying to transmit an unspecified type:

10| port p : a -> Cmd msg
         ^
But type variables like `a` cannot flow through ports. I need to know exactly
what type of data I am getting, so I can guarantee that unexpected data cannot
sneak in and crash the Elm program.
```

"I need to know exactly what type of data I am getting, so I can guarantee that unexpected data
cannot sneak in and crash the Elm program" — the compiler is asserting that the boundary is defended,
and naming the reason the admissible set is closed. **The admissible set is exactly the set of types
for which a decidable structural test exists**, which is the same criterion ticket 09 §4 uses to
decide whether a union member is admissible.

The function case gives the second reason, which is about *outgoing* values (**local**):

```
But functions cannot be sent in and out ports. If we allowed functions in from
JS they may perform some side-effects. If we let functions out, they could
produce incorrect results because Elm optimizations assume there are no
side-effects.
```

And the general case enumerates the whitelist back to the user (**local**):

```
I cannot handle that. The types that CAN flow in and out of Elm include:

    Ints, Floats, Bools, Strings, Maybes, Lists, Arrays, tuples, records, and
    JSON values.
```

The guide gives the same list for flags [7]: "`Bool`, `Int`, `Float`, `String`, `Maybe`, `List`,
`Array`, tuples, records, `Json.Decode.Value`". Ports and flags share the check — `toFlagsDecoder`
delegates to `toDecoder` for every type except `()` [2].

---

## 2 — What the generated JavaScript actually does to an incoming value

**It runs a decoder. The decoder is generated by the compiler from the declared type, and it is not
optional.**

### 2.1 Where the decoder comes from

`Optimize.Module.addPort` attaches a generated codec to every port at optimisation time [3]:

```haskell
addPort :: ModuleName.Canonical -> Name.Name -> Can.Port -> Opt.LocalGraph -> Opt.LocalGraph
addPort home name port_ graph =
  case port_ of
    Can.Incoming _ payloadType _ ->
      let
        (deps, fields, decoder) = Names.run (Port.toDecoder payloadType)
        node = Opt.PortIncoming decoder deps
      in
      addToGraph (Opt.Global home name) node fields graph

    Can.Outgoing _ payloadType _ ->
      let
        (deps, fields, encoder) = Names.run (Port.toEncoder payloadType)
        node = Opt.PortOutgoing encoder deps
      in
      addToGraph (Opt.Global home name) node fields graph
```

`Optimize.Port.toDecoder` [2] is a **type-directed structural synthesiser**: it walks the canonical
type and emits an `elm/json` decoder expression, one constructor at a time.

```haskell
toDecoder :: Can.Type -> Names.Tracker Opt.Expr
toDecoder tipe =
  case tipe of
    Can.TLambda _ _ ->
      error "functions should not be allowed through input ports"

    Can.TVar _ ->
      error "type variables should not be allowed through input ports"
    ...
    Can.TType _ name args ->
      case args of
        []
          | name == Name.float  -> decode "float"
          | name == Name.int    -> decode "int"
          | name == Name.bool   -> decode "bool"
          | name == Name.string -> decode "string"
          | name == Name.value  -> decode "value"

        [arg]
          | name == Name.maybe -> decodeMaybe arg
          | name == Name.list  -> decodeList arg
          | name == Name.array -> decodeArray arg
```

The `error "..."` arms are Haskell `error` calls, i.e. compiler panics: `checkPayload` has already
made them unreachable. **The rejection in §1 and the emission here are two halves of one design — the
type set is closed precisely so that the synthesiser is total.** Ticket 09 §4's rule (reject at the
declaration any union whose membership guard cannot be synthesised) is the same design, arrived at
independently.

Records decode field-by-field through `Json.Decode.field` + `andThen`; tuples through
`Json.Decode.index` + `andThen`; `Maybe` through `oneOf [ null Nothing, map Just sub ]` [2].

### 2.2 The generated JavaScript — read, not described

The decoders appear literally in the output. From `elm make src/Main.elm --output=dev.js`, 0.19.1
(**local**) — the port declarations in §7's `Main.elm` become:

```js
var $author$project$Main$takesInt = _Platform_incomingPort('takesInt', $elm$json$Json$Decode$int);

var $author$project$Main$takesMaybe = _Platform_incomingPort(
	'takesMaybe',
	$elm$json$Json$Decode$oneOf(
		_List_fromArray(
			[
				$elm$json$Json$Decode$null($elm$core$Maybe$Nothing),
				A2($elm$json$Json$Decode$map, $elm$core$Maybe$Just, $elm$json$Json$Decode$int)
			])));

var $author$project$Main$takesRecord = _Platform_incomingPort(
	'takesRecord',
	A2(
		$elm$json$Json$Decode$andThen,
		function (name) {
			return A2(
				$elm$json$Json$Decode$andThen,
				function (age) {
					return $elm$json$Json$Decode$succeed(
						{age: age, name: name});
				},
				A2($elm$json$Json$Decode$field, 'age', $elm$json$Json$Decode$int));
		},
		A2($elm$json$Json$Decode$field, 'name', $elm$json$Json$Decode$string)));

var $author$project$Main$takesValue = _Platform_incomingPort('takesValue', $elm$json$Json$Decode$value);

var $author$project$Main$sendsOut = _Platform_outgoingPort('sendsOut', $elm$json$Json$Encode$int);
```

**These are byte-identical between `elm make` and `elm make --optimize`** (**local**: `grep -n
"incomingPort\|outgoingPort"` over both builds returns the same lines at the same line numbers). The
check is not a debug-mode affordance.

### 2.3 Where the decoder runs

`_Platform_setupIncomingPort` in `elm/core` `src/Elm/Kernel/Platform.js` [4]:

```js
function _Platform_setupIncomingPort(name, sendToApp)
{
	var subs = __List_Nil;
	var converter = _Platform_effectManagers[name].__converter;

	// CREATE MANAGER
	var init = __Scheduler_succeed(null);
	_Platform_effectManagers[name].__init = init;
	_Platform_effectManagers[name].__onEffects = F3(function(router, subList, state)
	{
		subs = subList;
		return init;
	});

	// PUBLIC API

	function send(incomingValue)
	{
		var result = A2(__Json_run, converter, __Json_wrap(incomingValue));

		__Result_isOk(result) || __Debug_crash(4, name, result.a);

		var value = result.a;
		for (var temp = subs; temp.b; temp = temp.b) // WHILE_CONS
		{
			sendToApp(temp.a(value));
		}
	}

	return { send: send };
}
```

Three things in that function are the whole answer to this ticket's Elm question.

1. **`send` *is* the decode.** The function JavaScript calls as `app.ports.takesInt.send(v)` runs
   `_Json_run` on its argument before anything else happens. There is no bypass path; the object
   returned to JavaScript, `{ send: send }`, exposes nothing but this function.
2. **`sendToApp` is unreachable unless the decode succeeded** — the `||` short-circuit throws first.
3. **The failure is thrown synchronously, into the JavaScript caller's stack frame.** Elm's update
   loop never sees it. This is the "fail fast" policy the guide describes for flags [7]: "when one of
   the conversions goes wrong, **you get an error on the JS side!** … Rather than the error making its
   way through Elm code, it is reported as soon as possible."

The primitive checks are ordinary `typeof` tests in `elm/json` `src/Elm/Kernel/Json.js` [5]:

```js
var _Json_decodeInt = _Json_decodePrim(function(value) {
	return (typeof value !== 'number')
		? _Json_expecting('an INT', value)
		:
	(-2147483647 < value && value < 2147483647 && (value | 0) === value)
		? __Result_Ok(value)
		:
	(isFinite(value) && !(value % 1))
		? __Result_Ok(value)
		: _Json_expecting('an INT', value);
});

var _Json_decodeBool = _Json_decodePrim(function(value) {
	return (typeof value === 'boolean') ? __Result_Ok(value) : _Json_expecting('a BOOL', value);
});

var _Json_decodeFloat = _Json_decodePrim(function(value) {
	return (typeof value === 'number') ? __Result_Ok(value) : _Json_expecting('a FLOAT', value);
});

var _Json_decodeValue = _Json_decodePrim(function(value) {
	return __Result_Ok(_Json_wrap(value));
});
```

Note `_Json_decodeValue`: **unconditional `Ok`.** That is §4's subject.

### 2.4 The outbound direction does nothing, correctly

`toEncoder` for `Int` is `Json.Encode.int`, and in the generated output
`var $elm$json$Json$Encode$int = _Json_wrap;` — where `_Json_wrap__PROD(value) { return value; }`, the
identity function [5] (**local**, confirmed in both `dev.js` and `prod.js`). Outgoing ports do no
validation, and do not need to: the value came from Elm and Elm's type system already guarantees it.
`_Platform_setupOutgoingPort` calls `__Json_unwrap(converter(cmdList.a))` and hands the result
straight to the JavaScript subscribers [4].

**So Elm's boundary defence is inbound-only.** It is a precedent for ticket 18's central question —
an untyped caller entering a typed function — and says nothing at all about the FFI `-spec`
sub-decision, which is an *outbound* unverified claim to the ecosystem.

---

## 3 — What happens when validation fails

### 3.1 The mechanism

`__Debug_crash(4, name, result.a)` [4], and `elm/core` ships two `_Debug_crash` implementations
selected by build mode [6]:

```js
function _Debug_crash__PROD(identifier)
{
	throw new Error('https://github.com/elm/core/blob/1.0.0/hints/' + identifier + '.md');
}

function _Debug_crash__DEBUG(identifier, fact1, fact2, fact3, fact4)
{
	switch(identifier)
	{
		...
		case 4:
			var portName = fact1;
			var problem = fact2;
			throw new Error('Trying to send an unexpected type of value through port `' + portName + '`:\n' + problem);
```

So: a **thrown JavaScript `Error`**, synchronously, from the `app.ports.<name>.send(...)` call. Not a
silent drop, not a console warning, not a dead subscription. It is recoverable only in the sense that
any JS exception is — the caller may wrap `send` in `try`/`catch`, and the Elm program is undamaged
because nothing entered it. Elm code has no way to observe that it happened.

### 3.2 What the developer actually sees — three build modes, measured

**local**, all three builds of the same `Main.elm` (§7), each probe a `send` from Node:

```
=== build: dev ===                  (elm make)
OK   takesInt <- 42
THROW takesInt <- "hello": Trying to send an unexpected type of value through port `takesInt`: | [object Object]
THROW takesInt <- 1.5: Trying to send an unexpected type of value through port `takesInt`: | [object Object]
THROW takesInt <- null: Trying to send an unexpected type of value through port `takesInt`: | [object Object]
OK   takesRecord <- {name,age}
THROW takesRecord <- {name,age:"x"}: Trying to send an unexpected type of value through port `takesRecord`: | [object Object]
OK   takesRecord <- extra field
OK   takesMaybe <- null
OK   takesMaybe <- 7
THROW takesMaybe <- "x": Trying to send an unexpected type of value through port `takesMaybe`: | [object Object]
OK   takesValue <- function
OK   takesValue <- {anything}

=== build: prod ===                 (elm make --optimize)
OK   takesInt <- 42
THROW takesInt <- "hello": https://github.com/elm/core/blob/1.0.0/hints/4.md
THROW takesInt <- 1.5: https://github.com/elm/core/blob/1.0.0/hints/4.md
THROW takesInt <- null: https://github.com/elm/core/blob/1.0.0/hints/4.md
OK   takesRecord <- {name,age}
THROW takesRecord <- {name,age:"x"}: https://github.com/elm/core/blob/1.0.0/hints/4.md
OK   takesRecord <- extra field
OK   takesMaybe <- null
OK   takesMaybe <- 7
THROW takesMaybe <- "x": https://github.com/elm/core/blob/1.0.0/hints/4.md
OK   takesValue <- function
OK   takesValue <- {anything}

=== build: debug ===                (elm make --debug)
   ... identical to dev ...
```

Two findings.

**(a) Under `--optimize` the diagnostic is a bare URL.** The check still runs — that is the important
part, and it is why `--optimize` is not a soundness switch — but the entire content of the error
becomes `https://github.com/elm/core/blob/1.0.0/hints/4.md`. That page says, in full [8]:

> You are trying to send an invalid value through a port.
>
> You can get more detailed information if you can reproduce the error in dev mode.

No port name. No value. No expected type. The build flag that ships to production is the one that
tells you least.

**(b) Even in dev mode the message says `[object Object]`.** `problem = fact2` is `result.a`, an Elm
`Json.Decode.Error` value, and it is string-concatenated without conversion [4][6]. Compare the
*flags* path in the same generated file (**local**, `dev.js:1875`):

```js
function _Platform_initialize(flagDecoder, args, init, update, subscriptions, stepperBuilder)
{
	var result = A2(_Json_run, flagDecoder, _Json_wrap(args ? args['flags'] : undefined));
	$elm$core$Result$isOk(result) || _Debug_crash(2 /**/, _Json_errorToString(result.a) /**/);
```

Flags call `_Json_errorToString`; ports do not. Measured, a bad flag gives
`Problem with the flags given to your Elm program on initialization.` followed by a readable decoder
error; a bad port value gives `[object Object]`. This is **elm/core issue #1043**, "Bad error message
when sending the wrong thing through a port: `[object Object]`", opened 2019-09-16 and **still open**
[9] — so it is a property of elm/core 1.0.5, not of this harness.

**The check is sound; the diagnostic is not.** For ticket 18 that separation is worth keeping: ticket
12 §6 already measured that on the BEAM the *quality of the crash report* is most of what a boundary
check buys, and Elm demonstrates a boundary check whose report was left unfinished for six years
without anyone losing the safety property.

---

## 4 — How `Json.Decode.Value` differs from a typed port

### 4.1 Mechanically: it turns the check off

`Json.Decode.Value` is admissible as a port payload [1], and `toDecoder` maps it to
`Json.Decode.value` [2], which is [5]:

```js
var _Json_decodeValue = _Json_decodePrim(function(value) {
	return __Result_Ok(_Json_wrap(value));
});
```

**Unconditional success.** Anything JavaScript passes is accepted. Measured (**local**):

```
OK   takesValue <- function          // a JS function crossed a port
OK   takesValue <- {anything}
```

A raw JavaScript function entered the Elm runtime through a port — the exact thing the `Function`
rejection in §1.2 exists to prevent — because as a `Value` it is opaque and Elm will never apply it.
The type system's promise is preserved by *ignorance*, not by checking.

So the choice at a port is: **a compiler-generated check whose failure is a JS exception the Elm
program cannot see, or no check at all and a hand-written decoder inside Elm whose failure is a
`Result` the Elm program handles.** They are not "checked vs. more checked"; they are two different
places to put the same check, with different failure owners.

### 4.2 Why the community reaches for it, from the docs

The official guide recommends it, twice, and gives three reasons — none of which is that the typed
port fails to check.

> "**Sending `Json.Encode.Value` through ports is recommended.** Like with flags, certain core types
> can pass through ports as well. This is from the time before JSON decoders, and you can read about
> it more [here]." [10]

> "Many folks always use a `Json.Decode.Value` because it gives them really precise control. They can
> write a decoder to handle any weird scenarios in Elm code, recovering from unexpected data in a nice
> way. The other supported types actually come from before we had figured out a way to do JSON
> decoders." [7]

> "This is another reason why people like to use `Json.Decode.Value` for flags. Instead of getting an
> error in JS, the weird value goes through a decoder, guaranteeing that you implement some sort of
> fallback behavior." [7]

The three reasons, then: **the typed ports are legacy** ("from the time before JSON decoders"); **the
admissible set is too small** — §1.2 shows `Char`, `Result`, `Dict`, `Set` and every user-defined
union are refused, so any non-trivial payload has to be a `Value` anyway; and **the failure is in the
wrong place and unrecoverable** — a decoder failure is a `Result` Elm can branch on, a port-check
failure is an exception in JavaScript.

### 4.3 What the compiler's check does *not* cover

This is the sharper form of the question, and §5 is its answer: the compiler's check covers the
*shape* of a value against a small type vocabulary, and nothing else. It does not cover:

- **Refinements.** A record `{ age : Int }` decodes any whole number; there is no way to say `age > 0`.
- **The numeric domain of `Int`** — see §5.1, where the check admits values Elm's own arithmetic
  mishandles.
- **Width.** Extra record fields and extra tuple elements pass and are discarded — §5.2.
- **Any user-defined type**, which cannot cross at all, so the check has nothing to say about the
  domain the program actually models.

A decoder written by hand covers the first, third and fourth. The second is not covered by anything.

---

## 5 — The finding this ticket most needs: a boundary that checks and is still unsound

The brief for ticket 18 is ticket 06's third outcome — **silent unsoundness**, `add(1.5, 2.5)`
returning `4.0`. Elm reproduces it *inside a boundary that checks*.

### 5.1 `Int` accepts values Elm's own `Int` operations misbehave on

`_Json_decodeInt` [5] accepts a `number` if it fits in 32 bits **or** if `isFinite(value) && !(value % 1)`.
So any finite whole JavaScript number is an Elm `Int`. Measured (**local**), sending values through an
`Int` port and having Elm report what it received and what `n + 1` gives:

```
ACCEPT  Int <- 2**53
ACCEPT  Int <- 1e300
ACCEPT  Int <- 3.0
ACCEPT  Float <- NaN
ACCEPT  Float <- Inf
ACCEPT  Tuple <- [1,"a","b"]
--- what Elm actually received ---
  Int arrived: 9007199254740992 ; n+1 = 9007199254740992
  Int arrived: 1e+300 ; n+1 = 1e+300
  Int arrived: 3 ; n+1 = 4
  Float arrived: NaN
  Float arrived: Infinity
  Tuple arrived: (1, a)
```

**`String.fromInt` printed `1e+300`, and `n + 1 == n`.** A value of Elm type `Int` that renders in
exponential notation and is a fixed point of successor. Nothing crashed, nothing warned; the boundary
check passed it, because `1e300` is finite and has no fractional part. `Float` likewise accepts `NaN`
and `Infinity`, neither of which is expressible in JSON, on a bare `typeof value === 'number'` test [5].

Rejections in the same run (**local**), for contrast — the check is real, not vacuous:

```
REJECT  Int <- NaN
REJECT  Int <- new Number(5)       // boxed Number: typeof is 'object'
REJECT  Maybe <- undefined         // Json.Decode.null tests value === null
REJECT  Tuple <- [1]
REJECT  Tuple <- {0:1,1:"a"}
REJECT  Unit <- 0
```

`Maybe <- undefined` is worth noting on its own: `_Json_runHelp`'s `NULL` case is `value === null` [5],
so JavaScript's *other* absent value is a boundary failure. A JS object with a missing key yields
`undefined`, which will fail a `Maybe` port that a JS author would reasonably expect to accept it.

### 5.2 Width is silently truncated, and the docs describe behaviour the compiler does not have

Records and tuples accept extra structure and discard it — `Json.Decode.field` and
`Json.Decode.index` look up by key/index and ignore the rest [2][5]. For records the guide documents
this: `{ x: 3, y: 4, z: 50 }` => `{ x = 3, y = 4 }` [7]. For tuples it documents the opposite:

> `init : (String, Int) -> ...`
> - `["Tom", 42]` => `("Tom", 42)`
> - `["Bob", "4"]` => error
> - `["Joe", 9, 9]` => **error** [7]

**Measured on 0.19.1, `["Joe", 9, 9]` is not an error** (**local**), on both the flags path and the
port path:

```
   ACCEPT ["Tom",42]  => flags = (Tom, 42)
   ACCEPT ["Joe",9,9] => flags = (Joe, 9)
   REJECT ["Bob","4"] => Problem with the flags given to your Elm program on initialization.
   REJECT ["Sue"]     => Problem with the flags given to your Elm program on initialization.
```

The over-long array is accepted and truncated. The source explains why: `decodeTuple` composes
`Json.Decode.index 0` and `index 1` and never checks length [2]. So **the official guide overstates
the check** on precisely the case where a reader would be looking for a width guarantee. That is a
`doc` claim contradicted by `src` and `local`; the source wins.

---

## 6 — Reproduction

Everything marked **local** comes from the following, run on 2026-08-13 with `elm` 0.19.1 installed
via `npm install elm@0.19.1-6` and Node from `$PATH`. Reproduced here in full because the working
directory was a session scratchpad, not the repo.

`elm.json`:

```json
{
    "type": "application",
    "source-directories": [ "src" ],
    "elm-version": "0.19.1",
    "dependencies": {
        "direct": { "elm/core": "1.0.5", "elm/json": "1.1.3" },
        "indirect": {}
    },
    "test-dependencies": { "direct": {}, "indirect": {} }
}
```

`src/Main.elm` — the program behind §2.2 and §3.2:

```elm
port module Main exposing (main)

import Json.Decode
import Platform


port takesInt : (Int -> msg) -> Sub msg
port takesRecord : ({ name : String, age : Int } -> msg) -> Sub msg
port takesValue : (Json.Decode.Value -> msg) -> Sub msg
port takesMaybe : (Maybe Int -> msg) -> Sub msg
port sendsOut : Int -> Cmd msg


type Msg
    = GotInt Int
    | GotRecord { name : String, age : Int }
    | GotValue Json.Decode.Value
    | GotMaybe (Maybe Int)


main : Program () Int Msg
main =
    Platform.worker { init = \_ -> ( 0, Cmd.none ), update = update, subscriptions = subscriptions }


update : Msg -> Int -> ( Int, Cmd Msg )
update msg model =
    case msg of
        GotInt n -> ( model + n, sendsOut (n + 1) )
        GotRecord r -> ( model + r.age, sendsOut r.age )
        GotValue _ -> ( model, sendsOut 999 )
        GotMaybe _ -> ( model, sendsOut 888 )


subscriptions : Int -> Sub Msg
subscriptions _ =
    Sub.batch [ takesInt GotInt, takesRecord GotRecord, takesValue GotValue, takesMaybe GotMaybe ]
```

Built three ways, then probed:

```
elm make src/Main.elm             --output=dev.js
elm make src/Main.elm --optimize  --output=prod.js
elm make src/Main.elm --debug     --output=debug.js
```

`harness.js` (run as `node harness.js dev|prod|debug`):

```js
const build = process.argv[2] || 'dev';
const { Elm } = require('./' + build + '.js');
const app = Elm.Main.init({ flags: null });
app.ports.sendsOut.subscribe(v => console.log('   OUT ->', JSON.stringify(v), typeof v));

function probe(label, port, value) {
  try {
    app.ports[port].send(value);
    console.log('OK   ' + label);
  } catch (e) {
    console.log('THROW ' + label + ': ' + e.message.split('\n').join(' | '));
  }
}

console.log('=== build: ' + build + ' ===');
probe('takesInt <- 42',              'takesInt',    42);
probe('takesInt <- "hello"',         'takesInt',    'hello');
probe('takesInt <- 1.5',             'takesInt',    1.5);
probe('takesInt <- null',            'takesInt',    null);
probe('takesRecord <- {name,age}',   'takesRecord', { name: 'a', age: 3 });
probe('takesRecord <- {name,age:"x"}','takesRecord',{ name: 'a', age: 'x' });
probe('takesRecord <- extra field',  'takesRecord', { name: 'a', age: 3, extra: 'ignored?' });
probe('takesMaybe <- null',          'takesMaybe',  null);
probe('takesMaybe <- 7',             'takesMaybe',  7);
probe('takesMaybe <- "x"',           'takesMaybe',  'x');
probe('takesValue <- function',      'takesValue',  function boom(){});
probe('takesValue <- {anything}',    'takesValue',  { arbitrary: [1, 2, 3] });
```

`src/Edge.elm` — the program behind §5.1, reporting back what Elm received (outgoing port delivery is
deferred through the scheduler, so the harness dumps the reports from a `setTimeout`):

```elm
port module Edge exposing (main)

import Platform


port takesInt : (Int -> msg) -> Sub msg
port takesFloat : (Float -> msg) -> Sub msg
port takesMaybe : (Maybe Int -> msg) -> Sub msg
port takesTuple : (( Int, String ) -> msg) -> Sub msg
port takesUnit : (() -> msg) -> Sub msg
port report : String -> Cmd msg


type Msg = I Int | F Float | M (Maybe Int) | T ( Int, String ) | U ()


main : Program () () Msg
main =
    Platform.worker { init = \_ -> ( (), Cmd.none ), update = update, subscriptions = subs }


update : Msg -> () -> ( (), Cmd Msg )
update msg _ =
    ( ()
    , report <|
        case msg of
            I n -> "Int arrived: " ++ String.fromInt n ++ " ; n+1 = " ++ String.fromInt (n + 1)
            F x -> "Float arrived: " ++ String.fromFloat x
            M m -> "Maybe arrived: " ++ (case m of
                                            Just v -> "Just " ++ String.fromInt v
                                            Nothing -> "Nothing")
            T ( a, b ) -> "Tuple arrived: (" ++ String.fromInt a ++ ", " ++ b ++ ")"
            U () -> "Unit arrived"
    )


subs : () -> Sub Msg
subs _ =
    Sub.batch [ takesInt I, takesFloat F, takesMaybe M, takesTuple T, takesUnit U ]
```

`src/Flags.elm` — the program behind §5.2's tuple-flags measurement:

```elm
port module Flags exposing (main)

import Platform


port report : String -> Cmd msg


main : Program ( String, Int ) () ()
main =
    Platform.worker
        { init = \( s, n ) -> ( (), report ("flags = (" ++ s ++ ", " ++ String.fromInt n ++ ")") )
        , update = \_ m -> ( m, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }
```

The §1.2 rejection table was produced by compiling one `port p : <type>` declaration at a time in a
throwaway `src/Bad.elm` and capturing `elm make`'s output.

---

## Gaps and where I looked

Recorded rather than filled by inference.

- **[g1] Whether `Browser.element` / `Browser.application` differ from `Platform.worker` at the port
  boundary.** All local measurement used `Platform.worker`, which is what runs headless in Node.
  `_Platform_setupIncomingPort` is shared by all program kinds — it is reached through
  `_Platform_effectManagers`, not through any program-specific path [4] — so there is no reason to
  expect a difference, but it was not measured. The DOM-bearing programs would need a browser or
  jsdom.
- **[g2] Whether `elm/browser`'s `Browser.application` adds any port-adjacent check.** Not read;
  out of scope for the four questions.
- **[g3] The `Json.Decode.Error` value's structure was not inspected.** §3.2 establishes that it is
  concatenated as `[object Object]`; what it *contains* (and therefore what a fixed message would say)
  was not pursued, since the ticket asks what the developer sees.
- **Deliberately not researched**, per the scope boundary: The Elm Architecture, the 0.19 native-module
  removal, Elm's governance, and any assessment of Elm as a language. Sources that offered these were
  read for mechanism only.
- **No secondary sources are used in this file.** Every claim is `src`, `doc`, or `local`; where the
  guide [7] and the implementation [2] disagree (§5.2), the disagreement is reported and the source
  is taken as authoritative.

## Claim → source

| # | Source | Mark |
|---|---|---|
| 1 | `elm/compiler` tag `0.19.1` (`c9aefb6`), `compiler/src/Canonicalize/Effects.hs` — `canonicalizePort` (port shape), `checkPayload` and the `isIntFloatBool`/`isString`/`isJson`/`isList`/`isMaybe`/`isArray` predicates (admissible set) ([repo](https://github.com/elm/compiler/blob/0.19.1/compiler/src/Canonicalize/Effects.hs)) | **src** |
| 2 | `elm/compiler` tag `0.19.1`, `compiler/src/Optimize/Port.hs` — `toEncoder`, `toDecoder`, `toFlagsDecoder`, `decodeTuple`/`indexAndThen`, `decodeRecord`/`fieldAndThen`, `decodeMaybe` ([repo](https://github.com/elm/compiler/blob/0.19.1/compiler/src/Optimize/Port.hs)) | **src** |
| 3 | `elm/compiler` tag `0.19.1`, `compiler/src/Optimize/Module.hs` — `addPort`, attaching `Opt.PortIncoming decoder` / `Opt.PortOutgoing encoder` ([repo](https://github.com/elm/compiler/blob/0.19.1/compiler/src/Optimize/Module.hs)) | **src** |
| 4 | `elm/core` tag `1.0.5` (`84f3889`), `src/Elm/Kernel/Platform.js` — `_Platform_incomingPort`, `_Platform_setupIncomingPort`, `_Platform_outgoingPort`, `_Platform_setupOutgoingPort`, `_Platform_initialize` ([repo](https://github.com/elm/core/blob/1.0.5/src/Elm/Kernel/Platform.js)) | **src** |
| 5 | `elm/json` tag `1.1.3` (`063aaf0`), `src/Elm/Kernel/Json.js` — `_Json_decodeInt`, `_Json_decodeFloat`, `_Json_decodeBool`, `_Json_decodeString`, `_Json_decodeValue`, `_Json_run`, `_Json_runHelp` (`NULL` case tests `value === null`), `_Json_wrap__PROD`/`_Json_unwrap__PROD` ([repo](https://github.com/elm/json/blob/1.1.3/src/Elm/Kernel/Json.js)) | **src** |
| 6 | `elm/core` tag `1.0.5`, `src/Elm/Kernel/Debug.js` — `_Debug_crash__PROD` and `_Debug_crash__DEBUG` case 4 ([repo](https://github.com/elm/core/blob/1.0.5/src/Elm/Kernel/Debug.js)) | **src** |
| 7 | *An Introduction to Elm*, "Flags" — admissible flag types, "Elm checks for that sort of thing", the per-type conversion table including `["Joe", 9, 9] => error`, and "you get an error on the JS side! We are taking the 'fail fast' policy" — <https://guide.elm-lang.org/interop/flags.html> (raw: `evancz/guide.elm-lang.org`, `book/interop/flags.md`) | **doc** |
| 8 | `elm/core` tag `1.0.5`, `hints/4.md` — the page the `--optimize` build's error URL points to ([repo](https://github.com/elm/core/blob/1.0.5/hints/4.md)) | **src** |
| 9 | `elm/core` issue #1043, *Bad error message when sending the wrong thing through a port: `[object Object]`* — opened 2019-09-16 by `lydell`, **still open** ([issue](https://github.com/elm/core/issues/1043)) | **src** |
| 10 | *An Introduction to Elm*, "Ports" — "**Sending `Json.Encode.Value` through ports is recommended.** … This is from the time before JSON decoders" — <https://guide.elm-lang.org/interop/ports.html> (raw: `evancz/guide.elm-lang.org`, `book/interop/ports.md`) | **doc** |
| L | All measurements marked **local**: Elm 0.19.1 via npm `elm@0.19.1-6`, elm/core 1.0.5, elm/json 1.1.3, Node on macOS (Darwin 25.5.0), 2026-08-13. Reproduction in [§6](#6--reproduction) | **local** |
| g1–g3 | Gaps — see [Gaps](#gaps-and-where-i-looked) | gap |

---

## What this means for beam-sharp's boundary

Elm **is** a genuine counter-example to Gleam and purerl, but only in a narrow form the spec should
copy exactly: it defends the *port* boundary, *inbound* only, at *shape* level, over a closed type set
chosen so that a structural check is always synthesisable [1][2] — and it still admits `1e300` as an
`Int`, truncates over-wide tuples, and degrades its diagnostic to a bare URL under `--optimize`
(**local**, §5 and §3.2). The *mechanism* transfers to beam-sharp directly and is already specified
here: a type-directed structural check emitted where a foreign value becomes a typed value [2][3] is
ticket 09 §4's guard synthesiser, and Elm's admissible-set rule — reject at the declaration what you
cannot check [1] — is ticket 09's rule arrived at independently, which is real corroboration for a
decision that has no BEAM precedent. The *coverage* does not transfer, and the reason is structural
rather than a matter of effort: Elm's guarantee rests on owning the only door, since
`_Platform_setupIncomingPort` returns `{ send: send }` and `send` *is* the decode [4], so there is no
way into the Elm runtime that does not traverse compiler-emitted code. beam-sharp's foreign callers
are arbitrary processes reaching a typed value through mailbox sends, ETS reads, timers, `EXIT`/`DOWN`
signals and `code_change/3` state — channels that traverse no compiler-emitted code at all, and which
ticket 21 established cannot be ruled out because the BEAM has no link-time closure. So Elm licenses
the claim "a compiler can defend a boundary by checking data, and the check costs a closed type set"
while refusing the claim "therefore the language's guarantees survive its escape hatch" — Elm's
survive because there is one hatch and the compiler built it, and beam-sharp has eight it did not.
Finally, Elm offers nothing for the FFI `-spec` sub-decision: its outbound path is `_Json_wrap`, the
identity function [5], because Elm's own type system already guarantees what leaves — an unverified
outbound claim to a foreign ecosystem is a situation Elm never has to be in.
