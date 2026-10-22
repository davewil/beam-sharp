# source me: sets BSC and prints toolchain versions (does not clobber the caller's HERE)
_ENVDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BSC="$("$_ENVDIR/build-bsc-otp25.sh" | tail -1)"
export BSC
echo "# erl OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')  repo HEAD $(git -C "$_ENVDIR" rev-parse --short HEAD 2>/dev/null || echo '?')  bsc=$BSC (OTP-25 scratch build; diagnostic columns not faithful)"
