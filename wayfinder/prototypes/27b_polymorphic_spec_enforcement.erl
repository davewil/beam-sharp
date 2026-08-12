%%% 27b — Is an emitted polymorphic -spec enforced, or decorative?
%%%
%%% Ticket 13 §6 obliges the compiler to emit a `-spec` for every function whose beam-sharp
%%% type is known, widening to the nearest expressible supertype where a set-theoretic type
%%% has no Erlang spelling. Ticket 27 asks to CONFIRM RATHER THAN ASSUME what a polymorphic
%%% function publishes to the Erlang world.
%%%
%%% Gleam already demonstrates the grammar accepts variables:
%%%   -spec map(list(ACJ), fun((ACJ) -> ACL)) -> list(ACL).
%%% The open question is whether anything downstream CHECKS the relation.
%%%
%%% Measured locally, OTP 28.5, dialyzer against a PLT of erts/kernel/stdlib.
%%%
%%% PROBE (this file, p27b): `-spec map([A], fun((A) -> B)) -> [B].`
%%%   Ys is [binary()] by the variable relation; `hd(Ys) + 1` must be an error.
%%%   RESULT: `done (passed successfully)` — NO WARNING.
%%%
%%% CONTROL (p27c): identical shape with ground types,
%%%   `-spec map_mono([integer()], fun((integer()) -> binary())) -> [binary()].`
%%%   RESULT:
%%%     p27c.erl:8:1: Function misuse_mono/0 has no local return
%%%     p27c.erl:10:5: The call erlang:'+'(binary(), 1) will never return since it differs
%%%                    in the 1st argument from the success typing arguments: (number(), number())
%%%
%%% The control fires, so the probe is sensitive and the negative result is real.
%%%
%%% FINDING: Erlang's spec grammar accepts type variables, but Dialyzer does not enforce the
%%% relation across them — it reads `A` and `B` as `any()`. A polymorphic emitted spec conveys
%%% the relation to a human reader and to nothing else.
%%%
%%% CONSEQUENCES:
%%%
%%% 1. For ticket 13's emission contract: a polymorphic spec is not a widening problem (no
%%%    widening is needed — the grammar has variables), it is an ENFORCEMENT problem. The
%%%    emitted artifact is honest about its shape and inert as a check.
%%%
%%% 2. For ticket 06 / ticket 18: this is a further face of silent unsoundness. A raw Erlang
%%%    caller of a polymorphic beam-sharp function gets no defence from the published spec,
%%%    where a caller of a monomorphic one at least gets a Dialyzer warning if it runs
%%%    Dialyzer. Polymorphism therefore makes the boundary strictly weaker, not neutral.
%%%
%%% 3. It is NOT an argument against polymorphism as such — Dialyzer is opt-in and ticket 06
%%%    already established that neither Gleam nor purerl defends against any of the eight
%%%    channels. It is an argument that the emitted spec must not be counted as boundary
%%%    defence for polymorphic functions when ticket 18 tallies what defences exist.

-module(p27b).
-export([map/2, misuse/0, ok_use/0]).

-spec map([A], fun((A) -> B)) -> [B].
map(Xs, F) -> [F(X) || X <- Xs].

%% map/2 says the result element type is B = binary() here.
%% Adding 1 to a binary must be an error IF the variable relation is enforced. It is not.
misuse() ->
    Ys = map([1,2,3], fun(X) -> integer_to_binary(X) end),
    hd(Ys) + 1.

ok_use() ->
    Ys = map([1,2,3], fun(X) -> integer_to_binary(X) end),
    byte_size(hd(Ys)).
