function nvResult = detectNeovascularization(vesselMask, odMask, foveaCoord)
% DETECTNEOVASCULARIZATION Detects neovascularization via two-pass vessel density scoring.
%
% Pass 1: NVD (Neovascularization at the Disc)
%   - Checks vessel density within a dilated OD neighborhood
%   - NVD indicated by abnormally high, chaotic local vessel density near disc
%
% Pass 2: NVE (Neovascularization Elsewhere)
%   - Checks vessel density along the vascular arcades and mid-peripheral retina
%   - NVE indicated by focal high-density clusters distant from the disc
%
% Inputs:
%   vesselMask - Binary vessel mask from segmentVessels.m
%   odMask     - Binary OD mask from segmentOpticDiscFovea.m
%   foveaCoord - [x, y] fovea coordinate from segmentOpticDiscFovea.m
%
% Output: struct with fields
%   nvdFlag    - logical, true if NVD suspected
%   nveFlag    - logical, true if NVE suspected
%   nvdScore   - numerical density score near disc
%   nveScore   - numerical density score in periphery
%   nveMap     - density map image for visualization

    [rows, cols] = size(vesselMask);

    % Estimate OD radius from the mask
    odProps = regionprops(odMask, 'Centroid', 'EquivDiameter');
    if isempty(odProps)
        % Fallback: guess OD center from brightest region
        [~, maxIdx] = max(double(vesselMask(:)));
        [oy, ox] = ind2sub([rows, cols], maxIdx);
        odCentroid = [ox, oy];
        odRadius = round(cols * 0.08);
    else
        % Use the largest OD component
        [~, biggestIdx] = max([odProps.EquivDiameter]);
        odCentroid = odProps(biggestIdx).Centroid;
        odRadius = odProps(biggestIdx).EquivDiameter / 2;
    end

    % -----------------------------------------------------------------------
    % PASS 1: NVD — Vessel density in the peri-discal zone
    % The NVD zone is a ring around the OD: inner radius = OD boundary,
    % outer radius = 1.5x OD diameter.
    % -----------------------------------------------------------------------
    [X, Y] = meshgrid(1:cols, 1:rows);
    distFromOD = sqrt((X - odCentroid(1)).^2 + (Y - odCentroid(2)).^2);
    
    nvdInnerR = odRadius * 1.0;
    nvdOuterR = odRadius * 1.5;
    nvdZone = (distFromOD >= nvdInnerR) & (distFromOD <= nvdOuterR);
    
    % NVD score = fraction of the NVD zone covered by vessels
    nvdScore = sum(vesselMask(nvdZone)) / max(sum(nvdZone(:)), 1);
    
    % Empirically, nvdScore > 0.35 suggests abnormal vessel density near disc
    % (Normative density in literature is roughly 0.20-0.30 in this ring)
    nvdThreshold = 0.35;
    nvdFlag = nvdScore > nvdThreshold;

    % -----------------------------------------------------------------------
    % PASS 2: NVE — Focal vessel density clusters in the peripheral retina
    % Exclude the OD zone and macular zone (central 15% of image).
    % Divide the remainder into a grid and score each cell's vessel density.
    % Flag cells with density > 2 standard deviations above the mean.
    % -----------------------------------------------------------------------
    
    % Build the "periphery mask": everywhere except OD and macula
    maculaRadius = odRadius * 2;
    maculaZone = (sqrt((X - foveaCoord(1)).^2 + (Y - foveaCoord(2)).^2) <= maculaRadius);
    odExpandedZone = distFromOD <= (odRadius * 2);
    
    peripheryMask = ~maculaZone & ~odExpandedZone;
    
    % Grid-based local density map (16x16 grid)
    gridN = 16;
    cellH = floor(rows / gridN);
    cellW = floor(cols / gridN);
    
    densityGrid = zeros(gridN, gridN);
    for gr = 1:gridN
        for gc = 1:gridN
            r1 = (gr-1)*cellH + 1;
            r2 = min(gr*cellH, rows);
            c1 = (gc-1)*cellW + 1;
            c2 = min(gc*cellW, cols);
            
            cellPeriphery = peripheryMask(r1:r2, c1:c2);
            cellVessels   = vesselMask(r1:r2, c1:c2);
            
            numPeriph = sum(cellPeriphery(:));
            if numPeriph < 50
                densityGrid(gr, gc) = 0;  % too few valid pixels, skip
            else
                densityGrid(gr, gc) = sum(cellVessels(cellPeriphery)) / numPeriph;
            end
        end
    end
    
    % Flag NVE if any grid cell density is > mean + 2*std
    validCells = densityGrid(densityGrid > 0);
    if length(validCells) < 4
        nveFlag = false;
        nveScore = 0;
    else
        mu = mean(validCells);
        sigma = std(validCells);
        nveScore = max(densityGrid(:));
        nveFlag = any(densityGrid(:) > mu + 2*sigma);
    end
    
    % Upsample grid back for visualization
    nveMap = imresize(densityGrid, [rows cols], 'nearest');
    
    % Collect results
    nvResult.nvdFlag  = nvdFlag;
    nvResult.nveFlag  = nveFlag;
    nvResult.nvdScore = nvdScore;
    nvResult.nveScore = nveScore;
    nvResult.nveMap   = nveMap;
end
