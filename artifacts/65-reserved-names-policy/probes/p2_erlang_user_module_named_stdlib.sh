#!/usr/bin/env bash
# Probe (ii): compile and load a user module named lists / maps / string on OTP 25.
# Run: bash p2_erlang_user_module_named_stdlib.sh
set -u
T=$(mktemp -d); cd "$T"; mkdir user
erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
for m in lists maps string; do
cat > user/$m.erl <<X
-module($m).
-export([marker/0]).
marker() -> user_$m.
X
done
echo "=== A: erlc each (does the compiler object to the name?)"
for m in lists maps string; do erlc -o user user/$m.erl; echo "erlc $m exit=$?"; done
echo "=== B: add user dir to the FRONT of the path, then query: which file does the code server use; can we load_file?"
cat > b.escript <<'X'
#!/usr/bin/env escript
main([Dir]) ->
  code:add_patha(Dir),
  [begin
     io:format("~p: module_loaded=~p sticky=~p which=~p~n", [M, erlang:module_loaded(M), code:is_sticky(M), code:which(M)]),
     R = code:load_file(M),
     io:format("  code:load_file(~p) -> ~p~n", [M, R]),
     io:format("  after: exports has marker? ~p~n", [lists:member({marker,0}, M:module_info(exports))])
   end || M <- [lists, maps, string]].
X
escript b.escript "$T/user" 2>&1
echo "=== C: purge+load_binary of the user's bytes (the 'force it' path)"
cat > c.escript <<'X'
#!/usr/bin/env escript
main([Dir]) ->
  [begin
     {ok, Bin} = file:read_file(filename:join(Dir, atom_to_list(M) ++ ".beam")),
     R = code:load_binary(M, atom_to_list(M) ++ ".beam", Bin),
     io:format("load_binary(~p) -> ~p~n", [M, R])
   end || M <- [lists, maps, string]].
X
escript c.escript "$T/user" 2>&1
echo "=== D: 'release-like' path: fresh VM started with -pa user (user first) and -pz (user last); which one do lists/maps/string resolve to?"
for flag in -pa -pz; do
 echo "--- erl $flag user"
 erl -noshell $flag "$T/user" -eval '
   [io:format("~p which=~p  has marker=~p  sticky=~p~n",[M, code:which(M), lists:member({marker,0},M:module_info(exports)), code:is_sticky(M)]) || M <- [lists,maps,string]],
   io:format("lists:reverse([1,2]) works? ~p~n",[catch lists:reverse([1,2])]),
   halt().' 2>&1 | cut -c1-160 | grep -v '^$' | head -6
 echo "   vm exit status: ${PIPESTATUS[0]}"
done
echo "=== E: boot-script/release-like: -mode embedded (loads everything at boot from the release's own path list)"
erl -noshell -mode embedded -pa "$T/user" -eval 'io:format("embedded: lists which=~p~n",[code:which(lists)]),halt().' 2>&1 | cut -c1-160 | grep -v '^$' | head -4
echo "   vm exit status: ${PIPESTATUS[0]}"
echo "=== F: -compile(no_auto_import) / auto-import: a user module named like a BIF-bearing module? (erlang is the only auto-import source)"
cat > user/erlang_clash.erl <<'X'
-module(erlang_clash).
-export([t/0]).
t() -> length([1,2]).
-compile({no_auto_import,[length/1]}).
length(_) -> mine.
X
erlc -o user user/erlang_clash.erl; echo "erlc exit=$?"
cat > user/erlang_clash2.erl <<'X'
-module(erlang_clash2).
-export([t/0]).
t() -> length([1,2]).
length(_) -> mine.
X
erlc -o user user/erlang_clash2.erl; echo "erlc (no no_auto_import, local length/1 defined+auto-imported call) exit=$?"
echo "=== G: control for D/E: -pa with a dir holding only a harmless module (proves the boot crash in D is the shadowing, not -pa)"
mkdir ctl; printf -- '-module(harmless).\n-export([x/0]).\nx() -> ok.\n' > ctl/harmless.erl; erlc -o ctl ctl/harmless.erl
erl -noshell -pa "$T/ctl" -eval 'io:format("harmless:x() = ~p~n",[harmless:x()]),halt().' 2>&1 | head -3; echo "   vm exit status: ${PIPESTATUS[0]}"
rm -rf "$T"
