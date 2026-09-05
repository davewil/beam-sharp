%%% beam-sharp parser.
%%%
%%% A program is a list of declarations: `module`, `using`, `type`, `record`,
%%% `behaviour`, a signature, or a clause. A function is a signature followed
%%% by clauses that repeat its name, and each clause head carries patterns in
%%% the parameter position, so N clauses stand where C# allows one (ticket 01).

Nonterminals
  program decls decl
  module_decl type_decl signature clause foreign_decl foreign_sigs foreign_sig
  behaviour_decl record_decl field_decls field_decl
  type_expr type_union_members type_prim type_list type_params
  params param_list param
  patterns pattern_list pattern plist_items pat_fields pat_field
  rel_pattern rel_test int_lit refinement
  bin_segments bin_segment bin_size
  guard guard_expr
  body binding
  expr expr_list elist_items assign_fields assign_field
  switch_arms switch_arm modpath using_decl visibility call
  .

Terminals
  'module' 'type' 'when' 'using' 'behaviour' 'record' 'with' 'switch' 'var'
  'and' 'or' 'where' 'public' 'private'
  uident lident atom_lit integer string_lit '_'
  '->' '=>' '==' '!=' '<=' '>=' '<<' '<' '>' '+' '-' '*' '/' '%'
  '=' '|' '|>' '|?>' ',' '(' ')' '[' ']' '{' '}' '..' '.' ':' '?'
  .

Rootsymbol program.

%% Guards and expressions share one operator table, with `and`/`or` as the
%% conjunctions; a guard over typed values cannot fail, so there is no
%% fail-to-false (ticket 08, amended by 44). `=` is not an expression
%% operator, a binding is a body form (ticket 34), but it needs the lowest
%% precedence so `x = 1 + 2` shifts the operator instead of reducing the bind.
Nonassoc  50 '='.
Left  100 'or'.
Left  200 'and'.
Nonassoc 300 '==' '!=' '<' '>' '<=' '>='.
%% The pipe is looser than arithmetic, so `a + b |> F()` is `(a + b) |> F()`,
%% and tighter than comparison and `=`, so `var x = a |> F()` shifts the pipe
%% before the binding reduces; that is Elixir's position. `Left`, so
%% `a |> F() |> G()` is `G(F(a))`, and both operators share the level so
%% `a |?> F() |> G()` needs no bracket (ticket 17 §1 and §4, F14.5).
Left 350 '|>' '|?>'.
Left  400 '+' '-'.
%% `/` and `%` sit at `*`'s level and associate left, so `a / b / c` is
%% `(a / b) / c`; regrouping changes a truncating division (F26, ticket 38).
Left  500 '*' '/' '%'.
%% `with` binds tighter than any operator: `o with { Total = 1 } == x` reads as
%% a comparison of the updated record, which is the only sensible parse.
Nonassoc 600 'with'.
%% A switch subject binds tighter still, as in C#: `a + b switch { … }` is
%% `a + (b switch { … })`. Nonassoc, because a chained switch has no reading
%% worth having.
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
decl -> using_decl  : '$1'.

%% --- records ----------------------------------------------------------------
%% A record erases to a map carrying a tag minted from its qualified type
%% name. The tag is an ordinary field, so a hand-written `type` with the same
%% tag is the same type (ticket 26 §1).
record_decl -> 'record' uident '{' field_decls '}' :
    {record_decl, line('$1'), value('$2'), '$4'}.

field_decls -> field_decl                 : ['$1'].
field_decls -> field_decl ',' field_decls : ['$1' | '$3'].

field_decl -> uident ':' type_expr : {field, value('$1'), '$3'}.

%% There are no optional fields: `Notes?: int` is refused by name, and the
%% message says to write `Notes: option<int>` instead (ticket 26 §4, F6).
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
%% `behaviour GenServer` uses the platform's own word and is emitted as
%% written. Not `using GenServer`, which is the same tokens as a one-segment
%% import and would need a symbol table to tell apart.
behaviour_decl -> 'behaviour' uident : {behaviour, line('$1'), value('$2')}.

%% --- foreign modules --------------------------------------------------------
%% A foreign module is written as the atom it is on the BEAM, and the call
%% site is `:ets.lookup(t, k)`. The declaration attaches types to the name
%% Erlang already has; nothing is renamed and no case mapping exists.
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4'}.

foreign_sigs -> foreign_sig              : ['$1'].
foreign_sigs -> foreign_sig foreign_sigs : ['$1' | '$2'].

foreign_sig -> type_prim lident '(' params ')' :
    {foreign_sig, line('$2'), value('$2'), '$1', '$4'}.

%% --- native imports ---------------------------------------------------------
%% `using Shop.Orders` declares a dependency on a B# module and introduces no
%% name, like the foreign form above; the two are one construct, told apart
%% by the token class of what follows `using` (ticket 41 §1).
using_decl -> 'using' modpath : {import, line('$1'), modatom('$2')}.

%% --- module -----------------------------------------------------------------
%% A module's atom is its full dotted path, because a record tag is minted as
%% `Mod.Name` and only a unique module keeps two contexts from minting the
%% same tag (ticket 40 §1). `modpath` is shared with `using` and with the
%% qualified call site.
module_decl -> 'module' modpath : {module, line('$1'), modatom('$2')}.

%% `modpath` must be left-recursive. The right-recursive form builds with
%% shift/reduce conflicts (3, measured by `47c_alias_grammar_conflicts.sh` on
%% 2026-08-31) and misparses `List.Map(x)`, taking `List.Map` as the path and
%% leaving no function name. Left-recursive, at `modpath '.' uident` with `(`
%% ahead yecc shifts, so the last segment is the function name at a call site
%% and part of the path everywhere else (ticket 41 §1).
modpath -> uident               : [value('$1')].
modpath -> modpath '.' uident   : '$1' ++ [value('$3')].

%% --- type aliases -----------------------------------------------------------
%% `type X = ...` is the single naming construct; the name never enters the
%% algebra and there is no `union` keyword (ticket 09).
type_decl -> 'type' uident '=' type_expr :
    {type_alias, line('$1'), value('$2'), [], '$4'}.

%% A refined type is the alias with a predicate on it:
%% `type Octet = int where value >= 0 and value <= 255`. A guard-decidable
%% predicate becomes an interval in the algebra; anything else is refused by
%% the checker, not here (ticket 20 §5, as amended by 29). `value` is an
%% ordinary identifier the refinement translator gives meaning to, so a
%% parameter may still be named `value`.
type_decl -> 'type' uident '=' type_expr 'where' refinement :
    {type_refined, line('$1'), value('$2'), '$4', '$6'}.

%% The predicate is an ordinary expression, read back by the same
%% `alternatives/1` a guard goes through, so a refinement and a guard cannot
%% disagree about what `value >= 0` means (F2.5).
refinement -> expr : '$1'.

%% A parametric alias binds its variables here and substitutes them at the
%% use, so `Pair<int>` resolves to the tuple before `bs_types` sees it. A
%% parameter is lexed as `uident` like any user type name, so this list alone
%% distinguishes the two (ticket 27, F6.7).
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

%% The anonymous map type is what a record is: `type Spelled = { Kind:
%% :'Shop.Order', Id: int }` is the same type as the record whose tag mints
%% to that atom (ticket 09, F3.2).
type_prim -> '{' field_decls '}' : {t_map, '$2'}.

%% `list<int>`, `result<Delivery, ConsumeError>`, `Pair<int>`. In type
%% position nothing compares, so `<` is a bracket with no lookahead; the value
%% side did not learn it (ticket 28, F6.9). Lowercase is the prelude namespace
%% and PascalCase a user alias, both the same node. Arity is checked where the
%% parameters are known, not here (F6.6).
type_prim -> lident '<' type_list '>' : {t_generic, value('$1'), '$3'}.
type_prim -> uident '<' type_list '>' : {t_generic, value('$1'), '$3'}.

type_list -> type_expr               : ['$1'].
type_list -> type_expr ',' type_list : ['$1' | '$3'].

%% --- signatures -------------------------------------------------------------
%% A multi-clause function must carry a signature, because exhaustiveness is
%% only well posed against a declared input type (ticket 04). The visibility
%% marker is optional and an unmarked signature is private: it carries `none`,
%% and every reader tests `=:= public`, so `none` sorts as private by
%% construction (F12, ticket 40 §3 as amended 2026-08-17).
signature -> type_prim uident '(' params ')' :
    {signature, line('$2'), value('$2'), '$1', '$4', none}.
signature -> visibility type_prim uident '(' params ')' :
    {signature, line('$3'), value('$3'), '$2', '$5', '$1'}.

visibility -> 'public'  : public.
visibility -> 'private' : private.

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

%% A body is zero or more bindings followed by one expression, whose value is
%% the body's value (ticket 34). No terminator is needed: only a binding puts
%% `=` after a lowercase name, and `=` is not an expression operator, so one
%% token of lookahead separates `x = 1` from a body that is the variable `x`.
body -> expr : '$1'.
body -> binding body :
    case '$2' of
        {e_block, BL, Binds, Final} -> {e_block, BL, ['$1' | Binds], Final};
        Final -> {e_block, element(2, '$1'), ['$1'], Final}
    end.

%% `var` introduces and a bare `=` matches. The marker lets this rule take a
%% `pattern` directly: without it `binding -> pattern '=' expr` has
%% reduce/reduce conflicts (15 on 2026-08-16, `45a`'s control reproduces it)
%% and yecc refuses to generate, since every pattern form shares its first
%% token with an expression form. The marker also makes `var { Kind: k } = o`
%% parse, since a record pattern is not an expression (F8).
binding -> 'var' pattern '=' expr : bind(line('$3'), '$2', '$4').

%% The bare form is a match only: its left is an expression, narrowed by
%% `to_match/1`, which rejects anything that would introduce a name.
binding -> expr '=' expr : {dbind, line('$2'), to_match('$1'), '$3'}.

patterns -> '$empty'     : [].
patterns -> pattern_list : '$1'.

pattern_list -> pattern                  : ['$1'].
pattern_list -> pattern ',' pattern_list : ['$1' | '$3'].

pattern -> integer             : {p_int, line('$1'), value('$1')}.

%% A pattern takes a negative literal and not a general negation, because a
%% pattern is a value and `-x` is a computation.
pattern -> '-' integer         : {p_int, line('$1'), -value('$2')}.
pattern -> atom_lit            : {p_atom, line('$1'), value('$1')}.
pattern -> lident              : {p_var, line('$1'), value('$1')}.
pattern -> '_'                 : {p_wild, line('$1')}.

%% `== name` matches the value a name already holds; `==` keeps the `=:=`
%% meaning it has everywhere else (ticket 45, ticket 16). The relational
%% family divides on the operand: a relational takes a literal and `==` takes
%% a name, so `>= acc` and `== 4` are both refused. `==acc` and `== acc` are
%% one token stream.
pattern -> '==' lident         : {p_eqvar, line('$1'), value('$2')}.
%% A relational pattern names a span of integers where a whole argument goes:
%% `Classify(>= 4 and <= 7)` (ticket 42). `4..7` was refused because `..`
%% already means "the rest" in pattern position: borrow the construct, or do
%% not borrow the glyph. The combinator is restricted to relational tests, not
%% patterns in general, because `pattern 'and' pattern` would put `and` after
%% every pattern form while `and` is also an expression operator; the narrow
%% nonterminal has zero yecc conflicts, measured.
pattern -> rel_pattern : '$1'.

%% A string literal in pattern position is a byte-string singleton
%% (ticket 30 §4). Its residual is always open, so a set of these is never
%% exhaustive and a catch-all beside them is required, as in Gleam.
pattern -> string_lit : {p_str, line('$1'), value('$1')}.

%% A binary pattern closes on two `'>'` tokens, not a `>>`: the lexer has no
%% `>>` rule because `list<list<int>>` needs its close as two tokens (F13).
%% The pattern does shape and a function head does value, so there are no
%% relational patterns inside a segment; value dispatch belongs in a second
%% head, where the residual is computed (ticket 30 §§1, 2 and 4).
pattern -> '<<' bin_segments '>' '>' : {p_bin, line('$1'), '$2'}.

bin_segments -> bin_segment                  : ['$1'].
bin_segments -> bin_segment ',' bin_segments : ['$1' | '$3'].

%% A segment binds a name, matches a literal, or discards; its size is a
%% literal width, an earlier binding, or absent, and absent means the
%% remainder, unlike Erlang where a bare segment is one byte (F13, ticket 30
%% §2). `bs_check`, not the parser, refuses an unsized segment that is not
%% last, a width that is not positive, a literal that does not fit, and a size
%% not bound earlier in the same pattern.
bin_segment -> lident bin_size        : {seg_bind, line('$1'), value('$1'), '$2'}.
bin_segment -> '_' bin_size           : {seg_wild, line('$1'), '$2'}.
bin_segment -> int_lit ':' integer    : {seg_int,  line('$2'), '$1', value('$3')}.
bin_segment -> string_lit             : {seg_str,  line('$1'), value('$1')}.

bin_size -> '$empty'         : rest.
bin_size -> ':' integer      : {width, value('$2')}.
%% `payload:size` lexes as `payload` then the atom `:size`, because the atom
%% sigil wins by longest-match, while `payload:8` is three tokens. The atom is
%% accepted here, the one position where an atom has no other meaning, rather
%% than making the lexer context-sensitive; both productions are kept so that
%% `payload:size` and `payload: size` mean the same thing.
bin_size -> atom_lit         : {sized_by, value('$1')}.
bin_size -> ':' lident       : {sized_by, value('$2')}.

rel_pattern -> rel_test : '$1'.
rel_pattern -> rel_pattern 'and' rel_pattern :
    {p_and, line('$2'), '$1', '$3'}.
rel_pattern -> rel_pattern 'or' rel_pattern :
    {p_or, line('$2'), '$1', '$3'}.

rel_test -> '>=' int_lit : {p_rel, line('$1'), '>=', '$2'}.
rel_test -> '>'  int_lit : {p_rel, line('$1'), '>',  '$2'}.
rel_test -> '<=' int_lit : {p_rel, line('$1'), '<=', '$2'}.
rel_test -> '<'  int_lit : {p_rel, line('$1'), '<',  '$2'}.

%% A bound is a literal and may be negative: `Classify(<= -1)` is the
%% residual's own spelling for the negative half of `int`, so the parser must
%% accept what the diagnostic prints (ticket 23 §2).
int_lit -> integer     : value('$1').
int_lit -> '-' integer : -value('$2').

pattern -> '(' pattern_list ')' :
    case '$2' of
        [Single] -> Single;
        Many     -> {p_tuple, line('$1'), Many}
    end.

%% A property pattern `{ Kind: :'Shop.Order' }` is open: it constrains the
%% fields it names and says nothing about the rest, which is why the algebra
%% carries `closed`/`open`. The tag is an ordinary field, so dispatching over
%% a union of records needs no record-specific form (ticket 01, ticket 26 §1).
pattern -> '{' pat_fields '}' : {p_map, line('$1'), '$2'}.

pat_fields -> pat_field                : ['$1'].
pat_fields -> pat_field ',' pat_fields : ['$1' | '$3'].

pat_field -> uident ':' pattern : {value('$1'), '$3'}.

%% `Order { Id: id }` names the type and lets the compiler mint the tag, so an
%% erasure detail need not be written by hand. `p_rec` carries the name, not a
%% resolved tag: `bs_check` and the emitter each resolve it through the one
%% minting point (ticket 55, F22).
pattern -> uident '{' pat_fields '}' :
    {p_rec, line('$1'), value('$1'), '$3'}.

%% The binder is a bare trailing name, as in C#'s designation and a
%% signature's `Order o`: `as` is reserved for checked conversion and `=` is
%% kept out of pattern position (ticket 45). Zero yecc conflicts over a zero
%% baseline, measured by `55f_yecc_conflicts.sh` (ticket 55).
pattern -> uident '{' pat_fields '}' lident :
    {p_bind, line('$1'), value('$5'), {p_rec, line('$1'), value('$1'), '$3'}}.

%% `Circle c` is a type and a name with no fields: an empty `p_rec`, so the
%% tag test is all it carries and every downstream case already handles it.
pattern -> uident lident :
    {p_bind, line('$1'), value('$2'), {p_rec, line('$1'), value('$1'), []}}.

%% The binder over a bare property pattern: naming the type and binding the
%% value are independent, as in C#.
pattern -> '{' pat_fields '}' lident :
    {p_bind, line('$1'), value('$4'), {p_map, line('$1'), '$2'}}.

pattern -> '[' ']'          : {p_nil, line('$1')}.
pattern -> '[' plist_items ']' :
    begin {Items, Rest} = '$2', {p_list, line('$1'), Items, Rest} end.

%% A list pattern is `[]`, `[a, b]` or `[h, ..t]`: a prefix and an optional
%% rest, in C#'s collection-expression spelling (ticket 08, ticket 28). The
%% rest lives inside this nonterminal because a separate
%% `pattern_list ',' '..' pattern` rule needs two tokens of lookahead past the
%% comma and yecc has one. A `nil` rest means the list is closed: `[a, b]` is
%% exactly two, as in Erlang, Elixir, C# and Gleam. The rest is a marker that
%% may bind (`..t`) or not (`..`, `.._`) and constrains nothing, which bounds
%% the checker's unfolding to the longest prefix written (F20, ticket 54).
plist_items -> pattern                 : {['$1'], nil}.
plist_items -> '..'                    : {[], {p_wild, line('$1')}}.
plist_items -> '..' '_'                : {[], {p_wild, line('$2')}}.
plist_items -> '..' lident             : {[], {p_var, line('$2'), value('$2')}}.
plist_items -> pattern ',' plist_items :
    begin {Items, Rest} = '$3', {['$1' | Items], Rest} end.

%% The two retired forms get a fix-it rather than a bare syntax error; `..[]`
%% was ticket 53's answer and will be typed again from memory.
plist_items -> '..' '[' ']'             :
    return_error(line('$1'),
                 "`..[]` is retired -- a closed list is written `[a, b]`, "
                 "with no rest").
plist_items -> '..' '[' plist_items ']' :
    return_error(line('$1'),
                 "a rest is `..` or `..name` -- write the elements in the "
                 "prefix instead").

guard -> '$empty'            : none.
guard -> 'when' guard_expr   : {guard, '$2'}.

guard_expr -> expr : '$1'.

%% --- expressions ------------------------------------------------------------
expr -> integer  : {e_int, line('$1'), value('$1')}.

%% Unary minus lowers to `0 - e` rather than a node of its own, so nothing
%% downstream of the parser learns a new shape.
expr -> '-' expr : {e_op, line('$1'), '-', {e_int, line('$1'), 0}, '$2'}.
expr -> atom_lit : {e_atom, line('$1'), value('$1')}.
expr -> string_lit : {e_str, line('$1'), value('$1')}.
expr -> lident   : {e_var, line('$1'), value('$1')}.
%% `_` is an expression only so that `(a, _) = pair` parses, the left of a
%% bare `=` being an expression. Used as a value it is rejected by `bs_check`.
expr -> '_'      : {e_wild, line('$1')}.

%% --- calls ------------------------------------------------------------------
%% The call forms are a nonterminal of their own because a pipe's right
%% operand is a `call`, not an `expr`: the pipe never passes a bare function
%% value, so `x |> F` is a syntax error rather than a type error, and the
%% right operand needs no precedence (ticket 17 §1, F14). A duplicate
%% `expr -> uident '(' ...` must not be left behind: yecc reports that
%% reduce/reduce conflict as a warning and still emits a parser.

%% A local call.
call -> uident '(' expr_list ')' : {e_call, line('$1'), value('$1'), '$3'}.
call -> uident '(' ')'           : {e_call, line('$1'), value('$1'), []}.

%% `ValidateAs<list<Order>>(x)` is the instantiation bracket. A bare `uident`
%% is not an expression in this grammar, so none can be the left operand of
%% `expr '<' expr` and this production adds no conflict; `Foo < 3` is a syntax
%% error before and after it. `bs_check` refuses by name any function outside
%% the closed set `ValidateAs`, `ParseAtom`, `ToExistingAtom` (ticket 28, F18).
%% The empty argument list is needed by `x |> ValidateAs<list<Order>>()`
%% (ticket 18 §7).
call -> uident '<' type_list '>' '(' expr_list ')' :
    {e_inst, line('$1'), value('$1'), '$3', '$6'}.
call -> uident '<' type_list '>' '(' ')' :
    {e_inst, line('$1'), value('$1'), '$3', []}.

%% `:ets.lookup(t, k)` calls Erlang: an atom literal on the left, so no
%% casing convention is needed to tell it from a field projection.
call -> atom_lit '.' lident '(' expr_list ')' :
    {e_foreign_call, line('$1'), value('$1'), value('$3'), '$5'}.
call -> atom_lit '.' lident '(' ')' :
    {e_foreign_call, line('$1'), value('$1'), value('$3'), []}.

%% `List.Map(xs)` calls a B# module. The three dot-forms are told apart by
%% the token class of the left side alone: `lident` projects a field,
%% `atom_lit` calls Erlang, a `uident` path calls a B# module (ticket 41 §1).
call -> modpath '.' uident '(' expr_list ')' :
    {e_qcall, line('$2'), modatom('$1'), value('$3'), '$5'}.
call -> modpath '.' uident '(' ')' :
    {e_qcall, line('$2'), modatom('$1'), value('$3'), []}.

expr -> call : '$1'.

%% --- the pipe and the valve -------------------------------------------------
%% The piped value becomes the first argument, and that rewrite is all a pipe
%% is: `bs_lower:pipe_into/3` emits the call node here, so the checker and
%% the emitter see `F(x, a)` and nothing else (ticket 17 §1).
expr -> expr '|>' call : bs_lower:pipe_into(line('$2'), '$1', '$3').

%% The valve branches, so it cannot be a rewrite here; `bs_lower:valves/1`
%% turns it into a two-armed `switch` after the parse, because that needs two
%% synthesised names per stage unique across the file and a yecc action
%% cannot carry a counter (ticket 17 §4).
expr -> expr '|?>' call : {e_valve, line('$2'), '$1', '$3'}.

%% `x |> F` with no argument list is refused by the grammar, not by a named
%% production: two `expr '|>' modpath` productions would buy a better message
%% and cost 2 shift/reduce conflicts against a grammar that holds 0.

expr -> '(' expr_list ')' :
    case '$2' of
        [Single] -> Single;
        Many     -> {e_tuple, line('$1'), Many}
    end.

%% --- records in expression position -----------------------------------------
%% Construction names the type and assigns with `=`; `:` matches in a pattern
%% and declares in the type (ticket 26 §2).
expr -> uident '{' assign_fields '}' :
    {e_record, line('$1'), value('$1'), '$3'}.

assign_fields -> assign_field                   : ['$1'].
assign_fields -> assign_field ',' assign_fields : ['$1' | '$3'].

assign_field -> uident '=' expr : {value('$1'), '$3'}.

%% `with` updates a record without changing its field set; there is no spread,
%% so `{ ...o, X = 1 }` is a syntax error (ticket 26 §2).
expr -> expr 'with' '{' assign_fields '}' :
    {e_with, line('$2'), '$1', '$4'}.

%% The dot projects and is never a call: a lowercase receiver is a value and
%% a PascalCase one is a module, so a field `Total` and a function `Total`
%% coexist, told apart by syntax before types exist (ticket 17).
expr -> lident '.' uident : {e_proj, line('$2'), value('$1'), value('$3')}.

%% --- switch -----------------------------------------------------------------
%% A switch arm uses the clause head's own `pattern` nonterminal, so the
%% construct inherits exhaustiveness, guards and the residual with nothing
%% added (ticket 17 §6). An arm's body is a single `expr`, not a `body`: arms
%% are comma-separated and a body has no terminator, so `p => x = 1, x + 2`
%% could not be told from two arms with one token of lookahead.
expr -> expr 'switch' '{' switch_arms '}' :
    {e_switch, line('$2'), '$1', '$4'}.

switch_arms -> switch_arm                 : ['$1'].
switch_arms -> switch_arm ',' switch_arms : ['$1' | '$3'].

%% The arm carries the `=>`'s line, because that token is present in every
%% arm while a pattern's line may belong to a token the reader is not seeing.
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
expr -> expr '/'  expr : {e_op, line('$2'), '/',  '$1', '$3'}.
expr -> expr '%'  expr : {e_op, line('$2'), '%',  '$1', '$3'}.
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

%% A module path becomes its dotted atom here, so `bs_check:qualified/2` and
%% the emit path see the module atom and learn no new shape (ticket 40 §1).
modatom(Segments) -> list_to_atom(dotted(Segments)).

%% The same join as a string, for the diagnostics that have to print a path back
%% to the author before it has become an atom.
dotted(Segments) ->
    lists:flatten(lists:join(".", [atom_to_list(S) || S <- Segments])).

%% A plain name is a `bind`; anything else is a destructuring `dbind` carrying
%% a real pattern (ticket 34, F5).
bind(_L, {p_var, VL, V}, E) -> {bind, VL, V, E};
bind(L, Pat, E)             -> {dbind, L, Pat, E}.

%% The bare `=` is a match, so its left side must introduce nothing: it is
%% narrowed to a pattern of literals and compounds of literals, and anything
%% else is the error. The left is still parsed as an `expr` because one token
%% of lookahead cannot tell `(1, 2) = pair` from the tuple `(1, 2)`; only the
%% `var` form escapes that.
to_match({e_wild, L})     -> {p_wild, L};
to_match({e_int, L, N})   -> {p_int, L, N};
to_match({e_atom, L, A})  -> {p_atom, L, A};
%% There is no `e_str` clause: a string literal on the left of a bare `=`
%% falls to the error below.
to_match({e_tuple, L, Es})-> {p_tuple, L, [to_match(E) || E <- Es]};
to_match({e_nil, L})      -> {p_nil, L};
%% The rest narrows to a marker or not at all. The expression grammar admits
%% `..expr` because a spread is real in that position, so without this
%% `[a, ..[]] = xs` would keep the retired form alive (F20).
to_match({e_list, L, Items, Rest}) ->
    {p_list, L, [to_match(I) || I <- Items], to_match_rest(L, Rest)};
%% The message names the fix, `var x = ...`, which is the most common thing a
%% reader from the old dialect will type (F8.3, F4.7).
to_match({e_var, L, V}) ->
    return_error(L, lists:flatten(
        io_lib:format("~ts is introduced here, and a bare `=` matches rather "
                      "than introduces -- write `var ~ts = ...`", [V, V])));
to_match(E) ->
    return_error(element(2, E),
                 "the left of a bare `=` must be a literal pattern. To introduce "
                 "a name, write `var <pattern> = ...`").

%% `nil` is a closed list and stays closed; `_` is the anonymous marker; a
%% variable goes to `to_match/1`, which refuses it with the better message,
%% since a bare `=` cannot introduce. Everything else is the retired form.
to_match_rest(_L, nil)               -> nil;
to_match_rest(_L, {e_wild, WL})      -> {p_wild, WL};
to_match_rest(_L, E = {e_var, _, _}) -> to_match(E);
to_match_rest(L, _E) ->
    return_error(L, "a rest is `..` or `..name` -- `..[]` is retired, and a "
                    "closed list is written `[a, b]`").
