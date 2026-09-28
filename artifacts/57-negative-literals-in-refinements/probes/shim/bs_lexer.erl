%% PROBE SHIM, not the compiler's lexer. bs_check:pasted_signature/1 re-lexes a corrected-signature text
%% with bs_lexer:string/1 (bs_check.erl:2298); the real lexer cannot be built on OTP 25. This forwards to lex_mini.
-module(bs_lexer).
-export([string/1]).
string(S) -> {ok, lex_mini:tokens(S), 1}.
