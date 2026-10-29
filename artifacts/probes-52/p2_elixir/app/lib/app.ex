defmodule App do
  def a, do: Widget.Thing.new(1)        # module from app widget_core (name != module prefix)
  def b, do: Ghost.Nothing.f()          # module that exists nowhere
  def c, do: :ssl.start()               # real OTP app, not in extra_applications
  def d, do: Mix.Task.run("x")          # elixir-shipped app 'mix', not in extra_applications
end
