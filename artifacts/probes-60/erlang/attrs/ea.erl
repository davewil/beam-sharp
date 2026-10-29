-module(ea).
-compile(export_all).
-ignore_xref([{ea,keep,0}]).
-opaque t() :: {t, integer()}.
-export_type([t/0]).
-spec new() -> t().
new() -> {t, 1}.
keep() -> ok.
hidden() -> ok.
