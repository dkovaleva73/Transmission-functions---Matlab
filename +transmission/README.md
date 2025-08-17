# MATLAB Transmission Calculation Package

A comprehensive MATLAB package for calculating total optical transmission through astronomical systems, combining instrumental and atmospheric components.

## Overview

This package provides accurate transmission calculations for the LAST (Large Array Survey Telescope) system, implementing both instrumental (OTA - Optical Telescope Assembly) and atmospheric transmission models.

## Quick Start

```matlab
% Basic usage - calculate total transmission with defaults
Total = transmission.calculateTransmission();

% Custom wavelength range
Lam = linspace(400, 900, 251)';
Total = transmission.calculateTransmission(Lam);

% Different atmospheric conditions
Total = transmission.calculateTransmission('photometric_night');

% Instrumental transmission only (no atmosphere)
Total = transmission.calculateTransmission('no_atmosphere');

% Get detailed components
[Total, Components] = transmission.calculateTransmission();
```

## Main Functions

### `transmission.calculateTransmission()` - Convenience Function
User-friendly interface with flexible input options.

**Usage Examples:**
```matlab
% All defaults
Total = transmission.calculateTransmission();

% Custom wavelengths + scenario
Lam = linspace(350, 950, 301)';
Total = transmission.calculateTransmission(Lam, 'high_altitude');

% With plotting and detailed output
[Total, Components] = transmission.calculateTransmission('plot');
```

### `transmission.totalTransmission()` - Core Function
Direct interface for total transmission calculation.

```matlab
Config = transmission.inputConfig('default');
Lam = transmission.utils.makeWavelengthArray(Config);
Total = transmission.totalTransmission(Lam, Config);
```

### `transmission.calibratorWorkflow()` - Complete Calibrator Pipeline
One-stop function that performs the complete calibrator processing workflow.

```matlab
% Basic usage with defaults
totalFlux = transmission.calibratorWorkflow();

% With custom configuration and plotting
Config = transmission.inputConfig('photometric_night');
[totalFlux, SpecTrans, Wavelength, Metadata, Results] = transmission.calibratorWorkflow(Config, 'PlotResults', true);

% Override catalog file and save results
totalFlux = transmission.calibratorWorkflow([], 'CatalogFile', '/path/to/catalog.fits', 'SaveResults', true);
```

### `transmission.calibrators.*` - Individual Calibrator Functions
Step-by-step functions for custom calibrator processing workflows.

```matlab
% Find Gaia calibrators around LAST sources
[Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoords();

% Apply transmission to calibrator spectra
[SpecTrans, Wavelength, TransFunc] = transmission.calibrators.applyTransmissionToCalibrators(Spec, Metadata);

% Calculate total flux in photons
totalFlux = transmission.calibrators.calculateTotalFluxCalibrators(Wavelength, SpecTrans, Metadata);
```

## Package Structure

```
+transmission/
├── totalTransmission.m              % Core total transmission
├── calibratorWorkflow.m             % Complete calibrator processing pipeline
├── inputConfig.m                    % Configuration management
├── +instrumental/                   % Instrumental components
│   ├── otaTransmission.m           % Complete OTA transmission
│   ├── quantumEfficiency.m         % CCD quantum efficiency
│   ├── mirrorReflectance.m          % Mirror reflectivity
│   ├── correctorTransmission.m     % Corrector transmission
│   └── fieldCorrection.m           % Field-dependent corrections
├── +atmospheric/                    % Atmospheric components
│   ├── atmosphericTransmission.m   % Total atmospheric transmission
│   ├── rayleighTransmission.m      % Rayleigh scattering
│   ├── aerosolTransmission.m       % Aerosol extinction
│   ├── ozoneTransmission.m         % Ozone absorption
│   ├── waterTransmittance.m        % Water vapor absorption
│   └── umgTransmittance.m          % Uniformly Mixed Gas transmission
├── +calibrators/                    % Calibrator processing
│   ├── applyTransmissionToCalibrators.m   % Apply transmission to Gaia spectra
│   └── calculateTotalFluxCalibrators.m    % Calculate total flux in photons
├── +data/                          % Data handling and catalog processing
│   ├── findCalibratorsWithCoords.m % Find Gaia calibrators around LAST sources
│   └── loadAbsorptionData.m        % Load molecular absorption data
├── +utils/                         % Utility functions
│   ├── makeWavelengthArray.m       % Wavelength array generation
│   ├── skewedGaussianModel.m       % Skewed Gaussian model
│   ├── legendreModel.m             % Legendre polynomial model
│   ├── chebyshevModel.m            % Chebyshev polynomial model
│   ├── rescaleInputData.m          % Data rescaling utilities
│   └── airmassFromSMARTS.m         % Airmass calculation from SMARTS
└── examples/
    └── totalTransmissionDemo.m      % Complete demonstration
```
VO.search
improc.match
profview - profiler time of work
dnd
fmeansearch

handles, parameters
set, free - input for minimizator
xy minimization - lineary 
linearization for other 3? 

simplex method
convex


## Key Features

### ✅ Physically Realistic Results
- All transmission values bounded to [0, 1]
- Proper normalization of quantum efficiency
- Validated against reference data

### ✅ Comprehensive Atmospheric Modeling
- Rayleigh scattering
- Aerosol extinction  
- Ozone absorption
- Water vapor absorption
- Multiple atmospheric scenarios

### ✅ Accurate Instrumental Modeling
- CCD quantum efficiency (Skewed Gaussian × Legendre)
- Mirror reflectance (from StarBrightXLT data)
- Corrector transmission (from StarBrightXLT data)
- Field-dependent corrections

### ✅ Flexible Configuration System
- Predefined scenarios: `default`, `photometric_night`, `humid_conditions`, `high_altitude`, etc.
- Centralized parameter management
- Easy customization

### ✅ Calibrator Processing Pipeline
- Cross-matching LAST catalog sources with Gaia DR3 spectra
- Automatic magnitude filtering and duplicate removal
- Transmission application to Gaia spectra (336-1020 nm → 300-1100 nm)
- Total flux calculation in photons following Garrappa et al. 2025 methodology

## Configuration Scenarios

| Scenario | Description | Key Parameters |
|----------|-------------|----------------|
| `default` | Standard observing conditions | PWV: 1.0 cm, AOD: 0.1 |
| `photometric_night` | Excellent conditions | PWV: 0.5 cm, AOD: 0.05 |
| `humid_conditions` | High humidity | PWV: 3.0 cm |
| `high_altitude` | High altitude site | Pressure: 610 mbar, PWV: 0.2 cm |
| `sea_level` | Sea level site | Pressure: 1013 mbar |
| `dusty_conditions` | High aerosol loading | AOD: 0.3 |

## Performance

- **Calculation speed:** ~250 points/ms (typical hardware)
- **Memory efficient:** Vectorized operations
- **Scalable:** Handles 1-10000+ wavelength points

## Example Results

**Default conditions (300-1100 nm):**
- Peak transmission: 49.8% at 518 nm
- Mean transmission: 19.8%
- Effective range: 336-1016 nm (>1% peak)

**Instrumental only (no atmosphere):**
- Peak transmission: 79.5% at 477 nm  
- Mean transmission: 31.8%
- Demonstrates ~38% atmospheric loss on average

## References

1. Garrappa et al. 2025, A&A 699, A50 - Transmission modeling methodology
2. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - CCD quantum efficiency parameters
3. Gueymard, C. A. (2019). Solar Energy, 187, 233-253 - SMARTS atmosphere model
4. Ofek et al. AstroPack: https://www.mathworks.com/matlabcentral/fileexchange/128984-astropack-maatv2

## Dependencies

- MATLAB R2020b or later
- Statistics and Machine Learning Toolbox (for polynomial fitting)
- AstroPack 

## Contact

For questions or issues, please contact D. Kovaleva or refer to the Garrappa et al. 2025 paper.


