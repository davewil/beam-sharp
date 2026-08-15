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
  guard guard_expr
  body binding
  expr expr_list elist_items assign_fields assign_field
  switch_arms switch_arm
  .

Terminals
  'module' 'type' 'when' 'using' 'behaviour' 'record' 'with' 'switch'
  uident lident atom_lit integer '_'
  '->' '=>' '&&' '||' '==' '!=' '<=' '>=' '<' '>' '+' '-' '*'
  '=' '|' ',' '(' ')' '[' ']' '{' '}' '..' '.' ':' '?'
  .

Rootsymbol program.

%% Guards and expressions share an operator table. Ticket 08 settled `&&`/`||`
%% over Erlang's `,`/`;`, on the grounds that a guard over typed values cannot
%% fail — so there is nothing for fail-to-false to do.
%% `=` is not an expression operator — a binding is a body form (ticket 34) —
%% but it needs a precedence so that `x = 1 + 2` shifts the operator instead of
%% reducing the binding. Lowest, so everything binds tighter than the bind.
Nonassoc  50 '='.
Left  100 '||'.
Left  200 '&&'.
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

%% The left of `=` is parsed as an EXPRESSION and narrowed to a pattern in the
%% action. `binding -> pattern '=' expr` is the obvious rule and it reports
%% TWELVE reduce/reduce conflicts — measured, not feared: yecc has one token of
%% lookahead and every pattern form shares its first token with an expression
%% form, so after `(` the parser cannot tell `(a, b) = pair` from the tuple
%% `(a, b)`. Parsing the wider language and narrowing afterwards is the standard
%% escape, and it is what Erlang itself does, where `=` IS an expression.
%%
%% `x = e` still produces the `{bind, …}` node ticket 34 shipped, so nothing
%% downstream of the parser learns a new shape for the case that already worked.
binding -> expr '=' expr : bind(line('$2'), '$1', '$3').

patterns -> '$empty'     : [].
patterns -> pattern_list : '$1'.

pattern_list -> pattern                  : ['$1'].
pattern_list -> pattern ',' pattern_list : ['$1' | '$3'].

pattern -> integer             : {p_int, line('$1'), value('$1')}.
pattern -> atom_lit            : {p_atom, line('$1'), value('$1')}.
pattern -> lident              : {p_var, line('$1'), value('$1')}.
pattern -> '_'                 : {p_wild, line('$1')}.
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
expr -> atom_lit : {e_atom, line('$1'), value('$1')}.
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
expr -> expr '&&' expr : {e_op, line('$2'), '&&', '$1', '$3'}.
expr -> expr '||' expr : {e_op, line('$2'), '||', '$1', '$3'}.

expr_list -> expr               : ['$1'].
expr_list -> expr ',' expr_list : ['$1' | '$3'].

Erlang code.

line(T) -> element(2, T).
value(T) -> element(3, T).

%% A plain name keeps ticket 34's node; anything else is a destructuring bind
%% carrying a real pattern, which ticket 34 deferred to ticket 33 and F5 built.
bind(_L, {e_var, VL, V}, E) -> {bind, VL, V, E};
bind(L, Lhs, E)             -> {dbind, L, to_pattern(Lhs), E}.

%% Only the forms that are a pattern AND an expression can appear here. A bare
%% `{ Kind: :x }` is not an expression, so map destructuring does not reach this
%% function — recorded in F5's out-of-scope rather than half-supported.
to_pattern({e_var, L, V})   -> {p_var, L, V};
to_pattern({e_wild, L})     -> {p_wild, L};
to_pattern({e_int, L, N})   -> {p_int, L, N};
to_pattern({e_atom, L, A})  -> {p_atom, L, A};
to_pattern({e_tuple, L, Es})-> {p_tuple, L, [to_pattern(E) || E <- Es]};
to_pattern({e_nil, L})      -> {p_nil, L};
to_pattern({e_list, L, Items, Rest}) ->
    {p_list, L, [to_pattern(I) || I <- Items],
     case Rest of nil -> nil; R -> to_pattern(R) end};
to_pattern(E) ->
    return_error(element(2, E),
                 "the left of `=` must be a name or a pattern").
