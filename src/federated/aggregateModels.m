function newGlobalWeights = aggregateModels(weightDeltas, globalWeights)
% AGGREGATEMODELS FedAvg aggregation of weight deltas from all centres.
% Performs sample-weighted averaging: centres with more data contribute more.
%
% Inputs:
%   weightDeltas  - Cell array of weightDelta structs from localTrain
%   globalWeights - Current global weight struct
%
% Output:
%   newGlobalWeights - Updated global weights after FedAvg

    numCentres = length(weightDeltas);
    if numCentres == 0
        warning('No weight deltas provided. Returning unchanged global weights.');
        newGlobalWeights = globalWeights;
        return;
    end

    % Collect sample counts per centre for weighted averaging
    nSamples = zeros(numCentres, 1);
    for i = 1:numCentres
        if isfield(weightDeltas{i}, 'numSamples')
            nSamples(i) = weightDeltas{i}.numSamples;
        else
            nSamples(i) = 1; % equal weight fallback
        end
    end
    totalSamples = max(sum(nSamples), 1);
    weights_norm = nSamples / totalSamples; % normalised sample weights

    fprintf('[FedAvg] Aggregating %d centres (total %d samples).\n', numCentres, totalSamples);
    for i = 1:numCentres
        cid = 'unknown';
        if isfield(weightDeltas{i}, 'centreID')
            cid = weightDeltas{i}.centreID;
        end
        fprintf('  Centre %s: %d samples (weight=%.3f)\n', cid, nSamples(i), weights_norm(i));
    end

    % --- FedAvg: newGlobal = global + sum_i(weight_i * delta_i) ---
    newGlobalWeights = globalWeights;
    fields = fieldnames(globalWeights);

    for fi = 1:length(fields)
        f = fields{fi};
        if ~isstruct(globalWeights.(f)); continue; end

        subfields = fieldnames(globalWeights.(f));
        for si = 1:length(subfields)
            sf = subfields{si};
            if ~isnumeric(globalWeights.(f).(sf)); continue; end

            % Weighted sum of deltas
            weightedDeltaSum = zeros(size(globalWeights.(f).(sf)));
            for ci = 1:numCentres
                if isfield(weightDeltas{ci}, f) && isfield(weightDeltas{ci}.(f), sf)
                    d = weightDeltas{ci}.(f).(sf);
                    if isequal(size(d), size(weightedDeltaSum))
                        weightedDeltaSum = weightedDeltaSum + weights_norm(ci) * d;
                    end
                end
            end

            newGlobalWeights.(f).(sf) = globalWeights.(f).(sf) + weightedDeltaSum;
        end
    end

    % Save updated global weights
    cfg = config();
    modelDir = cfg.paths.models;
    if ~isfolder(modelDir); mkdir(modelDir); end
    save(fullfile(modelDir, 'gradingModel_global.mat'), 'newGlobalWeights');
    fprintf('[FedAvg] Global model updated and saved to %s\n', modelDir);
end
