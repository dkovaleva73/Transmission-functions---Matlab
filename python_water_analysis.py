#!/usr/bin/env python3
"""
Python Water Vapor Transmittance Analysis
Companion script for MATLAB water_transmission_comparison_tool.m

This script calculates water vapor transmittances using the original Python 
WaterTransmittance class and saves results for comparison with MATLAB implementation.

Usage:
    python python_water_analysis.py

Requirements:
    - transmission_fitter package installed
    - scipy (for saving .mat files)
"""

import numpy as np
import sys
import os

# Add the transmission_fitter package to path
sys.path.insert(0, '/home/dana/anaconda3/envs/myenv/lib/python3.12/site-packages')

from transmission_fitter.atmospheric_models import WaterTransmittance
from transmission_fitter.abscalutils import make_wvl_array

def analyze_water_transmission(z_, pw_, p_, verbose=True):
    """Analyze water vapor transmittance for given conditions"""
    
    if verbose:
        print(f"\nAnalyzing water transmission: Pw={pw_:.1f} cm, P={p_:.1f} hPa, Z={z_:.1f}°")
    
    # Create water transmittance model
    # Note: WaterTransmittance expects temperature, but we'll use a reasonable value
    tair = 15.0  # °C (to match MATLAB analysis)
    water_model = WaterTransmittance(z_, pw_, p_)
    
    # Calculate transmittance
    trans = water_model.make_transmission()
    
    if verbose:
        # Analyze results
        min_trans = np.min(trans)
        max_trans = np.max(trans)
        mean_trans = np.mean(trans)
        
        min_idx = np.argmin(trans)
        wavelengths = water_model.wvl_arr
        
        # Find absorption characteristics
        very_strong_abs = np.sum(trans < 0.1)   # Nearly opaque
        strong_abs = np.sum(trans < 0.5)        # Strong absorption
        moderate_abs = np.sum(trans < 0.8)      # Moderate absorption
        
        print(f"  Range: [{min_trans:.6f}, {max_trans:.6f}]")
        print(f"  Mean: {mean_trans:.6f}")
        print(f"  Min at λ={wavelengths[min_idx]:.0f}nm: {min_trans:.6f}")
        print(f"  Absorption points - Opaque: {very_strong_abs}, Strong: {strong_abs}, Moderate: {moderate_abs}")
    
    return trans, water_model.wvl_arr

def find_water_absorption_bands(wavelengths, transmission, pw_value, threshold=0.5):
    """Find major water vapor absorption bands"""
    
    print(f"\nMajor water vapor absorption bands (Pw={pw_value:.1f} cm, T<{threshold:.1f}):")
    
    strong_abs_mask = transmission < threshold
    
    if np.sum(strong_abs_mask) == 0:
        print(f"  No strong absorption bands found (all T > {threshold:.1f})")
        return
    
    abs_wavelengths = wavelengths[strong_abs_mask]
    abs_transmissions = transmission[strong_abs_mask]
    
    # Group consecutive absorption regions
    diff_wvl = np.diff(abs_wavelengths)
    band_breaks = np.where(diff_wvl > 20)[0]  # More than 20nm gap
    
    band_start = 0
    band_count = 0
    
    for i in range(len(band_breaks) + 1):
        if i < len(band_breaks):
            band_end = band_breaks[i] + 1
        else:
            band_end = len(abs_wavelengths)
        
        if band_end > band_start:
            band_count += 1
            wvl_range = abs_wavelengths[band_start:band_end]
            trans_range = abs_transmissions[band_start:band_end]
            
            min_idx = np.argmin(trans_range)
            min_trans = trans_range[min_idx]
            
            print(f"  Band {band_count}: {np.min(wvl_range):.0f}-{np.max(wvl_range):.0f} nm, "
                  f"deepest T={min_trans:.3f} at {wvl_range[min_idx]:.0f} nm")
        
        band_start = band_end

def main():
    """Main analysis function"""
    
    print("PYTHON WATER VAPOR TRANSMITTANCE ANALYSIS")
    print("="*50)
    print("Original Python WaterTransmittance implementation")
    
    # Test parameters
    z_test = 30.0       # zenith angle
    tair_test = 15.0    # temperature (for reference)
    p_test = 1013.25    # pressure
    
    # Test different precipitable water values
    pw_values = [0.5, 1.0, 2.0, 4.0, 6.0]  # cm
    
    print(f"\nTest conditions:")
    print(f"  Zenith angle: {z_test:.1f}°")
    print(f"  Temperature: {tair_test:.1f}°C (reference)")
    print(f"  Pressure: {p_test:.1f} hPa")
    print(f"  Water vapor amounts: {pw_values} cm")
    
    # Test each water vapor amount
    results = {}
    wavelengths = None
    
    for pw in pw_values:
        trans, wvl = analyze_water_transmission(z_test, pw, p_test, verbose=True)
        results[pw] = trans
        if wavelengths is None:
            wavelengths = wvl
    
    # Analyze spectral features for a reference case
    pw_ref = 2.0  # cm
    if pw_ref in results:
        find_water_absorption_bands(wavelengths, results[pw_ref], pw_ref, threshold=0.5)
    
    # Show water vapor sensitivity analysis
    print(f"\n" + "="*50)
    print("WATER VAPOR SENSITIVITY ANALYSIS")
    print("="*50)
    
    print(f"\n{'Pw (cm)':<8} | {'Range':<15} | {'Mean':<10} | {'Opaque':<8} | {'Strong':<8} | {'Moderate':<10}")
    print("-" * 70)
    
    for pw in pw_values:
        trans = results[pw]
        min_val, max_val = np.min(trans), np.max(trans)
        mean_val = np.mean(trans)
        
        very_strong_abs = np.sum(trans < 0.1)   # Nearly opaque
        strong_abs = np.sum(trans < 0.5)        # Strong absorption  
        moderate_abs = np.sum(trans < 0.8)      # Moderate absorption
        
        print(f"{pw:<8.1f} | [{min_val:.3f},{max_val:.3f}] | {mean_val:<10.6f} | "
              f"{very_strong_abs:<8} | {strong_abs:<8} | {moderate_abs:<10}")
    
    # Save results for MATLAB comparison
    print(f"\nSaving results for MATLAB comparison...")
    
    try:
        from scipy.io import savemat
        
        save_data = {
            'wavelengths': wavelengths,
            'test_conditions': {
                'zenith_angle': z_test,
                'temperature': tair_test,
                'pressure': p_test,
                'pw_values': np.array(pw_values)
            }
        }
        
        # Add transmission data for each water vapor amount
        for pw in pw_values:
            # Create valid MATLAB field name
            field_name = f'pw_{pw:.1f}_transmission'.replace('.', '_')
            save_data[field_name] = results[pw]
        
        savemat('python_water_results.mat', save_data)
        print("✅ Results saved to python_water_results.mat")
        
    except ImportError:
        print("⚠️  scipy not available, saving as text files")
        
        # Save as text files
        np.savetxt('python_water_wavelengths.txt', wavelengths)
        for pw in pw_values:
            filename = f'python_water_pw{pw:.1f}_transmission.txt'
            np.savetxt(filename, results[pw])
        print("✅ Results saved as individual text files")
    
    # Physical interpretation
    print(f"\n" + "="*50)
    print("PHYSICAL INTERPRETATION")
    print("="*50)
    
    print(f"\nWater vapor absorption characteristics:")
    print(f"• Strong absorption bands in NIR (700-1100 nm)")
    print(f"• Absorption strength increases with precipitable water amount")
    print(f"• Major bands around 720nm, 820nm, 940nm, 1100nm regions")
    print(f"• Atmospheric window regions show minimal absorption")
    print(f"• Correction factors (Bw, Bm, BMW, BP) account for:")
    print(f"  - Water vapor amount deviations (Bw)")
    print(f"  - Airmass effects (Bm)") 
    print(f"  - Combined water-airmass effects (BMW)")
    print(f"  - Pressure effects (BP)")
    
    print(f"\n✅ Python water vapor analysis complete!")
    print(f"Run MATLAB water_transmission_comparison_tool.m for full comparison")

if __name__ == '__main__':
    main()