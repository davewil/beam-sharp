const t = require("io-ts");
const { PathReporter } = require("io-ts/lib/PathReporter");
const E = require("fp-ts/lib/Either");
const show = (label, r) => {
  console.log("--- " + label);
  if (E.isRight(r)) console.log("OK", JSON.stringify(r.right));
  else {
    console.log("N errors", r.left.length);
    console.log("CONTEXT keys", JSON.stringify(r.left.map(e => ({ value: e.value, message: e.message, path: e.context.map(c => c.key), types: e.context.map(c => c.type.name) }))));
    console.log("PathReporter", JSON.stringify(PathReporter.report(r), null, 1));
  }
};
const Req = t.type({ model: t.string, n: t.number }, "Req");
show("1 extra, t.type", Req.decode({ model: "m", n: 1, extra: true }));
show("1 extra, t.exact", t.exact(Req).decode({ model: "m", n: 1, extra: true }));
show("1 extra, t.strict", t.strict({ model: t.string, n: t.number }).decode({ model: "m", n: 1, extra: true }));
show("2 missing model", Req.decode({ n: 1 }));
show("2 missing model + wrong n", Req.decode({ n: "x" }));
show("2 nested", t.type({ a: t.array(Req) }).decode({ a: [{ model: "m", n: 1 }, { n: 2 }] }));
const A = t.type({ type: t.literal("text"), text: t.string }, "A");
const B = t.type({ type: t.literal("image"), url: t.string }, "B");
const C = t.type({ type: t.literal("tool"), name: t.string, input: t.number }, "C");
const U = t.union([A, B, C]);
console.log("union _tag:", U._tag, "ctor:", U.constructor.name);
show("3a union valid tag missing key", U.decode({ type: "image" }));
show("3b union unknown tag", U.decode({ type: "video", url: "x" }));
show("3c union tag absent", U.decode({ url: "x" }));
const O = t.intersection([t.type({ b: t.union([t.string, t.null]) }), t.partial({ a: t.string })]);
show("D {b:null}", O.decode({ b: null }));
show("D {a:null,b:null}", O.decode({ a: null, b: null }));
show("D {}", O.decode({}));
show("D t.type with undefined-able: {}", t.type({ a: t.union([t.string, t.undefined]) }).decode({}));
