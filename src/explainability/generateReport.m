function [reportPath, txtPath] = generateReport(img, conceptVec, grade, rawScores, confidence, patientID, outputDir)
% GENERATEREPORT Composes an annotated HTML report with all pipeline outputs.
% All images and charts are embedded directly as Base64 Data URIs,
% making the HTML file 100% self-contained and portable when shared offline.
% Also generates a companion plain-text clinical summary for rural clinics.

    cfg = config();
    if nargin < 6 || isempty(patientID)
        patientID = 'PATIENT_001';
    end
    if nargin < 7 || isempty(outputDir)
        outputDir = cfg.paths.reports;
    end
    if ~isfolder(outputDir); mkdir(outputDir); end
    
    gradeName = cfg.classNames{min(5, max(1, grade + 1))};
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    
    % --- 1. Enhanced Image (CLAHE) ---
    enhancedImg = img;
    try
        if size(img,3) == 3
            lab = rgb2lab(img);
            L = lab(:,:,1) / 100;
            L = adapthisteq(L, 'ClipLimit', 0.02, 'NumTiles', [8 8]);
            lab(:,:,1) = L * 100;
            enhancedImg = uint8(lab2rgb(lab) * 255);
        else
            enhancedImg = adapthisteq(img);
        end
    catch
        enhancedImg = img;
    end
    
    % --- 2. Blood Vessel Mask ---
    [h, w, ~] = size(img);
    if isfield(conceptVec, 'vesselMask') && ~isempty(conceptVec.vesselMask)
        vm = logical(conceptVec.vesselMask);
        if ~isequal(size(vm), [h w]); vm = imresize(vm, [h w], 'nearest'); end
        vesselImg = cat(3, uint8(vm*255), uint8(vm*255), uint8(vm*255));
    else
        vesselImg = zeros(h, w, 3, 'uint8');
    end

    % --- 3. Build Lesion & Vessel Multi-Overlay ---
    lesionOverlay = im2double(img);
    
    % Vessel network underlay
    if isfield(conceptVec, 'vesselMask') && any(conceptVec.vesselMask(:))
        lesionOverlay = drawMaskOverlay(lesionOverlay, conceptVec.vesselMask, [0 0.8 0.6], 0.35);
    end
    
    % Lesions
    if isfield(conceptVec, 'maMask') && any(conceptVec.maMask(:))
        maD = imdilate(conceptVec.maMask, strel('disk', 3));
        lesionOverlay = drawMaskOverlay(lesionOverlay, maD, [1 0.1 0.1], 0.85);
    end
    if isfield(conceptVec, 'hmMask') && any(conceptVec.hmMask(:))
        lesionOverlay = drawMaskOverlay(lesionOverlay, conceptVec.hmMask, [0.8 0 0.2], 0.65);
    end
    if isfield(conceptVec, 'exMask') && any(conceptVec.exMask(:))
        lesionOverlay = drawMaskOverlay(lesionOverlay, conceptVec.exMask, [1 0.9 0], 0.75);
    end
    if isfield(conceptVec, 'cwsMask') && any(conceptVec.cwsMask(:))
        lesionOverlay = drawMaskOverlay(lesionOverlay, conceptVec.cwsMask, [0 0.9 1], 0.75);
    end
    
    % OD boundary & Fovea
    if isfield(conceptVec, 'odMask') && any(conceptVec.odMask(:))
        odBoundary = bwperim(conceptVec.odMask);
        odBoundary = imdilate(odBoundary, strel('disk', 2));
        lesionOverlay = drawMaskOverlay(lesionOverlay, odBoundary, [1 0.84 0], 0.9);
    end
    if isfield(conceptVec, 'foveaCoord') && numel(conceptVec.foveaCoord) >= 2
        fx = round(conceptVec.foveaCoord(1)); fy = round(conceptVec.foveaCoord(2)); sz = 14;
        fx = max(sz+1, min(w-sz, fx)); fy = max(sz+1, min(h-sz, fy));
        cr = max(1,fy-sz):min(h,fy+sz); cc = max(1,fx-sz):min(w,fx+sz);
        lesionOverlay(fy, cc, :) = repmat(reshape([1 0 0.6], 1, 1, 3), 1, numel(cc));
        lesionOverlay(cr, fx, :) = repmat(reshape([1 0 0.6], 1, 1, 3), numel(cr), 1);
    end
    
    % --- 4. Grad-CAM overlay ---
    try
        [gradCamImg, ~] = explainGrade(img, conceptVec);
    catch
        gradCamImg = im2uint8(lesionOverlay);
    end
    
    % --- 5. Microaneurysm Candidates ---
    maImg = buildCandidateVisualForReport(img, conceptVec, 'ma');
    
    % --- 6. Exudate Candidates ---
    exImg = buildCandidateVisualForReport(img, conceptVec, 'ex');
    
    % Evidence sentence
    evidenceSentence = generateEvidenceSentence(grade, conceptVec, confidence);
    
    % --- Save temporary image assets for Base64 conversion ---
    imgAssetsDir = fullfile(outputDir, 'assets');
    if ~isfolder(imgAssetsDir); mkdir(imgAssetsDir); end
    
    origPath     = fullfile(imgAssetsDir, sprintf('%s_%s_orig.png', patientID, timestamp));
    enhancedPath = fullfile(imgAssetsDir, sprintf('%s_%s_enh.png', patientID, timestamp));
    vesselPath   = fullfile(imgAssetsDir, sprintf('%s_%s_vessels.png', patientID, timestamp));
    overlayPath  = fullfile(imgAssetsDir, sprintf('%s_%s_overlay.png', patientID, timestamp));
    gradCamPath  = fullfile(imgAssetsDir, sprintf('%s_%s_gradcam.png', patientID, timestamp));
    
    imwrite(im2uint8(img), origPath);
    imwrite(enhancedImg, enhancedPath);
    imwrite(vesselImg, vesselPath);
    imwrite(im2uint8(lesionOverlay), overlayPath);
    imwrite(gradCamImg, gradCamPath);
    
    maPath = fullfile(imgAssetsDir, sprintf('%s_%s_ma.png', patientID, timestamp));
    exPath = fullfile(imgAssetsDir, sprintf('%s_%s_ex.png', patientID, timestamp));
    imwrite(maImg, maPath);
    imwrite(exImg, exPath);
    
    % --- Bar chart for grade probabilities ---
    chartFig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 500 350]);
    b = bar(0:4, rawScores*100, 'FaceColor', [0.12 0.47 0.88], 'EdgeColor', 'none');
    xlabel('ICDR Severity Grade', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Confidence (%)', 'FontSize', 10, 'FontWeight', 'bold');
    title('Class Probability Distribution', 'FontSize', 11, 'FontWeight', 'bold');
    ylim([0 100]); grid on;
    set(gca, 'XTick', 0:4, 'XTickLabel', {'0: None', '1: Mild', '2: Mod', '3: Sev', '4: PDR'}, 'FontSize', 9);
    chartPath = fullfile(imgAssetsDir, sprintf('%s_%s_chart.png', patientID, timestamp));
    saveas(chartFig, chartPath);
    close(chartFig);
    
    % Convert all 6 images to self-contained Base64 data URIs
    origB64     = fileToBase64(origPath);
    enhancedB64 = fileToBase64(enhancedPath);
    vesselB64   = fileToBase64(vesselPath);
    overlayB64  = fileToBase64(overlayPath);
    gradCamB64  = fileToBase64(gradCamPath);
    chartB64    = fileToBase64(chartPath);
    maB64       = fileToBase64(maPath);
    exB64       = fileToBase64(exPath);
    
    % Clean up temporary asset files
    try
        delete(origPath); delete(enhancedPath); delete(vesselPath);
        delete(overlayPath); delete(gradCamPath); delete(chartPath);
        delete(maPath); delete(exPath);
    catch; end
    
    % Referable flag styling
    referableStr = 'NON-REFERABLE (Grade < 2)';
    referableColor = '#16a34a';
    if grade >= 2
        referableStr = 'REFERABLE DR DETECTED (Grade >= 2)';
        referableColor = '#dc2626';
    end
    
    % Format HM types string
    if isfield(conceptVec, 'hmType') && ~isempty(conceptVec.hmType)
        hmTypesStr = strjoin(unique(cellstr(conceptVec.hmType)), ', ');
    else
        hmTypesStr = 'None';
    end
    
    txtFileName = sprintf('report_%s_%s.txt', patientID, timestamp);
    
    % --- Build Portable Self-Contained HTML ---
    html = ['<!DOCTYPE html>' ...
        '<html lang="en">' ...
        '<head>' ...
        '<meta charset="UTF-8">' ...
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">' ...
        '<title>Netra AI DR Report - ' char(patientID) '</title>' ...
        '<style>' ...
        '* { box-sizing: border-box; }' ...
        'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 25px; background: #0b1120; color: #1e293b; }' ...
        '.container { max-width: 1180px; margin: 0 auto; background: #ffffff; border-radius: 14px; padding: 30px; box-shadow: 0 10px 35px rgba(0,0,0,0.3); }' ...
        '.top-actions { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; flex-wrap: wrap; gap: 10px; }' ...
        '.btn-print { background: #2563eb; color: #ffffff; border: none; padding: 10px 22px; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 8px; box-shadow: 0 2px 6px rgba(37,99,235,0.3); }' ...
        '.btn-print:hover { background: #1d4ed8; }' ...
        '.btn-dl { background: #f1f5f9; color: #334155; border: 1px solid #cbd5e1; padding: 9px 18px; border-radius: 8px; font-size: 13px; font-weight: 600; text-decoration: none; }' ...
        '.btn-dl:hover { background: #e2e8f0; }' ...
        '.offline-badge { background: #ecfdf5; border: 1px solid #a7f3d0; color: #065f46; padding: 8px 16px; border-radius: 8px; font-size: 13px; font-weight: 600; display: inline-flex; align-items: center; gap: 6px; }' ...
        '.header-card { background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%); color: white; padding: 25px 30px; border-radius: 12px; margin-bottom: 24px; }' ...
        '.header-card h1 { margin: 0 0 8px 0; font-size: 26px; letter-spacing: 0.5px; }' ...
        '.badge { display: inline-block; padding: 7px 18px; border-radius: 20px; font-weight: bold; color: #fff; font-size: 14px; }' ...
        '.section { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 22px 25px; margin-bottom: 22px; }' ...
        '.section h2 { margin-top: 0; color: #0f172a; border-bottom: 2px solid #f1f5f9; padding-bottom: 10px; font-size: 19px; }' ...
        '.images-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-top: 15px; }' ...
        'figure { margin: 0; background: #04060a; border: 1px solid #cbd5e1; border-radius: 8px; overflow: hidden; text-align: center; }' ...
        'figure img { width: 100%; height: auto; display: block; }' ...
        'figcaption { padding: 9px; font-size: 12px; font-weight: 700; color: #e2e8f0; background: #0f172a; border-top: 1px solid #334155; }' ...
        '.evidence-box { background: #eff6ff; border-left: 5px solid #3b82f6; padding: 16px 20px; border-radius: 6px; font-size: 14px; line-height: 1.6; color: #1e40af; margin-top: 10px; }' ...
        'table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 13px; }' ...
        'th, td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; text-align: left; }' ...
        'th { background: #f8fafc; color: #475569; font-weight: 700; }' ...
        'tr:hover { background: #f8fafc; }' ...
        '.disclaimer { background: #fffbeb; border: 1px solid #fef3c7; border-left: 5px solid #f59e0b; color: #92400e; padding: 14px 18px; border-radius: 8px; font-size: 12px; line-height: 1.5; margin-top: 20px; }' ...
        '@media (max-width: 850px) { .images-grid { grid-template-columns: 1fr; } }' ...
        '@media print { body { background: #fff; padding: 0; } .container { box-shadow: none; padding: 10px; } .top-actions { display: none; } .images-grid { grid-template-columns: repeat(3, 1fr); } }' ...
        '</style>' ...
        '</head>' ...
        '<body>' ...
        '<div class="container">' ...
        '<div class="top-actions">' ...
        '<div class="offline-badge">&#9989; 100% Offline Standalone Report &mdash; Base64 Data Embedded &mdash; No Internet Required</div>' ...
        '<div style="display:flex; gap:10px;">' ...
        '<button class="btn-print" onclick="window.print()">&#128438; Print / Save as PDF</button>' ...
        '<a class="btn-dl" href="' txtFileName '" download>&#128196; Download Text Summary</a>' ...
        '</div>' ...
        '</div>' ...
        '<div class="header-card">' ...
        '<h1>&#128065; Netra AI &bull; Clinical Screening & Telemedicine Report</h1>' ...
        '<p style="margin: 5px 0 0 0; opacity: 0.9; font-size: 14px;"><strong>Patient ID:</strong> ' char(patientID) ' &nbsp;|&nbsp; <strong>Screening Date:</strong> ' datestr(now, 'mmmm dd, yyyy HH:MM') ' &nbsp;|&nbsp; <strong>Mode:</strong> Rural & Primary Care Offline Telemedicine</p>' ...
        '</div>' ...
        '<div class="section">' ...
        '<h2>Diagnostic Summary</h2>' ...
        '<div style="display: flex; align-items: center; gap: 15px; flex-wrap: wrap; margin-bottom: 15px;">' ...
        '<span style="font-size: 22px; font-weight: 700; color: #0f172a;">Grade ' num2str(grade) ': ' char(gradeName) '</span>' ...
        '<span class="badge" style="background: ' referableColor ';">' referableStr '</span>' ...
        '<span style="font-size: 14px; color: #64748b; margin-left: auto;"><strong>Calibrated Confidence:</strong> ' sprintf('%.1f%%', confidence*100) '</span>' ...
        '</div>' ...
        '<div class="evidence-box">' ...
        '<strong>Clinical Impression & Guidance:</strong><br>' evidenceSentence ...
        '</div>' ...
        '</div>' ...
        '<div class="section">' ...
        '<h2>Multimodal Visual Evidence & Iteration Pipelines</h2>' ...
        '<div class="images-grid">' ...
        '<figure><img src="data:image/png;base64,' origB64 '"><figcaption>1. Original Fundus</figcaption></figure>' ...
        '<figure><img src="data:image/png;base64,' enhancedB64 '"><figcaption>2. Enhanced Image (CLAHE)</figcaption></figure>' ...
        '<figure><img src="data:image/png;base64,' vesselB64 '"><figcaption>3. Blood Vessel Segmentation &bull; Score: ' sprintf('%.3f', conceptVec.vesselAbnormalityScore) '</figcaption></figure>' ...
        '<figure><img src="data:image/png;base64,' overlayB64 '"><figcaption>4. Multi-Lesion Overlay &bull; HM: ' num2str(conceptVec.hmCount) ' | CWS: ' num2str(conceptVec.cwsCount) '</figcaption></figure>' ...
        '<figure><img src="data:image/png;base64,' gradCamB64 '"><figcaption>5. Grad-CAM Attention Map</figcaption></figure>' ...
        '<figure><img src="data:image/png;base64,' chartB64 '"><figcaption>6. ICDR Class Probability</figcaption></figure>' ...
        '<figure><img src="data:image/png;base64,' maB64 '"><figcaption>7. Microaneurysm Candidates &bull; Count: ' num2str(conceptVec.maCount) '</figcaption></figure>' ...
        '<figure><img src="data:image/png;base64,' exB64 '"><figcaption>8. Exudate Candidates &bull; Area: ' num2str(conceptVec.exArea) ' px&sup2;</figcaption></figure>' ...
        '</div>' ...
        '</div>' ...
        '<div class="section">' ...
        '<h2>Quantitative Biomarkers (Concept Vector)</h2>' ...
        '<table>' ...
        '<thead><tr><th>Anatomical / Lesion Metric</th><th>Quantified Finding</th><th>Clinical Reference</th></tr></thead>' ...
        '<tbody>' ...
        '<tr><td>Microaneurysms (MA)</td><td><strong>' sprintf('%d', conceptVec.maCount) '</strong></td><td>Early vascular permeability indicator</td></tr>' ...
        '<tr><td>Haemorrhages (HM)</td><td><strong>' sprintf('%d (%s)', conceptVec.hmCount, hmTypesStr) '</strong></td><td>Focal retinal capillary rupture</td></tr>' ...
        '<tr><td>Hard Exudates Area</td><td><strong>' sprintf('%d px&sup2;', conceptVec.exArea) '</strong></td><td>Lipid deposition from vascular leakage</td></tr>' ...
        '<tr><td>Cotton-Wool Spots (CWS)</td><td><strong>' sprintf('%d', conceptVec.cwsCount) '</strong></td><td>Nerve fiber layer micro-infarction</td></tr>' ...
        '<tr><td>Neovascularization at Disc (NVD)</td><td><strong>' yesno(conceptVec.nvdFlag) '</strong></td><td>High-risk proliferative hallmark</td></tr>' ...
        '<tr><td>Peripheral Neovascularization (NVE)</td><td><strong>' yesno(conceptVec.nveFlag) '</strong></td><td>Active retinal neovascular proliferation</td></tr>' ...
        '<tr><td>Vessel Abnormality Score</td><td><strong>' sprintf('%.3f', conceptVec.vesselAbnormalityScore) '</strong></td><td>Morphological tortuosity index</td></tr>' ...
        '</tbody>' ...
        '</table>' ...
        '</div>' ...
        '<div class="disclaimer">' ...
        '<strong>&#9888; Clinical Notice:</strong> This report is synthesized by the Netra AI Clinical Decision Support System. It is intended to assist medical practitioners in rural health centers and telemedicine camps and must be correlated with clinical examination by an ophthalmologist.' ...
        '</div>' ...
        '</div>' ...
        '</body>' ...
        '</html>'];
    
    % Write fully self-contained HTML report file
    reportPath = fullfile(outputDir, sprintf('report_%s_%s.html', patientID, timestamp));
    fid = fopen(reportPath, 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', html);
    fclose(fid);
    
    % Write companion plain-text report for rural / low-spec systems
    txtPath = fullfile(outputDir, txtFileName);
    fidTxt = fopen(txtPath, 'w', 'n', 'UTF-8');
    fprintf(fidTxt, '========================================================================\r\n');
    fprintf(fidTxt, '           NETRA AI - CLINICAL SCREENING & TELEMEDICINE REPORT          \r\n');
    fprintf(fidTxt, '========================================================================\r\n');
    fprintf(fidTxt, 'Patient ID:         %s\r\n', char(patientID));
    fprintf(fidTxt, 'Screening Date:     %s\r\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fidTxt, 'DR Severity Grade:  Grade %d - %s\r\n', grade, char(gradeName));
    fprintf(fidTxt, 'Triage Status:      %s\r\n', referableStr);
    fprintf(fidTxt, 'Confidence:         %.1f%%\r\n', confidence*100);
    fprintf(fidTxt, '------------------------------------------------------------------------\r\n');
    fprintf(fidTxt, 'QUANTITATIVE BIOMARKERS (CONCEPT VECTOR):\r\n');
    fprintf(fidTxt, '  * Microaneurysms (MA):        %d\r\n', conceptVec.maCount);
    fprintf(fidTxt, '  * Haemorrhages (HM):          %d (Type: %s)\r\n', conceptVec.hmCount, hmTypesStr);
    fprintf(fidTxt, '  * Hard Exudates (px2):        %d\r\n', conceptVec.exArea);
    fprintf(fidTxt, '  * Cotton-Wool Spots:          %d\r\n', conceptVec.cwsCount);
    nvStr = 'NO'; if conceptVec.nvFlag; nvStr = 'YES (Detected)'; end
    fprintf(fidTxt, '  * Neovascularization (NV):    %s\r\n', nvStr);
    fprintf(fidTxt, '  * Vessel Abnormality Score:   %.3f\r\n', conceptVec.vesselAbnormalityScore);
    fprintf(fidTxt, '------------------------------------------------------------------------\r\n');
    fprintf(fidTxt, 'CLINICAL IMPRESSION & RECOMMENDATIONS:\r\n');
    fprintf(fidTxt, '%s\r\n', evidenceSentence);
    fprintf(fidTxt, '========================================================================\r\n');
    fprintf(fidTxt, 'NOTE: 100%% offline generated by Netra AI for rural clinic telemedicine.\r\n');
    fclose(fidTxt);
    
    fprintf('Self-contained HTML report saved: %s\n', reportPath);
    fprintf('Plain-text report saved:          %s\n', txtPath);
end

% -------------------------------------------------------------------------
function b64 = fileToBase64(filePath)
    if ~isfile(filePath)
        b64 = '';
        return;
    end
    fid = fopen(filePath, 'rb');
    bytes = fread(fid, [1, Inf], 'uint8=>uint8');
    fclose(fid);
    try
        b64 = char(matlab.net.base64encode(bytes));
    catch
        b64 = char(org.apache.commons.codec.binary.Base64.encodeBase64(bytes))';
    end
end

% -------------------------------------------------------------------------
function overlaid = drawMaskOverlay(imgD, mask, color, alpha)
    overlaid = imgD;
    [h, w, ~] = size(imgD);
    if ~isequal(size(mask), [h w])
        mask = imresize(logical(mask), [h w], 'nearest');
    else
        mask = logical(mask);
    end
    for c = 1:3
        ch = overlaid(:,:,c);
        ch(mask) = (1 - alpha) * ch(mask) + alpha * color(c);
        overlaid(:,:,c) = ch;
    end
end

% -------------------------------------------------------------------------
% -------------------------------------------------------------------------
function candRGB = buildCandidateVisualForReport(img, cv, type)
    % Generates candidate spot maps for MA and Exudates with visible outer eye contour and fundus context
    [h, w, ~] = size(img);
    fov = (img(:,:,1) > 15 | img(:,:,2) > 15 | img(:,:,3) > 15);
    fov = imfill(fov, 'holes');
    fovIn = imerode(fov, strel('disk', 8));
    
    % Provide subtle fundus anatomical context inside FOV
    gChan = double(img(:,:,2));
    bgLum = uint8(gChan * 0.35);
    candRGB = repmat(bgLum, [1 1 3]);
    candRGB(~repmat(fov, [1 1 3])) = 15; % Dark border outside
    
    if strcmp(type, 'ma')
        G = img(:,:,2);
        bhat = imbothat(G, strel('disk', 6));
        vThresh = mean(double(bhat(fovIn))) + 2.0 * std(double(bhat(fovIn)));
        maCand = (double(bhat) > vThresh) & fovIn;
        if isfield(cv, 'odMask') && ~isempty(cv.odMask)
            od = logical(cv.odMask);
            if ~isequal(size(od), [h w]); od = imresize(od, [h w], 'nearest'); end
            maCand = maCand & ~imdilate(od, strel('disk', 15));
        end
        maCand = bwareaopen(maCand, 2) & ~bwareaopen(maCand, 60);
        maD = imdilate(maCand, strel('disk', 3));
        % Red/Yellow high-contrast candidate points
        R = candRGB(:,:,1); G_out = candRGB(:,:,2); B = candRGB(:,:,3);
        R(maD) = 255; G_out(maD) = 40; B(maD) = 40;
        candRGB = cat(3, R, G_out, B);
    else
        bright = (double(img(:,:,1)) + double(img(:,:,2))) / 2;
        that = imtophat(uint8(bright), strel('disk', 8));
        exThresh = mean(that(fovIn)) + 1.8 * std(double(that(fovIn)));
        exCand = (double(that) > exThresh) & fovIn;
        if isfield(cv, 'odMask') && ~isempty(cv.odMask)
            od = logical(cv.odMask);
            if ~isequal(size(od), [h w]); od = imresize(od, [h w], 'nearest'); end
            exCand = exCand & ~imdilate(od, strel('disk', 12));
        end
        exCand = bwareaopen(exCand, 6);
        exD = imdilate(exCand, strel('disk', 2));
        % Crisp white/yellow exudates
        R = candRGB(:,:,1); G_out = candRGB(:,:,2); B = candRGB(:,:,3);
        R(exD) = 255; G_out(exD) = 255; B(exD) = 100;
        candRGB = cat(3, R, G_out, B);
    end
    
    % Draw outer eye boundary line
    candRGB = addOuterEyeLine(candRGB);
end
function s = yesno(flag)
    if flag
        s = '<span style="color:#dc2626; font-weight:bold;">YES (Detected)</span>';
    else
        s = '<span style="color:#16a34a;">No</span>';
    end
end


function imgOut = addOuterEyeLine(img)
    % Adds a luminous outer eye circular perimeter line to clearly demarcate retinal boundary
    if isempty(img); imgOut = img; return; end
    [h, w, c] = size(img);
    if c == 1
        imgOut = repmat(img, [1 1 3]);
    else
        imgOut = img;
    end
    lum = 0.299*double(imgOut(:,:,1)) + 0.587*double(imgOut(:,:,2)) + 0.114*double(imgOut(:,:,3));
    fov = lum > 12;
    fov = imfill(fov, 'holes');
    fov = imopen(fov, strel('disk', 6));
    fov = imclose(fov, strel('disk', 12));
    
    eyeRim = bwperim(fov);
    eyeRimD = imdilate(eyeRim, strel('disk', 2));
    
    R = imgOut(:,:,1); G = imgOut(:,:,2); B = imgOut(:,:,3);
    % Vivid Medical Cyan Ring for outer eye line
    R(eyeRimD) = 0;
    G(eyeRimD) = 220;
    B(eyeRimD) = 255;
    imgOut = cat(3, R, G, B);
end