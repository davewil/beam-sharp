#!/usr/bin/env python3
"""
switchcheck: exhaustiveness / well-formedness checker for the toy language
described in PACKET.md.

Prints one lowercase diagnostic tag per line, from the fixed vocabulary:
    switch_inexhaustive
    unreachable_arm
    rebinding
    return_not_declared

Nothing is printed for a well-formed program.
"""
import sys
import re

TAGS = set()


def emit(tag):
    TAGS.add(tag)


# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------
# Type descriptors are tuples:
#   ('bool',)
#   ('int',)
#   ('atom', None)                    -- open atom (any atom literal)
#   ('atomenum', (name, (v1,v2,...))) -- closed sum of bare atom literals
#   ('string',)
#   ('term',)
#   ('tuple', (t1, t2, ...))
#   ('list', elem_type)
#   ('sum', (name, {tag: [payload_types...]}))
#   ('record', (name, [(field, type), ...]))
#   ('unknown',)

def is_open_leaf(t):
    return t[0] in ('atom', 'string', 'term', 'unknown')


# ---------------------------------------------------------------------------
# Tokenizing helpers
# ---------------------------------------------------------------------------

def split_top_level(s, sep=','):
    """Split s on top-level occurrences of sep, respecting (), [], {}."""
    parts = []
    depth = 0
    cur = ''
    i = 0
    while i < len(s):
        c = s[i]
        if c in '([{':
            depth += 1
            cur += c
        elif c in ')]}':
            depth -= 1
            cur += c
        elif c == sep and depth == 0:
            parts.append(cur)
            cur = ''
        else:
            cur += c
        i += 1
    if cur.strip() != '' or parts:
        parts.append(cur)
    return [p.strip() for p in parts if p.strip() != '']


def strip_outer(s, open_c, close_c):
    s = s.strip()
    if s.startswith(open_c) and s.endswith(close_c):
        return s[1:-1]
    return None


# ---------------------------------------------------------------------------
# Declarations
# ---------------------------------------------------------------------------

def parse_type_decl(name, rhs, types):
    variants = split_top_level(rhs, '|')
    atoms = []
    tagged = {}
    is_pure_atoms = True
    for v in variants:
        v = v.strip()
        if v.startswith(':') and re.match(r'^:[A-Za-z_][A-Za-z0-9_]*$', v):
            atoms.append(v[1:])
        else:
            is_pure_atoms = False
            inner = strip_outer(v, '(', ')')
            if inner is None:
                continue
            parts = split_top_level(inner, ',')
            if not parts:
                continue
            tag = parts[0].strip()
            if tag.startswith(':'):
                tag = tag[1:]
            payload_types = [resolve_type_name(p.strip(), types) for p in parts[1:]]
            tagged[tag] = payload_types
    if is_pure_atoms and atoms:
        types[name] = ('atomenum', (name, tuple(atoms)))
    else:
        types[name] = ('sum', (name, tagged))


def resolve_type_name(txt, types):
    txt = txt.strip()
    m = re.match(r'^list<(.+)>$', txt)
    if m:
        return ('list', resolve_type_name(m.group(1), types))
    if txt == 'int':
        return ('int',)
    if txt == 'bool':
        return ('bool',)
    if txt == 'atom':
        return ('atom', None)
    if txt == 'string':
        return ('string',)
    if txt == 'term':
        return ('term',)
    if txt in types:
        return types[txt]
    return ('unknown',)


def parse_record_decl(name, body, types):
    fields = []
    for part in split_top_level(body, ','):
        if ':' not in part:
            continue
        fname, ftxt = part.split(':', 1)
        fields.append((fname.strip(), resolve_type_name(ftxt.strip(), types)))
    types[name] = ('record', (name, fields))


# ---------------------------------------------------------------------------
# Pattern AST
# ---------------------------------------------------------------------------
# Node kinds:
#   ('wild',)
#   ('var', name)
#   ('eqvar', name)
#   ('lit', kind, value)         kind in ('atom','int','bool','string')
#   ('interval', lo, hi)         inclusive bounds, None = unbounded
#   ('tuple', [nodes])
#   ('sumtag', tag, [nodes])
#   ('list', prefix_nodes, rest) rest: None(exact) / 'discard' / ('bind', name)
#   ('record', {field: node})


def contains_eqvar(node):
    if node[0] == 'eqvar':
        return True
    if node[0] == 'tuple':
        return any(contains_eqvar(n) for n in node[1])
    if node[0] == 'sumtag':
        return any(contains_eqvar(n) for n in node[2])
    if node[0] == 'list':
        if any(contains_eqvar(n) for n in node[1]):
            return True
        return False
    if node[0] == 'record':
        return any(contains_eqvar(n) for n in node[1].values())
    return False


def collect_bound_names_typed(node, ty, out):
    if node[0] == 'var':
        out.append((node[1], ty))
    elif node[0] == 'tuple':
        subtypes = ty[1] if ty[0] == 'tuple' else [('unknown',)] * len(node[1])
        for i, n in enumerate(node[1]):
            st = subtypes[i] if i < len(subtypes) else ('unknown',)
            collect_bound_names_typed(n, st, out)
    elif node[0] == 'sumtag':
        tagged = ty[1][1] if ty[0] == 'sum' else {}
        subtypes = tagged.get(node[1], [])
        for i, n in enumerate(node[2]):
            st = subtypes[i] if i < len(subtypes) else ('unknown',)
            collect_bound_names_typed(n, st, out)
    elif node[0] == 'list':
        elem_ty = ty[1] if ty[0] == 'list' else ('unknown',)
        for n in node[1]:
            collect_bound_names_typed(n, elem_ty, out)
        if node[2] and isinstance(node[2], tuple) and node[2][0] == 'bind':
            out.append((node[2][1], ty))
    elif node[0] == 'record':
        field_types = dict(ty[1][1]) if ty[0] == 'record' else {}
        for f, n in node[1].items():
            collect_bound_names_typed(n, field_types.get(f, ('unknown',)), out)


def apply_guard_to_pattern(node, varname, lo, hi):
    """Return a copy of `node` where any bare-var leaf named `varname` is
    replaced by an interval node reflecting the guard's refinement. This lets
    a guard on a variable bound deep inside a tuple/sum pattern narrow that
    position for exhaustiveness purposes, per: 'A guard the checker can read
    as a type operation refines the clause.'"""
    k = node[0]
    if k == 'var' and node[1] == varname:
        return ('interval', lo, hi)
    if k == 'tuple':
        return ('tuple', [apply_guard_to_pattern(n, varname, lo, hi) for n in node[1]])
    if k == 'sumtag':
        return ('sumtag', node[1], [apply_guard_to_pattern(n, varname, lo, hi) for n in node[2]])
    if k == 'list':
        return ('list', [apply_guard_to_pattern(n, varname, lo, hi) for n in node[1]], node[2])
    if k == 'record':
        return ('record', {f: apply_guard_to_pattern(n, varname, lo, hi) for f, n in node[1].items()})
    return node


def collect_bound_names(node, out):
    if node[0] == 'var':
        out.append(node[1])
    elif node[0] == 'tuple':
        for n in node[1]:
            collect_bound_names(n, out)
    elif node[0] == 'sumtag':
        for n in node[2]:
            collect_bound_names(n, out)
    elif node[0] == 'list':
        for n in node[1]:
            collect_bound_names(n, out)
        if node[2] and isinstance(node[2], tuple) and node[2][0] == 'bind':
            out.append(node[2][1])
    elif node[0] == 'record':
        for n in node[1].values():
            collect_bound_names(n, out)


REL_RE = re.compile(r'^(>=|<=|>|<)\s*(-?\d+)$')
INT_RE = re.compile(r'^-?\d+$')
IDENT_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')


def parse_pattern(text, ty):
    text = text.strip()
    if text == '_':
        return ('wild',)
    if text.startswith('=='):
        name = text[2:].strip()
        return ('eqvar', name)
    if text.startswith(':'):
        m = re.match(r'^:([A-Za-z_][A-Za-z0-9_]*)$', text)
        if m:
            return ('lit', 'atom', m.group(1))
    if text == 'true':
        return ('lit', 'bool', True)
    if text == 'false':
        return ('lit', 'bool', False)
    if text.startswith('"') and text.endswith('"'):
        return ('lit', 'string', text[1:-1])
    # relational / interval combos, joined by 'and'
    if re.match(r'^(>=|<=|>|<)', text):
        parts = re.split(r'\s+and\s+', text)
        lo, hi = None, None
        ok = True
        for p in parts:
            m = REL_RE.match(p.strip())
            if not m:
                ok = False
                break
            op, val = m.group(1), int(m.group(2))
            if op == '>=':
                lo = val if lo is None else max(lo, val)
            elif op == '>':
                lo = val + 1 if lo is None else max(lo, val + 1)
            elif op == '<=':
                hi = val if hi is None else min(hi, val)
            elif op == '<':
                hi = val - 1 if hi is None else min(hi, val - 1)
        if ok:
            return ('interval', lo, hi)
    if INT_RE.match(text):
        return ('lit', 'int', int(text))
    inner = strip_outer(text, '(', ')')
    if inner is not None:
        parts = split_top_level(inner, ',')
        if ty[0] == 'sum':
            tagged = ty[1][1]
            if parts and re.match(r'^:[A-Za-z_][A-Za-z0-9_]*$', parts[0].strip()):
                tag = parts[0].strip()[1:]
                payload_types = tagged.get(tag, [])
                subs = []
                for i, p in enumerate(parts[1:]):
                    pt = payload_types[i] if i < len(payload_types) else ('unknown',)
                    subs.append(parse_pattern(p, pt))
                return ('sumtag', tag, subs)
        # plain tuple
        subtypes = ty[1] if ty[0] == 'tuple' else None
        subs = []
        for i, p in enumerate(parts):
            st = subtypes[i] if subtypes and i < len(subtypes) else ('unknown',)
            subs.append(parse_pattern(p, st))
        return ('tuple', subs)
    inner = strip_outer(text, '[', ']')
    if inner is not None:
        parts = split_top_level(inner, ',')
        elem_ty = ty[1] if ty[0] == 'list' else ('unknown',)
        rest = None
        prefix_parts = parts
        if parts and (parts[-1] == '..' or parts[-1].startswith('..')):
            last = parts[-1]
            prefix_parts = parts[:-1]
            if last == '..':
                rest = 'discard'
            else:
                rest = ('bind', last[2:])
        prefix_nodes = [parse_pattern(p, elem_ty) for p in prefix_parts]
        return ('list', prefix_nodes, rest)
    inner = strip_outer(text, '{', '}')
    if inner is not None:
        parts = split_top_level(inner, ',')
        fields = {}
        field_types = dict(ty[1][1]) if ty[0] == 'record' else {}
        for p in parts:
            if ':' not in p:
                continue
            fname, ftxt = p.split(':', 1)
            fname = fname.strip()
            ft = field_types.get(fname, ('unknown',))
            fields[fname] = parse_pattern(ftxt.strip(), ft)
        return ('record', fields)
    if IDENT_RE.match(text):
        return ('var', text)
    return ('wild',)


# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------
# Returns dict varname -> ('interval', lo, hi) OR None if unreadable.
# Only supports conjunctions/disjunctions of `name OP intlit` all about ONE
# variable name; for simplicity we only credit a guard when every comparison
# in it refers to the SAME single variable, combined with 'and' (intersection).
# 'or' combos are treated as unreadable (credit nothing) to stay conservative.

def parse_guard(text):
    if text is None:
        return None
    text = text.strip()
    if not text:
        return None
    if re.search(r'\bor\b', text):
        return None  # not confidently readable; credit nothing
    parts = re.split(r'\band\b', text)
    var = None
    lo, hi = None, None
    for p in parts:
        p = p.strip()
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*(>=|<=|>|<)\s*(-?\d+)$', p)
        if not m:
            return None
        v, op, val = m.group(1), m.group(2), int(m.group(3))
        if var is None:
            var = v
        elif var != v:
            return None
        val = int(val)
        if op == '>=':
            lo = val if lo is None else max(lo, val)
        elif op == '>':
            lo = val + 1 if lo is None else max(lo, val + 1)
        elif op == '<=':
            hi = val if hi is None else min(hi, val)
        elif op == '<':
            hi = val - 1 if hi is None else min(hi, val - 1)
    if var is None:
        return None
    return (var, lo, hi)


# ---------------------------------------------------------------------------
# Interval domain (for a single int column at the top level)
# ---------------------------------------------------------------------------

def _lt(x, y):
    """x < y, treating None as -inf for x-position and +inf handled by
    caller context; here None in x means -inf, None in y means +inf."""
    if x is None:
        return y is None or True  # -inf < anything (incl +inf)
    if y is None:
        return True  # anything finite < +inf
    return x < y


def interval_subtract(intervals, lo, hi):
    """Subtract [lo,hi] (None=unbounded) from list of (a,b) intervals
    (None=unbounded on either side), returning the remaining pieces."""
    if lo is None and hi is None:
        return []
    result = []
    for (a, b) in intervals:
        # overlap test: overlap unless b < lo or a > hi
        no_overlap = False
        if lo is not None and b is not None and b < lo:
            no_overlap = True
        if hi is not None and a is not None and a > hi:
            no_overlap = True
        if no_overlap:
            result.append((a, b))
            continue
        # left remainder: (a, lo-1) if a < lo
        if lo is not None:
            if a is None or a < lo:
                left_hi = lo - 1
                if a is None or left_hi >= a:
                    result.append((a, left_hi))
        else:
            pass  # lo is None (-inf): no left remainder
        # right remainder: (hi+1, b) if b > hi
        if hi is not None:
            if b is None or b > hi:
                right_lo = hi + 1
                if b is None or right_lo <= b:
                    result.append((right_lo, b))
        else:
            pass  # hi is None (+inf): no right remainder
    clean = []
    for (a, b) in result:
        if a is not None and b is not None and a > b:
            continue
        clean.append((a, b))
    return clean


def interval_is_empty(intervals):
    return len(intervals) == 0


# ---------------------------------------------------------------------------
# Generic constructor-based domain model (Maranget-style usefulness check)
# ---------------------------------------------------------------------------
# A "row" for the generic matrix is a list of pattern nodes (one per column,
# after eqvar-rows have already been filtered out by the caller).


def domain_constructors(ty):
    """Return list of (ctor_key, [subtypes]) for a type, or None if the type
    has an unbounded / not-enumerable constructor set."""
    if ty[0] == 'bool':
        return [(True, []), (False, [])]
    if ty[0] == 'atomenum':
        return [(v, []) for v in ty[1][1]]
    if ty[0] == 'tuple':
        return [('tuple', list(ty[1]))]
    if ty[0] == 'record':
        field_types = [ft for (_, ft) in ty[1][1]]
        return [('record', field_types)]
    if ty[0] == 'sum':
        tagged = ty[1][1]
        return [(tag, list(pts)) for tag, pts in tagged.items()]
    if ty[0] == 'list':
        elem = ty[1]
        return [('nil', []), ('cons', [elem, ty])]
    # open / unknown / int / atom(open) / string / term
    return None


def node_ctor(node, ty):
    """Return (ctor_key, sub_nodes) for a concrete (non-wildcard) pattern
    node, matching the type's constructor space. Returns None if node is a
    wildcard/var (not a concrete constructor)."""
    k = node[0]
    if k in ('wild', 'var', 'eqvar'):
        return None
    if k == 'lit':
        return (node[2], [])
    if k == 'tuple':
        return ('tuple', node[1])
    if k == 'sumtag':
        return (node[1], node[2])
    if k == 'record':
        if ty[0] == 'record':
            field_names = [f for f, _ in ty[1][1]]
            subs = [node[1].get(f, ('wild',)) for f in field_names]
            return ('record', subs)
        return ('record', list(node[1].values()))
    if k == 'list':
        prefix, rest = node[1], node[2]
        if not prefix:
            if rest is None:
                return ('nil', [])
            else:
                # [..] or [..t] with empty prefix: matches nil or cons -> not
                # a single concrete constructor; treat as wildcard (matches
                # any list) since it covers both zero-or-more.
                return None
        head = prefix[0]
        tail_prefix = prefix[1:]
        tail_rest = rest
        tail_node = ('list', tail_prefix, tail_rest)
        return ('cons', [head, tail_node])
    if k == 'interval':
        return None  # handled separately; shouldn't reach generic engine
    return None


def is_wild(node):
    if node[0] in ('wild', 'var', 'eqvar'):
        return True
    if node[0] == 'list' and not node[1] and node[2] is not None:
        # `[..]` or `[..name]` with an empty prefix: matches any list
        # (zero or more elements) -- equivalent to a wildcard for this
        # column.
        return True
    return False


def specialize(matrix, ctor_key, arity, types0):
    """matrix: list of rows (list of nodes). Returns new matrix with column0
    replaced by `arity` new columns, keeping only rows whose column0 matches
    ctor_key (or is wildcard)."""
    out = []
    for row in matrix:
        head = row[0]
        c = node_ctor(head, types0)
        if is_wild(head):
            newcols = [('wild',)] * arity
            out.append(newcols + row[1:])
        elif c is not None and c[0] == ctor_key:
            subs = c[1]
            # pad/truncate to arity
            subs = list(subs) + [('wild',)] * (arity - len(subs))
            out.append(subs[:arity] + row[1:])
    return out


def default_matrix(matrix):
    out = []
    for row in matrix:
        if is_wild(row[0]):
            out.append(row[1:])
    return out


def used_constructors(matrix, ty):
    used = set()
    for row in matrix:
        c = node_ctor(row[0], ty)
        if c is not None:
            used.add(c[0])
    return used


def _node_as_interval(n):
    if n[0] == 'interval':
        return (n[1], n[2])
    if n[0] == 'lit' and n[1] == 'int':
        return (n[2], n[2])
    return (None, None)  # wildcard / var / anything else -> full range


def useful(matrix, query, types):
    """Is `query` (list of pattern nodes) useful against `matrix` (list of
    rows) for the given column `types`? True means query covers at least one
    value combination not covered by matrix."""
    if not types:
        return len(matrix) == 0
    ty0 = types[0]
    q0 = query[0]
    if ty0[0] == 'int':
        qlo, qhi = _node_as_interval(q0)
        remaining = [(qlo, qhi)]
        for r in matrix:
            a, b = _node_as_interval(r[0])
            remaining = interval_subtract(remaining, a, b)
            if not remaining:
                break
        if remaining:
            if not types[1:]:
                return True
            sub_matrix = [r[1:] for r in matrix]
            return useful(sub_matrix, query[1:], types[1:])
        else:
            if not types[1:]:
                return False
            sub_matrix = [r[1:] for r in matrix]
            return useful(sub_matrix, query[1:], types[1:])
    ctors = domain_constructors(ty0)
    if not is_wild(q0):
        c = node_ctor(q0, ty0)
        if c is None:
            # couldn't classify (e.g. malformed) -- be conservative: treat as
            # wildcard so we never falsely report unreachable.
            c = None
        if c is not None:
            ctor_key, subs = c
            arity = len(subs) if ctors is None else None
            if ctors is not None:
                for key, subtypes in ctors:
                    if key == ctor_key:
                        arity = len(subtypes)
                        sub_types = subtypes
                        break
                else:
                    sub_types = [('unknown',)] * len(subs)
            else:
                sub_types = [('unknown',)] * len(subs)
            m1 = specialize(matrix, ctor_key, len(sub_types), ty0)
            q1 = list(subs) + [('wild',)] * (len(sub_types) - len(subs))
            q1 = q1[:len(sub_types)] + query[1:]
            t1 = list(sub_types) + list(types[1:])
            return useful(m1, q1, t1)
        else:
            return useful(default_matrix(matrix), query[1:], types[1:])
    else:
        if ctors is None:
            # open/unbounded domain: only the default (wildcard) matrix
            # matters
            return useful(default_matrix(matrix), query[1:], types[1:])
        used = used_constructors(matrix, ty0)
        full = set(k for k, _ in ctors)
        if used >= full:
            for key, subtypes in ctors:
                m1 = specialize(matrix, key, len(subtypes), ty0)
                q1 = [('wild',)] * len(subtypes) + query[1:]
                t1 = list(subtypes) + list(types[1:])
                if useful(m1, q1, t1):
                    return True
            return False
        else:
            return useful(default_matrix(matrix), query[1:], types[1:])


def matrix_exhaustive(matrix, types):
    query = [('wild',)] * len(types)
    return not useful(matrix, query, types)


# ---------------------------------------------------------------------------
# Function / clause parsing
# ---------------------------------------------------------------------------

class Clause:
    def __init__(self, args_text, guard_text, body_text):
        self.args_text = args_text
        self.guard_text = guard_text
        self.body_text = body_text


def find_matching_paren(s, start):
    depth = 0
    for i in range(start, len(s)):
        if s[i] == '(':
            depth += 1
        elif s[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


def extract_statements(body):
    """Split the source (post-declarations) into top-level clause
    statements, each of the form `Name(...) [when ...] -> expr` where expr
    may itself contain braces that must balance before the statement ends."""
    stmts = []
    i = 0
    n = len(body)
    cur_start = None
    depth = 0
    lines = body.split('\n')
    buf = []
    brace_depth = 0
    started = False
    ident_start_re = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*\(')
    for line in lines:
        stripped = line.strip()
        if not started:
            if ident_start_re.match(stripped):
                started = True
                buf = [line]
                brace_depth = line.count('{') - line.count('}')
                if brace_depth <= 0 and not stripped.endswith('{'):
                    # single line clause complete if braces balanced
                    if brace_depth == 0:
                        stmts.append('\n'.join(buf))
                        buf = []
                        started = False
            continue
        else:
            buf.append(line)
            brace_depth += line.count('{') - line.count('}')
            if brace_depth <= 0:
                stmts.append('\n'.join(buf))
                buf = []
                started = False
    if buf:
        stmts.append('\n'.join(buf))
    return stmts


def parse_clause_stmt(stmt):
    m = re.match(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\(', stmt)
    if not m:
        return None
    name = m.group(1)
    open_paren = stmt.index('(', m.start())
    close_paren = find_matching_paren(stmt, open_paren)
    args_text = stmt[open_paren + 1:close_paren]
    rest = stmt[close_paren + 1:].strip()
    guard_text = None
    if rest.startswith('when'):
        arrow_idx = rest.find('->')
        guard_text = rest[4:arrow_idx].strip()
        rest = rest[arrow_idx:]
    if not rest.startswith('->'):
        return None
    body_text = rest[2:].strip()
    return name, args_text, guard_text, body_text


# ---------------------------------------------------------------------------
# Expression (return value) typing -- best effort, conservative
# ---------------------------------------------------------------------------

def literal_kind_of_expr(expr):
    expr = expr.strip()
    if expr.startswith(':'):
        m = re.match(r'^:([A-Za-z_][A-Za-z0-9_]*)$', expr)
        if m:
            return ('atom', m.group(1))
    if expr == 'true' or expr == 'false':
        return ('bool', expr == 'true')
    if INT_RE.match(expr):
        return ('int', int(expr))
    if expr.startswith('"') and expr.endswith('"'):
        return ('string', expr[1:-1])
    return None


def type_matches_return(rt, kind, value):
    if rt[0] == 'term':
        return True
    if rt[0] == 'unknown':
        return True
    if kind == 'atom':
        if rt[0] == 'atom':
            return True
        if rt[0] == 'atomenum':
            return value in rt[1][1]
        return False
    if kind == 'bool':
        return rt[0] == 'bool'
    if kind == 'int':
        return rt[0] == 'int'
    if kind == 'string':
        return rt[0] == 'string'
    return True


# ---------------------------------------------------------------------------
# Switch-expression parsing
# ---------------------------------------------------------------------------

def parse_switch_arms(body):
    """body like `<subject> switch { arm1, arm2, ... }`. Returns
    (subject_text, [(pattern_text, guard_text, expr_text), ...]) or None."""
    m = re.search(r'\bswitch\s*\{', body)
    if not m:
        return None
    subject_text = body[:m.start()].strip()
    brace_start = body.index('{', m.start())
    depth = 0
    end = None
    for i in range(brace_start, len(body)):
        if body[i] == '{':
            depth += 1
        elif body[i] == '}':
            depth -= 1
            if depth == 0:
                end = i
                break
    inner = body[brace_start + 1:end]
    arm_texts = split_top_level(inner, ',')
    arms = []
    for at in arm_texts:
        at = at.strip()
        if '=>' not in at:
            continue
        left, right = at.split('=>', 1)
        left = left.strip()
        right = right.strip()
        guard_text = None
        if left.startswith('when'):
            left = left[4:].strip()
        wm = re.search(r'\bwhen\b', left)
        if wm:
            pat_text = left[:wm.start()].strip()
            guard_text = left[wm.end():].strip()
        else:
            pat_text = left
        arms.append((pat_text, guard_text, right))
    return subject_text, arms


def resolve_subject_type(subject_text, param_types, record_field_types):
    subject_text = subject_text.strip()
    if subject_text in param_types:
        return param_types[subject_text], subject_text
    if '.' in subject_text:
        base, field = subject_text.split('.', 1)
        if base in param_types:
            bt = param_types[base]
            if bt[0] == 'record':
                for f, ft in bt[1][1]:
                    if f == field:
                        return ft, None
        return ('unknown',), None
    inner = strip_outer(subject_text, '(', ')')
    if inner is not None:
        parts = split_top_level(inner, ',')
        sub_types = []
        names = []
        for p in parts:
            t, nm = resolve_subject_type(p, param_types, record_field_types)
            sub_types.append(t)
            names.append(nm)
        return ('tuple', tuple(sub_types)), None
    return ('unknown',), None


# ---------------------------------------------------------------------------
# Core check logic shared between clause-heads and switch-arms
# ---------------------------------------------------------------------------

def check_rows(rows, types, scope_names_per_row=None):
    """rows: list of dicts with keys 'pattern' (list of nodes, one per
    column) and 'guard' (parsed guard tuple or None, only meaningful when
    types is a single int column).
    Returns (inexhaustive: bool, unreachable_flags: list[bool])
    """
    n = len(rows)
    unreachable = [False] * n

    # Special-case: single int column, use interval arithmetic.
    if len(types) == 1 and types[0][0] == 'int':
        intervals = [(None, None)]
        any_progress = False
        for i, row in enumerate(rows):
            node = row['pattern'][0]
            guard = row['guard']
            if contains_eqvar(node):
                continue
            lo, hi = None, None
            covers_all = False
            if node[0] == 'wild':
                covers_all = True
            elif node[0] == 'var':
                if guard is not None:
                    _, lo, hi = guard
                else:
                    covers_all = True
            elif node[0] == 'interval':
                lo, hi = node[1], node[2]
            elif node[0] == 'lit' and node[1] == 'int':
                lo = hi = node[2]
            else:
                covers_all = False
                lo = hi = None
                continue
            # reachability: does this row's coverage intersect current
            # residual?
            reach = False
            if covers_all:
                reach = not interval_is_empty(intervals)
            else:
                for (a, b) in intervals:
                    lo_ok = (lo is None) or (b is None) or (lo <= b)
                    hi_ok = (hi is None) or (a is None) or (hi >= a)
                    if lo_ok and hi_ok:
                        reach = True
                        break
            if not reach:
                unreachable[i] = True
                continue
            if covers_all:
                intervals = []
            else:
                intervals = interval_subtract(intervals, lo, hi)
        inexhaustive = not interval_is_empty(intervals)
        return inexhaustive, unreachable

    # Generic constructor-based engine.
    filtered_indices = [i for i, row in enumerate(rows)
                         if not any(contains_eqvar(n) for n in row['pattern'])]
    matrix = []
    prior_matrices = []
    for i, row in enumerate(rows):
        prior_matrices.append(list(matrix))
        has_eq = any(contains_eqvar(n) for n in row['pattern'])
        if has_eq:
            continue
        pat = row['pattern']
        is_full_wild = all(is_wild(p) for p in pat)
        if is_full_wild and row.get('guard') not in (None,):
            g = row.get('guard')
            if g is not None:
                pass
        if is_full_wild:
            u = useful(prior_matrices[i], pat, types)
            if not u:
                unreachable[i] = True
            matrix.append(pat)
        else:
            u = useful(prior_matrices[i], pat, types)
            if not u:
                unreachable[i] = True
            matrix.append(pat)

    inexhaustive = not matrix_exhaustive(matrix, types)
    return inexhaustive, unreachable


# ---------------------------------------------------------------------------
# Main driver
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        return
    path = sys.argv[1]
    try:
        with open(path) as f:
            src = f.read()
    except OSError:
        return

    types = {}
    lines = src.split('\n')
    i = 0
    decl_lines_consumed = set()

    # Parse `type X = ...` (single line) and `record X { ... }` (may span
    # lines) declarations, plus `module` line; everything else is left for
    # clause parsing.
    idx = 0
    n = len(lines)
    remaining_lines = []
    while idx < n:
        line = lines[idx]
        stripped = line.strip()
        if stripped.startswith('module '):
            idx += 1
            continue
        m = re.match(r'^type\s+(\w+)\s*=\s*(.+)$', stripped)
        if m:
            parse_type_decl(m.group(1), m.group(2), types)
            idx += 1
            continue
        m = re.match(r'^record\s+(\w+)\s*\{', stripped)
        if m:
            buf = stripped
            depth = stripped.count('{') - stripped.count('}')
            while depth > 0:
                idx += 1
                buf += '\n' + lines[idx]
                depth += lines[idx].count('{') - lines[idx].count('}')
            body_m = re.match(r'^record\s+(\w+)\s*\{(.*)\}\s*$', buf, re.S)
            if body_m:
                parse_record_decl(body_m.group(1), body_m.group(2), types)
            idx += 1
            continue
        remaining_lines.append(line)
        idx += 1

    rest_src = '\n'.join(remaining_lines)

    # Parse function signatures: `public RetType Name(Type1 p1, Type2 p2, ...)`
    sig_re = re.compile(r'^public\s+(\S+)\s+([A-Za-z_]\w*)\s*\(([^)]*)\)\s*$', re.M)
    functions = {}
    order = []
    for m in sig_re.finditer(rest_src):
        ret_ty_txt, fname, params_txt = m.group(1), m.group(2), m.group(3)
        ret_ty = resolve_type_name(ret_ty_txt, types)
        params = []
        for p in split_top_level(params_txt, ','):
            parts = p.strip().split()
            if len(parts) >= 2:
                pty_txt = ' '.join(parts[:-1])
                pname = parts[-1]
                params.append((pname, resolve_type_name(pty_txt, types)))
        functions[fname] = {'ret': ret_ty, 'params': params, 'clauses': []}
        order.append(fname)

    # Remove signature lines from body used for clause extraction.
    body_wo_sigs = sig_re.sub('', rest_src)

    stmts = extract_statements(body_wo_sigs)
    for stmt in stmts:
        parsed = parse_clause_stmt(stmt)
        if not parsed:
            continue
        name, args_text, guard_text, body_text = parsed
        if name not in functions:
            continue
        functions[name]['clauses'].append((args_text, guard_text, body_text))

    for fname in order:
        fn = functions[fname]
        params = fn['params']
        param_types = {pn: pt for pn, pt in params}
        ret_ty = fn['ret']
        clauses = fn['clauses']

        # ---- clause-head rebinding + exhaustiveness ----
        col_types = [pt for _, pt in params]
        rows = []
        for (args_text, guard_text, body_text) in clauses:
            arg_texts = split_top_level(args_text, ',') if args_text.strip() else []
            if len(arg_texts) != len(col_types):
                # best effort: pad/truncate
                while len(arg_texts) < len(col_types):
                    arg_texts.append('_')
                arg_texts = arg_texts[:len(col_types)]
            pat_nodes = [parse_pattern(t, col_types[i]) for i, t in enumerate(arg_texts)]
            # rebinding check: duplicate bare names within this single head
            names = []
            typed_names = []
            for i, node in enumerate(pat_nodes):
                collect_bound_names(node, names)
                collect_bound_names_typed(node, col_types[i], typed_names)
            seen = set()
            for nm in names:
                if nm in seen:
                    emit('rebinding')
                seen.add(nm)
            local_types = dict(typed_names)
            guard = parse_guard(guard_text)
            matched_nodes = pat_nodes
            if guard is not None:
                gvar, glo, ghi = guard
                matched_nodes = [apply_guard_to_pattern(n, gvar, glo, ghi) for n in pat_nodes]
            rows.append({'pattern': matched_nodes, 'guard': guard,
                         'body': body_text, 'names': set(names),
                         'local_types': local_types})

        if col_types:
            inexh, unreach = check_rows(rows, col_types)
            if inexh:
                emit('switch_inexhaustive')
            for u in unreach:
                if u:
                    emit('unreachable_arm')

        # ---- per-clause body analysis (return type + nested switch) ----
        for row in rows:
            body_text = row['body']
            scope = set(param_types.keys()) | row['names']
            local_var_types = dict(param_types)
            local_var_types.update(row['local_types'])
            analyze_body(body_text, ret_ty, local_var_types, scope, types)


def analyze_body(body_text, ret_ty, param_types, scope, types):
    sw = parse_switch_arms(body_text)
    if sw is None:
        kind_val = literal_kind_of_expr(body_text)
        if kind_val is not None:
            kind, value = kind_val
            if not type_matches_return(ret_ty, kind, value):
                emit('return_not_declared')
        return

    subject_text, arms = sw
    subj_ty, subj_name = resolve_subject_type(subject_text, param_types, types)

    col_types = [subj_ty]
    rows = []
    for (pat_text, guard_text, expr_text) in arms:
        node = parse_pattern(pat_text, subj_ty)
        names = []
        collect_bound_names(node, names)
        typed_names = []
        collect_bound_names_typed(node, subj_ty, typed_names)
        # rebinding: introduced name already bound in outer scope
        for nm in names:
            if nm in scope:
                emit('rebinding')
        guard = parse_guard(guard_text)
        if guard is not None:
            gvar = guard[0]
            if gvar in scope and gvar not in names:
                # guard references an outer name fine (not introduction)
                pass
        matched_node = node
        if guard is not None:
            gvar, glo, ghi = guard
            matched_node = apply_guard_to_pattern(node, gvar, glo, ghi)
        rows.append({'pattern': [matched_node], 'guard': guard, 'expr': expr_text,
                     'names': set(names), 'local_types': dict(typed_names)})

    inexh, unreach = check_rows(rows, col_types)
    if inexh:
        emit('switch_inexhaustive')
    for u in unreach:
        if u:
            emit('unreachable_arm')

    for row in rows:
        inner_scope = scope | row['names']
        inner_var_types = dict(param_types)
        inner_var_types.update(row['local_types'])
        analyze_body(row['expr'], ret_ty, inner_var_types, inner_scope, types)


if __name__ == '__main__':
    main()
    for t in sorted(TAGS):
        print(t)
