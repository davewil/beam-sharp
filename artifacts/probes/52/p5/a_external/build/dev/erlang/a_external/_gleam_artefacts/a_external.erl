-module(a_external).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/a_external.gleam").
-export([main/0]).

-file("src/a_external.gleam", 4).
-spec main() -> integer().
main() ->
    'Elixir.Nope':count([1, 2, 3]).
