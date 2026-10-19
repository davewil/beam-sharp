defmodule Caller do
  def go, do: Req.get!("http://x")
end
