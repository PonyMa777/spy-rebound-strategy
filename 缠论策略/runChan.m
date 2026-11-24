function r = runChan(csvPath)
% 读入行情，调用回测，再保存结果。删掉就要自己串起这些步骤。
% 已审查: runChan() uses data/SPY_1993_2026.csv; runChan('D:\path\stock.csv') uses your file.
here=fileparts(mfilename('fullpath')); root=fileparts(here);
if nargin==0 || strlength(string(csvPath))==0
    csvPath=fullfile(root,'data','SPY_1993_2026.csv');
end
T=readtable(csvPath);
if ~isdatetime(T.Date), T.Date=datetime(string(T.Date),'InputFormat','yyyy-MM-dd'); end
c=chanConfig(); r=backtestChan(T,c);
out=fullfile(root,'results','已审查_chan'); if ~isfolder(out), mkdir(out); end
writetable(r.Daily,fullfile(out,'daily.csv'));
writetable(r.Trades,fullfile(out,'trades.csv'));
writetable(r.Summary,fullfile(out,'summary.csv'));
writetable(r.ByType,fullfile(out,'by_type.csv'));
writetable(r.Segments,fullfile(out,'segments.csv'));
[~,name,ext]=fileparts(csvPath);
label=sprintf('已审查 | Chan MA%d/MA%d | %s%s',c.fastMA,c.slowMA,name,ext);
f=figure('Name',label,'Color','w','Position',[100 100 1100 800]); tiledlayout(3,1);
nexttile; plot(T.Date,r.Daily.SignalPrice,'Color',[0.2 0.4 0.8],'LineWidth',1); hold on;
tr=r.Trades; colors=[0 0.55 0; 0.1 0.6 0.9; 0.6 0.2 0.8]; types=["1B","2B","3B"];
names={'(Open + Close) / 2'};
for k=1:3
    b=tr.EntryType==types(k);
    if any(b)
        scatter(tr.EntryDate(b),tr.EntryPrice(b),40,colors(k,:),'^','filled'); names{end+1}=char(types(k)); %#ok<AGROW>
    end
end
x=~isnat(tr.ExitDate);
if any(x), scatter(tr.ExitDate(x),tr.ExitPrice(x),40,[0.85 0 0],'v','filled'); names{end+1}='Exit'; end
legend(names,'Location','best'); title(label); ylabel('Price'); grid on;
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
disp(label); disp(r.Summary); disp(r.ByType);
fprintf('Results: %s\n',out);
end
