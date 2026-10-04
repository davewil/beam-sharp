#!/bin/bash
# Verifies the file:line citations in ticket 60 / 22 at HEAD, and enumerates the sites a per-function
# marker (option C) would touch. Option C was NOT prototyped; this is a reading, stated as such in the brief.
cd /home/user/beam-sharp
echo "HEAD: $(git rev-parse --short HEAD)   (ticket cites 0b761f6: $(git cat-file -t 0b761f6 2>&1 | head -1))"
echo
echo "## ticket 60: 'add_module_import/5 ... bs_check.erl:407-425'"
echo "-- lines 407-425 at HEAD:"; sed -n 407,425p compiler/src/bs_check.erl | cut -c1-90 | sed -n '1,4p;$p'
echo "-- where add_module_import actually is:"; grep -n "^add_module_import\|add_module_import(" compiler/src/bs_check.erl
echo "-- its arity: $(grep -n '^add_module_import(' compiler/src/bs_check.erl)"
echo
echo "## ticket 22: 'bs_parser.yrl:262-268' (public/private) and 'bs_check.erl:43'"
sed -n 262,268p compiler/src/bs_parser.yrl | cut -c1-90
echo "-- visibility productions at HEAD:"; grep -n "^visibility ->" compiler/src/bs_parser.yrl
echo "-- default visibility field at HEAD:"; grep -n "vis = private" compiler/src/bs_check.erl
echo
echo "## the cited claim itself (reads only the callee's export set; no internal/friend/sealed/visible_to) -- still TRUE:"
awk '/^add_module_import\(M, World, Acc\)/,/^add_namespace_import/' compiler/src/bs_check.erl | grep -c "maps:get(exports"
grep -n -i -w -E "friend|sealed|visible_to" compiler/src/*.erl compiler/src/*.yrl compiler/src/*.xrl | grep -v "^compiler/src/bs_\(parser\|lexer\).erl" | head -3
echo "(no output above = none)"
echo
echo "## option C (per-function marker) -- every reader of the visibility value, and the two call-site refusals:"
grep -n -E "V =:= public|V =/= public|=:= public|is_public|vis = " compiler/src/bs_check.erl compiler/src/bs_emit.erl | cut -c1-120
echo "-- private_function raised at:"; grep -n "{private_function," compiler/src/bs_check.erl | cut -c1-110
echo "-- ctx fields available at those sites (does the ctx know the calling module?):"
sed -n '/^-record(ctx/,/\.$/p' compiler/src/bs_check.erl | tr -s ' \n' ' ' | cut -c1-400; echo
grep -c "module" <(sed -n '/^-record(ctx/,/^$/p' compiler/src/bs_check.erl) 
