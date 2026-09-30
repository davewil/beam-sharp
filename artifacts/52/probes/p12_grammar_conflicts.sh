#!/usr/bin/env bash
# p12: what does each candidate spelling cost the grammar?  yecc on SCRATCH COPIES of compiler/src/bs_parser.yrl;
# the repo's file is never edited.  Reports yecc's own conflict line.  (Baseline is this machine's OTP 25 yecc.)
R=/home/user/beam-sharp/compiler/src/bs_parser.yrl
D=$(mktemp -d)
run() { # name, extra-terminals-sed, production-block
  cp $R $D/$1.yrl
  [ -n "$2" ] && sed -i "$2" $D/$1.yrl
  # productions must go BEFORE the `Erlang code.` section or yecc reads them as Erlang (first run of this probe
  # did that and every variant printed the baseline count: see p12_grammar_conflicts.first_run_vacuous.out)
  [ -n "$3" ] && awk -v add="$3" '/^Erlang code\./ && !done { print add; print ""; done=1 } { print }' $D/$1.yrl > $D/$1.tmp && mv $D/$1.tmp $D/$1.yrl
  printf '%-34s ' "$1"
  erl -noshell -eval 'R=yecc:file("'$D/$1.yrl'",[{parserfile,"'$D/$1'.erl"},{verbose,false}]), io:format("~p~n",[element(1,R)]),halt().' 2>&1 | tr '\n' ' '; echo
}
echo "yecc output per variant (a 'Warning: conflicts' line appears whenever the count is not zero):"
run baseline '' ''
run B_in_atom_per_block '' "foreign_decl -> 'using' atom_lit 'in' atom_lit '{' foreign_sigs '}' : {foreign, line('\$1'), value('\$2'), value('\$4'), '\$6'}."
run C_using_app_line "s/^  'module' 'type'/  'app' 'module' 'type'/" "decl -> 'using' 'app' atom_lit : {requires, line('\$1'), value('\$3')}."
run C2_bare_using_atom '' "decl -> 'using' atom_lit : {requires, line('\$1'), value('\$2')}."
run D_attribute_before_using '' "foreign_decl -> '[' lident ':' lident ']' 'using' atom_lit '{' foreign_sigs '}' : {foreign, line('\$6'), value('\$7'), value('\$4'), '\$9'}."
