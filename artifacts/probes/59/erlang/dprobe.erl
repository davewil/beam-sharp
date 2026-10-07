-module(dprobe).
-export([nested/1, bad_local/0, pub_inc/1, bad_pub/0, ok_pass/1]).
%% private: guarded by hand
inc(N) when is_integer(N) -> N + 1.
%% private: unguarded, arithmetic only
inc_bare(N) -> N + 1.

nested(#{count := C}) -> inc(C).          %% forged float arrives here at runtime; dialyzer cannot know
ok_pass(X) -> inc_bare(X).
bad_local() -> inc(a).                    %% literal wrong kind to a PRIVATE guarded fn
pub_inc(N) when is_integer(N) -> N + 1.
bad_pub() -> dprobe:pub_inc(a).           %% literal wrong kind to an EXPORTED guarded fn (remote call)
