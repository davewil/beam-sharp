%%% What the compiler knows about OTP behaviours: the five behaviour names it
%%% lowers and the callbacks of each (ticket 32, ticket 35).
%%%
%%% Both tables live here and nowhere else. `bs_check` asks which declared
%%% callbacks are missing; `bs_emit` asks what a behaviour and each callback
%%% lower to. A behaviour whose name the compiler knows but whose callbacks it
%%% does not is the state that would rot if the two tables were apart.
%%%
%%% These are tables, not a naming rule. A snake_case<->PascalCase derivation
%%% reaches 1,920 of 1,924 stdlib+kernel names and cannot spell `'PKCS-1'` or
%%% `'OTP-PKIX'`, so the language has no such rule (ticket 32). Every row is
%%% written out by hand and nothing here is extended by inference.
%%%
%%% Callback renaming is contract-scoped: a row fires only for a function whose
%%% name AND arity match a callback of a behaviour this module declares.
%%% `HandleCall/3` in a module with no `behaviour` line stays `'HandleCall'/3`,
%%% and so does `HandleCall/2` in a module that declares `GenServer`, so a
%%% helper that shares a callback's name is never silently captured.

-module(bs_otp).

-export([behaviour_name/1, callbacks/1, callback_name/3, missing/2]).

%%% ---------------------------------------------------------------------------
%%% The behaviour name (ticket 32)
%%% ---------------------------------------------------------------------------

behaviour_name('GenServer')   -> gen_server;
behaviour_name('Supervisor')  -> supervisor;
behaviour_name('Application') -> application;
behaviour_name('GenStatem')   -> gen_statem;
behaviour_name('GenEvent')    -> gen_event;
behaviour_name(Other)         -> erlang:error({unknown_behaviour, Other}).

%%% ---------------------------------------------------------------------------
%%% The callback table: `{B# name, arity, OTP name, mandatory | optional}`.
%%%
%%% The mandatory/optional split is OTP's own, read from
%%% `M:behaviour_info(callbacks) -- M:behaviour_info(optional_callbacks)` on
%%% OTP 28.
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
%% `gen_statem`'s `{'StateName',3}` is deliberately absent: it is OTP's
%% placeholder for state functions, whose names are the user's own, so they
%% stay ordinary beam-sharp functions and must not lower.
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
%% `none` when it is an ordinary function. Both name and arity must match.
callback_name(_Name, _Arity, []) ->
    none;
callback_name(Name, Arity, [B | Rest]) ->
    case [Otp || {N, A, Otp, _} <- callbacks(B), N =:= Name, A =:= Arity] of
        [Otp | _] -> Otp;
        []        -> callback_name(Name, Arity, Rest)
    end.

%% The mandatory callbacks of `Behaviour` that `Defined` does not supply, as
%% `{B# name, arity}`: the spelling the author must write, not OTP's.
%%
%% Presence only. The type half of the contract (ticket 14 §4) is left to
%% Dialyzer, which checks a narrowed callback spec against OTP's own
%% `-callback` declarations at the boundary.
missing(Behaviour, Defined) ->
    [{N, A} || {N, A, _, mandatory} <- callbacks(Behaviour),
               not lists:member({N, A}, Defined)].
