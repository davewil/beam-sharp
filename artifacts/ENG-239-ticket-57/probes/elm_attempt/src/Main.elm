module Main exposing (f, g, h)

f : Int -> String
f x =
    case x of
        -1 -> "neg one"
        _ -> "other"

g : Int -> Bool
g x = x >= -5 + 1

h : Int -> String
h x =
    case x of
        1 + 2 -> "three"
        _ -> "other"
