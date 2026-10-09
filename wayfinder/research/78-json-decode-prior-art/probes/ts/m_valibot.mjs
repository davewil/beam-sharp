import * as v from "valibot";
const show = (label, r) => {
  console.log("--- " + label);
  if (r.success) console.log("OK", JSON.stringify(r.output));
  else {
    console.log("ISSUES", JSON.stringify(r.issues.map(i => ({ kind: i.kind, type: i.type, expected: i.expected, received: i.received, message: i.message, path: i.path?.map(p => p.key), dotPath: v.getDotPath(i), nested: i.issues?.map(n => ({ type: n.type, expected: n.expected, received: n.received, message: n.message, path: n.path?.map(p => p.key) })) })), null, 1));
    console.log("FLAT", JSON.stringify(v.flatten(r.issues)));
  }
};
const entries = { model: v.string(), n: v.number() };
const Req = v.object(entries);
show("1 extra key, object", v.safeParse(Req, { model: "m", n: 1, extra: true }));
show("1 extra key, strictObject", v.safeParse(v.strictObject(entries), { model: "m", n: 1, extra: true, e2: 1 }));
show("1 extra key, looseObject", v.safeParse(v.looseObject(entries), { model: "m", n: 1, extra: true }));
show("1 extra key, objectWithRest(number)", v.safeParse(v.objectWithRest(entries, v.number()), { model: "m", n: 1, extra: true }));
show("2 missing model", v.safeParse(Req, { n: 1 }));
show("2 missing model + wrong n", v.safeParse(Req, { n: "x" }));
show("2 missing model + wrong n, abortEarly", v.safeParse(Req, { n: "x" }, { abortEarly: true }));
show("2 nested missing", v.safeParse(v.object({ a: v.array(Req) }), { a: [{ model: "m", n: 1 }, { n: 2 }] }));

const A = v.object({ type: v.literal("text"), text: v.string() });
const B = v.object({ type: v.literal("image"), url: v.string() });
const C = v.object({ type: v.literal("tool"), name: v.string(), input: v.number() });
const U = v.union([A, B, C]);
const D = v.variant("type", [A, B, C]);
show("3a union, valid tag missing key", v.safeParse(U, { type: "image" }));
show("3b union, unknown tag", v.safeParse(U, { type: "video", url: "x" }));
show("3a variant, valid tag missing key", v.safeParse(D, { type: "image" }));
show("3b variant, unknown tag", v.safeParse(D, { type: "video", url: "x" }));
show("3c variant, tag absent", v.safeParse(D, { url: "x" }));

const O = v.object({ a: v.optional(v.string()), b: v.nullable(v.string()), c: v.nullish(v.string()), d: v.exactOptional(v.string()) });
show("D {b:null}", v.safeParse(O, { b: null }));
show("D {a:null,b:null}", v.safeParse(O, { a: null, b: null }));
show("D {}", v.safeParse(O, {}));
show("D {b:null,d:undefined}", v.safeParse(O, { b: null, d: undefined }));
console.log("has parseJson", typeof v.parseJson, "isoTimestamp", typeof v.isoTimestamp);
try {
  const J = v.pipe(v.string(), v.parseJson(), Req);
  show("F parseJson not-json", v.safeParse(J, "{nope"));
  show("F parseJson wrong shape", v.safeParse(J, '{"n":1}'));
} catch (e) { console.log("parseJson threw", e.message); }
