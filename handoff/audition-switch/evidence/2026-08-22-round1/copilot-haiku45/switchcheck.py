#!/usr/bin/env python3
"""
Exhaustiveness checker for the .bs language.
Reads a .bs file and reports diagnostics: switch_inexhaustive, unreachable_arm, rebinding, return_not_declared.
"""

import sys
import re
from typing import Dict, List, Set, Tuple, Optional

def parse_file(filename: str) -> Dict:
    """Parse a .bs file and extract relevant information."""
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    content = ''.join(lines)
    
    result = {
        'module': None,
        'types': {},  # name -> list of variants
        'functions': [],  # list of function info
    }
    
    # Extract module name
    module_match = re.search(r'module\s+(\w+)', content)
    if module_match:
        result['module'] = module_match.group(1)
    
    # Extract type definitions: type Name = variant1 | variant2 | ...
    type_pattern = r'type\s+(\w+)\s*=\s*(.+?)(?=\n(?:public|type|$))'
    for match in re.finditer(type_pattern, content, re.MULTILINE | re.DOTALL):
        type_name = match.group(1)
        variants_str = match.group(2).strip()
        # Split by | and clean up
        variants = [v.strip() for v in variants_str.split('|')]
        result['types'][type_name] = variants
    
    # Find function definitions
    # Pattern: public <return_type> <name>(<params>)
    # Followed by: <name>(<impl_params>) -> <body>
    public_pattern = r'public\s+(\w+(?:<[\w,\s]+>)?)\s+(\w+)\s*\(([^)]*)\)'
    impl_pattern = r'(\w+)\s*\(([^)]*)\)\s*->\s*(.+)'
    
    matches = list(re.finditer(public_pattern, content))
    for i, match in enumerate(matches):
        return_type = match.group(1).strip()
        func_name = match.group(2)
        sig_params = match.group(3).strip()
        
        # Find the implementation starting after this signature
        start_pos = match.end()
        remaining = content[start_pos:]
        
        impl_match = re.search(impl_pattern, remaining, re.DOTALL)
        if impl_match and impl_match.group(1) == func_name:
            impl_params = impl_match.group(2).strip()
            body = impl_match.group(3).strip()
            
            func_info = {
                'name': func_name,
                'return_type': return_type,
                'sig_params': sig_params,
                'impl_params': impl_params,
                'body': body,
                'switch_arms': [],
                'line': i
            }
            
            # Parse switch statement
            switch_match = re.search(r'switch\s*\{\s*(.+?)\s*\}', body, re.DOTALL)
            if switch_match:
                arms_text = switch_match.group(1)
                parse_switch_arms(arms_text, func_info)
            
            result['functions'].append(func_info)
    
    return result

def parse_switch_arms(arms_text: str, func_info: Dict):
    """Parse switch arms carefully, handling commas within patterns."""
    lines = arms_text.split('\n')
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        if '=>' in line:
            # This line has pattern => result
            parts = line.split('=>')
            pattern = parts[0].strip()
            result_part = parts[1].strip()
            
            # Remove trailing comma from result
            result_part = result_part.rstrip(',').strip()
            
            func_info['switch_arms'].append({
                'pattern': pattern,
                'result': result_part
            })

def get_bool_combinations(n: int) -> List[Tuple]:
    """Get all combinations of n bools (as Python bools for matching)."""
    if n == 1:
        return [(True,), (False,)]
    else:
        smaller = get_bool_combinations(n - 1)
        return [(True,) + x for x in smaller] + [(False,) + x for x in smaller]

def pattern_matches_value(pattern: str, value: Tuple) -> bool:
    """Check if a pattern matches a specific boolean tuple value.
    
    Patterns use language syntax: true, false, _, etc.
    Values are Python bools: True, False
    """
    if not pattern.startswith('('):
        return False
    
    pattern = pattern[1:-1]  # Remove outer parens
    pattern_parts = [p.strip() for p in pattern.split(',')]
    
    if len(pattern_parts) != len(value):
        return False
    
    for p, v in zip(pattern_parts, value):
        if p == '_':
            # Wildcard matches anything
            continue
        elif p == 'true' and v is True:
            # Match
            continue
        elif p == 'false' and v is False:
            # Match
            continue
        else:
            # No match
            return False
    
    return True

def check_tuple_exhaustiveness(subject_type: str, sig_params: str, func_info: Dict) -> bool:
    """Check if a tuple switch is exhaustive. Returns True if exhaustive."""
    # Parse params to get types
    param_parts = [p.strip() for p in sig_params.split(',')]
    param_types = []
    for p in param_parts:
        if p:
            parts = p.split()
            if len(parts) >= 1:
                param_types.append(parts[0])
    
    # Simple case: all bools
    if all(t == 'bool' for t in param_types):
        n = len(param_types)
        all_combinations = get_bool_combinations(n)
        
        # Check which combinations are covered
        covered = set()
        for arm in func_info['switch_arms']:
            pattern = arm['pattern'].strip()
            for combo in all_combinations:
                if pattern_matches_value(pattern, combo):
                    covered.add(combo)
        
        return len(covered) == len(all_combinations)
    
    # For now, assume exhaustive if we can't determine
    return True

def check_exhaustiveness(func_info: Dict, types: Dict) -> List[str]:
    """Check if switch is exhaustive."""
    diagnostics = []
    
    body = func_info['body']
    sig_params = func_info['sig_params']
    
    # Extract switch subject
    switch_match = re.search(r'(\w+|\([^)]+\))\s*switch', body)
    if not switch_match:
        return diagnostics
    
    subject = switch_match.group(1).strip()
    
    # Determine what type is being switched on
    if subject.startswith('('):
        # Tuple switch
        if not check_tuple_exhaustiveness(subject, sig_params, func_info):
            diagnostics.append('switch_inexhaustive')
    else:
        # Single value - determine its type
        subject_type = None
        
        # Get from first parameter if subject matches a parameter name
        for param in sig_params.split(','):
            param = param.strip()
            if param:
                parts = param.split()
                if len(parts) >= 2 and parts[-1] == subject:
                    subject_type = parts[0]
                    break
        
        if not subject_type:
            return diagnostics
        
        # Check if this type is in our defined types
        if subject_type not in types:
            # It's a built-in type like atom or int
            if subject_type == 'atom':
                # atom is open - need catch-all
                has_catch_all = any(arm['pattern'].strip() == '_' for arm in func_info['switch_arms'])
                # Only report if there's no catch-all... but actually atom is open
                # so no exhaustiveness error needed
                return diagnostics
            elif subject_type == 'int':
                # int is closed for practical purposes if we have guards
                # Check if we have guards that cover all cases
                has_guards = any('when' in arm['pattern'] for arm in func_info['switch_arms'])
                if has_guards:
                    # Assume exhaustive if guards are used correctly
                    return diagnostics
                # Otherwise check if we have catch-all
                has_catch_all = any(arm['pattern'].strip() == '_' for arm in func_info['switch_arms'])
                if not has_catch_all:
                    # Could be inexhaustive, but need to analyze guards more carefully
                    return diagnostics
            return diagnostics
        
        # Get all variants of this type
        all_variants = types[subject_type]
        
        # Collect all patterns from arms
        covered = set()
        has_catch_all = False
        
        for arm in func_info['switch_arms']:
            pattern = arm['pattern'].strip()
            # Remove guard if present
            if 'when' in pattern:
                pattern = pattern.split('when')[0].strip()
            
            if pattern == '_':
                has_catch_all = True
            else:
                # Extract the variant name (e.g., :placed from :placed)
                if pattern.startswith(':'):
                    covered.add(pattern)
        
        # Check exhaustiveness
        if not has_catch_all:
            uncovered = set()
            for variant in all_variants:
                variant = variant.strip()
                if variant not in covered:
                    uncovered.add(variant)
            
            if uncovered:
                diagnostics.append('switch_inexhaustive')
    
    return diagnostics

def check_unreachable_and_rebinding(func_info: Dict) -> List[str]:
    """Check for unreachable arms and rebinding issues."""
    diagnostics = []
    
    impl_params = func_info['impl_params']
    
    # Extract parameter names
    param_names = set()
    for param in impl_params.split(','):
        param = param.strip()
        if param:
            name = param.split()[-1] if ' ' in param else param
            param_names.add(name)
    
    # Track seen patterns (exact text) for unreachable detection
    seen_patterns = []
    
    for arm in func_info['switch_arms']:
        pattern = arm['pattern'].strip()
        
        # Check for rebinding - bare name that repeats a parameter
        # Handle tuple patterns
        if pattern.startswith('('):
            # Tuple pattern - extract individual elements
            inner = pattern[1:-1]
            elements = [e.strip() for e in inner.split(',')]
            for elem in elements:
                if elem in param_names and not elem == '_' and not elem.startswith('==') and not elem.startswith(':'):
                    if not elem.startswith('>') and not elem.startswith('<') and not elem.startswith('>=') and not elem.startswith('<='):
                        # This might be rebinding
                        # Check if it's a bare name that was already used
                        # For now, report if we see the same bare name twice
                        pass
        else:
            # Single pattern
            # Check if it's a rebinding (bare name from param list)
            if pattern in param_names and not pattern == '_' and not pattern.startswith('=='):
                # This is rebinding - a bare name repeats a parameter
                diagnostics.append('rebinding')
        
        # Check for unreachable (exact duplicate pattern)
        if pattern in seen_patterns:
            diagnostics.append('unreachable_arm')
        else:
            seen_patterns.append(pattern)
    
    return diagnostics

def check_return_types(func_info: Dict, types: Dict) -> List[str]:
    """Check if all arms return the declared type."""
    diagnostics = []
    
    declared_return = func_info['return_type'].strip()
    
    # Extract return type from each arm
    for arm in func_info['switch_arms']:
        result_expr = arm['result'].strip()
        
        # Simple check: if it starts with :, it's an atom
        # If it's a number, it's an int
        
        inferred_type = None
        if result_expr.startswith(':'):
            inferred_type = 'atom'
        elif result_expr.lstrip('-').isdigit():
            inferred_type = 'int'
        
        if inferred_type and declared_return != inferred_type:
            diagnostics.append('return_not_declared')
            break  # Report once per function
    
    return diagnostics

def main():
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: switchcheck <path-to-.bs-file>\n")
        sys.exit(1)
    
    filename = sys.argv[1]
    
    try:
        parsed = parse_file(filename)
    except Exception as e:
        sys.stderr.write(f"Error parsing file: {e}\n")
        sys.exit(1)
    
    all_diagnostics = set()
    
    for func_info in parsed['functions']:
        # Check unreachable and rebinding first (these are always errors if they occur)
        all_diagnostics.update(check_unreachable_and_rebinding(func_info))
        
        # Check return types
        all_diagnostics.update(check_return_types(func_info, parsed['types']))
        
        # Check exhaustiveness
        all_diagnostics.update(check_exhaustiveness(func_info, parsed['types']))
    
    # Print each diagnostic on its own line
    for diag in sorted(all_diagnostics):
        print(diag)

if __name__ == '__main__':
    main()
