#!/usr/bin/env bash
# 23a — What diagnostic channels does the platform already give beam-sharp?
#
# Ticket 23 asks whether diagnostics should have a machine-readable form. Before
# designing one, measure what OTP already does — at compile time, in the emitted
# artefact, and at runtime. Every claim marked [L*] in issue 23 comes from here.
#
# Run:  ./23a_otp_diagnostic_channels.sh          (OTP 28.5 when measured)
set -u
cd "$(mktemp -d)" || exit 1
echo "=== OTP: $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]), halt().') ==="

echo
echo "--- §1  compile-time: the diagnostic is a term, prose is derived from it ---"
cat > bad.erl <<'EOF'
-module(bad).
-export([f/1]).
f(X) -> Y + 1.
EOF
erl -noshell -eval '
R = compile:file("bad.erl", [return_errors, return_warnings, binary]),
io:format("term:     ~p~n", [R]),
{error, Es, _} = R,
[io:format("rendered: ~ts~n", [M:format_error(D)]) || {_F,Ds} <- Es, {_L,M,D} <- Ds],
halt().'

echo
echo "--- §2  ...and erlc publishes none of it: no flag recovers the term ---"
erlc -h 2>&1 | grep -icE 'json|diagnostic|machine' | sed 's/^/matching flags: /'

echo
echo "--- §3  what OTP promises: the envelope, not the payload ---"
erl -noshell -eval '
D = shell_docs:render(compile, file, element(2, code:get_doc(compile))),
S = unicode:characters_to_list(D),
case string:find(S, "structure has the following format") of
  nomatch -> io:format("not found~n");
  T -> io:format("~ts~n", [string:trim(string:slice(T, 0, 84))])
end, halt().' | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^ *$'

echo
echo "--- §4  the emitted artefact publishes what was compiled, verbatim ---"
cat > sample.erl <<'EOF'
-module(sample).
-export([classify/1]).
-spec classify({ok, integer()} | {error, atom()}) -> atom().
classify({ok, N}) when N > 0 -> positive;
classify({ok, _})            -> other;
classify({error, _})         -> unknown.
EOF
erlc +debug_info sample.erl
erl -noshell -eval '
{ok,{_,[{abstract_code,{_,Fs}}]}} = beam_lib:chunks("sample.beam",[abstract_code]),
io:format("exports: ~p~n", [sample:module_info(exports)]),
[io:format("~s", [erl_pp:attribute(A)]) || A <- Fs, element(1,A)=:=attribute, element(3,A)=:=spec],
[io:format("~s", [erl_pp:function(F)]) || F <- Fs, element(1,F)=:=function],
halt().'
echo "  (beam_lib:strip/1 removes this chunk; a stripped release answers nothing)"

echo
echo "--- §5  json ships in stdlib, and refuses tuples ---"
erl -noshell -eval '
io:format("json module: ~s~n", [code:which(json)]),
io:format("maps/lists:  ~ts~n", [json:encode(#{inexhaustive => #{ints => [[-1]]}})]),
try io:format("tuple:      ~ts~n", [json:encode(#{residual => {neg_inf,-1}})])
catch _:E -> io:format("tuple:       REFUSED ~p~n", [E]) end,
halt().'

echo
echo "--- §6  runtime: error_info carries a structured cause, format_error/2 renders it ---"
cat > einfo.erl <<'EOF'
-module(einfo).
-export([boundary/1, format_error/2, go/0]).

%% What a compiler-emitted boundary rejection could raise.
boundary(V) ->
    erlang:error(badarg, [V],
                 [{error_info, #{module => ?MODULE, cause => #{1 => rejected}}}]).

format_error(_Reason, [{_M,_F,[V],Info}|_]) ->
    #{cause := C} = proplists:get_value(error_info, Info, #{}),
    #{1 => io_lib:format("expected (:ok, int), got ~p (~p)", [V, maps:get(1, C)])}.

go() ->
    try boundary({error, oops})
    catch error:R:S ->
        io:format("class/reason: error:~p~n", [R]),
        [{M,F,A,I} | _] = S,
        io:format("frame:        ~p~n", [{M,F,A,I}]),
        io:format("rendered:     ~ts~n", [maps:get(1, M:format_error(R, S))])
    end.
EOF
erlc einfo.erl && erl -noshell -pa . -eval 'einfo:go(), halt().'

echo
echo "=== summary ==="
echo "  compile time : term + format_error   — built, then discarded at the CLI"
echo "  artefact     : abstract_code chunk   — faithful, Erlang's vocabulary, strippable"
echo "  runtime      : error_info + /2       — structured cause, since OTP 24"
