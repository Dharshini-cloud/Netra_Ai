# Netra AI DR — Technical Architecture & Implementation Documentation

This document provides a comprehensive technical breakdown of all 12 phases comprising the Netra AI Diabetic Retinopathy Diagnostic and Telemedicine platform.

---

## Table of Contents
1. [Phase 0: Environment & Configuration](#phase-0-environment--configuration)
2. [Phase 1: Dataset Unification & Patient-Aware Splitting](#phase-1-dataset-unification--patient-aware-splitting)
3. [Phase 2: Adaptive Image Quality Gate](#phase-2-adaptive-image-quality-gate)
4. [Phase 3: Anatomical & Biomarker Segmentation](#phase-3-anatomical--biomarker-segmentation)
5. [Phase 4: Concept Bottleneck Grading Model](#phase-4-concept-bottleneck-grading-model)
6. [Phase 5: Multimodal Explainability & Clinical Reporting](#phase-5-multimodal-explainability--clinical-reporting)
7. [Phase 6: Simulink Telemedicine Queuing & Workflow](#phase-6-simulink-telemedicine-queuing--workflow)
8. [Phase 7: Retinal Digital Twin & Longitudinal Tracking](#phase-7-retinal-digital-twin--longitudinal-tracking)
9. [Phase 8: Clinical Decision Support & Care Pathways](#phase-8-clinical-decision-support--care-pathways)
10. [Phase 9: Federated Learning Framework](#phase-9-federated-learning-framework)
11. [Phase 10: Validation, Benchmarking & Ablation](#phase-10-validation-benchmarking--ablation)
12. [Phase 11: Integrated Desktop Application](#phase-11-integrated-desktop-application)
13. [Phase 12: Demonstration & Deployment Guide](#phase-12-demonstration--deployment-guide)

---

## Phase 0: Environment & Configuration
* **Core File**: `config.m`
* **Purpose**: Establishes centralized directory paths, standardized image resolution ($512 \times 512 \times 3$), ICDR class definitions, and dataset metadata.
* **Key Specifications**:
  * Classes: `{'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'}`
  * Class Labels: `[0, 1, 2, 3, 4]`
  * Referable Threshold: Grade $\ge 2$ (Moderate NPDR or higher)
  * Dynamic absolute path resolution using `fileparts(mfilename('fullpath'))` to ensure portability across systems.

---

## Phase 1: Dataset Unification & Patient-Aware Splitting
* **Core Files**: `src/data/loadDataset.m`, `src/data/preprocessImages.m`, `src/data/buildPatientSplits.m`
* **Datasets Supported**:
  1. **APTOS 2019**: 3,662 fundus images (India rural screening context).
  2. **IDRiD**: 516 images with precise lesion segmentation ground truth.
  3. **Messidor-2**: 1,748 images held out entirely for true external out-of-distribution validation.
  4. **DRIVE**: 40 images with dual-observer vessel annotations.
* **Patient-Aware Stratification**:
  * Prevents data leakage between left and right eyes of the same patient by grouping patient IDs before splitting.
  * Stratified 70/15/15 train/val/test split preserving DR grade distribution.
  * Independent external test index saved as `data/splits/external_test_index.mat`.

---

## Phase 2: Adaptive Image Quality Gate
* **Core Files**: `src/quality/extractQualityFeatures.m`, `src/quality/trainQualityClassifier.m`, `src/quality/assessQuality.m`, `src/quality/enhanceImage.m`
* **Quality Feature Extraction**:
  * **Sharpness**: Variance of the Discrete Laplacian operator:
    $$\text{Sharpness} = \text{Var}\left(\nabla^2 I_{\text{green}}\right)$$
  * **Diagnostic Contrast**: Mean and standard deviation of the green spectral channel, where haemoglobin absorbance peaks.
  * **Specular Glare**: Proportion of pixels with value $V > 0.95$ and saturation $S < 0.10$ in HSV space.
  * **Field of View (FOV)**: Non-zero area ratio within the circular retinal mask.
* **Triage Logic**:
  * `ACCEPTED`: Passed directly to biomarker segmentation and grading.
  * `BORDERLINE_ENHANCED`: Automatically enhanced using Contrast-Limited Adaptive Histogram Equalization (CLAHE, `ClipLimit=0.02`) followed by bilateral filtering (`DegreeOfSmoothing=0.05`) to suppress sensor noise while preserving vessel margins.
  * `REJECTED_RECAPTURE`: Image unusable; triggers instant on-site recapture protocol.

---

## Phase 3: Anatomical & Biomarker Segmentation
* **Core Files**: `src/segmentation/segmentVessels.m`, `src/segmentation/segmentOpticDiscFovea.m`, `src/segmentation/segmentLesions.m`, `src/segmentation/detectNeovascularization.m`, `src/segmentation/buildConceptVector.m`
* **Target Biomarkers**:
  * **Retinal Vessels**: Multi-scale vessel enhancement using Frangi line/fibermetric filtering and optional U-Net (`trainVesselUNet.m`).
  * **Optic Disc (OD) & Fovea**: Circular Hough Transform and intensity thresholding for OD; geometric offset localization for the foveal avascular zone.
  * **Microaneurysms (MA)**: Morphological bottom-hat filtering ($3-7$ px radius) with circularity filter.
  * **Haemorrhages (HM)**: Morphological top-hat/bottom-hat with aspect-ratio lesion classification:
    * *Dot Haemorrhages*: Area $< 50$ px, circularity $> 0.75$.
    * *Blot Haemorrhages*: Area $\ge 50$ px, circularity $> 0.60$.
    * *Flame-Shaped Haemorrhages*: Elongated, eccentricity $> 0.85$.
  * **Hard Exudates (EX)**: Bright lesion detection in L\*a\*b\* color space ($L^* > 65, b^* > 15$).
  * **Cotton Wool Spots (CWS)**: Low-contrast, ill-defined fluffy white lesions.
  * **Neovascularization (NV)**: Frangi vessel density anomalies in peripapillary region (NVD) and peripheral arcades (NVE).
* **Output**: `conceptVector` struct containing counts, areas, types, and dense spatial lesion masks.

---

## Phase 4: Concept Bottleneck Grading Model
* **Core Files**: `src/grading/buildConceptBottleneckNet.m`, `src/grading/trainGradingModel.m`, `src/grading/calibrateThreshold.m`, `src/grading/predictGrade.m`
* **Architecture**:
  * **Visual Embedding Branch**: Pretrained ResNet-50 backbone stripped of classification layer; extracts a 2,048-dimensional dense visual feature vector via Global Average Pooling (GAP).
  * **Concept Feature Branch**: 7-dimensional numeric concept vector ($[MA, HM, EX, CWS, NV, NVD, NVE]$) processed through FC(32) $\rightarrow$ ReLU $\rightarrow$ FC(16).
  * **Fusion Head**: Concatenation of image embedding and concept embedding $\rightarrow$ FC(256) $\rightarrow$ BatchNorm $\rightarrow$ Dropout(0.4) $\rightarrow$ FC(5) $\rightarrow$ Softmax.
* **Calibration**:
  * Operating point calibrated on the validation set ROC curve to achieve **$\ge 90\%$ Sensitivity** for referable DR (Grade $\ge 2$) while maximizing specificity.

---

## Phase 5: Multimodal Explainability & Clinical Reporting
* **Core Files**: `src/explainability/explainGrade.m`, `src/explainability/calibrateConfidence.m`, `src/explainability/generateEvidenceSentence.m`, `src/explainability/generateReport.m`
* **Explainability Pillars**:
  1. **Spatial Attention**: Grad-CAM saliency heatmaps computed on the last convolutional layer (`activation_49_relu`), blended 50/50 with fundus images.
  2. **Biomarker Grounding**: Color-coded lesion overlay (Red: MA, Blue: HM, Yellow: Hard Exudates, Cyan: CWS).
  3. **Temperature Calibration**: Post-hoc temperature scaling ($T^*$) minimizing Negative Log-Likelihood (NLL) on validation calibration sets.
  4. **Natural Language Generation (NLG)**: Automated clinically fluent evidence sentences linking quantitative lesion findings to the assigned ICDR grade.
  5. **Exportable HTML Report**: Standalone CSS-styled report with embedded base64 images, findings tables, and clinical recommendations.

---

## Phase 6: Simulink Telemedicine Queuing & Workflow
* **Core Files**: `simulink/simulateTelemedicine.m`, `simulink/buildTelemedicineModel.m`, `simulink/runSimulationSweep.m`
* **Queuing Subsystems**:
  * Patient Arrival Generator (Poisson process $\lambda$).
  * Camera & Quality Station with instant recapture delay loop.
  * Edge Inference vs. Cloud Upload Switch.
  * Bandwidth-Limited Uplink Channel ($64$ kbps to $20$ Mbps) with priority queuing.
  * Central Specialist Review Queue ($M/M/c$ multiserver queue).
* **Clinical Triage Advantage**:
  * Transmitting only referable cases and compact concept reports ($<150$ KB) saves **$>90\%$ network bandwidth** compared to raw image upload ($12$ MB/patient).
  * Reduces ophthalmologist reading load by **$\sim 75-80\%$**.

---

## Phase 7: Retinal Digital Twin & Longitudinal Tracking
* **Core Files**: `src/digitaltwin/twinStore.m`, `src/digitaltwin/updateTwin.m`, `src/digitaltwin/registerAndCompare.m`, `src/digitaltwin/makeSyntheticVisit.m`
* **Key Functionality**:
  * Persistent file-based store in `data/twinstore/<patientID>.mat`.
  * Intensity-based rigid image registration (`imregtform`, monomodal) aligning prior visits to the current coordinate frame.
  * Spatial lesion subtraction:
    $$\text{New Lesions} = \text{Mask}_{\text{current}} \cap \neg \text{Warped}(\text{Mask}_{\text{prior}})$$
    $$\text{Resolved Lesions} = \text{Warped}(\text{Mask}_{\text{prior}}) \cap \neg \text{Mask}_{\text{current}}$$
  * Trajectory status: Flags `PROGRESSED`, `STABLE`, or `REGRESSED`.

---

## Phase 8: Clinical Decision Support & Care Pathways
* **Core Files**: `src/clinicalsupport/treatmentPathway.m`, `src/clinicalsupport/medicationLookup.m`, `src/clinicalsupport/nutritionGuidance.m`, `src/clinicalsupport/followUpMonitor.m`
* **Clinical Knowledge Engine**:
  * Grade-stratified care pathways: Routine (Grade 0), Annual (Grade 1), 3-Month Follow-Up (Grade 2), Urgent Referral (Grade 3), Emergency Vitrectomy (Grade 4).
  * Drug safety checker flagging contraindications (e.g., Thiazolidinediones/Pioglitazone inducing macular edema; Anticoagulants with active proliferative haemorrhage).
  * Evidence-based dietary guidelines and physical activity limitations.
  * Automated follow-up due date monitoring and recall alerts.

---

## Phase 9: Federated Learning Framework
* **Core Files**: `src/federated/localTrain.m`, `src/federated/aggregateModels.m`, `src/federated/runFederatedRounds.m`
* **FedAvg Formulation**:
  $$w_{t+1} = w_t + \sum_{k=1}^{K} \frac{n_k}{N} \Delta w_k^t$$
  Where $n_k$ is the number of local samples at centre $k$, and $\Delta w_k^t$ is the weight update delta from centre $k$.
* Simulates decentralized collaborative training across heterogeneous clinical centres without moving patient raw images.

---

## Phase 10: Validation, Benchmarking & Ablation
* **Core Files**: `validation/metrics.m`, `validation/runBenchmark.m`, `validation/runAblation.m`
* **Evaluation Metrics**: Cohen's Quadratic Weighted Kappa, Macro F1, Referable Sensitivity/Specificity, AUC-ROC.
* **Ablation Matrix**:
  1. Full Netra AI Pipeline (Quality Gate + CBM + ResNet-50).
  2. Degraded: No Quality Gate (unfiltered input).
  3. Degraded: No Concept Bottleneck (pure black-box CNN).

---

## Phase 11: Integrated Desktop Application
* **Core Files**: `app/NetraApp.m`, `runNetraApp.m`
* **UI Architecture**:
  * 5 cohesive tabs: Diagnostic Screening, Explainability & Report, Retinal Digital Twin, Clinical Decision Support, Analytics & Telemedicine Simulator.
  * Real-time status pills, interactive axes, responsive tables, and instant error fallbacks.

---

## Phase 12: Demonstration & Deployment Guide
* See [`docs/demo_script.md`](file:///d:/Downloads/Netra_Ai_DR/docs/demo_script.md) for the 5-minute live pitch and testing walkthrough.
