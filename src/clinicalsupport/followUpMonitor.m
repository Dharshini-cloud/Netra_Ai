function alerts = followUpMonitor(targetDate)
% FOLLOWUPMONITOR Scans the twin store for overdue follow-ups and generates alerts.
% Can be manually triggered (e.g., from NetraApp) or called on a schedule.
% Returns a struct array of alerts for overdue patients.
%
% Input:
%   targetDate - (Optional) date string to compare against; defaults to today.
%
% Output:
%   alerts - struct array, each with fields: {patientID, daysOverdue, lastVisitDate,
%            lastGrade, urgency, message}

    if nargin < 1 || isempty(targetDate)
        targetDate = now;
    else
        targetDate = datenum(targetDate);
    end

    % Follow-up interval by urgency (in days)
    followUpIntervals = struct(...
        'grade0', 365, ...   % Annual
        'grade1', 365, ...   % Annual
        'grade2', 90,  ...   % 3 months
        'grade3', 28,  ...   % 4 weeks
        'grade4', 7    ...   % 1 week
    );

    % Get all patient IDs in the store
    allPatients = twinStore('list');
    if isempty(allPatients)
        fprintf('[FollowUp] No patient records in twin store.\n');
        alerts = struct([]);
        return;
    end

    alerts = struct('patientID', {}, 'daysOverdue', {}, 'lastVisitDate', {}, ...
                    'lastGrade', {}, 'urgency', {}, 'message', {});
    alertCount = 0;

    for i = 1:length(allPatients)
        pid = allPatients{i};
        try
            record = twinStore('read', pid);
        catch
            continue;
        end

        if record.numVisits == 0
            continue;
        end

        % Most recent visit
        lastVisit = record.visits{end};
        lastVisitDate = datenum(lastVisit.visitDate);
        lastGrade = lastVisit.grade;

        % Determine expected follow-up interval
        gradeKey = sprintf('grade%d', lastGrade);
        if isfield(followUpIntervals, gradeKey)
            intervalDays = followUpIntervals.(gradeKey);
        else
            intervalDays = 365;
        end

        dueDate = lastVisitDate + intervalDays;
        daysSinceDue = floor(targetDate - dueDate);

        if daysSinceDue > 0
            % Patient is overdue
            alertCount = alertCount + 1;

            urgencyLevels = {'Routine','Soon','Urgent','Emergency'};
            urgencyIdx = min(lastGrade + 1, 4);
            urgency = urgencyLevels{urgencyIdx};

            if daysSinceDue > intervalDays * 0.5
                % Severely overdue — escalate urgency one level
                urgencyIdx = min(urgencyIdx + 1, 4);
                urgency = urgencyLevels{urgencyIdx};
            end

            alerts(alertCount).patientID    = pid;
            alerts(alertCount).daysOverdue  = daysSinceDue;
            alerts(alertCount).lastVisitDate = lastVisit.visitDate;
            alerts(alertCount).lastGrade    = lastGrade;
            alerts(alertCount).urgency      = urgency;
            alerts(alertCount).message      = sprintf( ...
                '[ALERT] Patient %s is %d day(s) overdue for follow-up. Last visit: %s (Grade %d). Urgency: %s.', ...
                pid, daysSinceDue, lastVisit.visitDate, lastGrade, urgency);

            fprintf('%s\n', alerts(alertCount).message);
        end
    end

    if alertCount == 0
        fprintf('[FollowUp] All %d patients are within their follow-up windows.\n', length(allPatients));
    else
        fprintf('[FollowUp] %d overdue patient(s) identified out of %d.\n', alertCount, length(allPatients));
    end
end
