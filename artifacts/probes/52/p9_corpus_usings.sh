#!/usr/bin/env bash
# P9: what do today's repo programs actually `using`? For each foreign `using :M {`
# in compiler/examples + wayfinder/prototypes (*.bs), find the owning application
# from the installed .app `modules` lists (OTP 25 + Elixir 1.14 only), and count
# how many of those modules a hex package would have to repeat `from :app` for.
set -u
R="$(cd "$(dirname "$0")/../../.." && pwd)"
grep -rh "^using :" "$R/compiler/examples" "$R/wayfinder/prototypes" --include=*.bs | sed "s/^using :\(.*\) {.*/\1/; s/^'//; s/'\$//" | sort > "${TMPDIR:-/tmp}/p9.$$.mods"
ERL_LIBS=/usr/lib/elixir/lib MODS="${TMPDIR:-/tmp}/p9.$$.mods" erl -noshell -eval '
{ok,B}=file:read_file(os:getenv("MODS")), Mods=[list_to_atom(binary_to_list(L))||L<-binary:split(B,<<"\n">>,[global]),L=/=<<>>],
Apps=[{A,proplists:get_value(modules,Ps,[])}||D<-filelib:wildcard("/usr/lib/erlang/lib/*")++filelib:wildcard("/usr/lib/elixir/lib/*"),F<-filelib:wildcard(filename:join([D,"ebin","*.app"])),{ok,[{application,A,Ps}]}<-[file:consult(F)]],
Own=fun(M)->case [A||{A,Ms}<-Apps,lists:member(M,Ms)] of [A|_]->A; []->case code:which(M) of non_existing->absent; _->no_app_file end end end,
Rs=[{M,Own(M)}||M<-Mods],
io:format("using blocks=~p~n",[length(Rs)]),
[io:format("  ~-28w -> ~w~n",[M,O])||{M,O}<-lists:usort(Rs)],
Abs=[M||{M,absent}<-Rs], io:format("owned by no installed app (third-party or newer OTP): ~p~n",[lists:usort(Abs)]),
halt(case lists:usort(Abs) =:= [list_to_atom("Elixir.Req"),epgsql,json] of true -> 0; false -> 1 end).' 2>&1  # asserts the census still finds exactly these three absent
rc=$?; rm -f "${TMPDIR:-/tmp}/p9.$$.mods"; exit $rc
