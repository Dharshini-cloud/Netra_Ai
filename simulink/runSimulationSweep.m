function sweepResults = runSimulationSweep()
% RUNSIMULATIONSWEEP Executes multi-parameter simulation sweep for Phase 6.
% Compares Netra AI Edge Triage against Conventional Cloud AI and Manual
% Tele-Ophthalmology across varying bandwidths, patient volumes, and doctor staffing.
%
% Generates publication-quality multi-panel visualization plots and saves
% comprehensive metrics to simulink/simulation_results.mat.
%
% Syntax:
%   sweepResults = runSimulationSweep()
%
% Outputs:
%   sweepResults - Struct containing:
%     .bandwidthSweep - Comparison table across bandwidth levels (64 - 10000 kbps)
%     .volumeSweep    - Comparison table across screening camp volumes (25 - 200 pts)
%     .doctorSweep    - Comparison table across specialist doctor staffing (1 - 3 docs)
%     .rawSims        - Cell array of raw simulation objects
%
% Netra AI DR Pipeline - Phase 6

fprintf('\n============================================================\n');
fprintf('   NETRA AI DR - TELEMEDICINE WORKFLOW SIMULATION SWEEP    \n');
fprintf('============================================================\n\n');

% Ensure simulink directory is in path
simDir = fileparts(mfilename('fullpath'));
addpath(simDir);

% -------------------------------------------------------------
% Sweep 1: Network Bandwidth Sensitivity (64 kbps to 10 Mbps)
% -------------------------------------------------------------
fprintf('--> Running Sweep 1: Network Bandwidth Sensitivity...\n');
bandwidths = [64, 128, 256, 512, 1024, 2048, 5000, 10000]; % kbps
modes = {'edge', 'cloud', 'manual'};
modeLabels = {'Netra AI Edge-Triage', 'Cloud AI Inference', 'Manual Tele-Retina'};

bwResults = struct();
for m = 1 : length(modes)
    currentMode = modes{m};
    tatMeans   = zeros(length(bandwidths), 1);
    tatP95s    = zeros(length(bandwidths), 1);
    urgentTats = zeros(length(bandwidths), 1);
    dataMBs    = zeros(length(bandwidths), 1);
    docReviews = zeros(length(bandwidths), 1);
    pctUnder30 = zeros(length(bandwidths), 1);
    
    for b = 1 : length(bandwidths)
        cfg = struct();
        cfg.numPatients        = 100;
        cfg.arrivalRatePerHour = 15;
        cfg.bandwidthKbps      = bandwidths(b);
        cfg.mode               = currentMode;
        cfg.numDoctors         = 1;
        cfg.randomSeed         = 42; % constant seed for strict parity
        
        res = simulateTelemedicine(cfg);
        
        tatMeans(b)   = res.meanTurnaroundMin;
        tatP95s(b)    = res.p95TurnaroundMin;
        urgentTats(b) = res.urgentTurnaroundMin;
        dataMBs(b)    = res.totalDataTransmittedMB;
        docReviews(b) = res.doctorCasesReviewed;
        pctUnder30(b) = res.patientsWithin30MinPct;
    end
    
    bwResults.(currentMode).bandwidths = bandwidths;
    bwResults.(currentMode).meanTAT    = tatMeans;
    bwResults.(currentMode).p95TAT     = tatP95s;
    bwResults.(currentMode).urgentTAT  = urgentTats;
    bwResults.(currentMode).dataMB     = dataMBs;
    bwResults.(currentMode).docReviews = docReviews;
    bwResults.(currentMode).pctUnder30 = pctUnder30;
end

% -------------------------------------------------------------
% Sweep 2: Screening Camp Patient Volume (25 to 200 patients/day)
% -------------------------------------------------------------
fprintf('--> Running Sweep 2: Patient Volume Sensitivity...\n');
volumes = [25, 50, 100, 150, 200];
volResults = struct();

for m = 1 : length(modes)
    currentMode = modes{m};
    tatMeans = zeros(length(volumes), 1);
    dataMBs  = zeros(length(volumes), 1);
    docUtil  = zeros(length(volumes), 1);
    
    for v = 1 : length(volumes)
        cfg = struct();
        cfg.numPatients        = volumes(v);
        cfg.arrivalRatePerHour = 15;
        cfg.bandwidthKbps      = 512; % Typical rural 3G/4G
        cfg.mode               = currentMode;
        cfg.numDoctors         = 1;
        cfg.randomSeed         = 42;
        
        res = simulateTelemedicine(cfg);
        tatMeans(v) = res.meanTurnaroundMin;
        dataMBs(v)  = res.totalDataTransmittedMB;
        docUtil(v)  = res.doctorUtilizationPct;
    end
    
    volResults.(currentMode).volumes = volumes;
    volResults.(currentMode).meanTAT = tatMeans;
    volResults.(currentMode).dataMB  = dataMBs;
    volResults.(currentMode).docUtil = docUtil;
end

% -------------------------------------------------------------
% Sweep 3: Doctor Staffing Level (1 to 3 Ophthalmologists)
% -------------------------------------------------------------
fprintf('--> Running Sweep 3: Doctor Staffing Sensitivity...\n');
doctorCounts = [1, 2, 3];
docResults = struct();

for m = 1 : length(modes)
    currentMode = modes{m};
    tatMeans = zeros(length(doctorCounts), 1);
    docUtil  = zeros(length(doctorCounts), 1);
    
    for d = 1 : length(doctorCounts)
        cfg = struct();
        cfg.numPatients        = 100;
        cfg.arrivalRatePerHour = 15;
        cfg.bandwidthKbps      = 512;
        cfg.mode               = currentMode;
        cfg.numDoctors         = doctorCounts(d);
        cfg.randomSeed         = 42;
        
        res = simulateTelemedicine(cfg);
        tatMeans(d) = res.meanTurnaroundMin;
        docUtil(d)  = res.doctorUtilizationPct;
    end
    
    docResults.(currentMode).doctors = doctorCounts;
    docResults.(currentMode).meanTAT = tatMeans;
    docResults.(currentMode).docUtil = docUtil;
end

% -------------------------------------------------------------
% Visualizations: 4-Panel High-Impact Figure
% -------------------------------------------------------------
fprintf('--> Generating Multi-Panel Visualization Figure...\n');
f = figure('Name', 'Netra AI Telemedicine Pipeline Simulation', ...
           'Position', [100, 100, 1100, 850], 'Color', [0.97, 0.98, 1.0], 'Visible', 'off');

colors = [0.12, 0.53, 0.90;   % Netra Blue
          0.93, 0.49, 0.19;   % Amber/Orange Cloud
          0.85, 0.20, 0.20];  % Red Manual

% Subplot 1: Turnaround Time vs Bandwidth (Log Scale)
subplot(2, 2, 1);
hold on; grid on; box on;
set(gca, 'XScale', 'log', 'FontSize', 10, 'LineWidth', 1.0);
for m = 1 : 3
    plot(bandwidths, bwResults.(modes{m}).meanTAT, '-o', ...
        'Color', colors(m, :), 'LineWidth', 2.2, 'MarkerSize', 6, 'MarkerFaceColor', colors(m, :));
end
xlabel('Network Bandwidth (kbps, log scale)', 'FontWeight', 'bold');
ylabel('Mean Turnaround Time (min)', 'FontWeight', 'bold');
title('1. End-to-End Patient TAT vs. Bandwidth', 'FontSize', 11, 'FontWeight', 'bold');
legend(modeLabels, 'Location', 'northeast', 'FontSize', 9);
xlim([50, 12000]);

% Subplot 2: Bandwidth Data Consumption per 100 Patients
subplot(2, 2, 2);
hold on; grid on; box on;
barData = [bwResults.edge.dataMB(1), bwResults.cloud.dataMB(1), bwResults.manual.dataMB(1)];
bObj = bar(categorical(modeLabels), barData);
bObj.FaceColor = 'flat';
bObj.CData(1, :) = colors(1, :);
bObj.CData(2, :) = colors(2, :);
bObj.CData(3, :) = colors(3, :);
ylabel('Total Data Transmitted (MB)', 'FontWeight', 'bold');
title('2. Network Data Transmitted (100 Patients)', 'FontSize', 11, 'FontWeight', 'bold');
for i = 1 : 3
    text(i, barData(i) + 30, sprintf('%.1f MB', barData(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 10);
end
ylim([0, max(barData) * 1.25]);

% Subplot 3: Urgent Case Escalation Time vs Bandwidth
subplot(2, 2, 3);
hold on; grid on; box on;
set(gca, 'XScale', 'log', 'FontSize', 10, 'LineWidth', 1.0);
for m = 1 : 3
    plot(bandwidths, bwResults.(modes{m}).urgentTAT, '-s', ...
        'Color', colors(m, :), 'LineWidth', 2.2, 'MarkerSize', 6, 'MarkerFaceColor', colors(m, :));
end
xlabel('Network Bandwidth (kbps, log scale)', 'FontWeight', 'bold');
ylabel('Urgent Case Disposition (min)', 'FontWeight', 'bold');
title('3. Severe / PDR Case Urgent Escalation Delay', 'FontSize', 11, 'FontWeight', 'bold');
legend(modeLabels, 'Location', 'northeast', 'FontSize', 9);
xlim([50, 12000]);

% Subplot 4: Doctor Workload & Queue Backlog across Screening Volume
subplot(2, 2, 4);
hold on; grid on; box on;
for m = 1 : 3
    plot(volumes, volResults.(modes{m}).meanTAT, '-^', ...
        'Color', colors(m, :), 'LineWidth', 2.2, 'MarkerSize', 6, 'MarkerFaceColor', colors(m, :));
end
xlabel('Screening Camp Daily Volume (patients)', 'FontWeight', 'bold');
ylabel('Mean Turnaround Time (min)', 'FontWeight', 'bold');
title('4. Scalability: Turnaround Time vs Daily Patient Volume', 'FontSize', 11, 'FontWeight', 'bold');
legend(modeLabels, 'Location', 'northwest', 'FontSize', 9);

% Save Figure
figPath = fullfile(simDir, 'telemedicine_simulation_results.png');
try
    exportgraphics(f, figPath, 'Resolution', 300);
    fprintf('Saved simulation plots to: %s\n', figPath);
catch
    saveas(f, figPath);
    fprintf('Saved simulation plots via saveas to: %s\n', figPath);
end
close(f);

% -------------------------------------------------------------
% Save Numerical Sweep Results MAT file
% -------------------------------------------------------------
matPath = fullfile(simDir, 'simulation_results.mat');
sweepResults = struct();
sweepResults.bwResults  = bwResults;
sweepResults.volResults = volResults;
sweepResults.docResults = docResults;
sweepResults.timestamp  = datestr(now);
save(matPath, 'sweepResults');
fprintf('Saved numerical simulation data to: %s\n\n', matPath);

% -------------------------------------------------------------
% Print Clinical Performance Comparison Table
% -------------------------------------------------------------
fprintf('========================================================================================\n');
fprintf('   TELEMEDICINE PERFORMANCE COMPARISON TABLE (100 Patients, 512 kbps Rural 3G/4G)       \n');
fprintf('========================================================================================\n');
fprintf('%-24s | %-12s | %-12s | %-14s | %-12s\n', ...
    'Architecture', 'Mean TAT', 'Urgent TAT', 'Data Volume', 'Doc Reviews');
fprintf('----------------------------------------------------------------------------------------\n');

% Extract at 512 kbps (index 4)
bIdx = 4;
for m = 1 : 3
    curM = modes{m};
    fprintf('%-24s | %8.1f min | %8.1f min | %10.1f MB | %6d / 100\n', ...
        modeLabels{m}, ...
        bwResults.(curM).meanTAT(bIdx), ...
        bwResults.(curM).urgentTAT(bIdx), ...
        bwResults.(curM).dataMB(bIdx), ...
        bwResults.(curM).docReviews(bIdx));
end
fprintf('========================================================================================\n');
fprintf('KEY FINDINGS:\n');
savingsPct = (1 - (bwResults.edge.dataMB(bIdx) / bwResults.manual.dataMB(bIdx))) * 100;
tatSpeedup = bwResults.manual.meanTAT(bIdx) / bwResults.edge.meanTAT(bIdx);
fprintf('- Netra AI Edge Triage reduces network bandwidth consumption by %.1f%%.\n', savingsPct);
fprintf('- Turnaround time is %.1fx faster than conventional tele-retina.\n', tatSpeedup);
fprintf('- 100%% of non-referable patients receive instant on-site counseling without specialist burden.\n');
fprintf('========================================================================================\n\n');

end
