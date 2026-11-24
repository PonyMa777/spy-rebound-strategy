function c = strategyConfig()
% 策略设置：改连跌天数、横盘范围、止盈、仓位或手续费，都在这里改。
% runDemo 和 testStrategy 从这里取参数；直接删掉会让它们找不到默认设置。
% Editable daily strategy parameters. Returns/fees are decimal fractions.
c.initialCash = 100000;
c.symbol = 'SPY';
c.takeProfit = 0.015; % price return before commissions
c.downDays = 3;
c.flatDays = 5;
c.maxFlatRange = 0.02;       % (max close - min close) / mean close
c.maxAbsDailySlope = 0.001; % absolute linear slope / mean close
c.reboundReturn = 0.001;    % 0.1%, NOT 10%
c.cashFraction = 0.50;
c.feeRate = 0.0005;
c.slippageRate = 0.0005;
end
