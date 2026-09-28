# 112 — Prior art on template strings: Erlang, Elixir, Gleam, C#, TypeScript

Research for [ticket 112](../issues/112-an-arithmetic-operand-with-no-numeric-part.md), 2026-09-28.
The ticket asks whether `id.Lab + "/" + id.Model` is refused. The question behind it is how
template (interpolated) strings are built in the languages B# borrows from, and what each one
lowers to.

**The survey's answer.** Every one of the five builds a template string by flat concatenation, and
the languages differ on two things only: what a hole will take, and whether `+` is the joining
operator. On the BEAM, both Elixir's `"#{x}"` and Gleam's `<>` lower to a single Erlang binary
construction, `<<A/binary, "/", B/binary>>`. Elixir wraps each hole in an inline `is_binary` test,
falls back to the `String.Chars` protocol, and raises at run time when no implementation exists.
Since 1.19 it also warns at compile time. Gleam has no interpolation. Its maintainer closed the
proposal in 2022 to "see how far we get with `<>`", and that proposal required every hole to be a
`String`. Erlang has no interpolation either. EEP 62 proposes one, and its pull request has been
marked stalled since 2023-09-13. C# converts anything implicitly through `ToString`, never fails,
and lowers to `string.Concat` when every hole is a `string`, or to `DefaultInterpolatedStringHandler`
otherwise. JavaScript converts anything with `ToString` and throws only on a `Symbol`, which
TypeScript turns into a compile error. Only the BEAM languages allow a concatenation in a pattern,
and only as a literal prefix. Only TypeScript has template strings at the type level.

Everything below is MEASURED or CITED, never both in one sentence. *Measured* means a probe run for
this file on this machine produced the output quoted. *Cited* means a primary source was fetched
for this file and says it. Every GitHub link is pinned to the tag or commit that was read.

| arm | instrument | what it can show |
|---|---|---|
| Erlang | `erl`/`erlc` OTP 28 (mise, the pinned toolchain) | **measured** for construction, patterns, guards, `io_lib`; **cited** from the OTP-28.5 reference manual and EEPs 62, 64, 66 |
| Elixir | 1.20.4 on OTP 29 (Homebrew's, not the pinned toolchain; the lowering is the Elixir compiler's, not the VM's) | **measured** for the emitted Erlang and the 1.19 warning; **cited** from the v1.20.4 source |
| Gleam | 1.18.1, a dependency-free probe project, generated Erlang read from `build/` | **measured**; **cited** from the v1.18.1 compiler source, issue 1473, discussion 1086 |
| C# | .NET SDK 9.0.306, a console project; method calls read back from the IL by reflection | **measured**; **cited** from Roslyn at `90083ec`, the C# 10 and 11 proposals, the C# standard, the .NET runtime at `5e29b8e` |
| TypeScript / JS | Node 24.19.0 for runtime semantics; no `tsc` on this machine | **measured** for JS runtime only; the TypeScript arm is **cited** entirely, from checker and transformer source at v6.0.3 / v5.9.3 and the handbook |

## Where B# stands, for orientation

Recorded in the repo, not researched here. `$` was set aside for C# interpolated strings when the
match token was chosen ([ticket 45](../issues/45-match-token.md), the candidates table).
Conversions are spelled `String.FromInt`, `String.FromFloat`, `String.FromAtom`
([ticket 97](../issues/97-conversions.md) Q1), and that ticket's own example builds text as a list,
`["£", String.FromInt(cents / 100), ".", Pence(cents % 100)]`. A record's own module may implement
a protocol ([ticket 99](../issues/99-protocols-revisited.md), decisions entry).
[Ticket 25](../issues/25-exemplar-programs.md) findings around lines 541 to 634 record that exemplar
25e needed an iodata type and died on `type Iodata = binary | list<Iodata>`.

## Erlang

### 1. Surface

Erlang has no interpolation. A double-quoted string is a list of code points, and two adjacent
string literals are concatenated at compile time
([erlang.org, data types, String](https://www.erlang.org/doc/system/data_types.html#string);
[source, L470-L494](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/data_types.md#L470-L494)).
OTP 27 added triple-quoted strings, which are indented and verbatim with no escape sequences
([same page, L497-L509](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/data_types.md#L497-L509);
[EEP 64, status Final/27](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0064.md#L1-L7)).
OTP 27 also added sigils. `~"..."` and `~b"..."` are UTF-8 binaries, `~B` and `~S` are verbatim,
and `~s` is a code-point list. Delimiters are `() [] {} <>` or ``/ | ' " ` #`` or triple quotes
([erlang.org, data types, Sigil](https://www.erlang.org/doc/system/data_types.html#sigil);
[source, L613-L703](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/data_types.md#L613-L703)).
EEP 66 states that sigils do *not* interpolate, and that "It has not been decided how or even *if*
string interpolation will be implemented in Erlang"
([EEP 66, L471-L495](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0066.md#L471-L495)).

EEP 62 (Draft, 2023) proposes four prefixed forms, `bf"…~Expr~…"`, `lf`, `bd` and `ld`, for a binary
or list result in user-facing or debug formatting. It gives no format specifiers
([EEP 62](https://www.erlang.org/eeps/eep-0062);
[source](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0062.md)).
It explains its delimiter choice under "Why not use Elixir's syntax?": *"Elixir uses `#{...}` …
Unfortunately, this conflicts with Erlang's syntax for maps. Elixir's maps use `%{...}`, so it
doesn't have that conflict"*
([L116-L121](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0062.md#L116-L121)).
Its reference implementation, [erlang/otp#7343](https://github.com/erlang/otp/pull/7343), is open
and labelled `stalled`. The OTP team's comment of 2023-09-13 says it "involves many small decisions
that need to be consistent and well-thought, e.g., symbol for sigils, complexity of the lexer and
parser given that it is defined in a recursive manner"
([comment](https://github.com/erlang/otp/pull/7343#issuecomment-1717596887)).

The nearest thing Erlang ships is `io_lib:format/2` with control sequences. `~s` prints an iolist,
binary or atom without quotes, `~ts` accepts `unicode:chardata()`, and `~p` / `~w` print any term in
Erlang syntax ([io.erl, L925-L970](https://github.com/erlang/otp/blob/OTP-28.5/lib/stdlib/src/io.erl#L925-L970);
[erlang.org, io:fwrite/3](https://www.erlang.org/doc/apps/stdlib/io.html#fwrite/3)).

### 2. What a hole accepts

There is no hole. In `io_lib:format`, the control sequence picks the conversion: `~s` refuses a
list with integers above 255 with a `badarg` at run time unless `t` is given, and `~p` takes any
term ([io.erl, L925-L958](https://github.com/erlang/otp/blob/OTP-28.5/lib/stdlib/src/io.erl#L925-L958)).
EEP 62's user-facing forms were designed to raise `badarg` rather than print an Erlang-specific term
such as a tuple, *"to push the developer to make an explicit formatting decision"*
([L86-L93](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0062.md#L86-L93)).

### 3. What it lowers to

Joining two binaries is a bit-syntax construction with `/binary` segments. A binary segment with no
size interpolates the whole value, and an ill-sized value raises
([expressions, Binary segments, L1456-L1497](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/expressions.md#L1456-L1497)).
Measured, OTP 28:

```erlang
key(Lab, Model) -> <<Lab/binary, "/", Model/binary>>.
%% p:key(<<"Lab">>, <<"M">>)  ->  <<"Lab/M">>
%% p:key(<<"Lab">>, 42)       ->  error:badarg
```

`++` concatenates lists ([expressions, List Operations](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/expressions.md#L1062-L1084)).
EEP 62 says its forms would be *"desugared into calls to functions from the `io_lib` module"*
([L123-L135](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0062.md#L123-L135)).

### 4. Result type

A binary construction gives a flat binary. `io_lib:format/2` returns `chars()`, defined as
`[char() | chars()]`, a possibly deep list
([io_lib.erl, L122 and L329-L334](https://github.com/erlang/otp/blob/OTP-28.5/lib/stdlib/src/io_lib.erl#L329-L334)).
Measured: `io_lib:format("~ts/~p", [~"Lab", #{a => 1}])` returned
`["Lab",47,[35,123,[["a"," => ","1"]],125]]`. The builder form is `iodata()`, defined as
`iolist() | binary()`, "meant to be output using any I/O module"
([erlang.erl, L138-L157](https://github.com/erlang/otp/blob/OTP-28.5/erts/preloaded/src/erlang.erl#L138-L157);
[erlang.org, iodata()](https://www.erlang.org/doc/apps/erts/erlang.html#t:iodata/0)). The
efficiency guide calls appending to a binary in a loop efficient, because the runtime avoids
copying the accumulator, and prepending not efficient
([binaryhandling.md, L28-L60](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/efficiency_guide/binaryhandling.md#L28-L60);
[erlang.org](https://www.erlang.org/doc/system/binaryhandling.html)).

### 5. Patterns

`f("prefix" ++ Str)` is valid and is sugar for `[$p,$r,…|Str]`
([expressions, String Prefix in Patterns, L187-L199](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/expressions.md#L187-L199)).
In a binary pattern, a segment with no size is allowed only as the last element
([L1370-L1372](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/expressions.md#L1370-L1372)),
so `<<"/users/", Id/binary>>` matches a prefix, and a suffix or infix needs a size. Measured:
`route(<<"/users/", Id/binary>>)` on `<<"/users/42">>` gives `<<"42">>`. A sigil that produces a
literal is valid in a pattern, and one that produces a call is not
([EEP 66, Patterns and Expressions, L164-L172](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0066.md#L164-L172)).

### 6. Guards

Guard expressions include "Expressions that construct atoms, integer, floats, lists, tuples,
records, binaries, and maps"
([expressions, Guard Expressions, L2253-L2270](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/expressions.md#L2253-L2270)).
Measured: `g(A, B) when <<A/binary, ":", B/binary>> =:= ~"v1:delete"` returns `true` for
`(<<"v1">>, <<"delete">>)` and `false` for `(1, <<"delete">>)`. The failed construction makes the
guard fail rather than raise.

## Elixir

### 1. Surface

`"…#{expr}…"` interpolates in double-quoted strings and in heredocs. `<>` concatenates binaries
([getting-started/basic-types.md, L200-L220](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/pages/getting-started/basic-types.md#L200-L220)).
Lowercase textual sigils (`~s`) interpolate and escape. Uppercase ones (`~S`) do neither. Sigils take
eight delimiters and heredoc quotes
([sigils.md, L92-L101](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/pages/getting-started/sigils.md#L92-L101)).
The tokenizer treats `\#{` as literal text
([elixir_interpolation.erl, L58-L61](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/src/elixir_interpolation.erl#L58-L61)).
Measured: `"\#{x}"` is the four bytes `#{x}`. There are no format specifiers in the hole.

### 2. What a hole accepts

Anything that implements `String.Chars`. The protocol's own doc says interpolation calls
`to_string/1`, and that `"foo#{bar}"` is the same as `"foo" <> to_string(bar)`
([string/chars.ex, L7-L27](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/string/chars.ex#L7-L27);
[hexdocs, String.Chars](https://hexdocs.pm/elixir/String.Chars.html)). The standard library
implements it for atoms, binaries, lists, integers, floats
([chars.ex](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/string/chars.ex)),
and a non-binary bitstring raises `Protocol.UndefinedError`
([L39-L50](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/string/chars.ex#L39-L50)).
The guide shows a tuple raising `Protocol.UndefinedError` and points to `inspect/1` instead
([protocols.md, L215-L232](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/pages/getting-started/protocols.md#L215-L232)).
Measured: `"#{%{a: 1}}/b"` raised `protocol String.Chars not implemented for Map`.

Since 1.19 the type checker warns at compile time: "If you pass a value that does not implement
said protocol, Elixir will now emit a warning accordingly"
([CHANGELOG v1.19.0](https://github.com/elixir-lang/elixir/blob/v1.19.0/CHANGELOG.md#type-checking-of-protocol-dispatch-and-implementations)).
The checker tags the call as `:interpolation`
([module/types/of.ex, L640-L648](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/module/types/of.ex#L640-L648))
and prints "incompatible value given to string interpolation", with advice to convert explicitly
or implement the protocol
([module/types/apply.ex, L2137-L2145 and L2196-L2207](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/module/types/apply.ex#L2137-L2207)).
Measured: the warning appears under `mix compile` for a `%Range{}` and a map literal, and the module
still compiles. Under bare `elixir` with `Code.compile_file/1` the same file printed no warning.
The diagnostic code reads `mod.__protocol__(:impls)` and has a separate message for
`{:consolidated, []}` ([apply.ex, L2181-L2194](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/module/types/apply.ex#L2181-L2194)),
so the check appears to need consolidated protocols. That last step is an inference from the code,
not a documented rule.

### 3. What it lowers to

The parser builds `{'<<>>', Meta, Parts}`, and each hole becomes
`Kernel.to_string(Expr)::binary` with `from_interpolation` metadata
([elixir_parser.yrl, L1081-L1093](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/src/elixir_parser.yrl#L1081-L1093)).
`Kernel.to_string/1` is a macro for `String.Chars.to_string/1`
([kernel.ex, L3499-L3501](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/kernel.ex#L3499-L3501)).
The call is dropped when the argument is already known to be a string, such as a literal or an
`Enum.join` call ([elixir_rewrite.erl, L243-L247 and L352-L362](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/src/elixir_rewrite.erl#L243-L362)).
Otherwise the Erlang pass inlines a fast path: a `case` that returns a binary unchanged and calls
the protocol for anything else
([elixir_erl_pass.erl, L563-L577](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/src/elixir_erl_pass.erl#L563-L577)).
Measured, the Erlang abstract code Elixir 1.20.4 emitted:

```erlang
%% def key(lab, model), do: "#{lab}/#{model}"
key(_lab@1, _model@1) ->
    <<case _lab@1 of
          _1 when is_binary(_1) -> _1;
          _1 -> 'Elixir.String.Chars':to_string(_1)
      end/binary,
      "/",
      case _model@1 of
          _2 when is_binary(_2) -> _2;
          _2 -> 'Elixir.String.Chars':to_string(_2)
      end/binary>>.

%% def cat(lab, model), do: lab <> "/" <> model
cat(_lab@1, _model@1) ->
    <<_lab@1/binary,"/",_model@1/binary>>.
```

`<>` flattens a chain into one `<<…>>` with `::binary` segments and raises `ArgumentError` at
compile time on a literal non-binary operand
([kernel.ex, L2136-L2217](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/kernel.ex#L2136-L2217)).
Its doc says it "Raises an `ArgumentError` if one of the sides aren't binaries"
([same, L2137-L2139](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/kernel.ex#L2137-L2139);
[hexdocs, Kernel.<>/2](https://hexdocs.pm/elixir/Kernel.html#%3C%3E/2)).

### 4. Result type

A flat binary, from one `<<…>>` construction (measured above). Iodata is a separate, explicit
choice; interpolation never produces it.

### 5. Patterns

`"foo" <> x = "foobar"` is allowed "as long as the left argument is a literal binary"
([kernel.ex, L2146-L2152](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/kernel.ex#L2146-L2152)).
A variable on the left raises "cannot perform prefix match because the left operand of <> has
unknown size" ([L2208-L2216](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/kernel.ex#L2208-L2216)).
Inside a match or guard, an interpolation is accepted only if its argument expands to a literal
binary ([elixir_bitstring.erl, L141-L153](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/src/elixir_bitstring.erl#L141-L153)).
Measured: `def route("/users/" <> id)` compiles to `route(<<"/users/",_id@1/binary>>)`.
`def p("/#{@pre}/" <> id)` with a module attribute compiles. `def q("/#{y}/" <> id)` fails with
"cannot invoke remote function String.Chars.to_string/1 inside a match".

### 6. Guards

`<>` is allowed in guards on the same terms as in patterns
([kernel.ex, L2146-L2147](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/kernel.ex#L2146-L2147)).
Measured: `def guarded(x) when x <> "!" == "hi!"` compiles to
`guarded(_x@1) when <<_x@1/binary,"!">> == <<"hi!">>`. An interpolation with a variable hole in a
guard is refused: "cannot invoke remote function String.Chars.to_string/1 inside a guard".

## Gleam

### 1. Surface

Gleam has no interpolation. Strings are double-quoted, may span lines, and have the escapes `\"`,
`\\`, `\f`, `\n`, `\r`, `\t` and `\u{…}`. `<>` concatenates
([tour, Strings](https://tour.gleam.run/basics/strings/);
[source](https://github.com/gleam-lang/language-tour/blob/234cb0284d91c458fa26e1b66e4b0276597d722f/src/content/chapter0_basics/lesson09_strings/en.html)).
There is no raw form and no format specifier in the language.

The maintainer's reasoning is on the record in two places. Louis Pilfold opened
[discussion 1086](https://github.com/gleam-lang/gleam/discussions/1086) on 2021-05-03. It proposes
typed holes (`String` by default; `int`, `float` and a `debug` annotation for anything else) and
mentions "pattern matching on string prefixes" as a future use. The discussion is still open. He
then filed [issue 1473](https://github.com/gleam-lang/gleam/issues/1473) on 2022-01-20 with
`"Hello, ${name}!"` and these rules:

> The interpolated expression within the `${}` must be of type `String`. In future we could permit
> other types, but not for this first version.

The Erlang output it specified is `<<"Hello, "/utf8, Name/binary, "!"/utf8>>`, and the JavaScript
output a native template literal. He closed it on 2022-11-05: *"Closing this because I would like to
see how far we get with `<>` for now."*
([comment](https://github.com/gleam-lang/gleam/issues/1473#issuecomment-1304456935)). When the
request came back in 2025 for i18n, he replied that language-level interpolation *"would be syntax,
so you couldn't load it from a file or any external source. Language level string interpolation has
the same limitations as the string concat operator."*
([comment](https://github.com/gleam-lang/gleam/issues/1473#issuecomment-3213379867)).

### 2. What `<>` accepts

Both operands must be `String`. The type checker assigns `(string(), string())` to
`BinOp::Concatenate` ([type_/expression.rs, L1923](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/type_/expression.rs#L1923)).
There is no implicit conversion, so a mismatched type is a compile error.

### 3. What it lowers to

Erlang: *"String concatenation is not a binop at all! It's just building a bit array."* Each operand
becomes a `/binary` segment, except a literal string, which becomes `/utf8`
([erlang.rs, L2459-L2490 and L2518-L2520](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/erlang.rs#L2459-L2520)).
JavaScript: `<>` prints as `+`
([javascript/expression.rs, L2111-L2113](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/javascript/expression.rs#L2111-L2113)).
Measured, Gleam 1.18.1 on the Erlang target:

```erlang
-spec model_key(binary(), binary()) -> binary().
model_key(Lab, Model) ->
    <<<<Lab/binary, "/"/utf8>>/binary, Model/binary>>.
```

### 4. Result type

A flat `String` (a binary on Erlang). The builder is `gleam/string_tree`, whose doc says it "is
compatible with Erlang's iodata", runs append and prepend in constant time, and warns that the
BEAM's own append optimisation may beat it for building by appending
([string_tree.gleam, L1-L17](https://github.com/gleam-lang/stdlib/blob/v1.0.5/src/gleam/string_tree.gleam#L1-L17);
[hexdocs](https://hexdocs.pm/gleam_stdlib/gleam/string_tree.html)).

### 5. Patterns

`"Hello, " <> name` in a `case` matches a string with that prefix and binds the rest
([tour, String patterns](https://tour.gleam.run/flow-control/string-patterns/)). The AST node is
`StringPrefix` with a literal left side and a variable right side
([ast.rs, L2932-L2941](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/ast.rs#L2932-L2941)),
and it lowers to a binary pattern
([erlang/pattern.rs, L195-L225](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/erlang/pattern.rs#L195-L225)).
Measured: `"/users/" <> id -> id` became `<<"/users/"/utf8, Id/binary>> -> Id`.

### 6. Guards

Gleam 1.15 added string concatenation in clause guards
([changelog v1.15.md, L34-L45](https://github.com/gleam-lang/gleam/blob/v1.18.1/changelog/v1.15.md#L34-L45);
[type_/error.rs, L1256](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/type_/error.rs#L1256)),
with its own codegen path ([erlang.rs, L2929-L2961](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/erlang.rs#L2929-L2961)).

Measured on 1.18.1, and narrow: the changelog's own example,
`_ if version <> ":" <> action == "v1:delete"`, returns `False` for `("v1", "delete")`. The generated
guard is

```erlang
_ when <<Version/binary, <<":"/utf8, Action/utf8>>/binary>> =:= ~"v1:delete" -> true;
```

`Action/utf8` needs an integer, so the construction fails and the guard is false. The two-operand
form `a <> b == "v1delete"` and the literal-right form `a <> ":" == "v1:"` both emit `/binary` for
the variable and return `True`. A search of the Gleam issue tracker for "guard concatenation" found
no report. I did not trace the cause. It matters to ticket 112 only because it is a shipping compiler
getting a concatenation wrong at the guard site, which is one of the sites ticket 112's delta names.

## C\#

### 1. Surface

`$"…{expr[,width][:format]}…"`. `{{` and `}}` escape a brace. A conditional expression in a hole needs
parentheses because `:` starts the format. `$@"…"` and `@$"…"` are verbatim interpolated strings
([learn, $ string interpolation](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/interpolated);
[source, L27-L77](https://github.com/dotnet/docs/blob/e7624b3a05febc0a5e6427a484de1aec9efc1c5e/docs/csharp/language-reference/tokens/interpolated.md#L27-L77)).
The standard's grammar excludes `"`, `\`, `{`, `}` and newlines from a regular interpolated string's
text, and recognises the format only when the `:` is not nested in brackets
([C# standard §12.8.3](https://github.com/dotnet/csharpstandard/blob/107068a0fee88b13e9c46ff64f98343ff29ff8ee/standard/expressions.md#1283-interpolated-string-expressions)).
C# 11 raw strings start with three or more `"`. With interpolation, the number of leading `$` sets how
many braces open a hole, and shorter brace runs are content
([raw-string-literal proposal, L63 and L488-L495](https://github.com/dotnet/csharplang/blob/93d55a09e48c7f36f312bffe2e5b83e8d18031b1/proposals/csharp-11.0/raw-string-literal.md#L488-L495)).
Measured: `$$"""{"lab": "{{id.Lab}}"}"""` printed `{"lab": "Lab"}`.

### 2. What a hole accepts, and how

Any expression. The standard formats the value "according to a default format for the type"
([§12.8.3, L1478](https://github.com/dotnet/csharpstandard/blob/107068a0fee88b13e9c46ff64f98343ff29ff8ee/standard/expressions.md#L1478)).
In the handler, `AppendFormatted<T>` appends nothing for `null`, uses `ISpanFormattable.TryFormat` or
`IFormattable.ToString(null, provider)` when the type has one, and otherwise calls `value.ToString()`
([DefaultInterpolatedStringHandler.cs, L237-L296](https://github.com/dotnet/runtime/blob/5e29b8efdce04de5a09d5bf4053f8ca59d3c9c40/src/libraries/System.Private.CoreLib/src/System/Runtime/CompilerServices/DefaultInterpolatedStringHandler.cs#L237-L296)).
Every type has a `ToString`, and the default returns "the fully qualified name of the object's
type" ([learn, Object.ToString](https://learn.microsoft.com/en-us/dotnet/api/system.object.tostring)).
A record's compiler-generated `ToString` prints `<record type name> { <property name> = <value>, … }`
([learn, records, built-in formatting](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record#built-in-formatting-for-display)).
So there is neither a compile error nor a run-time error for a type with no chosen conversion.
Measured: `$"{new Plain()}"` printed `Plain`, and `$"{id}"` for a record printed
`ModelIdentity { Lab = Lab, Model = M }`.

`+` behaves the same way. With a `string` on either side, a non-string operand is converted "by
invoking the virtual `ToString` method", and `null` becomes the empty string
([C# standard, addition operator, string concatenation](https://github.com/dotnet/csharpstandard/blob/107068a0fee88b13e9c46ff64f98343ff29ff8ee/standard/expressions.md#L4151-L4161)).
Measured: `"n=" + 42 + " p=" + new Plain()` printed `n=42 p=Plain`.

### 3. What it lowers to

Roslyn has three paths
([LocalRewriter_StringInterpolation.cs, L143-L216](https://github.com/dotnet/roslyn/blob/90083ecf59c688110a69cbf3871e5edb2693aadc/src/Compilers/CSharp/Portable/Lowering/LocalRewriter/LocalRewriter_StringInterpolation.cs#L143-L216)):

- If every hole is a `string` with no width or format, it rewrites to a chain of string concatenation
  (the comment: "All fill-ins, if any, are strings, and none of them have alignment or format
  specifiers. We can lower to a more efficient string concatenation").
- If a handler type is available, it lowers to the handler pattern and calls `ToStringAndClear()`.
- Otherwise it lowers to `String.Format("… {0}", new object[] { … })`.

The C# 10 proposal made the handler the default for `string`: "If the type of an interpolated string
is `string` and the type `System.Runtime.CompilerServices.DefaultInterpolatedStringHandler` exists …
the string is lowered using the handler pattern"
([improved-interpolated-strings.md, L214-L270](https://github.com/dotnet/csharplang/blob/93d55a09e48c7f36f312bffe2e5b83e8d18031b1/proposals/csharp-10.0/improved-interpolated-strings.md#L214-L270)).
Its motivation lists what `string.Format` cost: boxing struct arguments and allocating an argument
array ([L12-L33](https://github.com/dotnet/csharplang/blob/93d55a09e48c7f36f312bffe2e5b83e8d18031b1/proposals/csharp-10.0/improved-interpolated-strings.md#L12-L33)).
A handler's `Append…` may return `bool`, and later holes are then not evaluated
([L418-L445](https://github.com/dotnet/csharplang/blob/93d55a09e48c7f36f312bffe2e5b83e8d18031b1/proposals/csharp-10.0/improved-interpolated-strings.md#L418-L445)).

The docs page disagrees with itself. It says a `string`-typed interpolated string is processed by
`DefaultInterpolatedStringHandler`, and two paragraphs later that the compiler "typically transforms it
into a `String.Format` method call"
([interpolated.md, L97-L106](https://github.com/dotnet/docs/blob/e7624b3a05febc0a5e6427a484de1aec9efc1c5e/docs/csharp/language-reference/tokens/interpolated.md#L97-L106)).
The IL settles it. Measured, net9.0 Release, the calls each method makes:

```text
$"{id.Lab}/{id.Model}"   ->  String.Concat(String, String, String)
$"{lab}/{n}"  (n: int)   ->  DefaultInterpolatedStringHandler..ctor(Int32, Int32)
                             .AppendFormatted(String) .AppendLiteral(String)
                             .AppendFormatted(Int32)  .ToStringAndClear()
$"{d,10:F2}"             ->  ..ctor, .AppendFormatted(Double, Int32, String), .ToStringAndClear()
lab + "/" + n            ->  Int32.ToString(), String.Concat(String, String, String)
```

### 4. Result type

`string`, or `IFormattable` / `FormattableString` when converted to one of those at once
([§12.8.3, L1474](https://github.com/dotnet/csharpstandard/blob/107068a0fee88b13e9c46ff64f98343ff29ff8ee/standard/expressions.md#L1474)).
The builder is the handler itself. A custom handler type can receive the interpolated string as a
method argument ([improved-interpolated-strings.md, Summary](https://github.com/dotnet/csharplang/blob/93d55a09e48c7f36f312bffe2e5b83e8d18031b1/proposals/csharp-10.0/improved-interpolated-strings.md#L7-L10)).

### 5. Patterns

The patterns reference and the list-patterns proposal offer two forms, and neither is a string
prefix. A constant pattern takes a constant expression,
including a string literal or a `const`
([learn, patterns, constant pattern](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns#constant-pattern)),
and an interpolated string is a constant when every hole is a constant string
([learn, const](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/const)).
A list pattern applies to any countable and indexable type, and a slice pattern with a subpattern to
any countable and sliceable type. For `string`, the slice uses `string.Substring`
([list-patterns proposal, L41-L43 and L99](https://github.com/dotnet/csharplang/blob/93d55a09e48c7f36f312bffe2e5b83e8d18031b1/proposals/csharp-11.0/list-patterns.md#L41-L99)).
Measured: `case Route` with `const string Route = $"/{Pre}/"` matched `"/users/"`, and
`['/', 'u', .. var rest]` matched `"/u42"` with `rest == "42"`. That matches characters one at a time,
not a string prefix.

### 6. Guards

Not applicable. C# `when` clauses take any boolean expression.

## TypeScript and JavaScript

### 1. Surface

`` `…${expr}…` ``. In the text, `$` not followed by `{` is literal, and `` ` ``, `\` and `$` are the
characters that need care. Templates may contain line terminators
([ECMA-262, Template Literal Lexical Components](https://tc39.es/ecma262/multipage/ecmascript-language-lexical-grammar.html#sec-template-literal-lexical-components)).
There are no format specifiers. A tagged template `` tag`…` `` calls `tag` with a frozen array of
cooked strings (and a `raw` array) plus the hole values
([GetTemplateObject](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html#sec-gettemplateobject);
[tagged templates](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html#sec-tagged-templates-runtime-semantics-evaluation)).
Measured: ``tag`a${1}b\n${"x"}` `` passed strings `["a","b\n",""]`, raw `["a","b\\n",""]` and values
`[1,"x"]`.

### 2. What a hole accepts

At run time, anything but a `Symbol`. Each hole is converted with `ToString(sub)`, "like
String.prototype.concat rather than the + operator"
([Template Literals, Runtime Semantics: Evaluation](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html#sec-template-literals-runtime-semantics-evaluation)).
`ToString` throws a `TypeError` on a `Symbol` and uses `ToPrimitive(arg, string)` for an object
([ToString](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tostring)).
Measured, Node 24: `` `${o}` `` gave `str` while `"" + o` gave `1` for an object with both `toString`
and `valueOf`. `` `${{}}` `` gave `[object Object]`, `` `${Symbol("s")}` `` threw
`TypeError: Cannot convert a Symbol value to a string`.

TypeScript accepts any type in a hole, and reports a compile error only for a symbol-like type,
"Implicit conversion of a 'symbol' to a 'string' will fail at runtime"
([checker.ts, L41282-L41301](https://github.com/microsoft/TypeScript/blob/v6.0.3/src/compiler/checker.ts#L41282-L41301)).
For `+`, a string on either side makes the result `string` whatever the other operand is
([checker.ts, L40826-L40870](https://github.com/microsoft/TypeScript/blob/v6.0.3/src/compiler/checker.ts#L40826-L40870)).

### 3. What it lowers to

For targets ES2015 and later TypeScript leaves templates alone, since the ES2015 transformer is added
only `if (languageVersion < ScriptTarget.ES2015)`
([transformer.ts, L181-L182](https://github.com/microsoft/TypeScript/blob/v6.0.3/src/compiler/transformer.ts#L181-L182)).
That transformer rewrites `` `a${x}b` `` to `"a".concat(x, "b")`, chaining one `.concat` call per span
([es2015.ts at v5.9.3, L4804-L4821](https://github.com/microsoft/TypeScript/blob/v5.9.3/src/compiler/transformers/es2015.ts#L4804-L4821)),
which keeps the `ToString` rather than `+` semantics. TypeScript 6.0 deprecated `target: es5`, the
a target below ES2015 ([TypeScript 6.0 release notes](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-6-0.html)).

### 4. Result type

A flat string. The builder form is the tagged template: the tag function receives the parts and may
return any type ([tagged templates](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html#sec-tagged-templates-runtime-semantics-evaluation)).
In a const or template-literal context, the checker types the expression as a template literal type
rather than `string` ([checker.ts, L41293-L41300](https://github.com/microsoft/TypeScript/blob/v6.0.3/src/compiler/checker.ts#L41293-L41300)).

### 5. Patterns and types

JavaScript has no pattern-matching construct. The TC39 proposal is at Stage 1
([tc39/proposals, stage 1](https://github.com/tc39/proposals/blob/main/stage-1-proposals.md);
[proposal-pattern-matching](https://github.com/tc39/proposal-pattern-matching)).

TypeScript has template literal *types*. TS 4.1 introduced them, with union cross-products and
inference from substitution positions (`` `${K}Changed` `` infers `K`)
([4.1 release notes, L8 and L136-L173](https://github.com/microsoft/TypeScript-Website/blob/6556b08756b766fd41d0f887174cb0b042e5f72c/packages/documentation/copy/en/release-notes/TypeScript%204.1.md#L136-L173);
[handbook, Template Literal Types](https://www.typescriptlang.org/docs/handbook/2/template-literal-types.html)).
TS 4.3 made them match patterns: `` `${number}-${number}-${number}` `` accepts `` `1-2-3` ``
([4.3 release notes, L271-L345](https://github.com/microsoft/TypeScript-Website/blob/6556b08756b766fd41d0f887174cb0b042e5f72c/packages/documentation/copy/en/release-notes/TypeScript%204.3.md#L271-L345)).
TS 4.4 allowed pattern types such as `` `hello-${string}` `` in index signatures
([4.4 release notes, L214 and L253](https://github.com/microsoft/TypeScript-Website/blob/6556b08756b766fd41d0f887174cb0b042e5f72c/packages/documentation/copy/en/release-notes/TypeScript%204.4.md#L214-L253)).
These are types only. Nothing at run time checks them.

### 6. Guards

Not applicable.

## Comparison

| | Erlang (OTP 28) | Elixir 1.20 | Gleam 1.18 | C# (.NET 9 SDK) | TypeScript 6 / JS |
|---|---|---|---|---|---|
| Interpolation | none (EEP 62 draft, PR stalled) | `"#{x}"`, `~s`, heredocs | none (issue 1473 closed) | `$"{x,w:f}"`, `$@`, `$$"""` | `` `${x}` ``, tagged |
| Hole takes | n/a; `io_lib` `~s` / `~p` | any `String.Chars` impl | n/a (the 2022 plan: `String` only) | anything, via `ToString` | anything but `Symbol` |
| No conversion | n/a | compile **warning** (1.19+), run-time `Protocol.UndefinedError` | n/a | never fails; type name | TS compile error for `symbol`; JS `TypeError` |
| Concat operator | `<<A/binary, B/binary>>`, `++` for lists | `<>`, binaries only | `<>`, `String` only | `+`, converts the other side | `+`, converts the other side |
| Lowers to | binary construction | one `<<…>>`, `is_binary` fast path per hole | one bit array, `/binary` + `/utf8` | `string.Concat`, else handler, else `string.Format` | native, or `.concat` for ES5 |
| Result | flat binary; `io_lib` gives deep list | flat binary | flat binary | `string` | string |
| Builder | iodata | iodata (explicit) | `string_tree` (iodata) | interpolated string handler | tagged template |
| In patterns | `"p" ++ R`, `<<"p", R/binary>>` | `"p" <> r`, literal left | `"p" <> r`, literal left | constant, or list/slice of chars | none at run time; template literal **types** |
| In guards | binary construction allowed | `<>` yes; interpolation with a variable no | `<>` since 1.15 | n/a | n/a |

## Design axes for B#

Each axis below is a choice the five languages make independently of the others. The table says
which side each language takes. No recommendation is made.

**What a hole accepts.** Four positions exist, not two.

| position | who | source |
|---|---|---|
| only the string type; the author converts | Gleam's 2022 plan for `${}`; Gleam's `<>` today | [issue 1473](https://github.com/gleam-lang/gleam/issues/1473); [type_/expression.rs L1923](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/type_/expression.rs#L1923) |
| an explicit conversion chosen by syntax, per string (EEP 62) or per hole (`io_lib`, discussion 1086) | EEP 62 (`bf` vs `bd`); `io_lib` (`~s` vs `~p`); discussion 1086's `:int` annotations | [EEP 62](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0062.md); [io.erl](https://github.com/erlang/otp/blob/OTP-28.5/lib/stdlib/src/io.erl#L925-L970); [discussion 1086](https://github.com/gleam-lang/gleam/discussions/1086) |
| implicit through a protocol that a type may lack: a warning, then a run-time error | Elixir | [chars.ex](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/string/chars.ex#L7-L27); [CHANGELOG v1.19.0](https://github.com/elixir-lang/elixir/blob/v1.19.0/CHANGELOG.md#type-checking-of-protocol-dispatch-and-implementations) |
| implicit through a conversion every value has | C# (`ToString`); JS (`ToString`, bar `Symbol`) | [DISH.cs L237-L296](https://github.com/dotnet/runtime/blob/5e29b8efdce04de5a09d5bf4053f8ca59d3c9c40/src/libraries/System.Private.CoreLib/src/System/Runtime/CompilerServices/DefaultInterpolatedStringHandler.cs#L237-L296); [ECMA-262 ToString](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tostring) |

**Result: a flat binary or iodata.** All five interpolation or concatenation forms produce a flat
string. A builder is always a separate, explicit form: Erlang's `iodata()` and Gleam's `string_tree`
(which is iodata on Erlang), C#'s interpolated string handler, JS tagged templates. EEP 62's author argued in the pull request that a
template's static shape (the number of holes is known) allows optimisations `io_lib:format` cannot
([comment](https://github.com/erlang/otp/pull/7343#issuecomment-1743018236)). On the BEAM a flat result is one
binary construction (Elixir, measured in its section 3; [Gleam erlang.rs](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/erlang.rs#L2459-L2490)).

**Whether `+` concatenates.**

| side | who | source |
|---|---|---|
| `+` joins strings and converts the other operand | C#, JS / TS | [C# standard](https://github.com/dotnet/csharpstandard/blob/107068a0fee88b13e9c46ff64f98343ff29ff8ee/standard/expressions.md#L4151-L4161); [checker.ts L40826-L40870](https://github.com/microsoft/TypeScript/blob/v6.0.3/src/compiler/checker.ts#L40826-L40870) |
| a separate operator, string operands only | Elixir `<>`, Gleam `<>` | [kernel.ex L2136-L2159](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/kernel.ex#L2136-L2159); [Gleam JS codegen prints `<>` as `+`](https://github.com/gleam-lang/gleam/blob/v1.18.1/compiler-core/src/javascript/expression.rs#L2111-L2113) |
| no operator; bit syntax, or `++` on lists | Erlang | [expressions, List Operations](https://github.com/erlang/otp/blob/OTP-28.5/system/doc/reference_manual/expressions.md#L1062-L1084) |

In C#, `$"{a}/{b}"` over two strings and `a + "/" + b` compile to the same `String.Concat` call
(measured above), so a language may keep one and drop the other without changing the emitted code.

**Pattern use.** The BEAM languages allow a literal-prefix concatenation in a pattern, and lower it to
`<<"prefix", Rest/binary>>`: Erlang (`++` and bit syntax), Elixir (`<>`, literal left), Gleam (`<>`,
literal left). None of the five allows an interpolation with a variable hole in a pattern. Elixir
refuses one at compile time ([elixir_bitstring.erl](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/src/elixir_bitstring.erl#L141-L153), measured).
C# matches only a whole constant, or characters through a list pattern. TypeScript has the pattern at
the type level and nothing at run time. Discussion 1086 floated prefix matching as a future use of
interpolation syntax.

**Escaping and delimiter collisions with braces.** B# uses `{ }` for blocks, records and field sets.

| language | hole delimiter | how a literal brace or hole opener is written | source |
|---|---|---|---|
| C# | `{ }`, the same braces C# uses for blocks and initialisers | double it, `{{` `}}`; or raise the `$` count in a raw string so single braces are text | [interpolated.md L67-L77](https://github.com/dotnet/docs/blob/e7624b3a05febc0a5e6427a484de1aec9efc1c5e/docs/csharp/language-reference/tokens/interpolated.md#L53-L77); [raw-string-literal L63](https://github.com/dotnet/csharplang/blob/93d55a09e48c7f36f312bffe2e5b83e8d18031b1/proposals/csharp-11.0/raw-string-literal.md#L63) |
| Elixir | `#{ }` | `\#{`; or an uppercase sigil | [elixir_interpolation.erl L58-L61](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/src/elixir_interpolation.erl#L58-L61); [sigils.md](https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/pages/getting-started/sigils.md#L92-L101) |
| JS / TS | `${ }` inside backticks | `$` is literal unless followed by `{`; `\` escapes | [ECMA-262 lexical grammar](https://tc39.es/ecma262/multipage/ecmascript-language-lexical-grammar.html#sec-template-literal-lexical-components) |
| Erlang (EEP 62) | `~ ~` | rejected `#{` because Erlang maps are `#{…}` | [EEP 62 L116-L121](https://github.com/erlang/eep/blob/28e2ebbcf91647692dfaee97e0a926e607aab191/eeps/eep-0062.md#L116-L121) |
| Gleam (issue 1473) | `${ }` | `{name}` and `$name}` are plain text; only `${` opens a hole | [comment](https://github.com/gleam-lang/gleam/issues/1473#issuecomment-1017937615) |

C# is the one language here whose braces already mean blocks and object initialisers, as B#'s do, and
it kept `{ }` as the hole delimiter behind a `$` prefix, escaping by doubling. Erlang faced the same
kind of clash with map syntax and proposed a different delimiter. Those are the two recorded
precedents for this collision.

## What could not be found

- The cause of the Gleam 1.18.1 three-operand guard result. It is measured, not traced, and no issue
  was found.
- Any decision on Erlang interpolation after the 2023-09-13 stall. EEP 66 says it is undecided.
- A documented rule that Elixir's interpolation warning needs consolidated protocols. It is inferred
  from `apply.ex` and from the bare-`elixir` run printing nothing.
- A TypeScript measurement. `tsc` is not installed here, so every TypeScript claim is cited from
  source, and only the JavaScript runtime rows are measured.
