# builds var/{base,g1,g1c,g2}.yrl from the REAL compiler/src/bs_parser.yrl (never edits the repo)
import sys
s=open(sys.argv[1]).read()
base="refinement -> expr_low : '$1'."
assert base in s
g1="""refinement -> ref_or : '$1'.
ref_or -> ref_or 'or' ref_and : {e_op, line('$2'), 'or', '$1', '$3'}.
ref_or -> ref_and : '$1'.
ref_and -> ref_and 'and' ref_cmp : {e_op, line('$2'), 'and', '$1', '$3'}.
ref_and -> ref_cmp : '$1'.
ref_cmp -> lident ref_op int_lit : {e_op, line('$2'), element(1,'$2'), {e_var, line('$1'), value('$1')}, {e_int, line('$2'), '$3'}}.
ref_cmp -> int_lit ref_op lident : {e_op, line('$2'), element(1,'$2'), {e_int, line('$2'), '$1'}, {e_var, line('$3'), value('$3')}}.
ref_cmp -> '(' ref_or ')' : '$2'.
ref_op -> '==' : '$1'. ref_op -> '!=' : '$1'. ref_op -> '<' : '$1'. ref_op -> '>' : '$1'. ref_op -> '<=' : '$1'. ref_op -> '>=' : '$1'."""
g1s=s.replace(base,g1).replace(" rel_pattern rel_test int_lit refinement\n"," rel_pattern rel_test int_lit refinement ref_or ref_and ref_cmp ref_op\n")
assert 'ref_op\n' in g1s.split('Terminals')[0]
g1c=s.replace("expr_low -> '-' expr_low : negate(line('$1'), '$2').","expr_low -> '-' expr_low : negate(line('$1'), '$2').\nexpr_low -> '-' integer : {e_int, line('$1'), -value('$2')}.")
g2=s.replace("negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};","negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};\nnegate(_L, {e_int, IL, N}) -> {e_int, IL, -N};")
assert g1c!=s and g2!=s
for n,t in [('base',s),('g1',g1s),('g1c',g1c),('g2',g2)]: open('var/%s.yrl'%n,'w').write(t)
