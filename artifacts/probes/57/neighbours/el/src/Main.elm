module Main exposing (f)
f : Int -> Int
f n = case n of
        -7 -> 7
        _ -> if n >= -5 then 1 else 0
