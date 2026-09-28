%%% ctl.erl -- CONTROL: is there ANY loop on this OTP-25 JIT where stripping type info (+no_type_opt) changes time?
%%% Without a positive control, "no_type_opt costs 0% on the Day-01 loop" could just mean the harness or the
%%% OTP-25 loader is blind to type info everywhere. Prediction: EXPLORATORY, no strong prior. (a) tuple loop:
%%% none expected. (b) binary-match loop: no_type_opt disables ssa_opt_bsm/type-driven bsm opts, expected to be
%%% measurably slower if any type-driven path exists. If both show 0, the brief says the control found nothing.
%%% Macros TUP / BIN select one loop only, to attribute the effect.
-module(?MOD).
-export([part_two/1]).
-ifdef(TUP).
part_two(_) -> tup({3, 4}, 3000000, 0).
-else.
-ifdef(BIN).
part_two(_) -> cnt(bin(), 0).
-else.
part_two(_) -> {tup({3, 4}, 3000000, 0), cnt(bin(), 0)}.
-endif.
-endif.
tup(_, 0, Acc) -> Acc;
tup({A, B} = T, N, Acc) -> tup(T, N - 1, Acc + A * B).
bin() -> binary:copy(<<1,2,3,4,5,6,7,8>>, 250000).
cnt(<<X:8, Rest/binary>>, Acc) -> cnt(Rest, Acc + X);
cnt(<<>>, Acc) -> Acc.
