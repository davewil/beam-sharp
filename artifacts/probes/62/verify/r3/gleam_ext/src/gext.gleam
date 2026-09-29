// PROBE 7 — Gleam 1.12 calling the PascalCase B# export 'Api':'New'/1 and 'Api':'Get_X'/1 for real.
// The Api beam is put on the code path via ERL_LIBS at RUN time (run.sh).
//
// EXPECTED (before run): compiles; `gleam run` prints
//   new: #{'Id' => 1,'Kind' => 'Api.Order','Total' => 0}
//   get_x_pascal: 4
// i.e. Gleam is unaffected by PascalCase because the function name is a string.
@external(erlang, "Api", "New")
fn api_new(id: Int) -> a

@external(erlang, "Api", "Get_X")
fn api_get_x(x: Int) -> Int

@external(erlang, "io", "format")
fn format(fmt: String, args: List(a)) -> b

pub fn main() {
  let _ = format("new: ~p~n", [api_new(1)])
  let _ = format("get_x_pascal: ~p~n", [api_get_x(1)])
  Nil
}
