%%% pc.erl -- ADDED AFTER INDEPENDENT VERIFICATION (verification.md, finding F1); authored by the verifier, copied
%%% here unchanged apart from this header. Not part of the original brief's probes.
%%% Purpose: a control whose typed and +no_type_opt builds have an IDENTICAL instruction stream once {tr,R,_} is
%%% erased to R (checked by pcid.erl), so any time difference is due to annotations alone.
%%% Verifier's recorded result (its own run): typed 23.97 ms vs no_type_opt 48.49 ms (2.02x).
%%% Prediction to check on rerun: identical streams, no_type_opt clearly slower (>1.5x).
-module(?MOD).
-export([part_two/1]).
part_two(_) -> l(5000000, 0).
l(0, A) -> A;
l(N, A) ->
    X = N band 255, Y = N band 15,
    Z = X + Y + X + Y + X + Y + X + Y + X + Y,
    l(N - 1, (A + Z) band 16#ffffff).
