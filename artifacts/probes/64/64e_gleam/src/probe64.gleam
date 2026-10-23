//// Probe 64e — can Gleam's API tell "absent" from "present holding the sentinel"
//// when the value type is Gleam's top type, Dynamic?
//// Sentinels stored: the atom `nothing`, the atom `none`, and `Nil` (Gleam's `nil` atom).
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/io
import gleam/option.{type Option, None, Some}

@external(erlang, "erlang", "binary_to_atom")
fn atom(name: String) -> dynamic.Dynamic

fn describe(r: Result(dynamic.Dynamic, Nil)) -> String {
  case r {
    Ok(_) -> "present"
    Error(Nil) -> "absent"
  }
}

fn describe_opt(o: Option(dynamic.Dynamic)) -> String {
  case o {
    Some(_) -> "present"
    None -> "absent"
  }
}

pub fn main() {
  let d =
    dict.from_list([
      #("a", atom("nothing")),
      #("b", atom("none")),
      #("c", dynamic.nil()),
      #("d", dynamic.int(5)),
    ])
  io.println("dict.get over Dict(String, Dynamic):")
  ["a", "b", "c", "d", "zzz"]
  |> list_each(fn(k) { io.println("  " <> k <> " -> " <> describe(dict.get(d, k))) })

  io.println("Option(Dynamic) holding a stored sentinel vs None:")
  io.println("  Some(atom nothing) -> " <> describe_opt(Some(atom("nothing"))))
  io.println("  Some(atom none)    -> " <> describe_opt(Some(atom("none"))))
  io.println("  None               -> " <> describe_opt(None))

  io.println("Option(Option(Int)) keeps both layers apart:")
  let nested: Option(Option(Int)) = Some(None)
  case nested {
    Some(None) -> io.println("  Some(None)  -> outer present, inner absent")
    Some(Some(_)) -> io.println("  Some(Some)  -> both present")
    None -> io.println("  None        -> outer absent")
  }

  io.println("decode.optional_field over a Dynamic map (stdlib's own absent-vs-present at the top type):")
  let dyn = dynamic.properties([#(atom("k"), atom("nothing"))])
  let dec = {
    use v <- decode.optional_field(atom("k"), "DEFAULT", decode.dynamic |> decode.map(fn(_) { "present" }))
    decode.success(v)
  }
  io.println("  key stored as atom nothing -> " <> unwrap(decode.run(dyn, dec)))
  let empty = dynamic.properties([])
  io.println("  key missing                -> " <> unwrap(decode.run(empty, dec)))
}

fn unwrap(r: Result(String, a)) -> String {
  case r {
    Ok(s) -> s
    Error(_) -> "decode error"
  }
}

fn list_each(l: List(a), f: fn(a) -> Nil) -> Nil {
  case l {
    [] -> Nil
    [x, ..rest] -> {
      f(x)
      list_each(rest, f)
    }
  }
}
