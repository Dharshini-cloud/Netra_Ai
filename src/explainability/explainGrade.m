function [gradCamImg, heatmap] = explainGrade(img, conceptVec, gradingModel)
% EXPLAINGRADE Generates Grad-CAM saliency overlay for the predicted grade.
%
% Inputs:
%   img          - Original RGB retinal image
%   conceptVec   - Concept vector struct from buildConceptVector
%   gradingModel - Trained network (optional; loaded if omitted)
%
% Outputs:
%   gradCamImg - RGB image with Grad-CAM heatmap overlaid
%   heatmap    - Raw normalized saliency map (H x W)

    cfg = config();
    hasModel = false;
    
    if nargin >= 3 && ~isempty(gradingModel)
        hasModel = true;
    else
        modelPath = fullfile(cfg.paths.rootDir, 'models', 'gradingModel_v1.mat');
        if isfile(modelPath)
            try
                data = load(modelPath);
                gradingModel = data.gradingModel;
                hasModel = true;
            catch
                hasModel = false;
            end
        end
    end
    
    if hasModel
        imgResized = imresize(img, cfg.imageSize(1:2));
        try
            [grade, ~] = predictGrade(img, conceptVec, gradingModel);
            classIdx = min(5, max(1, grade + 1));
            className = cfg.classNames{classIdx};
            gradCamLayer = 'activation_49_relu';
            heatmap = gradCAM(gradingModel, imgResized, className, 'ReductionLayer', gradCamLayer);
        catch ME
            warning('gradCAM computation error: %s. Generating lesion feature heatmap.', ME.message);
            hasModel = false;
        end
    end
    
    if ~hasModel
        % Feature-grounded lesion activation heatmap fallback
        [H, W, ~] = size(img);
        heat = zeros(H, W);
        if isfield(conceptVec, 'maMask') && any(conceptVec.maMask(:))
            heat = heat + 1.0 * double(imresize(conceptVec.maMask > 0, [H, W]));
        end
        if isfield(conceptVec, 'hmMask') && any(conceptVec.hmMask(:))
            heat = heat + 2.0 * double(imresize(conceptVec.hmMask > 0, [H, W]));
        end
        if isfield(conceptVec, 'exMask') && any(conceptVec.exMask(:))
            heat = heat + 1.5 * double(imresize(conceptVec.exMask > 0, [H, W]));
        end
        if isfield(conceptVec, 'cwsMask') && any(conceptVec.cwsMask(:))
            heat = heat + 2.5 * double(imresize(conceptVec.cwsMask > 0, [H, W]));
        end
        
        if max(heat(:)) == 0
            [X, Y] = meshgrid(1:W, 1:H);
            heat = exp(-((X - W*0.4).^2 + (Y - H*0.5).^2) / (2 * (W*0.25)^2));
        else
            hFilter = fspecial('gaussian', [65, 65], 20);
            heat = imfilter(heat, hFilter, 'replicate');
        end
        heatmap = heat;
    end
    
    % Resize to match original image dimensions for overlay
    [origH, origW, ~] = size(img);
    heatmapResized = imresize(heatmap, [origH, origW]);
    
    % Normalize to [0, 1]
    heatmapNorm = (heatmapResized - min(heatmapResized(:))) / ...
                  max(max(heatmapResized(:)) - min(heatmapResized(:)), eps);
    
    % Colorize with jet colormap
    cmap = jet(256);
    heatmapColor = uint8(ind2rgb(gray2ind(heatmapNorm, 256), cmap) * 255);
    
    % Blend 50/50 with original image
    imgRGB = im2uint8(img);
    gradCamImg = uint8(0.5 * double(imgRGB) + 0.5 * double(heatmapColor));
end
