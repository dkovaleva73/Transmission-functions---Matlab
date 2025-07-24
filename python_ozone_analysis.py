#!/usr/bin/env python3
"""
Python Ozone Transmittance Analysis
Companion script for MATLAB ozone_transmission_comparison_tool.m

This script calculates ozone transmittances using the original Python 
Ozone_Transmission class and saves results for comparison with MATLAB implementation.

Usage:
    python python_ozone_analysis.py

Requirements:
    - transmission_fitter package installed
    - scipy (for saving .mat files)
"""

import numpy as np
import sys
import os

# Add the transmission_fitter package to path
sys.path.insert(0, '/home/dana/anaconda3/envs/myenv/lib/python3.12/site-packages')

from transmission_fitter.atmospheric_models import Ozone_Transmission
from transmission_fitter.abscalutils import make_wvl_array

def analyze_ozone_transmission(z_, uo_, verbose=True):
    """Analyze ozone transmittance for given conditions"""
    
    if verbose:
        print(f"\nAnalyzing ozone transmission: Uo={uo_:.0f} DU, Z={z_:.1f}°")
    
    # Create ozone transmittance model
    ozone_model = Ozone_Transmission(z_, uo_)
    
    # Calculate transmittance
    trans = ozone_model.make_transmission()
    
    if verbose:
        # Analyze results
        min_trans = np.min(trans)
        max_trans = np.max(trans)
        mean_trans = np.mean(trans)
        
        min_idx = np.argmin(trans)
        wavelengths = ozone_model.wvl_arr
        
        # Find absorption characteristics
        very_strong_abs = np.sum(trans < 0.01)   # Nearly opaque
        strong_abs = np.sum(trans < 0.1)         # Strong absorption
        moderate_abs = np.sum(trans < 0.5)       # Moderate absorption
        weak_abs = np.sum(trans < 0.9)           # Weak absorption
        
        print(f"  Range: [{min_trans:.6f}, {max_trans:.6f}]")
        print(f"  Mean: {mean_trans:.6f}")
        print(f"  Min at λ={wavelengths[min_idx]:.0f}nm: {min_trans:.6f}")
        print(f"  Absorption points - Opaque: {very_strong_abs}, Strong: {strong_abs}, "
              f"Moderate: {moderate_abs}, Weak: {weak_abs}")
    
    return trans, ozone_model.wvl_arr

def analyze_uv_absorption(wavelengths, transmission, uo_value):
    """Analyze UV ozone absorption characteristics"""
    
    print(f"\nUV ozone absorption analysis (Uo={uo_value:.0f} DU):")
    
    # Focus on UV region where ozone absorbs (Hartley band)
    uv_mask = wavelengths <= 350  # UV region
    
    if np.sum(uv_mask) == 0:
        print("  No UV wavelengths in range")
        return
    
    uv_wavelengths = wavelengths[uv_mask]
    uv_transmission = transmission[uv_mask]
    
    # Find characteristics of UV absorption
    min_idx = np.argmin(uv_transmission)
    min_trans = uv_transmission[min_idx]
    min_wvl = uv_wavelengths[min_idx]
    mean_uv_trans = np.mean(uv_transmission)
    
    print(f"  UV range: {np.min(uv_wavelengths):.0f}-{np.max(uv_wavelengths):.0f} nm")
    print(f"  Minimum transmission: {min_trans:.6f} at {min_wvl:.0f} nm")
    print(f"  Mean UV transmission: {mean_uv_trans:.6f}")
    
    # Categorize absorption strength in UV
    very_strong = np.sum(uv_transmission < 0.01)
    strong = np.sum(uv_transmission < 0.1)
    moderate = np.sum(uv_transmission < 0.5)
    
    print(f"  UV absorption points - Very strong: {very_strong}, Strong: {strong}, Moderate: {moderate}")

def main():
    """Main analysis function"""
    
    print("PYTHON OZONE TRANSMITTANCE ANALYSIS")
    print("="*50)
    print("Original Python Ozone_Transmission implementation")
    
    # Test parameters
    z_test = 30.0       # zenith angle
    
    # Test different ozone column densities (Dobson Units)
    # Typical range: 200-500 DU (varies with latitude, season)
    uo_values = [200, 250, 300, 350, 400, 450]  # DU
    
    print(f"\nTest conditions:")
    print(f"  Zenith angle: {z_test:.1f}°")
    print(f"  Ozone column amounts: {uo_values} DU")
    
    # Get wavelength info
    wvl_arr = make_wvl_array()
    print(f"  Wavelengths: {len(wvl_arr)} points [{np.min(wvl_arr):.0f}-{np.max(wvl_arr):.0f} nm]")
    
    # Test each ozone column amount
    results = {}
    wavelengths = None
    
    for uo in uo_values:
        trans, wvl = analyze_ozone_transmission(z_test, uo, verbose=True)
        results[uo] = trans
        if wavelengths is None:
            wavelengths = wvl
    
    # Analyze UV absorption characteristics for a reference case
    uo_ref = 300  # DU (typical mid-latitude value)
    if uo_ref in results:
        analyze_uv_absorption(wavelengths, results[uo_ref], uo_ref)
    
    # Show ozone column sensitivity analysis
    print(f"\n" + "="*50)
    print("OZONE COLUMN SENSITIVITY ANALYSIS")
    print("="*50)
    
    print(f"\n{'Uo (DU)':<8} | {'Range':<15} | {'Mean':<10} | {'Opaque':<8} | {'Strong':<8} | {'Moderate':<10}")
    print("-" * 70)
    
    for uo in uo_values:
        trans = results[uo]
        min_val, max_val = np.min(trans), np.max(trans)
        mean_val = np.mean(trans)
        
        very_strong_abs = np.sum(trans < 0.01)   # Nearly opaque
        strong_abs = np.sum(trans < 0.1)         # Strong absorption
        moderate_abs = np.sum(trans < 0.5)       # Moderate absorption
        
        print(f"{uo:<8.0f} | [{min_val:.6f},{max_val:.6f}] | {mean_val:<10.6f} | "
              f"{very_strong_abs:<8} | {strong_abs:<8} | {moderate_abs:<10}")
    
    # Save results for MATLAB comparison
    print(f"\nSaving results for MATLAB comparison...")
    
    try:
        from scipy.io import savemat
        
        save_data = {
            'wavelengths': wavelengths,
            'test_conditions': {
                'zenith_angle': z_test,
                'uo_values': np.array(uo_values)
            }
        }
        
        # Add transmission data for each ozone amount
        for uo in uo_values:
            field_name = f'uo_{uo}_transmission'
            save_data[field_name] = results[uo]
        
        savemat('python_ozone_results.mat', save_data)
        print("✅ Results saved to python_ozone_results.mat")
        
    except ImportError:
        print("⚠️  scipy not available, saving as text files")
        
        # Save as text files
        np.savetxt('python_ozone_wavelengths.txt', wavelengths)
        for uo in uo_values:
            filename = f'python_ozone_uo{uo}_transmission.txt'
            np.savetxt(filename, results[uo])
        print("✅ Results saved as individual text files")
    
    # Physical interpretation
    print(f"\n" + "="*50)
    print("PHYSICAL INTERPRETATION")
    print("="*50)
    
    print(f"\nOzone absorption characteristics:")
    print(f"• Primary absorption in UV region (Hartley band: 200-300 nm)")
    print(f"• Secondary absorption in visible (Chappuis band: 400-650 nm)")
    print(f"• Strong UV absorption protects life from harmful radiation")
    print(f"• Absorption follows Beer-Lambert law: T = exp(-σ * Uo * AM)")
    print(f"  where σ = cross-section, Uo = column density, AM = airmass")
    print(f"• Column density varies:")
    print(f"  - Latitude: 200-300 DU (tropics) to 300-500 DU (polar)")
    print(f"  - Season: Lower in spring, higher in fall")
    print(f"  - Altitude: Most ozone in stratosphere (15-30 km)")
    print(f"• Uses Loschmidt number for unit conversion: {2.6867811e19:.2e} cm⁻³")
    print(f"• SMARTS airmass coefficients account for atmospheric path length")
    
    print(f"\n✅ Python ozone analysis complete!")
    print(f"Run MATLAB ozone_transmission_comparison_tool.m for full comparison")

if __name__ == '__main__':
    main()