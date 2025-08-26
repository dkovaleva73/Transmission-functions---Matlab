#!/usr/bin/env python3
"""
Analyze the comparison between MATLAB and Python atmospheric transmission
"""
import numpy as np

# Read Python results
python_data = []
with open('/home/dana/matlab_projects/python_results.txt', 'r') as f:
    for line in f:
        if line.strip() and not line.startswith('#') and ',' in line:
            try:
                parts = line.strip().split(',')
                if len(parts) == 7:
                    wvl = float(parts[0])
                    trans_total = float(parts[1])
                    if 300 <= wvl <= 1100:
                        python_data.append([wvl, trans_total])
            except:
                pass

# Read MATLAB results
matlab_data = []
with open('/home/dana/matlab_projects/matlab_results.txt', 'r') as f:
    for line in f:
        if line.strip() and not line.startswith('#') and ',' in line:
            try:
                parts = line.strip().split(',')
                if len(parts) == 7:
                    wvl = float(parts[0])
                    trans_total = float(parts[1])
                    if 300 <= wvl <= 1100:
                        matlab_data.append([wvl, trans_total])
            except:
                pass

# Convert to arrays
python_data = np.array(python_data)
matlab_data = np.array(matlab_data)

# Ensure same length
min_len = min(len(python_data), len(matlab_data))
python_data = python_data[:min_len]
matlab_data = matlab_data[:min_len]

print("=== MATLAB vs PYTHON COMPARISON ===\n")
print(f"Number of wavelength points: {len(python_data)}")
print(f"Wavelength range: {python_data[0,0]:.0f} - {python_data[-1,0]:.0f} nm")

# Calculate differences
differences = matlab_data[:, 1] - python_data[:, 1]
abs_diff = np.abs(differences)
rel_diff = np.abs(differences / python_data[:, 1]) * 100  # percentage

print(f"\nTransmission differences:")
print(f"  Mean absolute difference: {np.mean(abs_diff):.6f}")
print(f"  Max absolute difference: {np.max(abs_diff):.6f}")
print(f"  Mean relative difference: {np.mean(rel_diff):.4f}%")
print(f"  Max relative difference: {np.max(rel_diff):.4f}%")

# Find wavelengths with largest differences
max_diff_idx = np.argmax(abs_diff)
print(f"\nLargest absolute difference at {python_data[max_diff_idx, 0]:.0f} nm:")
print(f"  Python: {python_data[max_diff_idx, 1]:.6f}")
print(f"  MATLAB: {matlab_data[max_diff_idx, 1]:.6f}")
print(f"  Difference: {differences[max_diff_idx]:.6f}")

# Check if differences are significant
threshold = 1e-6
significant_diffs = abs_diff > threshold
print(f"\nWavelengths with differences > {threshold}:")
if np.any(significant_diffs):
    sig_wvls = python_data[significant_diffs, 0]
    sig_py = python_data[significant_diffs, 1]
    sig_ml = matlab_data[significant_diffs, 1]
    sig_diff = differences[significant_diffs]
    
    print("Wavelength(nm) | Python    | MATLAB    | Difference")
    print("---------------|-----------|-----------|------------")
    for i in range(min(10, len(sig_wvls))):  # Show first 10
        print(f"    {sig_wvls[i]:6.1f}    | {sig_py[i]:.6f} | {sig_ml[i]:.6f} | {sig_diff[i]:+.6f}")
else:
    print("  None - Results are identical within numerical precision!")

# Statistical summary
print("\n=== STATISTICAL SUMMARY ===")
print(f"Python - Mean transmission: {np.mean(python_data[:, 1]):.4f}")
print(f"MATLAB - Mean transmission: {np.mean(matlab_data[:, 1]):.4f}")
print(f"Difference: {np.mean(matlab_data[:, 1]) - np.mean(python_data[:, 1]):.6f}")

# Check band averages
bands = [
    ("UV", 300, 400),
    ("Visible", 400, 700),
    ("NIR", 700, 1100)
]

print("\nBand-averaged transmissions:")
print("Band     | Python  | MATLAB  | Diff")
print("---------|---------|---------|--------")
for band_name, wvl_min, wvl_max in bands:
    mask_py = (python_data[:, 0] >= wvl_min) & (python_data[:, 0] <= wvl_max)
    mask_ml = (matlab_data[:, 0] >= wvl_min) & (matlab_data[:, 0] <= wvl_max)
    
    mean_py = np.mean(python_data[mask_py, 1])
    mean_ml = np.mean(matlab_data[mask_ml, 1])
    diff = mean_ml - mean_py
    
    print(f"{band_name:8s} | {mean_py:.4f} | {mean_ml:.4f} | {diff:+.6f}")

print("\n=== CONCLUSION ===")
if np.max(abs_diff) < 1e-5:
    print("✓ EXCELLENT AGREEMENT: MATLAB and Python implementations produce identical results!")
elif np.max(abs_diff) < 1e-3:
    print("✓ GOOD AGREEMENT: Minor numerical differences, likely due to floating-point precision.")
else:
    print("⚠ SIGNIFICANT DIFFERENCES: Further investigation needed.")