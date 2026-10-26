module Main exposing (classify, delta, offset)


classify : Int -> String
classify n =
    case n of
        -5 ->
            "minus five"

        0 ->
            "zero"

        _ ->
            "other"


delta : Int -> Bool
delta x =
    x >= -100 && x <= 100


offset : Int -> Int
offset x =
    x + -5
