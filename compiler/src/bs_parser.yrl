%%% beam-sharp parser — the walking-skeleton slice.
%%%
%%% Variant A, settled by ticket 01: a signature, then equations under it, with
%%% the function name repeated on each clause. The one structural move the whole
%%% language rests on is that the clause head's patterns sit in the *parameter*
%%% position, and N declarations are allowed where C# allows one.

Nonterminals
  program decls decl
  module_decl type_decl signature clause
  type_expr type_union_members type_prim type_list
  params param_list param
  patterns pattern_list pattern plist_items
  guard guard_expr
  expr expr_list elist_items
  .

Terminals
  'module' 'type' 'when'
  uident lident atom_lit integer '_'
  '->' '&&' '||' '==' '!=' '<=' '>=' '<' '>' '+' '-' '*'
  '=' '|' ';' ',' '(' ')' '[' ']' '..'
  .

Rootsymbol program.

%% Guards and expressions share an operator table. Ticket 08 settled `&&`/`||`
%% over Erlang's `,`/`;`, on the grounds that a guard over typed values cannot
%% fail — so there is nothing for fail-to-false to do.
Left  100 '||'.
Left  200 '&&'.
Nonassoc 300 '==' '!=' '<' '>' '<=' '>='.
Left  400 '+' '-'.
Left  500 '*'.

program -> decls : '$1'.

decls -> decl       : ['$1'].
decls -> decl decls : ['$1' | '$2'].

decl -> module_decl : '$1'.
decl -> type_decl   : '$1'.
decl -> signature   : '$1'.
decl -> clause      : '$1'.

%% --- module -----------------------------------------------------------------
module_decl -> 'module' uident ';' : {module, line('$1'), value('$2')}.

%% --- type aliases -----------------------------------------------------------
%% Ticket 09: `type X = ...` is the single naming construct, the name never
%% enters the algebra, and there is no `union` keyword to design.
type_decl -> 'type' uident '=' type_expr ';' :
    {type_alias, line('$1'), value('$2'), '$4'}.

type_expr -> type_union_members :
    case '$1' of [One] -> One; Many -> {t_union, Many} end.

type_union_members -> type_prim                          : ['$1'].
type_union_members -> type_prim '|' type_union_members   : ['$1' | '$3'].

type_prim -> atom_lit          : {t_atom, value('$1')}.
type_prim -> lident            : {t_builtin, value('$1')}.
type_prim -> uident            : {t_ref, value('$1')}.
type_prim -> '(' type_list ')' : {t_tuple, '$2'}.

%% `list<int>`. Ticket 28's disambiguation rule is about VALUE position, where a
%% `<` could be a comparison; in type position nothing compares, so the bracket
%% is unambiguous and costs no lookahead.
type_prim -> lident '<' type_expr '>' : {t_generic, value('$1'), '$3'}.

type_list -> type_expr               : ['$1'].
type_list -> type_expr ',' type_list : ['$1' | '$3'].

%% --- signatures -------------------------------------------------------------
%% Ticket 04's binding constraint: exhaustiveness is only well posed against a
%% *declared* input type, so a multi-clause function must carry a signature.
signature -> type_prim uident '(' params ')' ';' :
    {signature, line('$2'), value('$2'), '$1', '$4'}.

params -> '$empty'    : [].
params -> param_list  : '$1'.

param_list -> param                : ['$1'].
param_list -> param ',' param_list : ['$1' | '$3'].

%% A parameter may be named or anonymous: `Order o` or just `Order`.
param -> type_prim lident : {param, '$1', value('$2')}.
param -> type_prim        : {param, '$1', '_'}.

%% --- clauses ----------------------------------------------------------------
clause -> uident '(' patterns ')' guard '->' expr ';' :
    {clause, line('$1'), value('$1'), '$3', '$5', '$7'}.

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

%% A local call. The slice has no qualified names, so ticket 17's `|>` and the
%% module-qualified form are both out of scope here.
expr -> uident '(' expr_list ')' : {e_call, line('$1'), value('$1'), '$3'}.
expr -> uident '(' ')'           : {e_call, line('$1'), value('$1'), []}.

expr -> '(' expr_list ')' :
    case '$2' of
        [Single] -> Single;
        Many     -> {e_tuple, line('$1'), Many}
    end.

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
