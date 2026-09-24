function progressDashboard(patientID)
% PROGRESSDASHBOARD Plots grade/lesion-count trends per patient and cohort.
% If patientID is provided, shows that individual patient's longitudinal trends.
% If patientID is omitted or 'all', shows cohort-level summary statistics.
%
% Input:
%   patientID - (Optional) string patient ID, or 'all' / omitted for cohort view

    showCohort = nargin < 1 || isempty(patientID) || strcmpi(patientID, 'all');

    if showCohort
        plotCohortDashboard();
    else
        plotPatientDashboard(patientID);
    end
end

% ==========================================================================
function plotPatientDashboard(patientID)
    try
        record = twinStore('read', patientID);
    catch ME
        error('Cannot load twin record for %s: %s', patientID, ME.message);
    end

    if record.numVisits < 1
        disp('No visits recorded for this patient.');
        return;
    end

    nVisits = record.numVisits;
    dates   = cell(nVisits, 1);
    grades  = zeros(nVisits, 1);
    maCounts = zeros(nVisits, 1);
    hmCounts = zeros(nVisits, 1);
    exAreas  = zeros(nVisits, 1);
    cwsCounts = zeros(nVisits, 1);
    nvFlags  = zeros(nVisits, 1);

    for i = 1:nVisits
        v = record.visits{i};
        dates{i} = v.visitDate;
        grades(i) = v.grade;
        if isfield(v, 'conceptVec') && isstruct(v.conceptVec)
            cv = v.conceptVec;
            maCounts(i) = cv.maCount;
            hmCounts(i) = cv.hmCount;
            exAreas(i)  = cv.exArea;
            cwsCounts(i) = cv.cwsCount;
            nvFlags(i)  = double(cv.nvFlag);
        end
    end

    % Convert date strings to datetime for clean axis labels
    visitNums = 1:nVisits;

    fig = figure('Name', sprintf('Patient Dashboard: %s', patientID), ...
        'Position', [100 100 1100 700]);

    % --- Grade trend ---
    subplot(2, 3, 1);
    plot(visitNums, grades, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
    yticks(0:4); yticklabels({'0 No DR','1 Mild','2 Mod','3 Sev','4 PDR'});
    ylim([-0.5, 4.5]); xlabel('Visit'); ylabel('ICDR Grade');
    title('Grade Over Time'); grid on;

    % --- MA count trend ---
    subplot(2, 3, 2);
    bar(visitNums, maCounts, 'FaceColor', [0.8 0.2 0.2]);
    xlabel('Visit'); ylabel('Count'); title('Microaneurysms'); grid on;

    % --- HM count trend ---
    subplot(2, 3, 3);
    bar(visitNums, hmCounts, 'FaceColor', [0.2 0.2 0.8]);
    xlabel('Visit'); ylabel('Count'); title('Haemorrhages'); grid on;

    % --- Exudate area trend ---
    subplot(2, 3, 4);
    area(visitNums, exAreas, 'FaceColor', [1 0.9 0.2], 'FaceAlpha', 0.7);
    xlabel('Visit'); ylabel('Area (px²)'); title('Hard Exudate Area'); grid on;

    % --- CWS count ---
    subplot(2, 3, 5);
    bar(visitNums, cwsCounts, 'FaceColor', [0.2 0.8 0.8]);
    xlabel('Visit'); ylabel('Count'); title('Cotton-Wool Spots'); grid on;

    % --- NV flag timeline ---
    subplot(2, 3, 6);
    stem(visitNums, nvFlags, 'r', 'LineWidth', 2, 'MarkerFaceColor', 'r');
    ylim([-0.2, 1.5]); yticks([0 1]); yticklabels({'No NV','NV Detected'});
    xlabel('Visit'); title('Neovascularization Flag'); grid on;

    sgtitle(sprintf('Longitudinal Dashboard — Patient %s (%d visit(s))', patientID, nVisits), ...
        'FontSize', 14, 'FontWeight', 'bold');
end

% ==========================================================================
function plotCohortDashboard()
    allPatients = twinStore('list');
    if isempty(allPatients)
        disp('No patient records found in twin store.');
        return;
    end

    cfg = config();
    gradeDistribution = zeros(1, length(cfg.classLabels));
    referableCount = 0;
    totalCount = 0;
    latestGrades = [];

    for pi = 1:length(allPatients)
        try
            rec = twinStore('read', allPatients{pi});
            if rec.numVisits < 1; continue; end
            lastVisit = rec.visits{end};
            g = lastVisit.grade;
            if ~isnan(g) && g >= 0 && g <= 4
                gradeDistribution(g + 1) = gradeDistribution(g + 1) + 1;
                latestGrades(end+1) = g;
                if g >= 2; referableCount = referableCount + 1; end
                totalCount = totalCount + 1;
            end
        catch; end
    end

    fig = figure('Name', 'Cohort Dashboard', 'Position', [100 100 900 500]);

    % Grade distribution bar chart
    subplot(1, 2, 1);
    bar(cfg.classLabels, gradeDistribution, 'FaceColor', [0.3 0.5 0.8]);
    xlabel('ICDR Grade'); ylabel('Patient Count');
    title(sprintf('Cohort Grade Distribution (n=%d)', totalCount)); grid on;
    xticks(0:4); xticklabels(cfg.classNames);

    % Referable pie chart
    subplot(1, 2, 2);
    if totalCount > 0
        pie([totalCount - referableCount, referableCount], ...
            {sprintf('Non-Referable (%d)', totalCount - referableCount), ...
             sprintf('Referable (%d)', referableCount)});
        title('Referable vs Non-Referable DR');
        colormap([0.2 0.7 0.3; 0.8 0.2 0.2]);
    else
        text(0.5, 0.5, 'No data', 'HorizontalAlignment', 'center');
    end

    sgtitle(sprintf('Netra AI Cohort Dashboard — %d Patients', totalCount), ...
        'FontSize', 14, 'FontWeight', 'bold');
end
