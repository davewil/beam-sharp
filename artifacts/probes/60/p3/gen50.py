#!/usr/bin/env python3
"""Generate a 51-module tree: Shop.Internal.M01..M10 (10 internal leaves),
Shop.A01..A40 (each: 3 internal usings + previous A), Shop.All (uses all 50)."""
import os, sys
root = sys.argv[1]
def w(mod, body):
    d = os.path.join(root, *mod.split('.')); os.makedirs(d, exist_ok=True)
    open(os.path.join(d, mod.split('.')[-1] + '.bs'), 'w').write(body)
for j in range(1, 11):
    w(f'Shop.Internal.M{j:02d}', f"module Shop.Internal.M{j:02d}\n\npublic int G{j:02d}(int n)\nG{j:02d}(n) -> n + {j}\n")
for i in range(1, 41):
    us = [f'Shop.Internal.M{(i+k)%10+1:02d}' for k in range(3)]
    prev = [f'using Shop.A{i-1:02d}'] if i > 1 else []
    lines = ['using ' + u for u in us] + prev
    call = ' + '.join(f'G{u[-2:]}(n)' for u in us) + (f' + F{i-1:02d}(n)' if i > 1 else '')
    w(f'Shop.A{i:02d}', f"module Shop.A{i:02d}\n\n" + '\n'.join(lines) + f"\n\npublic int F{i:02d}(int n)\nF{i:02d}(n) -> {call}\n")
allu = [f'Shop.Internal.M{j:02d}' for j in range(1, 11)] + [f'Shop.A{i:02d}' for i in range(1, 41)]
w('Shop.All', "module Shop.All\n\n" + '\n'.join('using ' + u for u in allu) + "\n\npublic int Go(int n)\nGo(n) -> F40(n)\n")
