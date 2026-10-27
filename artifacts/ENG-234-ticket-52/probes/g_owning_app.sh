#!/bin/bash
# NOTE: run 1 (g_owning_app.run1.out) printed MISMATCH for :erlang because the derivation did not handle the atom `preloaded`; the expectation was written beforehand and not changed, only the derivation was fixed.
# Which application owns the modules the repo's .bs files already name under `using :…`?
# H1 kernel/stdlib modules resolve to kernel-*/stdlib-* (always started), so a check can exempt exactly those two.
# H2 other OTP modules (crypto, ssl, inets) resolve to applications that are NOT started by default (need declaring).
# H3 `Elixir.String` resolves to elixir-*. Falsified if any owning-app name != the expectation.
cd $(mktemp -d)
cat > o.escript <<'EOF'
#!/usr/bin/env escript
app(M) -> case code:which(M) of non_existing -> absent; P when is_atom(P) -> P; P -> hd(string:split(filename:basename(filename:dirname(filename:dirname(P))),"-")) end.
main(_) ->
  Exp = [{lists,"stdlib"},{ets,"stdlib"},{erlang,preloaded},{crypto,"crypto"},{ssl,"ssl"},{httpc,"inets"},
         {'Elixir.String',"elixir"},{'Elixir.Req',absent}],
  io:format("OTP ~s; started at boot: ~p~n",[erlang:system_info(otp_release),[A||{A,_,_}<-application:which_applications()]]),
  [begin R = (try app(M) catch _:_ -> absent end),
     io:format("  ~p -> ~p expected ~p ~s~n",[M,R,E, if R=:=E -> "ok"; true -> "MISMATCH" end]) end || {M,E} <- Exp].
EOF
ELIXIR_LIB=/usr/lib/elixir/lib ERL_LIBS=/usr/lib/elixir/lib escript o.escript
