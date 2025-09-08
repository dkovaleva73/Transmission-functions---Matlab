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

### `transmission.TransmissionOptimizer` - Multi-Stage Optimization
Comprehensive optimization system for calibrating transmission parameters using field calibrators.

```matlab
% Run full optimization sequence
Config = transmission.inputConfig();
optimizer = transmission.TransmissionOptimizer(Config);
finalParams = optimizer.runFullSequence();

% Use optimized parameters for photometry
CatalogAB = transmission.calculateAbsolutePhotometry(finalParams, Config);

% Get calibrator results with DiffMag
CalibratorTable = optimizer.getCalibratorResults();
```

### `transmission.TransmissionOptimizerAdvanced` - Advanced Multi-Stage Optimization
Enhanced optimizer with support for mixed optimization algorithms (nonlinear and linear least squares).

```matlab
% Run optimization with linear solver for field corrections
Config = transmission.inputConfig();
optimizer = transmission.TransmissionOptimizerAdvanced(Config);
finalParams = optimizer.runFullSequence();

% Customize minimizer for specific stages
optimizer.setMinimizerForStage(3, 'linear');  % Use linear solver for stage 3

% Get results and visualize
CalibratorTable = optimizer.getCalibratorResults();
optimizer.plotResults();  % Visualize optimization progress
```

### `transmission.minimizerFminGeneric` - Nonlinear Parameter Optimization
Generic nonlinear optimization engine using fminsearch with support for free/fixed parameters and sigma clipping.

```matlab
% Direct optimization call (usually called via TransmissionOptimizer)
Config = transmission.inputConfig();
[OptimalParams, Fval, ExitFlag, Output, ResultData] = ...
    transmission.minimizerFminGeneric(Config, ...
        'FreeParams', ["Norm_", "Center"], ...
        'SigmaClipping', true);
```

### `transmission.minimizerLinearLeastSquares` - Linear Field Correction Optimization
Specialized linear least squares solver for field correction parameters with closed-form solution.

```matlab
% Optimize field corrections using linear least squares
Config = transmission.inputConfig();
[OptimalParams, Fval] = transmission.minimizerLinearLeastSquares(Config, ...
    'FreeParams', ["kx0", "kx", "ky", "kx2", "ky2", "kx3", "ky3", "kx4", "ky4", "kxy"], ...
    'SigmaClipping', true, ...
    'Regularization', 1e-6);
```

### `transmission.calculateAbsolutePhotometry` - AB Magnitude Calculation
Calculate absolute photometry using optimized transmission parameters.

```matlab
% Calculate AB magnitudes for all stars
Config = transmission.inputConfig();
optimizer = transmission.TransmissionOptimizer(Config);
finalParams = optimizer.runFullSequence();
CatalogAB = transmission.calculateAbsolutePhotometry(finalParams, Config);
```

## Package Structure

```
+transmission/
├── totalTransmission.m              % Core total transmission
├── calibratorWorkflow.m             % Complete calibrator processing pipeline
├── inputConfig.m                    % Configuration management
├── minimizerFminGeneric.m          % Nonlinear parameter optimization (fminsearch)
├── minimizerLinearLeastSquares.m   % Linear least squares optimization for field corrections
├── TransmissionOptimizer.m         % Multi-stage optimization controller
├── TransmissionOptimizerAdvanced.m % Advanced optimizer with mixed algorithms
├── calculateAbsolutePhotometry.m   % Calculate AB magnitudes from optimized params
├── calculateCostFunction.m         % Standalone cost function calculator
├── +instrumental/                   % Instrumental components
│   ├── otaTransmission.m           % Complete OTA transmission
│   ├── calculateInstrumentalResponse.m % Instrumental response calculation
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
│   ├── findCalibratorsForAstroImage.m % Find calibrators for AstroImage fields
│   └── loadAbsorptionData.m        % Load molecular absorption data
├── +utils/                         % Utility functions
│   ├── makeWavelengthArray.m       % Wavelength array generation
│   ├── skewedGaussianModel.m       % Skewed Gaussian model
│   ├── legendreModel.m             % Legendre polynomial model
│   ├── chebyshevModel.m            % Chebyshev polynomial model
│   ├── rescaleInputData.m          % Data rescaling utilities
│   ├── airmassFromSMARTS.m         % Airmass calculation from SMARTS
│   └── sigmaClip.m                 % Sigma clipping for outlier removal
└── examples/
    └── totalTransmissionDemo.m      % Complete demonstration
```


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

### ✅ Advanced Optimization System
- Multi-stage optimization workflow based on Python fitutils module
- **Mixed optimization algorithms**: Nonlinear (fminsearch) and linear least squares
- **Linear solver for field corrections**: Fast, exact solution for Chebyshev coefficients
- Support for free and fixed parameter optimization
- Sigma clipping for outlier rejection with data propagation
- Python-compliant and simple field correction models
- Automatic calibrator matching with Gaia DR3
- **Advanced optimizer**: Stage-specific algorithm selection
- **Visualization tools**: Optimization progress and residual analysis

### ✅ Flexible Configuration System
- Predefined scenarios: `default`, `photometric_night`, `humid_conditions`, `high_altitude`, etc.
- Centralized parameter management
- Easy customization
- Optimization bounds management

### ✅ Calibrator Processing Pipeline
- Cross-matching LAST catalog sources with Gaia DR3 spectra
- Automatic magnitude filtering and duplicate removal
- Transmission application to Gaia spectra (336-1020 nm → 300-1100 nm)
- Total flux calculation in photons following Garrappa et al. 2025 methodology
- AB magnitude calculation with field-dependent corrections

## Optimization Workflow

The package provides two optimization approaches:

### Standard Optimization (TransmissionOptimizer)
5-stage nonlinear optimization sequence:
1. **Norm_** - Initial normalization with sigma clipping
2. **Norm_, Center** - QE parameters optimization
3. **Field corrections** - Chebyshev coefficients (nonlinear)
4. **Norm_** - Refinement after field corrections
5. **Pwv_cm, Tau_aod500** - Atmospheric parameters

### Advanced Optimization (TransmissionOptimizerAdvanced)
Mixed algorithm approach with superior performance:
1. **Norm_** - Initial normalization (nonlinear, sigma clipping)
2. **Norm_, Center** - QE parameters (nonlinear)
3. **Field corrections** - Chebyshev coefficients (**linear least squares**)
4. **Norm_** - Refinement (nonlinear)
5. **Pwv_cm, Tau_aod500** - Atmospheric parameters (nonlinear)

**Key advantages of Advanced Optimizer:**
- **10-100x faster** field correction optimization using linear solver
- **Exact solution** for field correction coefficients
- **Better convergence** with proper parameter propagation
- **Flexible**: Choose algorithm per stage
- **Robust**: Handles sigma-clipped data correctly

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


