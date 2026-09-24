function [calibratedScores, temperature] = calibrateConfidence(rawScores, trueLabels)
% CALIBRATECONFIDENCE Fits temperature scaling to calibrate model confidence.
% Temperature scaling is a single-parameter post-hoc calibration method:
%   calibratedScore = softmax(logits / T)
% where T is fit by minimizing negative log-likelihood on the calibration set.
%
% Inputs:
%   rawScores  - NxC matrix of pre-softmax logits OR post-softmax probabilities
%   trueLabels - Nx1 categorical or numeric true class labels
% Outputs:
%   calibratedScores - NxC calibrated probability matrix
%   temperature      - Scalar temperature T (saved to models/temperature.mat)

    % Convert true labels to 1-indexed class indices
    if iscategorical(trueLabels)
        labelIdx = uint8(trueLabels);
    else
        cfg = config();
        % Map grade 0-4 to 1-5
        labelIdx = trueLabels + 1;
    end
    
    nSamples = size(rawScores, 1);
    
    % Convert scores to logit space if they are probabilities (sum to ~1)
    if all(abs(sum(rawScores, 2) - 1) < 1e-3)
        % Already probabilities — convert to logits via log (approximate)
        logits = log(rawScores + eps);
    else
        logits = rawScores;
    end
    
    % --- Optimize temperature T by minimizing NLL on the calibration set ---
    % NLL = -mean( log( softmax(logits/T)[true_class] ) )
    nllFn = @(T) negativLogLikelihood(logits, labelIdx, T);
    
    % Search over T in [0.1, 10]
    T0 = 1.0;
    options = optimset('Display', 'off', 'TolX', 1e-6);
    temperature = fminsearch(nllFn, T0, options);
    temperature = max(0.1, min(10.0, temperature)); % clamp to safe range
    
    fprintf('Calibrated temperature T = %.4f\n', temperature);
    
    % Apply temperature scaling
    calibratedLogits = logits / temperature;
    % Softmax
    expLogits = exp(calibratedLogits - max(calibratedLogits, [], 2));
    calibratedScores = expLogits ./ sum(expLogits, 2);
    
    % Save
    cfg = config();
    modelDir = cfg.paths.models;
    if ~isfolder(modelDir); mkdir(modelDir); end
    save(fullfile(modelDir, 'temperature.mat'), 'temperature');
    disp('Saved temperature.mat');
end

function nll = negativLogLikelihood(logits, labelIdx, T)
    scaledLogits = logits / T;
    expL = exp(scaledLogits - max(scaledLogits, [], 2));
    probs = expL ./ sum(expL, 2);
    nSamples = size(probs, 1);
    nll = 0;
    for i = 1:nSamples
        nll = nll - log(max(probs(i, labelIdx(i)), eps));
    end
    nll = nll / nSamples;
end
