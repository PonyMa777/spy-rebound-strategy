function c = chanConfig()
% 需审查: Chan theory lessons 11-20, moving-average version. Returns/fees are decimal fractions.
c.initialCash = 100000;
c.fastMA = 5;             % lesson 11: short MA
c.slowMA = 10;            % lesson 11: long MA
c.forceMeasure = 'area';  % lesson 15: 'area' = sum|fast-slow| over a segment; 'mean' = area / bars
c.useBuy = [true true true]; % enable 1st / 2nd / 3rd class buy points
c.cashFraction = 0.50;
c.feeRate = 0.0005;
c.slippageRate = 0.0005;
c.maxHoldDays = Inf;      % optional time exit in trading days; Inf = off
end
