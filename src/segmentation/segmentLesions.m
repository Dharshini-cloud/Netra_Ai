function lesions = segmentLesions(img, vesselMask, odMask)
% SEGMENTLESIONS Generates candidate lesion masks using morphological filtering
% followed by shape-based analysis to separate lesion types.
% Includes haemorrhage type classification (dot / blot / flame).
%
% Inputs:
%   img        - RGB retinal image
%   vesselMask - Binary vessel mask from segmentVessels.m
%   odMask     - Binary OD mask from segmentOpticDiscFovea.m
%
% Output: struct with fields:
%   maMask     - Binary mask of Microaneurysm candidates
%   hmMask     - Binary mask of Haemorrhage candidates
%   hmType     - Per-component type cell array: 'dot' | 'blot' | 'flame'
%   exMask     - Binary mask of Exudate candidates
%   cwsMask    - Binary mask of Cotton-Wool Spot candidates

    imgD = im2double(img);
    greenChannel = imgD(:,:,2);
    
    % Combined exclusion mask: don't detect lesions where vessels or OD are
    exclusionMask = vesselMask | odMask;

    % -----------------------------------------------------------------------
    % 1. MICROANEURYSMS (MAs)
    % Dark, small, circular spots.
    % Detected via top-hat transform on the inverted green channel.
    % -----------------------------------------------------------------------
    seMA = strel('disk', 6);                         % SE smaller than MA max size
    invGreen = imcomplement(greenChannel);
    tophatMA = imtophat(invGreen, seMA);
    maCandidates = tophatMA > 0.05 & ~exclusionMask;
    
    % Remove very large regions (too big to be MAs)
    maCandidates = bwareaopen(maCandidates, 4);      % remove specks below 4px
    maProps = regionprops(maCandidates, 'Area', 'Eccentricity');
    maFilt = false(size(maCandidates));
    for i = 1:length(maProps)
        if maProps(i).Area <= 120 && maProps(i).Eccentricity < 0.8
            maFilt = maFilt | (bwlabel(maCandidates) == i);
        end
    end
    lesions.maMask = maFilt;

    % -----------------------------------------------------------------------
    % 2. HAEMORRHAGES (HMs)
    % Larger dark regions than MAs. Same top-hat method with a bigger SE.
    % Shape analysis produces hmType classification per connected component.
    % -----------------------------------------------------------------------
    seHM = strel('disk', 15);
    tophatHM = imtophat(invGreen, seHM);
    hmCandidates = tophatHM > 0.04 & ~odMask;      % Don't exclude vessels fully — bleed near vessels
    hmCandidates = bwareaopen(hmCandidates, 50);    % MAs removed by area floor
    
    hmProps = regionprops(hmCandidates, 'Area', 'Eccentricity', 'MajorAxisLength', 'MinorAxisLength', 'PixelIdxList');
    hmFilt = false(size(hmCandidates));
    hmType = {};
    
    for i = 1:length(hmProps)
        area = hmProps(i).Area;
        ecc = hmProps(i).Eccentricity;
        aspect = hmProps(i).MajorAxisLength / max(hmProps(i).MinorAxisLength, 1);
        
        if area < 50 || area > 5000
            continue;  % too small (MA) or too large (artifact)
        end
        
        hmFilt(hmProps(i).PixelIdxList) = true;
        
        % --- Haemorrhage type classification by shape/aspect ratio ---
        if area < 200 && ecc < 0.6
            hmType{end+1} = 'dot';          % Small, round
        elseif area >= 200 && ecc < 0.75
            hmType{end+1} = 'blot';         % Medium, somewhat round
        else
            hmType{end+1} = 'flame';        % Elongated, flame-shaped
        end
    end
    lesions.hmMask = hmFilt;
    lesions.hmType = hmType;

    % -----------------------------------------------------------------------
    % 3. EXUDATES (EXs)
    % Bright, waxy deposits — high intensity spots in green/red channels.
    % -----------------------------------------------------------------------
    % Combine red and green for bright region detection
    brightChannel = (imgD(:,:,1) + greenChannel) / 2;
    seEX = strel('disk', 8);
    tophatEX = imtophat(brightChannel, seEX);
    
    % Threshold bright regions
    thresholdEX = mean(tophatEX(tophatEX > 0)) + 2*std(tophatEX(tophatEX > 0));
    exCandidates = tophatEX > thresholdEX & ~exclusionMask;
    exCandidates = bwareaopen(exCandidates, 20);
    lesions.exMask = exCandidates;

    % -----------------------------------------------------------------------
    % 4. COTTON WOOL SPOTS (CWS) — "Soft Exudates"
    % Pale, fluffy, indistinct edges — grayer than hard exudates, near vessels.
    % -----------------------------------------------------------------------
    % CWS are bright but have a more diffuse, gray-white appearance.
    % We differentiate them from EX by looking at local variance (texture):
    % EX are crisp (high local variance), CWS are soft (low local variance).
    grayImg = rgb2gray(imgD);
    localVar = stdfilt(grayImg, ones(9));              % Local std dev
    
    softCandidates = exCandidates & (localVar < 0.05); % Low texture = soft/diffuse
    hardExudates   = exCandidates & (localVar >= 0.05);% High texture = crisp = hard EX
    
    lesions.exMask  = hardExudates;                    % Refine EX to hard exudates only
    lesions.cwsMask = bwareaopen(softCandidates, 30);
end
