#!/usr/bin/env bash
# CLAIM (ticket 60 text): "add_module_import/5 reads only the callee's export set (bs_check.erl:407-425) at 0b761f6";
#       "no internal/friend/sealed/visible_to anywhere in the checker".
# REFUTED IF: add_module_import is /5 at HEAD and sits at 407-425; or the grep below finds a visibility keyword
#       in the checker/parser/lexer/LANGUAGE.md; or 0b761f6 resolves to a commit.
# CONTROL: the same grep for `private` must find hits (a grep that finds nothing proves nothing).
. "$(dirname "$0")/env.sh"; cd "$REPO"
echo "--- HEAD: $(git rev-parse --short HEAD); 0b761f6 resolves? ->" $(git cat-file -t 0b761f6 2>&1)
echo "--- definition and call sites of add_module_import:"
grep -n 'add_module_import' compiler/src/bs_check.erl
echo "--- body (arity = number of params in the head):"
sed -n '/^add_module_import(/,/^$/p' compiler/src/bs_check.erl
echo "--- keyword grep (expect: no hits for internal|friend|sealed|visible_to as VISIBILITY; list all hits):"
grep -nwiE 'internal|friend|sealed|visible_to|visibleto' compiler/src/*.erl compiler/src/*.yrl compiler/src/*.xrl LANGUAGE.md | grep -v erl_internal
echo "--- control: private hits in parser/lexer:"; grep -cw 'private' compiler/src/bs_parser.yrl compiler/src/bs_lexer.xrl 2>/dev/null
echo "--- does add_module_import receive the caller (Self)? params:"; grep -n '^add_module_import\|^add_import' compiler/src/bs_check.erl
