%% Change these

fN = 'E:\ks_test\2020-10-28_10-42-20_INTERLACED.bin';
nChOriginal = 1; % how many channels in original data?

%%
fid = fopen(fN, 'r');
d = fread(fid,[nChOriginal,inf],"int16");
d(nChOriginal+1:4,:) = 0;
% d = repmat(d,4/nChOriginal,1);
fclose(fid);

fid = fopen([fN(1:end-4) '_kilosortDummied.bin'], 'w');
if fid < 0
    warning('Data could not be saved')
    return;
end
fwrite(fid, d, 'int16','l'); % little endian write
fclose(fid);
disp('Data saved!');