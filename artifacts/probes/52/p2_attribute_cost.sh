#!/usr/bin/env bash
# P2: can a compiled module carry a dependency attribute, via the same route bsc
# uses (serialised abstract forms -> compile:file(from_abstr, debug_info))?
# What does it cost in .beam bytes and in BEAM term words?
set -u
W="$(mktemp -d)"; cd "$W" || exit 2; fail=0
mk() { # name, attribute-lines
  cat > "$1.abstr" <<EOT
%% coding: latin-1
{attribute,1,module,$1}.
$2
{attribute,1,export,[{go,0}]}.
{function,1,go,0,[{clause,1,[],[],[{call,1,{remote,1,{atom,1,'Elixir.Req'},{atom,1,new}},[{nil,1}]}]}]}.
EOT
}
mk m0 ''
mk m1 "{attribute,1,bs_app,req}."
mk m1v "{attribute,1,bs_app,{req,<<\"~> 0.7\">>}}."
mk m5 "{attribute,1,bs_app,req}.
{attribute,1,bs_app,jason}.
{attribute,1,bs_app,mint}.
{attribute,1,bs_app,finch}.
{attribute,1,bs_app,plug}."
mk m5v "{attribute,1,bs_app,{req,<<\"~> 0.7\">>}}.
{attribute,1,bs_app,{jason,<<\"~> 1.4\">>}}.
{attribute,1,bs_app,{mint,<<\"~> 1.6\">>}}.
{attribute,1,bs_app,{finch,<<\"~> 0.17\">>}}.
{attribute,1,bs_app,{plug,<<\"~> 1.15\">>}}."
mk mbeh "{attribute,1,behaviour,gen_server}."
for m in m0 m1 m1v m5 m5v mbeh; do
  erl -noshell -eval "R=compile:file(\"$m.abstr\",[from_abstr,debug_info,return_warnings]), io:format(\"~s compile: ~p~n\",[\"$m\",case R of {ok,_,Ws} -> {ok,Ws}; O -> O end]), halt()." || fail=1
done
echo "== beam bytes =="; for m in m0 m1 m1v m5 m5v mbeh; do printf '%s %s\n' $m "$(stat -c %s $m.beam)"; done
echo "== module_info(attributes) at run time (loaded, no Req needed) + term words =="
erl -noshell -pa . -eval '
[begin {module,M}=code:ensure_loaded(M), A=[X||{K,_}=X<-M:module_info(attributes),K=:=bs_app],
  io:format("~p attrs=~p words(flat)=~p~n",[M,A,erts_debug:flat_size(A)]) end || M <- [m1,m1v,m5,m5v]],
io:format("go() -> ~p~n",[try m1:go() catch C:R -> {C,R} end]), halt().'
echo "== attribute readable from the FILE with no load (beam_lib attributes chunk) =="
erl -noshell -eval '{ok,{_,[{attributes,A}]}}=beam_lib:chunks("m5v.beam",[attributes]), io:format("~p~n",[[X||{bs_app,_}=X<-A]]), halt().' 
[ "$(stat -c %s m1.beam)" -gt "$(stat -c %s m0.beam)" ] || { echo "UNEXPECTED: no size change"; fail=1; }
erl -noshell -pa . -eval '{module,m1}=code:ensure_loaded(m1), halt(case proplists:get_value(bs_app,m1:module_info(attributes)) of [req] -> 0; _ -> 1 end).' || { echo "UNEXPECTED: attribute not readable"; fail=1; }
rm -rf "${W:?}"; exit $fail
