#!/usr/bin/env bash
# verdict.sh: mechanical PASS/FAIL per claim, read from out/*.out ONLY (no re-measurement).
# A line says CLAIM-HOLDS when the evidence pattern the claim predicted is present, CLAIM-REFUTED when it is absent.
cd "$(dirname "$0")/out" || exit 1
t() { # label file regex  [invert]
  if grep -qE -- "$3" "$2" 2>/dev/null; then r=HOLDS; else r=REFUTED; fi
  [ "${4:-}" = invert ] && { [ $r = HOLDS ] && r=REFUTED || r=HOLDS; }
  printf "%-9s %s\n" "CLAIM-$r" "$1"
}
echo "== ticket 62's own claims"
t "T1  62a rows 1-6 reproduce (Elixir dot-syntax on PascalCase = syntax error)"            p01.out '^REPRODUCED +:Shop.New\(1\) -> SYNTAX_ERROR'
t "T2  Erlang calls 'Shop':'New'(1) with ordinary syntax"                                   p01.out '^REPRODUCED +Erlang'
t "T3  record arrives as plain map; wrong tag / struct -> FunctionClauseError"              p01.out '^REPRODUCED +Elixir struct'
t "T4  'Elixir cannot call a PascalCase export' (ticket §1 headline)  [expected REFUTED]"   p02.out '^:Shop\."New"\(1\) +\{:raised|^:Shop\."New"\(1\) +:SYNTAX' 
t "T5  Elixir reads .Capitalised as an alias (parser text)"                                 p03.out 'unexpected \( after alias New'
t "T6  Gleam @external(erlang,\"Shop\",\"New\") compiles AND runs against a bsc beam"        p05.out "ext:make\(3\) -> #\{'Kind' => 'Shop.Order'"
t "T7  'Gleam downcases PascalCase to snake_case' for FUNCTIONS  [expected REFUTED]"        p05.out "I'm expecting a lowercase name here" invert
t "T8  Gleam lowers PascalCase CONSTRUCTORS to snake_case atoms"                            p05.out 'red \| h_t_t_p_get \| to_j_s_o_n'
t "T9  option 2 'costs two exports per function' (N=100: 100 -> 200 + 3)"                   p08.out '^100 +thin +.*exports=203'
echo "== new facts"
t "N1  quoted call :Shop.\"New\"(1) runs"                                                   p02.out '^:Shop\."New"\(1\) +\{:ok, %\{Kind'
t "N2  capture &:Shop.\"New\"/1 runs; unquoted capture is a syntax error"                  p02.out 'f = &:Shop\."New"/1; f\.\(4\) +\{:ok'
t "N3  elixirc type-checks quoted names against the beam (typo warns)"                      p04.out 'warning: :Shop\."Nw"/1 is undefined or private'
t "N4  formatter keeps the quotes on \"New\" (needed) and drops them on \"new\""            p04.out '^:Shop\."New"\(1\)$'
t "N5  defdelegate facade over unmodified beams works"                                      p15.out 'MyApp.Shop.which\(o\): :order'
t "N6  rule S: FooBar & Foo_Bar collide"                                                    p06.out 'alias_collision,.FooBar.,.Foo_Bar.,foo_bar'
t "N7  rule S: HttpGet & HTTPGet collide"                                                   p06.out 'alias_collision,.HttpGet.,.HTTPGet.,http_get'
t "N8  Module_Info alias collides with the BEAM's module_info/1"                            p06.out 'alias_shadows_existing,.Module_Info.,module_info,1'
if awk '/^--- Clash4/{f=1;next} /^--- /{f=0} f' p06.out | grep -q 'exception error'; then echo "CLAIM-REFUTED N9  private Foo_bar beside public FooBar does NOT collide"; else echo "CLAIM-HOLDS   N9  private Foo_bar beside public FooBar does NOT collide"; fi
t "N10 every derived alias (incl. do/end/fn/nil/true/when/and/not) is an unquoted Elixir call" p07.out ':Casing\.end\(1\) +:parses'
t "N11 thin alias is a tail call (no frame)"                                                p09.out 'alias has allocate \(a frame\)\? false'
t "N12a thin alias hides itself in crash traces (frame names the Pascal fn)"               p13.out "\{'Sz3','ScoreAt1Value',\[<<\"x\">>\]\}"
t "N12b dup alias shows its own name in the crash trace"                                    p13.out "\{'Sz3',score_at1_value,\[<<\"x\">>\]\}"
t "N13 callbacks of a behaviour module are ALREADY exported snake_case only"                p17.out '\{handle_call,3\}.*\{init,1\}|\{init,1\}'
t "N14 corpus has no acronym/underscore/digit names (rules S and G agree on all)"           p14.out 'names where S and G differ: 0 of'
t "N15 aliases invisible to bsc --api"                                                      p08.out '^api identical'
t "N16 snake alias of a non-callback Init/1 makes gen_server reach it (callback-name capture)"  p06.out 'gen_server:start\(Capture, 7, \[\]\) -> \{error,\{bad_return_value,7\}\}'
t "N17 import :Casing, only: [http_get: 1]; http_get(1) works with aliases"                p07.out 'http_get\(1\)  -> \{:ok, 2\}'
t "N18 import of a Pascal export cannot be CALLED unqualified (no alias)"                  p02.out 'import :Shop, only: \[New: 1\]; "New"\(1\) +\{:raised, SyntaxError'
echo "== p10: thin call-cost effect vs null spread"
awk '/^none +effect/{nmin=$(NF-1); nmax=$NF; gsub(/[\[\]\.]+/,"",nmin)} 1' p10.out >/dev/null
awk '
  /^none +effect/ { match($0,/median= *-?[0-9.]+ \[ *-?[0-9.]+\.\. *-?[0-9.]+\]/); s=substr($0,RSTART,RLENGTH); gsub(/[^-0-9. ]/," ",s); split(s,a," "); nlo=a[2]; nhi=a[3] }
  /^thin +effect/ { match($0,/median= *-?[0-9.]+ \[ *-?[0-9.]+\.\. *-?[0-9.]+\]/); s=substr($0,RSTART,RLENGTH); gsub(/[^-0-9. ]/," ",s); split(s,b," "); tmed=b[1]; tlo=b[2] }
  /^dup +effect/  { match($0,/median= *-?[0-9.]+ \[ *-?[0-9.]+\.\. *-?[0-9.]+\]/); s=substr($0,RSTART,RLENGTH); gsub(/[^-0-9. ]/," ",s); split(s,c," "); dmed=c[1]; dlo=c[2] }
  END { printf "null spread [%s..%s]; thin median %s (min %s); dup median %s (min %s)\n", nlo,nhi,tmed,tlo,dmed,dlo;
        if (nhi-nlo > 1.0) { print "INCONCLUSIVE  null spread wider than 1.0 ns after all attempts: this host could not resolve the effect"; exit }
        printf "CLAIM-%s  thin effect lies above the null spread (real cost)\n", (tlo+0 > nhi+0) ? "HOLDS" : "REFUTED";
        printf "CLAIM-%s  dup effect lies above the null spread\n",            (dlo+0 > nhi+0) ? "HOLDS" : "REFUTED" }' p10.out
