-module(forge).
-export([ship/1, ship_all/1, ship_all_guarded_inner/1, ship_field/1]).
%% Exported, record-typed param: tag-tested (what B# emits for `Ship(Order o)`)
ship(O) when map_get('Kind', O) == order -> inner_unguarded(O).
%% Exported, list<Order>: NOT a single closed record, so no tag test on the list
%% (bs_emit:record_tag/2 matches only one closed map member). Body forwards each
ship_all(Os) -> [inner_unguarded(O) || O <- Os].
ship_all_guarded_inner(Os) -> [inner_guarded(O) || O <- Os].
%% Exported, takes an Envelope record; its Order field is a nested record.
%% Only Envelope's own Kind is tested.
ship_field(E) when map_get('Kind', E) == envelope -> inner_unguarded(map_get('Order', E)).
inner_unguarded(O) -> {shipped, O}.
inner_guarded(O) when map_get('Kind', O) == order -> {shipped, O}.
