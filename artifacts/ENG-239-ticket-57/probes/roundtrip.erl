%% Ticket 38's residual-printing concern: does the compiler hand back a residual the surface can take back?
-module(roundtrip).
-export([main/0]).
decl(P) -> "module M\ntype Delta = int where " ++ P ++ "\npublic atom F(Delta d)\n".
main() -> try run() catch error:{opaque_refinement, L} -> io:format("the declaration itself is refused: opaque_refinement at ~p (residual never reachable)~n", [L]) end.
run() ->
  Pred = "value >= -10 and value <= 10",
  Partial = decl(Pred) ++ "F(0) -> :zero\n",
  D = drv:parse(Partial),
  Res = case bs_check:check(D) of
          {error, [E | _]} -> E;
          Other -> Other
        end,
  Rendered = try lists:flatten(bs_diag:format(bs_diag:descriptor("m.bs", Res))) catch C:R -> {render_failed, C, R} end,
  io:format("clauses given: F(0) only; checker verdict + rendered text:~n~s~n", [Rendered]),
  %% paste back what the residual names, spelled as relational patterns (patterns already take negative literals)
  Full = decl(Pred) ++ "F(>= -10 and <= -1) -> :neg\nF(0) -> :zero\nF(>= 1 and <= 10) -> :pos\n",
  io:format("pasted back as relational patterns: ~p~n", [guards:brief(drv:run(Full))]).
