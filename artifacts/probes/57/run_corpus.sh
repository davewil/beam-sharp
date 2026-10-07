#!/usr/bin/env bash
# Which constant shapes appear after a comparison operator in guards/refinements of the existing corpus?
cd /home/user/beam-sharp/compiler
echo "--- negative literal after comparison, in .bs examples/ (not tests):"
grep -rnE '(>=|<=|>|<|==|!=) *-[0-9]' examples --include=*.bs | grep -v '^\S*:[0-9]*:\s*//' 
echo "--- same in test/*.erl embedded sources:"
grep -rnE '(>=|<=|>|<|==|!=) *-[0-9]' test | head -40
echo "--- binary arithmetic of two int literals after a comparison (2+3, 0-5):"
grep -rnE '(>=|<=|>|<|==|!=) *\(?[0-9]+ *[-+*/%] *[0-9]+' examples test --include=*.bs --include=*.erl | head
echo "--- double negation / -(:"
grep -rnE '(>=|<=|>|<|==|!=) *-\(' examples test | head
echo "--- negative literal in relational PATTERNS (<= -1) in examples:"
grep -rnE '\((<=|>=|<|>) *-[0-9]' examples --include=*.bs | head
echo "--- counts: refinements total / with arithmetic comparand"
grep -rhE 'where value' examples test | wc -l
