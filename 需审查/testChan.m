function testChan()
% 需审查: rule tests on hand-built segments, then engine properties on synthetic prices.
% 1B: lower high, new low, weaker force.
s=mk([1 -1 1 -1],[110 108 105 103],[100 95 96 92],[0 10 0 6]);
[lb,stop]=chanClassify(s); assert(lb=="1B" && stop==92);
s.Force(4)=12; assert(chanClassify(s)=="");        % stronger last leg: no divergence
s.Force(4)=6; s.Hi(3)=111; assert(chanClassify(s)==""); % higher high: no downtrend, no divergence
% 2B: first pullback after 1B holds the 1B low.
s=mk([1 -1 1 -1],[110 108 105 103],[100 95 96 97],[0 10 0 6]); s.Label(2)="1B";
[lb,stop]=chanClassify(s); assert(lb=="2B" && stop==95);
s.Lo(4)=94; assert(chanClassify(s)~="2B");
% 3B and false breakout: pivot [ZD,ZG]=[100,103] from the three segments before the leave.
s=mk([-1 1 -1 1 -1],[105 104 103 110 108],[99 98 100 104 104],[5 5 5 5 5]);
[lb,stop,zg,zd]=chanClassify(s); assert(lb=="3B" && stop==103 && zg==103 && zd==100);
s.Lo(5)=102; [lb,~,~,~,fb]=chanClassify(s); assert(lb=="" && fb);
% Sell side mirrors.
s=mk([-1 1 -1 1],[100 105 103 108],[90 92 94 95],[0 10 0 6]); assert(chanClassify(s)=="1S");
s=mk([-1 1 -1 1],[100 105 103 104],[90 92 94 95],[0 10 0 6]); s.Label(2)="1S";
assert(chanClassify(s)=="2S");
s=mk([1 -1 1 -1 1],[105 104 103 101 98],[99 98 100 90 92],[5 5 5 5 5]);
[lb,~,zg,zd]=chanClassify(s); assert(lb=="3S" && zg==103 && zd==100);

% Engine: decaying waves on a drift produce divergences and pullbacks.
c=chanConfig(); t=(1:600)';
px=100+0.02*t+8*sin(2*pi*t/37).*(1+0.6*sin(2*pi*t/290))+3*sin(2*pi*t/11);
o=[px(1);px(1:end-1)];
T=table(datetime(2000,1,3)+caldays(t-1),o,max(o,px),min(o,px),px,'VariableNames',{'Date','Open','High','Low','Close'});
r=backtestChan(T,c); tr=r.Trades;
assert(height(tr)>0,'Synthetic series should trade.');
for k=1:height(tr)
    i=find(T.Date==tr.SignalDate(k)); j=find(T.Date==tr.EntryDate(k));
    assert(j==i+1 && abs(tr.EntryPrice(k)-T.Open(j)*(1+c.slippageRate))<1e-12); % next open fill
    assert(any(r.Daily.Signal(i)==["1B","2B","3B"]));
    if tr.ExitReason(k)=="STOP"
        e=find(T.Date==tr.ExitSignalDate(k)); assert(T.Low(e)<=tr.StopLevel(k));
    end
end
assert(all(r.Daily.Cash>=0) && all(r.Daily.Shares>=0));
closed=tr(tr.ExitReason~="OPEN",:); open=tr(tr.ExitReason=="OPEN",:);
expected=c.initialCash+sum(closed.PnL);
if ~isempty(open), expected=expected-open.Shares*open.EntryPrice-open.EntryFee+open.Shares*T.Close(end); end
assert(abs(r.Daily.Equity(end)-expected)<1e-6);
% No lookahead: changing prices after day m leaves earlier signals and trades unchanged.
m=400; U=T; U.Close(m+1:end)=U.Close(m+1:end)*1.3; U.Open(m+1:end)=U.Open(m+1:end)*1.3;
U.High=max(U.Open,U.Close); U.Low=min(U.Open,U.Close); q=backtestChan(U,c);
assert(isequal(r.Daily.Signal(1:m),q.Daily.Signal(1:m)));
a=tr(tr.ExitDate<=T.Date(m),:); b=q.Trades(q.Trades.ExitDate<=T.Date(m),:);
assert(isequal(a,b));
% Disabled buy points: no trades. Flat prices: no signals.
c2=c; c2.useBuy=[false false false]; assert(isempty(backtestChan(T,c2).Trades));
U=T; U.Open(:)=100; U.Close(:)=100; U.High(:)=100; U.Low(:)=100; q=backtestChan(U,c);
assert(all(q.Daily.Signal=="") && isempty(q.Trades));
% Explicit boundary, gap and ambiguous-bar tests.
c0=c; c0.slippageRate=0;
[why,p]=chanExitPrice(100,101.5,99.5,100,c0,false); assert(why=="TAKE_PROFIT" && abs(p-101.5)<1e-10);
[why,p]=chanExitPrice(100,101,99,100,c0,false); assert(why=="STOP" && p==99);
[why,p]=chanExitPrice(100,102,98,100,c0,false); assert(why=="STOP" && p==99);
[why,p]=chanExitPrice(97,102,96,100,c0,false); assert(why=="STOP" && p==97);
[why,p]=chanExitPrice(103,104,98,100,c0,false); assert(why=="TAKE_PROFIT" && p==103);
[why,p]=chanExitPrice(100,102,98,100,c0,true); assert(why=="STOP" && p==99);
[why,~]=chanExitPrice(100,101,99.1,100,c0,false); assert(why=="");
assert(isequal(r.Daily.SignalPrice,(T.Open+T.Close)/2));
V=T; V.Open=T.Close; V.Close=T.Open;
sv=chanSignals(V,c); st=chanSignals(T,c);
assert(isequaln(sv,st),'Signals must depend on OC mean, not Close alone.');
V=removevars(T,'Low'); rejected=false;
try, backtestChan(V,c); catch, rejected=true; end
assert(rejected,'Missing Low must be rejected.');
fprintf('PASS: 需审查 Chan rules (1B/2B/3B, 1S/2S/3S, false breakout) and engine (next open, stop, no lookahead, accounting).\n');
end

function s = mk(dir,hi,lo,f)
s.Dir=dir(:); s.Hi=hi(:); s.Lo=lo(:); s.Force=f(:); s.Label=strings(numel(dir),1);
end
