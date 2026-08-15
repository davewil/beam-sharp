%%% What the compiler knows about OTP behaviours — ticket 35, resolved 2026-08-15.
%%%
%%% TWO TABLES, ONE HOME. The behaviour NAME already lowered through a fixed
%%% table of five (`'GenServer' -> gen_server`), settled by ticket 32 and living
%%% in `bs_emit`. Ticket 35 is that construct one level down: the callback names.
%%% They are siblings and they belong together, because the thing that would rot
%%% if they were apart is the pairing — a behaviour whose name the compiler knows
%%% and whose callbacks it does not is exactly the state that broke `spec-check`.
%%%
%%% Both the checker and the emitter read from here, which is why this is its own
%%% module rather than an export from either. `bs_check` asks whether the declared
%%% callbacks are present; `bs_emit` asks what each one lowers to. One table, and
%%% no second place for the answer to live — the same rule F5 applied when it
%%% exported `resolve/2` rather than letting the emitter keep a copy.
%%%
%%% A TABLE, NOT A RULE, AND THE DISTINCTION IS LOAD-BEARING. Ticket 32 measured
%%% that a snake_case<->PascalCase derivation reaches 1,920 of 1,924 stdlib+kernel
%%% names and cannot spell `'PKCS-1'`, `'OTP-PKIX'`, or a quarter of Elixir's
%%% function names — so the language has no such rule anywhere and this does not
%%% introduce one. Every row below is written out by hand. That the rows happen to
%%% look like a pattern is a property of OTP's own naming, not a function the
%%% compiler applies, and nothing here can be extended by inference.
%%%
%%% AND IT IS CONTRACT-SCOPED, which is what answers 35's own objection that
%%% renaming would be "a naming rule by another route". A row fires only for a
%%% function whose name AND arity match a callback of a behaviour THIS MODULE
%%% DECLARES. `HandleCall/3` in a module with no `behaviour` line stays
%%% `'HandleCall'/3`, and so does `HandleCall/2` in a module that declares
%%% `GenServer` — the arity is part of the key precisely so a helper that happens
%%% to share a callback's name is not silently captured.

-module(bs_otp).

-export([behaviour_name/1, callbacks/1, callback_name/3, missing/2]).

%%% ---------------------------------------------------------------------------
%%% The behaviour name — ticket 32, unchanged, moved here from `bs_emit`
%%% ---------------------------------------------------------------------------

behaviour_name('GenServer')   -> gen_server;
behaviour_name('Supervisor')  -> supervisor;
behaviour_name('Application') -> application;
behaviour_name('GenStatem')   -> gen_statem;
behaviour_name('GenEvent')    -> gen_event;
behaviour_name(Other)         -> erlang:error({unknown_behaviour, Other}).

%%% ---------------------------------------------------------------------------
%%% The callback table
%%%
%%% `{B# name, arity, OTP name, mandatory | optional}`.
%%%
%%% The mandatory/optional split is OTP's own and was read off the runtime rather
%%% than written from memory: `M:behaviour_info(callbacks) -- M:behaviour_info(
%%% optional_callbacks)`, measured on OTP 28.
%%% ---------------------------------------------------------------------------

callbacks('GenServer') ->
    [{'Init',           1, init,            mandatory},
     {'HandleCall',     3, handle_call,     mandatory},
     {'HandleCast',     2, handle_cast,     mandatory},
     {'HandleInfo',     2, handle_info,     optional},
     {'HandleContinue', 2, handle_continue, optional},
     {'Terminate',      2, terminate,       optional},
     {'CodeChange',     3, code_change,     optional},
     {'FormatStatus',   1, format_status,   optional},
     {'FormatStatus',   2, format_status,   optional}];
callbacks('Supervisor') ->
    [{'Init', 1, init, mandatory}];
callbacks('Application') ->
    [{'Start',        2, start,         mandatory},
     {'Stop',         1, stop,          mandatory},
     {'ConfigChange', 3, config_change, optional},
     {'PrepStop',     1, prep_stop,     optional},
     {'StartPhase',   3, start_phase,   optional}];
%% `gen_statem` lists `{'StateName',3}` among its callbacks, and it is
%% DELIBERATELY ABSENT here. That entry is OTP's placeholder for state functions
%% in `state_functions` mode, whose names are the *user's* — so they are ordinary
%% beam-sharp functions and must not lower. A table of known names cannot contain
%% a name nobody knows yet, and pretending otherwise is the derivation rule
%% ticket 32 closed, arriving through the one door left open.
callbacks('GenStatem') ->
    [{'Init',         1, init,          mandatory},
     {'CallbackMode', 0, callback_mode, mandatory},
     {'HandleEvent',  4, handle_event,  optional},
     {'Terminate',    3, terminate,     optional},
     {'CodeChange',   4, code_change,   optional},
     {'FormatStatus', 1, format_status, optional},
     {'FormatStatus', 2, format_status, optional}];
callbacks('GenEvent') ->
    [{'Init',         1, init,          mandatory},
     {'HandleEvent',  2, handle_event,  mandatory},
     {'HandleCall',   2, handle_call,   mandatory},
     {'HandleInfo',   2, handle_info,   optional},
     {'Terminate',    2, terminate,     optional},
     {'CodeChange',   3, code_change,   optional},
     {'FormatStatus', 1, format_status, optional},
     {'FormatStatus', 2, format_status, optional}];
callbacks(Other) ->
    erlang:error({unknown_behaviour, Other}).

%% What `Name/Arity` lowers to, given the behaviours this module declares, or
%% `none` when it is an ordinary function. Both halves of the key matter — see
%% the contract-scoping note at the top.
callback_name(_Name, _Arity, []) ->
    none;
callback_name(Name, Arity, [B | Rest]) ->
    case [Otp || {N, A, Otp, _} <- callbacks(B), N =:= Name, A =:= Arity] of
        [Otp | _] -> Otp;
        []        -> callback_name(Name, Arity, Rest)
    end.

%% The mandatory callbacks of `Behaviour` that `Defined` does not supply, as
%% `{B# name, arity}` — the spelling the author must write, not OTP's.
%%
%% Ticket 14 §4 makes the compiler know the contract as a TYPE and check the
%% user's narrower signature by containment. This is the presence half only. The
%% type half is not owed here: Dialyzer already performs it at the boundary
%% against OTP's own `-callback` declarations, measured — a narrowed callback
%% spec is accepted and a wrong one is still reported `Invalid type
%% specification`.
missing(Behaviour, Defined) ->
    [{N, A} || {N, A, _, mandatory} <- callbacks(Behaviour),
               not lists:member({N, A}, Defined)].
