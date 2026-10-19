function r = runSPY(csvPath)
% User must supply actual SPY daily data, no synthetic fallback.
if nargin==0
    [name,folder]=uigetfile('*.csv','Select SPY daily CSV: Date,Open,High,Close');
    if isequal(name,0), r=[]; return; end
    csvPath=fullfile(folder,name);
end
r=runDemo(csvPath);
end
