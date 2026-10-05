# Probe changelog (ticket 52)

Rule: a probe is never edited after seeing its output merely to make it pass. Every edit is logged here with why.
Dates are the single session of 2026-10-05; ordering is the order the edits were made.

1. `00-fixtures.sh` / `fixtures/mylib`: first version of `lib/my_lib.ex` defined `MyLib.Request` AFTER its use, mix
   refused (compile error, no output of interest). Reordered. Later (before any probe of option programs ran)
   `MyLib.Request.method/1` was added so ShopA/B/C can call a second module of the same app.
2. `02-codepath-queries.sh` / `codepath.escript`: first run truncated columns (`~-9s` clipping `crypto-5.8.3`) and
   printed `application:load` errors as integer lists. Formatting only; the table is the same data. Widened columns, printed
   the error with `~s`. No query was added or removed.
3. `04-build-patched-bsc.sh`: `/usr/bin/time` does not exist here; replaced by `date`/`bc`. The patch itself was
   regenerated twice BEFORE `05` was first run, adding the two env-var hooks `BS_PROTO_CHECK_MODULES` (variant C) and
   `BS_PROTO_STRONG` (module must be found inside the declared app). Both are off by default.
4. `06-size-and-cost.sh`: first run failed because bsc requires module name == directory name (`module Req10` in
   `gen/none/`). Moved sources to `gen/<mode>/Req10/`. Added the "for scale" block of the repo's example beam sizes after
   the first result showed a LARGE relative delta on a tiny module; that block is context, not a change of method.
5. `07-corpus-census.sh`: a backtick inside a double-quoted `echo` was executed by the shell (printed `using: command not
   found`). Quoted properly. Part (c) was added after (a) and (b) showed the hook refuses nothing in `compiler/examples`:
   I went looking for a shipped program it WOULD refuse, found the LANGUAGE.md block, and report (a)/(b) as they were.
6. `08-ecosystem-readers.sh`: (i) the xref filter used `;` inside a list-comprehension filter (erl syntax error); the filter
   was dropped and the whole report printed. (ii) xref over `mylib/ebin` failed with `missing_backend elixir_erl`; Elixir's
   own ebin was put on the path. (iii) the systools release first failed with `undefined_applications [elixir]` then
   `[compiler]` because MY release spec was incomplete (mylib's .app lists them); added both to the .rel. None of the three
   changed what is being asked (does a tool read `bs_requires`).  `PLT_CACHE` env var added for iteration speed; unset by default.
7. `09-erlang-and-rebar3.sh`: stripped the sandbox's proxy banner and ANSI colour from rebar3 output (display only).
8. `15-surface-today.sh`: the first grep line printed `head`'s exit code, not grep's; replaced with a `grep -c` count.
9. `17-otp-app-names.sh`: corrected the label of the corpus count (it greps `.bs` files only, not LANGUAGE.md).
10. `05-patched-behaviour.sh` / `fixtures/bs/ShopBLie`: added AFTER the first full run, once the per-using "wrong app" case (ShopLie)
    had been seen, to ask the symmetric question of the per-module form. Its result (compiles, then undef) was not known when it
    was written. Also `07` part (c), `15` native-using control: added after the first runs, same reason.
11. `run.sh` first full run: all 18 scripts exit 0. `16-prototype-suite` is skipped by default; its one recorded run
    (RUN_EUNIT=1, 227 passed / 1 failed on BOTH the patched and the unpatched copy) is in `recorded/`.
