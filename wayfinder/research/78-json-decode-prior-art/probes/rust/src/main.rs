use serde::Deserialize;
use std::collections::BTreeMap;

#[derive(Debug, Deserialize)] #[allow(dead_code)]
struct Addr { city: String, zip: u32 }
#[derive(Debug, Deserialize)] #[allow(dead_code)]
struct User { name: String, age: u8, nick: Option<String>, addrs: Vec<Addr> }
#[derive(Debug, Deserialize)] #[serde(deny_unknown_fields)] #[allow(dead_code)]
struct Strict { a: i32 }
#[derive(Debug, Deserialize)] #[allow(dead_code)]
struct Extras { a: i32, #[serde(flatten)] rest: BTreeMap<String, serde_json::Value> }
#[derive(Debug, Deserialize)] #[allow(dead_code)]
struct Dflt { a: i32, #[serde(default)] b: i32 }
#[derive(Debug, Deserialize)] #[allow(dead_code)]
struct DblOpt { #[serde(default)] a: Option<Option<i32>> }

#[derive(Debug, Deserialize)] #[allow(dead_code)]
enum Ext { Circle { r: f64 }, Square { side: f64 }, Unit }
#[derive(Debug, Deserialize)] #[serde(tag = "type")] #[allow(dead_code)]
enum Int { Circle { r: f64 }, Square { side: f64 } }
#[derive(Debug, Deserialize)] #[serde(tag = "t", content = "c")] #[allow(dead_code)]
enum Adj { Circle { r: f64 }, Square { side: f64 } }
#[derive(Debug, Deserialize)] #[serde(untagged)] #[allow(dead_code)]
enum Unt { Circle { r: f64 }, Square { side: f64 } }
#[derive(Debug, Deserialize)] #[allow(dead_code)]
struct Holder { shapes: Vec<Int> }
#[derive(Debug, Deserialize)] #[allow(dead_code)]
struct HolderU { shapes: Vec<Unt> }

fn show<T: std::fmt::Debug + serde::de::DeserializeOwned>(label: &str, s: &str) {
    match serde_json::from_str::<T>(s) {
        Ok(v) => println!("[{label}] {s}\n    OK  {v:?}"),
        Err(e) => println!("[{label}] {s}\n    ERR {e}\n        category={:?} line={} column={}", e.classify(), e.line(), e.column()),
    }
}
fn path<T: std::fmt::Debug + serde::de::DeserializeOwned>(label: &str, s: &str) {
    let de = &mut serde_json::Deserializer::from_str(s);
    match serde_path_to_error::deserialize::<_, T>(de) {
        Ok(v) => println!("[{label}/path_to_error] {s}\n    OK  {v:?}"),
        Err(e) => println!("[{label}/path_to_error] {s}\n    ERR display={e}\n        path={} inner={}", e.path(), e.inner()),
    }
}

fn main() {
    println!("== A unknown keys");
    show::<Dflt>("A1 default ignore", r#"{"a":1,"zzz":2}"#);
    show::<Strict>("A2 deny_unknown_fields", r#"{"a":1,"zzz":2}"#);
    show::<Extras>("A3 flatten capture", r#"{"a":1,"zzz":2,"y":[1]}"#);
    println!("== B missing field");
    show::<User>("B1 missing age", r#"{"name":"x","addrs":[]}"#);
    show::<User>("B2 missing nested zip", r#"{"name":"x","age":1,"addrs":[{"city":"a","zip":1},{"city":"b"}]}"#);
    path::<User>("B2", r#"{"name":"x","age":1,"addrs":[{"city":"a","zip":1},{"city":"b"}]}"#);
    show::<Dflt>("B3 serde(default)", r#"{"a":1}"#);
    println!("== C type errors");
    show::<User>("C1 wrong type", r#"{"name":"x","age":"old","addrs":[]}"#);
    path::<User>("C1", r#"{"name":"x","age":"old","addrs":[]}"#);
    show::<User>("C2 two errors", r#"{"name":5,"age":"old","addrs":[]}"#);
    show::<User>("C3 out of range", r#"{"name":"x","age":300,"addrs":[]}"#);
    show::<User>("C4 float for int", r#"{"name":"x","age":1.0,"addrs":[]}"#);
    path::<User>("C5 nested wrong type", r#"{"name":"x","age":1,"addrs":[{"city":"a","zip":"q"}]}"#);
    show::<User>("C6 top-level not object", r#"[1,2]"#);
    println!("== D null vs absent");
    show::<User>("D1 nick null", r#"{"name":"x","age":1,"nick":null,"addrs":[]}"#);
    show::<User>("D2 nick absent", r#"{"name":"x","age":1,"addrs":[]}"#);
    show::<User>("D3 null for non-option", r#"{"name":null,"age":1,"addrs":[]}"#);
    show::<DblOpt>("D4 Option<Option> absent", r#"{}"#);
    show::<DblOpt>("D5 Option<Option> null", r#"{"a":null}"#);
    show::<DblOpt>("D6 Option<Option> 1", r#"{"a":1}"#);
    println!("== E input");
    show::<Dflt>("E1 trailing", r#"{"a":1} x"#);
    show::<Dflt>("E2 trailing second value", r#"{"a":1}{"a":2}"#);
    show::<Dflt>("E3 duplicate key struct", r#"{"a":1,"a":2}"#);
    show::<BTreeMap<String,i32>>("E4 duplicate key map", r#"{"a":1,"a":2}"#);
    show::<serde_json::Value>("E5 duplicate key Value", r#"{"a":1,"a":2}"#);
    show::<Extras>("E5b duplicate key in flatten", r#"{"a":1,"z":1,"z":2}"#);
    show::<u64>("E6 u64 max", "18446744073709551615");
    show::<u64>("E7 u64 overflow", "18446744073709551616");
    show::<i64>("E8 i64 from 2^63", "9223372036854775808");
    show::<serde_json::Value>("E9 Value bigint", "123456789012345678901234567890");
    show::<f64>("E10 f64 from int", "1");
    show::<i32>("E11 i32 from 1e2", "1e2");
    show::<Dflt>("E12 case", r#"{"A":1}"#);
    match serde_json::from_slice::<String>(b"\"a\xffb\"") { Ok(v)=>println!("[E13 from_slice invalid utf8 String] OK {v:?}"), Err(e)=>println!("[E13 from_slice invalid utf8 String]\n    ERR {e}\n        category={:?}", e.classify()) }
    match serde_json::from_slice::<serde_json::Value>(b"{\"a\":\"\\ud800\"}") { Ok(v)=>println!("[E14 lone surrogate escape] OK {v:?}"), Err(e)=>println!("[E14 lone surrogate escape]\n    ERR {e}\n        category={:?}", e.classify()) }
    match serde_json::from_reader::<_, Dflt>(&b"{\"a\":1} {\"a\":2}"[..]) { Ok(v)=>println!("[E15 from_reader trailing] OK {v:?}"), Err(e)=>println!("[E15 from_reader trailing]\n    ERR {e}\n        category={:?}", e.classify()) }
    println!("== F syntax vs data");
    show::<Dflt>("F1 not json", r#"hello"#);
    show::<Dflt>("F2 truncated", r#"{"a":"#);
    show::<Dflt>("F3 empty", r#""#);
    show::<Dflt>("F4 trailing comma", r#"{"a":1,}"#);
    show::<Dflt>("F5 wrong shape", r#"{"a":"s"}"#);
    println!("== G enums");
    show::<Ext>("G1 ext ok", r#"{"Circle":{"r":1}}"#);
    show::<Ext>("G2 ext unknown variant", r#"{"Triangle":{}}"#);
    show::<Ext>("G3 ext missing field", r#"{"Circle":{}}"#);
    show::<Ext>("G3b ext unit string", r#""Unit""#);
    show::<Ext>("G3c ext two keys", r#"{"Circle":{"r":1},"Square":{"side":1}}"#);
    show::<Int>("G4 int ok", r#"{"type":"Circle","r":1}"#);
    show::<Int>("G5 int unknown tag", r#"{"type":"Triangle"}"#);
    show::<Int>("G6 int missing tag", r#"{"r":1}"#);
    show::<Int>("G7 int missing field", r#"{"type":"Circle"}"#);
    show::<Int>("G8 int wrong field type", r#"{"type":"Circle","r":"x"}"#);
    show::<Int>("G8b int tag not string", r#"{"type":1,"r":1}"#);
    show::<Holder>("G9 int nested missing field", "{\"shapes\":[{\"type\":\"Square\",\"side\":1},\n {\"type\":\"Circle\"}]}");
    path::<Holder>("G9", "{\"shapes\":[{\"type\":\"Square\",\"side\":1},\n {\"type\":\"Circle\"}]}");
    show::<Adj>("G10 adj unknown tag", r#"{"t":"Triangle","c":{}}"#);
    show::<Adj>("G11 adj missing field", r#"{"t":"Circle","c":{}}"#);
    show::<Adj>("G11b adj missing content", r#"{"t":"Circle"}"#);
    show::<Unt>("G12 unt ok", r#"{"side":2}"#);
    show::<Unt>("G13 unt no match", r#"{"r":"x"}"#);
    show::<Unt>("G14 unt both match", r#"{"r":1,"side":2}"#);
    show::<HolderU>("G15 unt nested no match", "{\"shapes\":[{\"side\":1},\n {\"radius\":2}]}");
    path::<HolderU>("G15", "{\"shapes\":[{\"side\":1},\n {\"radius\":2}]}");
}
