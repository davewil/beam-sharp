#!/bin/bash
# Cost of carrying provenance into the .beam, if the compiler emitted it as a module attribute.
# H1 a custom attribute round-trips through beam_lib:chunks(attributes) WITHOUT loading the module.
# H2 cost is small and linear: report exact delta bytes (file size and Attr chunk) for 0/1/3 apps.
# H3 compile time delta is below noise (reported with spread, not asserted).
W=$(mktemp -d); cd $W
gen() { # name, attribute-line
cat > $1.erl <<EOF
-module($1).
-export([go/0]).
$2
go() -> 'Elixir.Req':new([]).
EOF
}
gen m0 ''
gen m1 "-bs_requires([{req}])."
gen m3 "-bs_requires([{req},{jason},{finch}])."
gen m1v "-bs_requires([{req,<<\"~> 0.5\">>}])."
for m in m0 m1 m3 m1v; do erlc +no_debug_info $m.erl; done
cat > s.escript <<'EOF'
#!/usr/bin/env escript
main(_) ->
  io:format("OTP ~s (+no_debug_info)~n",[erlang:system_info(otp_release)]),
  Base = filelib:file_size("m0.beam"),
  [begin
     {ok,{_,[{attributes,At}]}} = beam_lib:chunks(F++".beam",[attributes]),
     {ok,{_,[{"Attr",Raw}]}} = beam_lib:chunks(F++".beam",["Attr"]),
     io:format("~-4s file=~4B B  (+~3B vs none)  Attr chunk=~3B B  attributes=~p~n",
        [F, filelib:file_size(F++".beam"), filelib:file_size(F++".beam")-Base, byte_size(Raw), proplists:get_value(bs_requires,At)])
   end || F <- ["m0","m1","m3","m1v"]],
  io:format("loaded m1 during read? ~p~n",[code:is_loaded(m1)]),
  %% compile time, 30 runs each
  T = fun(Src) -> Ts=[element(1,timer:tc(fun()->compile:file(Src,[binary,report])end))||_<-lists:seq(1,30)], {lists:min(Ts), lists:nth(15,lists:sort(Ts)), lists:max(Ts)} end,
  io:format("compile:file min/median/max us m0=~p m3=~p~n",[T("m0.erl"),T("m3.erl")]).
EOF
escript s.escript
