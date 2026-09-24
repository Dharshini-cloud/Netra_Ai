function sentence = generateEvidenceSentence(grade, conceptVec, confidence)
    if nargin < 3 || isempty(confidence)
        confidence = 0.95;
    end
% GENERATEEVIDENCESENTENCE Template-based NLG from concept vector.
% Produces a clinically-phrased single paragraph suitable for the report.
%
% Inputs:
%   grade      - ICDR grade (0-4)
%   conceptVec - Concept struct from buildConceptVector
%   confidence - Scalar calibrated confidence (0-1)
% Output:
%   sentence   - char string, the evidence summary

    cfg = config();
    gradeName = cfg.classNames{grade + 1};
    confPct = round(confidence * 100);
    
    % Opening — grade and confidence
    sentence = sprintf('Netra AI predicts ICDR Grade %d (%s) with %d%% calibrated confidence. ', ...
        grade, gradeName, confPct);
    
    % ---- Microaneurysms ----
    if conceptVec.maCount == 0
        sentence = [sentence 'No microaneurysms were detected. '];
    elseif conceptVec.maCount <= 5
        sentence = [sentence sprintf('%d microaneurysm(s) identified, consistent with early vascular leakage. ', conceptVec.maCount)];
    else
        sentence = [sentence sprintf('%d microaneurysms identified — a significant burden suggestive of moderate-to-severe disease. ', conceptVec.maCount)];
    end
    
    % ---- Haemorrhages ----
    if conceptVec.hmCount == 0
        sentence = [sentence 'No haemorrhages detected. '];
    else
        if ~isempty(conceptVec.hmType)
            typeStr = strjoin(unique(conceptVec.hmType), '/');
            sentence = [sentence sprintf('%d haemorrhage(s) of type(s) [%s] identified. ', conceptVec.hmCount, typeStr)];
        else
            sentence = [sentence sprintf('%d haemorrhage(s) identified. ', conceptVec.hmCount)];
        end
    end
    
    % ---- Exudates ----
    if conceptVec.exArea == 0
        sentence = [sentence 'No hard exudates present. '];
    elseif conceptVec.exArea < 500
        sentence = [sentence 'Small area of hard exudates detected, indicating early lipid deposition. '];
    else
        sentence = [sentence sprintf('Significant hard exudate area (%d px²) detected — macular involvement should be evaluated. ', conceptVec.exArea)];
    end
    
    % ---- Cotton-Wool Spots ----
    if conceptVec.cwsCount == 0
        sentence = [sentence 'No cotton-wool spots identified. '];
    else
        sentence = [sentence sprintf('%d cotton-wool spot(s) present, suggesting focal retinal ischaemia. ', conceptVec.cwsCount)];
    end
    
    % ---- Neovascularization ----
    if ~conceptVec.nvdFlag && ~conceptVec.nveFlag
        sentence = [sentence 'No neovascularization detected. '];
    elseif conceptVec.nvdFlag && ~conceptVec.nveFlag
        sentence = [sentence 'Abnormal vessel density near the optic disc suggests possible NVD — proliferative changes at the disc. '];
    elseif ~conceptVec.nvdFlag && conceptVec.nveFlag
        sentence = [sentence 'Focal peripheral vessel density anomaly detected — possible NVE requiring ophthalmologist review. '];
    else
        sentence = [sentence 'Both NVD and NVE signals detected — findings consistent with high-risk proliferative diabetic retinopathy. '];
    end
    
    % ---- Referability tail ----
    if grade >= 2
        sentence = [sentence 'REFERRAL RECOMMENDED: findings cross the referable-DR threshold. Ophthalmologist review within appropriate timeframe advised.'];
    else
        sentence = [sentence 'Routine monitoring as per local guidelines is advised.'];
    end
end
