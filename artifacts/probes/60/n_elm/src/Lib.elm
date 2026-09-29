module Lib exposing (pub)

pub : Int -> Int
pub n = priv n + 1

priv : Int -> Int
priv n = n * 2
