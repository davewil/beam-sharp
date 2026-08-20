#!/usr/bin/env python3
import sys
import re
import itertools

def main():
    if len(sys.argv) < 2:
        return

    with open(sys.argv[1], 'r') as f:
        content = f.read()

    tags = set()

    # Parse custom types
    types = {}
    for match in re.finditer(r'type\s+(\w+)\s*=\s*(.+)', content):
        name = match.group(1)
        variants = [v.strip() for v in match.group(2).split('|')]
        types[name] = variants
    
    types['bool'] = ['true', 'false']

    # Parse signature
    sig_match = re.search(r'public\s+(\w+)\s+\w+\((.*?)\)', content)
    if not sig_match:
        return
    ret_type = sig_match.group(1)
    args_str = sig_match.group(2)
    args = []
    for arg in args_str.split(','):
        parts = arg.strip().split()
        if len(parts) == 2:
            args.append((parts[0], parts[1]))

    arg_names = {name for t, name in args}

    # Parse switch body
    switch_match = re.search(r'switch\s*\{([^}]*)\}', content)
    if not switch_match:
        return
    switch_body = switch_match.group(1)

    arms = []
    for line in switch_body.split('\n'):
        line = line.strip()
        if not line:
            continue
        if '=>' not in line:
            continue
        pat, res = line.split('=>')
        arms.append((pat.strip(), res.strip().rstrip(',')))

    # Check for return_not_declared
    for pat, res in arms:
        if ret_type == 'int' and res.startswith(':'):
            tags.add('return_not_declared')

    # Check for rebinding
    has_rebinding = False
    for pat, res in arms:
        first_token_match = re.match(r'^([a-zA-Z_]\w*)', pat)
        if first_token_match:
            first_token = first_token_match.group(1)
            if first_token in arg_names and first_token != '_':
                tags.add('rebinding')
                has_rebinding = True

    # Check for unreachable_arm and coverage
    is_tuple = len(args) > 1
    
    if is_tuple:
        universe_axes = [types.get(t, []) for t, name in args]
        universe = list(itertools.product(*universe_axes))
    else:
        subject_type = args[0][0]
        universe = types.get(subject_type, "open")

    covered_elements = set()
    catch_all_seen = False

    for pat, res in arms:
        first_token_match = re.match(r'^([a-zA-Z_]\w*)', pat)
        credits_nothing = False
        if first_token_match:
            first_token = first_token_match.group(1)
            if first_token in arg_names and first_token != '_':
                credits_nothing = True

        if pat == '_':
            if catch_all_seen:
                tags.add('unreachable_arm')
            catch_all_seen = True
            continue

        if is_tuple:
            pat_inner = pat.strip('()')
            pat_parts = [p.strip() for p in pat_inner.split(',')]
            matched_any = False
            for elem in universe:
                match = True
                for p, e in zip(pat_parts, elem):
                    if p != '_' and p != e:
                        match = False
                        break
                if match:
                    if elem not in covered_elements:
                        matched_any = True
                        if not credits_nothing:
                            covered_elements.add(elem)
            if not matched_any and not credits_nothing:
                tags.add('unreachable_arm')
        else:
            if pat in covered_elements or catch_all_seen:
                tags.add('unreachable_arm')
            else:
                if not credits_nothing:
                    covered_elements.add(pat)

    # Check for switch_inexhaustive
    # According to our exploration, if there is a rebinding error,
    # the compiler ONLY outputs 'rebinding' and not 'switch_inexhaustive' for that case.
    # We mirror that behavior to exactly match expected tags.
    if not has_rebinding:
        if not catch_all_seen:
            if universe == "open":
                tags.add('switch_inexhaustive')
            else:
                for elem in universe:
                    if elem not in covered_elements:
                        tags.add('switch_inexhaustive')
                        break

    for t in sorted(list(tags)):
        print(t)

if __name__ == '__main__':
    main()
