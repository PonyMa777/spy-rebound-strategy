function r = backtestChan(T,c)
% 需审查: long only. Signal at close t, fill at open t+1.
% Fixed intraday take-profit/stop only. Same-bar ambiguity: stop first.
required={'Date','Open','High','Low','Close'};
assert(all(ismember(required,T.Properties.VariableNames)), ...
    'CSV requires Date, Open, High, Low, Close columns. Low is required for intraday stops.');
assert(isdatetime(T.Date) && ~any(isnat(T.Date)) && issorted(T.Date) && ...
    numel(unique(T.Date))==height(T),'Dates must be valid, sorted and unique.');
assert(all(isfinite(T.Open) & T.Open>0 & isfinite(T.Close) & T.Close>0), ...
    'Open/Close must be positive finite prices.');
assert(c.initialCash>0 && c.cashFraction>0 && c.cashFraction<=1 && ...
    c.feeRate>=0 && c.slippageRate>=0 && c.slippageRate<1 && c.takeProfit>0 && c.stopLoss>0 && c.stopLoss<1,'Invalid parameters.');
assert(height(T)>0,'Data must not be empty.');
assert(all(isfinite(T.High) & isfinite(T.Low) & T.Low>0 & ...
    T.High>=max(T.Open,T.Close) & T.Low<=min(T.Open,T.Close)), 'Invalid OHLC prices.');
s=chanSignals(T,c); n=height(T);
buyTypes=["1B","2B","3B"]; buyTypes=buyTypes(logical(c.useBuy));

cash=c.initialCash; shares=0; entry=0; ot=struct();
pendingBuy=""; rows={};
equity=zeros(n,1); cashHistory=zeros(n,1); position=zeros(n,1);
for t=1:n
    if pendingBuy~="" && shares==0
        price=T.Open(t)*(1+c.slippageRate);
        qty=floor(cash*c.cashFraction/(price*(1+c.feeRate)));
        if qty>0
            fee=qty*price*c.feeRate; cash=cash-qty*price-fee;
            shares=qty; entry=t;
            ot=struct('EntryType',pendingBuy,'SignalDate',T.Date(t-1),'EntryDate',T.Date(t), ...
                'EntryPrice',price,'Shares',qty,'EntryFee',fee,'StopLevel',price*(1-c.stopLoss), ...
                'ExitReason',"OPEN",'ExitSignalDate',NaT,'ExitDate',NaT,'ExitPrice',NaN, ...
                'ExitFee',NaN,'PnL',NaN,'Return',NaN,'HoldDays',NaN);
        end
    end
    pendingBuy=""; exited=false;
    if shares>0
        [reason,price]=chanExitPrice(T.Open(t),T.High(t),T.Low(t),ot.EntryPrice,c,t==entry);
        if reason~=""
            fee=shares*price*c.feeRate;
            cash=cash+shares*price-fee; cost=ot.Shares*ot.EntryPrice+ot.EntryFee;
            ot.ExitReason=reason; ot.ExitSignalDate=T.Date(t); ot.ExitDate=T.Date(t);
            ot.ExitPrice=price; ot.ExitFee=fee; ot.PnL=shares*price-fee-cost;
            ot.Return=ot.PnL/cost; ot.HoldDays=t-entry;
            rows{end+1}=ot; shares=0; exited=true; %#ok<AGROW>
        end
    end
    if shares==0 && ~exited && ismember(s.Label(t),buyTypes)
        pendingBuy=s.Label(t);
    end
    equity(t)=cash+shares*T.Close(t); cashHistory(t)=cash; position(t)=shares;
end
if shares>0, ot.HoldDays=n-entry; rows{end+1}=ot; end
if isempty(rows)
    trades=table('Size',[0 15],'VariableTypes',{'string','datetime','datetime','double','double', ...
        'double','double','string','datetime','datetime','double','double','double','double','double'}, ...
        'VariableNames',{'EntryType','SignalDate','EntryDate','EntryPrice','Shares','EntryFee', ...
        'StopLevel','ExitReason','ExitSignalDate','ExitDate','ExitPrice','ExitFee','PnL','Return','HoldDays'});
else
    trades=struct2table([rows{:}],'AsArray',true);
end
% Buy-and-hold reference: same initial capital and entry cost assumptions.
bp=T.Open(1)*(1+c.slippageRate);
bq=floor(c.initialCash/(bp*(1+c.feeRate)));
benchmark=c.initialCash-bq*bp*(1+c.feeRate)+bq*T.Close;
peak=cummax([c.initialCash;equity]); drawdown=equity./peak(2:end)-1;
r.Daily=table(T.Date,T.Open,T.Close,(T.Open+T.Close)/2,s.Fast,s.Slow,s.State,s.Label,s.Stop,s.ZG,s.ZD,s.FalseBreak, ...
    position,cashHistory,equity,benchmark,drawdown,'VariableNames', ...
    {'Date','Open','Close','SignalPrice','FastMA','SlowMA','State','Signal','StructureLevel','ZG','ZD','FalseBreak', ...
    'Shares','Cash','Equity','BuyHoldEquity','Drawdown'});
r.Trades=trades; r.Segments=s.Segments;
closed=trades(trades.ExitReason~="OPEN",:);
[w,lo95,hi95]=winRate(closed.PnL);
r.Summary=table(equity(end)/c.initialCash-1,min(drawdown),benchmark(end)/c.initialCash-1, ...
    height(closed),w,lo95,hi95,mean(closed.Return),mean(closed.HoldDays), ...
    sum(s.Label=="1B"),sum(s.Label=="2B"),sum(s.Label=="3B"),sum(s.FalseBreak),shares, ...
    'VariableNames',{'TotalReturn','MaxDrawdown','BuyHoldReturn','ClosedTrades','WinRate', ...
    'WinLow95','WinHigh95','AvgTradeReturn','AvgHoldDays','Signals1B','Signals2B','Signals3B', ...
    'FalseBreaks','FinalShares'});
types=["1B";"2B";"3B"]; nT=zeros(3,1); wr=nan(3,1); avgR=nan(3,1); stops=zeros(3,1);
for k=1:3
    x=closed(closed.EntryType==types(k),:); nT(k)=height(x);
    wr(k)=winRate(x.PnL); avgR(k)=mean(x.Return); stops(k)=sum(x.ExitReason=="STOP");
end
r.ByType=table(types,nT,wr,avgR,stops,'VariableNames', ...
    {'EntryType','ClosedTrades','WinRate','AvgReturn','StopExits'});
end

function [p,lo,hi] = winRate(pnl)
% Win share with a Wilson 95% interval; NaN when there are no trades.
m=numel(pnl); p=NaN; lo=NaN; hi=NaN;
if m==0, return; end
p=mean(pnl>0); z=1.96;
mid=(p+z^2/(2*m))/(1+z^2/m); half=z*sqrt(p*(1-p)/m+z^2/(4*m^2))/(1+z^2/m);
lo=mid-half; hi=mid+half;
end
