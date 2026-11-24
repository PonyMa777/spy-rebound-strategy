"""Permute Chan entry labels within year and prior-close SMA200 regime."""
import csv
import math
import random
import statistics
import sys
from collections import defaultdict
from spy_v2_backtest import Account, replay

def study(rows):
    events=[]
    _,_,actual=replay(rows,events)
    bars=[tuple(float(row[k]) for k in ('Open','High','Low')) for row in rows]
    closes=[float(row['Close']) for row in rows]
    groups=defaultdict(list); marked=[]; count=defaultdict(int); trades={}
    for i,quote,label in events:
        regime=None if i<200 else closes[i-1]>=statistics.mean(closes[i-200:i])
        key=(rows[i]['Date'][:4],regime)
        groups[key].append(i)
        if label:
            marked.append(i);count[key]+=1
        probe=Account(.015,.01);probe.enter(quote)
        cost=probe.fill*1.0005
        probe.qty=1;probe.cash=0
        for end in range(i,len(rows)):
            if probe.exit_bar(*bars[end],end==i):break
        trades[i]=(cost,probe.cash if not probe.qty else closes[-1],end)
    def result(days):
        cash=100000;last=-1
        for i in sorted(days):
            if i<=last:continue
            cost,net,last=trades[i]
            cash+=math.floor(cash*.5/cost)*(net-cost)
        return (cash/100000-1)*100
    real=result(marked)
    assert abs(real-(actual.equity[-1]/100000-1)*100)<1e-8
    rng=random.Random(20261123)
    simulated=[result(i for k,n in count.items() for i in rng.sample(groups[k],n)) for _ in range(10000)]
    print(len(marked),len(events),real,statistics.median(simulated),sum(x<real for x in simulated))

if __name__=='__main__':
    with open(sys.argv[1],encoding='utf-8-sig') as f:study(list(csv.DictReader(f)))

