-module(g_none).
-export([outer_int/1, outer_tag/1]).
outer_int(N) -> inner_int(N) + 1.
inner_int(N) -> N + 1.
outer_tag(M) -> inner_tag(M).
inner_tag(M) -> map_get('Total', M).
