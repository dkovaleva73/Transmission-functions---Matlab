#!/usr/bin/env python3
"""
Compare Python and MATLAB atmospheric transmission implementations
"""
import numpy as np
import matplotlib.pyplot as plt
import sys
sys.path.append('/home/dana/anaconda3/envs/myenv/lib/python3.12/site-packages')

from transmission_fitter.atmospheric_models import (
    Rayleigh_Transmission, 
    Ozone_Transmission,
    WaterTransmittance,
    Aerosol_Transmission,
    UMGTransmittance
)

# Standard test conditions matching MATLAB defaults
z_ = 0.0           # Zenith angle (degrees)
p_ = 1013.25       # Pressure (mbar)
tair = 15.0        # Temperature (C)
dobson = 300       # Ozone (Dobson units)
pwv = 1.0          # Precipitable water vapor (cm)
tau_aod = 0.084    # Aerosol optical depth at 500nm
alpha = 0.6        # Angstrom exponent
co2_ppm = 395      # CO2 concentration

# Create wavelength array - 101 points from 300 to 1100 nm
wavelengths = np.linspace(300, 1100, 101)

print("=== PYTHON ATMOSPHERIC TRANSMISSION ===")
print(f"\nTest conditions:")
print(f"  Zenith angle: {z_} deg")
print(f"  Pressure: {p_} mbar")
print(f"  Temperature: {tair} C")
print(f"  Ozone: {dobson} DU")
print(f"  Water vapor: {pwv} cm")
print(f"  Aerosol AOD: {tau_aod}")
print(f"  CO2: {co2_ppm} ppm")

# Calculate individual components
print("\nCalculating components...")

# Rayleigh
ray = Rayleigh_Transmission(z_, p_)
trans_ray = ray.make_transmission()
trans_ray_interp = np.interp(wavelengths, ray.wvl_arr, trans_ray)

# Ozone
oz = Ozone_Transmission(z_, dobson)
trans_oz = oz.make_transmission()
trans_oz_interp = np.interp(wavelengths, oz.wvl_arr, trans_oz)

# Water
water = WaterTransmittance(z_, pwv, p_)
trans_water = water.make_transmission()
trans_water_interp = np.interp(wavelengths, water.wvl_arr, trans_water)

# Aerosol
aer = Aerosol_Transmission(z_, tau_aod, alpha)
trans_aer = aer.make_transmission()
trans_aer_interp = np.interp(wavelengths, aer.wvl_arr, trans_aer)

# UMG with trace gases
umg = UMGTransmittance(z_, tair, p_, co2_ppm, with_trace_gases=True)
trans_umg = umg.make_transmission()
trans_umg_interp = np.interp(wavelengths, umg.wvl_arr, trans_umg)

# Total transmission
trans_total = trans_ray_interp * trans_oz_interp * trans_water_interp * trans_aer_interp * trans_umg_interp

# Output results for comparison
print("\n# Wavelength(nm), Trans_Total, Trans_Ray, Trans_Oz, Trans_Water, Trans_Aer, Trans_UMG")
for i in range(len(wavelengths)):
    print(f"{wavelengths[i]:.1f}, {trans_total[i]:.6f}, {trans_ray_interp[i]:.6f}, "
          f"{trans_oz_interp[i]:.6f}, {trans_water_interp[i]:.6f}, "
          f"{trans_aer_interp[i]:.6f}, {trans_umg_interp[i]:.6f}")

plt.figure()
plt.plot(wavelengths, trans_total);
plt.show()

# Summary statistics
print(f"\n=== SUMMARY ===")
print(f"Mean total transmission: {np.mean(trans_total):.4f}")
print(f"Min total transmission: {np.min(trans_total):.4f}")
print(f"Max total transmission: {np.max(trans_total):.4f}")

# Band averages
uv_mask = (wavelengths >= 300) & (wavelengths <= 400)
vis_mask = (wavelengths >= 400) & (wavelengths <= 700)
nir_mask = (wavelengths >= 700) & (wavelengths <= 1100)

print(f"\nMean UV transmission (300-400 nm): {np.mean(trans_total[uv_mask]):.4f}")
print(f"Mean visible transmission (400-700 nm): {np.mean(trans_total[vis_mask]):.4f}")
print(f"Mean NIR transmission (700-1100 nm): {np.mean(trans_total[nir_mask]):.4f}")