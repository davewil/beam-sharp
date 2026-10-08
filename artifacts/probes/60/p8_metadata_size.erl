-module(p8_metadata_size).
-export([main/0]).
sz(T) -> {erts_debug:flat_size(T) * 8, byte_size(term_to_binary(T))}.
main() ->
    P = "compiler/examples/Shop/shop.bs",
    {ok, Decls} = bsc:parse_path(P),
    Sources = [{P, Decls}], World = #{},
    Entry = #{exports => bs_check:exports_of(Sources, World, 'Shop'),
              polys => bs_check:polys_of(Decls, World),
              private => bs_check:private_of(Decls),
              behaviours => [B || {behaviour, _, B} <- Decls],
              types => bs_check:types_of(Decls, 'Shop', World)},
    io:format("baseline World entry, module Shop (~p exports, ~p private): {heap bytes, term_to_binary bytes} = ~p~n",
              [maps:size(maps:get(exports, Entry)), maps:size(maps:get(private, Entry)), sz(Entry)]),
    io:format("Option A (derived from the module name): 0 extra terms~n"),
    [io:format("Option B  internal => #{{N,A}=>true}, ~2w internal fns: ~p~n", [K, sz(maps:from_list([{{list_to_atom("F"++integer_to_list(I)), 1}, true} || I <- lists:seq(1,K)]))]) || K <- [1,5,20]],
    [io:format("Option C  friends => [Mod,..],         ~2w friends:      ~p~n", [K, sz([list_to_atom("Acme.Friend"++integer_to_list(I)) || I <- lists:seq(1,K)])]) || K <- [1,3,10]],
    io:format("emitted .beam: no option adds an attribute or chunk (B only adds names to the export list the beam already has)~n").
