%%% Isolates the Spin/Wrap/Hit hot loop from bench_erl.erl, called ONCE with a
%%% large Left count instead of many times through Clicks/Sign/Size/list-fold.
%%% This localises step 1 of ticket 39 §3: is the cost in Spin itself, or in
%%% the outer fold?
-module(spin_isolated).
%% Only run/1 is exported, matching beam-sharp's Day01Isolated where Spin,
%% Wrap and Hit are `private` and only Run is `public` (the language's
%% default is private). This corrected a first version of this harness that
%% exported all four Erlang functions: with spin/4 externally callable, the
%% compiler cannot assume Step is always the literal 1 passed by run/1 (an
%% external caller could pass anything), so it keeps Step in a stack slot
%% across the Wrap/Hit calls. beam-sharp's Spin is never externally callable,
%% so the SAME Erlang compiler can prove Step is always 1 and drop the slot.
%% That was comparing export visibility, not the compilers — exactly the
%% failure mode the benchmark's own README warns about ("measuring my coding
%% style, not the compilers"). Verified below (spin_isolated_export_diff.txt).
-export([run/1]).

wrap(N) -> ((N rem 100) + 100) rem 100.

hit(0) -> 1;
hit(_) -> 0.

spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).

%% One call, Left iterations, matching the 673,364 total clicks the full
%% benchmark simulates across many small spin/4 calls.
run(Left) -> spin(50, 1, Left, 0).
