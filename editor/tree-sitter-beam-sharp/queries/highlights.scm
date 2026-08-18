; beam-sharp highlight queries.
;
; Capture names follow nvim-treesitter's standard set, so a colourscheme needs
; no per-language configuration.
;
; ORDER MATTERS: where two patterns capture the same node, the LAST one wins.
; The general rules are written first and the refinements after them, which is
; how `<` gets to be an operator everywhere except inside a generic bracket.

; --- comments ----------------------------------------------------------------
(comment) @comment @spell

; --- keywords ----------------------------------------------------------------
[
  "module"
  "type"
  "record"
  "using"
  "behaviour"
  "behavior"
  "with"
] @keyword

; `switch` is the only branching construct and `when` the only guard, so between
; them these two are the whole of the language's control flow.
[
  "switch"
  "when"
] @keyword.conditional

; --- literals ----------------------------------------------------------------
; The two keyword atoms. Captured as booleans rather than as identifiers because
; that is what they ARE -- an identifier here would be a variable, and a variable
; in pattern position matches everything.
(boolean) @boolean

; `:name` and `:'Shop.Order'`. An atom is not a string, but every editor theme
; has a colour for a symbol and almost none has one for an atom.
(atom) @string.special.symbol

(integer) @number

; --- types -------------------------------------------------------------------
(builtin_type) @type.builtin
(type_identifier) @type
(type_parameter) @type.parameter

; --- names -------------------------------------------------------------------
; THIS IS WHAT A REGEX GRAMMAR CANNOT DO. A type and a function are the same
; token class -- PascalCase, ticket 27 §4 -- so `Order` and `Describe` are
; indistinguishable to a lexer. Here they are different nodes because they are
; reached through different productions, and the highlighter simply asks.
(function_name) @function
(call function: (function_name) @function.call)

; F18. A codegen obligation is NOT a call — no such function exists in the
; emitted module — so it is coloured as the built-in construct it is rather than
; as something the author could have defined.
(instantiation obligation: (type_identifier) @function.builtin)

(field_name) @property
(variable) @variable
(parameter name: (lident) @variable.parameter)
(wildcard) @variable.builtin

; A record construction names a type and builds a value, so it reads better as a
; constructor than as either one alone.
(record_construction name: (type_identifier) @constructor)

; --- operators and punctuation -----------------------------------------------
[
  "->"
  "=>"
  ".."
  "&&"
  "||"
  "=="
  "!="
  "<"
  ">"
  "<="
  ">="
  "+"
  "-"
  "*"
  "="
  "|"
] @operator

[ "(" ")" "[" "]" "{" "}" ] @punctuation.bracket
[ "," ":" "." ] @punctuation.delimiter

; THE PAYOFF, and the reason this grammar exists rather than a regex one.
; `list<int>` and `a < b && c > d` are the same characters; ticket 28 settled the
; rule positionally -- a bracket in type position, a comparison everywhere else --
; and F6.9 pins it. A regex has no notion of position and must colour one of the
; two wrongly. These two patterns come last, so inside a generic they win.
(generic_type ["<" ">"] @punctuation.bracket)
(type_alias ["<" ">"] @punctuation.bracket)
