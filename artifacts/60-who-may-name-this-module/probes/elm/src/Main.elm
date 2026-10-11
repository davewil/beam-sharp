module Main exposing (main)
import Orders
import Html

main = Html.text (String.fromInt (Orders.recomputeTotal 3))
