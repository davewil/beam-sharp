-module(vendor_c).
-export([go/0]).
go() -> lib_a:pub().
