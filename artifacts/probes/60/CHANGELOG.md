# Probe changelog (ticket 60)

Every edit to a probe after its output was first seen is logged here with the reason.
None was made to turn a REFUTED into a CONFIRMED.

- Before the probes were written down: exploratory runs in a scratch dir tried `using :'Shop.Internal' { int RecomputeTotal(...) }`
  (a foreign declaration naming the B# module). It does not parse: foreign function names must be
  lowercase (`foreign_sig -> type_expr lident ...`, bs_parser.yrl), while B# function atoms are uppercase.
  That variant was dropped; only the `:erlang.apply` bypass (p03) is kept. Fixture `Bypass1` deleted.
- p01: a backtick inside a double-quoted `echo` executed `using` as a command. Cosmetic fix of two echo strings. No logic change.
- p02: the beam_lib:info query pattern-matched the wrong shape (info returns a proplist). Fixed to proplists:get_value(chunks, L). Removed a stray no-op line. Claim logic unchanged.
- p02: second fix to the same query: beam_lib:info/1 returns a plain proplist, not {ok,{_,L}}.
- p05: dropped the 'mix new + xref callers' block: it printed nothing and I could not explain why, so it supported no claim. Replaced with the mode list from `mix help xref`.
- p10: verdict used PIPESTATUS of rustc|head and got 141 (SIGPIPE) which happened to be non-zero; changed to capture rustc's own exit code. Outcome unchanged (rustc exit 1).
- p12: first run ran base first and each variant 7x in a row (ordering bias: base median 2644 ms vs patched 2146-2296 ms, i.e. patched FASTER, base spread 2022-3210). Changed to 15 interleaved rounds + beam-hash comparison. The 5%/spread criterion in the header was written before the first run and is unchanged.
- p12: removed the sha256-of-beam-files comparison. The four hashes differed (dc29..., f8fa..., 52a3..., 3bf3...) but the beams embed per-variant output paths, so file hashes cannot show whether emitted code differs. Kept raw first output in out/p12_measure.out.firstrun-before-beam-hash-fix. Replaced by p16 which compares beam_lib:md5/1 (code-and-literals md5) per module.
- p13: the raw-disassembly and the tp/ti counters matched a 6-tuple {function,N,A,_,_,Is}; beam_disasm returns a 5-tuple {function,N,A,Entry,Is} (the first dis() helper had it right and had already printed 1 vs 0 type tests). The first verdict line (REFUTED, with empty counts) was a probe bug, not a result. Fixed the pattern; no threshold changed.
- p12: added the mechanical timing verdict line implementing the 5%/spread criterion that was in the header from the start; no threshold changed. Re-ran p12 alone afterwards.
