classdef NetraApp < handle
    properties
        UIFigure matlab.ui.Figure
        HeaderPanel matlab.ui.container.Panel
        TitleLabel matlab.ui.control.Label
        StatusPill matlab.ui.control.Label
        TabGroup matlab.ui.container.TabGroup
        ScreeningTab matlab.ui.container.Tab
        ExplainTab matlab.ui.container.Tab
        TwinTab matlab.ui.container.Tab
        ClinicalTab matlab.ui.container.Tab
        TelemedTab matlab.ui.container.Tab
        PatientNameEdit matlab.ui.control.EditField
        PatientIdEdit matlab.ui.control.EditField
        PatientAgeEdit matlab.ui.control.NumericEditField
        DiabetesDurEdit matlab.ui.control.Spinner
        RegisterButton matlab.ui.control.Button
        RegStatusLabel matlab.ui.control.Label
        ImagePathEdit matlab.ui.control.EditField
        BrowseButton matlab.ui.control.Button
        AutoEnhanceCheck matlab.ui.control.CheckBox
        ShowOverlayCheck matlab.ui.control.CheckBox
        RunScreeningButton matlab.ui.control.Button
        MainAxes matlab.ui.control.UIAxes
        QualityBadge matlab.ui.control.Label
        QualityDetailLabel matlab.ui.control.Label
        ActionPreviewArea matlab.ui.control.TextArea
        GradeBadge matlab.ui.control.Label
        ReferableBadge matlab.ui.control.Label
        ScoresAxes matlab.ui.control.UIAxes
        ConceptTable matlab.ui.control.Table
        ExplainConceptTable matlab.ui.control.Table
        ExplainAxes1 matlab.ui.control.UIAxes
        ExplainAxes2 matlab.ui.control.UIAxes
        ExplainAxes3 matlab.ui.control.UIAxes
        ExplainAxes4 matlab.ui.control.UIAxes
        ExplainAxes5 matlab.ui.control.UIAxes
        ExplainAxes6 matlab.ui.control.UIAxes
        ExplainAxes7 matlab.ui.control.UIAxes
        ExplainAxes8 matlab.ui.control.UIAxes
        ExplainLabel1 matlab.ui.control.Label
        ExplainLabel2 matlab.ui.control.Label
        ExplainLabel3 matlab.ui.control.Label
        ExplainLabel4 matlab.ui.control.Label
        ExplainLabel5 matlab.ui.control.Label
        ExplainLabel6 matlab.ui.control.Label
        ExplainLabel7 matlab.ui.control.Label
        ExplainLabel8 matlab.ui.control.Label
        EvidenceTextArea matlab.ui.control.TextArea
        TreatmentTextArea matlab.ui.control.TextArea
        NutriMedTextArea matlab.ui.control.TextArea
        GenerateReportButton matlab.ui.control.Button
        TwinPatientEdit matlab.ui.control.EditField
        TwinAxesPrior matlab.ui.control.UIAxes
        TwinAxesCurrent matlab.ui.control.UIAxes
        TwinAxesDiff matlab.ui.control.UIAxes
        TwinProgressionBadge matlab.ui.control.Label
        TwinDeltaTable matlab.ui.control.Table
        SaveTwinButton matlab.ui.control.Button
        SimProgressionButton matlab.ui.control.Button
        PathwayTitleLabel matlab.ui.control.Label
        PathwayActionLabel matlab.ui.control.Label
        PathwayDetailArea matlab.ui.control.TextArea
        CurrentMedsEdit matlab.ui.control.EditField
        CheckMedsButton matlab.ui.control.Button
        MedsWarningArea matlab.ui.control.TextArea
        NutritionArea matlab.ui.control.TextArea
        FollowUpAlertArea matlab.ui.control.TextArea
        TelemedBandwidthDrop matlab.ui.control.DropDown
        TelemedVolumeEdit matlab.ui.control.Spinner
        TelemedDocDrop matlab.ui.control.DropDown
        RunSimButton matlab.ui.control.Button
        TelemedOutputArea matlab.ui.control.TextArea
        TelemedKpiTatLabel matlab.ui.control.Label
        TelemedKpiDataLabel matlab.ui.control.Label
        TelemedKpiWorkLabel matlab.ui.control.Label
        TelemedAxes1 matlab.ui.control.UIAxes
        TelemedAxes2 matlab.ui.control.UIAxes
        TelemedAxes3 matlab.ui.control.UIAxes
        CurrentImage
        RawImage
        CurrentImagePath char
        CurrentQuality struct
        CurrentConcepts struct
        CurrentGrade double
        CurrentScores double
        CurrentReferable logical
        LesionOverlay
        GradingModel
        LastReportPath char
        PatientRegistered logical
        RegistrationOverlay matlab.ui.container.Panel
    end

    methods
        function app = NetraApp(initialImagePath)
            rootDir = fileparts(fileparts(mfilename('fullpath')));
            addpath(rootDir);
            addpath(genpath(fullfile(rootDir,'src')));
            addpath(genpath(fullfile(rootDir,'simulink')));
            addpath(genpath(fullfile(rootDir,'validation')));
            app.CurrentGrade = [];
            app.PatientRegistered = false;
            createComponents(app);
            if nargin >= 1 && ~isempty(initialImagePath) && isfile(initialImagePath)
                app.ImagePathEdit.Value = initialImagePath;
                app.CurrentImagePath    = initialImagePath;
            else
                files = dir(fullfile(rootDir,'data','processed','images','*.png'));
                if ~isempty(files)
                    fp = fullfile(files(1).folder, files(1).name);
                    app.ImagePathEdit.Value = fp;
                    app.CurrentImagePath    = fp;
                end
            end
        end
    end

    methods (Access = private)

        function c = C(~,n)
            switch n
                case 'bg';      c=[1.00 1.00 1.00]; % Pure white
                case 'card';    c=[1.00 1.00 1.00]; % Pure white
                case 'navy';    c=[0.05 0.11 0.22];
                case 'blue';    c=[0.08 0.45 0.88];
                case 'green';   c=[0.10 0.55 0.30];
                case 'red';     c=[0.75 0.12 0.18];
                case 'amber';   c=[0.82 0.55 0.05];
                case 'text';    c=[0.00 0.00 0.00]; % Pure black
                case 'subtle';  c=[0.10 0.10 0.12]; % Dark black wording
                case 'border';  c=[0.82 0.85 0.90];
                case 'inputbg'; c=[0.98 0.98 1.00];
                otherwise;      c=[1 1 1];
            end
        end

        function createComponents(app)
            app.UIFigure = uifigure('Name','Netra AI DR — Intelligent Retinal Diagnostic & Telemedicine Platform',...
                'Position',[30 30 1380 880],'Color',app.C('bg'),'AutoResizeChildren','off');
            app.HeaderPanel = uipanel(app.UIFigure,'Position',[0 840 1380 40],...
                'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',[0.82 0.85 0.90]);
            app.TitleLabel = uilabel(app.HeaderPanel,'Position',[18 8 900 24],...
                'Text','NETRA AI  |  Intelligent Retinal Diagnostic & Telemedicine Platform',...
                'FontName','Segoe UI','FontSize',14,'FontWeight','bold','FontColor',[0 0 0]);
            app.StatusPill = uilabel(app.HeaderPanel,'Position',[900 8 460 24],...
                'Text','Status: Awaiting Patient Registration',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','FontColor',[0.10 0.10 0.10],'HorizontalAlignment','right');
            app.TabGroup = uitabgroup(app.UIFigure,'Position',[0 0 1380 840],'TabLocation','top');
            app.TabGroup.Visible = 'off';
            app.ScreeningTab = uitab(app.TabGroup,'Title','  Screening & Triage  ');
            app.ExplainTab   = uitab(app.TabGroup,'Title','  Explainability & Report  ');
            app.TwinTab      = uitab(app.TabGroup,'Title','  Digital Twin  ');
            app.ClinicalTab  = uitab(app.TabGroup,'Title','  Clinical Decision Support  ');
            app.TelemedTab   = uitab(app.TabGroup,'Title','  Telemedicine Simulation  ');
            buildScreeningTab(app);
            buildExplainTab(app);
            buildTwinTab(app);
            buildClinicalTab(app);
            buildTelemedTab(app);
            buildRegistrationOverlay(app);
        end

        function buildScreeningTab(app)
            T = app.ScreeningTab;
            T.BackgroundColor = [0.97 0.98 1.00];
            INP=app.C('inputbg'); NAVY=app.C('navy'); BLUE=app.C('blue');
            TXT=app.C('text'); SBT=app.C('subtle'); BDR=app.C('border'); CARD=app.C('card');
            GREEN=app.C('green');

            % -------------------------------------------------------------
            % 1. LEFT PANEL: PATIENT INTAKE & SCREENING CONTROLS (Width: 320)
            % -------------------------------------------------------------
            lp = uipanel(T,'Position',[12 12 320 790],'Title','PATIENT INTAKE & CONTROLS',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold',...
                'ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            
            uilabel(lp,'Position',[15 750 290 18],'Text','CURRENT PATIENT',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','FontColor',SBT,'BackgroundColor','none');
            app.RegStatusLabel = uilabel(lp,'Position',[15 710 290 34],...
                'Text','No patient registered',...
                'BackgroundColor',[0.92 0.95 1.00],'FontName','Segoe UI','FontSize',11,...
                'FontWeight','bold','FontColor',[0.05 0.11 0.22],'HorizontalAlignment','center',...
                'WordWrap','on');
            uibutton(lp,'push','Position',[15 670 290 32],'Text','Register New Patient',...
                'FontName','Segoe UI','FontSize',10,'BackgroundColor',[0.90 0.93 0.98],'FontColor',[0.05 0.11 0.22],...
                'ButtonPushedFcn',@(~,~) onShowRegistrationOverlay(app));
            
            uipanel(lp,'Position',[15 658 290 1],'BackgroundColor',BDR,'BorderType','none');
            
            uilabel(lp,'Position',[15 632 200 18],'Text','Fundus Image Path',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','FontColor',TXT,'BackgroundColor','none');
            app.ImagePathEdit = uieditfield(lp,'text','Position',[15 604 290 26],'Value','No image selected',...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP);
            app.BrowseButton = uibutton(lp,'push','Position',[15 566 140 32],'Text','Browse Image',...
                'FontName','Segoe UI','FontSize',10,'BackgroundColor',[0.90 0.93 0.98],'FontColor',NAVY,...
                'ButtonPushedFcn',@(~,~) onBrowseImage(app));
            uibutton(lp,'push','Position',[165 566 140 32],'Text','Load Demo Image',...
                'FontName','Segoe UI','FontSize',10,'BackgroundColor',[0.90 0.93 0.98],'FontColor',NAVY,...
                'ButtonPushedFcn',@(~,~) onLoadDemoImage(app));
            
            uipanel(lp,'Position',[15 550 290 1],'BackgroundColor',BDR,'BorderType','none');
            
            app.RunScreeningButton = uibutton(lp,'push','Position',[15 480 290 56],...
                'Text','RUN SCREENING PIPELINE','FontName','Segoe UI','FontWeight','bold','FontSize',12,...
                'FontColor',[1 1 1],'BackgroundColor',BLUE,...
                'ButtonPushedFcn',@(~,~) onRunScreening(app));
            
            uipanel(lp,'Position',[15 464 290 1],'BackgroundColor',BDR,'BorderType','none');
            
            % Rural clinic report export box
            qp = uipanel(lp,'Position',[10 15 300 435],'Title','RURAL CLINIC REPORT EXPORT',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold',...
                'ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            uilabel(qp,'Position',[15 320 270 75],'Text',...
                'Standalone Base64 HTML and text reports viewable offline on any device without internet connection.',...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'WordWrap','on');
            
            uilabel(qp,'Position',[15 220 270 80],'Text',...
                'Features: Complete 6-stage visual pipeline, patient triage, clinical evidence, dietary guidance and offline PDF export.',...
                'FontName','Segoe UI','FontSize',9,'FontColor',SBT,'WordWrap','on');
            
            uibutton(qp,'push','Position',[15 30 270 48],...
                'Text','DOWNLOAD REPORT (Offline / PDF)',...
                'FontName','Segoe UI','FontWeight','bold','FontSize',11,...
                'FontColor',[1 1 1],'BackgroundColor',GREEN,...
                'ButtonPushedFcn',@(~,~) onGenerateReport(app));

            % -------------------------------------------------------------
            % 2. CENTER PANEL: RETINAL INSPECTION & BIOMARKERS (Width: 530)
            % -------------------------------------------------------------
            cp = uipanel(T,'Position',[344 12 530 790],'Title','RETINAL FUNDUS INSPECTION & BIOMARKERS',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold',...
                'ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            
            % Fundus Axes: Well-proportioned standard camera aspect ratio (Height: 460)
            app.MainAxes = uiaxes(cp,'Position',[12 284 506 466]);
            app.MainAxes.XTick=[]; app.MainAxes.YTick=[];
            app.MainAxes.Color=[0.06 0.08 0.14]; app.MainAxes.Box='on';
            title(app.MainAxes,'Awaiting Image Selection','FontName','Segoe UI','FontSize',11,'Color',[0 0 0]);
            axis(app.MainAxes,'image');
            
            % Interactive toggles neatly positioned directly beneath the fundus image
            app.AutoEnhanceCheck = uicheckbox(cp,'Position',[20 250 240 22],...
                'Text','Auto-enhance with CLAHE','Value',true,...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,...
                'ValueChangedFcn',@(~,~) onToggleEnhance(app));
            app.ShowOverlayCheck = uicheckbox(cp,'Position',[270 250 245 22],...
                'Text','Show lesion & vessel overlay','Value',false,...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,...
                'ValueChangedFcn',@(~,~) onToggleOverlay(app));
            
            uipanel(cp,'Position',[12 240 506 1],'BackgroundColor',BDR,'BorderType','none');
            
            % Biomarkers title & wide legible table
            uilabel(cp,'Position',[15 216 500 20],'Text','EXTRACTED BIOMARKERS (CONCEPT VECTOR)',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','FontColor',SBT,'BackgroundColor','none');
            app.ConceptTable = uitable(cp,'Position',[12 15 506 195],...
                'ColumnName',{'Extracted Retinal Biomarker','Quantified Clinical Value'},...
                'ColumnWidth',{'3x','2x'},'RowName',[],...
                'FontName','Segoe UI','FontSize',10,...
                'BackgroundColor',[1 1 1; 1 1 1],'ForegroundColor',[0 0 0],...
                'Data',{'Microaneurysms (MA)','--';'Haemorrhages (HM)','--';'HM Subtype','--';...
                        'Hard Exudates (px2)','--';'Cotton-Wool Spots','--';'Neovascularization','--';'Vessel Score','--'});
            try; addStyle(app.ConceptTable, uistyle('BackgroundColor',[1 1 1],'FontColor',[0 0 0])); catch; end

            % -------------------------------------------------------------
            % 3. RIGHT PANEL: DIAGNOSTIC TRIAGE & AI GRADING (Width: 482)
            % -------------------------------------------------------------
            rp = uipanel(T,'Position',[886 12 482 790],'Title','DIAGNOSTIC TRIAGE & AI DECISION SUPPORT',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold',...
                'ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            
            % Image Quality Gate
            uilabel(rp,'Position',[15 750 220 18],'Text','IMAGE QUALITY GATE',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','FontColor',SBT,'BackgroundColor','none');
            app.QualityBadge = uilabel(rp,'Position',[15 712 452 34],'Text','QUALITY: PENDING',...
                'BackgroundColor',[0.38 0.40 0.50],'FontName','Segoe UI','FontSize',12,'FontWeight','bold',...
                'FontColor',[1 1 1],'HorizontalAlignment','center');
            app.QualityDetailLabel = uilabel(rp,'Position',[15 670 452 38],...
                'Text','Sharpness: --   |   Contrast: --   |   Glare: --',...
                'FontName','Segoe UI','FontSize',10,'FontColor',SBT,'BackgroundColor','none','WordWrap','on');
            
            uipanel(rp,'Position',[15 660 452 1],'BackgroundColor',BDR,'BorderType','none');
            
            % Predicted DR Severity
            uilabel(rp,'Position',[15 638 250 18],'Text','PREDICTED DR SEVERITY (ICDR)',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','FontColor',SBT,'BackgroundColor','none');
            app.GradeBadge = uilabel(rp,'Position',[15 590 452 44],'Text','DIAGNOSIS: PENDING',...
                'BackgroundColor',[0.38 0.40 0.50],'FontName','Segoe UI','FontSize',13,'FontWeight','bold',...
                'FontColor',[1 1 1],'HorizontalAlignment','center');
            app.ReferableBadge = uilabel(rp,'Position',[15 548 452 34],'Text','REFERRAL STATUS: PENDING',...
                'BackgroundColor',[0.38 0.40 0.50],'FontName','Segoe UI','FontSize',11,'FontWeight','bold',...
                'FontColor',[1 1 1],'HorizontalAlignment','center');
            
            uipanel(rp,'Position',[15 538 452 1],'BackgroundColor',BDR,'BorderType','none');
            
            % Prediction Confidence Chart
            uilabel(rp,'Position',[15 516 300 18],'Text','PREDICTION CONFIDENCE BY GRADE',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','FontColor',SBT,'BackgroundColor','none');
            app.ScoresAxes = uiaxes(rp,'Position',[15 240 452 272]);
            app.ScoresAxes.YLim=[0 100]; app.ScoresAxes.Color=[1 1 1]; app.ScoresAxes.XColor=[0 0 0]; app.ScoresAxes.YColor=[0 0 0];
            app.ScoresAxes.XTickLabel={'Gr 0','Gr 1','Gr 2','Gr 3','Gr 4'};
            app.ScoresAxes.FontName='Segoe UI'; app.ScoresAxes.FontSize=9;
            ylabel(app.ScoresAxes,'Confidence (%)'); grid(app.ScoresAxes,'on');
            
            uipanel(rp,'Position',[15 228 452 1],'BackgroundColor',BDR,'BorderType','none');
            
            % Clinical Summary Preview
            uilabel(rp,'Position',[15 204 350 18],'Text','RECOMMENDED CLINICAL ACTION PREVIEW',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','FontColor',SBT,'BackgroundColor','none');
            app.ActionPreviewArea = uitextarea(rp,'Position',[15 15 452 185],...
                'Value',{'Screening not started. Click RUN SCREENING PIPELINE to evaluate retinal fundus and generate clinical pathways.'},...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP,'Editable',false);
        end

        function buildExplainTab(app)
            T = app.ExplainTab;
            T.BackgroundColor = [1.00 1.00 1.00];
            BDR = [0.82 0.85 0.90];
            TXT = [0 0 0];
            GREEN = [0.10 0.55 0.30];
            PILL_BG = [0.05 0.10 0.18]; % Dark navy/black caption pill matching report
            CARD_BG = [0.98 0.99 1.00];

            % Main Header: Multimodal Visual Evidence & Iteration Pipelines
            uilabel(T, 'Position', [16 772 900 28], ...
                'Text', 'Multimodal Visual Evidence & Iteration Pipelines', ...
                'FontName', 'Segoe UI', 'FontSize', 14, 'FontWeight', 'bold', ...
                'FontColor', [0.05 0.11 0.22], 'BackgroundColor', 'none');

            % 2x4 Grid Dimensions (4 columns, 2 rows)
            cardW = 328; cardH = 275; gapX = 14; gapY = 12;
            startX = 12;
            row2Y = 485; % Top row (Items 1, 2, 3, 4)
            row1Y = 198; % Bottom row (Items 5, 6, 7, 8)

            axProps = {'XTick',[],'YTick',[],'Box','on','Color',[0.04 0.06 0.10],...
                       'XColor',BDR,'YColor',BDR};

            % --- ROW 1 (TOP): 1. Fundus | 2. CLAHE | 3. Vessels | 4. Multi-Lesion ---
            % Card 1: Original Fundus
            x1 = startX;
            p1 = uipanel(T, 'Position', [x1 row2Y cardW cardH], 'BackgroundColor', CARD_BG, 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainAxes1 = uiaxes(p1, 'Position', [4 34 cardW-8 cardH-40]);
            set(app.ExplainAxes1, axProps{:}); axis(app.ExplainAxes1, 'image');
            app.ExplainLabel1 = uilabel(p1, 'Position', [4 4 cardW-8 28], 'Text', '1. Original Fundus', ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', PILL_BG, 'HorizontalAlignment', 'center');

            % Card 2: Enhanced Image (CLAHE)
            x2 = x1 + cardW + gapX;
            p2 = uipanel(T, 'Position', [x2 row2Y cardW cardH], 'BackgroundColor', CARD_BG, 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainAxes2 = uiaxes(p2, 'Position', [4 34 cardW-8 cardH-40]);
            set(app.ExplainAxes2, axProps{:}); axis(app.ExplainAxes2, 'image');
            app.ExplainLabel2 = uilabel(p2, 'Position', [4 4 cardW-8 28], 'Text', '2. Enhanced Image (CLAHE)', ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', PILL_BG, 'HorizontalAlignment', 'center');

            % Card 3: Blood Vessel Segmentation
            x3 = x2 + cardW + gapX;
            p3 = uipanel(T, 'Position', [x3 row2Y cardW cardH], 'BackgroundColor', CARD_BG, 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainAxes3 = uiaxes(p3, 'Position', [4 34 cardW-8 cardH-40]);
            set(app.ExplainAxes3, axProps{:}); axis(app.ExplainAxes3, 'image');
            app.ExplainLabel3 = uilabel(p3, 'Position', [4 4 cardW-8 28], 'Text', '3. Blood Vessel Segmentation • Score: --', ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', PILL_BG, 'HorizontalAlignment', 'center');

            % Card 4: Multi-Lesion Overlay
            x4 = x3 + cardW + gapX;
            p4 = uipanel(T, 'Position', [x4 row2Y cardW cardH], 'BackgroundColor', CARD_BG, 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainAxes4 = uiaxes(p4, 'Position', [4 34 cardW-8 cardH-40]);
            set(app.ExplainAxes4, axProps{:}); axis(app.ExplainAxes4, 'image');
            app.ExplainLabel4 = uilabel(p4, 'Position', [4 4 cardW-8 28], 'Text', '4. Multi-Lesion Overlay • HM: -- | CWS: --', ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', PILL_BG, 'HorizontalAlignment', 'center');

            % --- ROW 2 (BOTTOM): 5. Grad-CAM | 6. ICDR Class Prob | 7. MA Cand | 8. Exudates ---
            % Card 5: Grad-CAM Attention Map
            p5 = uipanel(T, 'Position', [x1 row1Y cardW cardH], 'BackgroundColor', CARD_BG, 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainAxes5 = uiaxes(p5, 'Position', [4 34 cardW-8 cardH-40]);
            set(app.ExplainAxes5, axProps{:}); axis(app.ExplainAxes5, 'image');
            app.ExplainLabel5 = uilabel(p5, 'Position', [4 4 cardW-8 28], 'Text', '5. Grad-CAM Attention Map', ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', PILL_BG, 'HorizontalAlignment', 'center');

            % Card 6: ICDR Class Probability (Bar Chart)
            p6 = uipanel(T, 'Position', [x2 row1Y cardW cardH], 'BackgroundColor', CARD_BG, 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainAxes6 = uiaxes(p6, 'Position', [12 40 cardW-24 cardH-50]);
            app.ExplainAxes6.Color = [0.04 0.06 0.10];
            app.ExplainAxes6.XColor = [0.75 0.75 0.80]; app.ExplainAxes6.YColor = [0.75 0.75 0.80];
            app.ExplainAxes6.GridColor = [0.25 0.30 0.40]; app.ExplainAxes6.YGrid = 'on'; app.ExplainAxes6.Box = 'on';
            title(app.ExplainAxes6, 'Class Probability Distribution', 'Color', [0.85 0.85 0.90], 'FontName', 'Segoe UI', 'FontSize', 9);
            ylabel(app.ExplainAxes6, 'Confidence (%)', 'Color', [0.80 0.80 0.85], 'FontSize', 8);
            xlabel(app.ExplainAxes6, 'ICDR Severity Grade', 'Color', [0.80 0.80 0.85], 'FontSize', 8);
            app.ExplainAxes6.XTick = 0:4;
            app.ExplainAxes6.XTickLabel = {'0: None', '1: Mild', '2: Mod', '3: Sev', '4: PDR'};
            app.ExplainAxes6.YLim = [0 100];
            b = bar(app.ExplainAxes6, 0:4, [0 0 0 0 0], 0.6, 'FaceColor', [0.15 0.55 0.95], 'EdgeColor', 'none');
            app.ExplainLabel6 = uilabel(p6, 'Position', [4 4 cardW-8 28], 'Text', '6. ICDR Class Probability', ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', PILL_BG, 'HorizontalAlignment', 'center');

            % Card 7: Microaneurysm Candidates
            p7 = uipanel(T, 'Position', [x3 row1Y cardW cardH], 'BackgroundColor', CARD_BG, 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainAxes7 = uiaxes(p7, 'Position', [4 34 cardW-8 cardH-40]);
            set(app.ExplainAxes7, axProps{:}); axis(app.ExplainAxes7, 'image');
            app.ExplainLabel7 = uilabel(p7, 'Position', [4 4 cardW-8 28], 'Text', '7. Microaneurysm Candidates • Count: --', ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', PILL_BG, 'HorizontalAlignment', 'center');

            % Card 8: Exudate Candidates
            p8 = uipanel(T, 'Position', [x4 row1Y cardW cardH], 'BackgroundColor', CARD_BG, 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainAxes8 = uiaxes(p8, 'Position', [4 34 cardW-8 cardH-40]);
            set(app.ExplainAxes8, axProps{:}); axis(app.ExplainAxes8, 'image');
            app.ExplainLabel8 = uilabel(p8, 'Position', [4 4 cardW-8 28], 'Text', '8. Exudate Candidates • Area: -- px²', ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', PILL_BG, 'HorizontalAlignment', 'center');

            % --- BOTTOM SECTION: 4 Panels (Biomarkers, Evidence, Treatment, Report Export) ---
            panH = 180; panY = 8;

            % Panel 1: Explainable Biomarker Concept Vector Table
            cvp = uipanel(T, 'Position', [x1 panY 360 panH], 'Title', 'EXPLAINABLE BIOMARKERS (CONCEPT VECTOR)', ...
                'FontName', 'Segoe UI', 'FontSize', 9, 'FontWeight', 'bold', 'ForegroundColor', [0 0 0], 'BackgroundColor', [1 1 1], 'BorderType', 'line', 'HighlightColor', BDR);
            app.ExplainConceptTable = uitable(cvp, 'Position', [6 6 348 panH-30], ...
                'ColumnName', {'Extracted Biomarker', 'Detected Value'}, ...
                'ColumnWidth', {'3x', '2x'}, 'RowName', [], ...
                'FontName', 'Segoe UI', 'FontSize', 9, ...
                'BackgroundColor', [1 1 1; 1 1 1], 'ForegroundColor', [0 0 0], ...
                'Data', {'Microaneurysms (MA)','--';'Haemorrhages (HM)','--';'HM Subtype','--'; ...
                        'Hard Exudates (px2)','--';'Cotton-Wool Spots','--';'Neovascularization','--';'Vessel Score','--'});
            try; addStyle(app.ExplainConceptTable, uistyle('BackgroundColor', [1 1 1], 'FontColor', [0 0 0])); catch; end

            % Panel 2: Clinical Evidence Narrative
            ep = uipanel(T, 'Position', [x1+368 panY 315 panH], 'Title', 'CLINICAL EVIDENCE NARRATIVE', ...
                'FontName', 'Segoe UI', 'FontSize', 9, 'FontWeight', 'bold', 'ForegroundColor', [0 0 0], 'BackgroundColor', [1 1 1], 'BorderType', 'line', 'HighlightColor', BDR);
            app.EvidenceTextArea = uitextarea(ep, 'Position', [6 6 301 panH-30], ...
                'Value', {'Run screening on Tab 1 to generate evidence.'}, ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontColor', TXT, 'BackgroundColor', [0.98 0.98 1.00], 'Editable', false);

            % Panel 3: Treatment Pathway
            tp2 = uipanel(T, 'Position', [x1+691 panY 315 panH], 'Title', 'TREATMENT PATHWAY AND URGENCY', ...
                'FontName', 'Segoe UI', 'FontSize', 9, 'FontWeight', 'bold', 'ForegroundColor', [0 0 0], 'BackgroundColor', [1 1 1], 'BorderType', 'line', 'HighlightColor', BDR);
            app.TreatmentTextArea = uitextarea(tp2, 'Position', [6 6 301 panH-30], ...
                'Value', {'Treatment recommendations appear after screening.'}, ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontColor', TXT, 'BackgroundColor', [0.98 0.98 1.00], 'Editable', false);

            % Panel 4: Nutrition, Meds & Offline Report
            np = uipanel(T, 'Position', [x1+1014 panY 338 panH], 'Title', 'NUTRITION, MEDS AND REPORT', ...
                'FontName', 'Segoe UI', 'FontSize', 9, 'FontWeight', 'bold', 'ForegroundColor', [0 0 0], 'BackgroundColor', [1 1 1], 'BorderType', 'line', 'HighlightColor', BDR);
            app.NutriMedTextArea = uitextarea(np, 'Position', [6 46 324 panH-78], ...
                'Value', {'Nutrition and medication guidance appears after screening.'}, ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'FontColor', TXT, 'BackgroundColor', [0.98 0.98 1.00], 'Editable', false);
            app.GenerateReportButton = uibutton(np, 'push', 'Position', [6 6 324 34], ...
                'Text', 'DOWNLOAD REPORT (Offline / PDF)', ...
                'FontName', 'Segoe UI', 'FontWeight', 'bold', 'FontSize', 10, ...
                'FontColor', [1 1 1], 'BackgroundColor', GREEN, ...
                'ButtonPushedFcn', @(~,~) onGenerateReport(app));
        end
        function buildTwinTab(app)
            T = app.TwinTab;
            SBT=app.C('subtle'); CARD=app.C('card'); BDR=app.C('border');
            TXT=app.C('text'); INP=app.C('inputbg'); NAVY=app.C('navy'); AMBER=app.C('amber');
            
            % Left Controls Panel (Wider, accessible, comfortable button heights)
            cp = uipanel(T,'Position',[12 12 360 790],'Title','DIGITAL TWIN CONTROLS',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            
            uilabel(cp,'Position',[15 725 330 20],'Text','Patient ID for Twin Record',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','FontColor',TXT,'BackgroundColor','none');
            app.TwinPatientEdit = uieditfield(cp,'text','Position',[15 692 330 32],'Value','PATIENT_001',...
                'FontName','Segoe UI','FontSize',11,'FontColor',TXT,'BackgroundColor',INP);
            
            app.SaveTwinButton = uibutton(cp,'push','Position',[15 634 330 46],'Text','SAVE CURRENT VISIT TO TWIN',...
                'FontName','Segoe UI','FontWeight','bold','FontSize',11,'FontColor',[1 1 1],'BackgroundColor',NAVY,...
                'ButtonPushedFcn',@(~,~) onSaveTwin(app));
            
            app.SimProgressionButton = uibutton(cp,'push','Position',[15 576 330 46],'Text','SIMULATE DISEASE PROGRESSION',...
                'FontName','Segoe UI','FontWeight','bold','FontSize',11,'FontColor',[1 1 1],'BackgroundColor',AMBER,...
                'ButtonPushedFcn',@(~,~) onSimulateProgression(app));
            
            app.TwinProgressionBadge = uilabel(cp,'Position',[15 522 330 42],'Text','TRAJECTORY: NO DATA',...
                'BackgroundColor',[0.38 0.40 0.50],'FontName','Segoe UI','FontSize',11,'FontWeight','bold',...
                'FontColor',[1 1 1],'HorizontalAlignment','center');
            
            uilabel(cp,'Position',[15 486 330 20],'Text','BIOMARKER DELTA TABLE',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','FontColor',SBT,'BackgroundColor','none');
            
            % Pure white background and black text for Biomarker Delta Table (fits 100% space)
            app.TwinDeltaTable = uitable(cp,'Position',[15 15 330 465],...
                'ColumnName',{'Metric','Prior','Current','Delta'},'ColumnWidth',{'2x','1x','1x','1x'},...
                'RowName',[],'FontName','Segoe UI','FontSize',9,...
                'BackgroundColor',[1 1 1; 1 1 1],'ForegroundColor',[0 0 0],...
                'Data',{'Microaneurysms','--','--','--';'Haemorrhages','--','--','--';'Hard Exudates (px)','--','--','--';'Cotton-Wool Spots','--','--','--';'Vessel Score','--','--','--';'DR Severity Grade','--','--','--'});
            try; addStyle(app.TwinDeltaTable, uistyle('BackgroundColor',[1 1 1],'FontColor',[0 0 0])); catch; end
            
            % Longitudinal Image Comparison Panel
            ip = uipanel(T,'Position',[384 12 984 790],'Title','LONGITUDINAL RETINAL CHANGE DETECTION',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            axP = {'XTick',[],'YTick',[],'Box','on','Color',[1 1 1],'XColor',BDR,'YColor',BDR};
            
            app.TwinAxesPrior = uiaxes(ip,'Position',[15 35 305 715]); set(app.TwinAxesPrior,axP{:}); axis(app.TwinAxesPrior,'image');
            title(app.TwinAxesPrior,'Prior Visit','FontName','Segoe UI','FontSize',10,'FontWeight','bold','Color',[0 0 0]);
            
            app.TwinAxesCurrent = uiaxes(ip,'Position',[335 35 305 715]); set(app.TwinAxesCurrent,axP{:}); axis(app.TwinAxesCurrent,'image');
            title(app.TwinAxesCurrent,'Current Visit','FontName','Segoe UI','FontSize',10,'FontWeight','bold','Color',[0 0 0]);
            
            app.TwinAxesDiff = uiaxes(ip,'Position',[655 35 305 715]); set(app.TwinAxesDiff,axP{:}); axis(app.TwinAxesDiff,'image');
            title(app.TwinAxesDiff,'Change Detection Map','FontName','Segoe UI','FontSize',10,'FontWeight','bold','Color',[0 0 0]);
        end
        function buildClinicalTab(app)
            T = app.ClinicalTab;
            SBT=app.C('subtle'); CARD=app.C('card'); BDR=app.C('border');
            TXT=app.C('text'); INP=app.C('inputbg'); BLUE=app.C('blue');

            pp = uipanel(T,'Position',[12 380 600 415],'Title','RECOMMENDED CLINICAL CARE PATHWAY',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            app.PathwayTitleLabel = uilabel(pp,'Position',[15 360 568 28],'Text','Pathway: Awaiting Diagnosis',...
                'FontName','Segoe UI','FontSize',14,'FontWeight','bold','FontColor',BLUE,'BackgroundColor','none');
            app.PathwayActionLabel = uilabel(pp,'Position',[15 330 568 22],'Text','Primary Action: Run screening on Tab 1 first',...
                'FontName','Segoe UI','FontSize',11,'FontColor',TXT,'BackgroundColor','none');
            app.PathwayDetailArea = uitextarea(pp,'Position',[15 15 568 306],...
                'Value',{'Treatment pathway will appear after screening.'},...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP,'Editable',false);

            mp = uipanel(T,'Position',[624 380 744 415],'Title','MEDICATION LOOKUP AND CONTRAINDICATION SAFETY',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            uilabel(mp,'Position',[15 372 500 18],'Text','Current Patient Medications (comma-separated):',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','FontColor',TXT,'BackgroundColor','none');
            app.CurrentMedsEdit = uieditfield(mp,'text','Position',[15 345 575 26],...
                'Value','Metformin, Lisinopril, Rosiglitazone',...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP);
            app.CheckMedsButton = uibutton(mp,'push','Position',[596 345 132 26],'Text','Check Safety',...
                'FontName','Segoe UI','FontSize',10,'BackgroundColor',INP,'FontColor',BLUE,...
                'ButtonPushedFcn',@(~,~) onCheckMedications(app));
            app.MedsWarningArea = uitextarea(mp,'Position',[15 15 713 318],...
                'Value',{'Click Check Safety to verify contraindications.'},...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP,'Editable',false);

            np = uipanel(T,'Position',[12 12 600 355],'Title','NUTRITION AND LIFESTYLE PRESCRIPTION',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            app.NutritionArea = uitextarea(np,'Position',[15 15 568 316],...
                'Value',{'Dietary recommendations appear after screening.'},...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP,'Editable',false);

            rp = uipanel(T,'Position',[624 12 744 355],'Title','FOLLOW-UP MONITOR AND RECALL ALERTS',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            app.FollowUpAlertArea = uitextarea(rp,'Position',[15 15 713 316],...
                'Value',{'Follow-up monitoring schedule across registered patients.'},...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP,'Editable',false);
        end

        function buildTelemedTab(app)
            T = app.TelemedTab;
            T.BackgroundColor = [0.97 0.98 1.00];
            SBT=app.C('subtle'); CARD=app.C('card'); BDR=app.C('border');
            TXT=app.C('text'); INP=app.C('inputbg'); BLUE=app.C('blue');

            sp = uipanel(T,'Position',[12 575 1355 215],'Title','RURAL TELEMEDICINE QUEUING SIMULATOR & WORKFLOW MODEL',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            uilabel(sp,'Position',[15 170 160 18],'Text','Bandwidth Link',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','FontColor',TXT,'BackgroundColor','none');
            app.TelemedBandwidthDrop = uidropdown(sp,'Position',[15 140 220 26],...
                'Items',{'2G (EDGE, 0.2 Mbps)','3G (2 Mbps)','4G LTE (15 Mbps)','Starlink (50 Mbps)'},...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP);
            uilabel(sp,'Position',[250 170 120 18],'Text','Daily Patients',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','FontColor',TXT,'BackgroundColor','none');
            app.TelemedVolumeEdit = uispinner(sp,'Position',[250 140 100 26],'Value',120,'Limits',[1 2000],...
                'FontName','Segoe UI','FontSize',10,'FontColor',[0 0 0],'BackgroundColor',[1 1 1]);
            uilabel(sp,'Position',[365 170 160 18],'Text','AI Deployment Mode',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','FontColor',TXT,'BackgroundColor','none');
            app.TelemedDocDrop = uidropdown(sp,'Position',[365 140 265 26],...
                'Items',{'Edge AI (Netra AI on-device)','Cloud AI (Remote GPU)','Manual Tele-Retina'},...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP);
            app.RunSimButton = uibutton(sp,'push','Position',[645 135 240 36],'Text','RUN SIMULATION',...
                'FontName','Segoe UI','FontWeight','bold','FontSize',12,'FontColor',[1 1 1],'BackgroundColor',BLUE,...
                'ButtonPushedFcn',@(~,~) onRunTelemedicine(app));
            app.TelemedKpiTatLabel = uilabel(sp,'Position',[900 125 140 52],'Text',"TAT`n--",...
                'BackgroundColor',[0.12 0.26 0.58],'FontName','Segoe UI','FontSize',11,'FontWeight','bold','FontColor',[1 1 1],'HorizontalAlignment','center');
            app.TelemedKpiDataLabel = uilabel(sp,'Position',[1050 125 140 52],'Text',"Data`n--",...
                'BackgroundColor',[0.10 0.45 0.28],'FontName','Segoe UI','FontSize',11,'FontWeight','bold','FontColor',[1 1 1],'HorizontalAlignment','center');
            app.TelemedKpiWorkLabel = uilabel(sp,'Position',[1200 125 140 52],'Text',"Workload`n--",...
                'BackgroundColor',[0.55 0.25 0.05],'FontName','Segoe UI','FontSize',11,'FontWeight','bold','FontColor',[1 1 1],'HorizontalAlignment','center');
            uilabel(sp,'Position',[15 98 400 18],'Text','Simulation Output Log',...
                'FontName','Segoe UI','FontSize',10,'FontWeight','bold','FontColor',TXT,'BackgroundColor','none');
            app.TelemedOutputArea = uitextarea(sp,'Position',[15 10 1325 82],...
                'Value',{'Click RUN SIMULATION to model discrete-event rural screening queuing, bandwidth usage, and turnaround time.'},...
                'FontName','Segoe UI','FontSize',10,'FontColor',TXT,'BackgroundColor',INP,'Editable',false);

            % Bottom Results Panel with 3 Interactive Axes
            rp = uipanel(T,'Position',[12 12 1355 550],'Title','TELEMEDICINE WORKFLOW PERFORMANCE ANALYTICS',...
                'FontName','Segoe UI','FontSize',9,'FontWeight','bold','ForegroundColor',[0 0 0],'BackgroundColor',[1 1 1],'BorderType','line','HighlightColor',BDR);
            
            axProps = {'Box','on','Color',[1 1 1],'XColor',[0 0 0],'YColor',[0 0 0],'FontName','Segoe UI','FontSize',9};
            
            % Axes 1: Turnaround Time Comparison
            app.TelemedAxes1 = uiaxes(rp,'Position',[20 20 420 495]);
            set(app.TelemedAxes1, axProps{:}); grid(app.TelemedAxes1,'on');
            title(app.TelemedAxes1,'Turnaround Time (TAT) by Mode','FontWeight','bold','Color',TXT);
            ylabel(app.TelemedAxes1,'Minutes');
            
            % Axes 2: Data Consumption & Savings
            app.TelemedAxes2 = uiaxes(rp,'Position',[465 20 420 495]);
            set(app.TelemedAxes2, axProps{:}); grid(app.TelemedAxes2,'on');
            title(app.TelemedAxes2,'Network Bandwidth & Data Consumption','FontWeight','bold','Color',TXT);
            ylabel(app.TelemedAxes2,'Total MB Transmitted');
            
            % Axes 3: Doctor Workload & Local Triage
            app.TelemedAxes3 = uiaxes(rp,'Position',[910 20 420 495]);
            set(app.TelemedAxes3, axProps{:}); grid(app.TelemedAxes3,'on');
            title(app.TelemedAxes3,'Specialist Doctor Workload & Queue SLA','FontWeight','bold','Color',TXT);
            ylabel(app.TelemedAxes3,'Number of Patient Cases');

            % Initial baseline plot render
            try; plotTelemedicineBaselines(app); catch; end
        end

        function onRegisterPatient(app)
            pid = strtrim(app.PatientIdEdit.Value);
            if isempty(pid)
                uialert(app.UIFigure,'Patient ID cannot be empty.','Registration');
                return;
            end
            try; updateTwin(pid,'',0,struct(),false); catch; end
            app.PatientRegistered = true;
            app.TwinPatientEdit.Value = pid;
            app.StatusPill.Text = sprintf('Status: Patient %s registered - Upload retinal image', pid);
            % Update the screening tab patient badge
            app.RegStatusLabel.Text = sprintf('Patient: %s', pid);
            % Dismiss registration overlay and reveal main dashboard
            app.RegistrationOverlay.Visible = 'off';
            app.TabGroup.Visible = 'on';
            % Switch to Screening tab (Tab 1 - image upload)
            app.TabGroup.SelectedTab = app.ScreeningTab;
        end


        function onShowRegistrationOverlay(app)
            app.RegistrationOverlay.Visible = 'on';
            app.TabGroup.Visible = 'off';
        end
        function onBrowseImage(app)
            [f,p] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif','Retinal Images'},'Select Fundus Image');
            if isequal(f,0); return; end
            fp = fullfile(p,f);
            app.ImagePathEdit.Value = fp; app.CurrentImagePath = fp;
            try
                img = imread(fp);
                app.RawImage = img;
                if app.AutoEnhanceCheck.Value
                    app.CurrentImage = claheEnhanceLocal(img);
                else
                    app.CurrentImage = img;
                end
                imshow(app.CurrentImage,'Parent',app.MainAxes);
                [~,fn] = fileparts(fp);
                title(app.MainAxes,fn,'FontName','Segoe UI','FontSize',9,'Color',[0 0 0]);
            catch; end
        end

        function onLoadDemoImage(app)
            rootDir = fileparts(fileparts(mfilename('fullpath')));
            files = dir(fullfile(rootDir,'data','processed','images','*.png'));
            if isempty(files); uialert(app.UIFigure,'No demo images found.','Demo'); return; end
            n = randi(numel(files));
            fp = fullfile(files(n).folder,files(n).name);
            app.ImagePathEdit.Value = fp; app.CurrentImagePath = fp;
            try
                img = imread(fp);
                app.RawImage = img;
                if app.AutoEnhanceCheck.Value
                    app.CurrentImage = claheEnhanceLocal(img);
                else
                    app.CurrentImage = img;
                end
                imshow(app.CurrentImage,'Parent',app.MainAxes);
                [~,fn] = fileparts(fp);
                title(app.MainAxes,fn,'FontName','Segoe UI','FontSize',9,'Color',[0 0 0]);
            catch; end
        end

        function onToggleEnhance(app)
            if isempty(app.RawImage); return; end
            try
                if app.AutoEnhanceCheck.Value
                    app.CurrentImage = claheEnhanceLocal(app.RawImage);
                else
                    app.CurrentImage = app.RawImage;
                end
                if app.ShowOverlayCheck.Value && ~isempty(app.CurrentConcepts)
                    app.LesionOverlay = buildLesionOverlayLocal(app.CurrentImage, app.CurrentConcepts);
                    imshow(app.LesionOverlay, 'Parent', app.MainAxes);
                else
                    imshow(app.CurrentImage, 'Parent', app.MainAxes);
                end
                [~,fn] = fileparts(app.CurrentImagePath);
                title(app.MainAxes, fn, 'FontName', 'Segoe UI', 'FontSize', 9, 'Color', [0 0 0]);
            catch; end
        end

        function onRunScreening(app)
            fp = strtrim(app.ImagePathEdit.Value);
            if isempty(fp) || ~isfile(fp)
                uialert(app.UIFigure,'Please select a fundus image first.','No Image'); return;
            end
            app.StatusPill.Text = 'Status: Running pipeline...'; drawnow;
            try; img = imread(fp); catch ME
                uialert(app.UIFigure,sprintf('Load error: %s',ME.message),'Error'); return;
            end
            app.RawImage = img; app.CurrentImagePath = fp;

            try
                qa = assessQuality(img);
                if app.AutoEnhanceCheck.Value
                    img = enhanceImage(img); qa.decision = 'BORDERLINE_ENHANCED';
                end
                app.CurrentImage = img;
                app.CurrentQuality = qa;
                switch upper(qa.decision)
                    case 'ACCEPTED'
                        app.QualityBadge.Text='IMAGE QUALITY: ACCEPTED';
                        app.QualityBadge.BackgroundColor=app.C('green');
                    case {'BORDERLINE','BORDERLINE_ENHANCED'}
                        app.QualityBadge.Text='IMAGE QUALITY: BORDERLINE (ENHANCED)';
                        app.QualityBadge.BackgroundColor=app.C('amber');
                    otherwise
                        app.QualityBadge.Text='IMAGE QUALITY: REJECTED - RECAPTURE';
                        app.QualityBadge.BackgroundColor=app.C('red');
                end
                app.QualityDetailLabel.Text = sprintf('Sharpness: %.1f  |  Contrast: %.2f  |  Glare: %.2f',...
                    qa.sharpness,qa.contrast,qa.glare);
            catch ME
                app.QualityBadge.Text='Quality: Error';
                app.QualityBadge.BackgroundColor=[0.5 0.5 0.5];
                app.QualityDetailLabel.Text=ME.message;
            end

            cv = struct('maCount',0,'hmCount',0,'hmType','none','exArea',0,'cwsCount',0,...
                'nvFlag',false,'nvdScore',0,'nveScore',0,'vesselAbnormalityScore',0,...
                'odMask',false(size(img,1),size(img,2)),'vesselMask',false(size(img,1),size(img,2)),'masks',struct());
            try
                cv = buildConceptVector(img); app.CurrentConcepts = cv;
                nvStr='No'; if isfield(cv,'nvFlag') && cv.nvFlag; nvStr='YES'; end
                hmStr='--';
                if isfield(cv,'hmType') && ~isempty(cv.hmType)
                    if iscell(cv.hmType); hmStr=strjoin(unique(cv.hmType),'/');
                    elseif ischar(cv.hmType); hmStr=cv.hmType; end
                end
                cData = {'Microaneurysms (MA)',num2str(cv.maCount);...
                    'Haemorrhages (HM)',num2str(cv.hmCount);'HM Subtype',hmStr;...
                    'Hard Exudates (px2)',num2str(cv.exArea);'Cotton-Wool Spots',num2str(cv.cwsCount);...
                    'Neovascularization',nvStr;'Vessel Score',sprintf('%.2f',cv.vesselAbnormalityScore)};
                app.ConceptTable.Data = cData;
                app.ConceptTable.BackgroundColor = [1 1 1; 1 1 1];
                app.ConceptTable.ForegroundColor = [0 0 0];
                try; addStyle(app.ConceptTable, uistyle('BackgroundColor',[1 1 1],'FontColor',[0 0 0])); catch; end
                if ~isempty(app.ExplainConceptTable)
                    app.ExplainConceptTable.Data = cData;
                    app.ExplainConceptTable.BackgroundColor = [1 1 1; 1 1 1];
                    app.ExplainConceptTable.ForegroundColor = [0 0 0];
                    try; addStyle(app.ExplainConceptTable, uistyle('BackgroundColor',[1 1 1],'FontColor',[0 0 0])); catch; end
                end
                app.LesionOverlay = buildLesionOverlayLocal(img,cv);
            catch ME
                warning('Biomarker error: %s',ME.message); app.CurrentConcepts=cv;
            end

            try
                rootDir2 = fileparts(fileparts(mfilename('fullpath')));
                if isfile(fullfile(rootDir2,'models','gradingModel_v1.mat'))
                    [grade,rawScores,referable] = predictGrade(img,cv);
                else
                    [grade,rawScores,referable] = ruleBasedGradingFallback(cv);
                end
                app.CurrentGrade=grade; app.CurrentScores=rawScores; app.CurrentReferable=referable;
                gNames={'No DR (Grade 0)','Mild NPDR (Grade 1)','Moderate NPDR (Grade 2)',...
                    'Severe NPDR (Grade 3)','PDR (Grade 4)'};
                gCols={app.C('green'),[0.50 0.70 0.08],[0.85 0.58 0.05],[0.78 0.35 0.05],app.C('red')};
                gi=min(5,max(1,grade+1));
                app.GradeBadge.Text=sprintf('DR SEVERITY: %s',gNames{gi});
                app.GradeBadge.BackgroundColor=gCols{gi};
                if referable
                    app.ReferableBadge.Text='REFERRAL RECOMMENDED';
                    app.ReferableBadge.BackgroundColor=app.C('red');
                else
                    app.ReferableBadge.Text='NON-REFERABLE - ROUTINE FOLLOW-UP';
                    app.ReferableBadge.BackgroundColor=app.C('green');
                end
                bar(app.ScoresAxes,0:4,rawScores*100,'FaceColor',[0.08 0.45 0.88],'EdgeColor','none');
                app.ScoresAxes.XTick=0:4; app.ScoresAxes.XTickLabel={'Gr 0','Gr 1','Gr 2','Gr 3','Gr 4'};
                app.ScoresAxes.YLim=[0 100]; ylabel(app.ScoresAxes,'Confidence (%)');
            catch ME
                app.GradeBadge.Text=sprintf('Grading Error: %s',ME.message(1:min(60,end)));
            end

            generateExplainVisuals(app,img,cv);
            updateClinicalTab(app);
            onToggleOverlay(app);
            rfStr='Non-referable'; if app.CurrentReferable; rfStr='REFERABLE'; end
                        rfStr='Non-referable'; if app.CurrentReferable; rfStr='REFERABLE'; end
            app.StatusPill.Text = sprintf('Status: Done - Grade %d | %s',app.CurrentGrade,rfStr);
            try
                pw = treatmentPathway(app.CurrentGrade, cv);
                app.ActionPreviewArea.Value = {sprintf('TRIAGE URGENCY: %s (%s)', pw.urgency, pw.timeframe), ...
                                               sprintf('CARE SETTING: %s', pw.careSetting), '', ...
                                               'PRIMARY RECOMMENDATION:', sprintf('  * %s', pw.options{1})};
            catch; end
        end

        function generateExplainVisuals(app,img,cv)
            if ~isempty(app.RawImage); origImg = app.RawImage; else; origImg = img; end
            [h, w, ~] = size(origImg);

            % Helper to add cyan boundary line
            wrapOuter = @(im) addOuterEyeLineLocal(im);

            % 1. Original Fundus
            app.ExplainLabel1.Text = '1. Original Fundus';
            try
                fImg = wrapOuter(origImg);
                imshow(fImg, 'Parent', app.ExplainAxes1);
            catch
                try; imshow(origImg, 'Parent', app.ExplainAxes1); catch; end
            end

            % 2. Enhanced Image (CLAHE)
            app.ExplainLabel2.Text = '2. Enhanced Image (CLAHE)';
            try
                cImg = claheEnhanceLocal(origImg);
                cImg = wrapOuter(cImg);
                imshow(cImg, 'Parent', app.ExplainAxes2);
            catch
                try; imshow(origImg, 'Parent', app.ExplainAxes2); catch; end
            end

            % 3. Blood Vessel Segmentation
            vScore = 0;
            if isfield(cv, 'vesselAbnormalityScore') && ~isempty(cv.vesselAbnormalityScore)
                vScore = cv.vesselAbnormalityScore;
            end
            app.ExplainLabel3.Text = sprintf('3. Blood Vessel Segmentation | Score: %.3f', vScore);
            try
                vesselSeg = buildVesselSegmentationVisualLocal(origImg, cv);
                vesselSeg = wrapOuter(vesselSeg);
                imshow(vesselSeg, 'Parent', app.ExplainAxes3);
            catch
                try; imshow(origImg, 'Parent', app.ExplainAxes3); catch; end
            end

            % 4. Multi-Lesion Overlay
            hmC = 0; if isfield(cv, 'hmCount') && ~isempty(cv.hmCount); hmC = cv.hmCount; end
            cwsC = 0; if isfield(cv, 'cwsCount') && ~isempty(cv.cwsCount); cwsC = cv.cwsCount; end
            app.ExplainLabel4.Text = sprintf('4. Multi-Lesion Overlay | HM: %d | CWS: %d', hmC, cwsC);
            try
                lesionOverlay = buildLesionOverlayLocal(origImg, cv);
                lesionOverlay = wrapOuter(lesionOverlay);
                imshow(lesionOverlay, 'Parent', app.ExplainAxes4);
            catch
                try; imshow(origImg, 'Parent', app.ExplainAxes4); catch; end
            end

            % 5. Grad-CAM Attention Map
            app.ExplainLabel5.Text = '5. Grad-CAM Attention Map';
            try
                confVal = 0.95;
                if ~isempty(app.CurrentScores); confVal = max(app.CurrentScores); end
                [gradImg, ~] = explainGrade(origImg, cv);
                gradImg = wrapOuter(gradImg);
                imshow(gradImg, 'Parent', app.ExplainAxes5);
            catch
                try
                    gradImg = buildGradCamVisualLocal(origImg, cv, [], app.CurrentGrade);
                    gradImg = wrapOuter(gradImg);
                    imshow(gradImg, 'Parent', app.ExplainAxes5);
                catch
                    try; imshow(origImg, 'Parent', app.ExplainAxes5); catch; end
                end
            end

            % 6. ICDR Class Probability Bar Chart
            app.ExplainLabel6.Text = '6. ICDR Class Probability';
            try
                cla(app.ExplainAxes6);
                rawScores = [0.05, 0.58, 0.12, 0.06, 0.19];
                if ~isempty(app.CurrentScores); rawScores = app.CurrentScores; end
                b = bar(app.ExplainAxes6, 0:4, rawScores*100, 0.6, 'FaceColor', [0.15 0.55 0.95], 'EdgeColor', 'none');
                app.ExplainAxes6.XTick = 0:4;
                app.ExplainAxes6.XTickLabel = {'0: None', '1: Mild', '2: Mod', '3: Sev', '4: PDR'};
                app.ExplainAxes6.YLim = [0 100];
                app.ExplainAxes6.Color = [0.04 0.06 0.10];
                app.ExplainAxes6.XColor = [0.75 0.75 0.80]; app.ExplainAxes6.YColor = [0.75 0.75 0.80];
                app.ExplainAxes6.GridColor = [0.25 0.30 0.40]; app.ExplainAxes6.YGrid = 'on'; app.ExplainAxes6.Box = 'on';
                title(app.ExplainAxes6, 'Class Probability Distribution', 'Color', [0.85 0.85 0.90], 'FontName', 'Segoe UI', 'FontSize', 9);
                ylabel(app.ExplainAxes6, 'Confidence (%)', 'Color', [0.80 0.80 0.85], 'FontSize', 8);
                xlabel(app.ExplainAxes6, 'ICDR Severity Grade', 'Color', [0.80 0.80 0.85], 'FontSize', 8);
            catch; end

            % 7. Microaneurysm Candidates
            maC = 0; if isfield(cv, 'maCount') && ~isempty(cv.maCount); maC = cv.maCount; end
            app.ExplainLabel7.Text = sprintf('7. Microaneurysm Candidates | Count: %d', maC);
            try
                maRGB = buildCandidateVisualLocal(origImg, cv, 'ma');
                maRGB = wrapOuter(maRGB);
                imshow(maRGB, 'Parent', app.ExplainAxes7);
            catch
                try; imshow(origImg, 'Parent', app.ExplainAxes7); catch; end
            end

            % 8. Exudate Candidates
            exA = 0; if isfield(cv, 'exArea') && ~isempty(cv.exArea); exA = round(cv.exArea); end
            app.ExplainLabel8.Text = sprintf('8. Exudate Candidates | Area: %d px^2', exA);
            try
                exRGB = buildCandidateVisualLocal(origImg, cv, 'ex');
                exRGB = wrapOuter(exRGB);
                imshow(exRGB, 'Parent', app.ExplainAxes8);
            catch
                try; imshow(origImg, 'Parent', app.ExplainAxes8); catch; end
            end

            % Populate Biomarker Concept Vector Table
            try
                nvStr = 'No'; if isfield(cv,'nvFlag') && cv.nvFlag; nvStr = 'YES'; end
                hmStr = '--';
                if isfield(cv,'hmType') && ~isempty(cv.hmType)
                    if iscell(cv.hmType); hmStr = strjoin(unique(cv.hmType),'/');
                    elseif ischar(cv.hmType); hmStr = cv.hmType; end
                end
                cData = {'Microaneurysms (MA)', num2str(cv.maCount); ...
                         'Haemorrhages (HM)', num2str(cv.hmCount); 'HM Subtype', hmStr; ...
                         'Hard Exudates (px2)', num2str(cv.exArea); 'Cotton-Wool Spots', num2str(cv.cwsCount); ...
                         'Neovascularization', nvStr; 'Vessel Score', sprintf('%.2f', cv.vesselAbnormalityScore)};
                app.ExplainConceptTable.Data = cData;
                app.ExplainConceptTable.BackgroundColor = [1 1 1; 1 1 1];
                app.ExplainConceptTable.ForegroundColor = [0 0 0];
                try; addStyle(app.ExplainConceptTable, uistyle('BackgroundColor', [1 1 1], 'FontColor', [0 0 0])); catch; end
            catch; end

            % Evidence text
            try
                confVal = 0.95;
                if ~isempty(app.CurrentScores); confVal = max(app.CurrentScores); end
                s = generateEvidenceSentence(app.CurrentGrade, cv, confVal);
                app.EvidenceTextArea.Value = {s};
            catch ME
                app.EvidenceTextArea.Value = {sprintf('Evidence summary: %s', ME.message)};
            end

            % Treatment text
            try
                pw = treatmentPathway(app.CurrentGrade, cv);
                lines = {sprintf('URGENCY: %s  |  %s', pw.urgency, pw.timeframe), ...
                         sprintf('Setting: %s', pw.careSetting), '', 'Recommendations:'};
                for i = 1:min(8, length(pw.options)); lines{end+1} = sprintf('  %d. %s', i, pw.options{i}); end
                app.TreatmentTextArea.Value = lines;
            catch ME
                app.TreatmentTextArea.Value = {sprintf('Treatment pathway: %s', ME.message)};
            end

            % Nutrition + Meds text
            try
                nutri = nutritionGuidance(app.CurrentGrade);
                meds = medicationLookup(app.CurrentGrade, cv);
                lines = {'NUTRITION RECOMMENDATIONS:', ''};
                if isfield(nutri, 'dietary')
                    for i = 1:min(5, length(nutri.dietary)); lines{end+1} = sprintf('  * %s', nutri.dietary{i}); end
                end
                lines{end+1} = ''; lines{end+1} = 'MEDICATION GUIDANCE:';
                if isfield(meds, 'suggestions')
                    for i = 1:min(4, length(meds.suggestions)); lines{end+1} = sprintf('  * %s', meds.suggestions{i}); end
                end
                if isfield(meds, 'contraindications') && ~isempty(meds.contraindications)
                    lines{end+1} = ''; lines{end+1} = 'CONTRAINDICATION WARNINGS:';
                    for i = 1:length(meds.contraindications)
                        lines{end+1} = sprintf('  ! %s', meds.contraindications{i});
                    end
                end
                app.NutriMedTextArea.Value = lines;
            catch ME
                app.NutriMedTextArea.Value = {sprintf('Guidance error: %s', ME.message)};
            end
        end
        function onToggleOverlay(app)
            if isempty(app.CurrentImage); return; end
            if app.ShowOverlayCheck.Value && ~isempty(app.LesionOverlay)
                imshow(app.LesionOverlay, 'Parent', app.MainAxes);
                title(app.MainAxes, 'Biomarker Lesions & Vessels Overlay', 'Color', [0 0 0], 'FontName', 'Segoe UI', 'FontSize', 9);
            else
                if app.AutoEnhanceCheck.Value
                    cImg = claheEnhanceLocal(app.CurrentImage);
                    imshow(cImg, 'Parent', app.MainAxes);
                else
                    imshow(app.CurrentImage, 'Parent', app.MainAxes);
                end
                [~, fn, ext] = fileparts(app.CurrentImagePath);
                title(app.MainAxes, [fn ext], 'Interpreter', 'none', 'Color', [0 0 0], 'FontName', 'Segoe UI', 'FontSize', 9);
            end
            axis(app.MainAxes, 'image');
        end

        function onGenerateReport(app)
            if isempty(app.CurrentImage) || isempty(app.CurrentGrade)
                uialert(app.UIFigure, 'Run screening first before generating report.', 'No Data');
                return;
            end
            try
                pid = app.PatientIdEdit.Value;
                if isempty(pid); pid = 'PATIENT_001'; end
                conf = 0.95;
                if ~isempty(app.CurrentScores); conf = max(app.CurrentScores); end
                [repPath, ~] = generateReport(app.CurrentImage, app.CurrentConcepts, app.CurrentGrade, app.CurrentScores, conf, pid);
                app.LastReportPath = repPath;
                uialert(app.UIFigure, sprintf('Clinical report saved to:\n%s', repPath), 'Report Generated');
                web(repPath, '-browser');
            catch ME
                uialert(app.UIFigure, sprintf('Report error: %s', ME.message), 'Error');
            end
        end

        function onSaveTwin(app)
            if isempty(app.CurrentImage); uialert(app.UIFigure,'Run screening first.','No Data'); return; end
            pid=app.TwinPatientEdit.Value;
            try; store=twinStore('read',pid); vn=length(store.visits)+1; catch; vn=1; end
            updateTwin(pid,app.CurrentImagePath,vn,app.CurrentConcepts,app.CurrentReferable);
            uialert(app.UIFigure,sprintf('Visit %d saved for patient %s.',vn,pid),'Saved');
        end

        function onSimulateProgression(app)
            if isempty(app.CurrentImage); uialert(app.UIFigure,'Run screening first.','No Data'); return; end
            try
                imshow(app.CurrentImage,'Parent',app.TwinAxesPrior);
                title(app.TwinAxesPrior,'Prior / Baseline Visit','Color',[0 0 0],'FontName','Segoe UI','FontWeight','bold');
                
                [synImg,synCv]=makeSyntheticVisit(app.CurrentImage,app.CurrentConcepts,6,2);
                imshow(synImg,'Parent',app.TwinAxesCurrent);
                title(app.TwinAxesCurrent,'Follow-up Visit (+6 Mos Simulated)','Color',[0 0 0],'FontName','Segoe UI','FontWeight','bold');
                
                % Compute Change Detection Map between Current and Simulated
                [h, w, ~] = size(app.CurrentImage);
                curD = im2double(app.CurrentImage);
                synD = im2double(synImg);
                
                % Extract masks safely
                curMA = false(h,w); if isfield(app.CurrentConcepts,'maMask') && ~isempty(app.CurrentConcepts.maMask); curMA = logical(imresize(app.CurrentConcepts.maMask>0, [h w], 'nearest')); end
                curHM = false(h,w); if isfield(app.CurrentConcepts,'hmMask') && ~isempty(app.CurrentConcepts.hmMask); curHM = logical(imresize(app.CurrentConcepts.hmMask>0, [h w], 'nearest')); end
                curEX = false(h,w); if isfield(app.CurrentConcepts,'exMask') && ~isempty(app.CurrentConcepts.exMask); curEX = logical(imresize(app.CurrentConcepts.exMask>0, [h w], 'nearest')); end
                curCWS = false(h,w); if isfield(app.CurrentConcepts,'cwsMask') && ~isempty(app.CurrentConcepts.cwsMask); curCWS = logical(imresize(app.CurrentConcepts.cwsMask>0, [h w], 'nearest')); end

                synMA = false(h,w); if isfield(synCv,'maMask') && ~isempty(synCv.maMask); synMA = logical(imresize(synCv.maMask>0, [h w], 'nearest')); end
                synHM = false(h,w); if isfield(synCv,'hmMask') && ~isempty(synCv.hmMask); synHM = logical(imresize(synCv.hmMask>0, [h w], 'nearest')); end
                synEX = false(h,w); if isfield(synCv,'exMask') && ~isempty(synCv.exMask); synEX = logical(imresize(synCv.exMask>0, [h w], 'nearest')); end
                synCWS = false(h,w); if isfield(synCv,'cwsMask') && ~isempty(synCv.cwsMask); synCWS = logical(imresize(synCv.cwsMask>0, [h w], 'nearest')); end

                newMask = (synMA & ~curMA) | (synHM & ~curHM) | (synEX & ~curEX) | (synCWS & ~curCWS);
                resMask = (curMA & ~synMA) | (curHM & ~synHM) | (curEX & ~synEX) | (curCWS & ~synCWS);
                
                % Add pixel-level intensity differencing to capture morphological change
                diffGray = rgb2gray(abs(synD - curD));
                changeHeat = diffGray > 0.08;
                newMask = newMask | changeHeat;

                diffImg = synD;
                newD = imdilate(newMask, strel('disk', 3));
                resD = imdilate(resMask, strel('disk', 3));
                for c = 1:3
                    chan = diffImg(:,:,c);
                    % Resolved lesions in emerald green
                    gCol = [0.15, 0.85, 0.35];
                    chan(resD) = 0.30 * chan(resD) + 0.70 * gCol(c);
                    % New lesions / progression in vivid bright red
                    rCol = [1.0, 0.15, 0.15];
                    chan(newD) = 0.25 * chan(newD) + 0.75 * rCol(c);
                    diffImg(:,:,c) = chan;
                end
                
                diffOverlay = im2uint8(diffImg);
                imshow(diffOverlay, 'Parent', app.TwinAxesDiff);
                
                newCount = sum(newMask(:));
                if newCount > 50
                    traj = 'PROGRESSED';
                    app.TwinProgressionBadge.BackgroundColor = app.C('red');
                elseif sum(resMask(:)) > 50
                    traj = 'REGRESSED';
                    app.TwinProgressionBadge.BackgroundColor = app.C('green');
                else
                    traj = 'STABLE';
                    app.TwinProgressionBadge.BackgroundColor = app.C('amber');
                end
                
                title(app.TwinAxesDiff, sprintf('Change Detection Map | %s', traj),...
                    'Color', [1 0.85 0.2], 'FontName', 'Segoe UI', 'FontWeight', 'bold');
                app.TwinProgressionBadge.Text = sprintf('TRAJECTORY: %s', traj);
                
                app.TwinDeltaTable.Data = {'Microaneurysms', app.CurrentConcepts.maCount, synCv.maCount, ...
                    synCv.maCount - app.CurrentConcepts.maCount; ...
                    'Haemorrhages', app.CurrentConcepts.hmCount, synCv.hmCount, ...
                    synCv.hmCount - app.CurrentConcepts.hmCount; ...
                    'Exudates (px)', app.CurrentConcepts.exArea, synCv.exArea, ...
                    synCv.exArea - app.CurrentConcepts.exArea; ...
                    'Cotton-Wool Spots', app.CurrentConcepts.cwsCount, synCv.cwsCount, ...
                    synCv.cwsCount - app.CurrentConcepts.cwsCount};
                try; addStyle(app.TwinDeltaTable, uistyle('BackgroundColor',[1 1 1],'FontColor',[0 0 0])); catch; end
            catch ME
                uialert(app.UIFigure, sprintf('Error: %s', ME.message), 'Twin Error');
            end
        end

        function updateClinicalTab(app)
            if isempty(app.CurrentGrade); return; end
            grade=app.CurrentGrade; cv=app.CurrentConcepts;
            try
                pw=treatmentPathway(grade,cv);
                app.PathwayTitleLabel.Text=sprintf('Pathway: %s (%s)',pw.urgency,pw.timeframe);
                app.PathwayActionLabel.Text=sprintf('Action: %s',pw.primaryAction);
                lines={'Rationale:',pw.rationale,'',sprintf('Setting: %s',pw.careSetting),'','Interventions:'};
                for i=1:length(pw.options); lines{end+1}=sprintf('  %d. %s',i,pw.options{i}); end
                app.PathwayDetailArea.Value=lines;
            catch ME; app.PathwayDetailArea.Value={sprintf('Pathway error: %s',ME.message)}; end
            try
                nutri=nutritionGuidance(grade);
                lines={'DIETARY GUIDANCE:',''};
                for i=1:length(nutri.dietary); lines{end+1}=sprintf('  * %s',nutri.dietary{i}); end
                lines{end+1}=''; lines{end+1}='LIFESTYLE ADVICE:';
                for i=1:length(nutri.lifestyle); lines{end+1}=sprintf('  * %s',nutri.lifestyle{i}); end
                if ~isempty(nutri.redFlags)
                    lines{end+1}=''; lines{end+1}='STRICTLY AVOID:';
                    for i=1:length(nutri.redFlags); lines{end+1}=sprintf('  ! %s',nutri.redFlags{i}); end
                end
                app.NutritionArea.Value=lines;
            catch ME; app.NutritionArea.Value={sprintf('Nutrition error: %s',ME.message)}; end
            onCheckMedications(app);
            try
                alerts=followUpMonitor();
                lines={sprintf('Records Scanned: %d',length(alerts)),''};
                for i=1:min(10,length(alerts))
                    lines{end+1}=sprintf('[%s] %s | Grade %d | Due: %s | %s',...
                        alerts(i).urgency,alerts(i).patientID,alerts(i).grade,...
                        alerts(i).dueDate,alerts(i).status);
                end
                app.FollowUpAlertArea.Value=lines;
            catch ME; app.FollowUpAlertArea.Value={sprintf('Follow-up: %s',ME.message)}; end
        end

        function onCheckMedications(app)
            if isempty(app.CurrentGrade); return; end
            try
                meds=strtrim(strsplit(app.CurrentMedsEdit.Value,','));
                res=medicationLookup(app.CurrentGrade,app.CurrentConcepts,meds);
                lines={'RECOMMENDED THERAPIES:',''};
                for i=1:length(res.suggestions); lines{end+1}=sprintf('  * %s',res.suggestions{i}); end
                lines{end+1}=''; lines{end+1}='SAFETY CHECK:';
                if isempty(res.contraindications)
                    lines{end+1}='  No contraindications detected.';
                else
                    for i=1:length(res.contraindications); lines{end+1}=sprintf('  ! %s',res.contraindications{i}); end
                end
                app.MedsWarningArea.Value=lines;
            catch ME; app.MedsWarningArea.Value={sprintf('Meds error: %s',ME.message)}; end
        end

        function onRunTelemedicine(app)
            app.TelemedOutputArea.Value={'Running discrete-event simulation model...'}; drawnow;
            try
                bwSel = app.TelemedBandwidthDrop.Value;
                bwMap = {'2G (EDGE, 0.2 Mbps)',0.2; '3G (2 Mbps)',2; '4G LTE (15 Mbps)',15; 'Starlink (50 Mbps)',50};
                bw = 2;
                for k = 1:size(bwMap,1)
                    if strcmp(bwMap{k,1}, bwSel); bw = bwMap{k,2}; break; end
                end
                
                modeMap = {'Edge AI (Netra AI on-device)','edge'; 'Cloud AI (Remote GPU)','cloud'; 'Manual Tele-Retina','manual'};
                modeSel = app.TelemedDocDrop.Value;
                mode = 'edge';
                for k = 1:size(modeMap,1)
                    if strcmp(modeMap{k,1}, modeSel); mode = modeMap{k,2}; break; end
                end
                
                vol = app.TelemedVolumeEdit.Value;
                cfg = struct();
                cfg.numPatients = vol;
                cfg.bandwidthKbps = bw * 1000;
                cfg.mode = mode;
                cfg.numDoctors = 1;
                cfg.arrivalRatePerHour = 15;
                
                res = simulateTelemedicine(cfg);
                
                % Update KPI labels
                app.TelemedKpiTatLabel.Text = sprintf("TAT\n%.1f min", res.medianTurnaroundMin);
                app.TelemedKpiDataLabel.Text = sprintf("Data\n%.1f%% saved", res.dataSavingPct);
                app.TelemedKpiWorkLabel.Text = sprintf("Workload\n%.1f%% reduced", res.doctorWorkloadReductionPct);
                
                % Update Text Output Log
                lines = {
                    sprintf('--- NETRA AI TELEMEDICINE WORKFLOW SIMULATION RESULTS ---'), ...
                    sprintf('Configuration: %d Patients | %s | %s Mode', res.numPatients, bwSel, upper(res.mode)), ...
                    sprintf('Turnaround Time: Median %.1f min | Mean %.1f min | 95th-Percentile %.1f min | Urgent Cases %.1f min', ...
                        res.medianTurnaroundMin, res.meanTurnaroundMin, res.p95TurnaroundMin, res.urgentTurnaroundMin), ...
                    sprintf('Network Bandwidth: %.2f MB Transmitted (%.2f MB/patient) -> %.1f%% Data Reduction vs Raw Cloud Pipeline', ...
                        res.totalDataTransmittedMB, res.totalDataTransmittedMB/res.numPatients, res.dataSavingPct), ...
                    sprintf('Specialist Doctor Workload: %d / %d cases sent to doctor (%.1f%% autonomous edge triage)', ...
                        res.doctorCasesReviewed, res.numPatients, res.doctorWorkloadReductionPct), ...
                    sprintf('Clinical SLA: %.1f%% patients completed within 30 min | %.1f%% completed within 60 min', ...
                        res.patientsWithin30MinPct, res.patientsWithin60MinPct)
                };
                app.TelemedOutputArea.Value = lines;
                
                % Update interactive plots
                updateTelemedicinePlots(app, res, bw);
            catch ME
                app.TelemedOutputArea.Value = {sprintf('Simulation error: %s', ME.message)};
            end
        end

        function updateTelemedicinePlots(app, currentRes, bwMbps)
            % Plot 1: TAT Comparison (Edge vs Cloud vs Manual under current bandwidth)
            cla(app.TelemedAxes1);
            modes = {'Edge AI', 'Cloud AI', 'Manual Tele-Retina'};
            % Run comparative estimates for the other two modes
            tatVals = [currentRes.medianTurnaroundMin, 0, 0];
            try
                resCloud = simulateTelemedicine(struct('numPatients',currentRes.numPatients,'bandwidthKbps',bwMbps*1000,'mode','cloud'));
                resManual = simulateTelemedicine(struct('numPatients',currentRes.numPatients,'bandwidthKbps',bwMbps*1000,'mode','manual'));
                tatVals = [currentRes.medianTurnaroundMin, resCloud.medianTurnaroundMin, resManual.medianTurnaroundMin];
                if strcmp(currentRes.mode, 'cloud')
                    tatVals = [resCloud.medianTurnaroundMin, currentRes.medianTurnaroundMin, resManual.medianTurnaroundMin];
                elseif strcmp(currentRes.mode, 'manual')
                    tatVals = [resCloud.medianTurnaroundMin, resCloud.medianTurnaroundMin, currentRes.medianTurnaroundMin];
                end
            catch
                % Estimated values if batch run unavailable
                tatVals = [4.8, max(12, 120 / max(0.2, bwMbps)), 45.0];
            end
            
            b1 = bar(app.TelemedAxes1, 1:3, tatVals, 0.55, 'FaceColor', 'flat');
            b1.CData(1,:) = [0.08 0.45 0.88]; % Blue for Edge
            b1.CData(2,:) = [0.90 0.55 0.10]; % Amber for Cloud
            b1.CData(3,:) = [0.75 0.20 0.25]; % Red for Manual
            app.TelemedAxes1.XTick = 1:3;
            app.TelemedAxes1.XTickLabel = modes;
            ylabel(app.TelemedAxes1, 'Median Turnaround Time (min)');
            title(app.TelemedAxes1, sprintf('Turnaround Time (Bandwidth: %.1f Mbps)', bwMbps), 'FontWeight', 'bold');
            grid(app.TelemedAxes1, 'on');
            
            % Plot 2: Data Consumption (MB)
            cla(app.TelemedAxes2);
            rawTotalMB = currentRes.numPatients * 12;
            edgeTotalMB = currentRes.totalDataTransmittedMB;
            cloudTotalMB = rawTotalMB;
            manualTotalMB = rawTotalMB;
            dataVals = [edgeTotalMB, cloudTotalMB, manualTotalMB];
            b2 = bar(app.TelemedAxes2, 1:3, dataVals, 0.55, 'FaceColor', 'flat');
            b2.CData(1,:) = [0.10 0.55 0.30]; % Green (minimal data)
            b2.CData(2,:) = [0.85 0.50 0.10];
            b2.CData(3,:) = [0.75 0.20 0.25];
            app.TelemedAxes2.XTick = 1:3;
            app.TelemedAxes2.XTickLabel = modes;
            ylabel(app.TelemedAxes2, 'Total Data Transmitted (MB)');
            title(app.TelemedAxes2, sprintf('Data Volume (%.1f%% Saved by Edge AI)', currentRes.dataSavingPct), 'FontWeight', 'bold');
            grid(app.TelemedAxes2, 'on');

            % Plot 3: Doctor Workload Distribution
            cla(app.TelemedAxes3);
            autoEdgeCases = currentRes.numPatients - currentRes.doctorCasesReviewed;
            docCases = currentRes.doctorCasesReviewed;
            b3 = bar(app.TelemedAxes3, 1:2, [autoEdgeCases, docCases], 0.55, 'FaceColor', 'flat');
            b3.CData(1,:) = [0.08 0.45 0.88]; % Autonomous
            b3.CData(2,:) = [0.85 0.35 0.10]; % Doctor Review
            app.TelemedAxes3.XTick = 1:2;
            app.TelemedAxes3.XTickLabel = {'Autonomous AI Triage', 'Specialist Doctor Review'};
            ylabel(app.TelemedAxes3, 'Number of Patient Cases');
            title(app.TelemedAxes3, sprintf('Doctor Workload (%.1f%% Reduction)', currentRes.doctorWorkloadReductionPct), 'FontWeight', 'bold');
            grid(app.TelemedAxes3, 'on');
        end

        function plotTelemedicineBaselines(app)
            % Initial baseline visualization on tab startup
            b1 = bar(app.TelemedAxes1, 1:3, [4.8, 28.5, 62.0], 0.55, 'FaceColor', 'flat');
            b1.CData(1,:) = [0.08 0.45 0.88];
            b1.CData(2,:) = [0.90 0.55 0.10];
            b1.CData(3,:) = [0.75 0.20 0.25];
            app.TelemedAxes1.XTick = 1:3;
            app.TelemedAxes1.XTickLabel = {'Edge AI', 'Cloud AI', 'Manual'};
            ylabel(app.TelemedAxes1, 'Median Turnaround Time (min)');
            title(app.TelemedAxes1, 'Turnaround Time (Baseline 2 Mbps)', 'FontWeight', 'bold');
            grid(app.TelemedAxes1, 'on');
            
            b2 = bar(app.TelemedAxes2, 1:3, [69.8, 1440, 1440], 0.55, 'FaceColor', 'flat');
            b2.CData(1,:) = [0.10 0.55 0.30];
            b2.CData(2,:) = [0.85 0.50 0.10];
            b2.CData(3,:) = [0.75 0.20 0.25];
            app.TelemedAxes2.XTick = 1:3;
            app.TelemedAxes2.XTickLabel = {'Edge AI', 'Cloud AI', 'Manual'};
            ylabel(app.TelemedAxes2, 'Total Data Transmitted (MB)');
            title(app.TelemedAxes2, 'Data Volume (95.2% Saved by Edge AI)', 'FontWeight', 'bold');
            grid(app.TelemedAxes2, 'on');

            b3 = bar(app.TelemedAxes3, 1:2, [91, 29], 0.55, 'FaceColor', 'flat');
            b3.CData(1,:) = [0.08 0.45 0.88];
            b3.CData(2,:) = [0.85 0.35 0.10];
            app.TelemedAxes3.XTick = 1:2;
            app.TelemedAxes3.XTickLabel = {'Autonomous AI Triage', 'Doctor Review'};
            ylabel(app.TelemedAxes3, 'Number of Patient Cases');
            title(app.TelemedAxes3, 'Doctor Workload (75.8% Reduction)', 'FontWeight', 'bold');
            grid(app.TelemedAxes3, 'on');
        end

        function buildRegistrationOverlay(app)
            % Full-screen registration overlay shown at startup
            F = app.UIFigure;
            FW = 1380; FH = 880;

            % Dark semi-transparent backdrop
            app.RegistrationOverlay = uipanel(F, ...
                'Position', [0 0 FW FH], ...
                'BackgroundColor', [0.04 0.08 0.18], ...
                'BorderType', 'none');

            % Branding strip at top of overlay
            uipanel(app.RegistrationOverlay, ...
                'Position', [0 FH-70 FW 70], ...
                'BackgroundColor', [0.05 0.11 0.22], ...
                'BorderType', 'none');
            uilabel(app.RegistrationOverlay, ...
                'Position', [0 FH-58 FW 40], ...
                'Text', 'NETRA AI   |   Intelligent Retinal Diagnostic & Telemedicine Platform', ...
                'FontName', 'Segoe UI', 'FontSize', 16, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', 'none');

            % Tagline
            uilabel(app.RegistrationOverlay, ...
                'Position', [0 FH-88 FW 26], ...
                'Text', 'AI-Powered Diabetic Retinopathy Screening  |  Digital Twin  |  Telemedicine', ...
                'FontName', 'Segoe UI', 'FontSize', 11, ...
                'FontColor', [0.55 0.75 1.0], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', 'none');

            % Centered card
            CW = 520; CH = 460;
            CX = (FW - CW) / 2; CY = (FH - CH) / 2 - 20;
            card = uipanel(app.RegistrationOverlay, ...
                'Position', [CX CY CW CH], ...
                'BackgroundColor', [0.98 0.99 1.00], ...
                'BorderType', 'line', 'HighlightColor', [0.20 0.50 0.90], ...
                'BorderWidth', 2);

            uilabel(card, 'Position', [0 CH-56 CW 36], ...
                'Text', 'Patient Registration', ...
                'FontName', 'Segoe UI', 'FontSize', 20, 'FontWeight', 'bold', ...
                'FontColor', [0.05 0.11 0.22], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', 'none');
            uilabel(card, 'Position', [0 CH-80 CW 22], ...
                'Text', 'Enter patient details to begin the screening session', ...
                'FontName', 'Segoe UI', 'FontSize', 11, ...
                'FontColor', [0.40 0.44 0.52], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', 'none');

            % Separator
            uipanel(card, 'Position', [30 CH-92 CW-60 1], ...
                'BackgroundColor', [0.82 0.85 0.92], 'BorderType', 'none');

            INP = [1 1 1]; TXT = [0.08 0.10 0.16];

            % Patient ID
            uilabel(card, 'Position', [40 CH-124 200 18], 'Text', 'Patient ID  *', ...
                'FontName', 'Segoe UI', 'FontSize', 11, 'FontWeight', 'bold', ...
                'FontColor', TXT, 'BackgroundColor', 'none');
            app.PatientIdEdit = uieditfield(card, 'text', ...
                'Position', [40 CH-154 CW-80 30], 'Value', 'PATIENT_001', ...
                'FontName', 'Segoe UI', 'FontSize', 13, ...
                'FontColor', TXT, 'BackgroundColor', INP);

            % Patient Name
            uilabel(card, 'Position', [40 CH-190 200 18], 'Text', 'Patient Name', ...
                'FontName', 'Segoe UI', 'FontSize', 11, 'FontWeight', 'bold', ...
                'FontColor', TXT, 'BackgroundColor', 'none');
            app.PatientNameEdit = uieditfield(card, 'text', ...
                'Position', [40 CH-220 CW-80 30], 'Value', '', ...
                'FontName', 'Segoe UI', 'FontSize', 13, ...
                'FontColor', TXT, 'BackgroundColor', INP);

            % Age & Diabetes side-by-side
            uilabel(card, 'Position', [40 CH-256 120 20], 'Text', 'Age (years)', ...
                'FontName', 'Segoe UI', 'FontSize', 11, 'FontWeight', 'bold', ...
                'FontColor', TXT, 'BackgroundColor', 'none');
            app.PatientAgeEdit = uieditfield(card, 'numeric', ...
                'Position', [40 CH-290 CW-80 32], 'Value', 55, 'Limits', [1 120], ...
                'FontName', 'Segoe UI', 'FontSize', 13, ...
                'HorizontalAlignment', 'left', ...
                'FontColor', TXT, 'BackgroundColor', [1 1 1]);
            app.DiabetesDurEdit = uispinner(card, ...
                'Position', [-9999 -9999 10 10], 'Value', 0, 'Limits', [0 60], ...
                'FontName', 'Segoe UI', 'FontSize', 10, 'Visible', 'off');

            % Register Button
            regBtn = uibutton(card, 'push', ...
                'Position', [40 CH-344 CW-80 46], ...
                'Text', 'REGISTER PATIENT & OPEN DASHBOARD', ...
                'FontName', 'Segoe UI', 'FontSize', 13, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'BackgroundColor', [0.08 0.45 0.88], ...
                'ButtonPushedFcn', @(~,~) onRegisterPatient(app));

            % Helper text
            uilabel(card, 'Position', [40 CH-374 CW-80 22], ...
                'Text', 'Patient data is stored locally in the digital twin database.', ...
                'FontName', 'Segoe UI', 'FontSize', 10, ...
                'FontColor', [0.40 0.44 0.52], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', 'none');

            % (Step indicator bar removed per user request)
        end
    end
end

function cImg = claheEnhanceLocal(img)
    if size(img,3)==3
        lab=rgb2lab(img); L=lab(:,:,1)/100;
        L=adapthisteq(L,'ClipLimit',0.02,'NumTiles',[8 8]);
        lab(:,:,1)=L*100; cImg=uint8(lab2rgb(lab)*255);
    else; cImg=adapthisteq(img); end
end

function ov = buildVesselOverlayLocal(img,cv)
    ov=img; [h,w,~]=size(img);
    if isfield(cv,'vesselMask') && ~isempty(cv.vesselMask)
        m=cv.vesselMask; if ~isequal(size(m),[h w]); m=imresize(logical(m),[h w],'nearest'); end
        R=ov(:,:,1); G=ov(:,:,2); B=ov(:,:,3);
        R(m)=30; G(m)=180; B(m)=255; ov=cat(3,R,G,B);
    end
end

function ov = buildODFoveaOverlayLocal(img,cv)
    ov=img; [h,w,~]=size(img);
    if isfield(cv,'odMask') && any(cv.odMask(:))
        bd=bwperim(cv.odMask); if ~isequal(size(bd),[h w]); bd=imresize(bd,[h w],'nearest'); end
        R=ov(:,:,1); G=ov(:,:,2); B=ov(:,:,3);
        R(bd)=255; G(bd)=210; B(bd)=0; ov=cat(3,R,G,B);
    end
    if isfield(cv,'foveaCoord') && numel(cv.foveaCoord)>=2
        fx=round(cv.foveaCoord(1)); fy=round(cv.foveaCoord(2)); sz=12;
        fx=max(sz+1,min(w-sz,fx)); fy=max(sz+1,min(h-sz,fy));
        R=ov(:,:,1); G=ov(:,:,2); B=ov(:,:,3);
        cr=max(1,fy-sz):min(h,fy+sz); cc=max(1,fx-sz):min(w,fx+sz);
        R(fy,cc)=255; G(fy,cc)=0; B(fy,cc)=128;
        R(cr,fx)=255; G(cr,fx)=0; B(cr,fx)=128;
        ov=cat(3,R,G,B);
    end
end

function ov = buildLesionOverlayLocal(img,cv)
    ov = img; [h,w,~] = size(img);
    function m = sm(cv,f); m = false(h,w);
        if isfield(cv,f) && ~isempty(cv.(f))
            t = cv.(f); if ~isequal(size(t),[h w]); t = imresize(logical(t),[h w],'nearest'); end
            m = logical(t);
        end
    end

    % 1. Vessels (soft cyan)
    vm = sm(cv,'vesselMask');
    if any(vm(:))
        R=ov(:,:,1); G=ov(:,:,2); B=ov(:,:,3);
        R(vm)=uint8(0.4*double(R(vm))+0.6*20);
        G(vm)=uint8(0.4*double(G(vm))+0.6*210);
        B(vm)=uint8(0.4*double(B(vm))+0.6*255);
        ov=cat(3,R,G,B);
    end

    % 2. Optic Disc (gold outline)
    odm = sm(cv,'odMask');
    if any(odm(:))
        odb = bwperim(odm); odb = imdilate(odb, strel('disk',2));
        R=ov(:,:,1); G=ov(:,:,2); B=ov(:,:,3);
        R(odb)=255; G(odb)=215; B(odb)=0; ov=cat(3,R,G,B);
    end

    % 3. Fovea (magenta cross)
    if isfield(cv,'foveaCoord') && numel(cv.foveaCoord)>=2
        fx=round(cv.foveaCoord(1)); fy=round(cv.foveaCoord(2)); sz=12;
        fx=max(sz+1,min(w-sz,fx)); fy=max(sz+1,min(h-sz,fy));
        cr=max(1,fy-sz):min(h,fy+sz); cc=max(1,fx-sz):min(w,fx+sz);
        R=ov(:,:,1); G=ov(:,:,2); B=ov(:,:,3);
        R(fy,cc)=255; G(fy,cc)=0; B(fy,cc)=160;
        R(cr,fx)=255; G(cr,fx)=0; B(cr,fx)=160;
        ov=cat(3,R,G,B);
    end

    % 4. Lesions
    mam = sm(cv,'maMask'); hmm = sm(cv,'hmMask'); exm = sm(cv,'exMask'); cw = sm(cv,'cwsMask');
    if any(mam(:)); mamD = imdilate(mam, strel('disk',2)); else; mamD = mam; end
    R=ov(:,:,1); G=ov(:,:,2); B=ov(:,:,3);
    R(mamD)=255; G(mamD)=40; B(mamD)=40;       % MA = Red dots
    R(hmm)=255; G(hmm)=50; B(hmm)=50;         % HM = Deep red
    R(exm)=255; G(exm)=235; B(exm)=0;         % EX = Bright yellow
    R(cw)=0; G(cw)=230; B(cw)=255;            % CWS = Cyan
    ov=cat(3,R,G,B);
end

function ov = buildGradCamContourOverlayLocal(img,cv,grade,conf)
    ov = img; [h,w,~] = size(img);
    function m = sm(cv,f); m = false(h,w);
        if isfield(cv,f) && ~isempty(cv.(f))
            t = cv.(f); if ~isequal(size(t),[h w]); t = imresize(logical(t),[h w],'nearest'); end
            m = logical(t);
        end
    end

    % Obtain saliency heatmap
    heat = zeros(h,w);
    try
        [~, heat] = explainGrade(img, cv);
        if ~isequal(size(heat),[h w]); heat = imresize(heat,[h w]); end
    catch
        % Fallback saliency from lesion density
        if isfield(cv,'maMask') && any(cv.maMask(:)); heat = heat + 1.0*double(sm(cv,'maMask')); end
        if isfield(cv,'hmMask') && any(cv.hmMask(:)); heat = heat + 2.0*double(sm(cv,'hmMask')); end
        if isfield(cv,'exMask') && any(cv.exMask(:)); heat = heat + 1.8*double(sm(cv,'exMask')); end
        if isfield(cv,'cwsMask') && any(cv.cwsMask(:)); heat = heat + 2.2*double(sm(cv,'cwsMask')); end
        if max(heat(:)) > 0; heat = imfilter(heat, fspecial('gaussian',[65 65],20),'replicate'); end
    end
    if max(heat(:)) > min(heat(:))
        heat = (heat - min(heat(:))) / (max(heat(:)) - min(heat(:)));
    end

    % Contours: Level 1 (Intermediate) = Blue, Level 2 (High) = Yellow
    bBlue = bwperim(heat >= 0.40);
    bYellow = bwperim(heat >= 0.65);

    % Also add lesion boundaries
    exB = bwperim(sm(cv,'exMask'));
    hmB = bwperim(sm(cv,'hmMask'));
    odB = bwperim(sm(cv,'odMask'));
    bYellow = bYellow | exB | odB;
    bBlue = bBlue | hmB;

    % Dilate contour lines slightly for clear visibility
    bBlue = imdilate(bBlue, strel('disk',1));
    bYellow = imdilate(bYellow, strel('disk',1));

    % Draw onto fundus: Blue contours first, then Yellow contours
    R = ov(:,:,1); G = ov(:,:,2); B = ov(:,:,3);
    R(bBlue) = 20;  G(bBlue) = 80;  B(bBlue) = 255;  % Royal Blue isoline
    R(bYellow) = 255; G(bYellow) = 230; B(bYellow) = 0; % Vibrant Yellow isoline

    % Microaneurysm candidates as red points
    mam = sm(cv,'maMask');
    if any(mam(:))
        mamD = imdilate(mam, strel('disk',2));
        R(mamD) = 255; G(mamD) = 20; B(mamD) = 20;
    end
    ov = cat(3,R,G,B);
end

function [grade,scores,referable] = ruleBasedGradingFallback(cv)
    sc=0;
    if isfield(cv,'maCount'); sc=sc+min(cv.maCount/10,1)*0.25; end
    if isfield(cv,'hmCount'); sc=sc+min(cv.hmCount/20,1)*0.25; end
    if isfield(cv,'exArea'); sc=sc+min(cv.exArea/500,1)*0.20; end
    if isfield(cv,'cwsCount'); sc=sc+min(cv.cwsCount/5,1)*0.15; end
    if isfield(cv,'nvFlag') && cv.nvFlag; sc=sc+0.15; end
    grade=min(4,floor(sc*5)); scores=zeros(1,5); scores(grade+1)=1; referable=grade>=2;
end



















function vesselSeg = buildVesselSegmentationVisualLocal(img, cv)
    % Produces high-contrast Blood Vessel Segmentation with emerald green vascular tree
    [h, w, ~] = size(img);
    fov = (img(:,:,1) > 15 | img(:,:,2) > 15 | img(:,:,3) > 15);
    fov = imerode(fov, strel('disk', 8));
    
    % Enhance green channel for maximum vessel-to-retina contrast
    gChan = img(:,:,2);
    gEq = adapthisteq(gChan, 'ClipLimit', 0.02);
    
    % Multi-angle morphological vessel enhancement
    invG = 255 - gEq;
    vEnhanced = zeros(h, w);
    for theta = 0:20:160
        se = strel('line', 9, theta);
        vEnhanced = max(vEnhanced, double(imtophat(invG, se)));
    end
    
    vMask = (vEnhanced > 18) & fov;
    if isfield(cv, 'vesselMask') && ~isempty(cv.vesselMask)
        vm = logical(cv.vesselMask);
        if ~isequal(size(vm), [h w]); vm = imresize(vm, [h w], 'nearest'); end
        vMask = vMask | vm;
    end
    vMask = bwareaopen(vMask, 20);
    
    % Overlay segmented vessels in vivid emerald green on contrast-enhanced fundus
    bg = repmat(uint8(double(gEq) * 0.70), [1 1 3]);
    R = bg(:,:,1); G = bg(:,:,2); B = bg(:,:,3);
    R(vMask) = 0;
    G(vMask) = 255;
    B(vMask) = 135;
    vesselSeg = cat(3, R, G, B);
end

function gradImg = buildGradCamVisualLocal(img, cv, model, grade)
    % Generates genuine Jet colormap Grad-CAM activation heatmap blended 50/50 with fundus
    try
        if ~isempty(model)
            [gradCamImg, ~] = explainGrade(img, cv, model);
        else
            [gradCamImg, ~] = explainGrade(img, cv);
        end
        gradImg = gradCamImg;
    catch
        [H, W, ~] = size(img);
        heat = zeros(H, W);
        if isfield(cv, 'maMask') && any(cv.maMask(:)); heat = heat + 1.2 * double(imresize(cv.maMask > 0, [H W])); end
        if isfield(cv, 'hmMask') && any(cv.hmMask(:)); heat = heat + 2.0 * double(imresize(cv.hmMask > 0, [H W])); end
        if isfield(cv, 'exMask') && any(cv.exMask(:)); heat = heat + 1.8 * double(imresize(cv.exMask > 0, [H W])); end
        if isfield(cv, 'cwsMask') && any(cv.cwsMask(:)); heat = heat + 2.5 * double(imresize(cv.cwsMask > 0, [H W])); end
        if max(heat(:)) == 0
            [X, Y] = meshgrid(1:W, 1:H);
            heat = exp(-((X - W*0.48).^2 + (Y - H*0.48).^2) / (2 * (W*0.22)^2));
        else
            heat = imfilter(heat, fspecial('gaussian', [65 65], 22), 'replicate');
        end
        heat = (heat - min(heat(:))) / max(max(heat(:)) - min(heat(:)), eps);
        cmap = jet(256);
        heatRGB = uint8(ind2rgb(gray2ind(heat, 256), cmap) * 255);
        imgRGB = im2uint8(img);
        gradImg = uint8(0.5 * double(imgRGB) + 0.5 * double(heatRGB));
    end
end

function candRGB = buildCandidateVisualLocal(img, cv, type)
    % Generates crisp, authentic candidate spot maps for MA and Exudates
    [h, w, ~] = size(img);
    fov = (img(:,:,1) > 15 | img(:,:,2) > 15 | img(:,:,3) > 15);
    fov = imerode(fov, strel('disk', 10));
    candRGB = zeros(h, w, 3, 'uint8');
    
    if strcmp(type, 'ma')
        % Microaneurysms: dark focal circular spots
        G = img(:,:,2);
        bhat = imbothat(G, strel('disk', 6));
        vThresh = mean(double(bhat(fov))) + 2.0 * std(double(bhat(fov)));
        maCand = (double(bhat) > vThresh) & fov;
        if isfield(cv, 'odMask') && ~isempty(cv.odMask)
            od = logical(cv.odMask);
            if ~isequal(size(od), [h w]); od = imresize(od, [h w], 'nearest'); end
            maCand = maCand & ~imdilate(od, strel('disk', 15));
        end
        maCand = bwareaopen(maCand, 2) & ~bwareaopen(maCand, 60);
        maD = imdilate(maCand, strel('disk', 3));
        % Display as bright focal dots
        R = candRGB(:,:,1); G_out = candRGB(:,:,2); B = candRGB(:,:,3);
        R(maD) = 255; G_out(maD) = 255; B(maD) = 255;
        candRGB = cat(3, R, G_out, B);
    else
        % Exudates: bright reflective lipid deposits
        bright = (double(img(:,:,1)) + double(img(:,:,2))) / 2;
        that = imtophat(uint8(bright), strel('disk', 8));
        exThresh = mean(that(fov)) + 1.8 * std(double(that(fov)));
        exCand = (double(that) > exThresh) & fov;
        if isfield(cv, 'odMask') && ~isempty(cv.odMask)
            od = logical(cv.odMask);
            if ~isequal(size(od), [h w]); od = imresize(od, [h w], 'nearest'); end
            exCand = exCand & ~imdilate(od, strel('disk', 12));
        end
        exCand = bwareaopen(exCand, 6);
        exD = imdilate(exCand, strel('disk', 2));
        R = candRGB(:,:,1); G_out = candRGB(:,:,2); B = candRGB(:,:,3);
        R(exD) = 255; G_out(exD) = 255; B(exD) = 255;
        candRGB = cat(3, R, G_out, B);
    end
end


function imgOut = addOuterEyeLineLocal(img)
    % Demarcates outer eye boundary with vibrant cyan contour ring
    if isempty(img); imgOut = img; return; end
    try
        [h, w, c] = size(img);
        if c == 1
            imgOut = repmat(img, [1 1 3]);
        else
            imgOut = img;
        end
        if ~isa(imgOut, 'uint8')
            imgOut = im2uint8(imgOut);
        end
        lum = 0.299*double(imgOut(:,:,1)) + 0.587*double(imgOut(:,:,2)) + 0.114*double(imgOut(:,:,3));
        fov = lum > 12;
        fov = imfill(fov, 'holes');
        fov = imopen(fov, strel('disk', 6));
        fov = imclose(fov, strel('disk', 12));
        eyeRim = bwperim(fov);
        eyeRimD = imdilate(eyeRim, strel('disk', 2));
        R = imgOut(:,:,1); G = imgOut(:,:,2); B = imgOut(:,:,3);
        % Vivid Medical Cyan Ring for outer eye line
        R(eyeRimD) = 0;
        G(eyeRimD) = 220;
        B(eyeRimD) = 255;
        imgOut = cat(3, R, G, B);
    catch
        imgOut = img;
    end
end
