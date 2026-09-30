#!/usr/bin/env python3
# Compare hot functions (wrap/hit/spin) between erlc-built and bsc-built .S, labels renumbered in order of appearance.
import re,sys
d=sys.argv[1]
def fn(path,name):
    s=open(path).read()
    m=re.search(r"\{function, "+re.escape(name)+r", \d+, \d+\}\.\n(.*?)(?=\n\{function,|\Z)",s,re.S)
    body=m.group(1)
    body=re.sub(r'\{line,\[[^\n]*\]\}\.\n','',body)
    body=re.sub(r'\s+',' ',body)
    labs={}
    def r(m):
        labs.setdefault(m.group(1),len(labs)); return '{f,L%d}'%labs[m.group(1)]
    def rl(m):
        labs.setdefault(m.group(1),len(labs)); return '{label,L%d}'%labs[m.group(1)]
    body=re.sub(r'\{f,(\d+)\}',r,body); body=re.sub(r'\{label,(\d+)\}',rl,body)
    body=re.sub(r'\{f,L0\}','{f,0}',body)
    body=re.sub(r'% \S+','',body)
    body=re.sub(r'\{call(_last)?,(\d+),\{f,L?\d+\}','{call\\1,\\2,F',body)
    return body
for e,b in [('wrap',"'Wrap'"),('hit',"'Hit'"),('spin',"'Spin'")]:
    a=fn(d+'/bench_erl.S',e); c=fn(d+'/Day01.S',b)
    print(e,'IDENTICAL' if a==c else 'DIFFERENT')
    if a!=c: print(' erl:',a); print(' bs :',c)
