function datasetTable = loadDataset()
% LOADDATASET Parses all 4 sources into one common table schema
% Returns a table with schema: 
% {imagePath, patientID, grade, lesionMaskPaths, sourceDataset, cameraType, originalSplit}

    cfg = config();
    
    % Initialize empty table
    varNames = {'imagePath', 'patientID', 'grade', 'lesionMaskPaths', 'sourceDataset', 'cameraType', 'originalSplit'};
    varTypes = {'string', 'string', 'double', 'cell', 'string', 'string', 'string'};
    datasetTable = table('Size', [0, length(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);
    
    % 1. Parse APTOS 2019
    try
        aptosCsv = fullfile(cfg.paths.rawAPTOS, 'train.csv');
        if isfile(aptosCsv)
            aptosData = readtable(aptosCsv);
            n = height(aptosData);
            tempTable = table('Size', [n, length(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);
            for i = 1:n
                imgId = string(aptosData.id_code{i});
                tempTable.imagePath(i) = fullfile(cfg.paths.rawAPTOS, 'train_images', imgId + ".png");
                tempTable.patientID(i) = imgId; % No explicit patient ID in APTOS; use image ID
                tempTable.grade(i) = aptosData.diagnosis(i);
                tempTable.lesionMaskPaths{i} = '';
                tempTable.sourceDataset(i) = "APTOS2019";
                tempTable.cameraType(i) = "Unknown";
                tempTable.originalSplit(i) = "train";
            end
            datasetTable = [datasetTable; tempTable];
        end
    catch ME
        warning('Failed to load APTOS2019: %s', ME.message);
    end
    
    % 2. Parse IDRiD (Disease Grading)
    try
        % IDRiD ships with explicit train/test splits (413/103 images)
        splits = {'a. Training Set', 'b. Testing Set'};
        splitLabels = {'train', 'test'};
        
        dgCandidates = {
            fullfile(cfg.paths.rawIDRiD, 'B. Disease Grading'), ...
            fullfile(cfg.paths.rawIDRiD, 'Disease Grading'), ...
            cfg.paths.rawIDRiD
        };
        
        for s = 1:2
            idridCsv = '';
            imgDir = '';
            
            for d = 1:length(dgCandidates)
                dgBase = dgCandidates{d};
                
                % Check possible Groundtruth CSV locations
                csvFiles = {
                    fullfile(dgBase, '2. Groundtruths', sprintf('%s. IDRiD_Disease Grading_%s Labels.csv', char(96+s), [upper(splitLabels{s}(1)), splitLabels{s}(2:end), 'ing'])), ...
                    fullfile(dgBase, '2. Groundtruths', sprintf('%s_Disease Grading_%s Labels.csv', char(splitLabels{s}(1)), [upper(splitLabels{s}(1)), splitLabels{s}(2:end), 'ing'])), ...
                    fullfile(dgBase, 'Groundtruths', splits{s} + "_Disease_Grading.csv"), ...
                    fullfile(dgBase, 'Groundtruths', sprintf('%s_Disease_Grading.csv', splits{s})), ...
                    fullfile(dgBase, sprintf('%s_Disease_Grading.csv', splits{s})), ...
                    fullfile(dgBase, 'idrid_labels.csv')
                };
                for c = 1:length(csvFiles)
                    if isfile(csvFiles{c})
                        idridCsv = csvFiles{c};
                        break;
                    end
                end
                
                % Check possible Image directory locations
                imgDirs = {
                    fullfile(dgBase, '1. Original Images', splits{s}), ...
                    fullfile(dgBase, 'Original Images', splits{s}), ...
                    fullfile(dgBase, splits{s}), ...
                    fullfile(dgBase, 'Imagenes')
                };
                for im = 1:length(imgDirs)
                    if isfolder(imgDirs{im})
                        imgDir = imgDirs{im};
                        break;
                    end
                end
                
                if ~isempty(idridCsv) && ~isempty(imgDir)
                    break;
                end
            end
            
            if ~isempty(idridCsv) && ~isempty(imgDir)
                idridData = readtable(idridCsv);
                
                % Match column names case-insensitively
                colNames = string(idridData.Properties.VariableNames);
                imgCol = '';
                for col = ["Image_name", "ImageName", "Image name", "id_code", "Image"]
                    matchIdx = find(strcmpi(colNames, col), 1);
                    if ~isempty(matchIdx)
                        imgCol = char(colNames(matchIdx));
                        break;
                    end
                end
                
                gradeCol = '';
                for col = ["Retinopathy_grade", "RetinopathyGrade", "Retinopathy grade", "diagnosis", "grade", "Retinopathy"]
                    matchIdx = find(strcmpi(colNames, col), 1);
                    if ~isempty(matchIdx)
                        gradeCol = char(colNames(matchIdx));
                        break;
                    end
                end
                
                if ~isempty(imgCol) && ~isempty(gradeCol)
                    n = height(idridData);
                    tempTable = table('Size', [n, length(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);
                    for i = 1:n
                        imgId = string(idridData.(imgCol){i});
                        if endsWith(lower(imgId), [".jpg", ".png", ".tif"])
                            tempTable.imagePath(i) = fullfile(imgDir, imgId);
                        else
                            tempTable.imagePath(i) = fullfile(imgDir, imgId + ".jpg");
                        end
                        [~, baseId, ~] = fileparts(imgId);
                        tempTable.patientID(i) = string(baseId);
                        tempTable.grade(i) = double(idridData.(gradeCol)(i));
                        tempTable.lesionMaskPaths{i} = '';
                        tempTable.sourceDataset(i) = "IDRiD";
                        tempTable.cameraType(i) = "Kowa VX-10a";
                        tempTable.originalSplit(i) = splitLabels{s};
                    end
                    datasetTable = [datasetTable; tempTable];
                end
            end
        end
    catch ME
        warning('Failed to load IDRiD: %s', ME.message);
    end
    
    % 3. Parse DRIVE
    try
        % DRIVE does not have DR grades (used for vessel segmentation only)
        splits = {'training', 'test'};
        for s = 1:2
            imgDir = '';
            candDirs = {
                fullfile(cfg.paths.rawDRIVE, splits{s}, 'images'), ...
                fullfile(cfg.paths.rawDRIVE, splits{s}, splits{s}, 'images'), ...
                fullfile(cfg.paths.rawDRIVE, splits{s})
            };
            for cd = 1:length(candDirs)
                if isfolder(candDirs{cd})
                    imgDir = candDirs{cd};
                    break;
                end
            end
            
            if ~isempty(imgDir)
                files = dir(fullfile(imgDir, '*.tif'));
                n = length(files);
                if n > 0
                    tempTable = table('Size', [n, length(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);
                    for i = 1:n
                        [~, name, ~] = fileparts(files(i).name);
                        tempTable.imagePath(i) = fullfile(imgDir, files(i).name);
                        tempTable.patientID(i) = string(name);
                        tempTable.grade(i) = NaN; % NaN grade for ungradable/segmentation-only images
                        
                        maskName = strrep(name, 'training', 'manual1'); % DRIVE typical naming
                        maskPath = fullfile(fileparts(imgDir), '1st_manual', maskName + ".gif");
                        if ~isfile(maskPath)
                            maskPath = fullfile(fileparts(imgDir), 'mask', strrep(name, 'training', 'training_mask') + ".gif");
                        end
                        tempTable.lesionMaskPaths{i} = maskPath;
                        
                        tempTable.sourceDataset(i) = "DRIVE";
                        tempTable.cameraType(i) = "Canon CR5 non-mydriatic";
                        tempTable.originalSplit(i) = string(splits{s});
                    end
                    datasetTable = [datasetTable; tempTable];
                end
            end
        end
    catch ME
        warning('Failed to load DRIVE: %s', ME.message);
    end
    
    % 4. Parse Messidor-2
    try
        % Messidor-2 has image IDs and grades, usually in messidor_data.csv
        messidorCsv = fullfile(cfg.paths.rawMessidor, 'messidor_data.csv');
        if isfile(messidorCsv)
            m2Data = readtable(messidorCsv);
            n = height(m2Data);
            
            m2ImgDir = '';
            candImgDirs = {
                fullfile(cfg.paths.rawMessidor, 'messidor-2', 'preprocess'), ...
                fullfile(cfg.paths.rawMessidor, 'IMAGES'), ...
                fullfile(cfg.paths.rawMessidor, 'images'), ...
                cfg.paths.rawMessidor
            };
            for md = 1:length(candImgDirs)
                if isfolder(candImgDirs{md})
                    m2ImgDir = candImgDirs{md};
                    break;
                end
            end
            
            tempTable = table('Size', [n, length(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);
            for i = 1:n
                imgId = string(m2Data.image_id{i});
                tempTable.imagePath(i) = fullfile(m2ImgDir, imgId);
                tempTable.patientID(i) = imgId;
                tempTable.grade(i) = m2Data.adjudicated_dr_grade(i);
                tempTable.lesionMaskPaths{i} = '';
                tempTable.sourceDataset(i) = "Messidor2";
                tempTable.cameraType(i) = "Topcon TRC NW6";
                tempTable.originalSplit(i) = "external";
            end
            datasetTable = [datasetTable; tempTable];
        end
    catch ME
        warning('Failed to load Messidor2: %s', ME.message);
    end
    
    % Remove missing files to avoid errors downstream
    validIdx = isfile(datasetTable.imagePath);
    datasetTable = datasetTable(validIdx, :);
    fprintf('Loaded %d images across %d datasets.\n', height(datasetTable), length(unique(datasetTable.sourceDataset)));
end
