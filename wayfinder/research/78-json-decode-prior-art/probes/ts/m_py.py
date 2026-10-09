import sys, json
sys.path.insert(0, sys.argv[1])
from typing import Literal, Optional, Union, Annotated
import pydantic
from pydantic import BaseModel, Field, ValidationError, TypeAdapter, ConfigDict
print("pydantic", pydantic.VERSION)

def show(label, f):
    print("--- " + label)
    try:
        print("OK", repr(f()))
    except ValidationError as e:
        print("ERRORS", json.dumps(e.errors(include_url=False), default=repr))
        print("STR\n" + str(e))
    except Exception as e:
        print("EXC", type(e).__mro__[:3], e)

class Req(BaseModel):
    model: str
    n: int
class ReqForbid(BaseModel):
    model_config = ConfigDict(extra="forbid")
    model: str
    n: int
class ReqAllow(BaseModel):
    model_config = ConfigDict(extra="allow")
    model: str
    n: int
    __pydantic_extra__: dict[str, int] = Field(init=False)

show("1 extra, default ignore", lambda: Req.model_validate_json('{"model":"m","n":1,"extra":true}'))
show("1 extra, forbid", lambda: ReqForbid.model_validate_json('{"model":"m","n":1,"extra":true,"e2":1}'))
show("1 extra, allow typed int", lambda: ReqAllow.model_validate_json('{"model":"m","n":1,"extra":true}').model_extra)
show("1 extra, allow typed int bad", lambda: ReqAllow.model_validate_json('{"model":"m","n":1,"extra":"zz"}'))
show("2 missing model", lambda: Req.model_validate_json('{"n":1}'))
show("2 missing model + wrong n", lambda: Req.model_validate_json('{"n":"x"}'))
class Outer(BaseModel):
    a: list[Req]
show("2 nested missing", lambda: Outer.model_validate_json('{"a":[{"model":"m","n":1},{"n":2}]}'))

class A(BaseModel):
    type: Literal["text"]
    text: str
class B(BaseModel):
    type: Literal["image"]
    url: str
class C(BaseModel):
    type: Literal["tool"]
    name: str
    input: int
U = TypeAdapter(Union[A, B, C])
D = TypeAdapter(Annotated[Union[A, B, C], Field(discriminator="type")])
show("3a smart union, valid tag missing key", lambda: U.validate_json('{"type":"image"}'))
show("3b smart union, unknown tag", lambda: U.validate_json('{"type":"video","url":"x"}'))
show("3a discriminated, valid tag missing key", lambda: D.validate_json('{"type":"image"}'))
show("3b discriminated, unknown tag", lambda: D.validate_json('{"type":"video","url":"x"}'))
show("3c discriminated, tag absent", lambda: D.validate_json('{"url":"x"}'))

class O(BaseModel):
    a: Optional[str]
    b: Optional[str] = None
    c: str = "d"
show("D {} (a: Optional[str] no default)", lambda: O.model_validate_json('{}'))
show("D {a:null}", lambda: O.model_validate_json('{"a":null}'))
show("D {a:null,c:null}", lambda: O.model_validate_json('{"a":null,"c":null}'))
r = O.model_validate_json('{"a":null}')
print("fields_set", r.model_fields_set, "| exclude_unset dump:", r.model_dump_json(exclude_unset=True))

show("E not json", lambda: Req.model_validate_json('{nope'))
show("E trailing data", lambda: Req.model_validate_json('{"model":"m","n":1} x'))
show("E bytes", lambda: Req.model_validate_json(b'{"model":"m","n":1}'))
show("E invalid utf8 bytes", lambda: Req.model_validate_json(b'{"model":"\xff","n":1}'))
show("E duplicate keys", lambda: Req.model_validate_json('{"model":"a","model":"b","n":1}'))
show("E big int", lambda: Req.model_validate_json('{"model":"a","n":123456789012345678901234567890}'))
show("E float 1.0 into int (lax)", lambda: Req.model_validate_json('{"model":"a","n":1.0}'))
show("E float 1.5 into int", lambda: Req.model_validate_json('{"model":"a","n":1.5}'))
show("E string '1' into int (lax)", lambda: Req.model_validate_json('{"model":"a","n":"1"}'))
show("E string '1' into int (strict)", lambda: Req.model_validate_json('{"model":"a","n":"1"}', strict=True))
show("E float 1.0 into int (strict)", lambda: Req.model_validate_json('{"model":"a","n":1.0}', strict=True))
show("E NaN token", lambda: TypeAdapter(float).validate_json('NaN'))
show("E empty", lambda: Req.model_validate_json(''))

print("===== stdlib json")
for label, s in [("dup", '{"a":1,"a":2}'), ("NaN", '[NaN, Infinity]'), ("bigint", '123456789012345678901234567890'), ("1.0", '[1, 1.0]'), ("trailing", '{} x'), ("badutf8", b'"\xff"'), ("bytes", b'{"a":1}')]:
    try: print(label, repr(json.loads(s)))
    except Exception as e: print(label, "EXC", type(e).__mro__[:3], e)

print("===== msgspec")
import msgspec
print("msgspec", msgspec.__version__)
class MReq(msgspec.Struct):
    model: str
    n: int
class MReqF(msgspec.Struct, forbid_unknown_fields=True):
    model: str
    n: int
class MOuter(msgspec.Struct):
    a: list[MReq]
class MA(msgspec.Struct, tag="text"):
    text: str
class MB(msgspec.Struct, tag="image"):
    url: str
class MC(msgspec.Struct, tag="tool"):
    name: str
    input: int
class MO(msgspec.Struct):
    a: Optional[str]
    b: Optional[str] = None
    c: Union[str, None, msgspec.UnsetType] = msgspec.UNSET
def m(label, data, t, **kw):
    print("--- " + label)
    try: print("OK", repr(msgspec.json.decode(data, type=t, **kw)))
    except Exception as e: print("EXC", [c.__name__ for c in type(e).__mro__[:4]], "|", e)
m("1 extra default", b'{"model":"m","n":1,"extra":true}', MReq)
m("1 extra forbid", b'{"model":"m","n":1,"extra":true,"e2":1}', MReqF)
m("2 missing model", b'{"n":1}', MReq)
m("2 missing model + wrong n", b'{"n":"x"}', MReq)
m("2 nested missing", b'{"a":[{"model":"m","n":1},{"n":2}]}', MOuter)
m("3a tagged valid tag missing key", b'{"type":"image"}', Union[MA, MB, MC])
m("3b tagged unknown tag", b'{"type":"video","url":"x"}', Union[MA, MB, MC])
m("3c tagged tag absent", b'{"url":"x"}', Union[MA, MB, MC])
m("D {}", b'{}', MO)
m("D {a:null}", b'{"a":null}', MO)
m("D {a:null,c:null}", b'{"a":null,"c":null}', MO)
m("E not json", b'{nope', MReq)
m("E trailing", b'{"model":"m","n":1} x', MReq)
m("E str input", '{"model":"m","n":1}', MReq)
m("E invalid utf8", b'{"model":"\xff","n":1}', MReq)
m("E dup keys", b'{"model":"a","model":"b","n":1}', MReq)
m("E big int", b'{"model":"a","n":123456789012345678901234567890}', MReq)
m("E 1.0 into int", b'{"model":"a","n":1.0}', MReq)
m("E 1.5 into int", b'{"model":"a","n":1.5}', MReq)
m("E '1' into int strict default", b'{"model":"a","n":"1"}', MReq)
m("E '1' into int strict=False", b'{"model":"a","n":"1"}', MReq, strict=False)
m("E NaN", b'NaN', float)

print("===== cattrs")
import attrs, cattrs
from cattrs import Converter, transform_error
from cattrs.gen import make_dict_structure_fn
print("cattrs", getattr(cattrs, "__version__", "?"), "attrs", attrs.__version__)
@attrs.define
class CReq:
    model: str
    n: int
@attrs.define
class COuter:
    a: list[CReq]
def c(label, conv, data, t):
    print("--- " + label)
    try: print("OK", repr(conv.structure(data, t)))
    except Exception as e: print("EXC", type(e).__name__, "|", repr(e), "| transform_error:", transform_error(e) if isinstance(e, cattrs.BaseValidationError) else None)
conv = Converter()
c("1 extra default", conv, {"model": "m", "n": 1, "extra": True}, CReq)
c("1 extra forbid_extra_keys", Converter(forbid_extra_keys=True), {"model": "m", "n": 1, "extra": True}, CReq)
c("2 missing model", conv, {"n": 1}, CReq)
c("2 missing model + wrong n", conv, {"n": "x"}, CReq)
c("2 nested missing", conv, {"a": [{"model": "m", "n": 1}, {"n": 2}]}, COuter)
c("coercion: n='1'", conv, {"model": 5, "n": "1"}, CReq)
