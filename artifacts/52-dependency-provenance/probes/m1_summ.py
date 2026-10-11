import sys,re,statistics as st
rows=[dict(re.findall(r'(\w+)=(\d+)',l)) for l in open(sys.argv[1]).read().splitlines() if l.startswith('lib_dir=')]
for k in ['lib_dir','which','where_is_app','app_load']:
    v=sorted(int(r[k]) for r in rows)
    print(f"   cold first call {k:13s} n={len(v)} median={st.median(v)/1000:8.1f} us  min={v[0]/1000:8.1f}  max={v[-1]/1000:8.1f}")
