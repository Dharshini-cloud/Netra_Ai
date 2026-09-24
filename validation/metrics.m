function m = metrics(trueLabels, predLabels, predScores, referableGrade)
% METRICS Shared sensitivity/specificity/accuracy/Dice/AUC computation utilities.
% Returns a comprehensive metrics struct for both multi-class and binary (referable) tasks.
%
% Inputs:
%   trueLabels    - Nx1 numeric true ICDR grades (0-4)
%   predLabels    - Nx1 numeric predicted ICDR grades (0-4)
%   predScores    - NxC matrix of raw class probabilities (C = number of classes)
%   referableGrade - Grade threshold for binary referable task (default: 2)
%
% Output:
%   m - struct with fields: accuracy, confMat, sensitivity, specificity,
%       f1, kappa, referableAUC, referableSens, referableSpec, dicePerClass

    if nargin < 4; referableGrade = 2; end

    cfg = config();
    numClasses = length(cfg.classLabels);
    N = length(trueLabels);

    % ---- Multi-class metrics ----
    m.accuracy = sum(predLabels == trueLabels) / N;

    % Confusion matrix (row=true, col=predicted)
    m.confMat = confusionmat(trueLabels, predLabels, 'Order', cfg.classLabels);

    % Per-class precision, recall, F1
    m.sensitivity = zeros(numClasses, 1);  % recall per class
    m.specificity = zeros(numClasses, 1);
    m.precision   = zeros(numClasses, 1);
    m.f1          = zeros(numClasses, 1);
    m.dicePerClass = zeros(numClasses, 1);

    for ci = 1:numClasses
        grade = cfg.classLabels(ci);
        TP = sum(trueLabels == grade & predLabels == grade);
        FP = sum(trueLabels ~= grade & predLabels == grade);
        FN = sum(trueLabels == grade & predLabels ~= grade);
        TN = sum(trueLabels ~= grade & predLabels ~= grade);

        m.sensitivity(ci) = TP / max(TP + FN, 1);
        m.specificity(ci) = TN / max(TN + FP, 1);
        m.precision(ci)   = TP / max(TP + FP, 1);
        m.f1(ci)          = 2 * TP / max(2*TP + FP + FN, 1);
        m.dicePerClass(ci) = m.f1(ci);  % Dice = F1 in binary per-class context
    end

    m.macroF1 = mean(m.f1);
    m.macroSensitivity = mean(m.sensitivity);

    % Cohen's Kappa
    po = m.accuracy;
    pe = sum((sum(m.confMat, 1)/N) .* (sum(m.confMat, 2)'/N));
    m.kappa = (po - pe) / max(1 - pe, eps);

    % ---- Binary referable-DR metrics ----
    referableTrue  = trueLabels  >= referableGrade;
    referablePred  = predLabels  >= referableGrade;

    TP_r = sum(referableTrue & referablePred);
    FP_r = sum(~referableTrue & referablePred);
    FN_r = sum(referableTrue & ~referablePred);
    TN_r = sum(~referableTrue & ~referablePred);

    m.referableSens = TP_r / max(TP_r + FN_r, 1);
    m.referableSpec = TN_r / max(TN_r + FP_r, 1);
    m.referablePPV  = TP_r / max(TP_r + FP_r, 1);

    % AUC
    if nargin >= 3 && ~isempty(predScores)
        referableScore = sum(predScores(:, referableGrade+1:end), 2);
        [~, ~, ~, m.referableAUC] = perfcurve(referableTrue, referableScore, true);
    else
        m.referableAUC = NaN;
    end

    % ---- Print summary ----
    fprintf('\n===== Metrics Summary =====\n');
    fprintf('5-Class Accuracy:     %.2f%%\n', m.accuracy * 100);
    fprintf('Cohen''s Kappa:        %.4f\n', m.kappa);
    fprintf('Macro F1:             %.4f\n', m.macroF1);
    fprintf('Referable Sens:       %.2f%%\n', m.referableSens * 100);
    fprintf('Referable Spec:       %.2f%%\n', m.referableSpec * 100);
    fprintf('Referable AUC:        %.4f\n', m.referableAUC);
    fprintf('===========================\n\n');
end
