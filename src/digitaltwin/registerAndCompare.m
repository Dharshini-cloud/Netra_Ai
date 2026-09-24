function progressReport = registerAndCompare(currentImg, currentConcept, patientID)
% REGISTERANDCOMPARE Aligns current image to most recent prior visit and diffs lesion masks.
% Uses imregtform with vessel-mask features as registration landmarks.
% Produces a structured progression report with new/resolved/persistent lesion flags.
%
% Inputs:
%   currentImg     - RGB image from current visit
%   currentConcept - Concept vector struct from current visit
%   patientID      - String patient identifier
%
% Output:
%   progressReport - struct with progression summary

    progressReport = struct();
    progressReport.patientID = char(patientID);
    progressReport.date = datestr(now);
    progressReport.hasPriorVisit = false;

    % Try to load the patient's most recent prior visit
    try
        patientRecord = twinStore('read', patientID);
    catch
        progressReport.summary = 'No prior records found. This is the baseline visit.';
        return;
    end

    if patientRecord.numVisits < 2
        progressReport.summary = 'Only one prior visit exists. No comparison possible yet.';
        progressReport.hasPriorVisit = false;
        return;
    end

    progressReport.hasPriorVisit = true;

    % Load the second-to-last visit (latest prior)
    priorVisit = patientRecord.visits{end - 1};
    priorConcept = priorVisit.conceptVec;

    % --- Image Registration ---
    % Load prior image
    if isfile(priorVisit.imagePath)
        priorImg = imread(priorVisit.imagePath);
    else
        warning('Prior image not found at: %s. Skipping spatial registration.', priorVisit.imagePath);
        priorImg = currentImg; % Fallback: assume aligned
    end

    cfg = config();
    currentImgR = imresize(currentImg, cfg.imageSize(1:2));
    priorImgR   = imresize(priorImg,   cfg.imageSize(1:2));

    % Use grayscale vessel-enhanced images as registration targets
    currentFixed = im2double(rgb2gray(currentImgR));
    priorMoving  = im2double(rgb2gray(priorImgR));

    % Rigid registration (rotation + translation only — appropriate for fundus)
    [optimizer, metric] = imregconfig('monomodal');
    optimizer.MaximumIterations = 100;
    try
        tform = imregtform(priorMoving, currentFixed, 'rigid', optimizer, metric);
        priorAlignedGray = imwarp(priorMoving, tform, 'OutputView', imref2d(size(currentFixed)));

        % Extract prior masks safely
        pMA  = getMaskSafely(priorConcept, 'maMask', 'ma', cfg.imageSize);
        pHM  = getMaskSafely(priorConcept, 'hmMask', 'hm', cfg.imageSize);
        pEX  = getMaskSafely(priorConcept, 'exMask', 'ex', cfg.imageSize);
        pCWS = getMaskSafely(priorConcept, 'cwsMask', 'cws', cfg.imageSize);
        
        refView = imref2d(size(currentFixed));
        priorMA  = warpMask(pMA,  tform, refView);
        priorHM  = warpMask(pHM,  tform, refView);
        priorEX  = warpMask(pEX,  tform, refView);
        priorCWS = warpMask(pCWS, tform, refView);
    catch ME
        warning('Image registration failed (%s). Comparing masks without spatial alignment.', ME.message);
        priorMA  = getMaskSafely(priorConcept, 'maMask', 'ma', cfg.imageSize);
        priorHM  = getMaskSafely(priorConcept, 'hmMask', 'hm', cfg.imageSize);
        priorEX  = getMaskSafely(priorConcept, 'exMask', 'ex', cfg.imageSize);
        priorCWS = getMaskSafely(priorConcept, 'cwsMask', 'cws', cfg.imageSize);
    end

    % --- Lesion Mask Differencing ---
    curMA  = getMaskSafely(currentConcept, 'maMask', 'ma', cfg.imageSize);
    curHM  = getMaskSafely(currentConcept, 'hmMask', 'hm', cfg.imageSize);
    curEX  = getMaskSafely(currentConcept, 'exMask', 'ex', cfg.imageSize);
    curCWS = getMaskSafely(currentConcept, 'cwsMask', 'cws', cfg.imageSize);

    newMA  = curMA  & ~priorMA;
    newHM  = curHM  & ~priorHM;
    newEX  = curEX  & ~priorEX;
    newCWS = curCWS & ~priorCWS;

    resolvedMA  = priorMA  & ~curMA;
    resolvedHM  = priorHM  & ~curHM;
    resolvedEX  = priorEX  & ~curEX;
    resolvedCWS = priorCWS & ~curCWS;

    % --- Grade delta ---
    priorGrade = priorVisit.grade;

    % --- Progression flag ---
    newLesionCount = bwconncomp(newMA).NumObjects + bwconncomp(newHM).NumObjects + ...
                     bwconncomp(newEX).NumObjects + bwconncomp(newCWS).NumObjects;
    resolvedCount  = bwconncomp(resolvedMA).NumObjects + bwconncomp(resolvedHM).NumObjects + ...
                     bwconncomp(resolvedEX).NumObjects + bwconncomp(resolvedCWS).NumObjects;

    progressionFlag = (newLesionCount > 0) || ...
                      (isfield(currentConcept, 'nvFlag') && isfield(priorConcept, 'nvFlag') && ...
                       currentConcept.nvFlag && ~priorConcept.nvFlag);

    % Trajectory assessment
    if progressionFlag
        trajectory = 'PROGRESSED';
    elseif resolvedCount > 0 && newLesionCount == 0
        trajectory = 'REGRESSED';
    else
        trajectory = 'STABLE';
    end

    % --- Package results ---
    progressReport.priorGrade      = priorGrade;
    progressReport.priorDate       = priorVisit.visitDate;
    progressReport.priorImg        = priorImg;
    progressReport.priorConcepts   = priorConcept;
    progressReport.hasPrior        = true;
    progressReport.hasPriorVisit   = true;
    progressReport.hasProgressed   = progressionFlag;
    progressReport.progressionFlag = progressionFlag;
    progressReport.trajectory      = trajectory;
    progressReport.newLesions      = struct('MA', bwconncomp(newMA).NumObjects, ...
                                           'HM', bwconncomp(newHM).NumObjects, ...
                                           'EX', bwconncomp(newEX).NumObjects, ...
                                           'CWS', bwconncomp(newCWS).NumObjects);
    progressReport.resolvedLesions = struct('MA', bwconncomp(resolvedMA).NumObjects, ...
                                            'HM', bwconncomp(resolvedHM).NumObjects, ...
                                            'EX', bwconncomp(resolvedEX).NumObjects, ...
                                            'CWS', bwconncomp(resolvedCWS).NumObjects);
    progressReport.newLesionCount  = newLesionCount;
    progressReport.resolvedCount   = resolvedCount;
    progressReport.nvdNew = isfield(currentConcept, 'nvdFlag') && isfield(priorConcept, 'nvdFlag') && ...
                            currentConcept.nvdFlag && ~priorConcept.nvdFlag;
    progressReport.nveNew = isfield(currentConcept, 'nveFlag') && isfield(priorConcept, 'nveFlag') && ...
                            currentConcept.nveFlag && ~priorConcept.nveFlag;

    % Difference masks for visualisation
    progressReport.newMask      = newMA | newHM | newEX | newCWS;
    progressReport.resolvedMask = resolvedMA | resolvedHM | resolvedEX | resolvedCWS;

    % Generate diffOverlay RGB visualization
    curRGB = im2double(imresize(currentImg, [512, 512]));
    newR = imresize(progressReport.newMask > 0, [512, 512], 'nearest');
    resR = imresize(progressReport.resolvedMask > 0, [512, 512], 'nearest');
    
    diffImg = curRGB;
    for c = 1:3
        chan = diffImg(:,:,c);
        % Resolved lesions in emerald green
        gColor = [0.15, 0.85, 0.35];
        chan(resR) = 0.35 * chan(resR) + 0.65 * gColor(c);
        % New lesions in vivid red
        rColor = [1.0, 0.15, 0.15];
        chan(newR) = 0.25 * chan(newR) + 0.75 * rColor(c);
        diffImg(:,:,c) = chan;
    end
    progressReport.diffOverlay = im2uint8(diffImg);

    % Human-readable summary
    progressReport.summary = sprintf(...
        'Compared to visit on %s (Grade %d): %d new lesion(s), %d resolved. Trajectory: %s.', ...
        priorVisit.visitDate, priorGrade, newLesionCount, resolvedCount, trajectory);

    disp(progressReport.summary);
end

function m = getMaskSafely(cStruct, field1, field2, sz)
    if isfield(cStruct, field1) && ~isempty(cStruct.(field1))
        m = logical(imresize(cStruct.(field1) > 0, sz(1:2), 'nearest'));
    elseif isfield(cStruct, 'masks') && isstruct(cStruct.masks) && isfield(cStruct.masks, field2) && ~isempty(cStruct.masks.(field2))
        m = logical(imresize(cStruct.masks.(field2) > 0, sz(1:2), 'nearest'));
    else
        m = false(sz(1:2));
    end
end

function s = yesno(v)
    if v; s = 'YES'; else; s = 'No'; end
end

function m = warpMask(mask, tform, refView)
% WARPMASK Applies a spatial transform (from imregtform) to a binary mask.
    if isempty(mask) || ~any(mask(:))
        m = false(refView.ImageSize);
        return;
    end
    warped = imwarp(double(mask), tform, 'OutputView', refView, 'Interp', 'nearest');
    m = logical(warped > 0.5);
end
