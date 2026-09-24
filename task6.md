# Iteration 6 Complete: Simulink Telemedicine Workflow

**Phase 6 is fully written.** The pipeline now includes a high-fidelity discrete-event queuing simulation and programmatic Simulink model modeling rural diabetic retinopathy telemedicine operations.

---

## Phase 6 — Simulink Telemedicine Workflow

### [`simulateTelemedicine.m`](file:///d:/Downloads/Netra_Ai_DR/simulink/simulateTelemedicine.m)
A discrete-event simulation engine modeling the operational lifecycle of a rural screening camp:
- **Intake & Quality Subsystem**: Models Poisson patient arrivals, fundus camera queue, image quality checks, automatic edge enhancement for borderline images, and immediate on-site recapture for rejected images.
- **Edge AI vs. Cloud Triage Subsystem**:
  - *Netra AI Edge Mode*: ResNet-50 + Concept Bottleneck inference runs locally on the edge device ($~1.5$ s). Only referable cases ($G \ge 2$) transmit compressed fundus ROIs ($~1.8$ MB) and concept reports ($~150$ KB). Non-referable cases ($G \le 1$) are handled instantly on-site with clinical lifestyle/nutrition advice and queued for background sync.
  - *Cloud AI Mode*: All raw fundus images ($12$ MB) are uploaded over the link for cloud inference.
  - *Manual Tele-Retina*: All images are uploaded and 100% of cases are queued for human specialist review.
- **Network Transmission Channel**: Models bandwidth constraints ($64$ kbps to $10$ Mbps), network jitter, and priority queues for urgent/severe cases.
- **Central Ophthalmologist Station**: Multi-server $M/M/c$ review queue calculating specialist workload, queue wait times, and doctor utilization.
- **Clinical KPIs**: Computes end-to-end Turnaround Time (TAT: mean, median, 95th-pct), urgent case disposition delay, total MB transmitted, and percentage of patients completed in $<30$ and $<60$ minutes.

### [`buildTelemedicineModel.m`](file:///d:/Downloads/Netra_Ai_DR/simulink/buildTelemedicineModel.m)
- Programmatically constructs the visual Simulink block diagram (`NetraTelemedicinePipeline.slx`) using MATLAB Simulink APIs.
- Assembles:
  - `PatientArrivalGenerator`
  - `QualityGateSubsystem` (with on-site recapture loop)
  - `EdgeAIEngine` (Concept Bottleneck inference)
  - `TriageDecisionSwitch` (Referable vs. Non-referable path)
  - `BandwidthChannelQueue` (FIFO transmission buffer + rate limiter)
  - `OphthalmologistReviewStation` (Specialist review delay)
  - `TelemetryScopes` (ToWorkspace telemetry, TAT scope, and queue depth scopes)
- Safe fallback: checks `license('test', 'Simulink')` and logs helpful status.

### [`runSimulationSweep.m`](file:///d:/Downloads/Netra_Ai_DR/simulink/runSimulationSweep.m)
- Multi-parameter simulation sweep script:
  - **Bandwidth Sweep**: $64, 128, 256, 512, 1024, 2048, 5000, 10000$ kbps.
  - **Camp Volume Sweep**: $25, 50, 100, 150, 200$ patients/day.
  - **Doctor Staffing Sweep**: $1, 2, 3$ tele-ophthalmologists.
- Generates a publication-quality 4-panel figure (`telemedicine_simulation_results.png`):
  1. *End-to-End TAT vs. Bandwidth (log scale)*
  2. *Total Network Data Transmitted (MB)*
  3. *Severe / PDR Urgent Escalation Delay*
  4. *Scalability: Turnaround Time vs Daily Patient Volume*
- Saves numerical results to `simulink/simulation_results.mat` and outputs a comparative clinical summary table.

---

## How to Test
```matlab
addpath(genpath('simulink'));

% 1. Run single edge simulation with custom parameters:
cfg = struct();
cfg.numPatients = 50;
cfg.bandwidthKbps = 256; % 256 kbps rural 2G/3G
res = simulateTelemedicine(cfg);
disp(res.summaryText);

% 2. Run full multi-parameter sweep across all architectures:
sweepResults = runSimulationSweep();

% 3. (Optional) Build Simulink block diagram:
buildTelemedicineModel();
```

---

## Overall Project Status
| Phase | Status |
|---|---|
| 0 — Setup | ✅ |
| 1 — Data | ✅ |
| 2 — Quality | ✅ |
| 3 — Segmentation | ✅ |
| 4 — Grading | ✅ |
| 5 — Explainability | ✅ |
| 6 — Simulink Telemedicine | ✅ |
| 7 — Digital Twin | ✅ |
| 8 — Clinical Support | ✅ |
| 9 — Federated Learning | ✅ |
| 10 — Validation & Benchmarking | ✅ |
| **11 — App Integration** | ⏳ Iteration 7 |
| **12 — Presentation & Docs** | ⏳ Iteration 7 |

---

## Up Next: Iteration 7 — App Integration (Phase 11) + Presentation & Docs (Phase 12)
Final iteration connecting the end-to-end pipeline into a unified MATLAB App Designer interface, writing comprehensive documentation, demo script, and final delivery presentation assets!
