# Patches COPIES of the real grammar in $W/proto/{a,b,bk}. Run by 10_grammar_delta.sh.
import sys
W = sys.argv[1]
OLD = "foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :\n    {foreign, line('$1'), value('$2'), '$4'}."
def patch(path, f):
    s = open(path).read(); t = f(s); assert s != t, path; open(path, 'w').write(t)

# Option A -- per block, contextual word `from`, application as an atom:
#   using :'Elixir.Req' from :req { ... }
# The foreign node gains a fifth element (App | none).
patch(W + '/a/bs_parser.yrl', lambda s: s.replace(OLD,
"foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :\n    {foreign, line('$1'), value('$2'), '$4', none}.\n"
"foreign_decl -> 'using' atom_lit lident atom_lit '{' foreign_sigs '}' :\n"
"    from_kw('$3'),\n    {foreign, line('$1'), value('$2'), '$6', value('$4')}.")
  .replace("Erlang code.\n", "Erlang code.\n\nfrom_kw({lident, _, from}) -> ok;\n"
"from_kw({lident, L, W}) -> return_error(L, \"expected `from`, found `\" ++ atom_to_list(W) ++ \"`\").\n", 1))

# Option B -- per module, a declaration of its own, contextual word:  requires :req
patch(W + '/b/bs_parser.yrl', lambda s: s.replace("decl -> using_decl  : '$1'.",
"decl -> using_decl  : '$1'.\ndecl -> lident atom_lit : requires_kw('$1'), {requires, line('$1'), value('$2')}.")
  .replace("Erlang code.\n", "Erlang code.\n\nrequires_kw({lident, _, requires}) -> ok;\n"
"requires_kw({lident, L, W}) -> return_error(L, \"unknown declaration `\" ++ atom_to_list(W) ++ \"`\").\n", 1))

# Option B with a reserved keyword instead of a contextual word
patch(W + '/bk/bs_parser.yrl', lambda s: s.replace("decl -> using_decl  : '$1'.",
"decl -> using_decl  : '$1'.\ndecl -> 'requires' atom_lit : {requires, line('$1'), value('$2')}.")
  .replace("'module' 'type' 'when' 'using'", "'module' 'type' 'when' 'using' 'requires'", 1))
patch(W + '/bk/bs_lexer.xrl', lambda s: s.replace("using                   : {token, {'using', TokenLoc}}.",
"using                   : {token, {'using', TokenLoc}}.\nrequires                : {token, {'requires', TokenLoc}}."))
