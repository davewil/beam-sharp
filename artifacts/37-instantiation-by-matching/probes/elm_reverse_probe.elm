module Reverse exposing (reverse)

-- Generic polymorphic function: same shape needed twice in beam-sharp's exemplar
-- corpus (25e's ReverseParts :: list<binary> and ReverseRows :: list<Iodata>).
-- Elm expresses this ONE time, over a type variable `a`.

reverse : List a -> List a -> List a
reverse xs acc =
    case xs of
        [] -> acc
        x :: rest -> reverse rest (x :: acc)

-- Instantiated at two different concrete types, same function, no duplication.
reverseInts : List Int -> List Int
reverseInts xs = reverse xs []

reverseStrings : List String -> List String
reverseStrings xs = reverse xs []
