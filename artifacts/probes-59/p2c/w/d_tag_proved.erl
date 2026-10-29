-module(d_tag_proved). -export([pub/1]).
pub(O) when map_get('Kind', O) == 'M.Order' -> priv(O).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
