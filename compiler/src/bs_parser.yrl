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
%% Ticket 17 §1 and §4. The window is bounded on BOTH sides and only one bound
%% is obvious: F14.5 wants `a + b |> F()` to read as `(a + b) |> F()`, which puts
%% the pipe looser than arithmetic — but `var x = a |> F()` wants it tighter than
%% `=`, or the binding reduces before the operator shifts. So the window is
%% 51..399, and inside it the scenarios do not discriminate at all. Elixir puts
%% `|>` tighter than comparison and looser than arithmetic — `a |> F() == b` is
%% `(a |> F()) == b` there — which is the BEAM-family precedent the borrow
%% heuristic points at, and 350 is that position in this table.
%%
%% `Left`, because a chain is left-associative: `a |> F() |> G()` is `G(F(a))`,
%% which is the only reading in which a pipeline runs in the order it is read.
%% Both operators share the level so `a |?> F() |> G()` needs no bracket.
Left 350 '|>' '|?>'.
Left  400 '+' '-'.
%% F26 / ticket 38. `/` and `%` sit at `*`'s level and associate left, so
%% `a / b / c` is `(a / b) / c` and `a / b * c` is `(a / b) * c`. Both matter for
%% truncating division, where regrouping changes the answer: `7 / 2 * 2` is 6.
Left  500 '*' '/' '%'.
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
decl -> using_decl  : '$1'.

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

%% --- native imports ---------------------------------------------------------
%% Ticket 41 §1: `using` GENERALISES rather than being overloaded. The foreign
%% form above attaches types to a name Erlang already has and introduces no B#
%% name; this one declares a dependency and also introduces no B# name. Same
%% construct, told apart by the token class of what follows.
using_decl -> 'using' modpath : {import, line('$1'), modatom('$2')}.

%% --- module -----------------------------------------------------------------
%% Ticket 40 §1: a module's atom is its FULL dotted path, because ticket 26's tag
%% mint is `Mod ++ "." ++ Name` and only a unique `Mod` keeps two bounded
%% contexts from minting the same tag. `modpath` is shared with the native
%% `using` (41 §1) and with the qualified call site.
module_decl -> 'module' modpath : {module, line('$1'), modatom('$2')}.

%% TICKET 41 §1 OWED A YECC CONFLICT CHECK AND MARKED IT UNRUN. IT IS RUN, AND
%% THE TICKET'S CLAIM IS HALF FALSE.
%%
%% Its literal delta was RIGHT-recursive — `modpath -> uident '.' modpath` — and
%% that grammar builds with 2 shift/reduce conflicts and then MISPARSES the thing
%% it exists for: `List.Map(x)` is `syntax error before: '('`, because the
%% recursive arm greedily takes `List.Map` as the path and leaves no function
%% name behind. Building is not parsing, which is why this had to be run.
%%
%% LEFT recursion is the fix and it is the whole fix. At `modpath '.' uident`
%% with `(` ahead, yecc's shift preference takes the `(` — so the last segment
%% becomes the function name at a call site, and stays part of the path
%% everywhere else, which is exactly the "separated on the following token"
%% claim the ticket made for the wrong recursion direction.
modpath -> uident               : [value('$1')].
modpath -> modpath '.' uident   : '$1' ++ [value('$3')].

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
%% F12 / ticket 40 §3, amended 2026-08-17 — the visibility marker is OPTIONAL
%% here and optional in the language: AN UNMARKED SIGNATURE IS PRIVATE.
%%
%% It was optional here before the amendment too, for a different reason: §3
%% originally demanded a marker on every signature, and enforcing that in this
%% rule would have reported `syntax error before: 'list'` — a remark about the
%% token AFTER the missing word. The check that refused it by name is gone now,
%% and the grammar did not have to change, which is the argument for having put
%% the rule in the checker rather than here.
%%
%% `none` is what an unmarked signature carries. Every reader of that field tests
%% `=:= public`, never `=/= private`, so `none` sorts as private by construction
%% rather than by remembering to list it.
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

%% A STRING LITERAL IN PATTERN POSITION — ticket 30 §4.
%%
%% One production and no new token: F9 has lexed `string_lit` since it shipped,
%% and the literal was refused here only because nothing admitted it. It is a
%% byte-string singleton, which is the same construct §2 settles at wire scale —
%% F9 filed §4 with ticket 30 on exactly that suspicion and was right.
%%
%% A `string`'s residual is unconditionally OPEN, so a set of these is never
%% exhaustive on its own and a catch-all beside them is required and legal. That
%% matches Gleam, which permits both `"GET" <> rest` and `<<"GET", _:bytes>>` and
%% treats neither as total without `_`.
pattern -> string_lit : {p_str, line('$1'), value('$1')}.

%% A BINARY PATTERN — ticket 30 §§1, 2 and 4.
%%
%% CLOSED ON TWO `'>'` TOKENS, NOT ON A `>>`. The lexer has no `>>` rule and must
%% not gain one: `list<list<int>>` parses and runs, and a `>>` token would
%% swallow its closing brackets. See the comment on the `<<` rule in the lexer
%% for the whole argument. The cost here is one extra symbol in one production;
%% the alternative cost is generic code breaking for a binary feature.
%%
%% The pattern does SHAPE and a function head does VALUE — ticket 30's answer.
%% There are deliberately no relational patterns inside a segment: value dispatch
%% belongs in a second head, where the residual is computed and exhaustiveness
%% bites. Admitting `<<t:8>> when t >= 4` here would look like it proved
%% something and would not.
pattern -> '<<' bin_segments '>' '>' : {p_bin, line('$1'), '$2'}.

bin_segments -> bin_segment                  : ['$1'].
bin_segments -> bin_segment ',' bin_segments : ['$1' | '$3'].

%% A segment binds a name, matches a literal, or discards — and its size is a
%% literal width, an earlier binding, or absent. An ABSENT size means the
%% remainder, which is F13's §2 decision and a deliberate divergence from Erlang,
%% where a bare `<<A, B>>` is two BYTES. In a language with no default width the
%% remainder is the only sensible reading, and the alternative is a marker glyph
%% ticket 30 never decided and a feature may not invent.
%%
%% `bs_check` enforces that an unsized segment comes last, that a width is
%% positive, that a literal fits its width, and that a size names something bound
%% earlier in the same pattern. All four are known-shape refusals with their own
%% diagnostics rather than parse errors, which is this repo's habit.
bin_segment -> lident bin_size        : {seg_bind, line('$1'), value('$1'), '$2'}.
bin_segment -> '_' bin_size           : {seg_wild, line('$1'), '$2'}.
bin_segment -> int_lit ':' integer    : {seg_int,  line('$2'), '$1', value('$3')}.
bin_segment -> string_lit             : {seg_str,  line('$1'), value('$1')}.

bin_size -> '$empty'         : rest.
bin_size -> ':' integer      : {width, value('$2')}.
%% `payload:size` DOES NOT LEX AS THREE TOKENS, and this rule is why there are
%% two productions for one spelling.
%%
%% The atom sigil is `:name` and maximal munch prefers it, so `payload:size` is
%% the variable `payload` followed by the ATOM `:size` — while `payload:8` is
%% three tokens, because `:8` is not an atom. Measured: every `sized_by` test
%% failed with `syntax error before: size` while every width test passed.
%%
%% Fixed in the GRAMMAR rather than the lexer, which is the same call `<<`/`>>`
%% got and for the same reason. Making the atom rule context-sensitive to protect
%% a binary segment would put a collision in `:foo` EVERYWHERE to remove one
%% here; accepting the atom token in the one position where an atom has no other
%% possible meaning costs nothing. A segment size is a length, and no length was
%% ever an atom.
%%
%% Both productions are kept so that `payload:size` and `payload: size` mean the
%% same thing. An author cannot see the token stream and should not have to.
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

%% TICKET 55 / F22 — THE TYPE PREFIX AND THE TRAILING BINDER.
%%
%% The comment above is still true and is now half the story: the tag IS an
%% ordinary field, so `{ Kind: :'Shop.Order' }` remains a complete record
%% pattern. What it costs is that the tag is MINTED — `record_surface/4` puts it
%% there and `qualified/2` builds the qualified atom — so writing it by hand
%% makes an erasure detail load-bearing in source. Naming the type lets the
%% compiler mint it, which is what every neighbour surveyed does.
%%
%% `p_rec` carries the NAME, not a resolved tag. Resolution needs the type
%% environment and this is a parser; `bs_check` and the emitter each resolve it
%% through the one minting point rather than a second one being invented here.
pattern -> uident '{' pat_fields '}' :
    {p_rec, line('$1'), value('$1'), '$3'}.

%% THE BINDER IS A BARE TRAILING NAME, WITH NO KEYWORD, AND BOTH ALTERNATIVES
%% WERE ALREADY SPENT. `as` is committed to C#'s checked conversion — free in
%% the lexer, which makes it look available, and reserved on the map. `=`
%% introduces a binding in a body (F8) and ticket 45 kept it out of pattern
%% position deliberately when it gave `==` the match-a-bound-value meaning.
%%
%% What is left is C#'s bare designation, which is also the shape a SIGNATURE
%% already has: `param -> type_prim lident`, so `Order o`. Measured at zero yecc
%% conflicts over a baseline that is itself zero — see 55f_yecc_conflicts.sh.
pattern -> uident '{' pat_fields '}' lident :
    {p_bind, line('$1'), value('$5'), {p_rec, line('$1'), value('$1'), '$3'}}.

%% `Circle c` — a type and a name, no fields. LANGUAGE.md's own illustrative
%% spelling for dispatch, and character-identical to a parameter. It is an empty
%% `p_rec` rather than a form of its own, so the tag test is the only thing it
%% carries and every downstream case already handles it.
pattern -> uident lident :
    {p_bind, line('$1'), value('$2'), {p_rec, line('$1'), value('$1'), []}}.

%% The binder over the BARE property pattern, which keeps the two halves
%% separable: naming the type and binding the value are independent, and C#
%% permits the designation on both.
pattern -> '{' pat_fields '}' lident :
    {p_bind, line('$1'), value('$4'), {p_map, line('$1'), '$2'}}.

pattern -> '[' ']'          : {p_nil, line('$1')}.
pattern -> '[' plist_items ']' :
    begin {Items, Rest} = '$2', {p_list, line('$1'), Items, Rest} end.

%% F20, ticket 54 — THE REST IS A MARKER, NOT A PATTERN.
%%
%% `nil` here means the list is CLOSED: `[a, b]` is exactly two. It used to mean
%% "no rest was written", which `bs_check` turned into an error telling you to
%% write `[h, ..t]` — a form meaning two-or-MORE, which is a different program
%% and the one the checker miscounted. `[a, b]` is exactly-two in Erlang,
%% Elixir, C# and Gleam alike; refusing it was the divergence.
%%
%% The marker may bind (`..t`) or not (`..`, `.._`), and it constrains nothing.
%% That is what bounds the checker's unfolding to the longest prefix written.
plist_items -> pattern                 : {['$1'], nil}.
plist_items -> '..'                    : {[], {p_wild, line('$1')}}.
plist_items -> '..' '_'                : {[], {p_wild, line('$2')}}.
plist_items -> '..' lident             : {[], {p_var, line('$2'), value('$2')}}.
plist_items -> pattern ',' plist_items :
    begin {Items, Rest} = '$3', {['$1' | Items], Rest} end.

%% The two retired forms, caught here so they get a fix-it rather than a bare
%% "syntax error before: '['". `..[]` was ticket 53's answer and is used four
%% times in exemplar 25a, so it will be typed again from memory.
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

%% --- calls ------------------------------------------------------------------
%% The three call forms are a nonterminal of their own rather than three `expr`
%% productions, and F14 is why. Ticket 17 §1 is explicit that the pipe never
%% passes a bare function value — that was the whole reason `Result.Then` lost to
%% the valve, since it is "the only candidate that forces this ticket to spell
%% *function as a value*". So the rule is `expr '|>' call`, not `expr '|>' expr`
%% with a check afterwards. Two things follow: `x |> F` is a SYNTAX error rather
%% than a type error, which is the right layer for it; and the right operand
%% needs no precedence of its own, because it is not an expression.
%%
%% Factoring is the whole change — no call form gained or lost a spelling. The
%% one thing that must not happen is leaving a duplicate `expr -> uident '(' ...`
%% behind, which is a reduce/reduce conflict yecc reports as a WARNING while
%% still emitting a working-looking parser.

%% A local call.
call -> uident '(' expr_list ')' : {e_call, line('$1'), value('$1'), '$3'}.
call -> uident '(' ')'           : {e_call, line('$1'), value('$1'), []}.

%% F18 — THE INSTANTIATION BRACKET, and this is where ticket 28's closed-set rule
%% finally has something to act on. F6 declined to write it and said why: the set
%% is `ValidateAs`, `ParseAtom` and `ToExistingAtom`, all three were unbuilt, and
%% a rule over an empty set is a no-op. F18 builds the first of them.
%%
%% 28 frames the rule as LEXICAL — `<` opens a bracket after one of those names
%% and is a comparison everywhere else — which on `leex` means a post-lex retag,
%% since a scanner has no context. It is not needed. A bare `uident` IS NOT AN
%% EXPRESSION in this grammar: the only tokens that may follow one are `(`, `{`
%% and `.`, so no `uident` can ever be the left operand of `expr '<' expr` and
%% this production cannot conflict with it. `yecc` reports no new conflict.
%%
%% The observable surface is 28's rule exactly — `Foo < 3` was a syntax error
%% before this production and is one after it. What moves is WHERE the closed set
%% is enforced: `bs_check` refuses a name outside it by name, which is a better
%% error than `syntax error before: '<'` and is the only place that can tell
%% "not a codegen obligation" from "decided, and not built yet".
%%
%% The empty argument list is not decoration. Ticket 18 §7 writes
%% `EtsLookup(:orders, id) |> ValidateAs<list<Order>>()`, and `expr '|>' call`
%% means the pipe's right operand must parse as a `call` with no arguments.
call -> uident '<' type_list '>' '(' expr_list ')' :
    {e_inst, line('$1'), value('$1'), '$3', '$6'}.
call -> uident '<' type_list '>' '(' ')' :
    {e_inst, line('$1'), value('$1'), '$3', []}.

%% `:ets.lookup(t, k)` — an atom literal on the left, so no variable and no
%% casing convention is involved in telling this from a field projection.
call -> atom_lit '.' lident '(' expr_list ')' :
    {e_foreign_call, line('$1'), value('$1'), value('$3'), '$5'}.
call -> atom_lit '.' lident '(' ')' :
    {e_foreign_call, line('$1'), value('$1'), value('$3'), []}.

%% `List.Map(xs)` — ticket 41 §1. The three dot-forms are told apart by the token
%% class of the LEFT side and nothing else: `lident` projects a field, `atom_lit`
%% calls Erlang, `uident` path calls a B# module.
call -> modpath '.' uident '(' expr_list ')' :
    {e_qcall, line('$2'), modatom('$1'), value('$3'), '$5'}.
call -> modpath '.' uident '(' ')' :
    {e_qcall, line('$2'), modatom('$1'), value('$3'), []}.

expr -> call : '$1'.

%% --- the pipe and the valve -------------------------------------------------
%% Ticket 17 §1: the piped value becomes the FIRST argument, and the rewrite is
%% all there is. `bs_lower:pipe_into/3` emits the call node directly, so the
%% checker, the five check sites, the exhaustiveness walk and the `-spec` all see
%% `F(x, a)` because that is what exists — no checker or emitter change at all.
expr -> expr '|>' call : bs_lower:pipe_into(line('$2'), '$1', '$3').

%% Ticket 17 §4: the valve cannot be a rewrite, because it BRANCHES. It is left
%% unlowered here and turned into its two-armed `switch` by `bs_lower:valves/1`
%% after the parse — the lowering needs two synthesised names per stage that are
%% unique across the file, and a yecc action cannot carry a counter. See
%% `bs_lower` for why per-line names are not enough.
expr -> expr '|?>' call : {e_valve, line('$2'), '$1', '$3'}.

%% `x |> F` with no argument list is refused by the grammar above and NOT by a
%% production of its own. A named refusal was written, measured and removed: two
%% `expr '|>' modpath` productions buy a better message and cost 2 shift/reduce
%% conflicts against a grammar that has held 0, and a conflict is the one warning
%% yecc issues while still emitting a parser that looks like it works. §1 asks
%% only that this be a SYNTAX error rather than a type error, which it is —
%% yecc's own `syntax error before:` lands at the right line and the right layer.
%% The trade is recorded here because the next person to want the nicer message
%% should know it was tried rather than overlooked.

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

%% A module path becomes its dotted atom HERE, so nothing downstream learns a new
%% shape. Ticket 40 §1's delta says `bs_check:qualified/2` and the `bsc` emit path
%% need NO CHANGE because both were written against the module atom rather than
%% against a single segment — that holds only if the atom is what reaches them.
modatom(Segments) -> list_to_atom(dotted(Segments)).

%% The same join as a string, for the diagnostics that have to print a path back
%% to the author before it has become an atom.
dotted(Segments) ->
    lists:flatten(lists:join(".", [atom_to_list(S) || S <- Segments])).

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
%% F20 — THE SECOND SITE, AND THE ONE THAT WOULD HAVE BEEN MISSED.
%%
%% `plist_items` above restricts the rest in PATTERN position. A bare `=` parses
%% its left side as an EXPRESSION and narrows it here, and the expression
%% grammar still admits `..expr` because a spread is a real construct in that
%% position. So `[a, ..[]] = xs` would have kept the retired form alive on a
%% path nobody would think to look at. The rest narrows to a marker or not at
%% all.
to_match({e_list, L, Items, Rest}) ->
    {p_list, L, [to_match(I) || I <- Items], to_match_rest(L, Rest)};
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

%% `nil` is a closed list — `[a, b]` — and stays closed. `_` is the anonymous
%% marker. A variable is handed to `to_match/1`, which is the right answer for a
%% bare `=`: it introduces rather than matches, and that is already an error
%% with a better message than anything here could say. Everything else is the
%% retired form and gets the fix-it.
to_match_rest(_L, nil)               -> nil;
to_match_rest(_L, {e_wild, WL})      -> {p_wild, WL};
to_match_rest(_L, E = {e_var, _, _}) -> to_match(E);
to_match_rest(L, _E) ->
    return_error(L, "a rest is `..` or `..name` -- `..[]` is retired, and a "
                    "closed list is written `[a, b]`").
