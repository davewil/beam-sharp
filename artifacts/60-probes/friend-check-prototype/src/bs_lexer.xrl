%%% beam-sharp lexer — the walking-skeleton slice.
%%%
%%% Surface settled by ticket 01 and ticket 08: `->` for clauses (`=>` is reserved
%%% for lambdas, which this slice does not have), `:atom` for atoms, and — since
%%% ticket 44 amended 08 — `and`/`or` as the language's one conjunction, in guards
%%% and in patterns alike. Builtin type names are lowercase; user types and
%%% functions are PascalCase, which is what lets the grammar tell them apart
%%% without a symbol table.

Definitions.

D          = [0-9]
H          = [0-9a-fA-F]
UPPER      = [A-Z]
LOWER      = [a-z]
ALNUM      = [a-zA-Z0-9_]
WS         = [\s\t\r\n]

Rules.

{WS}+                   : skip_token.
//[^\n]*                : skip_token.

%% Keywords must precede the identifier rule: leex prefers the earliest rule
%% among equal-length matches.
module                  : {token, {'module', TokenLine}}.
type                    : {token, {'type', TokenLine}}.
when                    : {token, {'when', TokenLine}}.
using                   : {token, {'using', TokenLine}}.
%% The BEAM's own word for this, and what gets emitted. Erlang accepts either
%% spelling and keeps whichever you wrote (measured); B# accepts both and emits
%% the British one, because following the platform costs nothing here.
behaviour               : {token, {'behaviour', TokenLine}}.
behavior                : {token, {'behaviour', TokenLine}}.
%% F12 / ticket 40 §3 — Elixir's PLACEMENT, C#'s WORDS.
%%
%% Both BEAM languages make export an explicit per-function decision and differ
%% only in where it is written: Erlang in a separate `-export` list, Elixir at
%% the definition. Taking Elixir's placement avoids the one thing the list costs
%% — a second site that must agree with the definition, which is the drift
%% `bs_emit`'s single `name/2` funnel exists to prevent. Taking C#'s words
%% follows the map's borrow heuristic: survey all three tiers and take the most
%% accurate word. `def`/`defp` carries Elixir's macro vocabulary B# has no use
%% for; `public`/`private` say the thing plainly to both halves of the audience.
%%
%% Measured before these two lines landed, not inherited from the ticket: no
%% `.bs` file in the repo uses either word for anything, so no name is captured.
public                  : {token, {'public',  TokenLine}}.
private                 : {token, {'private', TokenLine}}.
%% PROTOTYPE for ticket 60 — "who may name this one". Directory-level
%% declaration, same shape as `using`, not a third visibility marker on the
%% signature (60's own sub-question 3).
friend                  : {token, {'friend', TokenLine}}.
%% Ticket 26 §1's provisional spelling; the surface question is ticket 22's.
record                  : {token, {'record', TokenLine}}.
%% `o with { Total = 500 }` — ticket 26 §2, width-preserving update. C#-only of
%% the two audiences; ticket 26 refused spread, so this is the single form.
with                    : {token, {'with', TokenLine}}.
%% Ticket 17 §6: the only branching construct, spelled postfix as C# spells it.
%% There is no `if`, no `else`, no `cond` and no ternary for this to sit beside,
%% so it is a keyword with nothing to be told apart from.
switch                  : {token, {'switch', TokenLine}}.
%% F8: a binding must SAY it is one. In C# a bare `x = 1` ASSIGNS to an existing
%% variable, which is the one thing this language cannot do — so unmarked, it puts
%% mutation in a C# reader's head at exactly the site the language forbids it.
%% `var x = 1` reads as *introduce x*, and `var` meaning "infer the type" is
%% literally correct here, where everything is inferred.
%%
%% It is also not merely free but PAYS: the marker is what lets the parser take a
%% `pattern` directly, which deletes `to_pattern/1` and the parse-wider-then-narrow
%% workaround. Measured — `binding -> pattern '=' expr` without it is 15
%% reduce/reduce and yecc refuses to generate.
%%
%% Free in the corpus: zero occurrences as an identifier, re-measured 2026-08-16.
var                     : {token, {'var', TokenLine}}.

%% THE ONE CONJUNCTION — ticket 44, amending ticket 08.
%%
%% 08 chose `&&`/`||` over Erlang's `,`/`;`. 42 then took C#'s relational pattern
%% whole, and C# spells its PATTERN combinator `and`/`or` — so for one hour the
%% language had two spellings for one meaning, one line apart:
%%
%%     Classify(>= 4 and <= 7)           -> :reserved
%%     Classify(n) when n >= 4 && n < 8  -> :reserved
%%
%% C#'s split costs nothing there because patterns and expressions rarely touch.
%% beam-sharp's defining move puts patterns in the PARAMETER position, so a
%% pattern and a guard sit on the same line in every non-trivial function. The
%% condition that makes C#'s split free is exactly the one this language does not
%% satisfy.
%%
%% Erlang's own `and` does not short-circuit where `andalso` does, which is the
%% one thing that could have made this a false friend. Measured on OTP 28
%% (`44a_guard_operator_probe.escript`): in GUARD context the distinction is
%% unobservable — a guard that raises simply fails — and a guard is the only
%% context beam-sharp lowers a conjunction into.
%%
%% `&&` and `||` are REMOVED, not kept as synonyms: write cost carries little
%% weight and read cost carries full weight, and a reader meeting both spellings
%% must ask whether the difference is meaningful. Two lexer rules deleted, which
%% is a rare direction of travel for a language decision.
%%
%% The cost is the variable namespace: a parameter named `and` or `or` is now
%% illegal. Measured in the corpus: zero occurrences.
and                     : {token, {'and', TokenLine}}.
or                      : {token, {'or', TokenLine}}.

%% Ticket 20 §5's refinement — `type Octet = int where value >= 0 and value <= 255`.
%%
%% One keyword and no second construct: a refinement is a `type` declaration with
%% a predicate on it, so §5's two tiers are told apart by what the predicate SAYS
%% rather than by how it is spelled. Guard-decidable predicates are reasoned
%% about; anything else is refused here (F2's Out of scope, and 20 §5 as amended
%% by 29 bars the opaque tier from clause heads anyway).
%%
%% `value` is deliberately NOT a keyword. It is an ordinary lowercase identifier
%% that the refinement translator gives meaning to, which keeps it out of the
%% variable namespace question entirely — a parameter named `value` stays legal,
%% and the name only means the subject inside a `where`.
where                   : {token, {'where', TokenLine}}.

%% THE TWO KEYWORD ATOMS. Ticket 10 and `LANGUAGE.md` §4 — *"`true` and `false`
%% are the only keyword atoms, `bool` is an ordinary alias"* — which the reference
%% marked **shipped** and which was not. Without these two rules a bare `true`
%% lexes as an ordinary lowercase identifier, and in pattern position that is a
%% VARIABLE: `Decide(true, p) -> :ack` binds a variable named `true`, matches
%% everything, and the second clause is dead.
%%
%% Found by running ticket 17 §6's own tuple-subject example, not by reading. It
%% is the worst shape a defect can take here — the program COMPILES and means
%% something else — and the only trace is an unreachable-clause warning that
%% reads like a comment on the code rather than a report of a misparse. It has
%% nothing to do with `switch`: `Decide(false, p)` returned `:ack` on master.
true                    : {token, {atom_lit, TokenLine, true}}.
false                   : {token, {atom_lit, TokenLine, false}}.

%% A STRING LITERAL — ticket 20 §4, *"a literal is a `string` by construction"*.
%%
%% The compiler sees the bytes, so the UTF-8 property is established HERE, at
%% compile time and at zero runtime cost. That is the sentence that keeps every
%% literal in the language from paying an O(n) validation, and it is why the
%% check belongs in the lexer rather than anywhere later: this is the only place
%% that has the bytes and a line number at the same time.
%%
%% `bsc` reads the file with `binary_to_list/1`, so `TokenChars` is a LATIN-1
%% byte list and a multi-byte character arrives as its separate bytes. That is
%% exactly what is wanted — the bytes are already UTF-8-encoded, so validating
%% them is a decode attempt and emitting them needs no re-encoding.
%% `\\.` is one literal backslash then any character; `[^"\\]` is any character
%% that is neither. Written with a doubled backslash it matches TWO backslashes
%% and no escape ever lexes — which surfaces as `illegal characters` on the
%% quote, several characters after the real fault.
"(\\.|[^"\\])*"         : str_token(TokenLine, TokenChars).

%% :atom — ticket 10 settled the sigil, and the universe is open, so nothing
%% declares an atom and the lexer simply interns what it sees.
:{LOWER}{ALNUM}*        : {token, {atom_lit, TokenLine, list_to_atom(tl(TokenChars))}}.
:true                   : {token, {atom_lit, TokenLine, true}}.
:false                  : {token, {atom_lit, TokenLine, false}}.

%% A quoted atom, for anything the bare sigil cannot spell. Ticket 26 §1 mints a
%% record's tag from its QUALIFIED name, so `:'Shop.Order'` is the shape the
%% minting produces and the shape a user writes when spelling the same type out
%% by hand — which is F3.2's whole test.
:'[^']*'                : {token, {atom_lit, TokenLine,
                                   list_to_atom(lists:sublist(TokenChars, 3, length(TokenChars) - 3))}}.

%% A HEX INTEGER — F13, and not in ticket 30's table.
%%
%% The decided surface writes AMQP's frame sentinel as `0xCE:8`, and before this
%% rule `0xCE` was the integer `0` followed by the variable `xCE`: a syntax error
%% several tokens later, in a construct the author had every reason to think was
%% settled. Longest-match puts it ahead of `{D}+` with no ordering dependency.
%%
%% It is added EVERYWHERE rather than inside a binary segment, because a lexer
%% that is context-sensitive for one construct's benefit is a worse thing to own
%% than the gap was, and because a language that can MATCH `0xCE` and cannot
%% WRITE it would be absurd. Both the marker and the digits are case-insensitive,
%% which is what every language in ticket 30's survey does and what a constant
%% copied out of an RFC will be written as.
0[xX]{H}+               : {token, {integer, TokenLine,
                                   list_to_integer(lists:nthtail(2, TokenChars), 16)}}.
{D}+                    : {token, {integer, TokenLine, list_to_integer(TokenChars)}}.

_                       : {token, {'_', TokenLine}}.

%% PascalCase: a user type or a function name.
{UPPER}{ALNUM}*         : {token, {uident, TokenLine, list_to_atom(TokenChars)}}.

%% lowercase: a variable, a parameter, or a builtin type (`int`, `atom`, `term`).
{LOWER}{ALNUM}*         : {token, {lident, TokenLine, list_to_atom(TokenChars)}}.

%% Two-character operators before their one-character prefixes.
%% `.` calls into a foreign module (`:ets.lookup`) and projects a record field.
%% `..` is matched first by longest-match, so the two never collide.
\.                      : {token, {'.', TokenLine}}.

%% `..` is the rest marker in `[h, ..t]` — ticket 28 adopted the C# collection
%% expression spelling in both pattern and construction position.
\.\.                    : {token, {'..', TokenLine}}.
->                      : {token, {'->', TokenLine}}.
%% The arrow ticket 08 reserved and nothing used until F7. `->` is a clause and
%% `=>` is a switch arm; two arrows, two jobs. Longest-match keeps it off the
%% `=` rule below without depending on rule order.
=>                      : {token, {'=>', TokenLine}}.
%% `&&` and `||` used to be here. Ticket 44 removed them — see the `and`/`or`
%% rules above. They are not kept as synonyms, so `n > 0 && n < 5` is now a
%% syntax error rather than a second way to write the same guard.
==                      : {token, {'==', TokenLine}}.
!=                      : {token, {'!=', TokenLine}}.
<=                      : {token, {'<=', TokenLine}}.
>=                      : {token, {'>=', TokenLine}}.

%% F13 — THE BINARY PATTERN'S OPENING BRACKET, AND ONLY THE OPENING ONE.
%%
%% Ticket 30's table names `<<` as the missing token and says nothing about the
%% closing end. The closing end is the one with a live collision: `list<list<int>>`
%% PARSES AND RUNS, so a `>>` rule here would swallow it by longest-match and the
%% failure would be a syntax error in generic code with no binary anywhere near
%% it. The grammar closes a binary pattern on two separate `'>'` tokens instead,
%% which is exactly what this file already emits there.
%%
%% Safe in this direction because no existing form puts two `<` adjacent: a
%% generic's open bracket is always preceded by a name (`list<`, `Result<`), so
%% `list<list<int>>` still lexes `list` `<` `list` `<` `int` `>` `>`. Erlang
%% resolves the same collision the same way round; C# resolves the generic case
%% in the parser because it has a `>>` OPERATOR to protect, and this language has
%% none — ticket 10 dropped the shift operators with the rest of C#'s numeric
%% tower.
<<                      : {token, {'<<', TokenLine}}.
<                       : {token, {'<', TokenLine}}.
>                       : {token, {'>', TokenLine}}.
\+                      : {token, {'+', TokenLine}}.
-                       : {token, {'-', TokenLine}}.
\*                      : {token, {'*', TokenLine}}.
%% F26 / ticket 38. `/` is TRUNCATED INTEGER DIVISION on two `int`s and lowers to
%% Erlang's `div`, never its `/`, which is float division. `%` is the remainder
%% that division leaves, signed by the dividend. `%` is escaped because leex
%% reads a bare one as the start of a comment — unescaped, the rule vanishes and
%% the token is silently never produced.
/                       : {token, {'/', TokenLine}}.
\%                      : {token, {'%', TokenLine}}.
=                       : {token, {'=', TokenLine}}.
%% The field separator in a record declaration and a record pattern. Ticket 26
%% §2's split — colon for matching, equals for assigning — which the atom sigil
%% forces anyway, since `Status: :placed` puts two colons together.
%%
%% Longest-match keeps this off the atom rule: `:placed` is six characters and
%% wins, `: ` is not an atom at all. The cost is that `Id:int` lexes `:int` as an
%% atom; the parser catches that shape by name rather than letting it surface as
%% an unhelpful syntax error.
:                       : {token, {':', TokenLine}}.
%% Not a language construct — ticket 26 §4 says there are no absent fields. It is
%% lexed so the parser can refuse `Notes?: int` by name instead of the scanner
%% failing on an illegal character.
\?                      : {token, {'?', TokenLine}}.
%% Ticket 17 §1 and §4 — the pipe and the valve. Longest-match is what keeps all
%% three off each other: `|?>` is three characters and wins over `|>`, which wins
%% over the union bar, so no lexer state and no lookahead is involved. The `?` is
%% free because ticket 10 dropped the ternary, and it sits INSIDE the `|>`
%% silhouette so the valve reads as a variant of the pipe rather than a new token.
\|\?>                    : {token, {'|?>', TokenLine}}.
\|>                      : {token, {'|>', TokenLine}}.
\|                      : {token, {'|', TokenLine}}.
,                       : {token, {',', TokenLine}}.
\(                      : {token, {'(', TokenLine}}.
\)                      : {token, {')', TokenLine}}.
\{                      : {token, {'{', TokenLine}}.
\}                      : {token, {'}', TokenLine}}.
\[                      : {token, {'[', TokenLine}}.
\]                      : {token, {']', TokenLine}}.

Erlang code.

%% Unescape, then validate. The order matters: an escape produces a byte, so
%% validating first would read the source spelling rather than the value.
str_token(Line, Chars) ->
    Body = lists:sublist(Chars, 2, length(Chars) - 2),
    case unescape(Body, []) of
        {error, Msg} ->
            {error, Msg};
        {ok, Bytes} ->
            case utf8_ok(Bytes) of
                true ->
                    {token, {string_lit, Line, Bytes}};
                false ->
                    %% Ticket 29 §4 told ticket 20 to STATE this divergence, and
                    %% this is where it is stated in executable form: C# and
                    %% TypeScript both substitute U+FFFD here. beam-sharp
                    %% refuses, because a silent replacement manufactures the
                    %% very invalid string the entry check exists to prevent —
                    %% and it would do it inside the one construct 20 §4 exempts
                    %% from ever being checked again.
                    {error, "string literal is not valid UTF-8"}
            end
    end.

%% Deliberately a closed set. An unknown escape is an error rather than the
%% character itself, so that adding `\u` later cannot change the meaning of a
%% program that already compiles.
unescape([], Acc)             -> {ok, lists:reverse(Acc)};
unescape([$\\, $"  | T], Acc) -> unescape(T, [$"  | Acc]);
unescape([$\\, $\\ | T], Acc) -> unescape(T, [$\\ | Acc]);
unescape([$\\, $n  | T], Acc) -> unescape(T, [$\n | Acc]);
unescape([$\\, $t  | T], Acc) -> unescape(T, [$\t | Acc]);
unescape([$\\, $r  | T], Acc) -> unescape(T, [$\r | Acc]);
unescape([$\\, $0  | T], Acc) -> unescape(T, [0   | Acc]);
unescape([$\\, C   | _], _)   -> {error, "unknown escape \\" ++ [C]};
unescape([C | T], Acc)        -> unescape(T, [C | Acc]).

%% A decode attempt over the raw bytes. `unicode:characters_to_binary/2` returns
%% an error tuple rather than replacing, which is the behaviour this needs and
%% is exactly where the two borrowed audiences go the other way.
utf8_ok(Bytes) ->
    case unicode:characters_to_binary(list_to_binary(Bytes), utf8, utf8) of
        B when is_binary(B) -> true;
        _                   -> false
    end.
