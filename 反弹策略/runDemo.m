function r = runDemo(csvPath)
% 共用运行入口：不传参数时用模拟价格演示，传 CSV 路径时读取真实数据；跑完保存结果和图。
% runSPY 选完文件也调用这里。删掉后两个入口都会失效，回测核心仍可单独调用。
% runDemo: synthetic example. runDemo('D:\path\stock.csv'): your data.
root=fileparts(fileparts(mfilename('fullpath'))); c=strategyConfig();
if nargin==0 || strlength(string(csvPath))==0
    closePrice=[105;104;103;102;100;100.02;99.99;100.01;100;100.20; ...
        100.4;100.9;100.6;101.2;102;101.5;103;102;101;100;99;101;102;103;104];
    dates=datetime(2025,1,1)+caldays((0:45)');
    dates=dates(~ismember(weekday(dates),[1 7])); dates=dates(1:numel(closePrice));
    openPrice=[closePrice(1);closePrice(1:end-1)];
    openPrice(1:10)=closePrice(1:10); % synthetic setup for OC mean signals
    T=table(dates,openPrice,max(openPrice,closePrice),closePrice,'VariableNames',{'Date','Open','High','Close'});
    label='SYNTHETIC DEMO - not real market performance';
else
    T=readtable(csvPath);
    if ~isdatetime(T.Date), T.Date=datetime(string(T.Date),'InputFormat','yyyy-MM-dd'); end
    label='SPY user CSV - 1.5% price take profit';
end
r=backtestStrategy(T,c);
out=fullfile(root,'results'); if ~isfolder(out), mkdir(out); end
writetable(r.Daily,fullfile(out,'daily.csv'));
writetable(r.Trades,fullfile(out,'trades.csv'));
writetable(r.Summary,fullfile(out,'summary.csv'));
f=figure('Name',label,'Color','w','Position',[100 100 1100 800]); tiledlayout(3,1);
nexttile; plot(T.Date,r.Daily.SignalPrice,'LineWidth',1.3); hold on;
idx=r.Daily.Signal; scatter(T.Date(idx),r.Daily.SignalPrice(idx),65,'o','MarkerEdgeColor',[0.8 0.5 0]);
if ~isempty(r.Trades)
    b=r.Trades.Side=="BUY"; s=r.Trades.Side=="SELL";
    scatter(r.Trades.ExecutionDate(b),r.Trades.FillPrice(b),65,[0 0.55 0],'^','filled');
    scatter(r.Trades.ExecutionDate(s),r.Trades.FillPrice(s),65,[0.85 0 0],'v','filled');
    legend('(Open+Close)/2','Signal','BUY','SELL','Location','best');
end
title(label); ylabel('Price'); grid on;
nexttile; plot(T.Date,[r.Daily.Equity,r.Daily.BuyHoldEquity],'LineWidth',1.2);
legend('Strategy: 50% cash entry','Buy and hold: full capital','Location','best');
ylabel('Account value'); grid on;
nexttile; plot(T.Date,100*r.Daily.Drawdown,'LineWidth',1.2);
ylabel('Drawdown (%)'); xlabel('Date'); grid on;
axs=findall(f,'Type','axes');
for k=1:numel(axs)
    axs(k).Color='w'; axs(k).XColor='k'; axs(k).YColor='k';
    axs(k).Title.Color='k'; axs(k).XLabel.Color='k'; axs(k).YLabel.Color='k';
end
lg=findall(f,'Type','legend');
for k=1:numel(lg), lg(k).Color='w'; lg(k).TextColor='k'; end
exportgraphics(f,fullfile(out,'backtest.png'));
disp(label); disp(r.Summary); disp(r.Trades);
fprintf('Results: %s\n',out);
end
