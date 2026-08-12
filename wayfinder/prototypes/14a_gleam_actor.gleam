import gleam/erlang/process.{type Subject}
import gleam/otp/actor

pub type Msg {
  Push(String)
  Pop(reply: Subject(String))
}

fn handle(state: List(String), msg: Msg) -> actor.Next(List(String), Msg) {
  case msg {
    Push(x) -> actor.continue([x, ..state])
    Pop(client) -> {
      case state {
        [x, ..rest] -> {
          process.send(client, x)
          actor.continue(rest)
        }
        [] -> {
          process.send(client, "empty")
          actor.continue(state)
        }
      }
    }
  }
}

/// Started from Erlang so the raw-message probe can address the pid.
pub fn boot() -> Subject(Msg) {
  let assert Ok(started) =
    actor.new([]) |> actor.on_message(handle) |> actor.start
  started.data
}

pub fn main() {
  let subject = boot()
  process.send(subject, Push("joe"))
  echo process.call(subject, 10, Pop)
}

/// A named actor: Gleam's own remedy for "don't pass subjects around".
pub fn boot_named() -> process.Name(Msg) {
  let name = process.new_name("stack")
  let assert Ok(_) =
    actor.new([]) |> actor.on_message(handle) |> actor.named(name) |> actor.start
  name
}
