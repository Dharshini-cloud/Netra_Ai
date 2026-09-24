function trainGradingModel()
% TRAINGRADINGMODEL Trains the concept-bottleneck grading network.
% Loads cached concept vectors + images, builds multimodal combined datastores,
% trains and evaluates, and saves versioned model artifact.

    cfg = config();
    modelDir = cfg.paths.models;
    if ~isfolder(modelDir); mkdir(modelDir); end
    
    % Use the config-defined processed data path
    conceptsPath = fullfile(cfg.paths.processed, 'concepts.mat');
    
    if ~isfile(conceptsPath)
        error(['concepts.mat not found. Run buildConceptVectorBatch on the full dataset first.\n' ...
               'Run: buildConceptVectorBatch();']);
    end
    
    disp('Loading splits and concept vectors...');
    trainSplit = load(fullfile(cfg.paths.splits, 'train_index.mat')).train_index;
    valSplit   = load(fullfile(cfg.paths.splits, 'val_index.mat')).val_index;
    conceptsData = load(conceptsPath);
    if isfield(conceptsData, 'concepts')
        concepts = conceptsData.concepts;
    else
        concepts = conceptsData;
    end
    
    % --- Filter gradable splits (exclude DRIVE / ungradable) ---
    trainGradable = trainSplit(~isnan(trainSplit.grade), :);
    valGradable   = valSplit(~isnan(valSplit.grade), :);
    
    % Build full image paths
    trainImgPaths = arrayfun(@(i) fullfile(cfg.paths.processedImages, ...
        sprintf('%s_%s.png', char(trainGradable.sourceDataset(i)), char(trainGradable.patientID(i)))), ...
        (1:height(trainGradable))', 'UniformOutput', false);
    valImgPaths = arrayfun(@(i) fullfile(cfg.paths.processedImages, ...
        sprintf('%s_%s.png', char(valGradable.sourceDataset(i)), char(valGradable.patientID(i)))), ...
        (1:height(valGradable))', 'UniformOutput', false);
    
    % Verify which files actually exist on disk
    validTrain = cellfun(@isfile, trainImgPaths);
    trainGradable = trainGradable(validTrain, :);
    trainImgPaths = trainImgPaths(validTrain);
    
    validVal = cellfun(@isfile, valImgPaths);
    valGradable = valGradable(validVal, :);
    valImgPaths = valImgPaths(validVal);
    
    fprintf('Found %d valid training images and %d valid validation images.\n', ...
        length(trainImgPaths), length(valImgPaths));
    
    trainLabels = categorical(trainGradable.grade, cfg.classLabels, cfg.classNames);
    valLabels   = categorical(valGradable.grade, cfg.classLabels, cfg.classNames);
    
    % --- Align concept features to image split rows by composite key ---
    trainConceptFeatures = alignConcepts(trainGradable, concepts);
    valConceptFeatures   = alignConcepts(valGradable,   concepts);
    
    % --- Create Multimodal Datastores (Image + Concept + Label) ---
    % 1. Image Datastores
    imdsTrain = imageDatastore(trainImgPaths);
    imdsVal   = imageDatastore(valImgPaths);
    
    % 2. Concept Vector Datastores
    trainConceptDs = arrayDatastore(trainConceptFeatures, 'IterationDimension', 1);
    valConceptDs   = arrayDatastore(valConceptFeatures,   'IterationDimension', 1);
    
    % 3. Label Datastores
    trainLabelDs = arrayDatastore(trainLabels);
    valLabelDs   = arrayDatastore(valLabels);
    
    % 4. Combine into multimodal tuples: {Image, ConceptVector, Label}
    combinedTrain = combine(imdsTrain, trainConceptDs, trainLabelDs);
    combinedVal   = combine(imdsVal,   valConceptDs,   valLabelDs);
    
    % ResNet-50 input size
    targetSize = [224, 224, 3];
    
    % Optional on-the-fly augmentation for training
    augmenter = imageDataAugmenter(...
        'RandRotation', [-15 15], ...
        'RandXReflection', true, ...
        'RandYReflection', true, ...
        'RandXScale', [0.9 1.1], ...
        'RandYScale', [0.9 1.1]);
    
    trainDs = transform(combinedTrain, @(data) preprocessGradingData(data, targetSize, augmenter));
    valDs   = transform(combinedVal,   @(data) preprocessGradingData(data, targetSize, []));
    
    % --- Build the Concept Bottleneck Network ---
    numConcepts = 7;
    lgraph = buildConceptBottleneckNet(numConcepts);
    
    % --- Training options ---
    try
        gpu = gpuDevice();
        execEnv = 'gpu';
        fprintf('GPU detected (%s). Using GPU for training.\n', gpu.Name);
        batchSize = 16;
        maxEpochs = 20;
    catch
        execEnv = 'cpu';
        disp('No compatible GPU detected. Using CPU for training.');
        batchSize = 32;
        maxEpochs = 10; % Faster convergence on CPU
    end
    
    opts = trainingOptions('adam', ...
        'ExecutionEnvironment', execEnv, ...
        'InitialLearnRate', 1e-4, ...
        'MaxEpochs', maxEpochs, ...
        'MiniBatchSize', batchSize, ...
        'Shuffle', 'every-epoch', ...
        'ValidationData', valDs, ...
        'ValidationFrequency', 40, ...
        'ValidationPatience', 4, ...
        'OutputNetwork', 'best-validation-loss', ...
        'Plots', 'training-progress', ...
        'Verbose', true);
    
    disp('Starting training for Concept Bottleneck grading model...');
    gradingModel = trainNetwork(trainDs, lgraph, opts);
    
    % Versioned save
    version = 1;
    savePath = fullfile(modelDir, sprintf('gradingModel_v%d.mat', version));
    while isfile(savePath)
        version = version + 1;
        savePath = fullfile(modelDir, sprintf('gradingModel_v%d.mat', version));
    end
    save(savePath, 'gradingModel');
    fprintf('Saved versioned model: %s\n', savePath);
    
    % Also save standard primary model checkpoint for pipeline inference
    primaryPath = fullfile(modelDir, 'gradingModel_v1.mat');
    save(primaryPath, 'gradingModel');
    fprintf('Saved primary model checkpoint: %s\n', primaryPath);
    disp('Grading Model training complete!');
end

% -------------------------------------------------------------------------
function dataOut = preprocessGradingData(dataIn, targetSize, augmenter)
% Formats {img, concept, label} for multi-input network
    img     = dataIn{1};
    concept = dataIn{2};
    label   = dataIn{3};
    
    % Ensure 3 channels
    if size(img, 3) == 1
        img = repmat(img, [1 1 3]);
    end
    
    % Resize to target size for ResNet backbone
    imgResized = imresize(img, targetSize(1:2));
    
    % Augment image if requested
    if ~isempty(augmenter)
        imgResized = augment(augmenter, imgResized);
    end
    
    % IMPORTANT: Concept vector must be a column vector [numFeatures x 1] (i.e. 7x1)
    % A 1x7 row vector is interpreted by MATLAB as 7 observations of 1 feature!
    conceptVec = single(concept(:));
    
    dataOut = {imgResized, conceptVec, label};
end

% -------------------------------------------------------------------------
function features = alignConcepts(splitTable, conceptStruct)
% ALIGNCONCEPTS Maps concept matrix rows to the order of splitTable rows.
% Matches by composite key: "DATASET_PATIENTID".
    n = height(splitTable);
    features = zeros(n, 7);
    
    if isstruct(conceptStruct) && isfield(conceptStruct, 'keys') && isfield(conceptStruct, 'matrix')
        keys = conceptStruct.keys;
        matrix = conceptStruct.matrix;
        for k = 1:n
            compositeKey = sprintf('%s_%s', char(splitTable.sourceDataset(k)), char(splitTable.patientID(k)));
            idx = find(strcmp(keys, compositeKey), 1);
            if ~isempty(idx)
                features(k, :) = matrix(idx, :);
            end
        end
    elseif isnumeric(conceptStruct)
        available = min(size(conceptStruct, 1), n);
        features(1:available, :) = conceptStruct(1:available, :);
    end
end