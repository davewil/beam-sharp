import gleam/erlang/process.{type Pid, type Subject}
import gleam/io
import gleam/otp/actor
import gleam/string

pub type Request {
  Get(reply: Subject(Int))
  Add(n: Int, reply: Subject(Int))
}

fn handle(state: Int, msg: Request) -> actor.Next(Int, Request) {
  case msg {
    Get(reply) -> {
      process.send(reply, state)
      actor.continue(state)
    }
    Add(n, reply) -> {
      process.send(reply, state + n)
      actor.continue(state + n)
    }
  }
}

@external(erlang, "erlang", "send")
fn raw_send(pid: Pid, msg: a) -> a

pub fn main() {
  let assert Ok(started) =
    actor.new(5) |> actor.on_message(handle) |> actor.start
  let subject = started.data
  let pid = started.pid
  io.println("get = " <> string.inspect(process.call(subject, 1000, Get)))
  raw_send(pid, #("bogus", 1))
  process.sleep(100)
  io.println("after raw send: alive=" <> string.inspect(process.is_alive(pid)))
  io.println("get again = " <> string.inspect(process.call(subject, 1000, Get)))
}
