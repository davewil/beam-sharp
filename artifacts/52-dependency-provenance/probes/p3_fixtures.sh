#!/bin/sh
# Builds the fixture library directories used by p3. Shapes:
#   libA/app_a-1.0/ebin   app_a.app (modules a_mod, shared)   -- rebar3/OTP style, versioned dir
#   libB/app_b-2.0/ebin   app_b.app (modules b_mod, shared)   -- SAME module name `shared` as app_a, different code
#   libC/app_c/ebin       app_c.app                            -- mix/_build style, unversioned dir
#   libD/app_d-1.0/ebin   d_mod.beam and NO .app file          -- "ebin without an app file"
#   loose/                loose_mod.beam, not in any app dir     -- module in a non-app directory
#   libE/foo-1.0/ebin     bar.app (app name != dir name), module e_mod
cd "$(dirname "$0")"; W=work/p3; rm -rf $W; mkdir -p $W; cd $W
mkmod() { mkdir -p $1;
  printf -- '-module(%s).\n-export([v/0]).\nv() -> %s.\n' "$2" "$3" > $1/$2.erl; (cd $1 && erlc $2.erl && rm $2.erl); }
mkapp() { mkdir -p $1;
  printf '{application,%s,[{description,"fixture"},{vsn,"%s"},{modules,[%s]},{registered,[]},{applications,[kernel,stdlib%s]}]}.\n' "$2" "$3" "$4" "$5" > $1/$2.app; }
mkmod libA/app_a-1.0/ebin a_mod 1;  mkmod libA/app_a-1.0/ebin shared from_a; mkapp libA/app_a-1.0/ebin app_a 1.0 "a_mod,shared" ""
mkmod libB/app_b-2.0/ebin b_mod 2;  mkmod libB/app_b-2.0/ebin shared from_b; mkapp libB/app_b-2.0/ebin app_b 2.0 "b_mod,shared" ",app_a"
mkmod libC/app_c/ebin c_mod 3;      mkapp libC/app_c/ebin app_c 0.3.0 "c_mod" ""
mkmod libD/app_d-1.0/ebin d_mod 4
mkmod loose loose_mod 5
mkmod libE/foo-1.0/ebin e_mod 6;    mkapp libE/foo-1.0/ebin bar 1.0 "e_mod" ""
ls -R . | head -60
