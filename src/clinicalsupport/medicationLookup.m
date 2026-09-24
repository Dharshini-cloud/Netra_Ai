function result = medicationLookup(grade, conceptVec, patientMedications)
% MEDICATIONLOOKUP Knowledge-base lookup + contraindication check.
% Suggests medications relevant to DR management and flags contraindications
% against the patient's current medication list.
%
% Inputs:
%   grade              - ICDR grade (0-4)
%   conceptVec         - (Optional) Concept vector struct from buildConceptVector
%   patientMedications - (Optional) Cell array of medication name strings (patient's current drugs)
%
% Output:
%   result - struct with fields:
%     suggestions         - cell array of medication suggestions
%     recommendations     - alias for suggestions
%     contraindications   - cell array of flagged interactions
%     safetyNotes         - general safety notes

    if nargin < 2 || isempty(conceptVec)
        conceptVec = struct('nvFlag', false, 'nvdFlag', false, 'nveFlag', false, ...
                            'exArea', 0, 'maCount', 0, 'hmCount', 0, 'cwsCount', 0);
    end
    if nargin < 3 || isempty(patientMedications)
        patientMedications = {};
    end

    % --- Knowledge base: grade -> medication suggestions ---
    medKB = struct();
    medKB.grade0 = {'Metformin (first-line glycaemic control)', ...
                    'ACE inhibitor or ARB for BP control (if hypertensive)'};
    medKB.grade1 = medKB.grade0;
    medKB.grade2 = [medKB.grade0, {'Consider fenofibrate (may slow DR progression)', ...
                                   'Review statin therapy for lipid management'}];
    medKB.grade3 = [medKB.grade2, {'Anti-VEGF agents (e.g., Ranibizumab, Bevacizumab) - clinician decision', ...
                                   'Intravitreal corticosteroids may be considered for refractory cases'}];
    medKB.grade4 = [medKB.grade3, {'Anti-VEGF induction therapy recommended', ...
                                   'Aspirin - not contraindicated in DR despite common misconception'}];

    gradeKey = sprintf('grade%d', grade);
    if isfield(medKB, gradeKey)
        result.suggestions = medKB.(gradeKey);
    else
        result.suggestions = medKB.grade4;
    end

    % NV-specific additions
    hasNV = false;
    if isfield(conceptVec, 'nvFlag') && conceptVec.nvFlag
        hasNV = true;
    end
    if hasNV
        result.suggestions{end+1} = 'Anti-VEGF therapy is first-line for PDR with NVD/NVE - consult retina specialist';
    end

    % Add recommendations alias for convenience
    result.recommendations = result.suggestions;

    % --- Contraindication check ---
    contraindicationDB = {
        'thiazolidinedione',   'macular oedema',    'Thiazolidinediones (e.g. pioglitazone) can worsen DME';
        'aspirin',             'none',              '';   % aspirin is safe
        'nsaid',               'bevacizumab',       'NSAIDs may interfere with anti-VEGF efficacy';
        'warfarin',            'anti-vegf',         'Warfarin increases intravitreal haemorrhage risk - review with haematology';
        'sildenafil',          'none',              'Sildenafil - no direct DR contraindication but caution with proliferative disease';
    };

    result.contraindications = {};
    result.safetyNotes = {};

    patMedLower = cellfun(@lower, patientMedications, 'UniformOutput', false);
    exAreaVal = 0;
    if isfield(conceptVec, 'exArea')
        exAreaVal = conceptVec.exArea;
    end

    for i = 1:size(contraindicationDB, 1)
        drug = contraindicationDB{i, 1};
        context = contraindicationDB{i, 2};
        note = contraindicationDB{i, 3};

        if any(contains(patMedLower, drug)) && ~isempty(note)
            relevant = true;
            if strcmp(context, 'macular oedema') && exAreaVal < 500
                relevant = false;
            end
            if strcmp(context, 'anti-vegf') && ~hasNV && grade < 3
                relevant = false;
            end
            if relevant
                result.contraindications{end+1} = sprintf('WARNING: %s - %s', upper(drug), note);
            end
        end
    end

    result.safetyNotes{end+1} = 'All medication decisions require clinician review and patient consent.';
    result.safetyNotes{end+1} = 'This knowledge base is a prototype and is not a substitute for clinical pharmacology judgment.';
    result.flaggedInteractions = result.contraindications;

    fprintf('[Medication] %d suggestions, %d contraindication(s) flagged.\n', ...
        length(result.suggestions), length(result.contraindications));
end