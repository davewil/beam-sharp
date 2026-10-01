-module(g_base_10).
-export(['Fun1'/1, 'Fun2'/1, 'Fun3'/1, 'Fun4'/1, 'Fun5'/1, 'Fun6'/1, 'Fun7'/1, 'Fun8'/1, 'Fun9'/1, 'Fun10'/1]).
'Fun1'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 1};
'Fun1'(_) -> error.
'Fun2'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 2};
'Fun2'(_) -> error.
'Fun3'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 3};
'Fun3'(_) -> error.
'Fun4'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 4};
'Fun4'(_) -> error.
'Fun5'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 5};
'Fun5'(_) -> error.
'Fun6'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 6};
'Fun6'(_) -> error.
'Fun7'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 7};
'Fun7'(_) -> error.
'Fun8'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 8};
'Fun8'(_) -> error.
'Fun9'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 9};
'Fun9'(_) -> error.
'Fun10'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + 10};
'Fun10'(_) -> error.
