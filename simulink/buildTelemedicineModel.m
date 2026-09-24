function success = buildTelemedicineModel(modelName)
% BUILDTELEMEDICINEMODEL Programmatically constructs the Simulink block diagram
% for the Netra AI rural telemedicine pipeline (NetraTelemedicinePipeline.slx).
%
% Visualizes and models:
%   1. Patient Arrival Generator (Poisson process)
%   2. Fundus Camera & Quality Gate Subsystem (with on-site recapture loop)
%   3. Edge AI Inference & Concept Bottleneck Engine (ResNet-50 + CBM)
%   4. Triage Decision Switch (Referable vs. Non-Referable triage)
%   5. Bandwidth Channel FIFO Queue & Transmission Throttler
%   6. Tele-Ophthalmologist Review Queue & Diagnosis Station
%   7. Telemetry Scopes (TAT, Queue Lengths, Bandwidth Monitor)
%
% Syntax:
%   success = buildTelemedicineModel()
%   success = buildTelemedicineModel('NetraTelemedicinePipeline')
%
% Netra AI DR Pipeline - Phase 6

if nargin < 1 || isempty(modelName)
    modelName = 'NetraTelemedicinePipeline';
end

fprintf('=== Netra AI: Building Simulink Telemedicine Model [%s] ===\n', modelName);

% Check Simulink availability
if ~exist('new_system', 'file') || ~license('test', 'Simulink')
    warning('Simulink is not available or licensed in the current MATLAB session. Skipping .slx binary generation.');
    success = false;
    return;
end

try
    % Close if already open
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    
    % Create new system
    new_system(modelName);
    open_system(modelName);
    
    % Configure solver parameters for discrete-event/discrete-step simulation
    set_param(modelName, 'SolverType', 'Fixed-step');
    set_param(modelName, 'Solver', 'FixedStepDiscrete');
    set_param(modelName, 'FixedStep', '1.0'); % 1 second resolution
    set_param(modelName, 'StopTime', '28800'); % 8-hour screening camp day (28,800 sec)
    
    % --- Block 1: Patient Arrival Generator (Random/Poisson) ---
    bArrival = [modelName, '/PatientArrivalGenerator'];
    add_block('simulink/Sources/Band-Limited White Noise', bArrival, ...
        'Position', [40, 100, 120, 150], ...
        'Cov', '1.0', 'Ts', '1.0');
    
    % --- Block 2: Camera Capture & Quality Gate Subsystem ---
    bQuality = [modelName, '/QualityGateSubsystem'];
    add_block('simulink/Ports & Subsystems/Subsystem', bQuality, ...
        'Position', [180, 85, 300, 165]);
    
    % Configure Quality Subsystem internals
    qSubIn  = [bQuality, '/In1'];
    qSubOut = [bQuality, '/Out1'];
    delete_line(bQuality, 'In1/1', 'Out1/1');
    
    bQCheck = [bQuality, '/QualityClassifier'];
    add_block('simulink/Discontinuities/Saturation', bQCheck, ...
        'Position', [100, 40, 150, 80], ...
        'UpperLimit', '1.0', 'LowerLimit', '0.0');
    
    bRecapture = [bQuality, '/RecaptureLoop'];
    add_block('simulink/Discrete/Discrete Filter', bRecapture, ...
        'Position', [200, 40, 260, 80]);
        
    add_line(bQuality, 'In1/1', 'QualityClassifier/1');
    add_line(bQuality, 'QualityClassifier/1', 'RecaptureLoop/1');
    add_line(bQuality, 'RecaptureLoop/1', 'Out1/1');
    
    % --- Block 3: Edge AI Inference Engine ---
    bEdgeAI = [modelName, '/EdgeAIEngine'];
    add_block('simulink/Ports & Subsystems/Subsystem', bEdgeAI, ...
        'Position', [360, 85, 480, 165]);
        
    eSubIn  = [bEdgeAI, '/In1'];
    eSubOut = [bEdgeAI, '/Out1'];
    delete_line(bEdgeAI, 'In1/1', 'Out1/1');
    
    bCBM = [bEdgeAI, '/ConceptBottleneckInference'];
    add_block('simulink/Math Operations/Gain', bCBM, ...
        'Position', [100, 40, 160, 80], ...
        'Gain', '1.0');
    add_line(bEdgeAI, 'In1/1', 'ConceptBottleneckInference/1');
    add_line(bEdgeAI, 'ConceptBottleneckInference/1', 'Out1/1');

    % --- Block 4: Triage Decision Switch ---
    bSwitch = [modelName, '/TriageDecisionSwitch'];
    add_block('simulink/Signal Routing/Switch', bSwitch, ...
        'Position', [540, 95, 600, 155], ...
        'Criteria', 'u2 >= Threshold', 'Threshold', '2.0'); % Grade >= 2 is Referable
    
    bRefConst = [modelName, '/ReferablePayload_1.8MB'];
    add_block('simulink/Sources/Constant', bRefConst, ...
        'Position', [480, 40, 520, 70], 'Value', '1.8');
        
    bNonRefConst = [modelName, '/NonReferablePayload_0.15MB'];
    add_block('simulink/Sources/Constant', bNonRefConst, ...
        'Position', [480, 180, 520, 210], 'Value', '0.15');

    % --- Block 5: Bandwidth Channel & Network Buffer ---
    bChannel = [modelName, '/BandwidthChannelQueue'];
    add_block('simulink/Ports & Subsystems/Subsystem', bChannel, ...
        'Position', [660, 95, 780, 155]);
        
    cSubIn  = [bChannel, '/In1'];
    cSubOut = [bChannel, '/Out1'];
    delete_line(bChannel, 'In1/1', 'Out1/1');
    
    bQueue = [bChannel, '/FIFO_TransmissionBuffer'];
    add_block('simulink/Discrete/Unit Delay', bQueue, ...
        'Position', [100, 40, 140, 80]);
        
    bBandwidthLimiter = [bChannel, '/BandwidthThrottler'];
    add_block('simulink/Discontinuities/Rate Limiter', bBandwidthLimiter, ...
        'Position', [180, 40, 240, 80], ...
        'RisingSlewLimit', '64', 'FallingSlewLimit', '-64'); % kB/s for 512kbps
        
    add_line(bChannel, 'In1/1', 'FIFO_TransmissionBuffer/1');
    add_line(bChannel, 'FIFO_TransmissionBuffer/1', 'BandwidthThrottler/1');
    add_line(bChannel, 'BandwidthThrottler/1', 'Out1/1');

    % --- Block 6: Tele-Ophthalmologist Review Station ---
    bDoctor = [modelName, '/OphthalmologistReviewStation'];
    add_block('simulink/Ports & Subsystems/Subsystem', bDoctor, ...
        'Position', [840, 95, 960, 155]);
        
    dSubIn  = [bDoctor, '/In1'];
    dSubOut = [bDoctor, '/Out1'];
    delete_line(bDoctor, 'In1/1', 'Out1/1');
    
    bDocQueue = [bDoctor, '/DoctorReviewQueue'];
    add_block('simulink/Discrete/Integer Delay', bDocQueue, ...
        'Position', [100, 40, 150, 80], 'NumDelays', '180'); % 180s review
    add_line(bDoctor, 'In1/1', 'DoctorReviewQueue/1');
    add_line(bDoctor, 'DoctorReviewQueue/1', 'Out1/1');

    % --- Block 7: Telemetry & Monitoring Scopes ---
    bTATScope = [modelName, '/TurnaroundTimeScope'];
    add_block('simulink/Sinks/Scope', bTATScope, ...
        'Position', [1020, 60, 1070, 110]);
        
    bQueueScope = [modelName, '/QueueDepthScope'];
    add_block('simulink/Sinks/Scope', bQueueScope, ...
        'Position', [1020, 140, 1070, 190]);
        
    bWorkspaceLog = [modelName, '/ToWorkspace_Telemetry'];
    add_block('simulink/Sinks/To Workspace', bWorkspaceLog, ...
        'Position', [1020, 220, 1100, 260], ...
        'VariableName', 'simTelemedTelemetry', ...
        'SaveFormat', 'Timeseries');

    % --- Connect System-Level Lines ---
    add_line(modelName, 'PatientArrivalGenerator/1', 'QualityGateSubsystem/1');
    add_line(modelName, 'QualityGateSubsystem/1', 'EdgeAIEngine/1');
    
    add_line(modelName, 'ReferablePayload_1.8MB/1', 'TriageDecisionSwitch/1');
    add_line(modelName, 'EdgeAIEngine/1', 'TriageDecisionSwitch/2');
    add_line(modelName, 'NonReferablePayload_0.15MB/1', 'TriageDecisionSwitch/3');
    
    add_line(modelName, 'TriageDecisionSwitch/1', 'BandwidthChannelQueue/1');
    add_line(modelName, 'BandwidthChannelQueue/1', 'OphthalmologistReviewStation/1');
    
    add_line(modelName, 'OphthalmologistReviewStation/1', 'TurnaroundTimeScope/1');
    add_line(modelName, 'BandwidthChannelQueue/1', 'QueueDepthScope/1');
    add_line(modelName, 'OphthalmologistReviewStation/1', 'ToWorkspace_Telemetry/1');

    % Save model
    slxPath = fullfile(fileparts(mfilename('fullpath')), [modelName, '.slx']);
    save_system(modelName, slxPath);
    close_system(modelName);
    
    fprintf('Successfully built and saved Simulink model: %s\n', slxPath);
    success = true;
    
catch ME
    warning('Error building Simulink model: %s\nUsing programmatic discrete-event engine.', ME.message);
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    success = false;
end

end
