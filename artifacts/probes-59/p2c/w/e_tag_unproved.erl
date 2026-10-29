-module(e_tag_unproved). -export([pub/1]).
pub(O) -> priv(O).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
