#!/usr/bin/env bash
# Probe 15: blast radius of candidate 3 (snake_case functions): how much written B# names a function in PascalCase.
cd /home/user/beam-sharp
echo ".bs files under compiler/ excluding _build (examples, exemplars, fixtures): $(find compiler -path compiler/_build -prune -o -name '*.bs' -print | wc -l)"
echo "function-clause heads/decls  (line starts with an UpperIdent then '('): $(grep -rhE '^(public |private )?[A-Za-z<>(), ?]* ?[A-Z][A-Za-z0-9_]*\(' --include=*.bs --exclude-dir=_build compiler | wc -l)"
echo "  of which 'public' declarations: $(grep -rhE '^public .*[A-Z][A-Za-z0-9_]*\(' --include=*.bs --exclude-dir=_build compiler | wc -l)"
echo "all PascalCase-call tokens '[A-Z]ident(' in .bs: $(grep -rhoE '\b[A-Z][A-Za-z0-9_]*\(' --include=*.bs --exclude-dir=_build compiler | wc -l)"
echo "wayfinder tickets mentioning PascalCase: $(grep -l PascalCase wayfinder/issues/*.md | wc -l) of $(ls wayfinder/issues/*.md | wc -l)"
echo "LANGUAGE.md lines: $(wc -l < LANGUAGE.md); code-fence lines containing 'Name(' : $(grep -cE '^[A-Z][A-Za-z0-9_]*\(' LANGUAGE.md)"
echo "--- the lexer rule that tells a function from a type/variable with no symbol table:"
grep -nE '^\{(UPPER|LOWER)\}\{ALNUM\}\*' compiler/src/bs_lexer.xrl
echo "--- bs_otp lowers callbacks by a hand table, not a rule (bs_otp.erl header):"
sed -n 6,8p compiler/src/bs_otp.erl
