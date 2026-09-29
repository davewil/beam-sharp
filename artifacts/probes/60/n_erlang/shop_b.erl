-module(shop_b).
-export([go_pub/0, go_priv/0]).
-spec go_pub() -> lib_a:pubt().
go_pub() -> lib_a:pub().
-spec go_priv() -> lib_a:privt().
go_priv() -> lib_a:priv().
