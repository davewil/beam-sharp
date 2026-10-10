-module(drive_forge).
-export([run/1]).
%% Calls into Forge from Erlang with forged terms and prints what comes back.
r(Label, F) ->
    R = try {returned, F()} catch C:E:_ -> {raised, C, case E of {Tag,_} -> Tag; _ -> E end} end,
    io:format("~-62s ~w~n", [Label, R]).
run(Mod) ->
    Ord  = #{'Kind'=>'Forge.Order',   'Id'=>1,'Total'=>7},
    Inv  = #{'Kind'=>'Forge.Invoice', 'Id'=>1,'Total'=>7},
    Bare = #{'Total'=>7},
    W    = fun(I) -> #{'Kind'=>'Forge.Wrapper','Inner'=>I} end,
    r("ViaField(Wrapper{valid Order})            [valid]", fun() -> Mod:'ViaField'(W(Ord)) end),
    r("ViaField(Order with a wrong Wrapper tag)  [exported guard, control]", fun() -> Mod:'ViaField'(Ord#{'Kind'=>'Forge.Nope'}) end),
    r("ViaField(Wrapper{Inner=an Invoice})       [forged one level down]", fun() -> Mod:'ViaField'(W(Inv)) end),
    r("ViaField(Wrapper{Inner=#{Total=>7}})      [forged, no tag at all]", fun() -> Mod:'ViaField'(W(Bare)) end),
    r("DirectField(Wrapper{Inner=an Invoice})    [same, helper factored away]", fun() -> Mod:'DirectField'(W(Inv)) end),
    r("ViaList([valid Order])                    [valid]", fun() -> Mod:'ViaList'([Ord]) end),
    r("ViaList([an Invoice])                     [forged list element]", fun() -> Mod:'ViaList'([Inv]) end),
    r("ViaList([#{Total=>7}])                    [forged, no tag at all]", fun() -> Mod:'ViaList'([Bare]) end),
    r("DirectList([an Invoice])                  [same, helper factored away]", fun() -> Mod:'DirectList'([Inv]) end),
    r("ViaUnion(Order)                           [valid]", fun() -> Mod:'ViaUnion'(Ord) end),
    r("ViaUnion(#{Total=>7})                     [the head names the record]", fun() -> Mod:'ViaUnion'(Bare) end),
    r("ViaTerm(valid Order)                      [valid]", fun() -> Mod:'ViaTerm'(Ord) end),
    r("ViaTerm(an Invoice)                       [ValidateAs refuses it]", fun() -> Mod:'ViaTerm'(Inv) end),
    ok.
