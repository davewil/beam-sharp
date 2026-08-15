%%% beam-sharp lexer — the walking-skeleton slice.
%%%
%%% Surface settled by ticket 01 and ticket 08: `->` for clauses (`=>` is reserved
%%% for lambdas, which this slice does not have), `:atom` for atoms, `&&`/`||` in
%%% guards. Builtin type names are lowercase; user types and functions are
%%% PascalCase, which is what lets the grammar tell them apart without a symbol
%%% table.

Definitions.

D          = [0-9]
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
%% Ticket 26 §1's provisional spelling; the surface question is ticket 22's.
record                  : {token, {'record', TokenLine}}.
%% `o with { Total = 500 }` — ticket 26 §2, width-preserving update. C#-only of
%% the two audiences; ticket 26 refused spread, so this is the single form.
with                    : {token, {'with', TokenLine}}.
%% Ticket 17 §6: the only branching construct, spelled postfix as C# spells it.
%% There is no `if`, no `else`, no `cond` and no ternary for this to sit beside,
%% so it is a keyword with nothing to be told apart from.
switch                  : {token, {'switch', TokenLine}}.

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
&&                      : {token, {'&&', TokenLine}}.
\|\|                    : {token, {'||', TokenLine}}.
==                      : {token, {'==', TokenLine}}.
!=                      : {token, {'!=', TokenLine}}.
<=                      : {token, {'<=', TokenLine}}.
>=                      : {token, {'>=', TokenLine}}.

<                       : {token, {'<', TokenLine}}.
>                       : {token, {'>', TokenLine}}.
\+                      : {token, {'+', TokenLine}}.
-                       : {token, {'-', TokenLine}}.
\*                      : {token, {'*', TokenLine}}.
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
