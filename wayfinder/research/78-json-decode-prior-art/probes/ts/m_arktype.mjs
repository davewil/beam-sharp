import { type } from "arktype";
const show = (label, out) => {
  console.log("--- " + label);
  if (out instanceof type.errors) {
    console.log("SUMMARY: " + out.summary);
    console.log("ERRORS", JSON.stringify([...out].map(e => ({ code: e.code, path: [...e.path], expected: e.expected, actual: e.actual, message: e.message })), null, 1));
  } else console.log("OK", JSON.stringify(out));
};
const Req = type({ model: "string", n: "number" });
show("1 extra key, default", Req({ model: "m", n: 1, extra: true }));
show("1 extra key, '+':'reject'", type({ "+": "reject", model: "string", n: "number" })({ model: "m", n: 1, extra: true, e2: 1 }));
show("1 extra key, '+':'delete'", type({ "+": "delete", model: "string", n: "number" })({ model: "m", n: 1, extra: true }));
show("1 extra key, index signature number", type({ model: "string", n: "number", "[string]": "number|string" })({ model: "m", n: 1, extra: true }));
show("2 missing model", Req({ n: 1 }));
show("2 missing model + wrong n", Req({ n: "x" }));
show("2 nested missing", type({ a: Req.array() })({ a: [{ model: "m", n: 1 }, { n: 2 }] }));
const U = type({ type: "'text'", text: "string" }).or({ type: "'image'", url: "string" }).or({ type: "'tool'", name: "string", input: "number" });
show("3a union, valid tag missing key", U({ type: "image" }));
show("3b union, unknown tag", U({ type: "video", url: "x" }));
show("3c union, tag absent", U({ url: "x" }));
const U2 = type({ a: "string" }).or({ b: "number" });
show("3d non-discriminable union", U2({ c: 1 }));
const O = type({ "a?": "string", b: "string|null", "c?": "string|null" });
show("D {b:null}", O({ b: null }));
show("D {a:null,b:null}", O({ a: null, b: null }));
show("D {}", O({}));
show("D {a:undefined,b:null}", O({ a: undefined, b: null }));
try {
  const J = type("string.json.parse").to({ model: "string", n: "number" });
  show("F json.parse not-json", J("{nope"));
  show("F json.parse wrong shape", J('{"n":1}'));
  show("F json.parse ok", J('{"model":"m","n":1}'));
} catch (e) { console.log("json.parse threw", e.message); }
