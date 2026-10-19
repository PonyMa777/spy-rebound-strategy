function p = initProject()
% Recreate MATLAB project metadata after cloning this repository.
root=fileparts(mfilename('fullpath'));
files=dir(fullfile(root,'*.prj'));
if isempty(files)
    p=matlab.project.createProject(root);
    p.Name='SPY Rebound Strategy';
else
    p=openProject(fullfile(root,files(1).name));
end
end
