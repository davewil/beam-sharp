%%% PROTOTYPE 13b — do source-only sub-modules survive into crash reports?
%%%
%%% For ticket 13 §3 (sub-modules are source-only) and prototype 01d, whose sharpest objection
%%% to source-only was: "the structure is a source fiction the runtime does not know about …
%%% a crash names 'Shop.Orders.Order':apply/2 rather than the sub-module the programmer wrote."
%%%
%%% Measured on Erlang/OTP 28.5. THAT OBJECTION IS LARGELY FALSE ON THE ABSTRACT FORMAT PATH.
%%%
%%% The mechanism: {attribute, ANNO, file, {Name, Line}} may appear REPEATEDLY mid-module, and
%%% re-points every form after it. This is how Elixir and LFE attribute generated code back to
%%% original source; on the Abstract Format path beam-sharp inherits it for free.
%%%
%%% Run:  erlc 13b_aggregate_attribution.erl
%%%       erl -noshell -eval '"13b_aggregate_attribution":go(), halt().'
%%%       erlc +from_abstr 'Shop.Orders.Order.abstr'
%%%
%%% OBSERVED — two functions in ONE beam module, reporting against TWO source files:
%%%
%%%   total/1 crash: {'Shop.Orders.Order',total,[99],[{file,"Order/Total.bs"},{line,42}]}
%%%   apply/1 crash: {'Shop.Orders.Order',apply,[99],[{file,"Order/Apply.bs"},{line,7}]}
%%%
%%% Note the line numbers are EXACT — they are whatever the annotation says. Compare the
%%% generated-Erlang-source-text route, where the same effect is achieved with `-file` directives
%%% but the directive occupies the line it names, so every number becomes arithmetic:
%%%
%%%   -file("Order/Total.bs", 42).   %% directive on line 42
%%%   total(1) -> ok.                %% reported as line 43
%%%
%%%   total/1: {'Shop.Orders.Src',total,[99],[{file,"Order/Total.bs"},{line,43}]}
%%%
%%% Both routes preserve -spec. The Abstract Format's advantage is that annotations are set
%%% directly and there is no off-by-one to lose.
%%%
%%% CONSEQUENCE FOR TICKET 13: source-only sub-modules keep per-sub-module observability, so
%%% 01d's remaining cost is only that the compiler owns a module abstraction the BEAM does not
%%% share. Note the repair is TARGET-SPECIFIC: it depends on annotations surviving into the beam,
%%% which is exactly what the Core Erlang path discards (see 13a §2).

-module('13b_aggregate_attribution').
-export([go/0]).

go() ->
    A = fun(L, C) -> erl_anno:new({L, C}) end,
    Forms =
        [{attribute, A(1, 1), file, {"Order/Apply.bs", 1}},
         {attribute, A(1, 2), module, 'Shop.Orders.Order'},
         {attribute, A(2, 2), export, [{apply, 1}, {total, 1}]},

         %% apply/1 — attributed to the Order/Apply.bs sub-module
         {function, A(7, 1), apply, 1,
          [{clause, A(7, 1), [{integer, A(7, 7), 1}], [], [{atom, A(7, 12), ok}]}]},

         %% switch source file: everything after this belongs to the Order/Total.bs sub-module
         {attribute, A(1, 1), file, {"Order/Total.bs", 1}},
         {function, A(42, 1), total, 1,
          [{clause, A(42, 1), [{integer, A(42, 7), 1}], [], [{atom, A(42, 12), ok}]}]},

         {eof, A(50, 1)}],

    %% erlc enforces module-name/filename matching on the from_abstr path too (see 13a §4)
    Txt = [io_lib:format("~p.~n", [F]) || F <- Forms],
    file:write_file("Shop.Orders.Order.abstr", Txt).
