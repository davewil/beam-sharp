# 20e — What `json:encode/1` does with binary shapes

Ticket 16 §4 decreed that the language publishes a serialisation mapping, and generates the
encoder from it, on the strength of a measured fact: `json:encode/1` **fails on tuples at any
depth, at runtime**. Moving that failure to compile time was the whole argument for generation.

Ticket 16 assumed binaries were the safe case. They are not — they fail the same way, and ticket
20 records this as the **fifth** sighting of binaries as where precision dies.

Measured on OTP 28.5, 2026-08-13:

```erlang
iolist_to_binary(json:encode(<<"hello">>))
%% => <<"\"hello\"">>                              works

iolist_to_binary(json:encode(<<255,254,0,1>>))
%% => ** exception: {invalid_byte, 255}            RUNTIME crash
%%    {json, invalid_byte, 2, [{file,"json.erl"},{line,543}]}

iolist_to_binary(json:encode(<<0:9>>))
%% => ** exception: {unsupported_type, <<0,0:1>>}  RUNTIME crash
%%    {json, do_encode, 2, [{file,"json.erl"},{line,203}]}
```

## Why this cannot be fixed inside the O(1) grammar

[`20b`](20b_binary_boundary_guards.erl) established that the whole `<<_:M, _:_*N>>` grammar is
O(1)-guard-decidable, because `byte_size/1` and `bit_size/1` read the term header.

**"Is this binary valid UTF-8?" reads the content.** It is O(n), it is not a guard, it cannot be a
clause head under ticket 11 §2, and it cannot be a foreign declaration under ticket 18 §2. So
text-versus-bytes is not expressible as a *type* in the adopted grammar — it needs narrowing by a
predicate.

## What ticket 20 decided from this

- `string` is `binary` refined by valid-UTF-8, and is the language's first and only O(n)
  refinement. It encodes as a JSON string.
- A bare `binary` encodes as **base64** — total, never fails.
- A non-byte-aligned `bitstring` has **no encoding**, and reaching the encoder with one is a
  compile-time error rather than `unsupported_type` at runtime. This is the same move ticket 16
  §4 made for tuples, applied to the shape 16 overlooked.
- A **literal is a `string` by construction** — the compiler sees the bytes and checks UTF-8 at
  compile time, at zero runtime cost. The generated O(n) entry check exists only for binaries
  built or received at runtime.

## Reproducing

```
erl -noshell -eval '
  io:format("~p~n", [catch iolist_to_binary(json:encode(<<"hello">>))]),
  io:format("~p~n", [catch iolist_to_binary(json:encode(<<255,254,0,1>>))]),
  io:format("~p~n", [catch iolist_to_binary(json:encode(<<0:9>>))]),
  halt().'
```
