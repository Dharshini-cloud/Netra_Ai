function imgEnhanced = enhanceImage(img)
% ENHANCEIMAGE CLAHE + Bilateral filtering for borderline images.
% Applies adaptive histogram equalization to the L channel of LAB space
% and bilateral filtering to smooth noise without blurring vessels.
    
    isUint8 = isa(img, 'uint8');
    
    % Convert to LAB color space to apply CLAHE to lightness only
    lab = rgb2lab(img);
    L = lab(:,:,1) ./ 100; % Scale 0-1 for processing
    
    % Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
    % Limits contrast enhancement to prevent noise amplification
    L_clahe = adapthisteq(L, 'NumTiles', [8 8], 'ClipLimit', 0.01);
    
    % Apply Bilateral Filter (intensity sigma 0.1, spatial sigma 5)
    % Smooths flat regions (noise) while preserving edges (vessels/lesions)
    L_filtered = imbilatfilt(L_clahe, 0.1, 5);
    
    % Reconstruct image
    lab(:,:,1) = L_filtered .* 100;
    imgEnhanced = lab2rgb(lab);
    
    % Convert back to uint8 if input was uint8
    if isUint8
        imgEnhanced = im2uint8(imgEnhanced);
    end
end
