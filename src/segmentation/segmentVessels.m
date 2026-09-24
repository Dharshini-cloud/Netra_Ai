function vesselMask = segmentVessels(img)
% SEGMENTVESSELS Segments retinal vessels.
% Uses classical Frangi (fibermetric) filtering as the base layer unconditionally,
% and refines with U-Net (dlnetwork or DAGNetwork) when models/vesselNet.mat exists.

    % Load config for model paths
    cfg = config();
    
    % Ensure image is double for filtering
    imgD = im2double(img);
    
    % Green channel has best vessel contrast (blood absorbs green light)
    greenChannel = imgD(:,:,2);
    
    % --- BASE LAYER: Classical Filtering ---
    % Invert green channel because vessels are darker than background
    invGreen = imcomplement(greenChannel);
    
    % Apply fibermetric (Hessian-based vessel enhancement)
    % Thicknesses 2 to 8 pixels cover most retinal vessels at 512x512
    baseVesselProb = fibermetric(invGreen, [2 4 6 8], 'ObjectPolarity', 'dark');
    
    % Binarize (threshold depends on contrast, 0.1 is standard for fibermetric)
    baseMask = baseVesselProb > 0.1; 
    
    % Clean up small noise artifacts
    baseMask = bwareaopen(baseMask, 30);
    
    % --- REFINEMENT LAYER: U-Net ---
    modelPath = fullfile(cfg.paths.models, 'vesselNet.mat');
    if isfile(modelPath)
        persistent vesselNet;
        if isempty(vesselNet)
            data = load(modelPath);
            vesselNet = data.vesselNet;
        end
        
        try
            origH = size(img, 1);
            origW = size(img, 2);
            targetH = cfg.imageSize(1);
            targetW = cfg.imageSize(2);
            
            % Ensure 3 channels
            imgRGB = img;
            if size(imgRGB, 3) == 1
                imgRGB = repmat(imgRGB, [1 1 3]);
            end
            
            % Resize and normalize to [0, 1] single
            imgScaled = im2single(imresize(imgRGB, [targetH, targetW]));
            
            if isa(vesselNet, 'dlnetwork')
                dlX = dlarray(imgScaled, 'SSCB');
                scores = predict(vesselNet, dlX);
                scoresMat = extractdata(scores);
                [~, predIdx] = max(scoresMat, [], 3);
                rawMask = (predIdx == 2);
            else
                % DAGNetwork or SeriesNetwork fallback
                C = semanticseg(imgScaled, vesselNet);
                rawMask = (string(C) == "Vessel");
            end
            
            % Resize back to original dimensions
            unetMask = imresize(rawMask, [origH, origW], 'nearest');
            
            % Combine: U-Net is generally more accurate, but classical catches fine capillaries
            vesselMask = unetMask | baseMask;
        catch ME
            warning('U-Net inference error: %s. Falling back to classical mask entirely.', ME.message);
            vesselMask = baseMask;
        end
    else
        % Fallback: strictly classical if model isn't trained yet
        vesselMask = baseMask;
    end
end