function store = twinStore(action, patientID, record)
% TWINSTORE Per-patient structured record store (create/read/update).
% Persists twin data to a MAT file at data/twinstore/<patientID>.mat
%
% Usage:
%   store = twinStore('read',   patientID)          → returns patient record struct
%   store = twinStore('create', patientID, record)  → initializes new patient record
%   store = twinStore('update', patientID, record)  → appends visit to existing record
%   store = twinStore('list')                       → returns cell array of all patient IDs
%   twinStore('delete', patientID)                  → removes patient record

    cfg = config();
    storeDir = fullfile(cfg.paths.data, 'twinstore');
    if ~isfolder(storeDir)
        mkdir(storeDir);
    end

    switch lower(action)

        case 'list'
            files = dir(fullfile(storeDir, '*.mat'));
            store = {files.name};
            % Strip .mat extension
            store = cellfun(@(f) strrep(f, '.mat', ''), store, 'UniformOutput', false);

        case 'read'
            filePath = fullfile(storeDir, [char(patientID) '.mat']);
            if ~isfile(filePath)
                error('No twin record found for patient: %s', patientID);
            end
            data = load(filePath);
            store = data.patientRecord;

        case 'create'
            filePath = fullfile(storeDir, [char(patientID) '.mat']);
            if isfile(filePath)
                warning('Record for %s already exists. Use update to add visits.', patientID);
                data = load(filePath);
                store = data.patientRecord;
                return;
            end
            % Initialize record schema
            patientRecord = struct();
            patientRecord.patientID  = char(patientID);
            patientRecord.createdAt  = datestr(now);
            patientRecord.visits     = {};          % cell array of visit structs
            patientRecord.numVisits  = 0;
            if nargin >= 3 && ~isempty(record)
                patientRecord.demographics = record; % optional demographics struct
            else
                patientRecord.demographics = struct();
            end
            save(filePath, 'patientRecord');
            store = patientRecord;
            fprintf('Created twin record for patient: %s\n', patientID);

        case 'update'
            filePath = fullfile(storeDir, [char(patientID) '.mat']);
            if ~isfile(filePath)
                % Auto-create if doesn't exist
                twinStore('create', patientID);
            end
            data = load(filePath);
            patientRecord = data.patientRecord;

            % Validate visit record schema
            required = {'visitDate', 'imagePath', 'grade', 'conceptVec', 'referableFlag'};
            for r = 1:length(required)
                if ~isfield(record, required{r})
                    error('Visit record missing required field: %s', required{r});
                end
            end

            % Append visit
            patientRecord.numVisits = patientRecord.numVisits + 1;
            record.visitIndex = patientRecord.numVisits;
            record.addedAt = datestr(now);
            patientRecord.visits{end+1} = record;

            save(filePath, 'patientRecord');
            store = patientRecord;
            fprintf('Visit %d appended for patient: %s\n', patientRecord.numVisits, patientID);

        case 'delete'
            filePath = fullfile(storeDir, [char(patientID) '.mat']);
            if isfile(filePath)
                delete(filePath);
                fprintf('Deleted twin record for: %s\n', patientID);
            else
                warning('No record found to delete for: %s', patientID);
            end
            store = [];

        otherwise
            error('Unknown twinStore action: %s. Use create/read/update/list/delete.', action);
    end
end
