function [threshold, rocData] = calibrateThreshold()
% CALIBRATETHRESHOLD Selects referable-DR operating threshold via ROC analysis.
% Referable DR = ICDR grade >= 2.
% Finds the lowest threshold achieving >= 90% sensitivity on the val set.
% Saves threshold to models/referableThreshold.mat

    cfg = config();
    
    modelPath = fullfile(cfg.paths.models, 'gradingModel_v1.mat');
    if ~isfile(modelPath)
        error('gradingModel_v1.mat not found. Run trainGradingModel first.');
    end
    data = load(modelPath);
    gradingModel = data.gradingModel;
    
    disp('Loading validation split for threshold calibration...');
    valSplit = load(fullfile(cfg.paths.splits, 'val_index.mat')).val_index;
    valGradable = valSplit(~isnan(valSplit.grade), :);
    
    % Try loading precomputed concept vectors from concepts.mat for fast calibration
    conceptsPath = fullfile(cfg.paths.processed, 'concepts.mat');
    hasCachedConcepts = false;
    if isfile(conceptsPath)
        cData = load(conceptsPath);
        if isfield(cData, 'concepts')
            concepts = cData.concepts;
            hasCachedConcepts = true;
            valConceptFeatures = alignConcepts(valGradable, concepts);
            disp('Using precomputed concept vectors from concepts.mat for fast evaluation.');
        end
    end
    
    % Run inference on the validation set
    numSamples = height(valGradable);
    rawScores = zeros(numSamples, length(cfg.classLabels));
    trueLabels = valGradable.grade;
    validMask = false(numSamples, 1);
    
    fprintf('Evaluating %d validation images...\n', numSamples);
    for i = 1:numSamples
        imgPath = fullfile(cfg.paths.processedImages, ...
            sprintf('%s_%s.png', char(valGradable.sourceDataset(i)), char(valGradable.patientID(i))));
        if ~isfile(imgPath); continue; end
        
        img = imread(imgPath);
        
        if hasCachedConcepts
            cv = valConceptFeatures(i, :);
        else
            cv = buildConceptVector(img);
        end
        
        [~, scores] = predictGrade(img, cv, gradingModel);
        rawScores(i, :) = scores;
        validMask(i) = true;
        
        if mod(i, 50) == 0 || i == numSamples
            fprintf('  Processed %d / %d validation samples.\n', i, numSamples);
        end
    end
    
    rawScores = rawScores(validMask, :);
    trueLabels = trueLabels(validMask);
    
    % Referable-DR: grade >= 2 -> binary classification
    referableTrue = (trueLabels >= 2);
    
    % Probability of referable = sum of P(grade 2) + P(grade 3) + P(grade 4)
    referableScore = sum(rawScores(:, 3:5), 2);
    
    % ROC curve analysis
    [X, Y, T, AUC] = perfcurve(referableTrue, referableScore, true);
    fprintf('====================================================\n');
    fprintf('Referable-DR AUC on validation set: %.4f\n', AUC);
    
    % Find threshold that achieves >= 90% sensitivity (recall)
    % Y = TPR (sensitivity), X = FPR (1 - specificity)
    sensitivityTarget = 0.90;
    validIdx = find(Y >= sensitivityTarget);
    
    if ~isempty(validIdx)
        % Among operating points with sensitivity >= 90%, pick highest specificity (lowest FPR)
        candidates = T(validIdx);
        correspondingFPR = X(validIdx);
        [~, bestIdx] = min(correspondingFPR);
        threshold = candidates(bestIdx);
        bestSens = Y(validIdx(bestIdx)) * 100;
        bestSpec = (1 - X(validIdx(bestIdx))) * 100;
        fprintf('Selected threshold = %.4f (Sensitivity=%.2f%%, Specificity=%.2f%%)\n', ...
            threshold, bestSens, bestSpec);
    else
        % Fallback if 90% is not strictly reached: use point with max sensitivity
        [bestSens, maxSensIdx] = max(Y);
        threshold = T(maxSensIdx);
        bestSpec = (1 - X(maxSensIdx)) * 100;
        bestSens = bestSens * 100;
        warning('Sensitivity >= 90%% not strictly achieved. Using maximum sensitivity threshold = %.4f (Sens=%.2f%%, Spec=%.2f%%)', ...
            threshold, bestSens, bestSpec);
    end
    fprintf('====================================================\n');
    
    rocData = struct('FPR', X, 'TPR', Y, 'Thresholds', T, 'AUC', AUC, ...
                     'selectedThreshold', threshold, 'sensitivity', bestSens, 'specificity', bestSpec);
    
    % Save threshold artifact
    modelDir = cfg.paths.models;
    if ~isfolder(modelDir); mkdir(modelDir); end
    save(fullfile(modelDir, 'referableThreshold.mat'), 'threshold', 'rocData');
    disp('Saved threshold to models/referableThreshold.mat successfully.');
end

% -------------------------------------------------------------------------
function features = alignConcepts(splitTable, conceptStruct)
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
