#!/bin/sh
# usage: bsc-with.sh EBIN <bsc args...>
ebin=$1; shift
exec erl -noshell -pa "$ebin" -eval 'bsc:main(init:get_plain_arguments()),halt().' -extra "$@"
