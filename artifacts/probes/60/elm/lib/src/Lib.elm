module Lib exposing (total)
import Lib.Internal
total : Int -> Int
total n = Lib.Internal.recompute n
