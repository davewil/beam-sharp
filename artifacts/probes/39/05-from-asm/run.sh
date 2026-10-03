#!/usr/bin/env bash
# Can type facts be injected below the abstract format?  `erlc +from_asm` accepts the assembler
# listing, including {'%',{var_info,Reg,[{type,T}]}} and {tr,Reg,T} operands.
#  A0 control (round-trip beam-sharp's own listing unchanged)
#  A1 TRUE fact: Spin's first arg is {t_integer,{0,99}} (Pos starts at 50, then only Wrap results)
#  A2 LIE: Spin's step arg claimed {t_integer,{1,1}} (really -1 or 1)
set -e
source "$(dirname "$0")/../common.sh"
cd "$(dirname "$0")"; rm -rf w; mkdir w
V="$PWD/../04-variants"; [ -f "$V/vbuild/b0_bs_as_is.S" ] || bash ../04-variants/run.sh >/dev/null 2>&1
mk() { # name  sed-expr
  sed -E "s/b0_bs_as_is/$1/g; $2" "$V/vbuild/b0_bs_as_is.S" > w/$1.S
  erlc +from_asm -o w w/$1.S && echo "[$1] erlc +from_asm: accepted ($(stat -c %s w/$1.beam) bytes)" || echo "[$1] erlc +from_asm: REJECTED"
}
mk a0_control ''
# Spin/4 header: first var_info after {label,9} is x0 -> narrow to 0..99
mk a1_true_fact "/'Spin', 4/,/label,9/!b; :a; n; s/\{var_info,\{x,0\},\[\{type,\{t_integer,\{-99,99\}\}\}\]\}/{var_info,{x,0},[{type,{t_integer,{0,99}}}]}/; /label,10/b; ba"
mk a2_LIE_step "/'Spin', 4/,/label,9/!b; :a; n; s/\{var_info,\{x,1\},\[\{type,\{t_integer,\{-1,1\}\}\}\]\}/{var_info,{x,1},[{type,{t_integer,{1,1}}}]}/; /label,10/b; ba"
for n in a0_control a1_true_fact a2_LIE_step; do echo "-- diff of $n vs control (Spin header only):"; diff <(grep -n var_info w/a0_control.S) <(grep -n var_info w/$n.S) || true; done
cat > t.erl <<'T'
-module(t).
-export([main/1]).
main([Dir, Input]) ->
    {ok, B} = file:read_file(Input),
    Ds = [case L of [$L|N] -> -list_to_integer(N); [$R|N] -> list_to_integer(N) end
          || L <- string:split(binary_to_list(B), "\n", all), L =/= ""],
    Ms = [a0_control, a1_true_fact, a2_LIE_step],
    [code:load_abs(Dir ++ "/" ++ atom_to_list(M)) || M <- Ms],
    [io:format("~-14s answer=~p (expected 6770)~n", [M, catch M:'PartTwo'(Ds)]) || M <- Ms],
    [[M:'PartTwo'(Ds) || _ <- lists:seq(1,20)] || M <- Ms],
    Rs = [begin {A,B2} = lists:split(R rem 3, Ms), [begin {T,_} = timer:tc(M,'PartTwo',[Ds]), {M,T} end || M <- B2 ++ A] end || R <- lists:seq(0,39)],
    io:format("~n40 rotated runs, ms:  min / median / IQR~n"),
    [begin L = lists:sort([T || R <- Rs, {Mm,T} <- R, Mm =:= M]),
           io:format("~-14s ~7.2f ~7.2f ~7.2f~n", [M, hd(L)/1000, lists:nth(21,L)/1000, (lists:nth(31,L)-lists:nth(11,L))/1000]) end || M <- Ms],
    halt().
T
erlc -o w t.erl
erl -noshell -pa w -eval 't:main(["w","'$INPUT'"])'
