#!/usr/bin/env bash
# 59b — CLAIM (ticket 59, "It is not [a defect]"): a forged record can reach a PRIVATE function
# through an EXPORTED one whose own guard does not see it, so the private tag test is the
# only check. Builds the B# program src/Forge/forge.bs under three compilers (cur = shipped,
# narrow = no tag test on private fns, widen = kind test on private fns too) and calls it
# from Erlang with hand-forged maps. Also from Elixir (same BEAM terms, second caller).
# CONTROLS (any would show a different answer if the claim were false):
#   ViaOrder   - forgery at the exported fn's OWN param: caught by the exported test in all 3
#   Inline     - same deep forgery, body never calls a private fn: caught by NO variant,
#                so the private test only helps when the deep value happens to be passed on
#   Hof:Run    - the private fn's call site is lists:map, not a checked B# site (fun capture)
#   tier-2     - right tag, wrong field type: caught by no variant (no exact-set/value test)
set -uo pipefail
source "${ENV_SH:-/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh}"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$REPO"; build_variants
for v in cur narrow widen; do mkdir -p "$WORK/out_$v"; bsc_v $v "$PROBE/src" "$WORK/out_$v" "$PROBE/src/Forge"; bsc_v $v "$PROBE/src" "$WORK/out_$v" "$PROBE/src/Hof"; done
cat > "$WORK/forge.erl" <<'ERL'
-module(forge).
-export([main/1]).
inv(T)  -> #{'Kind'=>'Forge.Invoice','Id'=>1,'Total'=>T}.   % wrong record, right fields
ord(T)  -> #{'Kind'=>'Forge.Order','Id'=>1,'Total'=>T}.
box(I)  -> #{'Kind'=>'Forge.Box','Item'=>I}.
cls(F) -> try F() of V -> {ok,V} catch error:function_clause -> function_clause;
                                       error:{badkey,_} -> badkey; error:{badmap,_} -> badmap;
                                       error:badarith -> badarith; C:R -> {C,R} end.
main([Dir]) ->
  code:add_patha(Dir),
  Cases = [
   {"ViaOrder(Invoice)           [control: exported test]", fun() -> 'Forge':'ViaOrder'(inv(5)) end},
   {"ViaOrder(Order)             [control: legit call]",     fun() -> 'Forge':'ViaOrder'(ord(5)) end},
   {"ViaBox(Box{Item=Invoice})   [deep forgery -> private]", fun() -> 'Forge':'ViaBox'(box(inv(5))) end},
   {"ViaBox(Box{Item=42})        [deep non-map]",            fun() -> 'Forge':'ViaBox'(box(42)) end},
   {"ViaBox(Box{Item=#{}})       [deep map, no Kind]",       fun() -> 'Forge':'ViaBox'(box(#{})) end},
   {"ViaBox(Box{Item=Order})     [legit]",                   fun() -> 'Forge':'ViaBox'(box(ord(5))) end},
   {"ViaList([Invoice])          [forgery in list elem]",    fun() -> 'Forge':'ViaList'([inv(5)]) end},
   {"Inline(Box{Item=Invoice})   [control: no private call]",fun() -> 'Forge':'Inline'(box(inv(5))) end},
   {"ViaBox(Box{Item=Order{Total=:x}}) [tier-2: bad field]", fun() -> 'Forge':'ViaBox'(box(ord(x))) end},
   {"ViaInts([1.5])              [float via exported list]", fun() -> 'Forge':'ViaInts'([1.5]) end},
   {"ViaInts([1])                [legit]",                   fun() -> 'Forge':'ViaInts'([1]) end},
   {"ViaInts([foo])              [atom via exported list]",  fun() -> 'Forge':'ViaInts'([foo]) end},
   {"Hof:Run([1.5]) [private Bump via lists:map]", fun() -> 'Hof':'Run'([1.5]) end},
   {"Hof:Run([1])   [legit]",                              fun() -> 'Hof':'Run'([1]) end}],
  [io:format("  ~-56s ~p~n",[N,cls(F)]) || {N,F} <- Cases].
ERL
erlc -o "$WORK" "$WORK/forge.erl"
for v in cur narrow widen; do echo "=== variant: $v"; erl -noshell -pa "$WORK" -eval 'forge:main(init:get_plain_arguments()), halt().' -extra "$WORK/out_$v"; done
echo "=== Elixir caller, variant cur (ViaBox with forged Item, ViaInts with 1.5)"
elixir -pa "$WORK/out_cur" -e '
  inv = %{:Kind => :"Forge.Invoice", :Id => 1, :Total => 5}
  IO.inspect(try do apply(:Forge, :ViaBox, [%{:Kind => :"Forge.Box", :Item => inv}]) rescue e -> e end, label: "ViaBox(forged Item)")
  IO.inspect(try do apply(:Forge, :ViaInts, [[1.5]]) rescue e -> e end, label: "ViaInts([1.5])")'
