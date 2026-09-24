# Iteration 2a Complete: Image Quality Gate

I have completed the code for Iteration 2a, implementing the Image Quality Gate module strictly following your design constraints.

## Changes Made

### 1. Feature Extraction
- **[`extractQualityFeatures.m`](file:///d:/Downloads/Netra_Ai_DR/src/quality/extractQualityFeatures.m)**: Computes 4 metrics. As requested, it strictly uses the **Green channel** for the illumination/diagnostic contrast feature, and the **HSV V-channel** exclusively for measuring specular glare.

### 2. Classifier Training
- **[`trainQualityClassifier.m`](file:///d:/Downloads/Netra_Ai_DR/src/quality/trainQualityClassifier.m)**: Instead of generic noise, this script programmatically corrupts good retinal images with realistic acquisition failures:
  - Directional motion blur (random angles).
  - Severe underexposure (simulating failed flash or dark pupil).
  - Specular flare patches (simulating off-axis reflections).
  It then trains an SVM (`fitcsvm`) and saves it to `models/qualityModel.mat`.

### 3. Quality Assessment
- **[`assessQuality.m`](file:///d:/Downloads/Netra_Ai_DR/src/quality/assessQuality.m)**: Wraps the SVM and specific feature thresholds to return the EXACT strings expected by the rest of the pipeline: `"ACCEPTED"`, `"BORDERLINE_ENHANCED"`, or `"REJECTED_RECAPTURE"`.

### 4. Image Enhancement
- **[`enhanceImage.m`](file:///d:/Downloads/Netra_Ai_DR/src/quality/enhanceImage.m)**: Applies CLAHE specifically to the lightness (L) channel of the LAB color space, followed by an edge-preserving Bilateral Filter to rescue borderline images without blurring diagnostic lesions.

## How to Verify
1. Run `trainQualityClassifier()` in MATLAB. It will synthesize bad examples from your processed images and generate `qualityModel.mat`.
2. Load a test image: `img = imread('data/processed/images/some_image.png');`
3. Assess it: `[status, report] = assessQuality(img); disp(status); disp(report);`
4. If it returns `BORDERLINE_ENHANCED`, test the enhancer: `enhanced = enhanceImage(img); imshowpair(img, enhanced, 'montage');`

Once you confirm the Quality Gate is functioning smoothly on your end, let me know, and we'll dive into **Iteration 2b (Vessels + Optic Disc/Fovea)**!
