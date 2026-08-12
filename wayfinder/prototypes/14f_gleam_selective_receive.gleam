import gleam/erlang/process

/// Does a Gleam selective receive LEAVE unmatched messages in the mailbox,
/// or consume them? Run inside one process so the mailbox is observable.
pub fn run() -> #(String, Int, Int) {
  let subject = process.new_subject()

  // Three messages land: two the subject knows nothing about, one it does.
  let me = process.self()
  raw_send(me, "junk-one")
  process.send(subject, "the-one-i-want")
  raw_send(me, "junk-two")

  let before = queue_len(me)

  // Selective receive on the subject only.
  let assert Ok(got) = process.receive(subject, 100)

  let after_ = queue_len(me)
  #(got, before, after_)
}

@external(erlang, "erlang", "send")
fn raw_send(pid: process.Pid, message: String) -> String

@external(erlang, "g14_ffi", "queue_len")
fn queue_len(pid: process.Pid) -> Int

pub fn main() {
  echo run()
}
