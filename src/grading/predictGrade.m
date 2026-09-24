function [grade, rawScores, referableFlag] = predictGrade(img, conceptVec, gradingModel)
% PREDICTGRADE Inference entry point: image + concept vector -> grade + scores.
%
% Inputs:
%   img          - RGB retinal image (will be resized to ResNet input size)
%   conceptVec   - struct from buildConceptVector, or 1x7 / 7x1 numeric feature vector
%   gradingModel - trained network from trainGradingModel (optional; loaded if omitted)
%
% Outputs:
%   grade         - predicted ICDR grade (0-4)
%   rawScores     - 1x5 probability vector over classes [No DR, Mild, Moderate, Severe, PDR]
%   referableFlag - logical, true if referable-DR threshold exceeded

    cfg = config();
    
    % Load model if not passed in
    if nargin < 3 || isempty(gradingModel)
        modelPath = fullfile(cfg.paths.models, 'gradingModel_v1.mat');
        if ~isfile(modelPath)
            error('gradingModel_v1.mat not found. Train the grading model first.');
        end
        data = load(modelPath);
        gradingModel = data.gradingModel;
    end
    
    % Load threshold
    threshPath = fullfile(cfg.paths.models, 'referableThreshold.mat');
    if isfile(threshPath)
        td = load(threshPath);
        referableThreshold = td.threshold;
    else
        referableThreshold = 0.5; % default before calibration
    end
    
    % If conceptVec is omitted, compute it on the fly
    if nargin < 2 || isempty(conceptVec)
        conceptVec = buildConceptVector(img);
    end
    
    % 1. Resize image to model input size (ResNet-50 expects 224x224x3)
    targetSize = [224, 224];
    try
        targetSize = gradingModel.Layers(1).InputSize(1:2);
    catch
    end
    
    imgResized = imresize(img, targetSize);
    if size(imgResized, 3) == 1
        imgResized = repmat(imgResized, [1 1 3]);
    elseif size(imgResized, 3) == 4
        imgResized = imgResized(:,:,1:3);
    end
    
    % Format inputs for 1 observation:
    % Image input expects 4-D array: [H, W, C, N] where N=1
    img4D = reshape(imgResized, [size(imgResized, 1), size(imgResized, 2), 3, 1]);
    
    % Feature input layer expects 2-D matrix: [N, numFeatures] where N=1 (1x7 row vector)
    if isstruct(conceptVec)
        conceptFeatures = [
            double(conceptVec.maCount), ...
            double(conceptVec.hmCount), ...
            double(conceptVec.exArea), ...
            double(conceptVec.cwsCount), ...
            double(conceptVec.nvFlag), ...
            double(conceptVec.nvdScore), ...
            double(conceptVec.nveScore)
        ];
    else
        conceptFeatures = double(conceptVec(:)');
    end
    feat2D = single(reshape(conceptFeatures, 1, []));
    
    % 3. Run inference
    try
        [predLabel, scores] = classify(gradingModel, img4D, feat2D);
        rawScores = double(scores);
    catch
        scores = predict(gradingModel, img4D, feat2D);
        rawScores = double(scores);
        [~, maxIdx] = max(rawScores);
        predLabel = categorical(cfg.classLabels(maxIdx), cfg.classLabels, cfg.classNames);
    end
    
    rawScores = reshape(rawScores, 1, []);
    
    % Map categorical label back to ICDR grade integer (0 to 4)
    grade = str2double(char(predLabel));
    if isnan(grade)
        [~, gradeIdx] = max(rawScores);
        grade = cfg.classLabels(gradeIdx);
    end
    
    % Apply referable threshold
    % Referable DR = Grade >= 2 (Moderate, Severe, PDR)
    referableScore = sum(rawScores(3:5));
    referableFlag = (referableScore >= referableThreshold);
end
