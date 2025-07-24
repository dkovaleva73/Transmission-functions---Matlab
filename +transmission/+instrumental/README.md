# Instrumental Transmission Module

This module contains MATLAB implementations of instrumental transmission functions ported from the Python transmission_fitter package.

## Components

### Core Functions
- `calculateOTATransmission.m` - Main OTA transmission calculation combining QE, mirror, and corrector
- `quantumEfficiencyModel.m` - QE modeling using Skewed Gaussian + Legendre polynomials
- `legendreModel.m` - Legendre polynomial corrections for QE
- `fieldCorrections.m` - Spatial field-dependent corrections using Chebyshev polynomials

### Data Loaders
- `loadInstrumentalData.m` - Load QE curves, mirror reflectivity, corrector transmission
- `loadFilterData.m` - Load SDSS filter transmission curves

### Utilities
- `normalizeWavelength.m` - Wavelength normalization for polynomial bases
- `skewedGaussian.m` - Skewed Gaussian model implementation

## Data Files
Templates directory contains:
- QE curves (QHY600M variants)
- Mirror reflectivity curves (StarBrightXLT)
- Corrector transmission curves
- SDSS filter transmission curves
- Transmission templates

## Usage
```matlab
% Basic OTA transmission calculation
Lam = transmission.utils.makeWavelengthArray();
[Trans_OTA, QE_model, Mirror_refl, Corrector_trans] = ...
    transmission.instrumental.calculateOTATransmission(Lam);

% With custom parameters
params = transmission.instrumental.getDefaultParameters();
params.amplitude = 350.0;  % Modify QE amplitude
Trans_OTA = transmission.instrumental.calculateOTATransmission(Lam, 'Parameters', params);
```