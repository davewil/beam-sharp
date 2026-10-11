#!/usr/bin/env python3
# Joins corpus.{reference,A,B,Barith}.out into one acceptance matrix. Run: python3 -I matrix.py
import re, os
here = os.path.dirname(os.path.abspath(__file__))
names = ['reference', 'A', 'B', 'Barith']; d = {}; order = []
for n in names:
    for l in open(os.path.join(here, f'corpus.{n}.out')):
        m = re.match(r'(ok|!!) (\S+)\s+(accepted|refused)\s+\(want (accepted|refused)', l)
        if m:
            d.setdefault(m.group(2), {})['want'] = m.group(4); d[m.group(2)][n] = m.group(3)
            if n == 'reference': order.append(m.group(2))
print('%-22s %-9s %-9s %-9s %-9s %-9s' % ('case', 'want', 'reference', 'A', 'B', 'Barith'))
for k in order:
    r = d[k]; print('%-22s %-9s %-9s %-9s %-9s %-9s' % (k, r['want'], r['reference'], r['A'], r['B'], r['Barith']))
# a patched build must still refuse every N* control
bad = [k for k in order if k.startswith(('N', 'F1', 'P3')) and any(d[k][n] != 'refused' for n in names)]
print('\nnegative controls accepted by some build:', bad or 'none')
