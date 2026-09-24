function net = rebuildNetworkFromWeights(globalWeights)
% REBUILDNETWORKFROMWEIGHTS Loads the base network structure for federated rounds.
    cfg = config();
    modelDir = cfg.paths.models;
    globalModelPath = fullfile(modelDir, 'gradingModel_global.mat');
    if ~isfile(globalModelPath) || ~isfield(load(globalModelPath), 'gradingModel')
        globalModelPath = fullfile(modelDir, 'gradingModel_v1.mat');
    end
    data = load(globalModelPath);
    if isfield(data, 'gradingModel')
        net = data.gradingModel;
    elseif isfield(data, 'gradingNet')
        net = data.gradingNet;
    else
        fn = fieldnames(data);
        net = data.(fn{1});
    end
end
