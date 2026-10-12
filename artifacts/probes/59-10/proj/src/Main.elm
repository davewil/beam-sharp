port module Main exposing (main)

import Platform

port incoming : (Int -> msg) -> Sub msg

main : Program () () Int
main =
    Platform.worker { init = \_ -> ( (), Cmd.none ), update = \_ m -> ( m, Cmd.none ), subscriptions = \_ -> incoming identity }
