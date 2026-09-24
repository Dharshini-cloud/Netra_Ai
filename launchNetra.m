function launchNetra(varargin)
%LAUNCHNETRA Launch the Netra AI DR Clinical & Telemedicine Platform.
%   launchNetra()                    — opens with auto-selected demo image
%   launchNetra('path/to/image.png') — opens with specified fundus image
%
%   Netra AI DR Platform — Phase 11
fprintf('====================================================\n');
fprintf('   Launching Netra AI DR Clinical & Telemedicine App \n');
fprintf('====================================================\n');

rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(rootDir,'src')));
addpath(genpath(fullfile(rootDir,'app')));
addpath(genpath(fullfile(rootDir,'simulink')));
addpath(genpath(fullfile(rootDir,'validation')));

if nargin >= 1 && ~isempty(varargin{1})
    app = NetraApp(varargin{1});
else
    app = NetraApp();
end
end
