function trainQualityClassifier()
% TRAINQUALITYCLASSIFIER Synthesizes degraded examples from good images
% and trains an SVM for the quality gate. Saves qualityModel.mat.

    cfg = config();
    disp('Synthesizing quality training data...');
    
    % Load processed dataset table to get baseline images
    splitsPath = fullfile(cfg.paths.splits, 'train_index.mat');
    if ~isfile(splitsPath)
        error('Splits not found. Run buildPatientSplits first.');
    end
    
    data = load(splitsPath);
    train_index = data.train_index;
    
    % Take a small subset (e.g., 50 images) of good images to augment
    numSamples = min(50, height(train_index));
    
    features = [];
    labels = []; % 1 = Acceptable, 0 = Reject
    
    for i = 1:numSamples
        srcDS  = char(train_index.sourceDataset(i));
        patID  = char(train_index.patientID(i));
        imgPath = fullfile(cfg.paths.processedImages, ...
            sprintf('%s_%s.png', srcDS, patID));
        
        if ~isfile(imgPath)
            continue;
        end
        
        img = imread(imgPath);
        
        % 1. Good quality (original)
        f_good = extractQualityFeatures(img);
        features = [features; f_good];
        labels = [labels; 1];
        
        % 2. Directional Motion Blur (Reject)
        h = fspecial('motion', 15, randi([0 180])); % Random angle
        imgBlur = imfilter(img, h, 'replicate');
        f_blur = extractQualityFeatures(imgBlur);
        features = [features; f_blur];
        labels = [labels; 0];
        
        % 3. Severe Underexposure (Reject)
        % Reduce brightness significantly to mimic dark pupil/no flash
        imgDark = imadjust(img, [], [0 0.3]); 
        f_dark = extractQualityFeatures(imgDark);
        features = [features; f_dark];
        labels = [labels; 0];
        
        % 4. Specular Flare (Reject)
        % Add an off-axis bright flare patch to mimic uneven illumination
        [r, c, ~] = size(img);
        flare = zeros(r, c);
        cx = randi([1, r]); cy = randi([1, c]);
        rr = randi([round(r/8), round(r/4)]);
        [X, Y] = meshgrid(1:c, 1:r);
        flareMask = ((X - cy).^2 + (Y - cx).^2) <= rr^2;
        flare(flareMask) = 1;
        flare = imgaussfilt(flare, 40) * 255; % smooth gradient
        
        imgFlare = img + uint8(repmat(flare, 1, 1, 3));
        f_flare = extractQualityFeatures(imgFlare);
        features = [features; f_flare];
        labels = [labels; 0];
    end
    
    disp('Training SVM classifier...');
    % Train SVM with standardization
    qualityModel = fitcsvm(features, labels, 'KernelFunction', 'rbf', 'Standardize', true);
    
    % Evaluate on training data
    pred = predict(qualityModel, features);
    acc = sum(pred == labels) / length(labels);
    fprintf('Training accuracy on synthetic data: %.2f%%\n', acc * 100);
    
    % Save model
    modelDir = cfg.paths.models;
    if ~isfolder(modelDir)
        mkdir(modelDir);
    end
    save(fullfile(modelDir, 'qualityModel.mat'), 'qualityModel');
    disp('Saved qualityModel.mat.');
end
