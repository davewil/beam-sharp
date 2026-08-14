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

%% :atom — ticket 10 settled the sigil, and the universe is open, so nothing
%% declares an atom and the lexer simply interns what it sees.
:{LOWER}{ALNUM}*        : {token, {atom_lit, TokenLine, list_to_atom(tl(TokenChars))}}.
:true                   : {token, {atom_lit, TokenLine, true}}.
:false                  : {token, {atom_lit, TokenLine, false}}.

{D}+                    : {token, {integer, TokenLine, list_to_integer(TokenChars)}}.

_                       : {token, {'_', TokenLine}}.

%% PascalCase: a user type or a function name.
{UPPER}{ALNUM}*         : {token, {uident, TokenLine, list_to_atom(TokenChars)}}.

%% lowercase: a variable, a parameter, or a builtin type (`int`, `atom`, `term`).
{LOWER}{ALNUM}*         : {token, {lident, TokenLine, list_to_atom(TokenChars)}}.

%% Two-character operators before their one-character prefixes.
%% `..` is the rest marker in `[h, ..t]` — ticket 28 adopted the C# collection
%% expression spelling in both pattern and construction position.
\.\.                    : {token, {'..', TokenLine}}.
->                      : {token, {'->', TokenLine}}.
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
\|                      : {token, {'|', TokenLine}}.
,                       : {token, {',', TokenLine}}.
\(                      : {token, {'(', TokenLine}}.
\)                      : {token, {')', TokenLine}}.
\[                      : {token, {'[', TokenLine}}.
\]                      : {token, {']', TokenLine}}.

Erlang code.
