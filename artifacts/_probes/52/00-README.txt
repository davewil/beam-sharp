Probes for ticket 52 — dependency provenance. All commands run against a
scratch copy of the compiler at /tmp/ticket52-scratch/compiler; the tracked
tree at /home/user/beam-sharp/compiler was never edited (see git status output
in this directory, and the *.diff files, which are diffs FROM the tracked tree
TO the scratch copy, kept for the record only).

Environment: OTP 28.5 built at /opt/otp28-src (BUILD_DONE, verified with
`erlang:system_info(otp_release)` -> "28"). bsc built with
`PATH=/opt/otp28-src/bin:$PATH; cd <compiler>; rebar3 escriptize`, landing at
<compiler>/_build/default/bin/bsc. Elixir: apt's 1.14.0 (erlang-base 25.3)
does NOT run under OTP 28 (see 03-apt-elixir-otp28-incompatible.txt) — a
genuine, measured environment fact, not assumed. Elixir 1.19.5 precompiled
for OTP 28 was fetched directly from GitHub releases
(https://github.com/elixir-lang/elixir/releases/download/v1.19.5/elixir-otp-28.zip,
HTTP 200) and used instead; this is a REAL, genuinely-present Elixir
installation, not a fake. hex.pm was tried once for `mix deps.get` on Req and
403'd through the proxy (see 03b) — not retried, per instructions.
