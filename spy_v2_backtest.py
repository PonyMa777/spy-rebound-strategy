"""Replay revised SPY rules. Usage: python spy_v2_backtest.py daily.csv output.svg"""
import csv
import math
import statistics
import sys
from pathlib import Path
from xml.sax.saxutils import escape


def buy_type(segments):
    if len(segments) < 3:
        return ""
    hi, lo, force, _ = segments[-1]
    if len(segments) >= 4 and lo < segments[-3][1] and segments[-2][0] < segments[-4][0] and force < segments[-3][2]:
        return "1B"
    if segments[-3][3] == "1B" and lo > segments[-3][1]:
        return "2B"
    if len(segments) >= 5:
        pivot = segments[-5:-2]
        top = min(s[0] for s in pivot)
        if top > max(s[1] for s in pivot) and segments[-2][0] > top and lo > top:
            return "3B"
    return ""


class Account:
    def __init__(self, profit, loss):
        self.cash, self.qty = 100000., 0
        self.profit, self.loss = profit, loss
        self.equity, self.closed = [], 0

    def enter(self, quote):
        self.fill = quote * 1.0005
        self.qty = int(self.cash * .5 / (self.fill * 1.0005))
        self.cash -= self.qty * self.fill * 1.0005

    def exit_bar(self, o, h, l, entered):
        if not self.qty:
            return False
        stop, target = self.fill*(1-self.loss), self.fill*(1+self.profit)
        if not entered and o <= stop:
            price = o*.9995
        elif not entered and o >= target:
            price = max(target,o*.9995)
        elif l <= stop:
            price = stop*.9995
        elif h >= target:
            price = target
        else:
            return False
        self.cash += self.qty*price*.9995
        self.qty = 0
        self.closed += 1
        return True


def replay(rows, crossings=None):
    rebound, chan = Account(.03,.015), Account(.015,.01)
    mids, diffs, segments, hold = [], [], [], []
    state, start, skip_first = 0, 0, True
    pending = False
    for i,r in enumerate(rows):
        o,h,l,c = (float(r[key]) for key in ('Open','High','Low','Close'))
        assert 0 < l <= min(o,c) <= max(o,c) <= h
        if not i:
            fill=o*1.0005
            shares=int(100000/(fill*1.0005))
            residual=100000-shares*fill*1.0005
        hold.append(residual+shares*c)
        entered = pending and not rebound.qty
        if entered:
            rebound.enter(o)
        sold = rebound.exit_bar(o,h,l,entered)
        # Before the open, test the down segment ending yesterday.
        # MA5 > MA10 iff live midpoint > sum(last 9 mids)-2*sum(last 4).
        candidate = None
        if state == -1 and not skip_first:
            candidate=[max(mids[start:]),min(mids[start:]),sum(abs(x) for x in diffs[start:]),""]
            candidate[3]=buy_type(segments+[candidate])
        entered = False
        if candidate:
            cross=2*(sum(mids[-9:])-2*sum(mids[-4:]))-o
            trigger=(math.floor(round(cross*100,8))+1)/100
            if h >= trigger:
                quote=max(o,trigger)
                if crossings is not None:
                    crossings.append((i,quote,bool(candidate[3])))
                if not chan.qty and candidate[3]:
                    chan.enter(quote)
                    entered=True
        chan.exit_bar(o,h,l,entered)
        for account in (rebound,chan):
            account.equity.append(account.cash+account.qty*c)
        mids.append((o+c)/2)
        pending=False
        if i>=9:
            d,a=mids[-10:-6],mids[-6:-1]
            m=statistics.mean(a)
            pending=(not sold and all(x>y for x,y in zip(d,d[1:])) and
                     (max(a)-min(a))/m<=.02 and abs(sum((j-2)*x for j,x in enumerate(a))/10/m)<=.001 and
                     abs(a[0]/d[-1]-1)<=.02 and mids[-1]/mids[-2]-1>=.001)
        diff=statistics.mean(mids[-5:])-statistics.mean(mids[-10:]) if i>=9 else 0
        new=1 if diff>1e-12 else -1 if diff< -1e-12 else state
        if new!=state:
            if state and skip_first:
                skip_first=False
            elif state:
                segments.append(candidate or [max(mids[start:-1]),min(mids[start:-1]),sum(abs(x) for x in diffs[start:]),""])
            state,start=new,i
        diffs.append(diff)
    return hold,rebound,chan


def chart(rows,series,path):
    out=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 980 475"><rect width="980" height="475" fill="white"/><g font-family="Arial,sans-serif" fill="#182c38">']
    def label(x,y,t,size=15):
        out.append(f'<text x="{x}" y="{y}" font-size="{size}">{escape(t)}</text>')
    label(28,34,'SPY buy and hold vs. revised strategies',25)
    label(28,60,rows[0]['Date']+' to '+rows[-1]['Date']+' | Cumulative return on $100,000 | Log wealth scale')
    low=min(75000,min(min(a) for _,a,_ in series)*.95)
    def y(v): return 380-290*math.log(v/low)/math.log(2000000/low)
    for v in [80000,100000,150000,200000,500000,1000000,1800000]:
        yy=y(v);out.append(f'<path d="M85 {yy}h850" stroke="#dce1e4"/>');label(12,yy+4,f'{(v/100000-1)*100:.0f}%')
    for idx,(name,a,color) in enumerate(series):
        points=' '.join(f'{85+850*i/(len(a)-1):.1f},{y(v):.1f}' for i,v in enumerate(a))
        out.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="1.6"/>')
        x=30+idx*310
        out.append(f'<path d="M{x} 435h26" stroke="{color}" stroke-width="4"/>')
        label(x+33,440,f'{name} {(a[-1]/100000-1)*100:+,.2f}%')
    for yr in [1993,2000,2010,2020,2026]:
        i=next(i for i,r in enumerate(rows) if r['Date'].startswith(str(yr)))
        label(74+850*i/(len(rows)-1),405,str(yr))
    Path(path).write_text(''.join(out)+'</g></svg>',encoding='utf-8')


if __name__=='__main__':
    with open(sys.argv[1],encoding='utf-8-sig') as f:
        rows=list(csv.DictReader(f))
    assert all(a['Date']<b['Date'] for a,b in zip(rows,rows[1:]))
    h,r,c=replay(rows)
    series=[('SPY buy and hold',h,'#334d99'),('Rebound v2',r.equity,'#00796b'),('Chan intraday proxy',c.equity,'#a74320')]
    for name,a,_ in series:
        peak=100000; dd=0
        for x in a:
            peak=max(peak,x);dd=min(dd,x/peak-1)
        print(name,round(100*(a[-1]/100000-1),3),round(100*dd,3))
    print('Closed trades:',r.closed,c.closed)
    chart(rows,series,sys.argv[2])

