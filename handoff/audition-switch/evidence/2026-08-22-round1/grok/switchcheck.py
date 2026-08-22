#!/usr/bin/env python3
"""Exhaustiveness / well-formedness checker for B# switch expressions."""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from typing import Optional, Union


# ---------------------------------------------------------------------------
# Lexer
# ---------------------------------------------------------------------------

KEYWORDS = {
    "module",
    "type",
    "record",
    "public",
    "switch",
    "when",
    "and",
    "or",
    "true",
    "false",
}

TWOCHAR = {
    "=>": "ARROW",
    "->": "FARROW",
    ">=": "GE",
    "<=": "LE",
    "==": "EQEQ",
    "..": "DOTDOT",
}


@dataclass
class Tok:
    kind: str
    value: object
    pos: int


class LexError(Exception):
    pass


def lex(src: str) -> list[Tok]:
    i = 0
    n = len(src)
    out: list[Tok] = []

    def peek(k=0):
        j = i + k
        return src[j] if j < n else ""

    while i < n:
        ch = src[i]
        if ch.isspace():
            i += 1
            continue
        if ch == "/" and peek(1) == "/":
            i += 2
            while i < n and src[i] != "\n":
                i += 1
            continue
        if ch == "/" and peek(1) == "*":
            i += 2
            while i < n and not (src[i] == "*" and peek(1) == "/"):
                i += 1
            i = min(i + 2, n)
            continue
        if ch == "#" and (not out or out[-1].kind in {"NEWLINE"}):
            while i < n and src[i] != "\n":
                i += 1
            continue

        two = src[i : i + 2]
        if two in TWOCHAR:
            out.append(Tok(TWOCHAR[two], two, i))
            i += 2
            continue

        if ch == ":" and (peek(1).isalpha() or peek(1) == "_"):
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            out.append(Tok("ATOM", src[i + 1 : j], i))
            i = j
            continue

        if ch.isalpha() or ch == "_":
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            word = src[i:j]
            if word == "true":
                out.append(Tok("BOOL", True, i))
            elif word == "false":
                out.append(Tok("BOOL", False, i))
            elif word in KEYWORDS:
                out.append(Tok(word.upper(), word, i))
            else:
                out.append(Tok("IDENT", word, i))
            i = j
            continue

        if ch.isdigit() or (
            ch == "-"
            and peek(1).isdigit()
            and (not out or out[-1].kind not in {"IDENT", "INT", "ATOM", "BOOL", "RPAREN", "RBRACK", "RBRACE"})
        ):
            j = i
            if ch == "-":
                j += 1
            while j < n and src[j].isdigit():
                j += 1
            out.append(Tok("INT", int(src[i:j]), i))
            i = j
            continue

        singles = {
            "(": "LPAREN",
            ")": "RPAREN",
            "[": "LBRACK",
            "]": "RBRACK",
            "{": "LBRACE",
            "}": "RBRACE",
            ",": "COMMA",
            "|": "PIPE",
            "<": "LT",
            ">": "GT",
            ":": "COLON",
            ".": "DOT",
            "=": "EQUAL",
            "+": "PLUS",
            "-": "MINUS",
            "*": "STAR",
            "/": "SLASH",
        }
        if ch in singles:
            out.append(Tok(singles[ch], ch, i))
            i += 1
            continue

        raise LexError(f"unexpected character {ch!r} at {i}")

    out.append(Tok("EOF", None, n))
    return out


# ---------------------------------------------------------------------------
# AST
# ---------------------------------------------------------------------------

# Types
@dataclass
class TInt:
    pass


@dataclass
class TBool:
    pass


@dataclass
class TAtom:  # open atom universe
    pass


@dataclass
class TTerm:
    pass


@dataclass
class TNamed:
    name: str


@dataclass
class TClosed:
    atoms: frozenset  # of str


@dataclass
class TTuple:
    elems: tuple  # of Type


@dataclass
class TList:
    elem: object


@dataclass
class TRecord:
    name: str
    fields: dict  # str -> Type


@dataclass
class TSum:
    variants: tuple  # of Type (typically TTuple or TClosed singleton)


Type = Union[TInt, TBool, TAtom, TTerm, TNamed, TClosed, TTuple, TList, TRecord, TSum]


# Patterns
@dataclass
class PWild:
    pass


@dataclass
class PVar:
    name: str


@dataclass
class PEq:
    name: str


@dataclass
class PAtom:
    name: str


@dataclass
class PInt:
    value: int


@dataclass
class PBool:
    value: bool


@dataclass
class PTuple:
    elems: tuple


@dataclass
class PList:
    elems: tuple
    rest: Optional[str]  # name or None for ..rest; False if no rest; '_' rest -> ""


@dataclass
class PRel:
    """Intersection of relational constraints (and-chain). `ors` is a list of and-chains."""

    chains: tuple  # tuple of tuple of (op, int)


@dataclass
class PAnd:
    left: object
    right: object


@dataclass
class POr:
    left: object
    right: object


# Guards
@dataclass
class GCmp:
    name: str
    op: str
    lit: object  # int | bool | str(atom) tagged
    lit_kind: str  # 'int' | 'bool' | 'atom'


@dataclass
class GAnd:
    left: object
    right: object


@dataclass
class GOr:
    left: object
    right: object


@dataclass
class GUnknown:
    pass


# Expressions
@dataclass
class EInt:
    value: int


@dataclass
class EBool:
    value: bool


@dataclass
class EAtom:
    name: str


@dataclass
class EVar:
    name: str


@dataclass
class ETuple:
    elems: tuple


@dataclass
class EField:
    obj: object
    name: str


@dataclass
class ECall:
    name: str
    args: tuple


@dataclass
class EBin:
    op: str
    left: object
    right: object


@dataclass
class EArm:
    pattern: object
    guard: object  # or None
    body: object


@dataclass
class ESwitch:
    subject: object
    arms: tuple  # of EArm


@dataclass
class FuncSig:
    name: str
    ret: Type
    params: tuple  # of (Type, str)


@dataclass
class Clause:
    name: str
    patterns: tuple
    guard: object
    body: object


@dataclass
class Program:
    types: dict  # name -> Type
    records: dict  # name -> TRecord
    sigs: dict  # name -> FuncSig
    clauses: list  # of Clause


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

class ParseError(Exception):
    pass


class Parser:
    def __init__(self, tokens: list[Tok]):
        self.toks = tokens
        self.i = 0

    def cur(self) -> Tok:
        return self.toks[self.i]

    def kind(self) -> str:
        return self.toks[self.i].kind

    def eat(self, kind: str) -> Tok:
        t = self.cur()
        if t.kind != kind:
            raise ParseError(f"expected {kind}, got {t.kind} ({t.value!r})")
        self.i += 1
        return t

    def accept(self, kind: str) -> Optional[Tok]:
        if self.kind() == kind:
            t = self.cur()
            self.i += 1
            return t
        return None

    def parse_program(self) -> Program:
        if self.kind() == "MODULE":
            self.eat("MODULE")
            self.eat("IDENT")
        types: dict = {}
        records: dict = {}
        sigs: dict = {}
        clauses: list = []
        while self.kind() != "EOF":
            k = self.kind()
            if k == "TYPE":
                name, ty = self.parse_type_decl()
                types[name] = ty
            elif k == "RECORD":
                rec = self.parse_record()
                records[rec.name] = rec
                types[rec.name] = rec
            elif k == "PUBLIC":
                sig = self.parse_sig()
                sigs[sig.name] = sig
            elif k == "IDENT":
                clauses.append(self.parse_clause())
            elif k == "MODULE":
                self.eat("MODULE")
                self.eat("IDENT")
            else:
                raise ParseError(f"unexpected {k} ({self.cur().value!r})")
        return Program(types, records, sigs, clauses)

    def parse_type_decl(self):
        self.eat("TYPE")
        name = self.eat("IDENT").value
        self.eat("EQUAL")
        ty = self.parse_type_union()
        return name, ty

    def parse_type_union(self) -> Type:
        terms = [self.parse_type_term()]
        while self.accept("PIPE"):
            terms.append(self.parse_type_term())
        if len(terms) == 1:
            return terms[0]
        if all(isinstance(t, TClosed) and len(t.atoms) == 1 for t in terms):
            atoms = frozenset().union(*(t.atoms for t in terms))
            return TClosed(atoms)
        return TSum(tuple(terms))

    def parse_type_term(self) -> Type:
        return self.parse_type()

    def parse_type(self) -> Type:
        if self.kind() == "ATOM":
            return TClosed(frozenset({self.eat("ATOM").value}))
        if self.kind() == "LPAREN":
            self.eat("LPAREN")
            elems = [self.parse_type_union_inner()]
            while self.accept("COMMA"):
                elems.append(self.parse_type_union_inner())
            self.eat("RPAREN")
            if len(elems) == 1:
                return elems[0]
            return TTuple(tuple(elems))
        if self.kind() != "IDENT":
            raise ParseError(f"expected type, got {self.kind()}")
        name = self.eat("IDENT").value
        if self.accept("LT"):
            inner = self.parse_type()
            self.eat("GT")
            if name == "list":
                return TList(inner)
            return TNamed(name)
        return _prim_or_named(name)

    def parse_type_union_inner(self) -> Type:
        # type inside tuple/parens, still allowing |  — but | is outer.
        return self.parse_type()

    def parse_record(self) -> TRecord:
        self.eat("RECORD")
        name = self.eat("IDENT").value
        self.eat("LBRACE")
        fields = {}
        if self.kind() != "RBRACE":
            while True:
                fname = self.eat("IDENT").value
                self.eat("COLON")
                fty = self.parse_type()
                fields[fname] = fty
                if not self.accept("COMMA"):
                    break
        self.eat("RBRACE")
        return TRecord(name, fields)

    def parse_sig(self) -> FuncSig:
        self.eat("PUBLIC")
        ret = self.parse_type()
        name = self.eat("IDENT").value
        self.eat("LPAREN")
        params = []
        if self.kind() != "RPAREN":
            while True:
                ty = self.parse_type()
                pname = self.eat("IDENT").value
                params.append((ty, pname))
                if not self.accept("COMMA"):
                    break
        self.eat("RPAREN")
        return FuncSig(name, ret, tuple(params))

    def parse_clause(self) -> Clause:
        name = self.eat("IDENT").value
        self.eat("LPAREN")
        pats = []
        if self.kind() != "RPAREN":
            while True:
                pats.append(self.parse_pattern())
                if not self.accept("COMMA"):
                    break
        self.eat("RPAREN")
        guard = None
        if self.accept("WHEN"):
            guard = self.parse_guard()
        self.eat("FARROW")
        body = self.parse_expr()
        return Clause(name, tuple(pats), guard, body)

    def parse_pattern(self) -> object:
        return self.parse_pattern_or()

    def parse_pattern_or(self):
        left = self.parse_pattern_and()
        while self.kind() == "OR" and self._next_is_pattern_operand():
            self.eat("OR")
            right = self.parse_pattern_and()
            left = POr(left, right)
        return left

    def parse_pattern_and(self):
        left = self.parse_pattern_atom()
        while self.kind() == "AND" and self._next_is_pattern_operand():
            self.eat("AND")
            right = self.parse_pattern_atom()
            if isinstance(left, PRel) and isinstance(right, PRel) and len(left.chains) == 1 and len(right.chains) == 1:
                left = PRel((left.chains[0] + right.chains[0],))
            else:
                left = PAnd(left, right)
        return left

    def _next_is_pattern_operand(self) -> bool:
        k = self.toks[self.i + 1].kind if self.i + 1 < len(self.toks) else "EOF"
        return k in {"GE", "LE", "GT", "LT", "EQEQ", "ATOM", "INT", "BOOL", "IDENT", "LPAREN", "LBRACK", "LBRACE"}

    def parse_pattern_atom(self):
        k = self.kind()
        if k == "IDENT" and self.cur().value == "_":
            self.eat("IDENT")
            return PWild()
        if k in {"GE", "LE", "GT", "LT"}:
            op = self.eat(k).value
            n = self._parse_int_lit()
            return PRel((((op, n),),))
        if k == "EQEQ":
            self.eat("EQEQ")
            if self.kind() == "IDENT":
                return PEq(self.eat("IDENT").value)
            # not admitted by spec; still consume a literal if present
            if self.kind() == "INT":
                n = self.eat("INT").value
                return PInt(n)
            raise ParseError("expected name after ==")
        if k == "ATOM":
            return PAtom(self.eat("ATOM").value)
        if k == "INT":
            return PInt(self.eat("INT").value)
        if k == "BOOL":
            return PBool(self.eat("BOOL").value)
        if k == "IDENT":
            return PVar(self.eat("IDENT").value)
        if k == "LPAREN":
            self.eat("LPAREN")
            if self.kind() == "RPAREN":
                self.eat("RPAREN")
                return PTuple(())
            elems = [self.parse_pattern()]
            while self.accept("COMMA"):
                elems.append(self.parse_pattern())
            self.eat("RPAREN")
            if len(elems) == 1:
                return elems[0]
            return PTuple(tuple(elems))
        if k == "LBRACK":
            self.eat("LBRACK")
            elems = []
            rest = None
            if self.kind() != "RBRACK":
                while True:
                    if self.accept("DOTDOT"):
                        if self.kind() == "IDENT":
                            rest = self.eat("IDENT").value
                        else:
                            rest = "_"
                        break
                    elems.append(self.parse_pattern())
                    if not self.accept("COMMA"):
                        break
                    if self.kind() == "DOTDOT" or (
                        self.kind() == "IDENT" and self.cur().value == ".."
                    ):
                        continue
                if self.accept("DOTDOT"):
                    if self.kind() == "IDENT":
                        rest = self.eat("IDENT").value
                    else:
                        rest = "_"
            self.eat("RBRACK")
            return PList(tuple(elems), rest)
        raise ParseError(f"expected pattern, got {k} ({self.cur().value!r})")

    def _parse_int_lit(self) -> int:
        if self.kind() == "INT":
            return self.eat("INT").value
        if self.kind() == "MINUS":
            self.eat("MINUS")
            return -self.eat("INT").value
        raise ParseError("expected integer")

    def parse_guard(self):
        return self.parse_guard_or()

    def parse_guard_or(self):
        left = self.parse_guard_and()
        while self.accept("OR"):
            right = self.parse_guard_and()
            left = GOr(left, right)
        return left

    def parse_guard_and(self):
        left = self.parse_guard_cmp()
        while self.accept("AND"):
            right = self.parse_guard_cmp()
            left = GAnd(left, right)
        return left

    def parse_guard_cmp(self):
        if self.accept("LPAREN"):
            g = self.parse_guard()
            self.eat("RPAREN")
            return g
        left = self.parse_guard_primary()
        if self.kind() in {"GE", "LE", "GT", "LT", "EQEQ"}:
            op = self.eat(self.kind()).value
            right = self.parse_guard_primary()
            if isinstance(left, EVar) and isinstance(right, (EInt, EBool, EAtom)):
                if isinstance(right, EInt):
                    return GCmp(left.name, op, right.value, "int")
                if isinstance(right, EBool):
                    return GCmp(left.name, op, right.value, "bool")
                return GCmp(left.name, op, right.name, "atom")
            return GUnknown()
        return GUnknown()

    def parse_guard_primary(self):
        k = self.kind()
        if k == "IDENT":
            return EVar(self.eat("IDENT").value)
        if k == "INT":
            return EInt(self.eat("INT").value)
        if k == "MINUS":
            self.eat("MINUS")
            return EInt(-self.eat("INT").value)
        if k == "BOOL":
            return EBool(self.eat("BOOL").value)
        if k == "ATOM":
            return EAtom(self.eat("ATOM").value)
        raise ParseError(f"expected guard primary, got {k}")

    def parse_expr(self):
        expr = self.parse_expr_add()
        if self.accept("SWITCH"):
            self.eat("LBRACE")
            arms = []
            if self.kind() != "RBRACE":
                while True:
                    if self.kind() == "RBRACE":
                        break
                    arms.append(self.parse_arm())
                    if not self.accept("COMMA"):
                        break
            self.eat("RBRACE")
            return ESwitch(expr, tuple(arms))
        return expr

    def parse_expr_add(self):
        left = self.parse_postfix()
        while self.kind() in {"PLUS", "MINUS"}:
            op = self.eat(self.kind()).value
            right = self.parse_postfix()
            left = EBin(op, left, right)
        return left

    def parse_postfix(self):
        expr = self.parse_primary()
        while True:
            if self.accept("DOT"):
                name = self.eat("IDENT").value
                expr = EField(expr, name)
                continue
            if self.kind() == "LPAREN" and isinstance(expr, EVar):
                self.eat("LPAREN")
                args = []
                if self.kind() != "RPAREN":
                    while True:
                        args.append(self.parse_expr())
                        if not self.accept("COMMA"):
                            break
                self.eat("RPAREN")
                expr = ECall(expr.name, tuple(args))
                continue
            break
        return expr

    def parse_primary(self):
        k = self.kind()
        if k == "INT":
            return EInt(self.eat("INT").value)
        if k == "BOOL":
            return EBool(self.eat("BOOL").value)
        if k == "ATOM":
            return EAtom(self.eat("ATOM").value)
        if k == "IDENT":
            return EVar(self.eat("IDENT").value)
        if k == "LPAREN":
            self.eat("LPAREN")
            if self.kind() == "RPAREN":
                self.eat("RPAREN")
                return ETuple(())
            elems = [self.parse_expr()]
            while self.accept("COMMA"):
                elems.append(self.parse_expr())
            self.eat("RPAREN")
            if len(elems) == 1:
                return elems[0]
            return ETuple(tuple(elems))
        raise ParseError(f"expected expression, got {k} ({self.cur().value!r})")

    def parse_arm(self) -> EArm:
        pat = self.parse_pattern()
        guard = None
        if self.accept("WHEN"):
            guard = self.parse_guard()
        self.eat("ARROW")
        body = self.parse_expr()
        return EArm(pat, guard, body)


def _prim_or_named(name: str) -> Type:
    if name == "int":
        return TInt()
    if name == "bool":
        return TBool()
    if name == "atom":
        return TAtom()
    if name == "term":
        return TTerm()
    return TNamed(name)


# ---------------------------------------------------------------------------
# Residuals
# ---------------------------------------------------------------------------

@dataclass
class REmpty:
    pass


@dataclass
class RInt:
    ivs: tuple  # of (lo, hi), inclusive, None = unbounded


@dataclass
class RBool:
    has_true: bool
    has_false: bool


@dataclass
class RClosed:
    atoms: frozenset


@dataclass
class ROpen:
    """Open atom / term. Empty only when caught."""

    excluded: frozenset
    caught: bool


@dataclass
class RTuple:
    alts: tuple  # of tuple of Res


@dataclass
class RSum:
    parts: tuple  # of Res


@dataclass
class RUnknown:
    caught: bool = False


Res = Union[REmpty, RInt, RBool, RClosed, ROpen, RTuple, RSum, RUnknown]


def r_empty(res: Res) -> bool:
    if isinstance(res, REmpty):
        return True
    if isinstance(res, RInt):
        return len(res.ivs) == 0
    if isinstance(res, RBool):
        return not res.has_true and not res.has_false
    if isinstance(res, RClosed):
        return len(res.atoms) == 0
    if isinstance(res, ROpen):
        return res.caught
    if isinstance(res, RTuple):
        return all(_alt_empty(a) for a in res.alts) or len(res.alts) == 0
    if isinstance(res, RSum):
        return all(r_empty(p) for p in res.parts)
    if isinstance(res, RUnknown):
        return res.caught
    return False


def _alt_empty(alt: tuple) -> bool:
    return any(r_empty(c) for c in alt)


def r_union(a: Res, b: Res) -> Res:
    if r_empty(a):
        return b
    if r_empty(b):
        return a
    if type(a) is not type(b):
        return RSum((a, b))
    if isinstance(a, RInt) and isinstance(b, RInt):
        return RInt(_norm_ivs(a.ivs + b.ivs))
    if isinstance(a, RBool) and isinstance(b, RBool):
        return RBool(a.has_true or b.has_true, a.has_false or b.has_false)
    if isinstance(a, RClosed) and isinstance(b, RClosed):
        return RClosed(a.atoms | b.atoms)
    if isinstance(a, ROpen) and isinstance(b, ROpen):
        return ROpen(a.excluded & b.excluded, a.caught and b.caught)
    if isinstance(a, RTuple) and isinstance(b, RTuple):
        return RTuple(a.alts + b.alts)
    if isinstance(a, RSum) and isinstance(b, RSum):
        return RSum(a.parts + b.parts)
    if isinstance(a, RUnknown) and isinstance(b, RUnknown):
        return RUnknown(a.caught and b.caught)
    return RSum((a, b))


def _lo_key(lo):
    return (0, 0) if lo is None else (1, lo)


def _norm_ivs(ivs):
    cleaned = []
    for lo, hi in ivs:
        if lo is not None and hi is not None and lo > hi:
            continue
        cleaned.append((lo, hi))
    cleaned.sort(key=lambda iv: _lo_key(iv[0]))
    merged = []
    for lo, hi in cleaned:
        if not merged:
            merged.append((lo, hi))
            continue
        mlo, mhi = merged[-1]
        if _can_merge(mhi, lo):
            merged[-1] = (mlo, _hi_max(mhi, hi))
        else:
            merged.append((lo, hi))
    return tuple(merged)


def _can_merge(a_hi, b_lo):
    if a_hi is None or b_lo is None:
        return True
    return b_lo <= a_hi + 1


def _hi_max(a, b):
    if a is None or b is None:
        return None
    return max(a, b)


def _lo_max(a, b):
    if a is None:
        return b
    if b is None:
        return a
    return max(a, b)


def _hi_min(a, b):
    if a is None:
        return b
    if b is None:
        return a
    return min(a, b)


def _iv_intersect(a, b):
    lo = _lo_max(a[0], b[0])
    hi = _hi_min(a[1], b[1])
    if lo is not None and hi is not None and lo > hi:
        return None
    return (lo, hi)


def _iv_subtract_one(a, b):
    inter = _iv_intersect(a, b)
    if inter is None:
        return (a,)
    ilo, ihi = inter
    out = []
    if ilo is not None:
        left_hi = ilo - 1
        left_lo = a[0]
        if left_lo is None or left_lo <= left_hi:
            out.append((left_lo, left_hi))
    if ihi is not None:
        right_lo = ihi + 1
        right_hi = a[1]
        if right_hi is None or right_lo <= right_hi:
            out.append((right_lo, right_hi))
    return tuple(out)


def int_intersect(a: RInt, b: RInt) -> RInt:
    out = []
    for ia in a.ivs:
        for ib in b.ivs:
            inter = _iv_intersect(ia, ib)
            if inter is not None:
                out.append(inter)
    return RInt(_norm_ivs(out))


def int_subtract(a: RInt, b: RInt) -> RInt:
    cur = a.ivs
    for sb in b.ivs:
        nxt = []
        for ia in cur:
            nxt.extend(_iv_subtract_one(ia, sb))
        cur = tuple(nxt)
    return RInt(_norm_ivs(cur))


def rel_interval(op: str, n: int):
    if op == ">=":
        return (n, None)
    if op == ">":
        return (n + 1, None)
    if op == "<=":
        return (None, n)
    if op == "<":
        return (None, n - 1)
    if op == "==":
        return (n, n)
    return (None, None)


def full_of(ty: Type, tenv: dict) -> Res:
    ty = resolve(ty, tenv)
    if isinstance(ty, TInt):
        return RInt(((None, None),))
    if isinstance(ty, TBool):
        return RBool(True, True)
    if isinstance(ty, TAtom) or isinstance(ty, TTerm):
        return ROpen(frozenset(), False)
    if isinstance(ty, TClosed):
        return RClosed(ty.atoms)
    if isinstance(ty, TTuple):
        comps = tuple(full_of(e, tenv) for e in ty.elems)
        return RTuple((comps,))
    if isinstance(ty, TSum):
        return RSum(tuple(full_of(v, tenv) for v in ty.variants))
    if isinstance(ty, TRecord):
        return RUnknown(False)
    if isinstance(ty, TList):
        return RUnknown(False)
    return RUnknown(False)


def resolve(ty: Type, tenv: dict) -> Type:
    seen = set()
    while isinstance(ty, TNamed) and ty.name not in seen:
        seen.add(ty.name)
        if ty.name in tenv:
            ty = tenv[ty.name]
        else:
            return ty
    return ty


# ---------------------------------------------------------------------------
# Pattern / residual split
# ---------------------------------------------------------------------------

def split(res: Res, pat) -> tuple[Res, Res]:
    """Return (matched, remaining) after structurally applying pat to res.

    Remaining is res minus the *credited* coverage of pat. Callers that need
    to withhold credit should ignore remaining and keep the original.
    """
    if r_empty(res):
        return REmpty(), REmpty()
    if isinstance(pat, POr):
        m1, r1 = split(res, pat.left)
        m2, r2 = split(r1, pat.right)
        return r_union(m1, m2), r2
    if isinstance(pat, PAnd):
        m1, r1 = split(res, pat.left)
        m2, r2 = split(m1, pat.right)
        # remaining: not left, or left-but-not-right
        return m2, r_union(r1, r2)
    if isinstance(pat, (PWild, PVar)):
        return res, REmpty()
    if isinstance(pat, PEq):
        # matches anything structurally, but caller withholds credit
        return res, REmpty()
    if isinstance(res, RSum):
        ms, rs = [], []
        for p in res.parts:
            m, r = split(p, pat)
            if not r_empty(m):
                ms.append(m)
            if not r_empty(r):
                rs.append(r)
        matched = ms[0] if len(ms) == 1 else (RSum(tuple(ms)) if ms else REmpty())
        remain = rs[0] if len(rs) == 1 else (RSum(tuple(rs)) if rs else REmpty())
        return matched, remain
    if isinstance(res, RUnknown):
        if isinstance(pat, (PWild, PVar)):
            return res, REmpty()
        # specific pattern against unknown: treat as reachable but no certain subtract
        return res, res
    if isinstance(pat, PAtom):
        return _split_atom(res, pat.name)
    if isinstance(pat, PBool):
        return _split_bool(res, pat.value)
    if isinstance(pat, PInt):
        return _split_int(res, RInt(((pat.value, pat.value),)))
    if isinstance(pat, PRel):
        ivs = _rel_chains_to_ivs(pat.chains)
        return _split_int(res, RInt(ivs))
    if isinstance(pat, PTuple):
        return _split_tuple(res, pat.elems)
    if isinstance(pat, PList):
        # lists are open (unbounded length) unless we model them; a concrete
        # prefix does not exhaust. Wildcard/var already handled.
        if r_empty(res):
            return REmpty(), res
        return res, res
    return REmpty(), res


def _rel_chains_to_ivs(chains) -> tuple:
    """Each chain is AND of (op,n); chains themselves are OR'd."""
    ivs = []
    for chain in chains:
        cur = (None, None)
        ok = True
        for op, n in chain:
            inter = _iv_intersect(cur, rel_interval(op, n))
            if inter is None:
                ok = False
                break
            cur = inter
        if ok:
            ivs.append(cur)
    return _norm_ivs(ivs)


def _split_atom(res: Res, name: str) -> tuple[Res, Res]:
    if isinstance(res, RClosed):
        if name in res.atoms:
            return RClosed(frozenset({name})), RClosed(res.atoms - {name})
        return REmpty(), res
    if isinstance(res, ROpen):
        if res.caught or name in res.excluded:
            return REmpty(), res
        return ROpen(frozenset(), False), ROpen(res.excluded | {name}, False)
    return REmpty(), res


def _split_bool(res: Res, value: bool) -> tuple[Res, Res]:
    if not isinstance(res, RBool):
        return REmpty(), res
    if value:
        matched = RBool(res.has_true, False)
        remain = RBool(False, res.has_false)
    else:
        matched = RBool(False, res.has_false)
        remain = RBool(res.has_true, False)
    if r_empty(matched):
        matched = REmpty()
    if r_empty(remain):
        remain = REmpty()
    return matched, remain


def _split_int(res: Res, want: RInt) -> tuple[Res, Res]:
    if not isinstance(res, RInt):
        return REmpty(), res
    matched = int_intersect(res, want)
    remain = int_subtract(res, want)
    if r_empty(matched):
        matched = REmpty()
    if r_empty(remain):
        remain = REmpty()
    return matched, remain


def _split_tuple(res: Res, pats: tuple) -> tuple[Res, Res]:
    if not isinstance(res, RTuple):
        return REmpty(), res
    matched_alts = []
    remain_alts = []
    for alt in res.alts:
        if _alt_empty(alt):
            continue
        if len(alt) != len(pats):
            remain_alts.append(alt)
            continue
        m_alt, r_alts = _split_one_alt(alt, pats)
        if m_alt is not None:
            matched_alts.append(m_alt)
        remain_alts.extend(r_alts)
    matched = RTuple(tuple(matched_alts)) if matched_alts else REmpty()
    remain = RTuple(tuple(remain_alts)) if remain_alts else REmpty()
    if isinstance(matched, RTuple) and all(_alt_empty(a) for a in matched.alts):
        matched = REmpty()
    if isinstance(remain, RTuple) and all(_alt_empty(a) for a in remain.alts):
        remain = REmpty()
    return matched, remain


def _split_one_alt(alt: tuple, pats: tuple):
    """Product split of one tuple alternative against component patterns."""
    splits = []
    for comp, pat in zip(alt, pats):
        splits.append(split(comp, pat))
    if any(r_empty(m) for m, _ in splits):
        return None, [alt]
    matched = tuple(m for m, _ in splits)
    remainders = []
    prefix_m = []
    for i, ((m, r), orig) in enumerate(zip(splits, alt)):
        if not r_empty(r):
            remainders.append(tuple(prefix_m + [r] + list(alt[i + 1 :])))
        prefix_m.append(m)
    return matched, remainders


def pattern_has_eq(pat) -> bool:
    if isinstance(pat, PEq):
        return True
    if isinstance(pat, PTuple):
        return any(pattern_has_eq(e) for e in pat.elems)
    if isinstance(pat, PList):
        return any(pattern_has_eq(e) for e in pat.elems)
    if isinstance(pat, (PAnd, POr)):
        return pattern_has_eq(pat.left) or pattern_has_eq(pat.right)
    return False


def collect_rebindings(pat, seen=None, found=None):
    if seen is None:
        seen = set()
        found = []
    if isinstance(pat, PVar):
        if pat.name in seen:
            found.append(pat.name)
        else:
            seen.add(pat.name)
    elif isinstance(pat, PTuple):
        for e in pat.elems:
            collect_rebindings(e, seen, found)
    elif isinstance(pat, PList):
        for e in pat.elems:
            collect_rebindings(e, seen, found)
        if pat.rest and pat.rest not in ("_", "") and pat.rest is not None:
            if pat.rest in seen:
                found.append(pat.rest)
            else:
                seen.add(pat.rest)
    elif isinstance(pat, (PAnd, POr)):
        collect_rebindings(pat.left, seen, found)
        collect_rebindings(pat.right, seen, found)
    return found


def collect_bindings(pat, path=None, out=None):
    if path is None:
        path = []
        out = {}
    if isinstance(pat, PVar):
        out.setdefault(pat.name, path)
    elif isinstance(pat, PTuple):
        for i, e in enumerate(pat.elems):
            collect_bindings(e, path + [i], out)
    elif isinstance(pat, PList):
        for i, e in enumerate(pat.elems):
            collect_bindings(e, path + [i], out)
    elif isinstance(pat, (PAnd, POr)):
        collect_bindings(pat.left, path, out)
        collect_bindings(pat.right, path, out)
    return out


def guard_readable(g) -> bool:
    if g is None:
        return True
    if isinstance(g, GUnknown):
        return False
    if isinstance(g, GCmp):
        return True
    if isinstance(g, (GAnd, GOr)):
        return guard_readable(g.left) and guard_readable(g.right)
    return False


def filter_guard(res: Res, guard, paths: dict, tenv: dict) -> Res:
    if guard is None:
        return res
    if isinstance(guard, GAnd):
        return filter_guard(filter_guard(res, guard.left, paths, tenv), guard.right, paths, tenv)
    if isinstance(guard, GOr):
        return r_union(
            filter_guard(res, guard.left, paths, tenv),
            filter_guard(res, guard.right, paths, tenv),
        )
    if isinstance(guard, GCmp):
        return _filter_cmp(res, guard, paths)
    return res


def _filter_cmp(res: Res, cmp: GCmp, paths: dict) -> Res:
    path = paths.get(cmp.name)
    if path is None:
        return res
    want = _cmp_to_res(cmp)
    if want is None:
        return res
    return intersect_at_path(res, path, want)


def _cmp_to_res(cmp: GCmp) -> Optional[Res]:
    if cmp.lit_kind == "int":
        if cmp.op not in {">=", ">", "<=", "<", "=="}:
            return None
        return RInt((rel_interval(cmp.op, cmp.lit),))
    if cmp.lit_kind == "bool":
        if cmp.op != "==":
            return None
        return RBool(cmp.lit is True, cmp.lit is False)
    if cmp.lit_kind == "atom":
        if cmp.op != "==":
            return None
        return RClosed(frozenset({cmp.lit}))
    return None


def intersect_at_path(res: Res, path: list, want: Res) -> Res:
    if r_empty(res):
        return REmpty()
    if not path:
        return intersect_res(res, want)
    if isinstance(res, RTuple):
        idx = path[0]
        alts = []
        for alt in res.alts:
            if idx >= len(alt):
                continue
            newc = intersect_at_path(alt[idx], path[1:], want)
            if r_empty(newc):
                continue
            alts.append(tuple(list(alt[:idx]) + [newc] + list(alt[idx + 1 :])))
        return RTuple(tuple(alts)) if alts else REmpty()
    if isinstance(res, RSum):
        parts = [intersect_at_path(p, path, want) for p in res.parts]
        parts = [p for p in parts if not r_empty(p)]
        if not parts:
            return REmpty()
        if len(parts) == 1:
            return parts[0]
        return RSum(tuple(parts))
    return REmpty()


def intersect_res(a: Res, b: Res) -> Res:
    if r_empty(a) or r_empty(b):
        return REmpty()
    if isinstance(a, RInt) and isinstance(b, RInt):
        return int_intersect(a, b)
    if isinstance(a, RBool) and isinstance(b, RBool):
        return RBool(a.has_true and b.has_true, a.has_false and b.has_false)
    if isinstance(a, RClosed) and isinstance(b, RClosed):
        return RClosed(a.atoms & b.atoms)
    if isinstance(a, RClosed) and isinstance(b, ROpen):
        if b.caught:
            return REmpty()
        return RClosed(a.atoms - b.excluded)
    if isinstance(a, ROpen) and isinstance(b, RClosed):
        if a.caught:
            return REmpty()
        return RClosed(b.atoms - a.excluded)
    if isinstance(a, ROpen) and isinstance(b, ROpen):
        if a.caught or b.caught:
            return REmpty()
        return ROpen(a.excluded | b.excluded, False)
    if isinstance(a, RTuple) and isinstance(b, RTuple):
        alts = []
        for aa in a.alts:
            for bb in b.alts:
                if len(aa) != len(bb):
                    continue
                comps = tuple(intersect_res(x, y) for x, y in zip(aa, bb))
                if not _alt_empty(comps):
                    alts.append(comps)
        return RTuple(tuple(alts)) if alts else REmpty()
    if isinstance(a, RSum):
        parts = [intersect_res(p, b) for p in a.parts]
        parts = [p for p in parts if not r_empty(p)]
        return parts[0] if len(parts) == 1 else (RSum(tuple(parts)) if parts else REmpty())
    if isinstance(b, RSum):
        return intersect_res(b, a)
    return REmpty()


def subtract_res(a: Res, b: Res) -> Res:
    """Best-effort a - b for guard remainder."""
    if r_empty(a) or r_empty(b):
        return a
    if isinstance(a, RInt) and isinstance(b, RInt):
        return int_subtract(a, b)
    if isinstance(a, RBool) and isinstance(b, RBool):
        return RBool(a.has_true and not b.has_true, a.has_false and not b.has_false)
    if isinstance(a, RClosed) and isinstance(b, RClosed):
        return RClosed(a.atoms - b.atoms)
    if isinstance(a, RTuple) and isinstance(b, RTuple):
        # subtract each b-alt from a
        cur = a
        for balt in b.alts:
            m, r = _split_tuple(cur, _alt_as_pats_impossible())
            # fall back to product split using a fake exact residual match:
            cur = _subtract_tuple_alt(cur, balt)
        return cur
    if isinstance(a, ROpen) and isinstance(b, RClosed):
        return ROpen(a.excluded | b.atoms, a.caught)
    if isinstance(a, ROpen) and isinstance(b, ROpen) and b.caught:
        return REmpty()
    return a


def _alt_as_pats_impossible():
    return ()


def _subtract_tuple_alt(res: RTuple, balt: tuple) -> Res:
    remain_alts = []
    for alt in res.alts:
        if len(alt) != len(balt):
            remain_alts.append(alt)
            continue
        prefix_m = []
        fully = True
        for i, (ac, bc) in enumerate(zip(alt, balt)):
            inter = intersect_res(ac, bc)
            leftover = subtract_res(ac, bc)
            if not r_empty(leftover):
                remain_alts.append(tuple(prefix_m + [leftover] + list(alt[i + 1 :])))
            if r_empty(inter):
                fully = False
                # nothing of this prefix matches balt; keep the rest of alt as-is
                # (already added leftover which is ac since no overlap)
                break
            prefix_m.append(inter)
        # if fully matched along all components, those values are subtracted
        # (no extra remainder)
        if not fully:
            # unmatched prefix already handled
            pass
    remain_alts = [a for a in remain_alts if not _alt_empty(a)]
    return RTuple(tuple(remain_alts)) if remain_alts else REmpty()


# ---------------------------------------------------------------------------
# Type checking of expressions (return_not_declared)
# ---------------------------------------------------------------------------

def expr_definitely_not_in(expr, expected: Type, env: dict, tenv: dict) -> bool:
    expected = resolve(expected, tenv)
    if isinstance(expr, ESwitch):
        return False  # arms checked individually
    got = infer_lit(expr, env, tenv)
    if got is None:
        return False  # unknown — do not guess
    return not inhabits(got, expected, tenv)


def infer_lit(expr, env: dict, tenv: dict):
    if isinstance(expr, EInt):
        return TInt()
    if isinstance(expr, EBool):
        return TBool()
    if isinstance(expr, EAtom):
        return TClosed(frozenset({expr.name}))
    if isinstance(expr, ETuple):
        elems = []
        for e in expr.elems:
            t = infer_lit(e, env, tenv)
            if t is None:
                return None
            elems.append(t)
        return TTuple(tuple(elems))
    if isinstance(expr, EVar):
        return env.get(expr.name)
    if isinstance(expr, EField):
        obj_t = infer_lit(expr.obj, env, tenv)
        if obj_t is None:
            return None
        obj_t = resolve(obj_t, tenv)
        if isinstance(obj_t, TRecord) and expr.name in obj_t.fields:
            return obj_t.fields[expr.name]
        return None
    return None


def inhabits(got: Type, expected: Type, tenv: dict) -> bool:
    got = resolve(got, tenv)
    expected = resolve(expected, tenv)
    if isinstance(expected, TInt):
        return isinstance(got, TInt)
    if isinstance(expected, TBool):
        return isinstance(got, TBool)
    if isinstance(expected, TAtom):
        return isinstance(got, (TAtom, TClosed))
    if isinstance(expected, TTerm):
        return True
    if isinstance(expected, TClosed):
        if isinstance(got, TClosed):
            return got.atoms <= expected.atoms
        if isinstance(got, TAtom):
            return False
        return False
    if isinstance(expected, TTuple) and isinstance(got, TTuple):
        if len(expected.elems) != len(got.elems):
            return False
        return all(inhabits(g, e, tenv) for g, e in zip(got.elems, expected.elems))
    if isinstance(expected, TNamed):
        return True  # unknown declared type — don't guess
    if isinstance(expected, TSum):
        return any(inhabits(got, v, tenv) for v in expected.variants)
    if isinstance(expected, TRecord):
        return isinstance(got, TRecord) and got.name == expected.name
    if isinstance(expected, TList):
        return isinstance(got, TList) and inhabits(got.elem, expected.elem, tenv)
    return True


# ---------------------------------------------------------------------------
# Subject type inference
# ---------------------------------------------------------------------------

def infer_subject(expr, env: dict, tenv: dict) -> Optional[Type]:
    if isinstance(expr, EVar):
        return env.get(expr.name)
    if isinstance(expr, ETuple):
        elems = []
        for e in expr.elems:
            t = infer_subject(e, env, tenv)
            if t is None:
                return None
            elems.append(t)
        return TTuple(tuple(elems))
    if isinstance(expr, EField):
        obj_t = infer_subject(expr.obj, env, tenv)
        if obj_t is None:
            return None
        obj_t = resolve(obj_t, tenv)
        if isinstance(obj_t, TRecord) and expr.name in obj_t.fields:
            return obj_t.fields[expr.name]
        return None
    if isinstance(expr, EAtom):
        return TClosed(frozenset({expr.name}))
    if isinstance(expr, EInt):
        return TInt()
    if isinstance(expr, EBool):
        return TBool()
    return None


def subject_paths(expr) -> dict:
    paths = {}
    if isinstance(expr, EVar):
        paths[expr.name] = []
    elif isinstance(expr, ETuple):
        for i, e in enumerate(expr.elems):
            if isinstance(e, EVar):
                paths[e.name] = [i]
            elif isinstance(e, ETuple):
                for name, p in subject_paths(e).items():
                    paths[name] = [i] + p
    return paths


def bind_pattern_to_type(pat, ty: Type, tenv: dict, env: dict):
    ty = resolve(ty, tenv)
    if isinstance(pat, PVar):
        env[pat.name] = ty
    elif isinstance(pat, PTuple) and isinstance(ty, TTuple) and len(pat.elems) == len(ty.elems):
        for p, t in zip(pat.elems, ty.elems):
            bind_pattern_to_type(p, t, tenv, env)
    elif isinstance(pat, PTuple) and isinstance(ty, TSum):
        # bind from the first matching variant of same arity
        for v in ty.variants:
            v = resolve(v, tenv)
            if isinstance(v, TTuple) and len(v.elems) == len(pat.elems):
                bind_pattern_to_type(pat, v, tenv, env)
                break
    elif isinstance(pat, PList) and isinstance(ty, TList):
        for p in pat.elems:
            bind_pattern_to_type(p, ty.elem, tenv, env)
        if pat.rest and pat.rest not in ("_", ""):
            env[pat.rest] = ty


# ---------------------------------------------------------------------------
# Checker
# ---------------------------------------------------------------------------

class Checker:
    def __init__(self, prog: Program):
        self.prog = prog
        self.tenv = dict(prog.types)
        self.tags: list[str] = []
        self.seen: set[str] = set()

    def emit(self, tag: str):
        if tag not in self.seen:
            self.seen.add(tag)
            self.tags.append(tag)

    def run(self):
        for cl in self.prog.clauses:
            self.check_clause(cl)
        return self.tags

    def check_clause(self, cl: Clause):
        sig = self.prog.sigs.get(cl.name)
        env: dict = {}
        expected = None
        if sig is not None:
            expected = sig.ret
            for (ty, _pname), pat in zip(sig.params, cl.patterns):
                bind_pattern_to_type(pat, ty, self.tenv, env)
            # also bind signature names if unused in pattern
            for ty, pname in sig.params:
                env.setdefault(pname, ty)
        bound: set = set()
        rebound: list = []
        for pat in cl.patterns:
            collect_rebindings(pat, bound, rebound)
        if rebound:
            self.emit("rebinding")
        self.check_expr(cl.body, expected, env, bound)

    def check_expr(self, expr, expected: Optional[Type], env: dict, bound: set):
        if isinstance(expr, ESwitch):
            self.check_switch(expr, expected, env, bound)
            return
        if expected is not None and expr_definitely_not_in(expr, expected, env, self.tenv):
            self.emit("return_not_declared")
        if isinstance(expr, ETuple):
            if isinstance(expected, TTuple) and len(expected.elems) == len(expr.elems):
                for e, t in zip(expr.elems, expected.elems):
                    self.check_expr(e, t, env, bound)
            else:
                for e in expr.elems:
                    self.check_expr(e, None, env, bound)
        elif isinstance(expr, ECall):
            for a in expr.args:
                self.check_expr(a, None, env, bound)
        elif isinstance(expr, EBin):
            self.check_expr(expr.left, None, env, bound)
            self.check_expr(expr.right, None, env, bound)
        elif isinstance(expr, EField):
            self.check_expr(expr.obj, None, env, bound)

    def check_switch(self, sw: ESwitch, expected: Optional[Type], env: dict, bound: set):
        self.check_expr(sw.subject, None, env, bound)
        sty = infer_subject(sw.subject, env, self.tenv)

        def arm_bound(pat) -> set:
            """Names in scope inside this arm: enclosing bindings plus this pattern."""
            rebound: list = []
            seen = set(bound)
            collect_rebindings(pat, seen, rebound)
            if rebound:
                self.emit("rebinding")
            return seen

        if sty is None:
            # cannot analyse exhaustiveness without a declared subject type
            for arm in sw.arms:
                inner = arm_bound(arm.pattern)
                self.check_expr(arm.body, expected, env, inner)
            return

        residual = full_of(sty, self.tenv)
        subj_paths = subject_paths(sw.subject)

        for arm in sw.arms:
            inner = arm_bound(arm.pattern)

            struct_m, struct_r = split(residual, arm.pattern)
            credits = not pattern_has_eq(arm.pattern)
            readable = guard_readable(arm.guard)
            if not readable:
                credits = False

            paths = dict(subj_paths)
            paths.update(collect_bindings(arm.pattern))

            if arm.guard is not None and readable:
                guarded = filter_guard(struct_m, arm.guard, paths, self.tenv)
            else:
                guarded = struct_m

            if r_empty(guarded) if (arm.guard is None or readable) else r_empty(struct_m):
                self.emit("unreachable_arm")

            if credits and (arm.guard is None or readable):
                if arm.guard is None:
                    residual = struct_r
                else:
                    failing = subtract_res(struct_m, guarded)
                    residual = r_union(struct_r, failing)
            # else: residual unchanged

            self.check_expr(arm.body, expected, env, inner)

        if not r_empty(residual):
            # Unknown residual that we couldn't subtract anything from should
            # still be reported if we never saw a catch-all. RUnknown without
            # catch is inexhaustive; RUnknown.caught is empty.
            if isinstance(residual, RUnknown) and not residual.caught:
                # we did not successfully model this type; don't guess
                pass
            else:
                self.emit("switch_inexhaustive")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def analyse(src: str) -> list[str]:
    tokens = lex(src)
    prog = Parser(tokens).parse_program()
    return Checker(prog).run()


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        return 1
    path = argv[1]
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    try:
        tags = analyse(src)
    except (LexError, ParseError):
        return 0
    for t in tags:
        print(t)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
