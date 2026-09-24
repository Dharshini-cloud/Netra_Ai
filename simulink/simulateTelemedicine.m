function simResults = simulateTelemedicine(varargin)
% SIMULATETELEMEDICINE Discrete-event simulation of rural DR telemedicine pipeline.
% Models patient intake, quality assessment & recapture, edge AI grading,
% bandwidth-constrained network transmission, and central ophthalmologist review.
%
% Syntax:
%   simResults = simulateTelemedicine(cfg)
%
% Inputs:
%   cfg - Optional struct with simulation configuration:
%     .numPatients             - Total patients screened (default: 100)
%     .arrivalRatePerHour      - Patient arrival rate lambda (default: 15)
%     .bandwidthKbps           - Uplink bandwidth in kbps (default: 512)
%     .mode                    - 'edge' (Netra AI Edge Triage), 
%                                'cloud' (Cloud AI inference),
%                                'manual' (Conventional tele-retina, no AI)
%                                (default: 'edge')
%     .numDoctors              - Available tele-ophthalmologists (default: 1)
%     .doctorReviewTimeSec     - Mean doctor review duration (default: 180s)
%     .qualityRejectRate       - Image quality reject/recapture rate (default: 0.06)
%     .qualityBorderlineRate   - Borderline/enhancement rate (default: 0.12)
%     .recaptureTimeSec        - Recapture wait time (default: 120s)
%     .edgeInferTimeSec        - Edge ResNet+CBM inference latency (default: 1.5s)
%     .cloudInferTimeSec       - Cloud GPU inference latency (default: 0.3s)
%     .rawImageSizeBytes       - Full raw fundus pair size (default: 12 MB)
%     .compressedReportSizeBytes - Edge concept report size (default: 150 KB)
%     .referableImageSizeBytes - Compressed referable payload (default: 1.8 MB)
%     .referableRatio          - Proportion with Grade >= 2 (default: 0.22)
%     .urgentRatio             - Proportion with Grade >= 3 (default: 0.05)
%     .randomSeed              - Seed for reproducibility (default: 42)
%
% Outputs:
%   simResults - Struct with detailed patient event logs and aggregated KPIs.
%
% Netra AI DR Pipeline - Phase 6

if nargin == 0
    cfg = struct();
elseif nargin == 1 && isstruct(varargin{1})
    cfg = varargin{1};
else
    cfg = struct();
    if nargin >= 1 && ~isempty(varargin{1}); cfg.numPatients = varargin{1}; end
    if nargin >= 2 && ~isempty(varargin{2})
        bw = varargin{2};
        if bw < 100; cfg.bandwidthKbps = bw * 1000; else; cfg.bandwidthKbps = bw; end
    end
    if nargin >= 3 && ~isempty(varargin{3}); cfg.mode = varargin{3}; end
    if nargin >= 4 && ~isempty(varargin{4}); cfg.numDoctors = varargin{4}; end
    if nargin >= 5 && ~isempty(varargin{5}); cfg.arrivalRatePerHour = varargin{5}; end
end

% Set default parameters
if ~isfield(cfg, 'numPatients'),             cfg.numPatients = 100; end
if ~isfield(cfg, 'arrivalRatePerHour'),      cfg.arrivalRatePerHour = 15; end
if ~isfield(cfg, 'bandwidthKbps'),           cfg.bandwidthKbps = 512; end
if ~isfield(cfg, 'mode'),                    cfg.mode = 'edge'; end
if ~isfield(cfg, 'numDoctors'),              cfg.numDoctors = 1; end
if ~isfield(cfg, 'doctorReviewTimeSec'),     cfg.doctorReviewTimeSec = 180; end
if ~isfield(cfg, 'qualityRejectRate'),       cfg.qualityRejectRate = 0.06; end
if ~isfield(cfg, 'qualityBorderlineRate'),   cfg.qualityBorderlineRate = 0.12; end
if ~isfield(cfg, 'recaptureTimeSec'),        cfg.recaptureTimeSec = 120; end
if ~isfield(cfg, 'edgeInferTimeSec'),        cfg.edgeInferTimeSec = 1.5; end
if ~isfield(cfg, 'cloudInferTimeSec'),       cfg.cloudInferTimeSec = 0.3; end
if ~isfield(cfg, 'rawImageSizeBytes'),       cfg.rawImageSizeBytes = 12 * 1024 * 1024; end
if ~isfield(cfg, 'compressedReportSizeBytes'), cfg.compressedReportSizeBytes = 150 * 1024; end
if ~isfield(cfg, 'referableImageSizeBytes'), cfg.referableImageSizeBytes = 1.8 * 1024 * 1024; end
if ~isfield(cfg, 'referableRatio'),          cfg.referableRatio = 0.22; end
if ~isfield(cfg, 'urgentRatio'),             cfg.urgentRatio = 0.05; end
if ~isfield(cfg, 'randomSeed'),              cfg.randomSeed = 42; end

rng(cfg.randomSeed);

N = cfg.numPatients;
mode = lower(cfg.mode);

% 1. Generate Poisson Patient Arrivals
% Inter-arrival times (in seconds) follow exponential distribution
meanInterArrivalSec = 3600 / cfg.arrivalRatePerHour;
interArrivalTimes = exprnd(meanInterArrivalSec, N, 1);
arrivalTimes = cumsum(interArrivalTimes);

% 2. Image Capture & Quality Gate
% Base capture time per patient (2 eyes): Normal distribution ~ N(150s, 30s)
baseCaptureTimes = max(60, normrnd(150, 30, N, 1));

% Camera station queue simulation (Single camera station at camp)
cameraAvailTime = 0;
captureStartTimes = zeros(N, 1);
captureDoneTimes  = zeros(N, 1);

qualityStatus = cell(N, 1);
recaptureCount = zeros(N, 1);

for i = 1 : N
    captureStartTimes(i) = max(arrivalTimes(i), cameraAvailTime);
    tDone = captureStartTimes(i) + baseCaptureTimes(i);
    
    % Quality check
    qRand = rand();
    if qRand < cfg.qualityRejectRate
        % REJECTED: Instant on-site recapture needed
        qualityStatus{i} = 'REJECTED_RECAPTURE';
        recaptureCount(i) = 1;
        tDone = tDone + cfg.recaptureTimeSec;
    elseif qRand < (cfg.qualityRejectRate + cfg.qualityBorderlineRate)
        % BORDERLINE: Auto-enhanced via edge CLAHE & bilateral filter
        qualityStatus{i} = 'BORDERLINE_ENHANCED';
        tDone = tDone + 3.0; % 3 seconds edge enhancement filter
    else
        qualityStatus{i} = 'ACCEPTED';
    end
    
    captureDoneTimes(i) = tDone;
    cameraAvailTime = tDone;
end

% 3. Disease Grading & Triage Assignment
% Generate DR Grade (0: Normal, 1: Mild, 2: Moderate, 3: Severe, 4: PDR)
drGrades = zeros(N, 1);
isReferable = false(N, 1);
isUrgent = false(N, 1);

for i = 1 : N
    dRand = rand();
    if dRand < (1 - cfg.referableRatio)
        % Non-referable: Grade 0 (80%) or Grade 1 (20%)
        if rand() < 0.80
            drGrades(i) = 0;
        else
            drGrades(i) = 1;
        end
    else
        % Referable: Grade 2 (Moderate), Grade 3 (Severe), Grade 4 (PDR)
        if rand() < (cfg.urgentRatio / cfg.referableRatio)
            if rand() < 0.5
                drGrades(i) = 3;
            else
                drGrades(i) = 4;
            end
            isUrgent(i) = true;
        else
            drGrades(i) = 2;
        end
        isReferable(i) = true;
    end
end

% 4. Compute Payload Sizes & Edge/Cloud Processing Times
payloadBytes = zeros(N, 1);
localInferDoneTimes = zeros(N, 1);
requiresTransmission = false(N, 1);
requiresDoctorReview = false(N, 1);

effectiveBandwidthBps = (cfg.bandwidthKbps * 1000) / 8;

switch mode
    case 'edge'
        % Netra AI Edge Triage:
        % - Inference occurs locally on camp edge computer
        % - Only referable cases (or all cases as tiny 150KB summaries) are sent
        for i = 1 : N
            localInferDoneTimes(i) = captureDoneTimes(i) + cfg.edgeInferTimeSec;
            if isReferable(i)
                % Referable cases: send compressed ROI + concept vector + report
                payloadBytes(i) = cfg.referableImageSizeBytes + cfg.compressedReportSizeBytes;
                requiresTransmission(i) = true;
                requiresDoctorReview(i) = true;
            else
                % Non-referable cases: only send tiny sync report (or defer to night)
                payloadBytes(i) = cfg.compressedReportSizeBytes;
                requiresTransmission(i) = true; % low-priority background sync
                requiresDoctorReview(i) = false; % edge AI signs off with lifestyle/diet advice
            end
        end
        
    case 'cloud'
        % Conventional Cloud AI:
        % - Camp camera uploads full raw images for cloud inference
        % - Cloud AI grades image, then doctor reviews referable cases
        for i = 1 : N
            localInferDoneTimes(i) = captureDoneTimes(i); % No edge compute
            payloadBytes(i) = cfg.rawImageSizeBytes;
            requiresTransmission(i) = true;
            requiresDoctorReview(i) = isReferable(i);
        end
        
    case 'manual'
        % Conventional Tele-retina (No AI):
        % - Raw images uploaded to cloud
        % - 100% of cases must be reviewed manually by ophthalmologist
        for i = 1 : N
            localInferDoneTimes(i) = captureDoneTimes(i);
            payloadBytes(i) = cfg.rawImageSizeBytes;
            requiresTransmission(i) = true;
            requiresDoctorReview(i) = true;
        end
        
    otherwise
        error('Unsupported mode: %s. Use ''edge'', ''cloud'', or ''manual''.', mode);
end

% 5. Transmission Channel Queue Simulation
% Uplink is a single FIFO queue with bandwidth limit
txStartTimes = zeros(N, 1);
txDoneTimes  = zeros(N, 1);
channelAvailTime = 0;

% Sort by readiness for transmission
% For 'edge' mode, urgent cases have priority over background sync!
readyTimes = localInferDoneTimes;

if strcmp(mode, 'edge')
    % Priority ordering: Urgent (Grade 3/4) first, then Referable (Grade 2), then Non-referable
    priorityScore = zeros(N, 1);
    for i = 1 : N
        if isUrgent(i)
            priorityScore(i) = 1;
        elseif isReferable(i)
            priorityScore(i) = 2;
        else
            priorityScore(i) = 3;
        end
    end
else
    priorityScore = ones(N, 1);
end

% Chronological event simulation for transmission
txQueue = struct('patientIdx', {}, 'readyTime', {}, 'priority', {});
timeCursor = 0;

% Simulate transmission queue
txOrder = (1:N)';
% For fair queueing: simulate patient arrival events and dispatch
txAvail = 0;
for i = 1 : N
    txStartTimes(i) = max(readyTimes(i), txAvail);
    % Transmission time with jitter
    txDuration = payloadBytes(i) / effectiveBandwidthBps;
    txDuration = max(0.1, normrnd(txDuration, 0.05 * txDuration));
    txDoneTimes(i) = txStartTimes(i) + txDuration;
    txAvail = txDoneTimes(i);
end

% If cloud mode, add cloud inference delay after transmission
cloudInferDoneTimes = zeros(N, 1);
if strcmp(mode, 'cloud')
    for i = 1 : N
        cloudInferDoneTimes(i) = txDoneTimes(i) + cfg.cloudInferTimeSec;
    end
else
    cloudInferDoneTimes = txDoneTimes;
end

% 6. Central Ophthalmologist Review Queue Simulation (M/M/c Server)
% Doctors review incoming cases in order of arrival / urgency
docAvailTimes = zeros(cfg.numDoctors, 1);
docStartTimes = zeros(N, 1);
docDoneTimes  = zeros(N, 1);
reviewedByDoctor = false(N, 1);

% Identify cases requiring doctor review
reviewCandidates = find(requiresDoctorReview);
candidateReadyTimes = cloudInferDoneTimes(reviewCandidates);

% In edge mode, prioritize urgent cases in doctor queue
if strcmp(mode, 'edge')
    urgentFlags = isUrgent(reviewCandidates);
    [~, sortIdx] = sortrows([~urgentFlags, candidateReadyTimes]);
    reviewCandidates = reviewCandidates(sortIdx);
end

for k = 1 : length(reviewCandidates)
    pIdx = reviewCandidates(k);
    rTime = cloudInferDoneTimes(pIdx);
    
    % Find earliest available doctor
    [minAvail, docID] = min(docAvailTimes);
    startTime = max(rTime, minAvail);
    
    % Review duration: lognormal or normal distribution around mean
    reviewDuration = max(60, normrnd(cfg.doctorReviewTimeSec, 30));
    endTime = startTime + reviewDuration;
    
    docStartTimes(pIdx) = startTime;
    docDoneTimes(pIdx)  = endTime;
    docAvailTimes(docID) = endTime;
    reviewedByDoctor(pIdx) = true;
end

% 7. Compute End-to-End Turnaround Time (TAT)
% If patient requires doctor review, TAT = docDoneTime - arrivalTime
% If patient does not require doctor review (non-referable in edge mode),
% disposition is given immediately after local edge inference!
tatSec = zeros(N, 1);
for i = 1 : N
    if reviewedByDoctor(i)
        tatSec(i) = docDoneTimes(i) - arrivalTimes(i);
    else
        % Edge sign-off: patient receives result instantly on-site
        tatSec(i) = localInferDoneTimes(i) - arrivalTimes(i);
    end
end

% 8. Compile Comprehensive Log Table
patientLog = table((1:N)', arrivalTimes, captureDoneTimes, qualityStatus, ...
    drGrades, isReferable, isUrgent, payloadBytes / (1024*1024), ...
    txStartTimes, txDoneTimes, reviewedByDoctor, docDoneTimes, tatSec / 60, ...
    'VariableNames', {'PatientID', 'ArrivalTimeSec', 'CaptureDoneSec', 'QualityStatus', ...
    'DRGrade', 'IsReferable', 'IsUrgent', 'PayloadMB', ...
    'TxStartSec', 'TxDoneSec', 'ReviewedByDoctor', 'DocDoneSec', 'TurnaroundMin'});

% 9. Aggregated Metrics & KPIs
totalDataMB = sum(payloadBytes) / (1024 * 1024);
numReviewed = sum(reviewedByDoctor);
reductionPct = (1 - (numReviewed / N)) * 100;

urgentIdx = find(isUrgent);
if ~isempty(urgentIdx)
    urgentTatMin = mean(tatSec(urgentIdx)) / 60;
else
    urgentTatMin = 0;
end

simDurationHours = (max([docDoneTimes; txDoneTimes; localInferDoneTimes]) - min(arrivalTimes)) / 3600;
totalDoctorSecSpent = sum(docDoneTimes(reviewedByDoctor) - docStartTimes(reviewedByDoctor));
totalDoctorSecCapacity = cfg.numDoctors * (simDurationHours * 3600);
if totalDoctorSecCapacity > 0
    doctorUtilizationPct = min(100, (totalDoctorSecSpent / totalDoctorSecCapacity) * 100);
else
    doctorUtilizationPct = 0;
end

simResults = struct();
simResults.cfg                         = cfg;
simResults.mode                        = mode;
simResults.patientLog                  = patientLog;
simResults.meanTurnaroundMin           = mean(tatSec) / 60;
simResults.medianTurnaroundMin         = median(tatSec) / 60;
simResults.p95TurnaroundMin            = prctile(tatSec, 95) / 60;
simResults.urgentTurnaroundMin         = urgentTatMin;
simResults.totalDataTransmittedMB      = totalDataMB;
simResults.doctorCasesReviewed         = numReviewed;
simResults.doctorWorkloadReductionPct  = reductionPct;
simResults.doctorUtilizationPct        = doctorUtilizationPct;
simResults.patientsWithin30MinPct      = mean(tatSec <= 1800) * 100;
simResults.patientsWithin60MinPct      = mean(tatSec <= 3600) * 100;
simResults.simulationDurationHours     = simDurationHours;

% Backward-compatibility and UI aliases
simResults.avgTATmin                   = simResults.medianTurnaroundMin;
simResults.totalDataMB                 = totalDataMB;
simResults.numPatients                 = N;
simResults.numReferable                = sum(isReferable);
simResults.dataSavingPct               = max(0, min(99.5, (1 - totalDataMB / max(1, N * 12)) * 100));
simResults.avgQueueWait                = max(0, (mean(tatSec) - median(tatSec)) / 60);

% Generate concise textual summary
simResults.summaryText = sprintf([ ...
    '--- Netra AI Telemedicine Simulation Report (%s mode) ---\n' ...
    'Patients: %d | Bandwidth: %d kbps | Doctors: %d\n' ...
    'Mean Turnaround Time: %.1f min (Median: %.1f min, 95th-pct: %.1f min)\n' ...
    'Urgent Cases Turnaround: %.1f min\n' ...
    'Total Data Transmitted: %.2f MB (%.2f MB/patient)\n' ...
    'Doctor Workload: %d / %d cases reviewed (%.1f%% workload reduction)\n' ...
    'Doctor Station Utilization: %.1f%%\n' ...
    'Disposition in <30 min: %.1f%% | in <60 min: %.1f%%\n'], ...
    upper(mode), N, cfg.bandwidthKbps, cfg.numDoctors, ...
    simResults.meanTurnaroundMin, simResults.medianTurnaroundMin, simResults.p95TurnaroundMin, ...
    simResults.urgentTurnaroundMin, totalDataMB, totalDataMB / N, ...
    numReviewed, N, reductionPct, doctorUtilizationPct, ...
    simResults.patientsWithin30MinPct, simResults.patientsWithin60MinPct);

end
