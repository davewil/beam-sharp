-module(shadow_noauto).
-compile(no_auto_import_types).
-export([f/1]).
-type integer() :: foo | bar.
-spec f(integer()) -> ok.
f(_) -> ok.
