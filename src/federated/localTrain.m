function weightDelta = localTrain(centreID, globalWeights, numEpochs)
% LOCALTRAIN Trains a model delta on one simulated centre's data.
% Starts from shared global weights, trains on the centre's local split only,
% returns the weight delta (localWeights - globalWeights).
%
% Inputs:
%   centreID      - String identifier for the simulated centre
%                   ('APTOS2019' | 'IDRiD' | 'DRIVE' — or any source dataset name)
%   globalWeights - Struct array of layer weights (from aggregateModels output)
%   numEpochs     - Number of local training epochs per round (default: 3)
%
% Output:
%   weightDelta - Struct with same shape as globalWeights, containing (local - global)

    if nargin < 3; numEpochs = 3; end

    cfg = config();
    modelDir = cfg.paths.models;
    if ~isfolder(modelDir); mkdir(modelDir); end

    % Load the shared global model
    if isstruct(globalWeights)
        % globalWeights passed directly — reconstruct the network
        globalModel = rebuildNetworkFromWeights(globalWeights);
    else
        % Load from file
        globalModelPath = fullfile(modelDir, 'gradingModel_global.mat');
        if ~isfile(globalModelPath)
            % Fall back to v1 on first round
            globalModelPath = fullfile(modelDir, 'gradingModel_v1.mat');
        end
        if ~isfile(globalModelPath)
            error('No global model found. Train a base model with trainGradingModel first.');
        end
        data = load(globalModelPath);
        globalModel = data.gradingModel;
        globalWeights = extractWeights(globalModel);
    end

    % --- Load this centre's local data (only images from centreID source) ---
    trainSplit = load(fullfile(cfg.paths.splits, 'train_index.mat')).train_index;
    centreData = trainSplit(trainSplit.sourceDataset == centreID & ~isnan(trainSplit.grade), :);

    if height(centreData) == 0
        warning('No data found for centre: %s. Returning zero delta.', centreID);
        weightDelta = zeroWeightDelta(globalWeights);
        return;
    end

    fprintf('[FedLocal] Centre %s: %d images for local training (%d epochs).\n', ...
        centreID, height(centreData), numEpochs);

    % Build image paths and labels
    imgPaths = arrayfun(@(i) fullfile(cfg.paths.processedImages, ...
        sprintf('%s_%s.png', centreData.sourceDataset(i), centreData.patientID(i))), ...
        (1:height(centreData))', 'UniformOutput', false);

    labels = categorical(centreData.grade, cfg.classLabels, cfg.classNames);

    % Concept features (load from concepts.mat or compute inline)
    conceptsPath = fullfile('data', 'processed', 'concepts.mat');
    if isfile(conceptsPath)
        allConcepts = load(conceptsPath).concepts;
        % Align to centreData — assumes concepts rows match train_index rows
        % For centres, we take the matching rows
        centreIdx = find(trainSplit.sourceDataset == centreID & ~isnan(trainSplit.grade));
        localConcepts = allConcepts(centreIdx, :);
    else
        % Fallback zeros (will train image branch only)
        localConcepts = zeros(height(centreData), 7);
    end

    imds = augmentedImageDatastore(cfg.imageSize, imgPaths, labels);
    conceptDs = arrayDatastore(localConcepts, 'IterationDimension', 1);
    localDs = combine(imds, conceptDs);

    % Local training options (fewer epochs than full training to limit overfitting)
    try
        gpuDevice();
        execEnv = 'gpu';
    catch
        execEnv = 'cpu';
    end
    
    opts = trainingOptions('adam', ...
        'ExecutionEnvironment', execEnv, ...
        'InitialLearnRate', 5e-5, ...
        'MaxEpochs', numEpochs, ...
        'MiniBatchSize', 8, ...
        'Shuffle', 'every-epoch', ...
        'Verbose', false, ...
        'Plots', 'none');

    fprintf('[FedLocal] Centre %s: Starting local training (%s)...\n', centreID, execEnv);
    localModel = trainNetwork(localDs, globalModel.Layers, opts);
    localWeights = extractWeights(localModel);
    weightDelta = computeWeightDelta(localWeights, globalWeights);
    weightDelta.centreID = centreID;
    weightDelta.numSamples = height(centreData);
    fprintf('[FedLocal] Centre %s: Training complete. Delta computed.\n', centreID);
end

% -------------------------------------------------------------------------
function weights = extractWeights(net)
    weights = struct();
    for i = 1:numel(net.Layers)
        lName = matlab.lang.makeValidName(net.Layers(i).Name);
        if isprop(net.Layers(i), 'Weights') && ~isempty(net.Layers(i).Weights)
            weights.(lName).W = net.Layers(i).Weights;
        end
        if isprop(net.Layers(i), 'Bias') && ~isempty(net.Layers(i).Bias)
            weights.(lName).b = net.Layers(i).Bias;
        end
    end
end

function delta = zeroWeightDelta(globalWeights)
    fields = fieldnames(globalWeights);
    delta = struct();
    for i = 1:length(fields)
        f = fields{i};
        if isstruct(globalWeights.(f))
            subfields = fieldnames(globalWeights.(f));
            for j = 1:length(subfields)
                sf = subfields{j};
                delta.(f).(sf) = zeros(size(globalWeights.(f).(sf)));
            end
        end
    end
    delta.centreID = 'unknown';
    delta.numSamples = 0;
end

function delta = computeWeightDelta(localWeights, globalWeights)
    delta = struct();
    fields = fieldnames(globalWeights);
    for i = 1:length(fields)
        f = fields{i};
        if isstruct(globalWeights.(f)) && isfield(localWeights, f)
            subfields = fieldnames(globalWeights.(f));
            for j = 1:length(subfields)
                sf = subfields{j};
                delta.(f).(sf) = localWeights.(f).(sf) - globalWeights.(f).(sf);
            end
        end
    end
end
