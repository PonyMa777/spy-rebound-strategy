function [label,stop,zg,zd,falseBreak] = chanClassify(seg)
% 已审查: classify the newest completed MA segment (lessons 12-20, MA version).
% seg fields are column vectors, oldest first: Dir (+1 up / -1 down), Hi, Lo, Force, Label.
% A down segment ends at a golden cross (buy side); an up segment ends at a death cross (sell side).
label=""; stop=NaN; zg=NaN; zd=NaN; falseBreak=false;
k=numel(seg.Dir);
if k<3, return; end
hi=seg.Hi; lo=seg.Lo; f=seg.Force;
if seg.Dir(k)<0
    % 1B: downtrend (lower high, lower low) whose last leg is weaker = bottom divergence.
    if k>=4 && lo(k)<lo(k-2) && hi(k-1)<hi(k-3) && f(k)<f(k-2)
        label="1B"; stop=lo(k); return;
    end
    % 2B: first pullback after a 1B does not break the 1B low.
    if seg.Label(k-2)=="1B" && lo(k)>lo(k-2)
        label="2B"; stop=lo(k-2); return;
    end
    % 3B: leave the pivot upward, first pullback stays above ZG; otherwise a false breakout.
    if k>=5
        [zg,zd]=pivot(hi,lo,k);
        if zg>zd && hi(k-1)>zg
            if lo(k)>zg, label="3B"; stop=zg; else, falseBreak=true; end
        else
            zg=NaN; zd=NaN;
        end
    end
else
    % 1S: uptrend (higher high, higher low) whose last leg is weaker = top divergence.
    if k>=4 && hi(k)>hi(k-2) && lo(k-1)>lo(k-3) && f(k)<f(k-2)
        label="1S"; return;
    end
    % 2S: first rebound after a 1S does not exceed the 1S high.
    if seg.Label(k-2)=="1S" && hi(k)<hi(k-2)
        label="2S"; return;
    end
    % 3S: leave the pivot downward, first rebound stays below ZD; otherwise a false breakdown.
    if k>=5
        [zg,zd]=pivot(hi,lo,k);
        if zg>zd && lo(k-1)<zd
            if hi(k)<zd, label="3S"; else, falseBreak=true; end
        else
            zg=NaN; zd=NaN;
        end
    end
end
end

function [zg,zd] = pivot(hi,lo,k)
% Lessons 17/20: overlap of the three segments before the leaving segment.
zg=min(hi(k-4:k-2)); zd=max(lo(k-4:k-2));
end
