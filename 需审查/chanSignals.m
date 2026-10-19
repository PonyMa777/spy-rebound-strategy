function s = chanSignals(T,c)
% 需审查: split daily closes into fast/slow MA segments; label each crossing day.
% A segment is known only at the crossing that ends it, so labels use data up to that close.
assert(c.fastMA>=1 && c.slowMA>c.fastMA,'slowMA must exceed fastMA.');
px=T.Close; n=numel(px);
fast=movmean(px,[c.fastMA-1 0]); fast(1:c.fastMA-1)=NaN;
slow=movmean(px,[c.slowMA-1 0]); slow(1:c.slowMA-1)=NaN;
d=fast-slow; state=zeros(n,1);
for t=2:n
    if isnan(d(t)), continue; end
    if d(t)>0, state(t)=1; elseif d(t)<0, state(t)=-1; else, state(t)=state(t-1); end
end
seg=struct('Dir',zeros(0,1),'Hi',zeros(0,1),'Lo',zeros(0,1),'Force',zeros(0,1), ...
    'Label',strings(0,1),'Start',zeros(0,1),'End',zeros(0,1));
label=strings(n,1); stop=nan(n,1); zg=nan(n,1); zd=nan(n,1); falseBreak=false(n,1);
curStart=0; first=true;
for t=2:n
    if state(t)==0 || state(t)==state(t-1), continue; end
    if state(t-1)~=0
        if first
            first=false; % first segment is cut by the MA warm-up
        else
            idx=(curStart:t-1)'; area=sum(abs(d(idx)));
            if strcmp(c.forceMeasure,'mean'), force=area/numel(idx); else, force=area; end
            seg.Dir(end+1,1)=state(t-1); seg.Hi(end+1,1)=max(px(idx)); seg.Lo(end+1,1)=min(px(idx));
            seg.Force(end+1,1)=force; seg.Label(end+1,1)=""; seg.Start(end+1,1)=curStart; seg.End(end+1,1)=t-1;
            [label(t),stop(t),zg(t),zd(t),falseBreak(t)]=chanClassify(seg);
            seg.Label(end)=label(t);
        end
    end
    curStart=t;
end
s.Fast=fast; s.Slow=slow; s.State=state; s.Label=label; s.Stop=stop;
s.ZG=zg; s.ZD=zd; s.FalseBreak=falseBreak;
s.Segments=table(seg.Dir,T.Date(max(seg.Start,1)),T.Date(max(seg.End,1)),seg.Hi,seg.Lo,seg.Force,seg.Label, ...
    'VariableNames',{'Dir','StartDate','EndDate','High','Low','Force','Label'});
end
