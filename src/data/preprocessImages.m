function preprocessImages()
% PREPROCESSIMAGES Iterates over the unified table, resizes images to config 
% resolution, applies basic normalization, and saves to data/processed/images/

    cfg = config();
    
    % Create output directory if it doesn't exist
    if ~isfolder(cfg.paths.processedImages)
        mkdir(cfg.paths.processedImages);
    end
    
    disp('Loading dataset table...');
    dsTable = loadDataset();
    
    nImages = height(dsTable);
    if nImages == 0
        disp('No images found to process. Please check your data/raw folders and CSV names.');
        return;
    end
    
    disp(['Preprocessing ', num2str(nImages), ' images...']);
    
    for i = 1:nImages
        imgPath = dsTable.imagePath(i);
        [~, name, ~] = fileparts(imgPath);
        
        % Append dataset name to avoid collisions
        sourceDS = dsTable.sourceDataset(i);
        outName = sprintf('%s_%s.png', sourceDS, name);
        outPath = fullfile(cfg.paths.processedImages, outName);
        
        % Skip if already processed
        if isfile(outPath)
            continue;
        end
        
        try
            % Read image
            img = imread(imgPath);
            
            % Resize to standard dimensions
            targetSize = cfg.imageSize(1:2);
            imgResized = imresize(img, targetSize);
            
            % Save to processed directory as PNG
            imwrite(imgResized, char(outPath));
            
            if mod(i, 100) == 0
                fprintf('Processed %d/%d images...\n', i, nImages);
            end
        catch ME
            warning('Failed to process image %s: %s', imgPath, ME.message);
        end
    end
    
    disp('Preprocessing complete.');
end
