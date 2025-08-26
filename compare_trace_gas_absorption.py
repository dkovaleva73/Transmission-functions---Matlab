#!/usr/bin/env python3
"""
Compare trace gas absorption coefficients at 350 and 450 nm
"""
import numpy as np
import os

# Constants from Python implementation
NLOSCHMIDT = 2.6868e19

# Test wavelengths
test_wavelengths = [350, 450]

# Standard conditions
z_ = 0  # Zenith angle
tair = 15  # Temperature C
p_ = 1013.25  # mbar
pp0 = p_ / 1013.25
co2_ppm = 395

print(f"\n=== PYTHON IMPLEMENTATION VALUES ===")
print(f"NLOSCHMIDT: {NLOSCHMIDT:.4e}")
print(f"Pressure ratio pp0: {pp0:.6f}")

# Simulate reading NO2 data - you'll need to provide actual values
# from your Python data files at 350 and 450 nm
print("\n=== NO2 Absorption ===")
print("NOTE: Replace these with actual values from your NO2 data file")

# Example structure - replace with actual data
# For 350 nm
wvl = 350
sigma_350 = 5.0e-19  # REPLACE with actual value
b0_350 = 1.0e-21     # REPLACE with actual value
print(f"\nAt {wvl} nm:")
print(f"  Raw sigma: {sigma_350:.4e}")
print(f"  Raw b0: {b0_350:.4e}")
print(f"  Temperature term b0*(228.7-220): {b0_350 * (228.7 - 220):.4e}")
no2_abs = NLOSCHMIDT * (sigma_350 + b0_350 * (228.7 - 220))
print(f"  NO2 abs coeff: {no2_abs:.4e}")

# NO2 abundance
no2_abundance = 1e-4 * min(1.8599 + 0.18453 * pp0, 41.771 * pp0)
print(f"  NO2 abundance: {no2_abundance:.4e}")

# For 450 nm
wvl = 450
sigma_450 = 1.0e-19  # REPLACE with actual value
b0_450 = 5.0e-22     # REPLACE with actual value
print(f"\nAt {wvl} nm:")
print(f"  Raw sigma: {sigma_450:.4e}")
print(f"  Raw b0: {b0_450:.4e}")
print(f"  Temperature term b0*(228.7-220): {b0_450 * (228.7 - 220):.4e}")
no2_abs = NLOSCHMIDT * (sigma_450 + b0_450 * (228.7 - 220))
print(f"  NO2 abs coeff: {no2_abs:.4e}")

print("\n=== SO2 Absorption ===")
print("NOTE: Replace these with actual values from your SO2U/SO2I data files")

# SO2 abundance
so2_abundance = 1e-4 * 0.11133 * (pp0**0.812) * np.exp(0.81319 + 3.0557 * (pp0**2) - 1.578 * (pp0**3))
print(f"SO2 abundance: {so2_abundance:.4e}")

print("\n" + "="*50)
print("TO GET ACTUAL VALUES:")
print("1. Load your Python absorption data files")
print("2. Extract values at 350 and 450 nm for NO2, SO2U, SO2I, etc.")
print("3. Compare with MATLAB values above")