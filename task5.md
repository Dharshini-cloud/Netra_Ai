# Iteration 4 Complete: Digital Twin + Clinical Support

**Phases 7 and 8 are fully written.** The pipeline now has persistent patient memory and a full rule-based clinical decision layer.

---

## Phase 7 — Digital Twin

### [`twinStore.m`](file:///d:/Downloads/Netra_Ai_DR/src/digitaltwin/twinStore.m)
A CRUD store keyed by patient ID. Each patient gets their own `data/twinstore/<patientID>.mat` file containing a `patientRecord` struct with a `visits{}` cell array. Supports: `create`, `read`, `update`, `list`, `delete`.

### [`updateTwin.m`](file:///d:/Downloads/Netra_Ai_DR/src/digitaltwin/updateTwin.m)
Thin wrapper that builds a typed visit record struct (date, imagePath, grade, conceptVec, referableFlag, any extra clinical fields) and calls `twinStore('update', ...)`.

### [`registerAndCompare.m`](file:///d:/Downloads/Netra_Ai_DR/src/digitaltwin/registerAndCompare.m)
- Loads the most recent prior visit from the twin store.
- Performs **rigid image registration** (`imregtform`, monomodal) to align the prior image to the current one.
- Warps prior lesion masks into current coordinates via `imwarp`.
- Computes set-differences: `newLesions = cur & ~priorAligned`, `resolvedLesions = prior & ~cur`.
- Flags progression if any new lesions or NV state change detected.

### [`makeSyntheticVisit.m`](file:///d:/Downloads/Netra_Ai_DR/src/digitaltwin/makeSyntheticVisit.m)
Paints realistic synthetic MAs (small 3–6px dark circles) and haemorrhages (8–15px dark ellipses) onto a real image for demo testing. Uses `rng(42)` for reproducibility. Calls `buildConceptVector` on the result so the concept struct is fully accurate.

---

## Phase 8 — Clinical Support

### [`treatmentPathway.m`](file:///d:/Downloads/Netra_Ai_DR/src/clinicalsupport/treatmentPathway.m)
- Grade 0–4 → base pathway options (routine/3-month/urgent/emergency).
- Modifiers: NV flags, exudate burden, cotton-wool spot count.
- Progression escalation: if grade increased since last visit, urgency escalates one level.

### [`medicationLookup.m`](file:///d:/Downloads/Netra_Ai_DR/src/clinicalsupport/medicationLookup.m)
- Grade-indexed suggestion KB (metformin, ACEi, fenofibrate, anti-VEGF, etc.).
- Contraindication checker against patient's current drug list (thiazolidinediones, warfarin, NSAIDs).

### [`nutritionGuidance.m`](file:///d:/Downloads/Netra_Ai_DR/src/clinicalsupport/nutritionGuidance.m)
- Universal core dietary items + grade-stratified additions.
- Lifestyle recommendations with grade ≥ 3 safety warnings (no contact sports, driving restrictions).
- Red-flag items (sugary drinks, high-GI foods, grapefruit if on relevant meds).
- Logs adherence entries back to the twin store if `adherenceEntry` is provided.

### [`followUpMonitor.m`](file:///d:/Downloads/Netra_Ai_DR/src/clinicalsupport/followUpMonitor.m)
- Scans all patient records, computes due dates from grade-stratified intervals (Grade 0–1 = annual, 2 = 90d, 3 = 28d, 4 = 7d).
- Escalates urgency for patients who are >50% past their interval.
- Returns a struct array of alerts ready to display in the app.

---

## Demo Test Snippet
```matlab
addpath(genpath('src'));
img = imread('data/processed/images/<any_image>.png');

% Visit 1 — baseline
cv1 = buildConceptVector(img);
updateTwin('DEMO_001', 'data/processed/images/<any_image>.png', 1, cv1, false);

% Visit 2 — synthetic progression
[synImg, cv2] = makeSyntheticVisit(img, cv1, 4, 1);
updateTwin('DEMO_001', 'demo_synth.png', 2, cv2, true);
imwrite(synImg, 'demo_synth.png');

% Compare
prog = registerAndCompare(synImg, cv2, 'DEMO_001');
disp(prog.summary);

% Clinical support outputs
pathway = treatmentPathway(2, cv2);
alerts  = followUpMonitor();
```

---

## Up Next: Iteration 5 — Federated Learning + Validation (Phases 9 & 10)
Files: `localTrain.m`, `aggregateModels.m`, `runFederatedRounds.m`, `runBenchmark.m`, `runAblation.m`, `metrics.m`, `progressDashboard.m`
