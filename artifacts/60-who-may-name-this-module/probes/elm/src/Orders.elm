module Orders exposing (apply)

apply : Int -> Int
apply n = recomputeTotal n + 1

recomputeTotal : Int -> Int
recomputeTotal n = n * 2
