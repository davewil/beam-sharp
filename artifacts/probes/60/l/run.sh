#!/usr/bin/env bash
# 60/l : the ticket's premises about the checker, re-measured at the current HEAD.
repo=$(cd "$(dirname "$0")/../../../.." && pwd); cd "$repo"
echo "HEAD: $(git log --oneline -1)"
echo "== commit 0b761f6 (cited by the ticket) reachable?"; git cat-file -t 0b761f6 2>&1 | head -1
echo "== internal/friend/sealed/visible_to in compiler/src (excluding generated parser):"
grep -n -w "internal\|friend\|sealed\|visible_to" compiler/src/*.erl compiler/src/*.yrl compiler/src/*.xrl | grep -v "^compiler/src/bs_parser.erl" | grep -v "^\S*:[0-9]*:\s*%%" | head
echo "== add_module_import and its caller now:"
grep -n "^add_import\|^add_module_import\|^add_namespace_import\|add_module_import(M, World, Acc)" compiler/src/bs_check.erl
sed -n 512,514p compiler/src/bs_check.erl
echo "== readers of the visibility field (a third marker must touch each):"
grep -n "V =/= public\|V =:= public\|=:= public" compiler/src/bs_check.erl compiler/src/bs_emit.erl compiler/src/bs_api.erl | grep -v "^\S*:[0-9]*:\s*%%"
echo '== lexer token rules (keywords and punctuation together):'; grep -c "TokenLoc}}\.$" compiler/src/bs_lexer.xrl
echo "== any .bs in the repo (outside artifacts/) using internal/within/friend as a word:"; grep -rnw "internal\|within\|friend" --include=*.bs . | grep -v "^./artifacts" | wc -l
