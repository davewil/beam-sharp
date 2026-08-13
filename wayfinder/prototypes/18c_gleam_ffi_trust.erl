%%% 18c — the Erlang side of the Gleam FFI trust probe. See 18c_gleam_ffi_trust.gleam.
%%% Both functions return something the Gleam declaration says they cannot.
%%% Copy to a Gleam project as src/probe_ffi.erl — the module name is what the
%%% @external attributes name, so it must stay `probe_ffi`.
-module(probe_ffi).
-export([lookup/1, count/0]).

%% declared on the Gleam side as List(Order), with id :: Int
lookup(_Id) -> [{order, <<"7">>, <<"acme">>}].

%% declared on the Gleam side as Int
count() -> 41.5.
