function features = extractQualityFeatures(img)
% EXTRACTQUALITYFEATURES Extracts image quality metrics for classification.
% Input: RGB Image (H x W x 3)
% Output: 1x4 array [sharpness, illumination_green, fov_ratio, glare_v]

    % Convert to double for calculations (0.0 to 1.0)
    imgD = im2double(img);
    
    % Mask for the retinal field (ignore dark background)
    grayImg = rgb2gray(imgD);
    mask = grayImg > 0.05; 
    
    % 1. Sharpness: Variance of Laplacian
    lap = fspecial('laplacian');
    imgLap = imfilter(grayImg, lap, 'replicate');
    % Compute variance only inside the FOV to avoid penalizing the mask edge
    if any(mask(:))
        sharpness = var(imgLap(mask));
    else
        sharpness = 0;
    end
    
    % 2. Illumination (Green Channel): diagnostic contrast
    greenChannel = imgD(:,:,2);
    if any(mask(:))
        illumination_green = mean(greenChannel(mask));
    else
        illumination_green = 0;
    end
    
    % 3. FOV Ratio: percentage of non-background pixels
    fov_ratio = sum(mask(:)) / numel(mask);
    
    % 4. Glare (V Channel in HSV): specular reflection/flare
    hsvImg = rgb2hsv(imgD);
    vChannel = hsvImg(:,:,3);
    % Glare defined as pixels near saturation in the foreground
    if any(mask(:))
        glare_v = sum(vChannel(mask) > 0.9) / sum(mask(:));
    else
        glare_v = 0;
    end
    
    features = [sharpness, illumination_green, fov_ratio, glare_v];
end
