function r = backtestStrategy(T,c)
% Signal at close t; execution at open t+1. Take-profit limit; re-entry after a fresh signal.
required = {'Date','Open','High','Close'};
assert(all(ismember(required,T.Properties.VariableNames)), ...
    'CSV requires Date, Open, High, Close columns.');
assert(isdatetime(T.Date),'Date must be datetime.');
assert(~any(isnat(T.Date)) && issorted(T.Date) && ...
    numel(unique(T.Date)) == height(T),'Dates must be valid, sorted and unique.');
assert(all(isfinite(T.Open) & T.Open>0 & isfinite(T.Close) & T.Close>0), ...
    'Open/Close must be positive finite prices.');
assert(c.downDays>=1 && c.downDays==fix(c.downDays) && ...
    c.flatDays>=2 && c.flatDays==fix(c.flatDays),'Invalid window lengths.');
assert(c.initialCash>0 && c.cashFraction>0 && c.cashFraction<=1 && ...
    c.feeRate>=0 && c.slippageRate>=0 && c.maxFlatRange>=0 && ...
    c.maxAbsDailySlope>=0 && c.reboundReturn>=0,'Invalid parameters.');
assert(all(isfinite(T.High) & T.High>=max(T.Open,T.Close)), 'Invalid High prices.');
assert(c.takeProfit>0,'Invalid take profit.');
n=height(T);
assert(n>=c.downDays+c.flatDays+2,'Not enough daily observations.');
signal=false(n,1); flat=false(n,1); decline=false(n,1);
flatRange=nan(n,1); slope=nan(n,1); dailyReturn=[NaN;diff(T.Close)./T.Close(1:end-1)];
for t=c.downDays+c.flatDays+2:n
    % Non-overlapping phases: decline -> flat -> rebound day t.
    a=t-c.flatDays;
    down=T.Close(a-c.downDays-1:a-1);
    plateau=T.Close(a:t-1);
    decline(t)=all(diff(down)<0);
    p=polyfit((0:c.flatDays-1)',plateau,1);
    flatRange(t)=(max(plateau)-min(plateau))/mean(plateau);
    slope(t)=p(1)/mean(plateau);
    % Include the transition into the plateau to reject a large intervening jump.
    transition=abs(plateau(1)/down(end)-1);
    flat(t)=flatRange(t)<=c.maxFlatRange && abs(slope(t))<=c.maxAbsDailySlope ...
        && transition<=c.maxFlatRange;
    signal(t)=decline(t) && flat(t) && dailyReturn(t)>=c.reboundReturn;
end
cash=c.initialCash; shares=0; target=NaN; lastExit=0;
equity=zeros(n,1); cashHistory=zeros(n,1); position=zeros(n,1);
trades=table('Size',[0 8],'VariableTypes', ...
    {'datetime','datetime','string','double','double','double','double','double'}, ...
    'VariableNames',{'SignalDate','ExecutionDate','Side','Shares','FillPrice','Fee','CashAfter','TargetPrice'});
for t=1:n
    boughtToday=false;
    if t>1 && signal(t-1) && shares==0 && t-1>lastExit
        price=T.Open(t)*(1+c.slippageRate);
        qty=floor(cash*c.cashFraction/(price*(1+c.feeRate)));
        if qty>0
            fee=qty*price*c.feeRate;
            cash=cash-qty*price-fee; shares=qty; boughtToday=true;
            target=price*(1+c.takeProfit);
            trades(end+1,:)={T.Date(t-1),T.Date(t),"BUY",qty,price,fee,cash,target};
        end
    end
    % Resting sell limit submitted after entry; daily high tests that target.
    if shares>0 && T.High(t)>=target
        sellPrice=target;
        if ~boughtToday && T.Open(t)>=target
            sellPrice=max(target,T.Open(t)*(1-c.slippageRate));
        end
        fee=shares*sellPrice*c.feeRate;
        cash=cash+shares*sellPrice-fee;
        trades(end+1,:)={NaT,T.Date(t),"SELL",shares,sellPrice,fee,cash,target};
        shares=0; target=NaN; lastExit=t;
    end
    equity(t)=cash+shares*T.Close(t);
    cashHistory(t)=cash; position(t)=shares;
end
% Buy-and-hold reference: same initial capital and entry cost assumptions.
bp=T.Open(1)*(1+c.slippageRate);
bq=floor(c.initialCash/(bp*(1+c.feeRate)));
benchmark=c.initialCash-bq*bp*(1+c.feeRate)+bq*T.Close;
peak=cummax([c.initialCash;equity]); drawdown=equity./peak(2:end)-1;
r.Daily=table(T.Date,T.Open,T.Close,dailyReturn,decline,flat,flatRange,slope, ...
    signal,position,cashHistory,equity,benchmark,drawdown,'VariableNames', ...
    {'Date','Open','Close','DailyReturn','Decline','Flat','FlatRange','DailySlope', ...
    'Signal','Shares','Cash','Equity','BuyHoldEquity','Drawdown'});
r.Trades=trades;
r.Summary=table(equity(end)/c.initialCash-1,min(drawdown), ...
    benchmark(end)/c.initialCash-1,sum(trades.Side=="BUY"),sum(trades.Side=="SELL"),shares, ...
    'VariableNames',{'TotalReturn','MaxDrawdown','BuyHoldReturn','Entries','Exits','FinalShares'});
end
