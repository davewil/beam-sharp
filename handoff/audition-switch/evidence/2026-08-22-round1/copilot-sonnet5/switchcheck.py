#!/usr/bin/env python3
import sys, re, itertools

INF = float('inf')
NEGINF = float('-inf')

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

def find_matching_brace(text, open_idx):
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return i
    return -1

def top_level_split(text, sep_chars):
    """Split text on top-level commas (or other single-char separators),
    respecting (), [], {} nesting."""
    parts = []
    depth = 0
    cur = []
    for ch in text:
        if ch in '([{':
            depth += 1
            cur.append(ch)
        elif ch in ')]}':
            depth -= 1
            cur.append(ch)
        elif ch == ',' and depth == 0:
            parts.append(''.join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append(''.join(cur))
    return [p.strip() for p in parts if p.strip() != '']

def split_arrow(text):
    # split on the last top-level '=>' - but there should be exactly one
    depth = 0
    for i in range(len(text) - 1):
        ch = text[i]
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        elif depth == 0 and text[i:i+2] == '=>':
            return text[:i].strip(), text[i+2:].strip()
    return None, None

def split_when(pattern_text):
    # split on first top-level ' when '
    depth = 0
    i = 0
    n = len(pattern_text)
    while i < n:
        ch = pattern_text[i]
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        elif depth == 0 and pattern_text[i:i+6] == ' when ':
            return pattern_text[:i].strip(), pattern_text[i+6:].strip()
        i += 1
    return pattern_text.strip(), None

# ---------- interval engine ----------
# intervals represented as list of (lo, hi) inclusive, lo/hi may be NEGINF/INF

def interval_full():
    return [(NEGINF, INF)]

def interval_normalize(intervals):
    intervals = [iv for iv in intervals if iv[0] <= iv[1]]
    if not intervals:
        return []
    intervals = sorted(intervals)
    merged = [intervals[0]]
    for lo, hi in intervals[1:]:
        mlo, mhi = merged[-1]
        adjacent = (lo <= mhi + 1) if (mhi != INF and lo != NEGINF) else (lo <= mhi)
        if adjacent:
            merged[-1] = (mlo, max(mhi, hi))
        else:
            merged.append((lo, hi))
    return merged

def interval_intersect_one(a, b):
    lo = max(a[0], b[0])
    hi = min(a[1], b[1])
    if lo <= hi:
        return (lo, hi)
    return None

def interval_intersect(alist, blist):
    out = []
    for a in alist:
        for b in blist:
            r = interval_intersect_one(a, b)
            if r:
                out.append(r)
    return interval_normalize(out)

def interval_union(alist, blist):
    return interval_normalize(list(alist) + list(blist))

def interval_complement(alist):
    alist = interval_normalize(alist)
    out = []
    cur = NEGINF
    for lo, hi in alist:
        if cur < lo:
            out.append((cur, lo - 1 if lo != NEGINF else lo))
        if hi == INF:
            cur = INF
            break
        cur = hi + 1
    if cur < INF:
        out.append((cur, INF))
    return interval_normalize(out)

def interval_subtract(alist, blist):
    return interval_intersect(alist, interval_complement(blist))

def interval_nonempty(alist):
    return len(interval_normalize(alist)) > 0

def parse_int_condition(text, varname=None):
    """Parse a relational condition possibly with 'and'/'or', return list of intervals.
    varname if given is stripped from comparisons like 'n < 5'."""
    text = text.strip()
    # split on top-level ' or '
    or_parts = split_logical(text, ' or ')
    if len(or_parts) > 1:
        result = []
        for p in or_parts:
            result = interval_union(result, parse_int_condition(p, varname))
        return result
    and_parts = split_logical(text, ' and ')
    if len(and_parts) > 1:
        result = interval_full()
        for p in and_parts:
            result = interval_intersect(result, parse_int_condition(p, varname))
        return result
    return parse_atomic_condition(text, varname)

def split_logical(text, sep):
    depth = 0
    i = 0
    n = len(text)
    parts = []
    last = 0
    while i < n:
        ch = text[i]
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        elif depth == 0 and text[i:i+len(sep)] == sep:
            parts.append(text[last:i].strip())
            i += len(sep)
            last = i
            continue
        i += 1
    parts.append(text[last:].strip())
    return parts

def parse_atomic_condition(text, varname):
    text = text.strip()
    if varname:
        # remove leading varname if present, e.g. "n < 5" -> "< 5"
        m = re.match(r'^' + re.escape(varname) + r'\s*(.*)$', text)
        if m:
            text = m.group(1).strip()
    m = re.match(r'^(>=|<=|>|<|==)\s*(-?\d+)$', text)
    if not m:
        return None  # unparseable
    op, val = m.group(1), int(m.group(2))
    if op == '>=':
        return [(val, INF)]
    elif op == '<=':
        return [(NEGINF, val)]
    elif op == '>':
        return [(val + 1, INF)]
    elif op == '<':
        return [(NEGINF, val - 1)]
    elif op == '==':
        return [(val, val)]
    return None

# ---------- domain model ----------

class Domain:
    """A domain for one slot: kind in ('atom_closed','bool','atom_open','int','unknown')"""
    def __init__(self, kind, elements=None):
        self.kind = kind
        self.elements = elements  # for atom_closed/bool: set of literal strings

def resolve_type_domain(typename, type_decls):
    if typename == 'bool':
        return Domain('bool', {'true', 'false'})
    if typename == 'int':
        return Domain('int')
    if typename == 'atom':
        return Domain('atom_open')
    if typename in type_decls:
        kind, elems = type_decls[typename]
        if kind == 'atom_union':
            return Domain('atom_closed', set(elems))
    return Domain('unknown')

# ---------- pattern classification ----------

class Pat:
    def __init__(self, kind, value=None):
        self.kind = kind  # 'wildcard','name','literal_atom','literal_bool','literal_int',
                           # 'relational','eqref','unknown'
        self.value = value

def classify_pattern(text, domain):
    text = text.strip()
    if text == '_':
        return Pat('wildcard')
    if text.startswith('=='):
        name = text[2:].strip()
        return Pat('eqref', name)
    if text.startswith(':'):
        return Pat('literal_atom', text)
    if text in ('true', 'false'):
        return Pat('literal_bool', text)
    if re.match(r'^-?\d+$', text):
        return Pat('literal_int', int(text))
    # relational directly on slot, e.g. ">= 4 and <= 7" or ">= 5"
    if re.match(r'^(>=|<=|>|<)', text):
        intervals = parse_int_condition(text, None)
        if intervals is not None:
            return Pat('relational', intervals)
        return Pat('unknown', text)
    if re.match(r'^[A-Za-z_]\w*$', text):
        return Pat('name', text)
    return Pat('unknown', text)

# ---------- arm coverage over a tuple of slot domains ----------

def full_domain_elements(domain):
    if domain.kind in ('atom_closed', 'bool'):
        return set(domain.elements)
    return None  # infinite/unknown

def pattern_reach_and_exhaust_sets(pat, domain, guard_intervals=None):
    """Return (reach_repr, exhaust_repr) for enum-style domains (atom_closed/bool).
    reach_repr/exhaust_repr: 'ALL' or a concrete set."""
    full = full_domain_elements(domain)
    if pat.kind == 'wildcard':
        return ('ALL', 'ALL')
    if pat.kind == 'literal_atom' or pat.kind == 'literal_bool':
        val = pat.value
        return ({val}, {val})
    if pat.kind == 'name':
        return ('ALL', set())  # matches all at runtime, credits nothing
    if pat.kind == 'eqref':
        return ('ALL', set())  # unknown value; treat as no credit; conservative for reach: could match some value but we don't know which -> treat as ALL for reach (non-guessing towards false reachable flag: safer to not mark unreachable)
    return ('ALL', set())  # unknown pattern: be permissive, don't cause false diagnostics

def universe_for_domains(domains):
    lists = []
    for d in domains:
        elems = full_domain_elements(d)
        if elems is None:
            return None
        lists.append(sorted(elems))
    return list(itertools.product(*lists))

# ---------- main analysis ----------

def analyze(text):
    tags = set()

    type_decls = {}
    for m in re.finditer(r'^\s*type\s+(\w+)\s*=\s*(.+)$', text, re.MULTILINE):
        name, rhs = m.group(1), m.group(2).strip()
        atoms = re.findall(r':\w+', rhs)
        parts = [p.strip() for p in rhs.split('|')]
        if atoms and all(p.startswith(':') for p in parts):
            type_decls[name] = ('atom_union', atoms)

    record_decls = {}
    for m in re.finditer(r'^\s*record\s+(\w+)\s*\{([^}]*)\}', text, re.MULTILINE):
        name, body = m.group(1), m.group(2)
        fields = {}
        for f in body.split(','):
            f = f.strip()
            if not f:
                continue
            fm = re.match(r'^(\w+)\s*:\s*(\w+)$', f)
            if fm:
                fields[fm.group(1)] = fm.group(2)
        record_decls[name] = fields

    # find public function signatures
    sig_pattern = re.compile(r'^\s*public\s+(\S+)\s+(\w+)\s*\(([^)]*)\)\s*$', re.MULTILINE)
    sigs = list(sig_pattern.finditer(text))

    for idx, sm in enumerate(sigs):
        ret_type, func_name, params_str = sm.group(1), sm.group(2), sm.group(3)
        start = sm.end()
        end = sigs[idx + 1].start() if idx + 1 < len(sigs) else len(text)
        block = text[start:end]

        params = []
        if params_str.strip():
            for p in params_str.split(','):
                p = p.strip()
                pm = re.match(r'^(\S+)\s+(\w+)$', p)
                if pm:
                    params.append((pm.group(1), pm.group(2)))
        param_types = {name: typ for typ, name in params}

        analyze_function(func_name, ret_type, params, param_types, block,
                          type_decls, record_decls, tags)

    return tags

def get_slot_domain(expr, param_types, type_decls, record_decls):
    expr = expr.strip()
    if expr in param_types:
        return resolve_type_domain(param_types[expr], type_decls)
    m = re.match(r'^(\w+)\.(\w+)$', expr)
    if m:
        base, field = m.group(1), m.group(2)
        if base in param_types:
            rec_type = param_types[base]
            fields = record_decls.get(rec_type, {})
            if field in fields:
                return resolve_type_domain(fields[field], type_decls)
    return Domain('unknown')

def analyze_function(func_name, ret_type, params, param_types, block,
                      type_decls, record_decls, tags):
    ret_category = category_for_type(ret_type, type_decls)

    # clause head may rebind parameter names positionally, e.g.
    # Route(o, p) -> (o, p) switch { ... }
    head_m = re.match(
        r'\s*' + re.escape(func_name) + r'\s*\(([^)]*)\)\s*->', block)
    if head_m:
        local_names = top_level_split(head_m.group(1), [','])
        if len(local_names) == len(params):
            param_types = dict(param_types)
            for (typ, _), local in zip(params, local_names):
                local = local.strip()
                if re.match(r'^[A-Za-z_]\w*$', local):
                    param_types[local] = typ

    swm = re.search(r'->\s*(.+?)\s*switch\s*\{', block, re.DOTALL)
    if swm:
        subject_text = swm.group(1).strip()
        open_brace = block.index('{', swm.start())
        close_brace = find_matching_brace(block, open_brace)
        if close_brace == -1:
            return
        arms_text = block[open_brace + 1:close_brace]
        arm_strs = top_level_split(arms_text, [','])

        # determine slot domains
        tup_m = re.match(r'^\(([^)]*)\)$', subject_text)
        if tup_m:
            idents = top_level_split(tup_m.group(1), [','])
            domains = [get_slot_domain(i, param_types, type_decls, record_decls) for i in idents]
        else:
            domains = [get_slot_domain(subject_text, param_types, type_decls, record_decls)]

        arms = []
        for a in arm_strs:
            pat_part, body_part = split_arrow(a)
            if pat_part is None:
                continue
            pat_part, guard = split_when(pat_part)
            arms.append((pat_part, guard, body_part))

        check_exhaustiveness_and_reachability(arms, domains, tags)
        check_rebinding_in_arms(arms, domains, tags)
        check_return_types(arms, ret_category, type_decls, tags)
        return

    # multi-clause head style (no switch block): gather clauses for this function
    clause_re = re.compile(
        r'^\s*' + re.escape(func_name) + r'\s*\(([^)]*)\)\s*(?:when\s+(.+?))?\s*->\s*(.+)$',
        re.MULTILINE)
    arms = []
    for cm in clause_re.finditer(block):
        args_str, guard, body = cm.group(1), cm.group(2), cm.group(3)
        arms.append((args_str.strip(), guard.strip() if guard else None, body.strip()))
    if not arms:
        return
    domains = [resolve_type_domain(t, type_decls) for t, n in params]
    # arm pattern text is itself the whole arg list (comma separated slots), wrap logic:
    wrapped_arms = []
    for pat_part, guard, body in arms:
        wrapped_arms.append((pat_part, guard, body))
    check_exhaustiveness_and_reachability(wrapped_arms, domains, tags, args_are_raw=True)
    check_rebinding_in_arms(wrapped_arms, domains, tags, args_are_raw=True)
    check_return_types(wrapped_arms, ret_category, type_decls, tags)

def category_for_type(typename, type_decls):
    if typename == 'int':
        return 'int'
    if typename == 'bool':
        return 'bool'
    if typename == 'atom':
        return 'atom'
    if typename in type_decls:
        return 'atom'
    return None

def literal_category(text):
    text = text.strip()
    if re.match(r'^-?\d+$', text):
        return 'int'
    if text in ('true', 'false'):
        return 'bool'
    if text.startswith(':') and re.match(r'^:\w+$', text):
        return 'atom'
    return None

def check_return_types(arms, ret_category, type_decls, tags):
    if ret_category is None:
        return
    for pat_part, guard, body in arms:
        cat = literal_category(body)
        if cat is not None and cat != ret_category:
            tags.add('return_not_declared')

def get_slot_patterns(pat_part, nslots, args_are_raw=False):
    if nslots == 1 and not args_are_raw:
        # single subject; pattern may be wrapped or bare
        m = re.match(r'^\(([^)]*)\)$', pat_part)
        if m:
            inner = top_level_split(m.group(1), [','])
            if len(inner) == 1:
                return inner
        return [pat_part]
    else:
        inner_text = pat_part
        m = re.match(r'^\(([^)]*)\)$', pat_part)
        if m:
            inner_text = m.group(1)
        parts = top_level_split(inner_text, [','])
        if len(parts) != nslots:
            return None
        return parts

def check_rebinding_in_arms(arms, domains, tags, args_are_raw=False):
    nslots = len(domains)
    for pat_part, guard, body in arms:
        slots = get_slot_patterns(pat_part, nslots, args_are_raw)
        if not slots:
            continue
        seen_names = set()
        for s in slots:
            p = classify_pattern(s, Domain('unknown'))
            if p.kind == 'name':
                if p.value in seen_names:
                    tags.add('rebinding')
                seen_names.add(p.value)

def check_exhaustiveness_and_reachability(arms, domains, tags, args_are_raw=False):
    nslots = len(domains)
    kinds = [d.kind for d in domains]

    if any(k == 'unknown' for k in kinds):
        return  # can't reason safely; avoid guessing

    if all(k in ('atom_closed', 'bool') for k in kinds):
        universe = universe_for_domains(domains)
        if universe is None or len(universe) > 4096:
            return
        universe_set = set(universe)
        covered_reach = set()
        covered_exhaust = set()
        for pat_part, guard, body in arms:
            slots = get_slot_patterns(pat_part, nslots, args_are_raw)
            if slots is None:
                continue
            reach_sets = []
            exhaust_sets = []
            for s, dom in zip(slots, domains):
                p = classify_pattern(s, dom)
                r, e = pattern_reach_and_exhaust_sets(p, dom)
                reach_sets.append(r)
                exhaust_sets.append(e)

            def matches(combo, sets):
                for val, s in zip(combo, sets):
                    if s == 'ALL':
                        continue
                    if val not in s:
                        return False
                return True

            arm_reach_combos = {c for c in universe if matches(c, reach_sets)}
            new_reach = arm_reach_combos - covered_reach
            if not new_reach:
                tags.add('unreachable_arm')
            covered_reach |= arm_reach_combos
            arm_exhaust_combos = {c for c in universe if matches(c, exhaust_sets)}
            covered_exhaust |= arm_exhaust_combos

        if covered_exhaust != universe_set:
            tags.add('switch_inexhaustive')
        return

    if nslots == 1 and kinds[0] == 'int':
        domain = domains[0]
        reach_residual = interval_full()
        exhaust_residual = interval_full()
        for pat_part, guard, body in arms:
            slots = get_slot_patterns(pat_part, nslots, args_are_raw)
            if slots is None:
                continue
            s = slots[0]
            p = classify_pattern(s, domain)
            reach_cov = None
            exhaust_cov = None
            if p.kind == 'wildcard':
                reach_cov = interval_full()
                exhaust_cov = interval_full()
            elif p.kind == 'literal_int':
                reach_cov = [(p.value, p.value)]
                exhaust_cov = reach_cov
            elif p.kind == 'relational':
                reach_cov = p.value
                exhaust_cov = p.value
            elif p.kind == 'name':
                if guard:
                    gi = parse_int_condition(guard, p.value)
                    gi = gi if gi is not None else interval_full()
                    reach_cov = gi
                    exhaust_cov = gi
                else:
                    reach_cov = interval_full()
                    exhaust_cov = []
            else:
                reach_cov = interval_full()
                exhaust_cov = []

            overlap = interval_intersect(reach_residual, reach_cov)
            if not interval_nonempty(overlap):
                tags.add('unreachable_arm')
            reach_residual = interval_subtract(reach_residual, reach_cov)
            exhaust_residual = interval_subtract(exhaust_residual, exhaust_cov)

        if interval_nonempty(exhaust_residual):
            tags.add('switch_inexhaustive')
        return

    if nslots == 1 and kinds[0] == 'atom_open':
        seen_literals = set()
        catchall_hit = False
        has_catchall = False
        for pat_part, guard, body in arms:
            slots = get_slot_patterns(pat_part, nslots, args_are_raw)
            if slots is None:
                continue
            s = slots[0]
            p = classify_pattern(s, domains[0])
            if p.kind == 'literal_atom':
                if catchall_hit or p.value in seen_literals:
                    tags.add('unreachable_arm')
                seen_literals.add(p.value)
            elif p.kind == 'wildcard' or p.kind == 'name':
                if catchall_hit:
                    tags.add('unreachable_arm')
                catchall_hit = True
                if p.kind == 'wildcard':
                    has_catchall = True
            else:
                pass
        if not has_catchall:
            tags.add('switch_inexhaustive')
        return

    # mixed / unsupported shape: don't guess
    return

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    path = sys.argv[1]
    text = read_file(path)
    tags = analyze(text)
    for t in sorted(tags):
        print(t)

if __name__ == '__main__':
    main()
