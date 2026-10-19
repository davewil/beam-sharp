defmodule CallerNW do
  @compile {:no_warn_undefined, Req}
  def go, do: Req.get!("http://x")
end
