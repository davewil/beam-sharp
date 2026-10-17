module Main exposing (pat, expr, dbl)

pat : Int -> String
pat x =
    case x of
        -5 -> "neg5"
        _ -> "other"

expr : Int
expr = -5

dbl : Int
dbl = - -5
