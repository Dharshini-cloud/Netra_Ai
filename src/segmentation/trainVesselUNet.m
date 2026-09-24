function trainVesselUNet()
% TRAINVESSELUNET Trains U-Net on DRIVE dataset using modern MATLAB trainnet workflow.
% Normalizes inputs to [0, 1] and cleans undefined mask labels to prevent NaN loss.

    cfg = config();
    disp('Starting Vessel U-Net Training setup...');
    
    % Locate splits
    splitsPath = fullfile(cfg.paths.splits, 'train_index.mat');
    if ~isfile(splitsPath)
        error('Splits not found. Run buildPatientSplits first.');
    end
    data = load(splitsPath);
    train_index = data.train_index;
    
    % Filter DRIVE dataset
    driveIdx = train_index.sourceDataset == "DRIVE";
    driveData = train_index(driveIdx, :);
    
    if height(driveData) == 0
        error('No DRIVE data found in the train split. Check data loading.');
    end
    
    fprintf('Found %d DRIVE images for training.\n', height(driveData));
    
    % 1. Setup file paths
    imageFiles = driveData.imagePath;
    maskFiles  = string(driveData.lesionMaskPaths);
    maskFiles  = maskFiles(:)';  % 1xN row vector
    
    % Auto-detect vessel pixel value (255 or 1)
    sampleMask = imread(char(maskFiles(1)));
    vesselVal  = max(sampleMask(:));
    labelIDs   = [0, vesselVal];
    classNames = ["Background", "Vessel"];

    % 2. Create datastores using modern combine() approach
    imds = imageDatastore(imageFiles);
    pxds = pixelLabelDatastore(maskFiles, classNames, labelIDs);
    
    % Combine image + mask datastores
    dsCombined = combine(imds, pxds);
    
    % Preprocess: Resize, scale pixels to [0, 1], and clean undefined mask pixels
    targetSize = cfg.imageSize(1:2);
    dsTrain = transform(dsCombined, @(data) preprocessSegmentationData(data, targetSize));
    
    % 3. Create U-Net architecture (2 classes: Background, Vessel)
    numClasses = 2;
    if exist('unet', 'file') == 2 || exist('unet', 'builtin') == 5
        net = unet(cfg.imageSize, numClasses, 'EncoderDepth', 4);
    else
        net = unetLayers(cfg.imageSize, numClasses, 'EncoderDepth', 4);
    end
    
    % 4. Execution Hardware
    try
        gpu = gpuDevice();
        execEnv = 'gpu';
        fprintf('GPU detected (%s). Training U-Net on GPU.\n', gpu.Name);
    catch
        execEnv = 'cpu';
        disp('No compatible GPU detected. Training U-Net on CPU.');
    end
    
    % 5. Training Options (Stable learning rate + Adam solver)
    opts = trainingOptions('adam', ...
        'ExecutionEnvironment', execEnv, ...
        'InitialLearnRate', 5e-4, ...
        'GradientThreshold', 1, ...
        'MaxEpochs', 25, ...
        'MiniBatchSize', 2, ...
        'Shuffle', 'every-epoch', ...
        'Plots', 'training-progress', ...
        'Verbose', true);
        
    disp('Training U-Net (Deep Learning Training Progress window will open)...');
    
    % Train using modern trainnet (or trainNetwork fallback)
    if exist('trainnet', 'file') == 2 || exist('trainnet', 'builtin') == 5
        [vesselNet, info] = trainnet(dsTrain, net, "crossentropy", opts);
    else
        [vesselNet, info] = trainNetwork(dsTrain, net, opts);
    end
    % 6. Save trained model
    modelDir = cfg.paths.models;
    if ~isfolder(modelDir)
        mkdir(modelDir);
    end

    % Save the model
    save(fullfile(modelDir, 'vesselNet.mat'), 'vesselNet');

    % NEW: Automatically find the training plot window and save it as an image!
    trainFig = findall(groot, 'Type', 'Figure');
    if ~isempty(trainFig)
        saveas(trainFig(1), fullfile(modelDir, 'training_progress_graph.png'));
        disp('Training graph saved to models/training_progress_graph.png');
    end

    disp('Vessel U-Net trained and saved successfully to models/vesselNet.mat!');
   end

% --- Helper function: Normalize & Clean Data ---
function dataOut = preprocessSegmentationData(dataIn, targetSize)
    img  = dataIn{1};
    mask = dataIn{2};
    
    % Ensure 3 color channels
    if size(img, 3) == 1
        img = repmat(img, [1 1 3]);
    end
    
    % Resize and scale image pixels to single [0.0, 1.0] (prevents gradient explosion)
    imgResized = im2single(imresize(img, targetSize));
    
    % Resize mask using nearest neighbor to preserve discrete category labels
    maskResized = imresize(mask, targetSize, 'nearest');
    
    % Replace any undefined border/FOV pixels with 'Background' (prevents NaN loss)
    if any(isundefined(maskResized(:)))
        maskResized(isundefined(maskResized)) = "Background";
    end
    
    dataOut = {imgResized, maskResized};
end
