-module(f_tag_built). -export([pub/1]).
pub(N) -> priv(#{'Kind' => 'M.Order', f1 => N}).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
