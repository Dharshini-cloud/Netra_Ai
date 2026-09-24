function guidance = nutritionGuidance(grade, patientID, adherenceEntry)
% NUTRITIONGUIDANCE Rule-based dietary/lifestyle guidance + adherence logging.
% Returns guidance struct and optionally logs an adherence entry to the twin store.
%
% Inputs:
%   grade          - ICDR grade (0-4)
%   patientID      - (Optional) String patient identifier (for adherence logging)
%   adherenceEntry - (Optional) Struct to log: {date, metGoals, notes}
%
% Output:
%   guidance - struct with fields:
%     dietary          - cell array of all dietary recommendations
%     dietaryAdditions - cell array of grade-specific additions
%     lifestyle        - cell array of lifestyle recommendations
%     redFlags         - cell array of dietary items to strictly avoid
%     adherenceLogged  - logical

    if nargin < 1 || isempty(grade)
        grade = 0;
    end
    gradeIdx = min(5, max(1, round(grade) + 1));

    guidance = struct();

    % --- Core dietary recommendations (universal for all DR grades) ---
    coreItems = {
        'Maintain HbA1c < 7% through portion-controlled, low-GI carbohydrates';
        'Limit refined sugars and high-GI foods (white bread, sugary drinks, processed snacks)';
        'Increase omega-3 intake (oily fish 2x/week or flaxseed/walnuts)';
        'Mediterranean-style diet: vegetables, legumes, whole grains, olive oil';
        'Adequate protein (lean meat, eggs, legumes) to support retinal repair';
        'Stay hydrated - aim for 6-8 glasses of water per day'
    };

    gradeAdditions = {
        {'Annual nutritional review to maintain healthy metabolic parameters'}; ...  % Grade 0
        {'Strict sodium restriction (<2g/day) to control blood pressure, a key DR driver'}; ...  % Grade 1
        {'Fenofibrate-compatible low-fat diet if fenofibrate is prescribed'; ...  % Grade 2
         'Lutein/zeaxanthin-rich foods (leafy greens, eggs) to support macular pigment density'}; ...
        {'Strict lipid control diet - reduce saturated fat to <7% of total calories'; ...  % Grade 3
         'Vitamin C and E antioxidant-rich diet (berries, nuts, citrus)'; ...
         'Avoid high-salt, high-fat processed foods entirely'}; ...
        {'Same as Grade 3 - maintain strict glycemic and blood pressure targets'; ...  % Grade 4
         'Nutritional support referral recommended if appetite is reduced post-treatment'}
    };

    additions = gradeAdditions{gradeIdx};
    guidance.dietaryAdditions = additions;
    guidance.dietary = [coreItems(:); additions(:)];

    % --- Lifestyle recommendations ---
    guidance.lifestyle = {
        '150 minutes of moderate aerobic activity per week (walking, swimming, cycling)';
        'Blood glucose monitoring before and after exercise';
        'Smoking cessation - smoking significantly accelerates microvascular damage';
        'Limit alcohol: <= 14 units/week (alcohol raises blood glucose unpredictably)';
        'Annual comprehensive foot examination alongside eye screening';
        'Regular blood pressure home monitoring'
    };

    if grade >= 3
        guidance.lifestyle{end+1} = 'Avoid high-intensity contact sports or heavy straining (Valsalva) - risk of vitreous haemorrhage with PDR';
        guidance.lifestyle{end+1} = 'Driving restrictions may apply - check local guidelines for visual acuity standards';
    end

    % --- Red flags (strictly avoid) ---
    guidance.redFlags = {
        'Sugar-sweetened beverages and high-fructose corn syrup products';
        'Trans fats and highly processed bakery items';
        'High-glycaemic index refined carbohydrates consumed without fiber or protein';
        'Grapefruit / grapefruit juice (if taking specific statins or calcium channel blockers)'
    };

    guidance.adherenceLogged = false;
    % Alias fields for NetraApp
    guidance.dietaryRecommendations = guidance.dietary;
    guidance.lifestyleAdvice        = guidance.lifestyle;

    % Optional: log adherence entry to twinStore if patientID is provided
    if nargin >= 3 && ~isempty(patientID) && ~isempty(adherenceEntry)
        try
            patientRecord = twinStore('read', patientID);
            if ~isfield(patientRecord, 'adherenceHistory')
                patientRecord.adherenceHistory = {};
            end
            adherenceEntry.loggedDate = datestr(now);
            patientRecord.adherenceHistory{end+1} = adherenceEntry;
            twinStore('update', patientID, patientRecord);
            guidance.adherenceLogged = true;
            fprintf('[Nutrition] Adherence record logged for %s.\n', patientID);
        catch
        end
    end
end