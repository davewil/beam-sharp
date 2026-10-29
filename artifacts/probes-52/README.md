Ticket 52 probes. claim -> probe:
p1_missing.erl/p1_out.txt   run-time shape of a missing dep (undef, code:which, ensure_loaded, application:load/ensure_all_started, fake app naming a ghost dep + control)
p2_erlang/proj + p2_rebar3_out.txt   rebar3 compile passes, xref flags missing module but not unlisted-app (ssl)
p2_erlang/rel/rel.erl + p2_systools_out.txt   systools checks .app `applications` at release build
p2_elixir/ + p2_mix_out.txt, p2_mix_out2.txt   mix: undefined-module warning vs app-not-depended warning; control (extra_applications); ERL_LIBS-only case
p2_gleam/ + p2_gleam_out.txt   gleam: import needs [dependencies]; @external module unchecked
p3/p3_map.erl p3_out.txt       module->app for real installed Elixir/OTP modules (premise test)
p3/mkfix.sh, p3b_escript_out.txt, p3c_fixtures.erl p3c_out.txt, p3d_two_roots.txt, p3e_dirname_vs_appname.txt   failure cases: escript, dup, orphan, unlisted, dir!=app
p4/p4_cost.erl p4_out.txt (p4_out_rerun.txt)   microsecond cost; p4/p4b.erl p4b_out.txt  .beam bytes for a -bs_requires attribute
Re-run: see Probe index in the brief.
