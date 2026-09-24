function [status, qualityReport] = assessQuality(img)
% ASSESSQUALITY Wraps extraction and SVM inference.
% Returns EXACT string flags wired into the pipeline.

    cfg = config();
    features = extractQualityFeatures(img);
    sharpness = features(1);
    illum_green = features(2);
    fov = features(3);
    glare_v = features(4);
    
    persistent qualityModel;
    hasModel = false;
    
    if isempty(qualityModel)
        modelPath = fullfile(cfg.paths.rootDir, 'models', 'qualityModel.mat');
        if isfile(modelPath)
            try
                data = load(modelPath);
                qualityModel = data.qualityModel;
                hasModel = true;
            catch
                hasModel = false;
            end
        end
    else
        hasModel = true;
    end
    
    % Classification: use trained SVM if available, otherwise heuristic rule engine
    isAcceptable = true;
    posScore = 1.0;
    
    if hasModel
        try
            [pred, score] = predict(qualityModel, features);
            posScore = score(2);
            isAcceptable = (pred == 1);
        catch
            hasModel = false;
        end
    end
    
    if ~hasModel
        % Robust heuristic classifier fallback
        if fov < 0.20 || sharpness < 1e-5 || illum_green < 0.08 || illum_green > 0.85 || glare_v > 0.08
            isAcceptable = false;
            posScore = -1.0;
        elseif illum_green < 0.22 || glare_v > 0.025 || sharpness < 1.5e-4
            isAcceptable = true;
            posScore = 0.5;
        else
            isAcceptable = true;
            posScore = 1.5;
        end
    end
    
    % Determine status and explanation
    if ~isAcceptable
        if fov < 0.20
            msg = "Insufficient Field of View.";
        elseif sharpness < 1e-4
            msg = "Severe motion blur or lack of focus.";
        elseif illum_green < 0.1 || illum_green > 0.85
            msg = "Illumination out of bounds (severe underexposure or washed out).";
        elseif glare_v > 0.05
            msg = "Excessive specular glare/flare.";
        else
            msg = "General quality check rejection.";
        end
        status = "REJECTED_RECAPTURE";
    elseif posScore < 1.0 || illum_green < 0.25 || glare_v > 0.02
        status = "BORDERLINE_ENHANCED";
        msg = "Image accepted with borderline contrast/illumination; enhancement recommended.";
    else
        status = "ACCEPTED";
        msg = "Image quality passes all clinical checks.";
    end
    
    % Structure report for NetraApp and downstream modules
    qualityReport = struct();
    qualityReport.status = char(status);
    qualityReport.decision = char(status);
    qualityReport.sharpnessScore = sharpness * 1000; % scaled variance for UI display
    qualityReport.sharpness = sharpness * 1000;
    qualityReport.diagnosticContrast = illum_green * 100;
    qualityReport.contrast = illum_green * 100;
    qualityReport.glarePercentage = glare_v;
    qualityReport.glare = glare_v;
    qualityReport.fovRatio = fov;
    qualityReport.message = msg;
    qualityReport.text = char(msg);
    
    if nargout <= 1
        status = qualityReport;
    end
end

