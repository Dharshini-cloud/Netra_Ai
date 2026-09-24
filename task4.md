# Iteration 3 Complete: Grading Model + Explainability

**Phases 4 and 5 are fully written.** The pipeline can now go from an image all the way to a styled HTML clinical report.

## Phase 4 — DR Grading Model

### [`buildConceptBottleneckNet.m`](file:///d:/Downloads/Netra_Ai_DR/src/grading/buildConceptBottleneckNet.m)
- Loads pretrained **ResNet-50** and strips the classification head.
- Adds a Global Average Pooling + Flatten branch to produce a 2048-d image embedding.
- A separate `featureInputLayer` branch (FC32 → FC16) processes the concept vector.
- Both branches **concatenate** → FC256 → BN → Dropout(0.4) → FC5 → Softmax.

### [`trainGradingModel.m`](file:///d:/Downloads/Netra_Ai_DR/src/grading/trainGradingModel.m)
- Builds combined `imageDatastore` + `arrayDatastore` (concept vectors) via `combine()`.
- On-the-fly augmentation: rotations, reflections, x/y scaling.
- Adam optimizer, lr=1e-4, **early stopping** (patience=5 on val loss), saves `gradingModel_v1.mat`.
- Versioned save — won't overwrite existing models, auto-increments version number.

### [`calibrateThreshold.m`](file:///d:/Downloads/Netra_Ai_DR/src/grading/calibrateThreshold.m)
- Runs inference on the **validation set** (not test).
- Computes `P(referable) = P(grade≥2)` and plots the full ROC curve via `perfcurve`.
- Selects the operating point with **minimum FPR** (maximum specificity) subject to **sensitivity ≥ 90%**.
- Saves `referableThreshold.mat`.

### [`predictGrade.m`](file:///d:/Downloads/Netra_Ai_DR/src/grading/predictGrade.m)
- Single entry-point accepting `(img, conceptVec, gradingModel)`.
- Flattens the concept struct to a `1x7` numeric row automatically.
- Returns `grade`, `rawScores`, and `referableFlag` (based on saved threshold).

---

## Phase 5 — Explainability

### [`explainGrade.m`](file:///d:/Downloads/Netra_Ai_DR/src/explainability/explainGrade.m)
- Calls `gradCAM()` targeting `activation_49_relu` (ResNet-50's last conv layer).
- Colorizes via jet colormap and blends 50/50 with the original image.

### [`calibrateConfidence.m`](file:///d:/Downloads/Netra_Ai_DR/src/explainability/calibrateConfidence.m)
- Fits a scalar temperature `T` via `fminsearch` minimizing NLL on the calibration set.
- Applies `softmax(logits / T)` and saves `temperature.mat`.

### [`generateEvidenceSentence.m`](file:///d:/Downloads/Netra_Ai_DR/src/explainability/generateEvidenceSentence.m)
- Template-based NLG covering all concept fields: MA, HM (with type), EX, CWS, NVD/NVE.
- Closes with a referral recommendation sentence based on grade threshold.

### [`generateReport.m`](file:///d:/Downloads/Netra_Ai_DR/src/explainability/generateReport.m)
- Produces a **standalone HTML file** (no external dependencies) with:
  - Original image, color-coded lesion overlay (MA=red, HM=blue, EX=yellow, CWS=cyan, OD=green), Grad-CAM overlay, grade probability bar chart.
  - Evidence sentence, concept findings table, and a clinical disclaimer.

## How to Test
```matlab
addpath(genpath('src'));
img = imread('data/processed/images/<any_image>.png');
cv = buildConceptVector(img);
% After training the model:
[grade, scores, referable] = predictGrade(img, cv);
sentence = generateEvidenceSentence(grade, cv, max(scores));
reportPath = generateReport(img, cv, grade, scores, max(scores), 'PATIENT_001');
web(reportPath); % open in browser
```

---

## Up Next: Iteration 4 — Digital Twin & Clinical Support (Phases 7 & 8)
Files: `twinStore.m`, `updateTwin.m`, `registerAndCompare.m`, `makeSyntheticVisit.m`, `treatmentPathway.m`, `medicationLookup.m`, `nutritionGuidance.m`, `followUpMonitor.m`
