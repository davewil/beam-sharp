module Main exposing (main)

-- exposing list = Elm's export list; `helper` is private. Nothing is checked at runtime in either:
-- a value of type Order cannot be forged inside Elm; the only door is a port/flag decoder.
type alias Order = { total : Int }

amount : Order -> Int
amount o = helper o

helper : Order -> Int
helper o = o.total

main = Platform.worker { init = \_ -> ( (), Cmd.none ), update = \_ m -> ( m, Cmd.none ), subscriptions = \_ -> Sub.none }
