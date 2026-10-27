# Hypothesis H1: `@moduledoc false` is documentation-only: a hidden module is still callable from anywhere.
# Falsifiable: if Elixir enforced it, calling the hidden stdlib module's function would raise.
IO.puts("Elixir #{System.version()} / OTP #{System.otp_release()}")
{:docs_v1, _, _, _, md, _, _} = Code.fetch_docs(Module.ParallelChecker)
IO.inspect(md, label: "Module.ParallelChecker moduledoc chunk (:hidden = @moduledoc false)")
exports = Module.ParallelChecker.module_info(:exports)
IO.inspect(Enum.take(exports, 4), label: "its exports")
# Kernel.Utils is hidden too; call one of its functions from this unrelated script
{:docs_v1, _, _, _, md2, _, _} = Code.fetch_docs(Kernel.Utils)
IO.inspect(md2, label: "Kernel.Utils moduledoc chunk")
v = Kernel.Utils.announce_struct(String) 
IO.inspect(v, label: "called hidden fn: no error")
