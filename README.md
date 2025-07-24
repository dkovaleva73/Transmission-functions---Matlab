# MATLAB Atmospheric Transmission Package

A comprehensive MATLAB package for calculating atmospheric and instrumental transmission effects for astronomical and optical applications.

## Features

### Atmospheric Effects
- **Rayleigh Scattering**: Molecular scattering using Gueymard (2019) formulation
- **Aerosol Extinction**: Aerosol scattering and absorption with Angstrom law
- **Ozone Absorption**: UV ozone absorption using tabulated cross-sections
- **Water Vapor Absorption**: Complex water vapor transmission model with multiple bands
- **Combined Calculator**: Total atmospheric transmission combining all effects

### Utilities
- **Airmass Calculations**: SMARTS 2.9.5 tabulated values for different constituents
- **Wavelength Arrays**: Flexible wavelength grid generation
- **Validation Tools**: Test functions for package verification

## Installation

1. Clone or download this repository to your MATLAB path
2. Ensure you're in the `matlab_projects` directory or add it to your MATLAB path
3. The package uses MATLAB's `+package` structure for organization

## Quick Start

```matlab
% Create wavelength array
wavelength = transmission.utils.make_wavelength_array(400, 800, 201);

% Define atmospheric parameters
zenith_angle = 30; % degrees
pressure = 1013.25; % mbar
precip_water = 2.0; % cm
ozone_dobson = 300; % Dobson units
aod500 = 0.1; % Aerosol optical depth at 500nm
alpha = 1.3; % Angstrom exponent

% Calculate individual components
trans_rayleigh = transmission.atmospheric.rayleigh(zenith_angle, pressure, wavelength);
trans_aerosol = transmission.atmospheric.aerosol(zenith_angle, aod500, alpha, wavelength);

% Calculate total transmission
params.pressure = pressure;
params.precipitable_water = precip_water;
params.ozone_dobson = ozone_dobson;
params.aerosol_aod500 = aod500;
params.aerosol_alpha = alpha;

trans_total = transmission.atmospheric_total(zenith_angle, params, wavelength);

% Plot results
plot(wavelength, trans_total);
xlabel('Wavelength (nm)');
ylabel('Transmission');
title('Atmospheric Transmission');
```

## Package Structure

```
+transmission/
├── +atmospheric/           # Atmospheric transmission effects
│   ├── aerosol.m          # Aerosol extinction
│   ├── rayleigh.m         # Rayleigh scattering
│   ├── ozone.m            # Ozone absorption
│   └── water.m            # Water vapor absorption
├── +instrumental/          # Instrumental effects (future)
├── +utils/                # Utility functions
│   ├── airmass_from_SMARTS.m
│   └── make_wavelength_array.m
├── atmospheric_total.m     # Combined atmospheric calculator
└── examples/              # Example scripts
```

## Function Reference

### Atmospheric Functions

#### `transmission.atmospheric.rayleigh(zenith_angle, pressure, wavelength)`
Calculate Rayleigh scattering transmission.
- `zenith_angle`: Zenith angle in degrees
- `pressure`: Surface pressure in mbar
- `wavelength`: Wavelength array in nm

#### `transmission.atmospheric.aerosol(zenith_angle, aod500, alpha, wavelength)`
Calculate aerosol extinction transmission.
- `zenith_angle`: Zenith angle in degrees
- `aod500`: Aerosol optical depth at 500nm
- `alpha`: Angstrom exponent
- `wavelength`: Wavelength array in nm

#### `transmission.atmospheric.ozone(zenith_angle, dobson_units, wavelength)`
Calculate ozone absorption transmission.
- `zenith_angle`: Zenith angle in degrees
- `dobson_units`: Ozone column in Dobson units
- `wavelength`: Wavelength array in nm

#### `transmission.atmospheric.water(zenith_angle, precip_water, pressure, wavelength)`
Calculate water vapor absorption transmission.
- `zenith_angle`: Zenith angle in degrees
- `precip_water`: Precipitable water in cm
- `pressure`: Surface pressure in hPa
- `wavelength`: Wavelength array in nm

#### `transmission.atmospheric_total(zenith_angle, params, wavelength, options)`
Calculate total atmospheric transmission.
- `zenith_angle`: Zenith angle in degrees
- `params`: Structure with atmospheric parameters
- `wavelength`: Wavelength array in nm
- `options`: Optional name-value pairs to enable/disable components

### Utility Functions

#### `transmission.utils.make_wavelength_array(min_wvl, max_wvl, num_points)`
Generate wavelength array for calculations.
- `min_wvl`: Minimum wavelength in nm (default: 300)
- `max_wvl`: Maximum wavelength in nm (default: 1100)
- `num_points`: Number of points (default: 401)

#### `transmission.utils.airmass_from_SMARTS(zenith_angle, constituent)`
Calculate airmass using SMARTS tabulated values.
- `zenith_angle`: Zenith angle in degrees
- `constituent`: Atmospheric constituent name

## Examples

Run the example script:
```matlab
run('example_atmospheric_transmission.m')
```

This will demonstrate:
- Individual transmission components
- Total atmospheric transmission
- Effect of different zenith angles
- Plotting and analysis

## Data Requirements

Some functions require external data files:
- **Ozone**: `Abs_O3UV.dat` for UV ozone cross-sections
- **Water vapor**: `Abs_H2O.dat` for water vapor absorption coefficients

The package will automatically search for these files in common locations.

## References

1. Gueymard, C. A. (2019). The SMARTS spectral irradiance model after 25 years: New developments and validation of reference spectra. Solar Energy, 187, 233-253.

2. Gueymard, C. A. (2001). Parameterized transmittance model for direct beam and circumsolar spectral irradiance. Solar Energy, 71(5), 325-346.

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
