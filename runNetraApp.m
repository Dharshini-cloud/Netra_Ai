function runNetraApp(varargin)
%RUNNETRAAPP Convenience alias for launchNetra.
%   runNetraApp()                    — opens with auto-selected demo image
%   runNetraApp('path/to/image.png') — opens with specified fundus image
if nargin >= 1
    launchNetra(varargin{1});
else
    launchNetra();
end
end
