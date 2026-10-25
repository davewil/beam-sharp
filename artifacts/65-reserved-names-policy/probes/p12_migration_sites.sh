#!/usr/bin/env bash
# P12: how many source sites option 2 would rewrite: reserved-qualifier calls (List.|Map.|Term.|Float. + Capital + `(`) in .bs files, tests and docs.
cd /home/user/beam-sharp
pat='\b(List|Map|Term|Float)\.[A-Z][A-Za-z]*\('
echo ".bs files (excl _build):  $(grep -rEo "$pat" --include=*.bs --exclude-dir=_build . | wc -l) sites in $(grep -rlE "$pat" --include=*.bs --exclude-dir=_build . | wc -l) files"
echo "compiler/test/*.erl:     $(grep -Eo "$pat" compiler/test/*.erl | wc -l) sites in $(grep -lE "$pat" compiler/test/*.erl | wc -l) files"
echo "LANGUAGE.md + CONTEXT.md: $(grep -Eo "$pat" LANGUAGE.md CONTEXT.md | wc -l) sites"
echo "wayfinder/*.md:          $(grep -rEo "$pat" wayfinder --include=*.md | wc -l) sites"
