-module(c).
-export([h/0]).
-include_lib("public_key/include/public_key.hrl").   %% real app: resolves via code:lib_dir/1
h() -> #'RSAPublicKey'{modulus = 1, publicExponent = 3}.
