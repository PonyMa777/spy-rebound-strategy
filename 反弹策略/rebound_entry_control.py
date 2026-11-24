"""Matched random-entry control. Run with python rebound_entry_control.py SPY_daily.csv."""
import csv
import math
import random
import statistics as st
import sys
from collections import defaultdict
from bisect import bisect_right

def study(rows, trials=10000, seed=20261123):
    assert all(a['Date'] < b['Date'] for a,b in zip(rows,rows[1:]))
    o,h,c=([float(r[k]) for r in rows] for k in ('Open','High','Close'))
    mid=[(x+y)/2 for x,y in zip(o,c)]
    signals=[]; ordinary=defaultdict(list); required=defaultdict(int)
    # Match signal dates before any position filter. All features known at that close.
    for i in range(9,len(rows)-1):
        d=mid[i-9:i-5]; p=mid[i-5:i]; m=st.mean(p)
        signal=(all(x>y for x,y in zip(d,d[1:])) and
                (max(p)-min(p))/m<=.02 and abs(sum((j-2)*v for j,v in enumerate(p))/10/m)<=.001
                and abs(p[0]/d[-1]-1)<=.02 and mid[i]/mid[i-1]-1>=.001)
        regime='warmup' if i<199 else c[i]>=st.mean(c[i-199:i+1])
        key=(rows[i]['Date'][:4],regime)
        if signal:
            signals.append(i);required[key]+=1
        else:
            ordinary[key].append(i)
    assert all(len(ordinary[k])>=n for k,n in required.items())
    fills={}
    def order(i):
        if i not in fills:
            j=i+1; buy=o[j]*1.0005; target=buy*1.03
            while j<len(h) and h[j]<target: j+=1
            sell=(max(target,o[j]*.9995) if j<len(h) and j>i+1 else target)
            fills[i]=(buy,j,sell)
        return fills[i]
    def account(days):
        cash=100000.; k=0; entries=0; invested=0
        while k<len(days):
            i=days[k]; buy,j,sell=order(i); qty=math.floor(cash*.5/(buy*1.0005))
            if not qty: break
            cash-=qty*buy*1.0005;entries+=1;invested+=min(j,len(h)-1)-i
            if j==len(h):
                cash+=qty*c[-1];break
            cash+=qty*sell*.9995;k=bisect_right(days,j)
        return (cash/100000-1)*100,entries,invested
    actual=account(signals); rng=random.Random(seed); results=[]
    for _ in range(trials):
        days=sorted(i for key,n in required.items() for i in rng.sample(ordinary[key],n))
        results.append(account(days))
    ranks=sorted(x[0] for x in results)
    print('dates',rows[0]['Date'],rows[-1]['Date'],'raw signals',len(signals),'actual',actual)
    print('random return p05 median p95',ranks[trials//20-1],st.median(ranks),ranks[19*trials//20-1])
    print('random median entries/days',*[st.median(x[k] for x in results) for k in (1,2)])
    print('strictly beaten',sum(x<actual[0] for x in ranks),'of',trials)

if __name__=='__main__':
    with open(sys.argv[1],encoding='utf-8-sig') as f: study(list(csv.DictReader(f)))

