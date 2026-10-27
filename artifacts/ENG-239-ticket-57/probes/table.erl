%% Shared table of refinement spellings, run against whichever ebin dir is on the path (baseline / fixA / fixB).
-module(table).
-export([main/0]).
ref(Pred) -> "module M\ntype T = int where " ++ Pred ++ "\npublic int F(T d)\nF(d) -> d\n".
rows() ->
  [ %% {Label, Source, ExpectBaseline}   (expectations are the TICKET's claims, checked, not assumed)
    {"value >= -5",                    ref("value >= -5")},
    {"value >= -5 and value <= 5",     ref("value >= -5 and value <= 5")},
    {"value >= 1 or value <= -1",      ref("value >= 1 or value <= -1")},
    {"value <= 3 or value >= 10",      ref("value <= 3 or value >= 10")},
    {"value != 0",                     ref("value != 0")},
    {"value != -1",                    ref("value != -1")},
    {"-5 <= value",                    ref("-5 <= value")},
    {"value >= 2 + 3",                 ref("value >= 2 + 3")},
    {"value >= 1 - 2",                 ref("value >= 1 - 2")},
    {"value >= -(-5)",                 ref("value >= -(-5)")},
    {"value >= 2 * 3",                 ref("value >= 2 * 3")},
    {"value >= -2 * 3",                ref("value >= -2 * 3")},
    {"value >= 7 / 2",                 ref("value >= 7 / 2")},
    {"value >= 1 / 0",                 ref("value >= 1 / 0")},
    {"value >= -5.0",                  ref("value >= -5.0")},
    {"value >= 0 - 5",                 ref("value >= 0 - 5")},
    {"value >= 5 % 3",                 ref("value >= 5 % 3")}
  ].
main() ->
  [begin R = drv:run(S), io:format("~-34s ~p~n", [L, guards:brief(R)]) end || {L, S} <- rows()],
  ok.
