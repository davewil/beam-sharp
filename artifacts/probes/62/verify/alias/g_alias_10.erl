-module(g_alias_10).
-export(['Fun1'/1, fun_1/1, 'Fun2'/1, fun_2/1, 'Fun3'/1, fun_3/1, 'Fun4'/1, fun_4/1, 'Fun5'/1, fun_5/1, 'Fun6'/1, fun_6/1, 'Fun7'/1, fun_7/1, 'Fun8'/1, fun_8/1, 'Fun9'/1, fun_9/1, 'Fun10'/1, fun_10/1]).
'Fun1'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 1};
'Fun1'(_) -> error.
fun_1(X) -> 'Fun1'(X).
'Fun2'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 2};
'Fun2'(_) -> error.
fun_2(X) -> 'Fun2'(X).
'Fun3'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 3};
'Fun3'(_) -> error.
fun_3(X) -> 'Fun3'(X).
'Fun4'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 4};
'Fun4'(_) -> error.
fun_4(X) -> 'Fun4'(X).
'Fun5'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 5};
'Fun5'(_) -> error.
fun_5(X) -> 'Fun5'(X).
'Fun6'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 6};
'Fun6'(_) -> error.
fun_6(X) -> 'Fun6'(X).
'Fun7'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 7};
'Fun7'(_) -> error.
fun_7(X) -> 'Fun7'(X).
'Fun8'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 8};
'Fun8'(_) -> error.
fun_8(X) -> 'Fun8'(X).
'Fun9'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 9};
'Fun9'(_) -> error.
fun_9(X) -> 'Fun9'(X).
'Fun10'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 10};
'Fun10'(_) -> error.
fun_10(X) -> 'Fun10'(X).
