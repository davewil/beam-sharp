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
