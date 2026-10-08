port module Main exposing (main)
port incoming : (Int -> msg) -> Sub msg
main = Platform.worker { init = \_ -> ((), Cmd.none), update = \_ m -> (m, Cmd.none), subscriptions = \_ -> incoming (\_ -> ()) }
