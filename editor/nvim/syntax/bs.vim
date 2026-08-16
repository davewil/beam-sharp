" beam-sharp syntax highlighting.
"
" Derived from compiler/src/bs_lexer.xrl, which is the source of truth.
"
" DEFINITION ORDER IS SIGNIFICANT. Vim resolves overlapping syntax items by:
" a keyword beats a match; among matches starting at the same position the one
" defined LAST wins; and an item starting earlier beats one starting later. So
" the general rules are defined first and the specific ones after them, and the
" comment rule is defined last so that nothing leaks out of a `//` line.

if exists("b:current_syntax")
  finish
endif

" --- keywords ----------------------------------------------------------------
" `switch` is the only branching construct (ticket 17 §6). There is no `if`, no
" `else`, no `cond` and no ternary to list beside it.
syn keyword bsConditional switch when
" `var` introduces a name (F8, ticket 45); `where` carries a type's refinement
" predicate (F2, ticket 20 §5). `var` shipped with F8 and was never listed here.
syn keyword bsKeyword     module type record using behaviour behavior with var where

" The one conjunction, in every position -- guard, pattern combinator and
" refinement predicate (ticket 44, amending ticket 08). There is no && and no ||.
syn keyword bsOperator    and or

" The two keyword atoms. Highlighting these as constants rather than as
" identifiers is not decoration: as identifiers they are VARIABLES, and a
" variable in pattern position matches everything.
syn keyword bsBoolean     true false

" `int`, `atom`, `term`, `bool` are the builtin types; everything else lowercase
" is a variable or a parameter.
syn keyword bsType        int atom term bool

" --- names -------------------------------------------------------------------
" A type and a function are the SAME token class -- PascalCase -- so only the
" compiler's symbol table can really tell `Order` from `Describe`. The bracket
" is the best heuristic a regex has; semantic tokens over an LSP would fix it.
syn match bsTypeName  "\<[A-Z][a-zA-Z0-9_]*\>"
syn match bsFunction  "\<[A-Z][a-zA-Z0-9_]*\>\ze\s*("
syn match bsField     "\<[A-Z][a-zA-Z0-9_]*\>\ze\s*:"
syn match bsVariable  "\<[a-z][a-zA-Z0-9_]*\>"

" Only where a bracket follows: written without one these three are an error
" (needs_type_args), so requiring the `<` is more accurate than a bare word list
" and leaves `result` free to be an ordinary variable name.
syn match bsType      "\<\%(list\|option\|result\)\>\ze\s*<"

syn match bsNumber    "\<\d\+\>"

" Exactly `_`. An identifier cannot start with an underscore -- the lexer has no
" rule for one -- so `_foo` does not lex at all and is not matched here.
syn match bsWildcard  "\<_\>"

" --- operators ---------------------------------------------------------------
" Two arrows, two jobs: `->` is a clause, `=>` is a switch arm.
syn match bsOperator  "->\|=>\|\.\.\|&&\|||\|==\|!=\|<=\|>=\|[<>+\-*=|?:]"

" --- atoms -------------------------------------------------------------------
" Defined after the operator rule so that `:` opening an atom beats `:` the
" separator. The quoted form comes last of the two, for the same reason.
"
" There is no space after the sigil, which is what makes `Id:int` colour `:int`
" as an atom while `Id: int` does not -- the identical one-character trap the
" parser catches by name.
syn match bsAtom      ":[a-z][a-zA-Z0-9_]*"
syn match bsAtom      ":'[^']*'"

" --- comments ----------------------------------------------------------------
" Last, so it claims the whole line ahead of anything defined above it.
syn match bsComment   "//.*$"

hi def link bsComment     Comment
hi def link bsConditional Conditional
hi def link bsKeyword     Keyword
hi def link bsBoolean     Boolean
hi def link bsType        Type
hi def link bsTypeName    Structure
hi def link bsFunction    Function
hi def link bsField       Identifier
hi def link bsVariable    Normal
hi def link bsNumber      Number
hi def link bsAtom        Constant
hi def link bsWildcard    Special
hi def link bsOperator    Operator

let b:current_syntax = "bs"
