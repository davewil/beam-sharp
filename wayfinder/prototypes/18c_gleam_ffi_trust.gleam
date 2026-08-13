//// 18c — What a Gleam `@external` declaration is actually worth
////
//// Evidence for ticket 18 §2 and ticket 06's third outcome. Observed locally on
//// Gleam 1.18.1 / OTP 28 (2026-08-13). Two foreign functions are declared with
//// deliberately WRONG types; the Erlang side returns something else entirely.
////
////   gleam new gleamffi --skip-git --skip-github
////   cp 18c_gleam_ffi_trust.gleam gleamffi/src/gleamffi.gleam
////   cp 18c_gleam_ffi_trust.erl   gleamffi/src/probe_ffi.erl
////   cd gleamffi && gleam build
////   cat build/dev/erlang/gleamffi/_gleam_artefacts/gleamffi.erl
////   EB=$(find build -type d -name ebin | tr '\n' ' ')
////   erl $(for d in $EB; do echo -n "-pa $d "; done) -noshell -eval \
////     'io:format("first_id: ~p~nadd_one : ~p~n",[gleamffi:first_id(1),gleamffi:add_one()]),halt().'
////
//// RESULT: it compiles without a warning. The generated Erlang emits a `-spec`
//// asserting the declared type and a body that is a bare pass-through:
////
////     -spec count() -> integer().
////     count() -> probe_ffi:count().
////
////     first_id(1) : <<"7">>    is_integer -> false
////     add_one()   : 42.5       is_integer -> false
////
//// So Gleam trusts the declaration AND publishes the false claim to the
//// ecosystem — a raw Erlang caller running Dialyzer is actively misled.
////
//// The sharper half is `first_id`'s generated consumer:
////
////     case probe_ffi:lookup(Id) of
////         [{order, Oid, _} | _] -> Oid;
////
//// The clause head tested the tag and the arity and bound `Oid` BARE. Ticket
//// 10's forge asymmetry at the FFI site, and the reason "declare anything,
//// check one level deep" fails: that option IS this, with one more tag.

pub type Order {
  Order(id: Int, customer: String)
}

// A foreign function DECLARED to return a list of Orders with an Int id.
// Nothing checked this. The Erlang side returns a binary in the id position.
@external(erlang, "probe_ffi", "lookup")
pub fn lookup(id: Int) -> List(Order)

// A foreign function DECLARED to return an Int. The Erlang side returns a float.
@external(erlang, "probe_ffi", "count")
pub fn count() -> Int

pub fn first_id(id: Int) -> Int {
  case lookup(id) {
    [Order(oid, _), ..] -> oid
    [] -> 0
  }
}

pub fn add_one() -> Int {
  count() + 1
}
