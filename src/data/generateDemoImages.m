function imagePaths = generateDemoImages()
% GENERATEDEMOIMAGES Generates 3 realistic synthetic retinal fundus demo images:
% 1. DEMO_APTOS_001_NORMAL.png   (Grade 0: Normal Retina)
% 2. DEMO_APTOS_002_MODERATE.png (Grade 2: Moderate NPDR with MAs, HMs, Exudates)
% 3. DEMO_APTOS_003_SEVERE.png   (Grade 4: Proliferative DR / Severe NPDR)
%
% Saves images to data/processed/images/
%
% Netra AI DR Pipeline

    cfg = config();
    outDir = cfg.paths.processedImages;
    if ~isfolder(outDir); mkdir(outDir); end
    
    imagePaths = cell(1, 3);
    
    % Generate 3 grades
    imagePaths{1} = fullfile(outDir, 'DEMO_APTOS_001_NORMAL.png');
    imagePaths{2} = fullfile(outDir, 'DEMO_APTOS_002_MODERATE.png');
    imagePaths{3} = fullfile(outDir, 'DEMO_APTOS_003_SEVERE.png');
    
    imgNormal = renderFundus(0);
    imwrite(imgNormal, imagePaths{1});
    
    imgMod = renderFundus(2);
    imwrite(imgMod, imagePaths{2});
    
    imgSevere = renderFundus(4);
    imwrite(imgSevere, imagePaths{3});
    
    fprintf('Successfully generated 3 demo fundus images in %s\n', outDir);
end

function imgRGB = renderFundus(grade)
    H = 512; W = 512;
    [X, Y] = meshgrid(1:W, 1:H);
    
    % Circular Retinal FOV Mask
    centerX = W / 2; centerY = H / 2;
    radius = W * 0.44;
    distCenter = sqrt((X - centerX).^2 + (Y - centerY).^2);
    retinaMask = distCenter <= radius;
    
    % Base orange-red retinal background with natural vignetting
    vignette = 1 - 0.35 * (distCenter / radius).^2;
    vignette(~retinaMask) = 0;
    
    R = 0.78 * vignette;
    G = 0.38 * vignette;
    B = 0.12 * vignette;
    
    % Optic Disc (bright yellowish circle at ~0.35 W, 0.5 H)
    odX = round(W * 0.32);
    odY = round(H * 0.50);
    odRadius = round(W * 0.075);
    distOD = sqrt((X - odX).^2 + (Y - odY).^2);
    odMask = distOD <= odRadius;
    
    % Optic disc gradient (brighter margin, central physiologic cup)
    cupMask = distOD <= (odRadius * 0.45);
    odGrad = exp(-(distOD.^2) / (2 * (odRadius * 0.8)^2));
    
    R(odMask) = R(odMask) * 0.3 + 0.95 * odGrad(odMask);
    G(odMask) = G(odMask) * 0.3 + 0.85 * odGrad(odMask);
    B(odMask) = B(odMask) * 0.3 + 0.45 * odGrad(odMask);
    
    R(cupMask) = 1.0; G(cupMask) = 0.95; B(cupMask) = 0.65;
    
    % Fovea (dark avascular zone located temporally ~2.5 disc diameters away)
    fovX = round(W * 0.62);
    fovY = round(H * 0.52);
    distFov = sqrt((X - fovX).^2 + (Y - fovY).^2);
    fovDark = exp(-(distFov.^2) / (2 * (W * 0.05)^2));
    
    R = R .* (1 - 0.25 * fovDark);
    G = G .* (1 - 0.35 * fovDark);
    B = B .* (1 - 0.45 * fovDark);
    
    % Blood Vessels (superior and inferior vascular arcades)
    vesselMask = false(H, W);
    theta = linspace(0, pi, 400);
    
    % Superior arcade
    ax1 = odX + (W * 0.32) * (1 - cos(theta));
    ay1 = odY - (H * 0.30) * sin(theta);
    for k = 1:length(ax1)
        px = round(ax1(k)); py = round(ay1(k));
        if px >= 1 && px <= W && py >= 1 && py <= H && retinaMask(py, px)
            vesselMask(max(1, py-2):min(H, py+2), max(1, px-2):min(W, px+2)) = true;
        end
    end
    
    % Inferior arcade
    ax2 = odX + (W * 0.32) * (1 - cos(theta));
    ay2 = odY + (H * 0.30) * sin(theta);
    for k = 1:length(ax2)
        px = round(ax2(k)); py = round(ay2(k));
        if px >= 1 && px <= W && py >= 1 && py <= H && retinaMask(py, px)
            vesselMask(max(1, py-2):min(H, py+2), max(1, px-2):min(W, px+2)) = true;
        end
    end
    
    % Smooth vessel mask and darken vessel pixels
    vesselSmooth = imgaussfilt(double(vesselMask), 1.2);
    R = R .* (1 - 0.50 * vesselSmooth);
    G = G .* (1 - 0.65 * vesselSmooth);
    B = B .* (1 - 0.70 * vesselSmooth);
    
    % --- Add Pathology by DR Grade ---
    rng(42 + grade);
    
    if grade >= 2
        % Microaneurysms (tiny dark red dots, 2-4 px)
        numMAs = 12;
        for m = 1:numMAs
            mx = round(W * (0.42 + 0.35 * rand()));
            my = round(H * (0.30 + 0.40 * rand()));
            if retinaMask(my, mx)
                rr = randi([2, 3]);
                [mX, mY] = meshgrid(max(1, mx-rr):min(W, mx+rr), max(1, my-rr):min(H, my+rr));
                blob = ((mX - mx).^2 + (mY - my).^2) <= rr^2;
                idx = sub2ind([H, W], mY(blob), mX(blob));
                R(idx) = R(idx) * 0.4;
                G(idx) = G(idx) * 0.1;
                B(idx) = B(idx) * 0.05;
            end
        end
        
        % Haemorrhages (larger dark blotches, 6-12 px)
        numHMs = 5;
        for h = 1:numHMs
            hx = round(W * (0.45 + 0.30 * rand()));
            hy = round(H * (0.25 + 0.50 * rand()));
            if retinaMask(hy, hx)
                rx = randi([5, 9]); ry = randi([4, 8]);
                [hX, hY] = meshgrid(max(1, hx-rx):min(W, hx+rx), max(1, hy-ry):min(H, hy-ry));
                blob = ((hX - hx).^2 / rx^2 + (hY - hy).^2 / ry^2) <= 1;
                idx = sub2ind([H, W], hY(blob), hX(blob));
                R(idx) = R(idx) * 0.45;
                G(idx) = G(idx) * 0.12;
                B(idx) = B(idx) * 0.08;
            end
        end
        
        % Hard Exudates (bright yellowish punctate patches)
        numEX = 8;
        for e = 1:numEX
            ex = round(W * (0.50 + 0.25 * rand()));
            ey = round(H * (0.35 + 0.30 * rand()));
            if retinaMask(ey, ex)
                er = randi([2, 5]);
                [eX, eY] = meshgrid(max(1, ex-er):min(W, ex+er), max(1, ey-er):min(H, ey-er));
                blob = ((eX - ex).^2 + (eY - ey).^2) <= er^2;
                idx = sub2ind([H, W], eY(blob), eX(blob));
                R(idx) = 0.98;
                G(idx) = 0.92;
                B(idx) = 0.35;
            end
        end
    end
    
    if grade >= 4
        % Cotton Wool Spots (soft, cloudy white patches)
        for c = 1:3
            cx = round(W * (0.38 + 0.28 * rand()));
            cy = round(H * (0.32 + 0.36 * rand()));
            if retinaMask(cy, cx)
                cr = randi([12, 18]);
                [cX, cY] = meshgrid(max(1, cx-cr):min(W, cx+cr), max(1, cy-cr):min(H, cy-cr));
                distC = sqrt((cX - cx).^2 + (cY - cy).^2);
                cBlob = distC <= cr;
                cSoft = exp(-(distC.^2) / (2 * (cr*0.5)^2));
                idx = sub2ind([H, W], cY(cBlob), cX(cBlob));
                R(idx) = R(idx) * 0.4 + 0.6 * cSoft(cBlob);
                G(idx) = G(idx) * 0.4 + 0.6 * cSoft(cBlob);
                B(idx) = B(idx) * 0.4 + 0.55 * cSoft(cBlob);
            end
        end
        
        % Neovascularization (fine, disorganized vessels near OD)
        for n = 1:12
            nx = odX + randi([-round(odRadius*1.5), round(odRadius*1.5)]);
            ny = odY + randi([-round(odRadius*1.5), round(odRadius*1.5)]);
            if nx >= 1 && nx <= W && ny >= 1 && ny <= H
                R(max(1, ny-1):min(H, ny+1), max(1, nx-1):min(W, nx+1)) = 0.35;
                G(max(1, ny-1):min(H, ny+1), max(1, nx-1):min(W, nx+1)) = 0.10;
                B(max(1, ny-1):min(H, ny+1), max(1, nx-1):min(W, nx+1)) = 0.05;
            end
        end
    end
    
    % Zero outside retina mask
    R(~retinaMask) = 0;
    G(~retinaMask) = 0;
    B(~retinaMask) = 0;
    
    imgRGB = cat(3, R, G, B);
    imgRGB = min(1.0, max(0.0, imgRGB));
    imgRGB = im2uint8(imgRGB);
end
