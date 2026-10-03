#!/bin/sh
# Run the PROTOTYPE bsc built by build.sh. Mode via BS52=off|module|app|attr (unset = baseline behaviour).
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
exec erl -noshell -pa ${BS52_EBIN:-/tmp/bs52_proto/ebin} -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra "$@"
