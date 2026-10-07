%% Prototype of the *checker delta* for ticket 60, over module-name atoms only.
%% Not wired into compiler/ (forbidden); this is the body add_import would call.
-module(may_name).
-export([internal_rule/2, declared_rule/3, segs/1]).

segs(M) -> string:split(atom_to_list(M), ".", all).

%% Option A (path-derived, Go's rule): the LAST segment named "Internal" fixes the parent;
%% only modules whose path starts with that parent (whole segments) may name it.
internal_rule(Importer, Callee) ->
    CS = segs(Callee),
    case [I || {I, "Internal"} <- lists:zip(lists:seq(1, length(CS)), CS)] of
        []  -> allowed;
        Is  -> Parent = lists:sublist(CS, lists:last(Is) - 1),
               case lists:prefix(Parent, segs(Importer)) of true -> allowed; false -> refused end
    end.

%% Option B (callee-declared): Allowed is a list of module paths read from the callee's header.
declared_rule(_Importer, _Callee, any) -> allowed;
declared_rule(Importer, _Callee, Allowed) ->
    IS = segs(Importer),
    case lists:any(fun(A) -> lists:prefix(segs(A), IS) end, Allowed) of true -> allowed; false -> refused end.
