#!/bin/sh
# Can code:lib_dir/1 + code:which/1 tell "application missing" from "module missing"?
# And what do application:load / code:ensure_loaded say for the same inputs?
. "$(dirname "$0")/env.sh"
here=$(cd "$(dirname "$0")" && pwd)
erlc -o $W $here/prov.erl
export ERL_LIBS=$W/greeter_build/dev/lib:$W/rlib_src/_build/default/lib:$W/glib_src/build/dev/erlang
echo "ERL_LIBS=$ERL_LIBS"
erl -noshell -pa $W -eval '
io:format("-- check(App, Mod) = lib_dir then which~n"),
prov:row(greeter, '"'"'Elixir.Greeter'"'"'),          % app + module present
prov:row(greeter, '"'"'Elixir.Greeter.Nope'"'"'),      % app present, module typo
prov:row(req,     '"'"'Elixir.Req'"'"'),               % app absent (the 51 scenario)
prov:row(rlib,    rlib_util),
prov:row(glib,    glib),
prov:row(stdlib,  lists),                  % OTP itself
prov:row(kernel,  lists),                  % WRONG app named for the module: still ok
prov:row(greeter, lists),                  % module exists, but NOT in the named app
io:format("-- the other candidates, same inputs~n"),
io:format("  application:load(greeter)   = ~p~n", [application:load(greeter)]),
io:format("  application:load(req)       = ~p~n", [application:load(req)]),
io:format("  code:ensure_loaded(Greeter) = ~p~n", [code:ensure_loaded('"'"'Elixir.Greeter'"'"')]),
io:format("  code:ensure_loaded(Req)     = ~p~n", [code:ensure_loaded('"'"'Elixir.Req'"'"')]),
io:format("  code:ensure_loaded(Greeter.Nope) = ~p~n", [code:ensure_loaded('"'"'Elixir.Greeter.Nope'"'"')]),
io:format("  code:lib_dir(greeter)       = ~p~n", [code:lib_dir(greeter)]),
io:format("  code:lib_dir(req)           = ~p~n", [code:lib_dir(req)]),
io:format("  code:which(Greeter)         = ~p~n", [code:which('"'"'Elixir.Greeter'"'"')]),
io:format("  code:which(Req)             = ~p~n", [code:which('"'"'Elixir.Req'"'"')]),
io:format("-- side effects: is the module now LOADED by merely asking?~n"),
io:format("  before which: ~p~n", [erlang:module_loaded(rlib)]),
_ = code:which(rlib),
io:format("  after  which: ~p~n", [erlang:module_loaded(rlib)]),
_ = code:ensure_loaded(rlib),
io:format("  after  ensure_loaded: ~p~n", [erlang:module_loaded(rlib)]),
io:format("  application:loaded_applications has rlib: ~p~n", [lists:keymember(rlib,1,application:loaded_applications())]),
halt().'
