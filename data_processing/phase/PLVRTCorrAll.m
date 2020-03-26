% function computePLVAll(sbj_name,project_name,block_names,dirs,elecs1,elecs2,pairing,PLVdim,locktype,column,conds,noise_method,plv_params)
function PLVRTCorrAll(sbj_name,project_name,block_names,dirs,elecs1,elecs2,pairing,locktype,column,conds,plv_params)
%% INPUTS
%       sbj_name: subject name
%       project_name: name of task
%       block_names: blocks to be analyed (cell of strings)
%       dirs: directories pointing to files of interest (generated by InitializeDirs)
%       elecs1, elecs2: pairs of electrodes b/w which to compute PLV  
%                       (can either be vectors of elec #s or cells of elec names)
%       pairing: 'all' (compute PLV between all sites in elecs1 and all
%                       sites in elecs2) or 
%                'one' (compute PLV between corresponding entries in elecs1
%                       and elecs2; elecs1 and elecs2 must be same size)   
%       locktype: 'stim' or 'resp' (which event epoched data is locked to)
%       column: column of data.trialinfo by which to sort trials for plotting
%       conds:  cell containing specific conditions to plot within column (default: all of the conditions within column)
%       noise_method:   how to exclude data (default: 'trial'):
%                       'none':     no epoch rejection
%                       'trial':    exclude noisy trials (set to NaN)
%                       'timepts':  set noisy timepoints to NaN but don't exclude entire trials
%%
nelec1 = length(elecs1);
nelec2 = length(elecs2);

if isempty(plv_params)
    plv_params = genPLVParams(project_name);
end

% load globalVar
load([dirs.data_root,'/OriginalData/',sbj_name,'/global_',project_name,'_',sbj_name,'_',block_names{1},'.mat'])
if iscell(elecs1)
    elecnums1 = ChanNamesToNums(globalVar,elecs1);
    elecnames1 = elecs1;
else
    elecnums1 = elecs1;
    elecnames1 = ChanNumsToNames(globalVar,elecs1);
end
if iscell(elecs2) % if names, convert to numbers
    elecnums2 = ChanNamesToNums(globalVar,elecs2);
    elecnames2 = elecs2;
else
    elecnums2 = elecs2;
    elecnames2 = ChanNumsToNames(globalVar,elecs2);
end
% if pairing all elecs1 to all elecs2, reshape them so one-to-one
if strcmp(pairing,'all')
    elecnums1 = repmat(elecnums1,[nelec2,1]);
    elecnums1 = reshape(elecnums1,[1,nelec1*nelec2]);
    elecnums2 = repmat(elecnums2,[1,nelec1]);
    
    elecnames1 = repmat(elecnames1,[nelec2,1]);
    elecnames1 = reshape(elecnames1,[1,nelec1*nelec2]);
    elecnames2 = repmat(elecnames2,[1,nelec1]);
end

tag = [locktype,'lock'];
if plv_params.blc
    tag = [tag,'_bl_corr'];
end
concatfield = {'phase'}; % concatenate phase across blocks

% if have previously run PLV on other pairs of elecrodes, load and append to
% file (rather than overwriting)
dir_out = [dirs.result_root,'/',project_name,'/',sbj_name,'/allblocks/'];   
fn = [dir_out,sbj_name,'_PLV_',PLVdim,'.mat'];
if exist(fn,'file')
    load(fn,'PLV')
end

if ~exist(dir_out,'dir')
    mkdir(dir_out)
end

for ei = 1
    data_tmp = concatBlocks(sbj_name,block_names,dirs,elecnums1(ei),'Spec',concatfield,tag);
    if isempty(conds)
        tmp = find(~cellfun(@isempty,(data_tmp.trialinfo.(column))));
        conds = unique(data_tmp.trialinfo.(column)(tmp));
    end
%     [grouped_trials,grouped_condnames] = groupConds(conds,data_tmp.trialinfo,column,'none',false);
    [grouped_trials,grouped_condnames] = groupConds_multicol({'respType','condNotAfterMtn'},{'CC_city'},data.trialinfo,'trials');
    nconds = length(grouped_trials);
    trialinfo_tmp = data_tmp.trialinfo;
    for bi = 1:length(block_names)
        blocktrials = find(strcmp(trialinfo_tmp.block,block_names{bi}));
        for ci = 1:nconds
            condtrials = find(strcmp(newcol,grouped_condnames{ci}));
            tmp_trials = intersect(blocktrials,condtrials);
            trialinfo_tmp.RT(tmp_trials)=zscore(trialinfo_tmp.RT(tmp_trials));
        end
    end
end

for ei = 1:length(elecnums1)
    el1 = elecnums1(ei);
    el2 = elecnums2(ei);
    if el1 ~= el2
        % concatenate across blocks
        data_all1 = concatBlocks(sbj_name,block_names,dirs,el1,'Spec',concatfield,tag);
        data_all2 = concatBlocks(sbj_name,block_names,dirs,el2,'Spec',concatfield,tag);
        
        phase_diff = angle(exp(1i*(data_all1.phase-data_all2.phase)));
        
        if (strcmp(PLVdim,'trials')) % compute across time (1 value per trial)
            PLV.vals = squeeze(nanmean(exp(1i*(phase_diff)),3));
            PLV.trialinfo = data1.trialinfo;
        else % compute across trials (1 value per timept in trial)
            PLV.vals = squeeze(nanmean(exp(1i*(phase_diff)),2));
            PLV.time = data1.time;
        end
        
        if strcmp(PLVdim,'time') % separate by condition
            data_tmp1 = data_all1;
            data_tmp2 = data_all2;
            for ci = 1:length(grouped_trials)
                data_tmp1.phase = data_all1.phase(:,grouped_trials{ci},:);
                data_tmp2.phase = data_all2.phase(:,grouped_trials{ci},:);
                PLV_tmp = computePLV(data_tmp1,data_tmp2,PLVdim,plv_params);
                PLV.([elecnames1{ei},'_',elecnames2{ei}]).(grouped_condnames{ci})= PLV_tmp.vals;
            end
        else
            PLV_tmp = computePLV(data_all1,data_all2,PLVdim,plv_params);
            PLV.([elecnames1{ei},'_',elecnames2{ei}])= PLV_tmp.vals;
        end
        disp(['Computed PLV between ',elecnames1{ei},' and ',elecnames2{ei}])
    end
    
    PLV.freqs = PLV_tmp.freqs;
end

if strcmp(PLVdim,'trials')
    PLV.trialinfo = data_all1.trialinfo;
else
    PLV.time = data_all1.time;
end

save(fn,'PLV')

end

