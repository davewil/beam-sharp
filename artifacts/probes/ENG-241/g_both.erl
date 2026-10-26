-module(g_both).
-export([outer_int/1, outer_tag/1]).
outer_int(N) when is_integer(N) -> inner_int(N) + 1.
inner_int(N) when is_integer(N) -> N + 1.
outer_tag(M) when map_get('Kind', M) == order -> inner_tag(M).
inner_tag(M) when map_get('Kind', M) == order -> map_get('Total', M).
