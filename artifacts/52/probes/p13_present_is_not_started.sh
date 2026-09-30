#!/usr/bin/env bash
# p13: "on the code path" is not "running".  `ticker` is an OTP application whose API needs its process.
# Code path: /tmp/fakelibs52b (built by brief.md Reproduce).  Does declaring/locating the app make Cold() work?
cd "$(dirname "$0")"
export ERL_LIBS=/tmp/fakelibs52b
echo '--- Cold(): ticker on the path, never started'
./bsc.sh --src-root programs programs/Tick Cold; echo "exit=$?"
echo '--- Warm(): the program starts the application itself (as 51a/Req.bs Start() does), then calls'
./bsc.sh --src-root programs programs/Tick Warm; echo "exit=$?"
