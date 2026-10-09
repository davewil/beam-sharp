import { z } from "zod";
const show = (label, r) => {
  console.log("--- " + label);
  if (r.success) console.log("OK", JSON.stringify(r.data));
  else { console.log("ISSUES", JSON.stringify(r.error.issues, null, 1)); console.log("PRETTY\n" + z.prettifyError(r.error)); }
};
const Req = z.object({ model: z.string(), n: z.number() });
show("1 extra key, z.object", Req.safeParse({ model: "m", n: 1, extra: true }));
show("1 extra key, z.strictObject", z.strictObject({ model: z.string(), n: z.number() }).safeParse({ model: "m", n: 1, extra: true, e2: 1 }));
show("1 extra key, z.looseObject", z.looseObject({ model: z.string(), n: z.number() }).safeParse({ model: "m", n: 1, extra: true }));
show("1 extra key, catchall(z.number())", Req.catchall(z.number()).safeParse({ model: "m", n: 1, extra: true }));
show("2 missing model", Req.safeParse({ n: 1 }));
show("2 missing model + wrong n (all errors?)", Req.safeParse({ n: "x" }));
show("2 nested missing", z.object({ a: z.array(Req) }).safeParse({ a: [{ model: "m", n: 1 }, { n: 2 }] }));

const A = z.object({ type: z.literal("text"), text: z.string() });
const B = z.object({ type: z.literal("image"), url: z.string() });
const C = z.object({ type: z.literal("tool"), name: z.string(), input: z.number() });
const U = z.union([A, B, C]);
const D = z.discriminatedUnion("type", [A, B, C]);
show("3a union, valid tag missing key", U.safeParse({ type: "image" }));
show("3b union, unknown tag", U.safeParse({ type: "video", url: "x" }));
show("3a discriminatedUnion, valid tag missing key", D.safeParse({ type: "image" }));
show("3b discriminatedUnion, unknown tag", D.safeParse({ type: "video", url: "x" }));
show("3c discriminatedUnion, tag absent", D.safeParse({ url: "x" }));

// D null vs absent
const O = z.object({ a: z.string().optional(), b: z.string().nullable(), c: z.string().nullish() });
show("D {b:null}", O.safeParse({ b: null }));
show("D {a:null,b:null}", O.safeParse({ a: null, b: null }));
show("D {} (b absent)", O.safeParse({}));
show("D {a:undefined,b:null} key present", O.safeParse({ a: undefined, b: null }));

// E/F JSON text
for (const name of ["json", "codec"]) console.log("has z." + name, typeof z[name]);
try {
  const jsonCodec = z.codec(z.string(), Req, { decode: (s, ctx) => { try { return JSON.parse(s); } catch (e) { ctx.issues.push({ code: "invalid_format", format: "json", input: s, message: e.message }); return z.NEVER; } }, encode: (v) => JSON.stringify(v) });
  show("F codec not-json", jsonCodec.safeParse("{nope"));
  show("F codec wrong shape", jsonCodec.safeParse('{"n":1}'));
  console.log("encode", jsonCodec.encode({ model: "m", n: 1 }));
} catch (e) { console.log("codec threw", e.message); }
show("z.json() on a function-free value", z.json().safeParse({ a: [1, null, "x"] }));
show("z.json() on undefined member", z.json().safeParse({ a: undefined }));
show("non-object input", Req.safeParse("str"));
show("null input", Req.safeParse(null));
