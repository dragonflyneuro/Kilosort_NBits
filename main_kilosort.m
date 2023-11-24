%% STEP1: CHANGE THESE TO MATCH PATHS

addpath(genpath('E:\Github\Kilosort_NBits')) % path to kilosort folder
addpath('E:\Github\npy-matlab\npy-matlab') % for converting to Phy

rootZ = 'E:\ks_test'; % path to binary file
rootTemp = 'C:\ks_test'; % path to temporary binary file (same size as data, should be on fast SSD)
rootC = 'E:\ks_test'; % path to config and chanMap file

chanMapFile = 'chanMap_singleDummied_60k.mat';
binaryFile = '2020-10-28_10-42-20_INTERLACED_kilosortDummied.bin';

ops.trange = [0 Inf]; % time range to sort

actuallyOnlySingleChannelFlag = 0;
ops.NchanTOT    = 4; % total number of channels in your recording
ops.fs = 60000; % sampling rate of data

run(fullfile(rootC, 'config.m'))
ops.fproc   = fullfile(rootTemp, 'temp_wh.dat'); % proc file on a fast SSD
ops.chanMap = fullfile(rootC, chanMapFile);
ops.fbinary = fullfile(rootZ, binaryFile);

%% STEP2: RUN THIS FOR SORTING

fprintf('Looking for data inside %s \n', rootZ)

% duplication-DK
% is there a channel map file in this folder?
% fs = dir(fullfile(rootZ, 'chan*.mat'));
% if ~isempty(fs)
    % ops.chanMap = fullfile(rootZ, fs(1).name);
% end
% find the binary file
% fs          = [dir(fullfile(rootZ, '*.bin')) dir(fullfile(rootZ, '*.dat'))];
% ops.fbinary = fullfile(rootZ, fs(1).name);

% preprocess data to create temp_wh.dat
rez = preprocessDataSub(ops);

% time-reordering as a function of drift
rez = clusterSingleBatches(rez);

% saving here is a good idea, because the rest can be resumed after loading rez
save(fullfile(rootZ, 'rez.mat'), 'rez', '-v7.3');

% main tracking and template matching algorithm
rez = learnAndSolve8b(rez);
save(fullfile(rootZ, 'rez1.mat'), 'rez', '-v7.3');

%% STEP3: RUN THIS FOR CLUSTERING

% OPTIONAL: remove double-counted spikes - solves issue in which individual spikes are assigned to multiple templates.
% See issue 29: https://github.com/MouseLand/Kilosort2/issues/29
%rez = remove_ks2_duplicate_spikes(rez);

% final merges
rez = find_merges(rez, 1);

if actuallyOnlySingleChannelFlag == 0
    % final splits by SVD
    rez = splitAllClusters(rez, 1);
    
    % final splits by amplitudes
    rez = splitAllClusters(rez, 0);
else
    rez.Wphy = cat(1, zeros(1+rez.ops.nt0min, size(rez.W,2), 3), rez.W); % for Phy, we need to pad the spikes with zeros so the spikes are aligned to the center of the window
end

% decide on cutoff
rez = set_cutoff(rez);

fprintf('found %d good units \n', sum(rez.good>0))
fprintf('Saving results to Phy  \n')
rezToPhy(rez, rootZ);

%% STEP4: Write to MATLAB file

% discard features in final rez file (too slow to save)
rez.cProj = [];
rez.cProjPC = [];

% final time sorting of spikes, for apps that use st3 directly
[~, isort]   = sortrows(rez.st3);
rez.st3      = rez.st3(isort, :);

% Ensure all GPU arrays are transferred to CPU side before saving to .mat
rez_fields = fieldnames(rez);
for i = 1:numel(rez_fields)
    field_name = rez_fields{i};
    if(isa(rez.(field_name), 'gpuArray'))
        rez.(field_name) = gather(rez.(field_name));
    end
end

% save final results as rez2
fprintf('Saving final results in rez2  \n')
fname = fullfile(rootZ, 'rez2.mat');
save(fname, 'rez', '-v7.3');


