-module(g_tag_pattern). -export([pub/1]).
pub(#{'Kind' := 'M.Order'} = O) -> priv(O).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
