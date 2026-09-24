# Iteration 2c Complete: Lesions + Neovascularization + Concept Vector

The final segmentation block is done. All Phase 3 modules are now written. The pipeline can now produce a complete, structured concept vector from a single retinal image.

## Changes Made

### 1. Lesion Classifier Training ([`trainLesionClassifiers.m`](file:///d:/Downloads/Netra_Ai_DR/src/segmentation/trainLesionClassifiers.m))
- Extracts 32×32 positive patches (from IDRiD lesion masks) and negative patches (random foreground) for each lesion type: **MA, HE, EX, SE**.
- Defines a compact 3-layer patch CNN per type (`conv → pool → conv → pool → FC`).
- The `trainNetwork` lines are commented out so it is safe to run without a GPU — uncomment when GPU is ready.

### 2. Lesion Segmentation ([`segmentLesions.m`](file:///d:/Downloads/Netra_Ai_DR/src/segmentation/segmentLesions.m))
- **MA**: Inverted green + top-hat (disk-6 SE) + area/eccentricity filter (`area ≤ 120, ecc < 0.8`).
- **HM**: Larger top-hat (disk-15 SE) + shape classifier:
  - `dot` → `area < 200, ecc < 0.6`
  - `blot` → `area ≥ 200, ecc < 0.75`
  - `flame` → high eccentricity / elongated
  - This directly populates `hmType` in the concept vector — the gap flagged in your review.
- **EX**: Bright region top-hat on avg(red, green) + adaptive threshold.
- **CWS**: Separates soft from hard exudates using local standard deviation (`stdfilt`) — soft/diffuse patches = CWS, crisp/high-variance patches = hard EX.

### 3. Two-Pass Neovascularization ([`detectNeovascularization.m`](file:///d:/Downloads/Netra_Ai_DR/src/segmentation/detectNeovascularization.m))
- **NVD pass**: Computes vessel density in a peri-discal ring (1.0–1.5× OD radius). Flags if density > 0.35.
- **NVE pass**: Divides the peripheral retina into a 16×16 density grid (excluding macula and OD zones). Flags if any cell is >2σ above the mean density — indicating focal, abnormal clusters. Returns a full `nveMap` for visualization.

### 4. Concept Vector Integration ([`buildConceptVector.m`](file:///d:/Downloads/Netra_Ai_DR/src/segmentation/buildConceptVector.m))
Chains all modules in order (`segmentVessels → segmentOpticDiscFovea → segmentLesions → detectNeovascularization`) and returns the complete struct: `{maCount, hmCount, hmType, exArea, cwsCount, nvdFlag, nveFlag, nvFlag, vesselAbnormalityScore}` — plus the raw masks for report overlays.

## How to Verify
Run this block in MATLAB to test the full concept vector on one image:
```matlab
addpath(genpath('src'));
img = imread('data/processed/images/APTOS2019_<any_name>.png');
cv = buildConceptVector(img);
disp(cv);
```
You should see a printed log: `Concept Vector Built — MA: X | HM: X | EX area: X | ...`

---

## ✅ All of Phase 2 & Phase 3 Complete

The complete segmentation pipeline spans **Iterations 2a → 2b → 2c**. Ready to move to:

**Iteration 3: Grading Model (Phase 4) + Explainability (Phase 5)**
- `buildConceptBottleneckNet.m` — ResNet-50 backbone fused with concept vector
- `trainGradingModel.m` — Full training script with validation and checkpointing
- `calibrateThreshold.m` — ROC-based threshold to hit ≥90% referable-DR sensitivity
- `predictGrade.m` — Inference entry point
- `explainGrade.m`, `generateReport.m`, `calibrateConfidence.m`, `generateEvidenceSentence.m`
