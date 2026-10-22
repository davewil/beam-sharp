#!/usr/bin/env bash
# Probe 09: (1) every site in the repo compiler that a scoped marker (Option B) or an import-time
# rule (Options A/C) has to touch, by grep; (2) text-prefix vs segment-prefix on dotted module atoms.
HERE=$(cd "$(dirname "$0")" && pwd); C=$(cd "$HERE/../../../compiler/src" && pwd)
echo "--- 1a. readers of the visibility field (a {public,Scope} encoding must be taught to ALL of these):"
grep -n '=:= public\|, public, \|V =:= public' $C/*.erl
echo "--- 1b. the single import choke point, and the 'qualified calls need using' rule:"
grep -n '^add_import\|^add_module_import\|^qualified_module\|^require_imported\|Qualified calls still require' $C/bs_check.erl
echo "--- 1c. existing segment-aware prefix helper (note the appended \".\"):"
sed -n '/^children(Prefix, Known)/,/^$/p' $C/bs_check.erl
echo "--- 1d. diagnostics: bs_diag has no catch-all message/1 clause (a new error tag without a clause crashes):"
grep -n '^message(_\|^message(D\b' $C/bs_diag.erl | head -3; echo "(no output above = no catch-all)"
echo "--- 1e. 'to' as a keyword would steal an identifier already used in the exemplar corpus:"
grep -rn -w 'pid to' $HERE/../../../compiler/examples --include=*.bs
echo "--- 2. text prefix vs segment prefix"
erl -noshell -eval '
Parent = "Shop.Orders", Importer = "Shop.OrdersExtra",
io:format("text prefix   lists:prefix(~p,~p) = ~p   (WRONG: admits Shop.OrdersExtra)~n",[Parent,Importer,lists:prefix(Parent,Importer)]),
Seg = fun(S) -> string:split(S, ".", all) end,
io:format("segment prefix lists:prefix(~p,~p) = ~p~n",[Seg(Parent),Seg(Importer),lists:prefix(Seg(Parent),Seg(Importer))]),
halt().'
