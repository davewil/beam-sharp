-module(rcons).
-export([h/1, g/1]).
h(X) -> crypto:hash(sha256, X).     % uses crypto without listing it in `applications`
g(X) -> 'Elixir.Greeter':hello(X).  % a remote call into a module no listed app provides
