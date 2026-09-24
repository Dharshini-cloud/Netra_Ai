function pathways = treatmentPathway(grade, conceptVec, visitHistory)
% TREATMENTPATHWAY Maps grade + concept flags + history to clinician-reviewed pathway options.
% All outputs are explicitly labelled as suggestions requiring clinician sign-off.
%
% Inputs:
%   grade        - ICDR grade (0-4)
%   conceptVec   - Concept vector struct from buildConceptVector
%   visitHistory - Optional struct array of prior visits (from twinStore)
%
% Output:
%   pathways - struct with fields:
%     options       - cell array of pathway option strings
%     urgency       - 'Routine' | 'Soon' | 'Urgent' | 'Emergency'
%     rationale     - char string explaining the recommendation basis

    if nargin < 3; visitHistory = []; end

    pathways.options   = {};
    pathways.urgency   = 'Routine';
    pathways.rationale = '';

    % --- Grade-based primary routing ---
    switch grade
        case 0
            pathways.options{end+1} = 'Annual screening â€” no DR detected';
            pathways.urgency = 'Routine';
            pathways.rationale = 'No diabetic retinopathy signs observed.';

        case 1
            pathways.options{end+1} = 'Repeat screening in 12 months';
            pathways.options{end+1} = 'Optimise glycaemic and blood pressure control';
            pathways.urgency = 'Routine';
            pathways.rationale = 'Mild NPDR: background changes only.';

        case 2
            pathways.options{end+1} = 'Refer to ophthalmologist within 3 months';
            pathways.options{end+1} = 'Optimise HbA1c target (<7%) with endocrinology';
            pathways.options{end+1} = 'Review antihypertensive medication';
            pathways.urgency = 'Soon';
            pathways.rationale = 'Moderate NPDR: referable disease threshold crossed.';

        case 3
            pathways.options{end+1} = 'Urgent ophthalmology referral (within 4 weeks)';
            pathways.options{end+1} = 'Fluorescein angiography to map ischaemia extent';
            pathways.options{end+1} = 'Consider panretinal photocoagulation (PRP) â€” clinician decision';
            pathways.urgency = 'Urgent';
            pathways.rationale = 'Severe NPDR: high risk of progression to PDR.';

        case 4
            pathways.options{end+1} = 'Emergency ophthalmology referral (within 1 week or sooner if symptomatic)';
            pathways.options{end+1} = 'Anti-VEGF injection therapy consideration â€” clinician decision';
            pathways.options{end+1} = 'Vitreoretinal surgery assessment if tractional detachment suspected';
            pathways.urgency = 'Emergency';
            pathways.rationale = 'Proliferative DR detected â€” sight-threatening disease.';
    end

    % --- Concept-level modifiers ---
    if isfield(conceptVec,'nvdFlag') && (conceptVec.nvdFlag || conceptVec.nveFlag)
        pathways.options{end+1} = 'Neovascularization detected â€” ophthalmologist must review PRP candidacy';
        if strcmp(pathways.urgency, 'Routine') || strcmp(pathways.urgency, 'Soon')
            pathways.urgency = 'Urgent';
        end
        pathways.rationale = [pathways.rationale ' NVD/NVE signals present.'];
    end

    if isfield(conceptVec,'exArea') && conceptVec.exArea > 1000
        pathways.options{end+1} = 'Significant exudate burden â€” evaluate for clinically significant macular oedema (CSMO)';
        pathways.options{end+1} = 'Consider optical coherence tomography (OCT) for macular thickness';
    end

    if isfield(conceptVec,'cwsCount') && conceptVec.cwsCount >= 2
        pathways.options{end+1} = 'Multiple cotton-wool spots â€” screen for associated systemic hypertension';
    end

    % --- Progression modifier (if history available) ---
    if ~isempty(visitHistory) && length(visitHistory) >= 2
        prevGrade = visitHistory{end-1}.grade;
        if grade > prevGrade
            pathways.options{end+1} = sprintf('Grade progression detected (%dâ†’%d) â€” expedite pathway by one urgency level', prevGrade, grade);
            % Escalate urgency
            urgencyLevels = {'Routine','Soon','Urgent','Emergency'};
            curIdx = find(strcmp(pathways.urgency, urgencyLevels));
            if curIdx < 4
                pathways.urgency = urgencyLevels{curIdx + 1};
            end
        end
    end

    % Append disclaimer to all options
    pathways.options{end+1} = 'âš  All pathways are AI-generated suggestions. A qualified ophthalmologist must review and confirm before any action.';

        % --- Alias fields for backward compat with NetraApp ---
    pathways.urgencyLevel    = pathways.urgency;
    pathways.interventions   = pathways.options;
    pathways.primaryAction   = '';
    if ~isempty(pathways.options)
        pathways.primaryAction = pathways.options{1};
    end
    pathways.clinicalRationale = pathways.rationale;
    switch pathways.urgency
        case 'Routine';   pathways.timeframe = 'Annual / 12 months'; pathways.careSetting = 'Community Diabetic Screening';
        case 'Soon';      pathways.timeframe = 'Within 3 months';    pathways.careSetting = 'Ophthalmology Outpatient Clinic';
        case 'Urgent';    pathways.timeframe = 'Within 4 weeks';     pathways.careSetting = 'Ophthalmology Day Unit';
        case 'Emergency'; pathways.timeframe = 'Within 1 week';      pathways.careSetting = 'Emergency Ophthalmology / Vitreoretinal Unit';
        otherwise;        pathways.timeframe = 'As soon as possible'; pathways.careSetting = 'Specialist Clinic';
    end
    fprintf('[Treatment] Urgency: %s | %d pathway option(s) generated.\n', pathways.urgency, length(pathways.options)-1);
end
