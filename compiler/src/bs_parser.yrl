%%% beam-sharp parser — the walking-skeleton slice.
%%%
%%% Variant A, settled by ticket 01: a signature, then equations under it, with
%%% the function name repeated on each clause. The one structural move the whole
%%% language rests on is that the clause head's patterns sit in the *parameter*
%%% position, and N declarations are allowed where C# allows one.

Nonterminals
  program decls decl
  module_decl type_decl signature clause foreign_decl foreign_sigs foreign_sig
  behaviour_decl record_decl field_decls field_decl
  type_expr type_union_members type_prim type_list type_params
  params param_list param
  patterns pattern_list pattern plist_items pat_fields pat_field
  rel_pattern rel_test int_lit refinement
  guard guard_expr
  body binding
  expr expr_list elist_items assign_fields assign_field
  switch_arms switch_arm
  .

Terminals
  'module' 'type' 'when' 'using' 'behaviour' 'record' 'with' 'switch' 'var'
  'and' 'or' 'where'
  uident lident atom_lit integer string_lit '_'
  '->' '=>' '==' '!=' '<=' '>=' '<' '>' '+' '-' '*'
  '=' '|' ',' '(' ')' '[' ']' '{' '}' '..' '.' ':' '?'
  .

Rootsymbol program.

%% Guards and expressions share an operator table. Ticket 08 settled the
%% conjunction over Erlang's `,`/`;`, on the grounds that a guard over typed
%% values cannot fail — so there is nothing for fail-to-false to do. Ticket 44
%% then amended the SPELLING to `and`/`or`, leaving the mechanism untouched: the
%% lifting that makes `(d as int) > 0` yield false is on the comparison, so the
%% operator joining it to anything else was never part of that argument.
%% `=` is not an expression operator — a binding is a body form (ticket 34) —
%% but it needs a precedence so that `x = 1 + 2` shifts the operator instead of
%% reducing the binding. Lowest, so everything binds tighter than the bind.
Nonassoc  50 '='.
Left  100 'or'.
Left  200 'and'.
Nonassoc 300 '==' '!=' '<' '>' '<=' '>='.
Left  400 '+' '-'.
Left  500 '*'.
%% `with` binds tighter than any operator: `o with { Total = 1 } == x` reads as
%% a comparison of the updated record, which is the only sensible parse.
Nonassoc 600 'with'.
%% Tighter still, which is C#'s own reading: a switch expression's subject is a
%% *range expression*, so `a + b switch { … }` is `a + (b switch { … })` there
%% and here. Nonassoc because `x switch { … } switch { … }` has no reading worth
%% having — the brace block already makes the subject unambiguous, so a chain
%% would be legible only to a parser.
Nonassoc 700 'switch'.

program -> decls : '$1'.

decls -> decl       : ['$1'].
decls -> decl decls : ['$1' | '$2'].

decl -> module_decl : '$1'.
decl -> type_decl   : '$1'.
decl -> signature   : '$1'.
decl -> clause      : '$1'.
decl -> foreign_decl : '$1'.
decl -> behaviour_decl : '$1'.
decl -> record_decl : '$1'.

%% --- records ----------------------------------------------------------------
%% Ticket 26 §1. A record erases to a MAP carrying a tag minted from its
%% qualified type name; everything stays structural, so the tag is an ordinary
%% field and a hand-written `type` with the same tag is the same type.
%%
%% The spelling is §1's own provisional `record`; whether it stays a keyword or
%% becomes a modifier on `type` is ticket 22's, and nothing below depends on it.
record_decl -> 'record' uident '{' field_decls '}' :
    {record_decl, line('$1'), value('$2'), '$4'}.

field_decls -> field_decl                 : ['$1'].
field_decls -> field_decl ',' field_decls : ['$1' | '$3'].

field_decl -> uident ':' type_expr : {field, value('$1'), '$3'}.

%% Ticket 26 §4: there are no absent fields. The kept form is
%% `Notes: option<int>`, which F6 landed — so the diagnostic can now name the
%% spelling to write instead of only saying what the language does not have.
field_decl -> uident '?' ':' type_expr :
    return_error(line('$2'),
                 "no optional fields: a record's field set is exact, so '" ++
                 atom_to_list(value('$1')) ++ "?' is not a thing it can have -- "
                 "write `" ++ atom_to_list(value('$1')) ++ ": option<T>`").

%% `Id:int` lexes `:int` as an atom, because longest-match prefers the sigil.
%% Catching the shape here turns what would be an opaque syntax error into the
%% one-character fix.
field_decl -> uident atom_lit :
    return_error(line('$2'),
                 "write 'Id: int' with a space -- ':" ++
                 atom_to_list(value('$2')) ++ "' lexes as an atom literal").

%% --- behaviours -------------------------------------------------------------
%% `behaviour GenServer` — the platform's own word, and literally what is
%% emitted. Not `using GenServer`, which is the same three tokens as a
%% single-segment import and would need a symbol table to disambiguate; not
%% `use`, which in Elixir is a macro that injects default callback bodies B#
%% will never generate; not `implements` or `instance`, each of which carries
%% baggage from a paradigm this construct does not belong to.
behaviour_decl -> 'behaviour' uident : {behaviour, line('$1'), value('$2')}.

%% --- foreign modules --------------------------------------------------------
%% On the BEAM a module IS an atom, so the module is written as one and the
%% call site is Elixir's: `:ets.lookup(t, k)`. Nothing is renamed — the
%% declaration attaches types to the name Erlang already has, which is why no
%% snake_case/PascalCase mapping exists anywhere in the language.
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4'}.

foreign_sigs -> foreign_sig              : ['$1'].
foreign_sigs -> foreign_sig foreign_sigs : ['$1' | '$2'].

foreign_sig -> type_prim lident '(' params ')' :
    {foreign_sig, line('$2'), value('$2'), '$1', '$4'}.

%% --- module -----------------------------------------------------------------
module_decl -> 'module' uident : {module, line('$1'), value('$2')}.

%% --- type aliases -----------------------------------------------------------
%% Ticket 09: `type X = ...` is the single naming construct, the name never
%% enters the algebra, and there is no `union` keyword to design.
type_decl -> 'type' uident '=' type_expr :
    {type_alias, line('$1'), value('$2'), [], '$4'}.

%% A REFINED type — ticket 20 §5, `type Octet = int where value >= 0 and value <= 255`.
%%
%% Not a second declaration construct: it is the alias above with a predicate on
%% it, which is what keeps 20 §5's two tiers apart by what the predicate SAYS
%% rather than by how it is spelled. A guard-decidable predicate is reasoned
%% about and lands in the algebra as an interval; anything else is refused by the
%% checker, since 20 §5 as amended by 29 bars the opaque tier from clause heads
%% and this surface has no other check site to put it at.
%%
%% `value` is an ordinary lowercase identifier, deliberately — the refinement
%% translator gives it meaning and the lexer does not, so a parameter named
%% `value` stays legal and the word means the subject only inside a `where`.
type_decl -> 'type' uident '=' type_expr 'where' refinement :
    {type_refined, line('$1'), value('$2'), '$4', '$6'}.

%% The predicate is an ordinary expression, so it inherits the whole comparison
%% and conjunction grammar rather than getting a second one — and the checker
%% then reads it back with the SAME `alternatives/1` a guard goes through. One
%% translator, so a refinement and a guard cannot come to disagree about what
%% `value >= 0` means (F2.5).
refinement -> expr : '$1'.

%% A PARAMETRIC alias — ticket 27 §(b). The variable is bound here, substituted
%% at the use, and gone before `bs_types` sees anything: `Pair<int>` resolves to
%% the tuple, never to a node the algebra has to know about.
%%
%% A parameter is lexed as `uident`, exactly like a user type name (ticket 27 §4
%% forced declaration for that reason — builtins are lowercase, so a lowercase
%% implicit convention could not tell `a` from a builtin you have not met). So
%% nothing but this list distinguishes the two, which is what F6.7 asserts.
type_decl -> 'type' uident '<' type_params '>' '=' type_expr :
    {type_alias, line('$1'), value('$2'), '$4', '$7'}.

type_params -> uident                 : [value('$1')].
type_params -> uident ',' type_params : [value('$1') | '$3'].

type_expr -> type_union_members :
    case '$1' of [One] -> One; Many -> {t_union, Many} end.

type_union_members -> type_prim                          : ['$1'].
type_union_members -> type_prim '|' type_union_members   : ['$1' | '$3'].

type_prim -> atom_lit          : {t_atom, value('$1')}.
type_prim -> lident            : {t_builtin, value('$1')}.
type_prim -> uident            : {t_ref, value('$1')}.
type_prim -> '(' type_list ')' : {t_tuple, '$2'}.

%% The anonymous map type. Ticket 09's naming rule means this is not a second
%% construct beside `record` — it is what a record IS, and F3.2 turns that into
%% a test: `type Spelled = { Kind: :'Shop.Order', Id: int }` must be the same
%% type as the record whose tag mints to the same atom.
type_prim -> '{' field_decls '}' : {t_map, '$2'}.

%% `list<int>`, `result<Delivery, ConsumeError>`, `Pair<int>`. Ticket 28's
%% disambiguation rule is about VALUE position, where a `<` could be a
%% comparison; in type position nothing compares, so the bracket is unambiguous
%% and costs no lookahead. F6.9 asserts the value side did not learn it.
%%
%% Lowercase is the prelude namespace (`list`, `option`, `result`) and PascalCase
%% is a user alias; both are the same node, because after resolution neither name
%% exists. Arity is checked where the parameters are known, not here — a bracket
%% with the wrong number of arguments is a diagnostic (F6.6), and the parser has
%% no way to know the right number.
type_prim -> lident '<' type_list '>' : {t_generic, value('$1'), '$3'}.
type_prim -> uident '<' type_list '>' : {t_generic, value('$1'), '$3'}.

type_list -> type_expr               : ['$1'].
type_list -> type_expr ',' type_list : ['$1' | '$3'].

%% --- signatures -------------------------------------------------------------
%% Ticket 04's binding constraint: exhaustiveness is only well posed against a
%% *declared* input type, so a multi-clause function must carry a signature.
signature -> type_prim uident '(' params ')' :
    {signature, line('$2'), value('$2'), '$1', '$4'}.

params -> '$empty'    : [].
params -> param_list  : '$1'.

param_list -> param                : ['$1'].
param_list -> param ',' param_list : ['$1' | '$3'].

%% A parameter may be named or anonymous: `Order o` or just `Order`.
param -> type_prim lident : {param, '$1', value('$2')}.
param -> type_prim        : {param, '$1', '_'}.

%% --- clauses ----------------------------------------------------------------
clause -> uident '(' patterns ')' guard '->' body :
    {clause, line('$1'), value('$1'), '$3', '$5', '$7'}.

%% A body is zero or more bindings followed by one expression. Ticket 34: a name
%% may be bound in a body, and the value is the last expression — so a body is
%% still an expression, with names in front of it, rather than a statement list
%% that happens to end in a value.
%%
%% No terminator is needed and none is introduced: a binding is the only thing
%% that can put `=` after a lowercase name, and `=` is not an expression
%% operator (equality is `==`), so one token of lookahead separates `x = 1` from
%% a body whose value is the variable `x`.
body -> expr : '$1'.
body -> binding body :
    case '$2' of
        {e_block, BL, Binds, Final} -> {e_block, BL, ['$1' | Binds], Final};
        Final -> {e_block, element(2, '$1'), ['$1'], Final}
    end.

%% F8 — `var` INTRODUCES, and a bare `=` MATCHES.
%%
%% The marker is what lets this rule take a `pattern` directly. Without it,
%% `binding -> pattern '=' expr` reports reduce/reduce conflicts and yecc refuses
%% to generate: it has one token of lookahead and every pattern form shares its
%% first token with an expression form, so after `(` the parser cannot tell
%% `(a, b) = pair` from the tuple `(a, b)`. After `var` it can, because nothing
%% else may follow that word.
%%
%% MEASURED, and the recorded number had gone stale. The comment here read
%% "TWELVE reduce/reduce"; it is **15** on 2026-08-16 (`45a`'s control reproduces
%% it). The count is not a constant — it grows as pattern and expression forms
%% are added, so F6, F7 and F9 each moved it. A measurement with a date is the
%% honest form; a bare number in a comment reads as a fact and rots.
%%
%% AND THE MARKER PAYS TWICE. It deletes the narrowing for the introducing form,
%% and it makes MAP DESTRUCTURING reachable: `var { Kind: k } = o` parses, where
%% `{ Kind: k } = o` could not, because a record pattern is not an expression and
%% so never reached the old narrowing at all. F5 recorded that as out of scope;
%% it arrives here as a side effect rather than as work.
binding -> 'var' pattern '=' expr : bind(line('$3'), '$2', '$4').

%% The bare form survives for MATCHES only. Its left is still an expression,
%% narrowed by `to_match/1`, which now rejects anything that would introduce.
binding -> expr '=' expr : {dbind, line('$2'), to_match('$1'), '$3'}.

patterns -> '$empty'     : [].
patterns -> pattern_list : '$1'.

pattern_list -> pattern                  : ['$1'].
pattern_list -> pattern ',' pattern_list : ['$1' | '$3'].

pattern -> integer             : {p_int, line('$1'), value('$1')}.

%% A pattern takes a negative LITERAL and not a general negation, because a
%% pattern is a value and `-x` is a computation. The interval algebra needs
%% nothing new: `range(-1, -1)` is what `p_int` already produces.
pattern -> '-' integer         : {p_int, line('$1'), -value('$2')}.
pattern -> atom_lit            : {p_atom, line('$1'), value('$1')}.
pattern -> lident              : {p_var, line('$1'), value('$1')}.
pattern -> '_'                 : {p_wild, line('$1')}.

%% Ticket 45 — a match against the value a name ALREADY HOLDS. One rule, and no
%% new lexer token: `==` has lexed since the walking skeleton, and ticket 16 fixed
%% its meaning as `=:=`, so the glyph carries into pattern position with exactly
%% the meaning it has everywhere else.
%%
%% It reads as the equality member of ticket 42's relational family (`>= 4`), and
%% the family divides on the operand: relational operators take a LITERAL, `==`
%% takes a NAME. So `>= acc` (a bound set at run time) and `== 4` (a second
%% spelling for the literal pattern `4`) are both refused — measured clean if ever
%% added deliberately, and deliberately not added.
%%
%% The space is not significant. `==acc` and `== acc` are one token stream,
%% because `==` is maximal-munch and an identifier cannot begin with it.
pattern -> '==' lident         : {p_eqvar, line('$1'), value('$2')}.
%% A RELATIONAL PATTERN — ticket 42. `Classify(>= 4 and <= 7)` names a span of
%% integers where a whole argument goes.
%%
%% `4..7` was refused and the refusal is the interesting half: C#'s `..` builds a
%% half-open slice specification over *indices*, is not enumerable, and in
%% pattern position already means "the rest" — which this language took in 28 §5
%% and runs today as `Reverse([x, ..rest], acc)`. So the range spelling was never
%% the tier-1 borrow it looked like. The rule that came out of it governs future
%% borrowings: BORROW THE CONSTRUCT, OR DON'T BORROW THE GLYPH.
%%
%% The combinator is restricted to relational tests rather than to patterns
%% generally, and that is a grammar fact as much as a scope call: `pattern 'and'
%% pattern` would put `and` after every pattern form, including the bare `lident`
%% that a switch arm starts with, and `and` is also an expression operator. The
%% narrow nonterminal keeps the two apart with no lookahead — measured, yecc
%% reports zero conflicts for it. C#'s `and` combines arbitrary patterns; this one
%% does not yet, and no exemplar asks it to.
%%
%% `==` is deliberately NOT a member. Ticket 45 gave it the pattern meaning "the
%% value this NAME holds", and the family divides on the operand: a relational
%% takes a literal, `==` takes a name. `== 4` and `>= acc` are both refused.
pattern -> rel_pattern : '$1'.

rel_pattern -> rel_test : '$1'.
rel_pattern -> rel_pattern 'and' rel_pattern :
    {p_and, line('$2'), '$1', '$3'}.
rel_pattern -> rel_pattern 'or' rel_pattern :
    {p_or, line('$2'), '$1', '$3'}.

rel_test -> '>=' int_lit : {p_rel, line('$1'), '>=', '$2'}.
rel_test -> '>'  int_lit : {p_rel, line('$1'), '>',  '$2'}.
rel_test -> '<=' int_lit : {p_rel, line('$1'), '<=', '$2'}.
rel_test -> '<'  int_lit : {p_rel, line('$1'), '<',  '$2'}.

%% The bound is a LITERAL, and negative bounds are the case that makes this its
%% own nonterminal: `Classify(<= -1)` is the residual's own spelling for the
%% negative half of `int`, so the diagnostic 23 §2 synthesises has to be
%% something the parser accepts back.
int_lit -> integer     : value('$1').
int_lit -> '-' integer : -value('$2').

pattern -> '(' pattern_list ')' :
    case '$2' of
        [Single] -> Single;
        Many     -> {p_tuple, line('$1'), Many}
    end.

%% Lists. Ticket 08 settled prefix-plus-rest only, and ticket 28 adopted C#'s
%% collection-expression spelling: `[]`, `[a, b]`, `[h, ..t]`.
%%
%% The rest marker lives INSIDE the items nonterminal rather than as a separate
%% `pattern_list ',' '..' pattern` rule, because the latter needs two tokens of
%% lookahead past the comma and yecc has one.
%% The property pattern, which ticket 01 already had working in the parameter
%% position. The tag is an ordinary field, so dispatching over a union of records
%% needs no record-specific pattern form — `{ Kind: :'Shop.Order' }` is it.
%%
%% A record pattern is OPEN: it constrains the fields it names and says nothing
%% about the rest. That is what lets one clause cover a whole record by naming
%% only its tag, and it is why the algebra carries `closed`/`open` at all.
pattern -> '{' pat_fields '}' : {p_map, line('$1'), '$2'}.

pat_fields -> pat_field                : ['$1'].
pat_fields -> pat_field ',' pat_fields : ['$1' | '$3'].

pat_field -> uident ':' pattern : {value('$1'), '$3'}.

pattern -> '[' ']'          : {p_nil, line('$1')}.
pattern -> '[' plist_items ']' :
    begin {Items, Rest} = '$2', {p_list, line('$1'), Items, Rest} end.

plist_items -> pattern                 : {['$1'], nil}.
plist_items -> '..' pattern            : {[], '$2'}.
plist_items -> pattern ',' plist_items :
    begin {Items, Rest} = '$3', {['$1' | Items], Rest} end.

guard -> '$empty'            : none.
guard -> 'when' guard_expr   : {guard, '$2'}.

guard_expr -> expr : '$1'.

%% --- expressions ------------------------------------------------------------
expr -> integer  : {e_int, line('$1'), value('$1')}.

%% NEGATION. Absent until 2026-08-15, and absent by oversight rather than
%% decision — a grep for "unary" across `LANGUAGE.md`, every ticket, the fog and
%% every feature file returns nothing. C# has it and Erlang has it, so both tiers
%% agree and there was nothing to decide.
%%
%% Found by running AoC 2025 Day 1, where a direction had to be written
%% `0 - 1` because `-1` did not lex as anything. Negative numbers arrived fine as
%% DATA the whole time — `bs_run`'s reader has always handled `-68` — so the gap
%% was only ever in source.
%%
%% Lowered to `0 - e` rather than given its own node, so nothing downstream of
%% the parser learns a new shape: the checker's `op_type('-')` and the emitter's
%% `erl_op('-')` both already answer.
expr -> '-' expr : {e_op, line('$1'), '-', {e_int, line('$1'), 0}, '$2'}.
expr -> atom_lit : {e_atom, line('$1'), value('$1')}.
%% Expression position only. A string literal in PATTERN position would need a
%% value-level singleton in the binary part of the algebra, and ticket 20's
%% grammar is `<<_:M, _:_*N>>` — sizes, not values, so it cannot say "this one".
%% That is ticket 30 §2's open question (a union discriminated by a value inside
%% the binary) at the smallest possible scale. Admitting the pattern without it
%% would mean admitting a match the checker cannot prove exhaustive.
expr -> string_lit : {e_str, line('$1'), value('$1')}.
expr -> lident   : {e_var, line('$1'), value('$1')}.
%% `_` is an expression ONLY so that `(a, _) = pair` parses — the left of a bind
%% is an expression (see `binding` above). Used as a value it is rejected by
%% `bs_check`, not by `erlc` against an emitted file the author never wrote.
expr -> '_'      : {e_wild, line('$1')}.

%% A local call. The slice has no qualified names, so ticket 17's `|>` and the
%% module-qualified form are both out of scope here.
expr -> uident '(' expr_list ')' : {e_call, line('$1'), value('$1'), '$3'}.

%% `:ets.lookup(t, k)` — an atom literal on the left, so no variable and no
%% casing convention is involved in telling this from a field projection.
expr -> atom_lit '.' lident '(' expr_list ')' :
    {e_foreign_call, line('$1'), value('$1'), value('$3'), '$5'}.
expr -> atom_lit '.' lident '(' ')' :
    {e_foreign_call, line('$1'), value('$1'), value('$3'), []}.
expr -> uident '(' ')'           : {e_call, line('$1'), value('$1'), []}.

expr -> '(' expr_list ')' :
    case '$2' of
        [Single] -> Single;
        Many     -> {e_tuple, line('$1'), Many}
    end.

%% --- records in expression position -----------------------------------------
%% Construction names the type. Ticket 26 §2's separator split: `=` assigns here,
%% `:` matches in a pattern and declares in the type.
expr -> uident '{' assign_fields '}' :
    {e_record, line('$1'), value('$1'), '$3'}.

assign_fields -> assign_field                   : ['$1'].
assign_fields -> assign_field ',' assign_fields : ['$1' | '$3'].

assign_field -> uident '=' expr : {value('$1'), '$3'}.

%% Ticket 26 §2: width-preserving update. Not spread — §2 refused it, because a
%% widened record would carry a minted tag while not being that record, and no
%% signature could be written against it without the row variable ticket 27
%% declined. `{ ...o, X = 1 }` has no production and is a syntax error.
expr -> expr 'with' '{' assign_fields '}' :
    {e_with, line('$2'), '$1', '$4'}.

%% The dot PROJECTS and is never a call — ticket 17 narrowed it to exactly this.
%% The disambiguation is lexical and happens before types exist: a lowercase
%% receiver is a value, a PascalCase one is a module. So a record field `Total`
%% and a function `Total` coexist, told apart by syntax rather than resolution.
expr -> lident '.' uident : {e_proj, line('$2'), value('$1'), value('$3')}.

%% --- switch -----------------------------------------------------------------
%% Ticket 17 §6. The one structural move, run backwards: ticket 01 moved C#'s
%% pattern grammar OUT of switch arms and into the parameter position, and this
%% puts the same grammar back into expression position. So `pattern` below is
%% the clause head's own nonterminal, not a copy of it, and the construct
%% inherits exhaustiveness, guards and the residual with nothing added.
%%
%% An arm's body is a single `expr` rather than a `body`. That is a grammar
%% fact, not a view about bodies: arms are comma-separated and a body is
%% bindings-then-expression with no terminator, so `p => x = 1, x + 2` cannot be
%% told from two arms with the one token of lookahead yecc has.
expr -> expr 'switch' '{' switch_arms '}' :
    {e_switch, line('$2'), '$1', '$4'}.

switch_arms -> switch_arm                 : ['$1'].
switch_arms -> switch_arm ',' switch_arms : ['$1' | '$3'].

%% The arm carries the `=>`'s line, because that token is present in every arm
%% while a pattern's own line may belong to a token the reader is not looking at.
switch_arm -> pattern guard '=>' expr :
    {arm, line('$3'), '$1', '$2', '$4'}.

expr -> '[' ']'          : {e_nil, line('$1')}.
expr -> '[' elist_items ']' :
    begin {Items, Rest} = '$2', {e_list, line('$1'), Items, Rest} end.

elist_items -> expr                 : {['$1'], nil}.
elist_items -> '..' expr            : {[], '$2'}.
elist_items -> expr ',' elist_items :
    begin {Items, Rest} = '$3', {['$1' | Items], Rest} end.

expr -> expr '+'  expr : {e_op, line('$2'), '+',  '$1', '$3'}.
expr -> expr '-'  expr : {e_op, line('$2'), '-',  '$1', '$3'}.
expr -> expr '*'  expr : {e_op, line('$2'), '*',  '$1', '$3'}.
expr -> expr '==' expr : {e_op, line('$2'), '==', '$1', '$3'}.
expr -> expr '!=' expr : {e_op, line('$2'), '!=', '$1', '$3'}.
expr -> expr '<'  expr : {e_op, line('$2'), '<',  '$1', '$3'}.
expr -> expr '>'  expr : {e_op, line('$2'), '>',  '$1', '$3'}.
expr -> expr '<=' expr : {e_op, line('$2'), '<=', '$1', '$3'}.
expr -> expr '>=' expr : {e_op, line('$2'), '>=', '$1', '$3'}.
expr -> expr 'and' expr : {e_op, line('$2'), 'and', '$1', '$3'}.
expr -> expr 'or'  expr : {e_op, line('$2'), 'or',  '$1', '$3'}.

expr_list -> expr               : ['$1'].
expr_list -> expr ',' expr_list : ['$1' | '$3'].

Erlang code.

line(T) -> element(2, T).
value(T) -> element(3, T).

%% A plain name keeps ticket 34's node; anything else is a destructuring bind
%% carrying a real pattern, which ticket 34 deferred to ticket 33 and F5 built.
%% Downstream learns no new shape: `var` changed how the LEFT is read, not what
%% a binding IS.
bind(_L, {p_var, VL, V}, E) -> {bind, VL, V, E};
bind(L, Pat, E)             -> {dbind, L, Pat, E}.

%% THE BARE `=` IS A MATCH, so its left side must introduce nothing.
%%
%% `var` took the introducing form off this path entirely — that rule reads a
%% `pattern` directly — so what remains here is the narrowing for a MATCH, over a
%% much smaller language: literals and compounds of literals. The error is the
%% whole point of the function now rather than a fallback at the bottom of it.
%%
%% Why the bare form still narrows at all: it is still `expr '=' expr`, because
%% one token of lookahead cannot tell `(1, 2) = pair` from the tuple `(1, 2)`.
%% Only the marked form escapes that, which is exactly why the marker pays.
to_match({e_wild, L})     -> {p_wild, L};
to_match({e_int, L, N})   -> {p_int, L, N};
to_match({e_atom, L, A})  -> {p_atom, L, A};
%% No `e_str` clause, deliberately. A string literal has no PATTERN form — the
%% algebra's binary grammar is `<<_:M, _:_*N>>`, sizes rather than values, so it
%% cannot say "this one" (ticket 30 §2). It falls to the error below.
to_match({e_tuple, L, Es})-> {p_tuple, L, [to_match(E) || E <- Es]};
to_match({e_nil, L})      -> {p_nil, L};
to_match({e_list, L, Items, Rest}) ->
    {p_list, L, [to_match(I) || I <- Items],
     case Rest of nil -> nil; R -> to_match(R) end};
%% F8.3 — the message names the fix, which is F4.7's rule. This is the single
%% most common thing a reader coming from the old dialect will type.
to_match({e_var, L, V}) ->
    return_error(L, lists:flatten(
        io_lib:format("~ts is introduced here, and a bare `=` matches rather "
                      "than introduces -- write `var ~ts = ...`", [V, V])));
to_match(E) ->
    return_error(element(2, E),
                 "the left of a bare `=` must be a literal pattern. To introduce "
                 "a name, write `var <pattern> = ...`").
