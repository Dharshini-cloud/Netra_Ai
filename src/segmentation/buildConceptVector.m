function conceptVec = buildConceptVector(img)
% BUILDCONCEPTVECTOR Integration function: calls all segmentation modules
% and assembles outputs into the structured concept vector for Phase 4 (grading).
%
% Input:  img         - RGB retinal image
% Output: conceptVec  - struct with fields:
%   maCount              - int, number of microaneurysm regions
%   hmCount              - int, number of haemorrhage regions
%   hmType               - cell array of 'dot'|'blot'|'flame' per HM component
%   exArea               - double, total pixel area of hard exudates
%   cwsCount             - int, number of cotton-wool spot regions
%   nvdFlag              - logical, NVD detected
%   nveFlag              - logical, NVE detected
%   vesselAbnormalityScore - double, combined NVD+NVE score
%   vesselMask           - binary mask (for downstream use / visualisation)
%   odMask               - binary mask (for downstream use / visualisation)
%   foveaCoord           - [x,y]

    % ---- Stage 1: Quality gate is applied upstream; assume img is accepted/enhanced ----

    % ---- Stage 2a: Vessel segmentation (classical + optional U-Net) ----
    vesselMask = segmentVessels(img);

    % ---- Stage 2b: Optic Disc and Fovea ----
    [odMask, foveaCoord] = segmentOpticDiscFovea(img, vesselMask);

    % ---- Stage 2c: Lesion detection (masks built on top of vessel/OD knowledge) ----
    lesions = segmentLesions(img, vesselMask, odMask);

    % ---- Stage 2d: Neovascularization (both NVD and NVE passes) ----
    nvResult = detectNeovascularization(vesselMask, odMask, foveaCoord);

    % ---- Assemble concept vector ----
    conceptVec.maCount  = sum(bwconncomp(lesions.maMask).NumObjects);
    conceptVec.hmCount  = sum(bwconncomp(lesions.hmMask).NumObjects);
    conceptVec.hmType   = lesions.hmType;
    conceptVec.exArea   = sum(lesions.exMask(:));
    conceptVec.cwsCount = bwconncomp(lesions.cwsMask).NumObjects;
    
    conceptVec.nvdFlag  = nvResult.nvdFlag;
    conceptVec.nveFlag  = nvResult.nveFlag;
    conceptVec.nvFlag   = nvResult.nvdFlag || nvResult.nveFlag;    % convenience combined flag
    
    % Raw NV density scores needed by predictGrade's concept flattening (7-dim vector)
    conceptVec.nvdScore = nvResult.nvdScore;
    conceptVec.nveScore = nvResult.nveScore;
    
    % Combined abnormality score: weighted sum of NVD and NVE individual scores
    conceptVec.vesselAbnormalityScore = 0.6 * nvResult.nvdScore + 0.4 * nvResult.nveScore;

    % Pass through raw masks for visualisation / report overlays
    conceptVec.maMask     = lesions.maMask;
    conceptVec.hmMask     = lesions.hmMask;
    conceptVec.exMask     = lesions.exMask;
    conceptVec.cwsMask    = lesions.cwsMask;
    conceptVec.vesselMask = vesselMask;
    conceptVec.odMask     = odMask;
    conceptVec.foveaCoord = foveaCoord;
    conceptVec.nveMap     = nvResult.nveMap;
    
    % Structured mask group for NetraApp and multi-overlay renderers
    conceptVec.masks = struct( ...
        'ma',      lesions.maMask, ...
        'hm',      lesions.hmMask, ...
        'ex',      lesions.exMask, ...
        'cws',     lesions.cwsMask, ...
        'vessels', vesselMask, ...
        'od',      odMask);
    
    fprintf(['Concept Vector Built — MA: %d | HM: %d | EX area: %d px | CWS: %d | ' ...
             'NVD: %d | NVE: %d | VesselScore: %.3f\n'], ...
             conceptVec.maCount, conceptVec.hmCount, conceptVec.exArea, conceptVec.cwsCount, ...
             conceptVec.nvdFlag, conceptVec.nveFlag, conceptVec.vesselAbnormalityScore);
end
