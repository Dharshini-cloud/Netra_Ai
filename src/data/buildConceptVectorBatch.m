function buildConceptVectorBatch()
% BUILDCONCEPTVECTORBATCH Runs buildConceptVector on every processed image
% and saves a structured concepts.mat for use in trainGradingModel.
%
% Output: data/processed/concepts.mat containing:
%   concepts.keys   - Nx1 cell array of "DATASET_PATIENTID" composite keys
%   concepts.matrix - Nx7 double feature matrix
%     Column order: [maCount, hmCount, exArea, cwsCount, nvFlag, nvdScore, nveScore]
%
% This script is the mandatory pre-step before trainGradingModel.

    cfg = config();
    addpath(genpath(fullfile(cfg.paths.rootDir, 'src')));

    % Load the full unified dataset index
    splitsDir = cfg.paths.splits;
    if ~isfile(fullfile(splitsDir, 'train_index.mat'))
        error('Splits not found. Run buildPatientSplits() first.');
    end

    train_idx    = load(fullfile(splitsDir, 'train_index.mat')).train_index;
    val_idx      = load(fullfile(splitsDir, 'val_index.mat')).val_index;
    test_idx     = load(fullfile(splitsDir, 'test_index.mat')).test_index;
    ext_idx      = load(fullfile(splitsDir, 'external_test_index.mat')).external_test_index;

    % Combine all splits for one big batch pass
    allData = [train_idx; val_idx; test_idx; ext_idx];
    N = height(allData);

    keys   = cell(N, 1);
    matrix = zeros(N, 7);

    fprintf('Building concept vectors for %d images...\n', N);
    failCount = 0;

    for i = 1:N
        ds  = char(allData.sourceDataset(i));
        pid = char(allData.patientID(i));
        imgPath = fullfile(cfg.paths.processedImages, sprintf('%s_%s.png', ds, pid));

        compositeKey = sprintf('%s_%s', ds, pid);
        keys{i} = compositeKey;

        if ~isfile(imgPath)
            failCount = failCount + 1;
            matrix(i, :) = zeros(1, 7);
            continue;
        end

        try
            img = imread(imgPath);
            cv  = buildConceptVector(img);

            % Extract 7-dim feature row in fixed column order
            matrix(i, :) = [
                double(cv.maCount), ...
                double(cv.hmCount), ...
                double(cv.exArea), ...
                double(cv.cwsCount), ...
                double(cv.nvFlag), ...
                double(cv.nvdScore), ...
                double(cv.nveScore)
            ];

            if mod(i, 50) == 0
                fprintf('  Progress: %d / %d (%.1f%%)...\n', i, N, 100*i/N);
            end
        catch ME
            warning('Failed on %s: %s', compositeKey, ME.message);
            failCount = failCount + 1;
            matrix(i, :) = zeros(1, 7);
        end
    end

    % Package and save
    concepts = struct();
    concepts.keys   = keys;
    concepts.matrix = matrix;

    outPath = fullfile(cfg.paths.processed, 'concepts.mat');
    if ~isfolder(cfg.paths.processed)
        mkdir(cfg.paths.processed);
    end
    save(outPath, 'concepts');

    fprintf('\nDone. %d concept vectors saved to:\n  %s\n', N - failCount, outPath);
    if failCount > 0
        fprintf('Warning: %d images were missing or failed — zero vectors used.\n', failCount);
    end
end
