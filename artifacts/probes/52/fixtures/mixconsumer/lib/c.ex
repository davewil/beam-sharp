defmodule C do
  def lib, do: MyLib.new([])
  def otp, do: :ssl.versions()
end
