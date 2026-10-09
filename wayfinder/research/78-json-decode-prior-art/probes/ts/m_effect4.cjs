const { Schema: S, SchemaIssue, Exit, Result } = require("effect");
console.log("SchemaIssue exports:", Object.keys(SchemaIssue).join(" "));
const show = (label, schema, input, opts) => {
  console.log("--- " + label);
  try { console.log("OK", JSON.stringify(S.decodeUnknownSync(schema)(input, opts))); }
  catch (e) { console.log("THROWS " + e.constructor.name + ": " + e.message); }
};
const Req = S.Struct({ model: S.String, n: S.Number });
const x = { model: "m", n: 1, extra: true };
show("1 extra default", Req, x);
show("1 extra onExcessProperty error", Req, x, { onExcessProperty: "error" });
show("1 extra onExcessProperty preserve", Req, x, { onExcessProperty: "preserve" });
show("2 missing model", Req, { n: 1 });
show("2 missing + wrong n default", Req, { n: "x" });
show("2 missing + wrong n errors all", Req, { n: "x" }, { errors: "all" });
show("2 nested", S.Struct({ a: S.Array(Req) }), { a: [{ model: "m", n: 1 }, { n: 2 }] });
const A = S.Struct({ type: S.Literal("text"), text: S.String });
const B = S.Struct({ type: S.Literal("image"), url: S.String });
const C = S.Struct({ type: S.Literal("tool"), name: S.String, input: S.Number });
const U = S.Union([A, B, C]);
show("3a union valid tag missing key", U, { type: "image" }, { errors: "all" });
show("3b union unknown tag", U, { type: "video", url: "x" }, { errors: "all" });
show("3c union tag absent", U, { url: "x" }, { errors: "all" });
const O = S.Struct({ a: S.optional(S.String), b: S.NullOr(S.String), c: S.optionalKey(S.String) });
show("D {b:null}", O, { b: null });
show("D {a:null,b:null}", O, { a: null, b: null });
show("D {a:undefined,b:null}", O, { a: undefined, b: null });
show("D {b:null,c:undefined}", O, { b: null, c: undefined });
show("D {}", O, {});
const J = S.fromJsonString(Req);
show("F fromJsonString not json", J, "{nope");
show("F fromJsonString wrong shape", J, '{"n":1}');
try { console.log("encode:", S.encodeSync(J)({ model: "m", n: 1 })); } catch (e) { console.log(e.message); }
