function p = initProject()
% 可选工具：第一次打开仓库时创建 MATLAB 项目文件，以后直接打开已有项目。
% 删掉后仍可在这个目录直接运行 runSPY，只少了一步创建或打开项目的快捷方式。
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
