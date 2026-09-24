function results = runBenchmark()
% RUNBENCHMARK Full pipeline vs. plain-CNN baseline comparison on identical test data.
% Evaluates both models on the held-out test set and on Messidor-2 external test.
% Saves side-by-side results to validation/results_summary.mat

    cfg = config();
    addpath(genpath('src'));

    disp('===== Netra AI Benchmark =====');

    % Load test splits
    testSplit    = load(fullfile(cfg.paths.splits, 'test_index.mat')).test_index;
    externalTest = load(fullfile(cfg.paths.splits, 'external_test_index.mat')).external_test_index;

    testGradable     = testSplit(~isnan(testSplit.grade), :);
    externalGradable = externalTest(~isnan(externalTest.grade), :);

    % Load models
    pipelineModelPath = fullfile(cfg.paths.models, 'gradingModel_v1.mat');
    baselineModelPath = fullfile(cfg.paths.models, 'baselineModel.mat');

    if ~isfile(pipelineModelPath)
        error('Pipeline model not found. Run trainGradingModel first.');
    end
    pipelineModel = load(pipelineModelPath).gradingModel;

    hasBaseline = isfile(baselineModelPath);
    if hasBaseline
        baselineModel = load(baselineModelPath).baselineModel;
    else
        warning('Baseline model not found. Run trainBaseline (see runBenchmark comments) to generate it.');
    end

    results = struct();

    % --- Helper: run inference on a split ---
    function [trueL, predL, scores] = runInference(dataTable, model, useConceptVec)
        n = height(dataTable);
        trueL  = dataTable.grade;
        predL  = zeros(n, 1);
        scores = zeros(n, length(cfg.classLabels));

        for i = 1:n
            imgPath = fullfile(cfg.paths.processedImages, ...
                sprintf('%s_%s.png', char(dataTable.sourceDataset(i)), char(dataTable.patientID(i))));
            if ~isfile(imgPath); continue; end
            img = imread(imgPath);

            if useConceptVec
                cv = buildConceptVector(img);
                [predL(i), scores(i,:)] = predictGrade(img, cv, model);
            else
                % Baseline: image only, plain classify
                imgR = imresize(img, cfg.imageSize(1:2));
                [predCat, sc] = classify(model, imgR);
                scores(i,:) = sc;
                predL(i) = cfg.classLabels(predCat == categorical(cfg.classNames));
            end
        end
    end

    % --- Pipeline evaluation ---
    disp('Evaluating Netra AI pipeline on held-out test set...');
    [trueL, predL, scores] = runInference(testGradable, pipelineModel, true);
    results.pipeline.test = metrics(trueL, predL, scores);

    disp('Evaluating Netra AI pipeline on Messidor-2 (external)...');
    [trueLE, predLE, scoresE] = runInference(externalGradable, pipelineModel, true);
    results.pipeline.external = metrics(trueLE, predLE, scoresE);

    % --- Baseline evaluation ---
    if hasBaseline
        disp('Evaluating baseline CNN on held-out test set...');
        [trueL_b, predL_b, scores_b] = runInference(testGradable, baselineModel, false);
        results.baseline.test = metrics(trueL_b, predL_b, scores_b);

        disp('Evaluating baseline CNN on Messidor-2 (external)...');
        [trueLE_b, predLE_b, scoresE_b] = runInference(externalGradable, baselineModel, false);
        results.baseline.external = metrics(trueLE_b, predLE_b, scoresE_b);
    end

    % Store centralised accuracy for federated comparison
    results.centralizedAccuracy = results.pipeline.test.accuracy;

    % --- Print comparison table ---
    fprintf('\n====== Benchmark Comparison ======\n');
    fprintf('%-30s  %-12s  %-12s\n', 'Metric', 'Netra AI', 'Baseline');
    fprintf('%s\n', repmat('-', 1, 56));
    printRow = @(name, pVal, bVal) fprintf('%-30s  %-12s  %-12s\n', name, ...
        sprintf('%.2f%%', pVal*100), sprintf('%.2f%%', bVal*100));

    if hasBaseline
        printRow('5-Class Accuracy (test)',   results.pipeline.test.accuracy, results.baseline.test.accuracy);
        printRow('Referable Sensitivity',     results.pipeline.test.referableSens, results.baseline.test.referableSens);
        printRow('Referable Specificity',     results.pipeline.test.referableSpec, results.baseline.test.referableSpec);
        printRow('Macro F1',                  results.pipeline.test.macroF1, results.baseline.test.macroF1);
        printRow('External Test Accuracy',    results.pipeline.external.accuracy, results.baseline.external.accuracy);
    else
        fprintf('Pipeline 5-Class Accuracy:    %.2f%%\n', results.pipeline.test.accuracy*100);
        fprintf('Pipeline Referable Sens:      %.2f%%\n', results.pipeline.test.referableSens*100);
        fprintf('Pipeline Referable Spec:      %.2f%%\n', results.pipeline.test.referableSpec*100);
        fprintf('Pipeline External Accuracy:   %.2f%%\n', results.pipeline.external.accuracy*100);
    end

    % Save
    validationDir = cfg.paths.validation;
    if ~isfolder(validationDir); mkdir(validationDir); end
    save(fullfile(validationDir, 'results_summary.mat'), 'results');
    disp('Saved results_summary.mat to validation dir.');
end
