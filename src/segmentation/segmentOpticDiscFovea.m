function [odMask, foveaCoord] = segmentOpticDiscFovea(img, vesselMask)
% SEGMENTOPTICDISCFOVEA Localizes Optic Disc and Fovea.
% Optic disc: brightest circular region.
% Fovea: darkest region at a specific geometric offset from the OD.
% Inputs:
%   img - RGB image
%   vesselMask - Binary mask of vessels (used to exclude vessels from OD detection)
% Outputs:
%   odMask - Binary mask of the Optic Disc
%   foveaCoord - [x, y] coordinates of the fovea

    imgD = im2double(img);
    grayImg = rgb2gray(imgD);
    [rows, cols] = size(grayImg);
    
    % --- 1. Optic Disc (OD) detection ---
    % Eliminate vessels so they don't disrupt OD intensity thresholding
    % We replace vessel pixels with the local background intensity (inpainting approximation via morph closing)
    se = strel('disk', 15);
    imgNoVessels = imclose(grayImg, se);
    
    % Find brightest regions
    % We use 99th percentile to adapt to different image illuminations
    threshold = prctile(imgNoVessels(imgNoVessels > 0.1), 99);
    odCandidates = imgNoVessels > threshold;
    odCandidates = bwareaopen(odCandidates, 100);
    
    % Find the most circular/compact component
    stats = regionprops(odCandidates, 'Area', 'Centroid', 'Eccentricity', 'EquivDiameter');
    
    if isempty(stats)
        % Fallback to brightest overall pixel if thresholding failed
        [~, maxIdx] = max(imgNoVessels(:));
        [y, x] = ind2sub(size(grayImg), maxIdx);
        odCentroid = [x, y];
        odRadius = round(cols * 0.08); % roughly 8% of width
    else
        % Pick the one with lowest eccentricity (most circular)
        [~, bestIdx] = min([stats.Eccentricity]);
        odCentroid = stats(bestIdx).Centroid;
        odRadius = stats(bestIdx).EquivDiameter / 2;
    end
    
    % Create explicit OD mask
    [columnsInImage, rowsInImage] = meshgrid(1:cols, 1:rows);
    % 1.2x multiplier to ensure the bright halo is fully encompassed
    odMask = (rowsInImage - odCentroid(2)).^2 + (columnsInImage - odCentroid(1)).^2 <= (odRadius*1.2).^2;
    
    % --- 2. Fovea localization ---
    % Fovea is generally located 2 to 2.5 OD diameters temporal to the OD.
    % Since we don't know left/right eye explicitly, we search both sides for the darkest region.
    
    greenChannel = imgD(:,:,2);
    % Smooth heavily to ignore small vessel fragments/haemorrhages
    smoothedGreen = imgaussfilt(greenChannel, 15);
    
    % Mask out the OD so its bright halo doesn't interfere
    smoothedGreen(odMask) = 1; 
    
    % Search radius (macula distance)
    dist = 2.5 * (odRadius * 2);
    
    % Find darkest point globally, but constrain it to be roughly horizontally aligned with OD
    % We penalize pixels that are vertically far from the OD centroid
    yDistPenalty = abs(rowsInImage - odCentroid(2)) / rows;
    
    % We penalize pixels that are not at the expected distance
    xDist = abs(columnsInImage - odCentroid(1));
    xDistPenalty = abs(xDist - dist) / cols;
    
    % Combine intensity with spatial priors
    % Lower score = better candidate
    foveaScore = smoothedGreen + (yDistPenalty * 0.5) + (xDistPenalty * 0.5);
    
    % Ignore pixels outside the FOV (black background)
    foveaScore(grayImg < 0.05) = Inf;
    
    [~, minIdx] = min(foveaScore(:));
    [fy, fx] = ind2sub([rows, cols], minIdx);
    
    foveaCoord = [fx, fy];
end
