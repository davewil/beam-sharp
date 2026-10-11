#!/usr/bin/env python3
# Summarises timing.out : per workload and build, the median of the 5 per-round medians (each = 40 timed runs) and the range of those medians.
import re, statistics, collections, os
here = os.path.dirname(os.path.abspath(__file__)); d = collections.defaultdict(list); cur = None
for l in open(os.path.join(here, 'timing.out')):
    m = re.match(r'## round=(\d) build=(\w+)', l)
    if m: cur = m.group(2); continue
    m = re.match(r'(.{18}) runs=40 median=(\d+)us', l)
    if m: d[(m.group(1).strip(), cur)].append(int(m.group(2)))
work = sorted({k[0] for k in d})
print('%-18s %s' % ('workload (us)', '  '.join('%-22s' % b for b in ['base', 'A', 'B', 'Barith'])))
for w in work:
    print('%-18s %s' % (w, '  '.join('%-22s' % ('%d [%d..%d]' % (statistics.median(d[(w, b)]), min(d[(w, b)]), max(d[(w, b)]))) for b in ['base', 'A', 'B', 'Barith'])))
