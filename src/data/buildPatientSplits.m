function buildPatientSplits()
% BUILDPATIENTSPLITS Implements stratified splitting based on ICDR grade
% Rules:
% 1. Messidor-2 -> external_test_index.mat
% 2. IDRiD -> preserve native splits
% 3. Others -> Group by patient, split 70/15/15 stratified by grade

    cfg = config();
    
    if ~isfolder(cfg.paths.splits)
        mkdir(cfg.paths.splits);
    end
    
    dsTable = loadDataset();
    if isempty(dsTable)
        error('Dataset is empty. Run data loading first.');
    end
    
    % Initialize split tags in table
    dsTable.assignedSplit = repmat("none", height(dsTable), 1);
    
    % 1. Messidor-2 -> external
    m2Idx = dsTable.sourceDataset == "Messidor2";
    dsTable.assignedSplit(m2Idx) = "external_test";
    
    % 2. IDRiD -> preserve native splits
    idridTrainIdx = dsTable.sourceDataset == "IDRiD" & dsTable.originalSplit == "train";
    idridTestIdx = dsTable.sourceDataset == "IDRiD" & dsTable.originalSplit == "test";
    dsTable.assignedSplit(idridTrainIdx) = "train";
    dsTable.assignedSplit(idridTestIdx) = "test";
    
    % 3. Others (APTOS, DRIVE) -> Group by patient (if left/right eye info available)
    % Only split data that doesn't have an assigned split yet.
    remainingIdx = find(dsTable.assignedSplit == "none");
    remainingData = dsTable(remainingIdx, :);
    
    if ~isempty(remainingData)
        % Get unique patients in the remaining data
        [uniquePatients, ~, patientGroupIdx] = unique(remainingData.patientID);
        
        % To stratify, we need a single grade per patient. Take max grade if eyes differ.
        patientGrades = zeros(length(uniquePatients), 1);
        for i = 1:length(uniquePatients)
            g = max(remainingData.grade(patientGroupIdx == i));
            if isnan(g)
                g = -1; % special category for stratification (e.g. DRIVE)
            end
            patientGrades(i) = g;
        end
        
        % Perform 70/15/15 split on unique patients using cvpartition
        % train: 70%, val+test: 30%
        cv1 = cvpartition(patientGrades, 'HoldOut', 0.3);
        trainPatients = uniquePatients(training(cv1));
        valTestPatients = uniquePatients(test(cv1));
        valTestGrades = patientGrades(test(cv1));
        
        % split val+test into 50/50 (15%/15% of total)
        cv2 = cvpartition(valTestGrades, 'HoldOut', 0.5);
        valPatients = valTestPatients(training(cv2));
        testPatients = valTestPatients(test(cv2));
        
        % Map back to original table
        for i = 1:length(remainingIdx)
            pid = dsTable.patientID(remainingIdx(i));
            if ismember(pid, trainPatients)
                dsTable.assignedSplit(remainingIdx(i)) = "train";
            elseif ismember(pid, valPatients)
                dsTable.assignedSplit(remainingIdx(i)) = "val";
            elseif ismember(pid, testPatients)
                dsTable.assignedSplit(remainingIdx(i)) = "test";
            end
        end
    end
    
    % Extract arrays of indices relative to the processed images
    train_index = dsTable(dsTable.assignedSplit == "train", :);
    val_index = dsTable(dsTable.assignedSplit == "val", :);
    test_index = dsTable(dsTable.assignedSplit == "test", :);
    external_test_index = dsTable(dsTable.assignedSplit == "external_test", :);
    
    % Save to .mat files
    save(fullfile(cfg.paths.splits, 'train_index.mat'), 'train_index');
    save(fullfile(cfg.paths.splits, 'val_index.mat'), 'val_index');
    save(fullfile(cfg.paths.splits, 'test_index.mat'), 'test_index');
    save(fullfile(cfg.paths.splits, 'external_test_index.mat'), 'external_test_index');
    
    disp('Splits generated and saved successfully.');
    fprintf('Train: %d, Val: %d, Test: %d, External Test: %d\n', ...
        height(train_index), height(val_index), height(test_index), height(external_test_index));
end
