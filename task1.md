# Iteration 1 Complete: Setup and Data Preparation

I have completed the code for Iteration 1. You can now run this locally in your MATLAB environment assuming your datasets are placed in the `data/raw/` directories.

## Changes Made

### 1. Project Configuration
- **[`config.m`](file:///d:/Downloads/Netra_Ai_DR/config.m)**: Exposes the `512x512` image size preference, the class labels, and generates absolute paths to all the necessary datasets based on the project's root folder (`pwd`).

### 2. Dataset Loading & Unification
- **[`loadDataset.m`](file:///d:/Downloads/Netra_Ai_DR/src/data/loadDataset.m)**: We implemented parsers that handle the four different datasets, unifying them into a standard MATLAB `table`. It also extracts the `originalSplit` tag from IDRiD and correctly sets `sourceDataset`.

### 3. Image Preprocessing
- **[`preprocessImages.m`](file:///d:/Downloads/Netra_Ai_DR/src/data/preprocessImages.m)**: Iterates over the unified table. It scales all images to `512x512` and writes them into `data/processed/images/`, prefixing the filename with the dataset source to prevent namespace collisions.

### 4. Split Generation
- **[`buildPatientSplits.m`](file:///d:/Downloads/Netra_Ai_DR/src/data/buildPatientSplits.m)**: Implemented exactly as requested:
  - Held out Messidor-2 entirely as `external_test_index.mat`.
  - Enforced IDRiD's native splits.
  - Used patient IDs to safely group right/left eyes together before creating the 70/15/15 stratified train/val/test splits for APTOS and DRIVE.

## How to Verify
1. Open MATLAB and navigate to `d:\Downloads\Netra_Ai_DR`.
2. Add the `src` folder to your path (e.g., `addpath(genpath('src'))`).
3. Run `preprocessImages()` — you should see progress logs in your command window as it resizes and saves images.
4. Run `buildPatientSplits()` — it should report the exact number of images sorted into each split.

Let me know if you run into any file-path or CSV-header quirks specific to your raw data downloads, and we can adjust the parsing logic. If it works perfectly, we can move on to **Iteration 2: Image Quality and Segmentation!**
