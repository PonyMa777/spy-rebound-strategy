function r = runSPY(csvPath)
% 选文件的快捷入口：弹窗选 SPY 行情 CSV，再交给 runDemo 读取和回测。
% 删掉后仍可用 runDemo(csvPath) 跑同一份数据，只少了这个入口。
% User must supply actual SPY daily data, no synthetic fallback.
if nargin==0
    [name,folder]=uigetfile('*.csv','Select SPY daily CSV: Date,Open,High,Close');
    if isequal(name,0), r=[]; return; end
    csvPath=fullfile(folder,name);
end
r=runDemo(csvPath);
end
