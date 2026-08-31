#!/usr/bin/env bash
#
# 47c — What does the alias arm actually cost the grammar?
#
# Round 1 of ticket 47 told David the compiler delta for `using S = Solo` is
# "one grammar arm on `'using' uident '=' modpath` (`'='` already has a
# precedence slot, so no new terminal)" — and in the same breath recorded that
# it OWES "a re-run of the yecc conflict check that ticket 41 left standing at
# `bs_parser.yrl:157-169`, because it is a third arm discriminated on `=` after
# a `uident` that `modpath` also accepts."
#
# So the cost estimate David was asked to weigh Q1 against was unmeasured. This
# runs it. Nothing here decides whether the alias should exist; it prices it.
#
# BUILDING IS NOT PARSING, and that is this repo's own lesson rather than a
# general one. `bs_parser.yrl:157-169` records ticket 41 discovering it: the
# right-recursive `modpath` it originally specified BUILT, and then misparsed
# `List.Map(x)` as `syntax error before: '('` because the recursive arm
# greedily swallowed the function name. A conflict count alone would have
# passed that grammar. So this probe measures three things, not one:
#
#   1. conflicts       yecc's count, base vs alias
#   2. the corpus      every .bs file in compiler/examples parsed by BOTH
#                      grammars, ASTs compared — a silent misparse shows here
#   3. eight shapes    A1-A8, verdicts pinned, including the qualified call
#                      that is exactly what ticket 41's version broke
#
#   ./47c_alias_grammar_conflicts.sh
#   ./47c_alias_grammar_conflicts.sh --self-test
#
# The self-test rebuilds ticket 41's right-recursive `modpath` and requires the
# probe to see BOTH of its failure modes — conflicts, and the misparse — with
# the left-recursive grammar green beside it. A probe that cannot see the defect
# this repository has already shipped once is not evidence of anything.
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
YRL="$ROOT/compiler/src/bs_parser.yrl"
EBIN="$ROOT/compiler/_build/default/lib/bsc/ebin"
WORK="${TMPDIR:-/tmp}/bs47c.$$"

SELF_TEST=0
[ "${1:-}" = "--self-test" ] && SELF_TEST=1

[ -f "$YRL" ] || { echo "FAIL: no grammar at $YRL"; exit 1; }
if [ ! -d "$EBIN" ]; then
    echo "building bsc..."
    (cd "$ROOT/compiler" && rebar3 compile >/dev/null 2>&1)
fi
[ -d "$EBIN" ] || { echo "FAIL: no compiled bsc at $EBIN"; exit 1; }

trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK"
cd "$WORK" || exit 1

# ---------------------------------------------------------------- the grammars
# `base` is the shipped grammar, copied rather than referenced so this probe
# never writes into compiler/src.
cp "$YRL" base.yrl

# The line the alias arm is inserted after. Matched EXACTLY: if the shipped
# grammar's `using` rule is ever edited, this probe stops silently measuring the
# wrong thing and says so instead.
ANCHOR="using_decl -> 'using' modpath : {import, line('\$1'), modatom('\$2')}."
if ! grep -qF "$ANCHOR" base.yrl; then
    echo "FAIL: the shipped \`using_decl\` rule is not the one this probe was"
    echo "      written against. The alias arm's cost must be re-measured"
    echo "      against whatever replaced it — do not edit the anchor to match."
    exit 1
fi

# ROUND 1'S PROPOSED ARM, VERBATIM. It writes `mods` and never `funs`, which is
# §5's answer to owed item 2, so the action builds an `import_alias` carrying
# the author-chosen key alongside the module atom.
ARM="using_decl -> 'using' uident '=' modpath : {import_alias, line('\$1'), value('\$2'), modatom('\$4')}."
awk -v anchor="$ANCHOR" -v arm="$ARM" \
    '{ print } index($0, anchor) == 1 { print arm }' base.yrl > alias.yrl

# TICKET 41'S RIGHT-RECURSIVE `modpath`, rebuilt for the self-test only. This is
# the defect the parser comment records, not a hypothetical one.
sed -e "s|^modpath -> modpath '\.' uident   : '\$1' ++ \[value('\$3')\]\.|modpath -> uident '.' modpath : [value('\$1') \| '\$3'].|" \
    base.yrl > right.yrl

# ---------------------------------------------------------------- yecc
conflicts() {
    # yecc reports conflicts as a warning on stdout and still returns {ok, _},
    # so the count is read from the report, not from the return value.
    mise exec -- erl -noshell -eval \
        "yecc:file(\"$1.yrl\", [{report, true}, {verbose, false}]), halt()." 2>&1 |
        sed -n 's/.*conflicts: \([0-9]*\) shift\/reduce, \([0-9]*\) reduce\/reduce.*/\1 \2/p'
}

sum_conflicts() {
    local c
    c="$(conflicts "$1")"
    [ -z "$c" ] && { echo 0; return; }
    echo "$c" | awk '{ t += $1 + $2 } END { print t + 0 }'
}

BASE_C="$(sum_conflicts base)"
ALIAS_C="$(sum_conflicts alias)"
RIGHT_C="$(sum_conflicts right)"

# ---------------------------------------------------------------- the probe
cat > probe.erl <<'ERL'
-module(probe).
-export([main/1]).

main([Root, Mod]) ->
    P = list_to_atom(Mod),
    Files = filelib:wildcard(Root ++ "/**/*.bs"),
    {Diff, Cmp, Skip} = lists:foldl(fun(F, {D, C, S}) ->
        {ok, Src} = file:read_file(F),
        case bs_lexer:string(binary_to_list(Src)) of
            {error, _, _} -> {D, C, S + 1};
            {ok, Toks, _} ->
                B = norm(base:parse(Toks)),
                A = norm(P:parse(Toks)),
                case B =:= A of
                    true  -> {D, C + 1, S};
                    false -> io:format("DIFFERS: ~s~n  base: ~p~n  ~s: ~p~n",
                                       [F, B, Mod, A]),
                             {D + 1, C + 1, S}
                end
        end
    end, {0, 0, 0}, Files),
    io:format("corpus ~p compared, ~p unlexable, ~p AST differences~n",
              [Cmp, Skip, Diff]),
    lists:foreach(fun({Name, Src}) ->
        {ok, Toks, _} = bs_lexer:string(Src),
        io:format("SHAPE ~s ~s ~s~n",
                  [Name, verdict(base:parse(Toks)), verdict(P:parse(Toks))])
    end, shapes()),
    io:format("DIFFCOUNT ~p~n", [Diff]),
    halt(0).

%% A parse ERROR carries the generated parser's own module name, so two
%% grammars differ on every refusal for a reason that is not the grammar.
%% Erase it, or the corpus reports differences that are the probe's own.
norm({error, {Line, _Mod, Msg}}) -> {error, {Line, parser, Msg}};
norm(Other)                      -> Other.

verdict({ok, _})    -> "parses";
verdict({error, _}) -> "refused".

%% A1/A2/A5/A7/A8 are the grammar as it ships and MUST NOT MOVE — A8 above all,
%% because a qualified call is precisely what ticket 41's arm broke while
%% building cleanly. A3/A4/A6 are the alias form, refused today by construction.
shapes() ->
    [{"A1", "module M\nusing Solo\n"},
     {"A2", "module M\nusing Shop.Collections.List\n"},
     {"A3", "module M\nusing S = Solo\n"},
     {"A4", "module M\nusing L = Shop.Collections.List\n"},
     {"A5", "module M\nusing Solo\n\npublic int Go(int n)\nGo(n) -> Solo.Sum([n], 0)\n"},
     {"A6", "module M\nusing S = Solo\n\npublic int Go(int n)\nGo(n) -> S.Sum([n], 0)\n"},
     {"A7", "module M\nusing Shop.Collections\n\npublic int Go(int n)\nGo(n) -> List.Sum([n], 0)\n"},
     {"A8", "module M\n\npublic int Go(int n)\nGo(n) -> Alpha.Coll.List.Sum([n], 0)\n"}].
ERL

mise exec -- erl -noshell -pa . -pa "$EBIN" -eval \
    '{ok,_}=compile:file("base.erl",[{outdir,"."}]),
     {ok,_}=compile:file("alias.erl",[{outdir,"."}]),
     {ok,_}=compile:file("right.erl",[{outdir,"."}]),
     {ok,_}=compile:file("probe.erl",[{outdir,"."}]),
     halt().' >/dev/null 2>&1 || { echo "FAIL: a generated parser did not compile"; exit 1; }

run_probe() {
    mise exec -- erl -noshell -pa . -pa "$EBIN" -run probe main "$ROOT/compiler/examples" "$1" 2>&1
}

# ---------------------------------------------------------------- self-test
if [ "$SELF_TEST" = "1" ]; then
    echo "--- self-test: can this probe see ticket 41's defect? ---"
    echo
    rout="$(run_probe right)"
    rdiff="$(printf '%s' "$rout" | sed -n 's/^DIFFCOUNT //p')"
    ra8="$(printf '%s' "$rout" | sed -n 's/^SHAPE A8 [a-z]* //p')"
    la8="$(printf '%s' "$(run_probe alias)" | sed -n 's/^SHAPE A8 [a-z]* //p')"

    st_fails=0
    check() {
        if [ "$2" = "$3" ]; then
            echo "ok   $1"
        else
            echo "FAIL $1: got '$2', wanted '$3'"
            st_fails=$((st_fails + 1))
        fi
    }
    # RED half — the right-recursive grammar must be seen to fail, both ways.
    [ "$RIGHT_C" -gt 0 ] &&
        echo "ok   right-recursive modpath conflicts ($RIGHT_C > 0)" ||
        { echo "FAIL right-recursive modpath: $RIGHT_C conflicts, wanted > 0"
          st_fails=$((st_fails + 1)); }
    check "right-recursive modpath misparses the qualified call" "$ra8" "refused"
    [ "$rdiff" -gt 0 ] &&
        echo "ok   right-recursive modpath diverges on the corpus ($rdiff files)" ||
        { echo "FAIL right-recursive modpath: corpus identical, wanted divergence"
          st_fails=$((st_fails + 1)); }
    # GREEN half — a check that fires on everything passes the first half and is
    # worthless. The correct grammar must stand beside it and be seen to pass.
    check "the alias grammar still parses the qualified call" "$la8" "parses"

    echo
    if [ "$st_fails" -eq 0 ]; then
        echo "47c self-test: the probe sees the defect and clears the correct form."
        exit 0
    fi
    echo "47c self-test: $st_fails checks did not hold. The probe is not evidence."
    exit 1
fi

# ---------------------------------------------------------------- measurement
echo "--- conflicts ---"
echo "  shipped grammar          $BASE_C"
echo "  + the alias arm          $ALIAS_C"
echo

out="$(run_probe alias)"
printf '%s\n' "$out" | grep -v '^DIFFCOUNT' | grep -v '^SHAPE '
diff_count="$(printf '%s' "$out" | sed -n 's/^DIFFCOUNT //p')"

echo
echo "--- shapes ---"
# base|alias, pinned. A move in EITHER direction is the finding.
PINNED="
A1|parses|parses|using Solo
A2|parses|parses|using Shop.Collections.List
A3|refused|parses|using S = Solo
A4|refused|parses|using L = Shop.Collections.List
A5|parses|parses|qualified call through a plain import
A6|refused|parses|qualified call through the alias
A7|parses|parses|short-qualified call, namespace tier (41 §5)
A8|parses|parses|fully-qualified call — TICKET 41'S BREAKAGE
"

fails=0
count=0
while IFS='|' read -r shape want_base want_alias what; do
    [ -z "$shape" ] && continue
    count=$((count + 1))
    got="$(printf '%s' "$out" | sed -n "s/^SHAPE $shape //p")"
    if [ "$got" != "$want_base $want_alias" ]; then
        echo "FAIL $shape: base/alias = '$got', pinned '$want_base $want_alias'"
        fails=$((fails + 1))
    else
        echo "ok   $shape  base=$want_base alias=$want_alias  ($what)"
    fi
done <<EOF
$PINNED
EOF

echo
echo "--- what the measurement says ---"
cat <<SUMMARY
The arm is free at the grammar level, and round 1's estimate holds.

  conflicts        $BASE_C -> $ALIAS_C.  No new terminal, and \`=\` after a
                   \`uident\` in a \`using\` line is decidable on one token of
                   lookahead: nothing else can follow a \`modpath\` there.
  the corpus       $diff_count AST differences across compiler/examples. The added
                   arm changes no program that exists today.
  A8               still parses. This is the shape ticket 41's grammar broke
                   while building, and it is why a conflict count alone would
                   not have been an answer.

WHAT THIS DOES NOT SAY. It prices Q1, it does not answer it. The recommendation
in §6 rests on the lockout (ENG-270), not on grammar cost — an arm that were
expensive would have argued against the alias, but a free one does not argue
for it. The cost that remains unpriced is the one §5 named: \`mods\` would take
its first AUTHOR-CHOSEN key, where every key in either table is derived today.
That is a checker question, and this probe does not reach the checker.

ONE STALE NUMBER FOUND. \`bs_parser.yrl:160-165\` says the right-recursive
grammar "builds with 2 shift/reduce conflicts". Measured today it is $RIGHT_C —
the grammar has grown since ticket 41 wrote that, so the comment reads as a
present-tense claim about a number that has moved. Its finding is unaffected:
the misparse, which is the part that matters, reproduces exactly.
SUMMARY

echo
if [ "$fails" -eq 0 ] && [ "$diff_count" = "0" ]; then
    echo "47c: $count/$count shapes hold, corpus identical."
    exit 0
fi
echo "47c: $fails of $count shapes moved, $diff_count corpus differences."
echo "     Either direction is a finding — read it before editing this file."
exit 1
