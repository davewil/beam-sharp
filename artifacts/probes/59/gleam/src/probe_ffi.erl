-module(probe_ffi).
-export([forged_int/0, forged_order/0]).
forged_int() -> 1.5.                       %% a float, typed Int on the Gleam side
forged_order() -> {not_an_order, <<"x">>}. %% a term that is not the opaque Order's constructor
