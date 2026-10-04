%%% PROTOTYPE (ticket 60) -- a `within` declaration restricts who may name a module. Test of the COPY only.
-module(within_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [escript/0, fixture_root/0, place/3, run_cli/1, built/0]).

-define(OUT, bs_test_support:run_root()).

tree(Root, Within) ->
    place(Root, "Rules.bs",
          "module Acme.Orders.Rules\n" ++ Within ++
          "public int Recompute(int x)\nRecompute(x) -> x + 1\n"),
    place(Root, "Orders.bs",
          "module Acme.Orders\nusing Acme.Orders.Rules\n"
          "public int Total(int x)\nTotal(x) -> Recompute(x)\n"),
    place(Root, "Billing.bs",
          "module Acme.Billing\nusing Acme.Orders.Rules\n"
          "public int Invoice(int x)\nInvoice(x) -> Recompute(x)\n"),
    place(Root, "OrdersExtra.bs",
          "module Acme.OrdersExtra\nusing Acme.Orders.Rules\n"
          "public int Sneak(int x)\nSneak(x) -> Recompute(x)\n"),
    place(Root, "Tests.bs",
          "module Acme.Orders.Tests\nusing Acme.Orders.Rules\n"
          "public int Check(int x)\nCheck(x) -> Recompute(x)\n").

run(Root, Mod, Arg) ->
    run_cli("--src-root " ++ Root ++ " -o " ++ ?OUT ++ " " ++ Root ++ "/" ++ Mod ++ " " ++ Arg).

said(Out, Frag) -> ?assertNotEqual(nomatch, string:find(Out, Frag), {Frag, Out}).

%% unrestricted: everyone may name it (today's behaviour, unchanged)
no_within_means_anyone_may_name_it_test() ->
    case built() of
        false -> ok;
        true ->
            Root = fixture_root() ++ "/within0",
            tree(Root, ""),
            said(run(Root, "Acme/Billing", "1"), "rc:0")
    end.

a_sibling_is_refused_at_its_using_line_test() ->
    case built() of
        false -> ok;
        true ->
            Root = fixture_root() ++ "/within1",
            tree(Root, "within Acme.Orders\n"),
            Out = run(Root, "Acme/Billing", "1"),
            said(Out, "`using Acme.Orders.Rules`"),
            said(Out, "declared `within Acme.Orders`"),
            said(Out, "rc:1")
    end.

the_parent_and_a_descendant_may_name_it_test() ->
    case built() of
        false -> ok;
        true ->
            Root = fixture_root() ++ "/within2",
            tree(Root, "within Acme.Orders\n"),
            said(run(Root, "Acme/Orders", "1"), "rc:0"),
            said(run(Root, "Acme/Orders/Tests", "1"), "rc:0")
    end.

%% a string prefix is not a segment prefix
acme_ordersextra_is_not_inside_acme_orders_test() ->
    case built() of
        false -> ok;
        true ->
            Root = fixture_root() ++ "/within3",
            tree(Root, "within Acme.Orders\n"),
            said(run(Root, "Acme/OrdersExtra", "1"), "rc:1")
    end.

a_within_that_does_not_contain_its_own_module_is_refused_test() ->
    case built() of
        false -> ok;
        true ->
            Root = fixture_root() ++ "/within4",
            tree(Root, "within Acme.Billing\n"),
            Out = run(Root, "Acme/Orders/Rules", "1"),
            said(Out, "does not contain"),
            said(Out, "rc:1")
    end.
