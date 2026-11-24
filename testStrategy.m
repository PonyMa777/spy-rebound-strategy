function testStrategy()
% 自动检查：用已知价格验证买卖日期、止盈和现金计算，并检查未来价格会不会影响过去的信号。
% 删掉后照样能跑回测，但以后改代码时就少了这组检查。
c=strategyConfig();
p=[105;104;103;102;100;100.02;99.99;100.01;100;100.2;101;102;103];
o=[p(1);p(1:end-1)]; o(1:10)=p(1:10);
T=table(datetime(2025,1,1)+caldays((0:numel(p)-1)'),o,max(o,p),p, ...
    'VariableNames',{'Date','Open','High','Close'});
r=backtestStrategy(T,c);
assert(r.Daily.Signal(10) && height(r.Trades)==2);
assert(r.Trades.ExecutionDate(1)==T.Date(11));
assert(r.Trades.Side(2)=="SELL" && r.Trades.ExecutionDate(2)==T.Date(12));
assert(abs(r.Trades.FillPrice(2)/r.Trades.FillPrice(1)-1-c.takeProfit)<1e-10);
assert(r.Daily.Shares(10)==0 && r.Daily.Shares(11)>0 && r.Daily.Shares(12)==0);
assert(c.initialCash-r.Trades.CashAfter(1)<=c.initialCash*c.cashFraction);
assert(all(r.Daily.Cash>=0));
expected=c.initialCash+sum((2*(r.Trades.Side=="SELL")-1).*r.Trades.Shares.*r.Trades.FillPrice-r.Trades.Fee);
assert(abs(r.Daily.Equity(end)-expected)<1e-7);
U=T; U.Close(12:end)=1000; U.Open(12:end)=1000; U.High=max(U.Open,U.Close);
q=backtestStrategy(U,c);
assert(isequal(r.Daily.Signal(1:11),q.Daily.Signal(1:11)));
assert(isequal(r.Trades(1,:),q.Trades(1,:)));
assert(q.Trades.FillPrice(2)>=q.Trades.TargetPrice(2));
q=backtestStrategy(T(1:10,:),c); assert(isempty(q.Trades));
U=T; U.Open(:)=100; U.Close(:)=100; U.High(:)=100;
q=backtestStrategy(U,c); assert(isempty(q.Trades));
U=T; U.High(11)=105; q=backtestStrategy(U,c);
assert(q.Trades.ExecutionDate(1)==q.Trades.ExecutionDate(2));
U=[T;T]; U.Date=datetime(2025,1,1)+caldays((0:height(U)-1)');
q=backtestStrategy(U,c); assert(sum(q.Trades.Side=="BUY")==2 && sum(q.Trades.Side=="SELL")==2);
% Close rises 0.4%, but OC mean is flat: must not trigger.
U=T; U.Open(10)=99.6; U.Close(10)=100.4; U.High(10)=100.4;
q=backtestStrategy(U,c); assert(~q.Daily.Signal(10));
% Close falls, but OC mean rises 0.2%: must trigger.
U=T; U.Open(10)=100.6; U.Close(10)=99.8; U.High(10)=100.6;
q=backtestStrategy(U,c); assert(q.Daily.Signal(10));
assert(max(abs(q.Daily.SignalPrice-(U.Open+U.Close)/2))<1e-10);
fprintf('PASS: OC mean signal tests; next-open entry, take profit, budget, no lookahead, gaps, same-day exit, re-entry.\n');
end
