#!/usr/bin/env python3
"""
switchcheck: exhaustiveness and pattern checker for the B# language
"""
import sys
import re
from typing import Dict, List, Set, Tuple, Optional, Union
from dataclasses import dataclass


class IntInterval:
    """Represents a set of integer intervals."""
    def __init__(self, intervals=None):
        # intervals is a list of (min, max) tuples (inclusive)
        # None for min/max means unbounded
        if intervals is None:
            self.intervals = []
        else:
            self.intervals = intervals
    
    @staticmethod
    def from_value(value):
        """Create an interval representing a single integer."""
        return IntInterval([(value, value)])
    
    @staticmethod
    def from_relational(op, bound):
        """Create an interval from a relational pattern."""
        if op == '>=':
            return IntInterval([(bound, None)])
        elif op == '<=':
            return IntInterval([(None, bound)])
        elif op == '>':
            return IntInterval([(bound + 1, None)])
        elif op == '<':
            return IntInterval([(None, bound - 1)])
        return IntInterval()
    
    @staticmethod
    def all_integers():
        """Interval representing all integers."""
        return IntInterval([(None, None)])
    
    def union(self, other):
        """Return the union of two interval sets."""
        combined = sorted(self.intervals + other.intervals)
        merged = []
        for start, end in combined:
            if merged and self._can_merge(merged[-1], (start, end)):
                prev_start, prev_end = merged[-1]
                # Merge
                new_start = prev_start if prev_start is None else (min(prev_start, start) if start is not None else None)
                new_end = prev_end if prev_end is None else (max(prev_end, end) if end is not None else None)
                merged[-1] = (new_start, new_end)
            else:
                merged.append((start, end))
        return IntInterval(merged)
    
    @staticmethod
    def _can_merge(interval1, interval2):
        """Check if two intervals can be merged."""
        start1, end1 = interval1
        start2, end2 = interval2
        
        # Handle unbounded intervals
        if end1 is None or start2 is None:
            return True  # At least one is unbounded, assume they connect
        
        # Check if adjacent or overlapping
        return start2 <= end1 + 1
    
    def intersect(self, other):
        """Return the intersection of two interval sets."""
        if not self.intervals or not other.intervals:
            return IntInterval()
        
        result = []
        for start1, end1 in self.intervals:
            for start2, end2 in other.intervals:
                # Compute intersection
                inter_start = max(start1 if start1 is not None else float('-inf'),
                                start2 if start2 is not None else float('-inf'))
                inter_end = min(end1 if end1 is not None else float('inf'),
                               end2 if end2 is not None else float('inf'))
                
                if inter_start <= inter_end:
                    # Convert back to None for unbounded
                    inter_start = None if inter_start == float('-inf') else int(inter_start)
                    inter_end = None if inter_end == float('inf') else int(inter_end)
                    result.append((inter_start, inter_end))
        
        return IntInterval(result)
    
    def complement(self):
        """Return the complement of this interval set."""
        if not self.intervals:
            return IntInterval.all_integers()
        
        result = []
        
        # Add interval before the first interval
        start1, end1 = self.intervals[0]
        if start1 is None:
            # First interval goes to -infinity
            pass
        else:
            result.append((None, start1 - 1))
        
        # Add intervals between consecutive intervals
        for i in range(len(self.intervals) - 1):
            _, end_curr = self.intervals[i]
            start_next, _ = self.intervals[i + 1]
            if end_curr is not None and start_next is not None:
                result.append((end_curr + 1, start_next - 1))
        
        # Add interval after the last interval
        _, end_last = self.intervals[-1]
        if end_last is None:
            # Last interval goes to +infinity
            pass
        else:
            result.append((end_last + 1, None))
        
        return IntInterval(result)
    
    def is_empty(self):
        """Check if the interval set is empty."""
        return len(self.intervals) == 0
    
    def is_all_integers(self):
        """Check if the interval covers all integers."""
        return len(self.intervals) == 1 and self.intervals[0] == (None, None)
    
    def __repr__(self):
        return f"IntInterval({self.intervals})"


# Built-in types with known variants
BUILTIN_TYPES = {
    'bool': ['true', 'false'],
}


@dataclass
class TypeDef:
    name: str
    variants: List[str]  # For union types like :a | :b | :c


def parse_file(filename: str) -> Dict:
    """Parse a .bs file and extract relevant information."""
    with open(filename, 'r') as f:
        content = f.read()
    
    result = {
        'module': None,
        'types': {},
        'functions': [],
    }
    
    lines = content.split('\n')
    
    # Parse module name
    for line in lines:
        match = re.match(r'module\s+(\w+)', line)
        if match:
            result['module'] = match.group(1)
            break
    
    # Parse type definitions
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        match = re.match(r'type\s+(\w+)\s*=\s*(.+)', line)
        if match:
            type_name = match.group(1)
            type_def = match.group(2).strip()
            # Parse union type: :a | :b | :c
            variants = [v.strip() for v in re.split(r'\|', type_def)]
            result['types'][type_name] = TypeDef(type_name, variants)
        i += 1
    
    # Parse function signature and switch
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Match function signature: public <return-type> <name>(<params>)
        sig_match = re.match(r'public\s+(\S+)\s+(\w+)\s*\((.*?)\)', line)
        if sig_match:
            return_type = sig_match.group(1)
            func_name = sig_match.group(2)
            params_str = sig_match.group(3)
            
            # Parse parameters
            params = []
            for param in params_str.split(','):
                param = param.strip()
                if param:
                    parts = param.split()
                    if len(parts) >= 2:
                        param_type = parts[0]
                        param_name = parts[1]
                        params.append({'name': param_name, 'type': param_type})
                    else:
                        params.append({'name': param, 'type': None})
            
            # Find the switch statement
            i += 1
            while i < len(lines):
                match_line = lines[i].strip()
                
                # Match clause head: FuncName(pattern) -> subject switch { ... }
                clause_match = re.match(r'(\w+)\s*\((.*?)\)\s*->\s*(.*?)\s+switch\s*\{', match_line)
                if clause_match:
                    subject_expr = clause_match.group(3).strip()
                    
                    # Parse switch arms
                    arms = []
                    i += 1
                    while i < len(lines):
                        arm_line = lines[i].strip()
                        if arm_line == '}':
                            break
                        if arm_line and not arm_line.startswith('//'):
                            # Match arm: pattern => result
                            arm_match = re.match(r'([^=]+?)\s*=>\s*(.+)', arm_line)
                            if arm_match:
                                pattern = arm_match.group(1).strip()
                                result_expr = arm_match.group(2).strip().rstrip(',')
                                arms.append({
                                    'pattern': pattern,
                                    'result': result_expr
                                })
                        i += 1
                    
                    func_info = {
                        'name': func_name,
                        'return_type': return_type,
                        'params': params,
                        'subject': subject_expr,
                        'arms': arms
                    }
                    result['functions'].append(func_info)
                    break
                
                i += 1
        
        i += 1
    
    return result


def get_type_of_param(parsed: Dict, param_name: str) -> Optional[str]:
    """Get the declared type of a parameter."""
    if not parsed['functions']:
        return None
    
    func = parsed['functions'][0]
    for param in func['params']:
        if param['name'] == param_name:
            return param['type']
    return None


def is_closed_type(parsed: Dict, type_name: Optional[str]) -> bool:
    """Check if a type is closed (has finite enumerable values)."""
    if type_name is None:
        return False
    
    # Built-in closed types
    if type_name in BUILTIN_TYPES:
        return True
    
    # User-defined types
    if type_name in parsed['types']:
        return True
    
    return False


def split_pattern_elements(s: str) -> List[str]:
    """Split tuple pattern elements, handling nested tuples."""
    elements = []
    current = []
    depth = 0
    
    for char in s:
        if char == '(':
            depth += 1
            current.append(char)
        elif char == ')':
            depth -= 1
            current.append(char)
        elif char == ',' and depth == 0:
            elements.append(''.join(current).strip())
            current = []
        else:
            current.append(char)
    
    if current:
        elements.append(''.join(current).strip())
    
    return elements


def parse_pattern(pattern: str) -> Union[str, Tuple, List]:
    """
    Parse a pattern and return its normalized form.
    Returns:
    - '_' for wildcard
    - ('tuple', [...patterns...]) for tuple patterns
    - 'name' for variables
    - ':atom' for atom literals
    - number for number literals
    - 'true' or 'false' for bool literals
    - ('guarded', pattern, guard_str) for guarded patterns
    - ('==', name) for equality patterns
    """
    pattern = pattern.strip()
    
    if pattern == '_':
        return '_'
    
    if pattern.startswith('(') and pattern.endswith(')'):
        # Tuple pattern
        inner = pattern[1:-1]
        elements = split_pattern_elements(inner)
        return ('tuple', [parse_pattern(e) for e in elements])
    
    # Check for guard
    if ' when ' in pattern:
        pattern_part = pattern.split(' when ')[0].strip()
        guard_part = pattern.split(' when ')[1].strip()
        return ('guarded', parse_pattern(pattern_part), guard_part)
    
    # Check for relational pattern (>= 5, < 10, etc.)
    if re.match(r'^(>=|<=|>|<)\s*(-?\d+)', pattern):
        op = re.match(r'^(>=|<=|>|<)\s*(-?\d+)', pattern).group(1)
        value = int(re.match(r'^(>=|<=|>|<)\s*(-?\d+)', pattern).group(2))
        return ('relational', op, value)
    
    # Check for equality pattern (== name)
    if pattern.startswith('=='):
        name = pattern[2:].strip()
        return ('==', name)
    
    # Check for atom literal
    if pattern.startswith(':'):
        return pattern
    
    # Check for bool literals
    if pattern == 'true' or pattern == 'false':
        return pattern
    
    # Check for number literal
    if re.match(r'^-?\d+$', pattern):
        return int(pattern)
    
    # Variable/binding
    return pattern


def pattern_covers(pattern: Union[str, Tuple, List], value: Union[str, Tuple, List, int]) -> bool:
    """
    Check if a pattern covers a particular value for COVERAGE analysis.
    Returns True if the pattern definitely covers the value.
    Note: == patterns return False because matched names don't credit to the certain set.
    """
    if pattern == '_':
        return True
    
    if isinstance(pattern, str):
        # Check for literals first
        if pattern.startswith(':'):
            # Atom literal - exact match only
            return pattern == value
        elif pattern == 'true' or pattern == 'false':
            # Bool literal - exact match only
            return pattern == value
        else:
            # Variable matches any value (binding)
            return True
    
    if isinstance(pattern, int):
        # Number literal - exact match
        return pattern == value
    
    if isinstance(pattern, tuple):
        if pattern[0] == 'tuple':
            # Tuple pattern
            if not isinstance(value, tuple):
                return False
            patterns = pattern[1]
            if len(patterns) != len(value):
                return False
            return all(pattern_covers(p, v) for p, v in zip(patterns, value))
        
        elif pattern[0] == 'guarded':
            # Guarded pattern - we can't fully evaluate guards,
            # but we can check the base pattern
            return pattern_covers(pattern[1], value)
        
        elif pattern[0] == 'relational':
            # Relational pattern - check the constraint
            op, bound = pattern[1], pattern[2]
            if not isinstance(value, int):
                return False
            if op == '>=':
                return value >= bound
            elif op == '<=':
                return value <= bound
            elif op == '>':
                return value > bound
            elif op == '<':
                return value < bound
        
        elif pattern[0] == '==':
            # Equality pattern - matched names don't credit to the certain set
            # because their value is unknown at compile time
            return False
    
    return False


def all_values_for_type(parsed: Dict, type_name: str) -> Optional[List]:
    """Get all values for a closed type."""
    # Check built-in types first
    if type_name in BUILTIN_TYPES:
        return BUILTIN_TYPES[type_name]
    
    # Check user-defined types
    if type_name not in parsed['types']:
        return None
    
    type_def = parsed['types'][type_name]
    return type_def.variants


def generate_all_tuples(type_names: List[str], parsed: Dict) -> Optional[List[Tuple]]:
    """Generate all value tuples for a list of types."""
    all_variants = []
    for type_name in type_names:
        variants = all_values_for_type(parsed, type_name)
        if variants is None:
            return None  # Open type
        all_variants.append(variants)
    
    # Cartesian product
    result = []
    
    def product(lists):
        if not lists:
            return [[]]
        first = lists[0]
        rest = product(lists[1:])
        return [[x] + r for x in first for r in rest]
    
    for combination in product(all_variants):
        result.append(tuple(combination))
    
    return result


def check_exhaustiveness(parsed: Dict) -> List[str]:
    """Check if the switch is exhaustive."""
    errors = []
    
    if not parsed['functions']:
        return errors
    
    func = parsed['functions'][0]
    subject = func['subject'].strip()
    arms = func['arms']
    
    # Parse the subject to determine what types are involved
    is_tuple = subject.startswith('(') and subject.endswith(')')
    subject_types = []
    
    if is_tuple:
        # Tuple subject - get types by position in the function signature
        inner = subject[1:-1]
        elements = split_pattern_elements(inner)
        # Elements could be parameter names or expressions
        # If they're simple identifiers, match by position in function params
        for idx, elem in enumerate(elements):
            elem = elem.strip()
            # Try to match by position in the function parameters
            if idx < len(func['params']):
                param_type = func['params'][idx]['type']
            else:
                param_type = None
            subject_types.append(param_type)
    else:
        # Single subject - could be a parameter name or expression
        # Try to match by position
        if len(func['params']) > 0:
            param_type = func['params'][0]['type']
        else:
            param_type = None
        subject_types.append(param_type)
    
    # Special handling for int types with relational patterns
    if len(subject_types) == 1 and subject_types[0] == 'int':
        # For int, use interval arithmetic
        return check_exhaustiveness_int(parsed, arms)
    
    # Check if all subject types are closed (have finite enumerable values)
    all_closed = True
    for t in subject_types:
        if not is_closed_type(parsed, t):
            all_closed = False
            break
    
    if not all_closed:
        # If any type is open (like bare `atom` or `int`), we can't check exhaustiveness
        # But catch-all is allowed for open types
        return errors
    
    # Generate all possible values
    if is_tuple:
        all_cases = generate_all_tuples(subject_types, parsed)
        if all_cases is None:
            return errors
    else:
        # Single type - don't wrap in tuple
        all_values = all_values_for_type(parsed, subject_types[0])
        if all_values is None:
            return errors
        all_cases = all_values
    
    # Check coverage
    covered = [False] * len(all_cases)
    has_catchall = False
    
    for arm in arms:
        pattern_str = arm['pattern'].strip()
        
        # Check for catch-all
        if pattern_str == '_':
            has_catchall = True
            break
        
        parsed_pattern = parse_pattern(pattern_str)
        
        # Check which cases this pattern covers
        for i, case_value in enumerate(all_cases):
            if pattern_covers(parsed_pattern, case_value):
                covered[i] = True
    
    # If there's no catch-all and some cases aren't covered, it's inexhaustive
    if not has_catchall and not all(covered):
        errors.append('switch_inexhaustive')
    
    return errors


def check_exhaustiveness_int(parsed: Dict, arms: List) -> List[str]:
    """Check exhaustiveness for int type using interval arithmetic."""
    errors = []
    
    # Track which integer intervals are covered
    covered = IntInterval()
    
    for arm in arms:
        pattern_str = arm['pattern'].strip()
        
        # Check for catch-all
        if pattern_str == '_':
            # Catch-all covers all integers
            covered = IntInterval.all_integers()
            break
        
        parsed_pattern = parse_pattern(pattern_str)
        
        # Determine what this pattern covers
        arm_coverage = IntInterval()
        
        if isinstance(parsed_pattern, int):
            # Literal integer
            arm_coverage = IntInterval.from_value(parsed_pattern)
        elif isinstance(parsed_pattern, tuple):
            if parsed_pattern[0] == 'relational':
                op, bound = parsed_pattern[1], parsed_pattern[2]
                arm_coverage = IntInterval.from_relational(op, bound)
            elif parsed_pattern[0] == 'guarded':
                # For guarded patterns with a variable, try to extract guard intervals
                base_pattern = parsed_pattern[1]
                guard_str = parsed_pattern[2]
                
                guard_intervals = extract_guard_intervals(guard_str)
                if guard_intervals is not None:
                    arm_coverage = guard_intervals
                # Otherwise, a bare variable with a guard we can't parse covers everything
                elif isinstance(base_pattern, str) and base_pattern not in ('_',) and not base_pattern.startswith(':'):
                    arm_coverage = IntInterval.all_integers()
            elif parsed_pattern[0] == '==':
                # Matched names don't credit to coverage
                arm_coverage = IntInterval()
        elif isinstance(parsed_pattern, str):
            if parsed_pattern == '_':
                arm_coverage = IntInterval.all_integers()
            elif not parsed_pattern.startswith(':'):
                # Bare variable matches all integers
                arm_coverage = IntInterval.all_integers()
        
        # Add to covered intervals
        covered = covered.union(arm_coverage)
    
    # Check if all integers are covered
    if not covered.is_all_integers():
        errors.append('switch_inexhaustive')
    
    return errors


def extract_guard_intervals(guard_str: str) -> Optional[IntInterval]:
    """
    Try to extract integer intervals from a guard expression.
    Returns IntInterval if successful, None if the guard is too complex.
    """
    guard_str = guard_str.strip()
    
    # Handle single conditions
    if ' and ' not in guard_str and ' or ' not in guard_str:
        # Single relational condition
        match = re.match(r'([a-zA-Z_]\w*)\s*(>=|<=|>|<)\s*(-?\d+)', guard_str)
        if match:
            op = match.group(2)
            bound = int(match.group(3))
            return IntInterval.from_relational(op, bound)
    
    # Handle 'and' chains: parse into separate conditions and intersect
    if ' and ' in guard_str:
        parts = guard_str.split(' and ')
        intervals = []
        for part in parts:
            part = part.strip()
            match = re.match(r'([a-zA-Z_]\w*)\s*(>=|<=|>|<)\s*(-?\d+)', part)
            if match:
                op = match.group(2)
                bound = int(match.group(3))
                interval = IntInterval.from_relational(op, bound)
                intervals.append(interval)
            else:
                return None  # Can't parse this condition
        
        if intervals:
            # Intersect all intervals
            result = intervals[0]
            for interval in intervals[1:]:
                result = result.intersect(interval)
            return result
    
    return None


def check_unreachable(parsed: Dict) -> List[str]:
    """Check for unreachable arms."""
    errors = []
    
    if not parsed['functions']:
        return errors
    
    func = parsed['functions'][0]
    subject = func['subject'].strip()
    arms = func['arms']
    
    # Parse subject types
    is_tuple = subject.startswith('(') and subject.endswith(')')
    subject_types = []
    if is_tuple:
        inner = subject[1:-1]
        elements = split_pattern_elements(inner)
        for idx, elem in enumerate(elements):
            elem = elem.strip()
            # Get type by position in function params
            if idx < len(func['params']):
                param_type = func['params'][idx]['type']
            else:
                param_type = None
            subject_types.append(param_type)
    else:
        # Single subject - get type by position
        if len(func['params']) > 0:
            param_type = func['params'][0]['type']
        else:
            param_type = None
        subject_types.append(param_type)
    
    # Check if all subject types are closed
    all_closed = True
    for t in subject_types:
        if not is_closed_type(parsed, t):
            all_closed = False
            break
    
    if not all_closed:
        return errors  # Can't analyze unreachable for open types
    
    # Generate all possible values
    if is_tuple:
        all_cases = generate_all_tuples(subject_types, parsed)
        if all_cases is None:
            return errors
    else:
        # Single type - don't wrap in tuple
        all_values = all_values_for_type(parsed, subject_types[0])
        if all_values is None:
            return errors
        all_cases = all_values
    
    # Track which cases are already covered
    covered_cases = set()
    
    for arm_idx, arm in enumerate(arms):
        pattern_str = arm['pattern'].strip()
        
        if pattern_str == '_':
            # Catch-all over a closed type is always an error (unreachable)
            # because the compiler knows all case names
            if all_closed:
                errors.append('unreachable_arm')
            break
        
        parsed_pattern = parse_pattern(pattern_str)
        
        # Find cases covered by this pattern
        this_arm_covers = set()
        for i, case_value in enumerate(all_cases):
            if pattern_covers(parsed_pattern, case_value):
                this_arm_covers.add(i)
        
        # Check if this arm is completely unreachable
        # (all its cases were already covered by earlier arms)
        if this_arm_covers and this_arm_covers.issubset(covered_cases):
            errors.append('unreachable_arm')
            break
        
        # Add this arm's cases to the covered set
        covered_cases.update(this_arm_covers)
    
    return errors


def check_return_type(parsed: Dict) -> List[str]:
    """Check if return expressions match declared return type."""
    errors = []
    
    if not parsed['functions']:
        return errors
    
    func = parsed['functions'][0]
    return_type = func['return_type']
    
    # Collect all return values from arms
    for arm in func['arms']:
        result = arm['result'].strip()
        
        # Determine the type of result
        result_type = None
        
        if result.startswith(':'):
            result_type = 'atom'
        elif re.match(r'^-?\d+$', result):
            result_type = 'int'
        elif result in parsed['types']:
            result_type = result
        else:
            # Could be a variable or other expression - skip
            continue
        
        # Check if it matches the declared return type
        if result_type and result_type != return_type:
            errors.append('return_not_declared')
            break
    
    return errors


def extract_names_from_pattern(pattern_str: str) -> Set[str]:
    """Extract all variable names introduced in a pattern."""
    names = set()
    
    # Remove guards for now - we'll check them separately
    if ' when ' in pattern_str:
        pattern_str = pattern_str.split(' when ')[0]
    
    pattern_str = pattern_str.strip()
    
    # Handle tuple patterns
    if pattern_str.startswith('(') and pattern_str.endswith(')'):
        inner = pattern_str[1:-1]
        elements = split_pattern_elements(inner)
        for elem in elements:
            names.update(extract_names_from_pattern(elem))
        return names
    
    # Skip wildcards
    if pattern_str == '_':
        return names
    
    # Skip literals
    if pattern_str.startswith(':'):
        return names
    if pattern_str in ('true', 'false'):
        return names
    if re.match(r'^-?\d+$', pattern_str):
        return names
    
    # Skip relational patterns
    if re.match(r'^(>=|<=|>|<)\s*(-?\d+)', pattern_str):
        return names
    
    # Skip equality patterns
    if pattern_str.startswith('=='):
        return names
    
    # It's a variable name
    names.add(pattern_str)
    return names


def extract_names_from_guard(guard_str: str) -> Set[str]:
    """Extract all variable names used in a guard."""
    names = set()
    # Simple approach: look for identifiers that are not operators/keywords
    # Match word boundaries to get variable names
    tokens = re.findall(r'\b[a-zA-Z_]\w*\b', guard_str)
    for token in tokens:
        # Skip keywords and operators
        if token not in ('and', 'or', 'not', 'when', 'true', 'false'):
            names.add(token)
    return names


def check_for_rebinding(parsed: Dict) -> List[str]:
    """Check for rebinding errors (repeated variable names in pattern or guard)."""
    errors = []
    
    if not parsed['functions']:
        return errors
    
    func = parsed['functions'][0]
    arms = func['arms']
    
    for arm in arms:
        pattern_str = arm['pattern'].strip()
        
        # Extract names introduced in the pattern
        introduced_names = extract_names_from_pattern(pattern_str)
        
        # Check if there's a guard
        if ' when ' in pattern_str:
            guard_part = pattern_str.split(' when ')[1]
            guard_names = extract_names_from_guard(guard_part)
            
            # If any guard name was introduced in the pattern, it's rebinding
            rebinding_names = introduced_names & guard_names
            if rebinding_names:
                errors.append('rebinding')
                return errors
    
    return errors


def main():
    if len(sys.argv) != 2:
        print("Usage: switchcheck <path-to-.bs-file>", file=sys.stderr)
        sys.exit(1)
    
    filename = sys.argv[1]
    
    try:
        parsed = parse_file(filename)
    except Exception as e:
        print(f"Error parsing file: {e}", file=sys.stderr)
        sys.exit(1)
    
    errors = []
    
    # Check for rebinding first - this is a syntax error that should stop other checks
    rebinding_errors = check_for_rebinding(parsed)
    if rebinding_errors:
        errors.extend(rebinding_errors)
        # Don't run other checks if rebinding error
        unique_errors = sorted(set(errors))
        for error in unique_errors:
            print(error)
        return
    
    # Run remaining checks
    errors.extend(check_exhaustiveness(parsed))
    errors.extend(check_unreachable(parsed))
    errors.extend(check_return_type(parsed))
    
    # Remove duplicates and print in sorted order
    unique_errors = sorted(set(errors))
    for error in unique_errors:
        print(error)


if __name__ == '__main__':
    main()
