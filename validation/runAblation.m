function ablation = runAblation()
% RUNABLATION Pipeline ablation study.
% Tests three configurations on the identical held-out test set:
%   1. Full pipeline (quality gate + concept bottleneck + grading)
%   2. Pipeline minus quality gate (all images pass directly to segmentation)
%   3. Pipeline minus concept bottleneck (image embedding only, no concept features)
% Quantifies the contribution of each module independently.

    cfg = config();
    addpath(genpath('src'));

    testSplit   = load(fullfile(cfg.paths.splits, 'test_index.mat')).test_index;
    testGradable = testSplit(~isnan(testSplit.grade), :);

    pipelineModelPath = fullfile(cfg.paths.models, 'gradingModel_v1.mat');
    if ~isfile(pipelineModelPath)
        error('Pipeline model not found. Run trainGradingModel first.');
    end
    pipelineModel = load(pipelineModelPath).gradingModel;

    n = height(testGradable);
    trueLabels = testGradable.grade;

    ablation = struct();

    % --- Config 1: FULL PIPELINE ---
    disp('Ablation [1/3]: Full pipeline...');
    predFull   = zeros(n, 1);
    scoresFull = zeros(n, length(cfg.classLabels));
    qualityRejectCount = 0;

    for i = 1:n
        imgPath = fullfile(cfg.paths.processedImages, ...
            sprintf('%s_%s.png', char(testGradable.sourceDataset(i)), char(testGradable.patientID(i))));
        if ~isfile(imgPath); continue; end
        img = imread(imgPath);

        % Quality gate active
        [status, ~] = assessQuality(img);
        if status == "REJECTED_RECAPTURE"
            qualityRejectCount = qualityRejectCount + 1;
            predFull(i) = 0; % treated as no-DR if rejected
            continue;
        elseif status == "BORDERLINE_ENHANCED"
            img = enhanceImage(img);
        end

        cv = buildConceptVector(img);
        [predFull(i), scoresFull(i,:)] = predictGrade(img, cv, pipelineModel);
    end
    ablation.full = metrics(trueLabels, predFull, scoresFull);
    ablation.full.qualityRejectCount = qualityRejectCount;
    fprintf('Quality gate rejected %d images.\n', qualityRejectCount);

    % --- Config 2: MINUS QUALITY GATE ---
    disp('Ablation [2/3]: No quality gate (all images passed through)...');
    predNoQuality   = zeros(n, 1);
    scoresNoQuality = zeros(n, length(cfg.classLabels));

    for i = 1:n
        imgPath = fullfile(cfg.paths.processedImages, ...
            sprintf('%s_%s.png', char(testGradable.sourceDataset(i)), char(testGradable.patientID(i))));
        if ~isfile(imgPath); continue; end
        img = imread(imgPath);
        % No quality gate — images pass directly
        cv = buildConceptVector(img);
        [predNoQuality(i), scoresNoQuality(i,:)] = predictGrade(img, cv, pipelineModel);
    end
    ablation.noQualityGate = metrics(trueLabels, predNoQuality, scoresNoQuality);

    % --- Config 3: MINUS CONCEPT BOTTLENECK ---
    disp('Ablation [3/3]: No concept bottleneck (image embedding only)...');
    predNoConcept   = zeros(n, 1);
    scoresNoConcept = zeros(n, length(cfg.classLabels));

    for i = 1:n
        imgPath = fullfile(cfg.paths.processedImages, ...
            sprintf('%s_%s.png', char(testGradable.sourceDataset(i)), char(testGradable.patientID(i))));
        if ~isfile(imgPath); continue; end
        img = imread(imgPath);

        % Pass zero concept vector — effectively disables the concept branch
        zeroConcept = zeros(1, 7);
        [predNoConcept(i), scoresNoConcept(i,:)] = predictGrade(img, zeroConcept, pipelineModel);
    end
    ablation.noConceptBottleneck = metrics(trueLabels, predNoConcept, scoresNoConcept);

    % --- Print ablation table ---
    fprintf('\n====== Ablation Study Results ======\n');
    fprintf('%-35s  %-10s  %-10s  %-10s\n', 'Metric', 'Full', 'No QGate', 'No CBN');
    fprintf('%s\n', repmat('-', 1, 68));
    ablPrint = @(name, v1, v2, v3) fprintf('%-35s  %-10s  %-10s  %-10s\n', name, ...
        sprintf('%.2f%%', v1*100), sprintf('%.2f%%', v2*100), sprintf('%.2f%%', v3*100));
    ablPrint('5-Class Accuracy', ...
        ablation.full.accuracy, ablation.noQualityGate.accuracy, ablation.noConceptBottleneck.accuracy);
    ablPrint('Referable Sensitivity', ...
        ablation.full.referableSens, ablation.noQualityGate.referableSens, ablation.noConceptBottleneck.referableSens);
    ablPrint('Macro F1', ...
        ablation.full.macroF1, ablation.noQualityGate.macroF1, ablation.noConceptBottleneck.macroF1);

    % Save
    validationDir = cfg.paths.validation;
    if ~isfolder(validationDir); mkdir(validationDir); end
    save(fullfile(validationDir, 'results_summary.mat'), 'ablation', '-append');
    disp('Ablation results appended to results_summary.mat');
end
