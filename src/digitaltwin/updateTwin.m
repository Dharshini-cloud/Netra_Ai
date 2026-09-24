function patientRecord = updateTwin(patientID, imagePath, grade, conceptVec, referableFlag, extraFields)
% UPDATETWIN Appends a new visit record after each screening completes.
% Creates a new patient record if one doesn't exist yet.
%
% Inputs:
%   patientID    - String patient identifier
%   imagePath    - Path to the processed screening image
%   grade        - Predicted ICDR grade (0-4)
%   conceptVec   - Concept vector struct from buildConceptVector
%   referableFlag - Logical, true if referable-DR threshold exceeded
%   extraFields  - Optional struct with additional clinical fields
%                  (e.g. HbA1c, bloodPressure, treatmentDecision)

    if nargin < 6
        extraFields = struct();
    end

    % Build visit record
    visitRecord = struct();
    visitRecord.visitDate     = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    visitRecord.imagePath     = char(imagePath);
    visitRecord.grade         = grade;
    visitRecord.conceptVec    = conceptVec;
    visitRecord.referableFlag = referableFlag;

    % Merge any extra clinical fields
    extraFieldNames = fieldnames(extraFields);
    for i = 1:length(extraFieldNames)
        visitRecord.(extraFieldNames{i}) = extraFields.(extraFieldNames{i});
    end

    % Write to store
    patientRecord = twinStore('update', patientID, visitRecord);

    fprintf('[Twin] Visit recorded for %s — Grade %d, Referable: %d\n', ...
        patientID, grade, referableFlag);
end
