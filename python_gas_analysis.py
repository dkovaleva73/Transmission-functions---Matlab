#!/usr/bin/env python3
"""
Python Gas-by-Gas Transmittance Analysis
Companion script for MATLAB gas_by_gas_comparison_tool.m

This script calculates individual gas transmittances using the original Python 
UMGTransmittance class and saves results for comparison with MATLAB implementation.

Usage:
    python python_gas_analysis.py

Requirements:
    - transmission_fitter package installed
    - scipy (for saving .mat files)
"""

import numpy as np
import sys
import os

# Add the transmission_fitter package to path
sys.path.insert(0, '/home/dana/anaconda3/envs/myenv/lib/python3.12/site-packages')

from transmission_fitter.atmospheric_models import UMGTransmittance, NLOSCHMIDT
from transmission_fitter.abscalutils import make_wvl_array

class SingleGasUMG(UMGTransmittance):
    """Modified UMGTransmittance to test individual gases"""
    
    def __init__(self, z_, tair, p_, co2_ppm=415., with_trace_gases=True, target_gas='ALL'):
        super().__init__(z_, tair, p_, co2_ppm, with_trace_gases)
        self.target_gas = target_gas
        
    def _optical_depth(self, pp0, sza):
        """Modified optical depth calculation for single gas testing"""
        
        tt0 = np.zeros_like(pp0) + (self.tair + 273.15) / 273.15
        taug_l = np.zeros((len(sza), len(self.wvl_arr)))

        def getam(constituent):
            return self.Airmass_from_SMARTS(sza, constituent)

        def getabs(constituent):
            return getattr(self, f'{constituent}abs')[None, :]

        # Only calculate for target gas
        if self.target_gas == 'O2' or self.target_gas == 'ALL':
            # 1. Oxygen, O2
            abundance = 1.67766e5 * pp0
            taug_l += getabs('o2') * abundance * getam('o2')
            
        if self.target_gas == 'CH4' or self.target_gas == 'ALL':
            # 2. Methane, CH4
            abundance = 1.3255 * (pp0 ** 1.0574)
            taug_l += getabs('ch4') * abundance * getam('ch4')
            
        if self.target_gas == 'CO' or self.target_gas == 'ALL':
            # 3. Carbon Monoxide, CO
            abundance = .29625 * (pp0**2.4480) * \
                np.exp(.54669 - 2.4114 * pp0 + .65756 * (pp0**2))
            taug_l += getabs('co') * abundance * getam('co')
            
        if self.target_gas == 'N2O' or self.target_gas == 'ALL':
            # 4. Nitrous Oxide, N2O
            abundance = .24730 * (pp0**1.0791)
            taug_l += getabs('n2o') * abundance * getam('n2o')
            
        if self.target_gas == 'CO2' or self.target_gas == 'ALL':
            # 5. Carbon Dioxide, CO2
            abundance = 0.802685 * self.co2_ppm * pp0
            taug_l += getabs('co2') * abundance * getam('co2')
            
        if self.target_gas == 'N2' or self.target_gas == 'ALL':
            # 6. Nitrogen, N2
            abundance = 3.8269 * (pp0**1.8374)
            taug_l += getabs('n2') * abundance * getam('n2')
            
        if self.target_gas == 'O4' or self.target_gas == 'ALL':
            # 7. Oxygen-Oxygen, O4
            abundance = 1.8171e4 * (NLOSCHMIDT**2) * (pp0**1.7984) / (tt0**.344)
            taug_l += getabs('o4') * abundance * getam('o2')

        # Trace gases (if enabled)
        if self.with_trace_gases:
            if self.target_gas == 'NH3' or self.target_gas == 'ALL':
                # 7. Ammonia, NH3
                lpp0 = np.log(pp0)
                abundance = np.exp(
                    - 8.6499 + 2.1947*lpp0 - 2.5936*(lpp0**2)
                    - 1.819*(lpp0**3) - 0.65854*(lpp0**4))
                taug_l += getabs('nh3') * abundance * getam('nh3')

        return taug_l

def analyze_single_gas(gas_name, z_=30.0, tair=15.0, p_=1013.25, co2_ppm=415.0, verbose=True):
    """Analyze transmittance for a single gas"""
    
    if verbose:
        print(f"\nAnalyzing {gas_name} transmittance...")
    
    # Create single-gas UMG model
    umg = SingleGasUMG(z_, tair, p_, co2_ppm, with_trace_gases=True, target_gas=gas_name)
    
    # Calculate transmittance
    trans = umg.make_transmission()
    
    if verbose:
        # Analyze results
        min_trans = np.min(trans)
        max_trans = np.max(trans)
        mean_trans = np.mean(trans)
        
        min_idx = np.argmin(trans)
        wavelengths = umg.wvl_arr
        
        # Find absorption features
        strong_absorption = np.sum(trans < 0.99)
        
        print(f"  Range: [{min_trans:.6f}, {max_trans:.6f}]")
        print(f"  Mean: {mean_trans:.6f}")
        print(f"  Min at λ={wavelengths[min_idx]:.0f}nm: {min_trans:.6f}")
        print(f"  Absorption points (T<0.99): {strong_absorption}")
    
    return trans, umg.wvl_arr

def main():
    """Main analysis function"""
    
    print("PYTHON GAS-BY-GAS TRANSMITTANCE ANALYSIS")
    print("="*50)
    print("Original Python UMGTransmittance implementation")
    
    # Test parameters
    z_test = 30.0
    tair_test = 15.0
    p_test = 1013.25
    co2_ppm = 415.0
    
    print(f"\nTest conditions:")
    print(f"  Zenith angle: {z_test:.1f}°")
    print(f"  Temperature: {tair_test:.1f}°C")
    print(f"  Pressure: {p_test:.1f} hPa")
    print(f"  CO2: {co2_ppm:.0f} ppm")
    
    # Test each gas
    gases = ['O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4', 'NH3']
    results = {}
    
    for gas in gases:
        trans, wavelengths = analyze_single_gas(
            gas, z_test, tair_test, p_test, co2_ppm, verbose=True)
        results[gas] = trans
    
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
                'co2_ppm': co2_ppm
            }
        }
        
        # Add transmission data for each gas
        for gas in gases:
            save_data[f'{gas}_transmission'] = results[gas]
        
        savemat('python_gas_results.mat', save_data)
        print("✅ Results saved to python_gas_results.mat")
        
    except ImportError:
        print("⚠️  scipy not available, saving as text files")
        
        # Save as text files
        np.savetxt('python_wavelengths.txt', wavelengths)
        for gas in gases:
            np.savetxt(f'python_{gas}_transmission.txt', results[gas])
        print("✅ Results saved as individual text files")
    
    # Summary
    print(f"\n" + "="*50)
    print("ANALYSIS SUMMARY")
    print("="*50)
    
    print(f"\nGas Transmission Ranges:")
    for gas in gases:
        trans = results[gas]
        min_val, max_val = np.min(trans), np.max(trans)
        absorption_points = np.sum(trans < 0.99)
        print(f"  {gas:<4}: [{min_val:.6f}, {max_val:.6f}] - {absorption_points} absorption points")
    
    print(f"\n✅ Python analysis complete!")
    print(f"Run MATLAB gas_by_gas_comparison_tool.m for full comparison")

if __name__ == '__main__':
    main()