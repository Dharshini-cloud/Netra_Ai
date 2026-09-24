function trainLesionClassifiers()
% TRAINLESIONCLASSIFIERS Trains small patch-level CNN false-positive classifiers
% for each lesion type: MA (Microaneurysms), HM (Haemorrhages), EX (Exudates), CWS (Cotton Wool Spots).
% Uses IDRiD lesion-level ground truth to extract positive and negative patches.
% Saves models/lesionClassifiers.mat

    cfg = config();
    modelDir = cfg.paths.models;
    if ~isfolder(modelDir)
        mkdir(modelDir);
    end

    % Locate splits or scan raw IDRiD directory directly
    splitsPath = fullfile(cfg.paths.splits, 'train_index.mat');
    idridData = table();
    if isfile(splitsPath)
        data = load(splitsPath);
        train_index = data.train_index;
        idridData = train_index(train_index.sourceDataset == "IDRiD", :);
    end

    % If splits don't have IDRiD, populate directly from data/raw/IDRiD/A. Segmentation
    if height(idridData) == 0
        segImgDir = fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '1. Original Images', 'a. Training Set');
        if isfolder(segImgDir)
            imgFiles = dir(fullfile(segImgDir, '*.jpg'));
            if isempty(imgFiles)
                imgFiles = dir(fullfile(segImgDir, '*.tif'));
            end
            if ~isempty(imgFiles)
                pIDs = cellfun(@(x) erase(x, {'.jpg', '.tif'}), {imgFiles.name}', 'UniformOutput', false);
                pPaths = cellfun(@(folder, name) fullfile(folder, name), {imgFiles.folder}', {imgFiles.name}', 'UniformOutput', false);
                pSource = repmat(["IDRiD"], length(imgFiles), 1);
                idridData = table(string(pIDs), string(pPaths), pSource, ...
                    'VariableNames', {'patientID', 'imagePath', 'sourceDataset'});
                fprintf('Loaded %d IDRiD segmentation training images directly from raw folder.\n', height(idridData));
            end
        end
    end

    if height(idridData) == 0
        error('No IDRiD images found in splits or in data/raw/IDRiD/A. Segmentation.');
    end

    % Lesion types and their IDRiD mask folder suffixes
    lesionTypes = {'MA', 'HE', 'EX', 'SE'}; % IDRiD naming: MA=Microaneurysms, HE=Haemorrhages, EX=Exudates, SE=Soft Exudates
    patchSize = [32 32]; % Patch size for the classifier CNN

    lesionClassifiers = struct();

    for lt = 1:length(lesionTypes)
        lType = lesionTypes{lt};
        disp(['Extracting patches for: ', lType]);

        switch lType
            case 'MA'
                subfolders = {'1. Microaneurysms', 'Microaneurysms', 'MA'};
            case 'HE'
                subfolders = {'2. Haemorrhages', 'Haemorrhages', 'HE'};
            case 'EX'
                subfolders = {'3. Hard Exudates', 'Hard Exudates', 'EX'};
            case 'SE'
                subfolders = {'4. Soft Exudates', 'Soft Exudates', 'SE'};
            otherwise
                subfolders = {lType};
        end

        posPatches = {};
        negPatches = {};

        for i = 1:height(idridData)
            imgPath = char(idridData.imagePath(i));
            [~, imgName, ~] = fileparts(imgPath);

            % Extract numeric ID if present (e.g. IDRiD_001 -> 1)
            tokens = regexp(char(imgName), 'IDRiD_(\d+)', 'tokens');
            if ~isempty(tokens)
                idNum = str2double(tokens{1}{1});
                candMaskNames = {
                    sprintf('IDRiD_%02d_%s.tif', idNum, lType), ...
                    sprintf('IDRiD_%03d_%s.tif', idNum, lType), ...
                    sprintf('IDRiD_%d_%s.tif', idNum, lType), ...
                    sprintf('%s_%s.tif', char(imgName), lType)
                };
            else
                candMaskNames = {sprintf('%s_%s.tif', char(imgName), lType)};
                idNum = NaN;
            end

            % Search for mask across IDRiD segmentation ground truth directories
            maskPath = '';
            for s = 1:length(subfolders)
                sub = subfolders{s};
                searchDirs = {
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', sub), ...
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '2. All Segmentation Groundtruths', 'b. Testing Set', sub), ...
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', sub), ...
                    fullfile(cfg.paths.rawIDRiD, sub), ...
                    fullfile(cfg.paths.rawIDRiD, lType)
                };
                for sd = 1:length(searchDirs)
                    for mn = 1:length(candMaskNames)
                        candPath = fullfile(searchDirs{sd}, candMaskNames{mn});
                        if isfile(candPath)
                            maskPath = candPath;
                            break;
                        end
                    end
                    if ~isempty(maskPath), break; end
                end
                if ~isempty(maskPath), break; end
            end

            if isempty(maskPath)
                continue;
            end

            % Check if a dedicated segmentation image exists, otherwise use imgPath
            imgFileToRead = '';
            if ~isnan(idNum)
                candImgFiles = {
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '1. Original Images', 'a. Training Set', sprintf('IDRiD_%02d.jpg', idNum)), ...
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '1. Original Images', 'b. Testing Set', sprintf('IDRiD_%02d.jpg', idNum)), ...
                    imgPath
                };
                for cif = 1:length(candImgFiles)
                    if isfile(candImgFiles{cif})
                        imgFileToRead = candImgFiles{cif};
                        break;
                    end
                end
            elseif isfile(imgPath)
                imgFileToRead = imgPath;
            end

            if isempty(imgFileToRead)
                continue;
            end

            img = imread(imgFileToRead);
            if size(img, 3) == 4
                img = img(:,:,1:3);
            elseif size(img, 3) == 1
                img = repmat(img, [1 1 3]);
            end
            img = imresize(img, cfg.imageSize(1:2));

            mask = imread(maskPath);
            if size(mask, 3) == 3
                mask = rgb2gray(mask);
            elseif size(mask, 3) == 4
                mask = rgb2gray(mask(:,:,1:3));
            elseif size(mask, 3) > 1
                mask = mask(:,:,1);
            end
            mask = imresize(double(mask), cfg.imageSize(1:2)) > 0;

            % Extract positive patches (from lesion pixels)
            [rows, cols] = find(mask);
            half = floor(patchSize / 2);
            for p = 1:min(20, length(rows))
                r = rows(p); c = cols(p);
                r1 = max(1, r-half(1)); r2 = min(cfg.imageSize(1), r+half(1));
                c1 = max(1, c-half(2)); c2 = min(cfg.imageSize(2), c+half(2));
                patch = img(r1:r2, c1:c2, :);
                if isequal(size(patch), [patchSize(1)+1, patchSize(2)+1, 3]) || ...
                   isequal(size(patch), [patchSize(1), patchSize(2), 3])
                    posPatches{end+1} = imresize(patch, patchSize);
                end
            end

            % Extract negative patches (from non-lesion foreground areas)
            [rowsN, colsN] = find(~mask & (rgb2gray(img) > 20));
            if ~isempty(rowsN)
                shuffleIdx = randperm(length(rowsN), min(20, length(rowsN)));
                for p = 1:length(shuffleIdx)
                    r = rowsN(shuffleIdx(p)); c = colsN(shuffleIdx(p));
                    r1 = max(1, r-half(1)); r2 = min(cfg.imageSize(1), r+half(1));
                    c1 = max(1, c-half(2)); c2 = min(cfg.imageSize(2), c+half(2));
                    patch = img(r1:r2, c1:c2, :);
                    if isequal(size(patch), [patchSize(1)+1, patchSize(2)+1, 3]) || ...
                       isequal(size(patch), [patchSize(1), patchSize(2), 3])
                        negPatches{end+1} = imresize(patch, patchSize);
                    end
                end
            end
        end

        % Fallback: If posPatches is empty, scan A. Segmentation folder directly
        if isempty(posPatches)
            for s = 1:length(subfolders)
                sub = subfolders{s};
                segDirs = {
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', sub), ...
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '2. All Segmentation Groundtruths', 'b. Testing Set', sub)
                };
                imgDirs = {
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '1. Original Images', 'a. Training Set'), ...
                    fullfile(cfg.paths.rawIDRiD, 'A. Segmentation', '1. Original Images', 'b. Testing Set')
                };
                for sd = 1:length(segDirs)
                    if isfolder(segDirs{sd})
                        tifs = dir(fullfile(segDirs{sd}, '*.tif'));
                        for f = 1:length(tifs)
                            maskPath = fullfile(segDirs{sd}, tifs(f).name);
                            [~, baseName, ~] = fileparts(tifs(f).name);
                            baseNameClean = regexprep(baseName, ['_' lType '$'], '');
                            candImg = fullfile(imgDirs{sd}, [baseNameClean, '.jpg']);
                            if isfile(candImg)
                                img = imread(candImg);
                                if size(img, 3) == 4
                                    img = img(:,:,1:3);
                                elseif size(img, 3) == 1
                                    img = repmat(img, [1 1 3]);
                                end
                                img = imresize(img, cfg.imageSize(1:2));
                                mask = imread(maskPath);
                                if size(mask, 3) == 3
                                    mask = rgb2gray(mask);
                                elseif size(mask, 3) == 4
                                    mask = rgb2gray(mask(:,:,1:3));
                                elseif size(mask, 3) > 1
                                    mask = mask(:,:,1);
                                end
                                mask = imresize(double(mask), cfg.imageSize(1:2)) > 0;
                                
                                [rows, cols] = find(mask);
                                half = floor(patchSize / 2);
                                for p = 1:min(20, length(rows))
                                    r = rows(p); c = cols(p);
                                    r1 = max(1, r-half(1)); r2 = min(cfg.imageSize(1), r+half(1));
                                    c1 = max(1, c-half(2)); c2 = min(cfg.imageSize(2), c+half(2));
                                    patch = img(r1:r2, c1:c2, :);
                                    if isequal(size(patch), [patchSize(1)+1, patchSize(2)+1, 3]) || ...
                                       isequal(size(patch), [patchSize(1), patchSize(2), 3])
                                        posPatches{end+1} = imresize(patch, patchSize);
                                    end
                                end
                                
                                [rowsN, colsN] = find(~mask & (rgb2gray(img) > 20));
                                if ~isempty(rowsN)
                                    shuffleIdx = randperm(length(rowsN), min(20, length(rowsN)));
                                    for p = 1:length(shuffleIdx)
                                        r = rowsN(shuffleIdx(p)); c = colsN(shuffleIdx(p));
                                        r1 = max(1, r-half(1)); r2 = min(cfg.imageSize(1), r+half(1));
                                        c1 = max(1, c-half(2)); c2 = min(cfg.imageSize(2), c+half(2));
                                        patch = img(r1:r2, c1:c2, :);
                                        if isequal(size(patch), [patchSize(1)+1, patchSize(2)+1, 3]) || ...
                                           isequal(size(patch), [patchSize(1), patchSize(2), 3])
                                            negPatches{end+1} = imresize(patch, patchSize);
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if ~isempty(posPatches), break; end
            end
        end

        if isempty(posPatches) || isempty(negPatches)
            warning('Insufficient patches for %s. Skipping.', lType);
            continue;
        end

        % Build patch dataset
        allPatches = cat(4, cat(4, posPatches{:}), cat(4, negPatches{:}));
        allLabels = categorical([ones(length(posPatches),1); zeros(length(negPatches),1)]);
        
        % Small patch CNN layers
        patchLayers = [
            imageInputLayer([patchSize 3])
            convolution2dLayer(3, 16, 'Padding', 'same')
            reluLayer()
            maxPooling2dLayer(2, 'Stride', 2)
            convolution2dLayer(3, 32, 'Padding', 'same')
            reluLayer()
            maxPooling2dLayer(2, 'Stride', 2)
            fullyConnectedLayer(64)
            reluLayer()
            dropoutLayer(0.5)
            fullyConnectedLayer(2)
            softmaxLayer()
            classificationLayer()
        ];

        try
            gpu = gpuDevice();
            execEnv = 'gpu';
        catch
            execEnv = 'cpu';
        end

        opts = trainingOptions('adam', ...
            'ExecutionEnvironment', execEnv, ...
            'MaxEpochs', 15, ...
            'MiniBatchSize', 32, ...
            'Verbose', true, ...
            'Plots', 'none');

        disp(['Training patch CNN for: ', lType]);
        net = trainNetwork(allPatches, allLabels, patchLayers, opts);
        lesionClassifiers.(lType) = net;

        fprintf('Classifier training complete for %s (%d positive, %d negative patches).\n', ...
            lType, length(posPatches), length(negPatches));
    end

    save(fullfile(modelDir, 'lesionClassifiers.mat'), 'lesionClassifiers');
    disp('Saved models/lesionClassifiers.mat successfully.');
end
