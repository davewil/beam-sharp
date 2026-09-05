%%% beam-sharp lexer.
%%%
%%% Keywords are lowercase words, `:name` is an atom, and `true`/`false` are
%%% the only keyword atoms. Builtin type names are lowercase; user types and
%%% functions are PascalCase, which lets the grammar tell them apart without a
%%% symbol table. `->` opens a clause body and `=>` a switch arm, `|>` pipes,
%%% `..` marks a rest, and `and`/`or` are the only conjunctions, in guards and
%%% in patterns alike.

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
%% Both spellings are accepted and one token is produced; the emitter writes
%% the BEAM's own `behaviour`.
behaviour               : {token, {'behaviour', TokenLine}}.
behavior                : {token, {'behaviour', TokenLine}}.
%% Visibility is written on the signature, in C#'s words: `public` exports a
%% function and there is no separate export list (F12, ticket 40 §3).
public                  : {token, {'public',  TokenLine}}.
private                 : {token, {'private', TokenLine}}.
%% `record` declares a record type (ticket 26 §1).
record                  : {token, {'record', TokenLine}}.
%% `o with { Total = 500 }` updates a record without changing its field set;
%% there is no spread form (ticket 26 §2).
with                    : {token, {'with', TokenLine}}.
%% `switch` is the only branching construct, spelled postfix as in C#; there is
%% no `if`, `else` or ternary (ticket 17 §6).
switch                  : {token, {'switch', TokenLine}}.
%% `var` marks a binding that introduces names; a bare `=` only matches. The
%% marker lets the parser take a `pattern` directly: without it
%% `binding -> pattern '=' expr` is 15 reduce/reduce conflicts (measured
%% 2026-08-16) and yecc refuses to generate (F8).
var                     : {token, {'var', TokenLine}}.

%% `raise` crashes on purpose, and is a keyword rather than a prelude function
%% returning `none`: a function would be lexically identical to a call, would
%% keep its signature in another file under one-function-per-file, and would
%% leave no single token that finds every crash site (ticket 12 §5). Being a
%% keyword, it is not available as a name — a parameter called `raise` is a
%% syntax error, the same consequence `and` and `or` carry below.
raise                   : {token, {'raise', TokenLine}}.

%% `and`/`or` are the only conjunctions, in guards and in patterns alike; `&&`
%% and `||` are not accepted, even as synonyms, and a parameter may not be
%% named `and` or `or` (ticket 44, amending ticket 08). Erlang's `and` does not
%% short-circuit, but a guard is the only context a conjunction lowers into and
%% there a raising guard simply fails, so the difference is unobservable.
and                     : {token, {'and', TokenLine}}.
or                      : {token, {'or', TokenLine}}.

%% `where` attaches a predicate to a type alias:
%% `type Octet = int where value >= 0 and value <= 255` (ticket 20 §5).
%% `value` is not a keyword: it is an ordinary identifier the refinement
%% translator gives meaning to, so a parameter named `value` stays legal.
where                   : {token, {'where', TokenLine}}.

%% `true` and `false` are the only keyword atoms (ticket 10, LANGUAGE.md §4).
%% Without these rules a bare `true` lexes as a lowercase identifier, which in
%% pattern position is a variable that matches everything.
true                    : {token, {atom_lit, TokenLine, true}}.
false                   : {token, {atom_lit, TokenLine, false}}.

%% A string literal must be valid UTF-8, checked here because this is the one
%% place with the bytes and a line number at once, so no later stage validates
%% a literal (ticket 20 §4). `TokenChars` is a Latin-1 byte list, so a
%% multi-byte character arrives as its UTF-8 bytes and needs no re-encoding.
%% `\\.` is one backslash then any character; written doubled it would match
%% two backslashes and no escape would ever lex.
"(\\.|[^"\\])*"         : str_token(TokenLine, TokenChars).

%% `:name` is an atom. The universe is open: nothing declares an atom and the
%% lexer interns what it sees (ticket 10).
:{LOWER}{ALNUM}*        : {token, {atom_lit, TokenLine, list_to_atom(tl(TokenChars))}}.
:true                   : {token, {atom_lit, TokenLine, true}}.
:false                  : {token, {atom_lit, TokenLine, false}}.

%% A quoted atom spells what the bare sigil cannot, such as `:'Shop.Order'`,
%% the tag minted from a record's qualified name (ticket 26 §1, F3.2).
:'[^']*'                : {token, {atom_lit, TokenLine,
                                   list_to_atom(lists:sublist(TokenChars, 3, length(TokenChars) - 3))}}.

%% `0xCE` is an integer, accepted everywhere and not only inside a binary
%% segment; marker and digits are case-insensitive. Longest-match puts it
%% ahead of `{D}+` with no ordering dependency (F13).
0[xX]{H}+               : {token, {integer, TokenLine,
                                   list_to_integer(lists:nthtail(2, TokenChars), 16)}}.
{D}+                    : {token, {integer, TokenLine, list_to_integer(TokenChars)}}.

_                       : {token, {'_', TokenLine}}.

%% PascalCase: a user type or a function name.
{UPPER}{ALNUM}*         : {token, {uident, TokenLine, list_to_atom(TokenChars)}}.

%% lowercase: a variable, a parameter, or a builtin type (`int`, `atom`).
{LOWER}{ALNUM}*         : {token, {lident, TokenLine, list_to_atom(TokenChars)}}.

%% `.` joins module path segments, calls into a foreign module (`:ets.lookup`)
%% and projects a record field. `..` wins by longest-match, so the two never
%% collide whatever the rule order.
\.                      : {token, {'.', TokenLine}}.

%% `..` is the rest marker in `[h, ..t]`, in pattern and construction position
%% alike (ticket 28).
\.\.                    : {token, {'..', TokenLine}}.
->                      : {token, {'->', TokenLine}}.
%% `->` opens a clause body and `=>` a switch arm. Longest-match keeps `=>` off
%% the `=` rule below whatever the rule order (F7).
=>                      : {token, {'=>', TokenLine}}.
==                      : {token, {'==', TokenLine}}.
!=                      : {token, {'!=', TokenLine}}.
<=                      : {token, {'<=', TokenLine}}.
>=                      : {token, {'>=', TokenLine}}.

%% `<<` opens a binary pattern, and there is no `>>` token: `list<list<int>>`
%% must lex its close as two `>` tokens, so the parser closes a binary on two
%% `'>'` tokens too. `<<` is safe because no other form puts two `<` adjacent;
%% a generic's bracket always follows a name (F13).
<<                      : {token, {'<<', TokenLine}}.
<                       : {token, {'<', TokenLine}}.
>                       : {token, {'>', TokenLine}}.
\+                      : {token, {'+', TokenLine}}.
-                       : {token, {'-', TokenLine}}.
\*                      : {token, {'*', TokenLine}}.
%% `/` is truncating integer division and lowers to Erlang's `div`, never its
%% float `/`; `%` is the remainder, signed by the dividend (F26, ticket 38).
%% `%` is escaped because leex reads a bare one as a comment and silently
%% drops the rule.
/                       : {token, {'/', TokenLine}}.
\%                      : {token, {'%', TokenLine}}.
=                       : {token, {'=', TokenLine}}.
%% `:` separates a field from its type in a declaration and from its pattern
%% in a record pattern; `=` assigns in construction (ticket 26 §2).
%% Longest-match gives `:placed` to the atom rule, so `Id:int` lexes `:int` as
%% an atom; the parser refuses that shape by name.
:                       : {token, {':', TokenLine}}.
%% `?` is not a language construct: there are no optional fields. It is lexed
%% so the parser can refuse `Notes?: int` by name (ticket 26 §4).
\?                      : {token, {'?', TokenLine}}.
%% `|>` is the pipe, `|?>` the valve, and `|` joins union members. Longest-match
%% keeps the three apart with no lexer state (ticket 17 §1 and §4).
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
                    %% Invalid UTF-8 is refused, not replaced with U+FFFD as
                    %% C# and TypeScript do: a silent replacement would
                    %% manufacture the invalid string this check exists to
                    %% prevent (ticket 29 §4, ticket 20 §4).
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

%% A decode attempt over the raw bytes; `unicode:characters_to_binary/2`
%% returns an error tuple rather than replacing, which is what is needed here.
utf8_ok(Bytes) ->
    case unicode:characters_to_binary(list_to_binary(Bytes), utf8, utf8) of
        B when is_binary(B) -> true;
        _                   -> false
    end.
