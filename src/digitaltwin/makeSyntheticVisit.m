function [syntheticImg, syntheticConcept] = makeSyntheticVisit(baseImg, baseConcept, numNewMA, numNewHM)
% MAKESYNTHETICVISIT Generates a synthetic "later visit" by adding synthetic lesions.
% Used for demo and testing of the digital twin comparison pipeline.
%
% Inputs:
%   baseImg      - RGB image from the "baseline" visit
%   baseConcept  - Concept struct from the baseline visit
%   numNewMA     - Number of synthetic microaneurysms to add (default: 3)
%   numNewHM     - Number of synthetic haemorrhages to add (default: 1)
%
% Outputs:
%   syntheticImg     - Modified RGB image with synthetic lesions painted in
%   syntheticConcept - Updated concept struct for the synthetic visit

    if nargin < 3; numNewMA = 3; end
    if nargin < 4; numNewHM = 1; end

    syntheticImg = im2double(baseImg);
    [rows, cols, ~] = size(syntheticImg);

    % Only place lesions within the retinal FOV (not background)
    grayBase = rgb2gray(syntheticImg);
    fovMask = grayBase > 0.05;
    [fovRows, fovCols] = find(fovMask);

    rng(42); % reproducibility for demo

    % --- Synthetic Microaneurysms ---
    % Small (3-6px radius) dark circles mimicking dot haemorrhages/MAs
    for i = 1:numNewMA
        % Pick a random FOV location away from the OD mask
        idx = randi(length(fovRows));
        cy = fovRows(idx); cx = fovCols(idx);

        % Skip if too close to OD
        if isfield(baseConcept, 'odMask') && ~isempty(baseConcept.odMask) && baseConcept.odMask(cy, cx); continue; end

        r = randi([3, 6]);
        [X, Y] = meshgrid(max(1,cx-r):min(cols,cx+r), max(1,cy-r):min(rows,cy+r));
        circleMask = ((X-cx).^2 + (Y-cy).^2) <= r^2;

        for ch = 1:3
            slice = syntheticImg(max(1,cy-r):min(rows,cy+r), max(1,cx-r):min(cols,cx+r), ch);
            slice(circleMask) = slice(circleMask) * 0.35; % darken the region
            syntheticImg(max(1,cy-r):min(rows,cy+r), max(1,cx-r):min(cols,cx+r), ch) = slice;
        end
    end

    % --- Synthetic Haemorrhages ---
    % Medium (8-15px radius) dark blot shapes
    for i = 1:numNewHM
        idx = randi(length(fovRows));
        cy = fovRows(idx); cx = fovCols(idx);
        if isfield(baseConcept, 'odMask') && ~isempty(baseConcept.odMask) && baseConcept.odMask(cy, cx); continue; end

        r = randi([8, 15]);
        % Slightly elliptical for realism
        rxScale = 1 + 0.3 * (rand() - 0.5);
        ryScale = 1 + 0.3 * (rand() - 0.5);

        [X, Y] = meshgrid(max(1,cx-r):min(cols,cx+r), max(1,cy-r):min(rows,cy+r));
        ellipseMask = (((X-cx)/(r*rxScale)).^2 + ((Y-cy)/(r*ryScale)).^2) <= 1;

        for ch = 1:3
            slice = syntheticImg(max(1,cy-r):min(rows,cy+r), max(1,cx-r):min(cols,cx+r), ch);
            slice(ellipseMask) = slice(ellipseMask) * 0.20;
            syntheticImg(max(1,cy-r):min(rows,cy+r), max(1,cx-r):min(cols,cx+r), ch) = slice;
        end
    end

    syntheticImg = im2uint8(syntheticImg);

    % --- Update concept vector for the synthetic image ---
    syntheticConcept = buildConceptVector(syntheticImg);

    fprintf('[Synthetic Visit] Added %d MA(s), %d HM(s). New MA count: %d â†’ %d, HM: %d â†’ %d\n', ...
        numNewMA, numNewHM, ...
        baseConcept.maCount, syntheticConcept.maCount, ...
        baseConcept.hmCount, syntheticConcept.hmCount);
end
