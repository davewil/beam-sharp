#!/usr/bin/env bash
# Re-runs the ticket's own prototype unmodified.
export PATH=$HOME/.nix-profile/bin:$PATH
bash "$(cd "$(dirname "$0")" && pwd)/../../../wayfinder/prototypes/62a_from_the_outside.sh"
