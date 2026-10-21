function [reason,price] = chanExitPrice(o,h,l,entry,c,isEntryDay)
% Resting bracket orders: open gaps first, otherwise pessimistic intraday order.
% Targets are gross price returns, not net of fees.
target=entry*(1+c.takeProfit); stop=entry*(1-c.stopLoss);
reason=""; price=NaN;
if ~isEntryDay && o<=stop
    reason="STOP"; price=o*(1-c.slippageRate);
elseif ~isEntryDay && o>=target
    reason="TAKE_PROFIT"; price=max(target,o*(1-c.slippageRate));
elseif l<=stop
    reason="STOP"; price=stop*(1-c.slippageRate);
elseif h>=target
    reason="TAKE_PROFIT"; price=target;
end
end