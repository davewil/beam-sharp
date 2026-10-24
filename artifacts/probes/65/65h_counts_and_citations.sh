#!/usr/bin/env bash
# PROBE 65h — every count, date and line number the brief quotes, from the command that produces it.
# Reads the working tree and git history. It runs no compiler. Needs full history (not a shallow clone).
#
#   bash artifacts/probes/65/65h_counts_and_citations.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
[ "$(git rev-parse --is-shallow-repository)" = false ] || { echo "REFUSED: shallow clone"; exit 2; }
CALLRE='\b(List|Map|Term|Float)\.[A-Z][A-Za-z]*\('
ROSTER='String|Enum|Int|Binary|Process|GenServer|Supervisor|Logger|System|Task|Agent'   # the ten narrow names + Binary
RESERVED='List|Map|Term|Float|Enumerable'
echo "HEAD: $(git rev-parse --short HEAD) $(git log -1 --format=%cs)"
echo "== history"
echo "commits touching compiler/src/bs_check.erl:        $(git rev-list --count HEAD -- compiler/src/bs_check.erl)"
echo "commits in the whole repository:                  $(git rev-list --count HEAD)"
echo "== files"
echo ".bs files tracked by git:                            $(git ls-files '*.bs' | wc -l)"
echo "== where the reserved set and its rows live (bs_check.erl)"
grep -n '^reserved_qualifiers() ->\|^standard_table() ->\|^declared_rows() ->\|^reserved_module_name(\|^stratum_two() ->\|^compiler_known_redeclared(\|^compiler_known_function(\|^reserved_call(\|^protocol_table() ->' compiler/src/bs_check.erl | sed 's/^/   bs_check.erl:/'
grep -n 'lists:member(Mod, bs_check:reserved_qualifiers())' compiler/src/bs_emit.erl | sed 's/^/   bs_emit.erl:/'
echo "   standard rows at HEAD (standard_table + declared_rows keys): $(grep -E -o "\{\{?'(List|Map|Term|Float)', *'[A-Za-z]+', *[0-9]\}" compiler/src/bs_check.erl | sed -E "s/^\{+//; s/\}$//" | sort -u | wc -l)"
echo "== call sites of the reserved qualifiers, regex  $CALLRE  (what an 'unreachable namespace' would rewrite)"
echo "   .bs files:      $(git ls-files '*.bs' | xargs grep -Eoh "$CALLRE" | wc -l) calls in $(git ls-files '*.bs' | xargs grep -lE "$CALLRE" | wc -l) files"
echo "   eunit sources:  $(git ls-files 'compiler/test/*' | xargs grep -Eoh "$CALLRE" | wc -l) calls in $(git ls-files 'compiler/test/*' | xargs grep -lE "$CALLRE" | wc -l) files"
for f in LANGUAGE.md TOUR.md STANDARD-ENVIRONMENT.md; do echo "   $f: $(grep -Eoh "$CALLRE" $f | wc -l) calls"; done
echo "   features:       $(git ls-files 'compiler/features/*' | xargs grep -Eoh "$CALLRE" | wc -l) calls"
echo "   tickets:        $(git ls-files 'wayfinder/issues/*' | xargs grep -Eoh "$CALLRE" | wc -l) mentions"
echo "== planned roster: collisions and uses in tracked .bs files"
echo "   WHOLE module name is a roster word:   $(git ls-files '*.bs' | xargs grep -hE "^module ($ROSTER)\$" | wc -l)"
echo "   LAST segment is a roster word:        $(git ls-files '*.bs' | xargs grep -hE "^module [A-Za-z0-9_.]+\.($ROSTER)\$" | wc -l)"
echo "   Roster.Op( calls:                     $(git ls-files '*.bs' | xargs grep -Eoh "\b($ROSTER)\.[A-Z][A-Za-z]*\(" | sort | uniq -c | tr '\n' ' ')"
git ls-files '*.bs' | xargs grep -lE "\b($ROSTER)\.[A-Z][A-Za-z]*\(" | sed 's/^/      in /'
echo "   other module names in the tree that look like standard modules: $(git ls-files '*.bs' | xargs grep -hE '^module (Stream|Json|Req|Queue|Stats)$' | sort | uniq -c | tr '\n' ' ')"
echo "   eunit inline programs declaring a module named after an ALREADY-reserved word:"
grep -nE "module ($RESERVED)\\\\n" compiler/test/*.erl | sed 's/^/      /' | cut -c1-110
echo "   eunit inline programs declaring a module named after any of the ten narrow names or Binary (a whole-name declaration, \"module X\\n\"): $(grep -cE "module ($ROSTER)\\\\n" compiler/test/*.erl | awk -F: '{n+=$2} END{print n+0}')"
echo "   (the eunit SUITE was not run with the roster delta by this probe; see 65i)"
echo "== dates"
echo "   protocol_table (Enumerable) first appears: $(git log -S'protocol_table() ->' --format='%h %cs' -- compiler/src/bs_check.erl | tail -1)"
echo "   Float first reserved:                      $(git log -S"'Float'" --format='%h %cs' -- compiler/src/bs_check.erl | tail -1 | cut -c1-80)"
echo "== the lexer has no spare sigil to borrow (option 2)"
for c in '@' '~' '`' '\^' '#'; do printf '   lexer rules mentioning %s: %s\n' "$c" "$(grep -c -- "^[^%]*$c" compiler/src/bs_lexer.xrl)"; done
echo "== statuses the brief relies on (Status: line of each ticket file)"
for n in 63 65 67 87 93 96 97 98 99; do printf '   %s: ' $n; grep -m1 '^Status' wayfinder/issues/$n-*.md | cut -c1-110; done
echo "== module names that differ from an OTP 28 module only by case (the ENG-391 / F54:171 hazard: on a case-insensitive disk 'Queue.beam' IS 'queue.beam')"
if command -v erl >/dev/null; then
  MODFILE="$(mktemp)"; trap 'rm -f "$MODFILE"' EXIT
  git ls-files '*.bs' | xargs grep -h '^module ' | awk '{print $2}' | sort -u > "$MODFILE"
  erl -noshell -eval '
    {ok,B}=file:read_file(hd(init:get_plain_arguments())),
    Names=[N || N <- string:split(binary_to_list(B),"\n",all), N =/= ""],
    All=sets:from_list([M || {M,_,_} <- code:all_available()]),
    Hits=[N || N <- Names, string:lowercase(N) =/= N, sets:is_element(string:lowercase(N), All)],
    io:format("   OTP 28 modules available in this install: ~p~n",[sets:size(All)]),
    io:format("   distinct module names declared in tracked .bs files: ~p~n",[length(Names)]),
    io:format("   of those, the LOWERCASED name equals an OTP module (only the comparison is lowercased; the atom stays as written): ~p~n",[Hits]),
    [io:format("   code:which(~s) on this case-sensitive disk = ~s  (a stdlib path), so there is no clash here~n",[string:lowercase(H), code:which(list_to_atom(string:lowercase(H)))]) || H <- Hits],
    halt().' -extra "$MODFILE"
else
  echo "   (erl not on PATH; source env.sh to run this section)"
fi
