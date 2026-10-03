#!/usr/bin/env python3
# Generates a many-module tree: N public modules Acme.Lib.P<i> and N internal modules Acme.Lib.Internal.I<i>,
# each module using several earlier ones, plus Acme.App using the last 50 public modules.
import os, shutil, sys
N = int(sys.argv[1]); out = sys.argv[2]
shutil.rmtree(out, ignore_errors=True)
def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True); open(path, 'w').write(text)
def mod(name, dirp, uses, fn, call):
    usings = ''.join('using %s\n' % u for u in uses)
    w(f'{out}/{dirp}/index.bs', f'module {name}\n\n{usings}')
    body = f'{fn}(x) -> {call}' if call else f'{fn}(x) -> x + 1'
    w(f'{out}/{dirp}/{fn}.bs', f'module {name}\n\npublic int {fn}(int x)\n{body}\n')
for i in range(N):
    iu = [f'Acme.Lib.Internal.I{j}' for j in (i-1, i-2) if j >= 0]
    call = f'F_I{i-1}(x)' if i >= 1 else None
    mod(f'Acme.Lib.Internal.I{i}', f'Acme/Lib/Internal/I{i}', iu, f'F_I{i}', call)
for i in range(N):
    uses = [f'Acme.Lib.Internal.I{i}'] + [f'Acme.Lib.Internal.I{i-1}'] * (i >= 1) + \
           [f'Acme.Lib.P{j}' for j in (i-1, i-2, i-3) if j >= 0]
    call = f'F_P{i-1}(F_I{i}(x))' if i >= 1 else f'F_I{i}(x)'
    mod(f'Acme.Lib.P{i}', f'Acme/Lib/P{i}', uses, f'F_P{i}', call)
last = [f'Acme.Lib.P{j}' for j in range(max(0, N-50), N)]
mod('Acme.App', 'Acme/App', last, 'Main', f'F_P{N-1}(x)')
print(f'{2*N+1} modules, {sum(len(f) for _,_,f in os.walk(out))} files')
