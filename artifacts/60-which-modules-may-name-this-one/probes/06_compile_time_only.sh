#!/bin/bash
# (e) Does anything survive into the .beam? Compile the SAME Rules module with (prototype) and
#     without (baseline HEAD build /tmp/c60) the `within` line; compare the files; then call the
#     restricted function from plain Erlang, outside any B# check.
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
PROTO=/tmp/c60a/_build/default/bin/bsc
BASE=/tmp/c60/_build/default/bin/bsc
rm -rf /tmp/t60d /tmp/o60_plain /tmp/o60_within && cp -r "$HERE/tree" /tmp/t60d && cd /tmp/t60d
echo "## baseline: Rules WITHOUT within, HEAD compiler"
$BASE -o /tmp/o60_x --src-root . Acme/Orders/Rules; echo "exit=$?"
# FIRST RUN (kept in 06_first_run_lines_shifted.out): the plain file had no extra line, so the within version
# had every line number one greater; the beams differed by 4 bytes. That is a line-number difference, not a
# marker. To test the marker and not the line shift, the baseline is rebuilt with a COMMENT on the line `within` occupies.
sed -i 's/^module Acme.Orders.Rules$/module Acme.Orders.Rules\n\/\/ within Acme.Orders/' Acme/Orders/Rules/Rules.bs
rm -rf /tmp/o60_x; echo "## baseline v2: same line count, the line is a comment"
$BASE -o /tmp/o60_x --src-root . Acme/Orders/Rules; echo "exit=$?"
sed -i 's/^\/\/ within Acme.Orders$/within Acme.Orders/' Acme/Orders/Rules/Rules.bs
cp /tmp/o60_x/Acme.Orders.Rules.beam /tmp/plain.beam; rm -rf /tmp/o60_x
# SECOND RUN (kept in 06_second_run_outdir_differs.out): still 4 bytes apart; all chunks equal except CInf, which
# records the OUTPUT DIRECTORY name (o60_plain vs o60_within). Both builds now use one directory name.
echo "## prototype: Rules WITH within"
$PROTO -o /tmp/o60_x --src-root . Acme/Orders/Rules; echo "exit=$?"
cp /tmp/o60_x/Acme.Orders.Rules.beam /tmp/within.beam; ls -l /tmp/plain.beam /tmp/within.beam
echo "## byte comparison"
cmp /tmp/plain.beam /tmp/within.beam && echo IDENTICAL
echo "## chunks of the restricted module (attributes, exports) from the prototype build"
erl -noshell -eval '
 {ok,{_,[{attributes,A},{exports,E}]}} = beam_lib:chunks("/tmp/within.beam",[attributes,exports]),
 io:format("attributes=~p~nexports=~p~n",[A,E]), halt().'
echo
echo "## and an ordinary Erlang module that sits OUTSIDE the subtree calls it at run time (a compiled caller; no B# checker involved)"
cat > /tmp/outsider.erl <<'EOT'
-module(outsider).
-export([go/0]).
go() -> 'Acme.Orders.Rules':'Recompute'([10, 20, 30]).
EOT
erlc -o /tmp /tmp/outsider.erl && erl -noshell -pa /tmp -pa /tmp/o60_x -eval 'io:format("outsider:go() = ~p~n",[outsider:go()]), halt().'
echo
echo "## and the REPL-style apply, no source at all:"
erl -noshell -pa /tmp/o60_x -eval 'io:format("~p~n",[apply(list_to_atom("Acme.Orders.Rules"), list_to_atom("Recompute"), [[1,2,3]])]), halt().'
