function cfg = config()
% CONFIG Global configuration for Netra AI DR pipeline
% Returns a struct containing all global settings and paths

    cfg = struct();
    
    % Image resolution for standard CNN processing
    cfg.imageSize = [512, 512, 3];
    
    % Random seed for reproducibility
    cfg.randomSeed = 42;
    
    % Class labels (ICDR grades)
    cfg.classLabels = [0, 1, 2, 3, 4];
    cfg.classNames = {'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};
    
    % Dynamic base directory of this configuration file
    baseDir = fileparts(mfilename('fullpath'));
    cfg.paths.rootDir = baseDir;
    cfg.paths.rawAPTOS = fullfile(baseDir, 'data', 'raw', 'APTOS2019');
    cfg.paths.rawIDRiD = fullfile(baseDir, 'data', 'raw', 'IDRiD');
    cfg.paths.rawDRIVE = fullfile(baseDir, 'data', 'raw', 'DRIVE');
    cfg.paths.rawMessidor = fullfile(baseDir, 'data', 'raw', 'Messidor2');
    
    % Processed paths
    cfg.paths.data            = fullfile(baseDir, 'data');
    cfg.paths.processed       = fullfile(baseDir, 'data', 'processed');
    cfg.paths.processedImages = fullfile(baseDir, 'data', 'processed', 'images');
    cfg.paths.processedMasks  = fullfile(baseDir, 'data', 'processed', 'masks');
    cfg.paths.splits          = fullfile(baseDir, 'data', 'splits');
    cfg.paths.twinstore       = fullfile(baseDir, 'data', 'twinstore');
    cfg.paths.models          = fullfile(baseDir, 'models');
    cfg.paths.reports         = fullfile(baseDir, 'reports');
    cfg.paths.validation      = fullfile(baseDir, 'validation');
end
