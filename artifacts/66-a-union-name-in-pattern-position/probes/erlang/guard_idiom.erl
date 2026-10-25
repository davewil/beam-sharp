-module(guard_idiom).
-export([f/1, g/1]).
%% the guard idiom: bind the whole value, test the discriminant in the guard (ssl/tls_dtls_client_connection.erl:146-150 does this with is_record).
f(X) when is_map(X), (map_get(kind, X) =:= a orelse map_get(kind, X) =:= b) -> {member, map_get(id, X)};
f(_) -> other.
%% the same through a pattern binding for the discriminant
g(#{kind := K} = X) when K =:= a; K =:= b -> {member, map_get(id, X)};
g(_) -> other.
