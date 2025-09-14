# transmissionFast Package

A high-performance MATLAB package for calculating astronomical transmission functions combining instrumental and atmospheric effects with advanced caching optimizations.

## Overview

The `transmissionFast` package provides fast, accurate calculations of total transmission for astronomical observations by combining:
- **Instrumental transmission**: Optical Telescope Assembly (OTA) components including quantum efficiency, mirror reflectance, and corrector transmission
- **Atmospheric transmission**: Rayleigh scattering, molecular absorption (O₃, H₂O, UMG), and aerosol scattering

## Key Performance Features

### 🚀 5-Layer Caching System
- **Configuration caching**: Parameters and absorption data cached in `inputConfig()`
- **Wavelength array caching**: Automatic extraction from `Config.WavelengthArray`
- **Persistent function caching**: Results cached for identical parameters
- **File I/O caching**: CSV data loaded once and reused
- **Airmass-dependent caching**: Atmospheric calculations optimized per airmass

### ⚡ Performance Gains
- **mirrorReflectance**: 124× faster on cached calls
- **correctorTransmission**: 18× faster on cached calls
- **Automatic memory extraction**: Functions use cached wavelength arrays when no explicit wavelength provided
- **Eliminated redundant calculations**: No repeated `makeWavelengthArray()` calls during optimization

### 🔄 Backward Compatibility
- All existing function calls work unchanged
- Multi-parameter interfaces preserved
- Graceful fallbacks when cached data unavailable

## Quick Start

```matlab
% Basic usage with automatic caching - fastest approach
Config = transmissionFast.inputConfig('default');
Total = transmissionFast.totalTransmission();  % Uses cached wavelength array

% Custom wavelength range (explicit)
Lam = transmissionFast.utils.makeWavelengthArray(Config);
Total = transmissionFast.totalTransmission(Lam, Config);

% With pre-loaded absorption data for maximum performance in loops
AbsData = transmissionFast.data.loadAbsorptionData([], {}, false);
Total = transmissionFast.totalTransmission([], Config, 'AbsorptionData', AbsData);

% Different atmospheric conditions using cached wavelength
Config = transmissionFast.inputConfig('photometric_night');
Total = transmissionFast.totalTransmission([], Config);  % Automatic wavelength extraction
```

## Main Functions

### `transmissionFast.totalTransmission()` - Core Function
Calculate complete system transmission with automatic caching optimization.

**Flexible Interface Patterns:**
```matlab
% Automatic wavelength extraction (fastest for repeated calls)
Total = transmissionFast.totalTransmission();                    % Default config
Total = transmissionFast.totalTransmission([], Config);          % Custom config

% Explicit wavelength arrays (backward compatibility)
Lam = transmissionFast.utils.makeWavelengthArray(Config);
Total = transmissionFast.totalTransmission(Lam, Config);

% With pre-loaded absorption data (optimization loops)
AbsData = transmissionFast.data.loadAbsorptionData([], {}, false);
Total = transmissionFast.totalTransmission([], Config, 'AbsorptionData', AbsData);
```

### `transmissionFast.inputConfig()` - Configuration Management
Centralized configuration with built-in caching for parameters, absorption data, and wavelength arrays.

```matlab
% Available presets with automatic caching
Config = transmissionFast.inputConfig('default');           % Standard conditions
Config = transmissionFast.inputConfig('photometric_night'); % Excellent conditions  
Config = transmissionFast.inputConfig('humid_conditions');  % High humidity
Config = transmissionFast.inputConfig('high_altitude');     % High altitude site

% Config automatically contains cached wavelength array
fprintf('Cached wavelength points: %d\n', length(Config.WavelengthArray));
```

### `transmissionFast.calibratorWorkflow()` - Complete Calibrator Pipeline
One-stop function that performs the complete calibrator processing workflow with caching optimization.

```matlab
% Basic usage with automatic caching
totalFlux = transmissionFast.calibratorWorkflow();

% With custom configuration and plotting
Config = transmissionFast.inputConfig('photometric_night');
[totalFlux, SpecTrans, Wavelength, Metadata, Results] = ...
    transmissionFast.calibratorWorkflow(Config, 'PlotResults', true);

% Override catalog file and save results
totalFlux = transmissionFast.calibratorWorkflow([], ...
    'CatalogFile', '/path/to/catalog.fits', 'SaveResults', true);
```

### `transmissionFast.TransmissionOptimizer` - Multi-Stage Optimization
Comprehensive optimization system for calibrating transmission parameters using field calibrators.

```matlab
% Run full optimization sequence with caching
Config = transmissionFast.inputConfig();
optimizer = transmissionFast.TransmissionOptimizer(Config);
finalParams = optimizer.runFullSequence();

% Use optimized parameters for photometry
CatalogAB = transmissionFast.calculateAbsolutePhotometry(finalParams, Config);

% Get calibrator results with DiffMag
CalibratorTable = optimizer.getCalibratorResults();
```

### `transmissionFast.TransmissionOptimizerAdvanced` - Advanced Multi-Stage Optimization
Enhanced optimizer with support for mixed optimization algorithms and superior caching performance.

```matlab
% Run optimization with linear solver for field corrections
Config = transmissionFast.inputConfig();
optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config);
finalParams = optimizer.runFullSequence();

% Customize minimizer for specific stages
optimizer.setMinimizerForStage(3, 'linear');  % Use linear solver for stage 3

% Get results and visualize
CalibratorTable = optimizer.getCalibratorResults();
optimizer.plotResults();  % Visualize optimization progress
```

### `transmissionFast.calculateAbsolutePhotometry()` - AB Magnitude Calculation
Calculate absolute photometry using optimized transmission parameters with cached calculations.

```matlab
% Calculate AB magnitudes with optimized parameters
Config = transmissionFast.inputConfig();
optimizer = transmissionFast.TransmissionOptimizer(Config);
finalParams = optimizer.runFullSequence();
CatalogAB = transmissionFast.calculateAbsolutePhotometry(finalParams, Config);
```

### Cache Management Utilities
Utility functions to manage the multi-layer caching system:

```matlab
% Clear specific caches when needed
transmissionFast.utils.clearWavelengthCache();    % Clear wavelength array cache
transmissionFast.utils.clearInstrumentalCaches();  % Clear mirror/corrector caches
transmissionFast.utils.clearAirmassCaches();       % Clear airmass-dependent caches

% Get cache statistics
stats = transmissionFast.utils.getAirmassCacheStats();
fprintf('Cache hit rate: %.1f%%\n', stats.hitRate * 100);
```

### Individual Processing Functions

#### Calibrator Functions
```matlab
% Find Gaia calibrators around LAST sources (with caching)
[Spec, Mag, Coords, LASTData, Metadata] = transmissionFast.data.findCalibratorsWithCoords();

% Apply transmission to calibrator spectra (uses cached wavelength)
[SpecTrans, Wavelength, TransFunc] = ...
    transmissionFast.calibrators.applyTransmissionToCalibrators(Spec, Metadata, Config);

% Calculate total flux in photons
totalFlux = transmissionFast.calibrators.calculateTotalFluxCalibrators(...
    Wavelength, SpecTrans, Metadata);

% Find calibrators for AstroImage fields
[Spec, Mag, Coords, Metadata] = ...
    transmissionFast.data.findCalibratorsForAstroImage(AstroImageObject);
```

#### Optimization Functions
```matlab
% Nonlinear parameter optimization (fminsearch)
[OptimalParams, Fval, ExitFlag, Output, ResultData] = ...
    transmissionFast.minimizerFminGeneric(Config, ...
        'FreeParams', ["Norm_", "Center"], ...
        'SigmaClipping', true);

% Linear least squares optimization for field corrections
[OptimalParams, Fval] = transmissionFast.minimizerLinearLeastSquares(Config, ...
    'FreeParams', ["kx0", "kx", "ky", "kx2", "ky2", "kxy"], ...
    'SigmaClipping', true, ...
        'Regularization', 1e-6);

% Calculate cost function directly
[CostValue, Results] = transmissionFast.calculateCostFunction(Params, Config);
```

## Package Structure

```
+transmissionFast/
├── totalTransmission.m                 % Core total transmission with caching
├── inputConfig.m                       % Configuration management with 5-layer caching
├── calculateAbsolutePhotometry.m       % Absolute photometry calculations
├── calculateCostFunction.m             % Cost function for optimization
├── calibratorWorkflow.m                % Complete calibrator processing pipeline
├── TransmissionOptimizer.m             % Multi-stage optimization controller
├── TransmissionOptimizerAdvanced.m     % Advanced optimizer with mixed algorithms
├── minimizerFminGeneric.m              % Nonlinear optimization (fminsearch)
├── minimizerLinearLeastSquares.m       % Linear least squares solver
├── +atmospheric/
│   ├── atmosphericTransmission.m       % Total atmospheric transmission
│   ├── rayleighTransmission.m          % Rayleigh scattering
│   ├── aerosolTransmission.m           % Aerosol extinction
│   ├── ozoneTransmission.m             % Ozone absorption
│   ├── waterTransmittance.m            % Water vapor absorption
│   └── umgTransmittance.m              % Uniformly Mixed Gas transmission
├── +instrumental/
│   ├── otaTransmission.m               % Complete OTA transmission
│   ├── quantumEfficiency.m             % CCD quantum efficiency
│   ├── mirrorReflectance.m             % Mirror reflectivity with persistent cache
│   ├── correctorTransmission.m         % Corrector transmission with persistent cache
│   └── fieldCorrection.m               % Field-dependent corrections
├── +calibrators/
│   ├── applyTransmissionToCalibrators.m     % Apply transmission to Gaia spectra
│   └── calculateTotalFluxCalibrators.m      % Calculate total flux in photons
├── +data/
│   ├── findCalibratorsWithCoords.m     % Find Gaia calibrators around LAST sources
│   ├── findCalibratorsForAstroImage.m  % Find calibrators for AstroImage fields
│   └── loadAbsorptionData.m            % Load molecular absorption data
└── +utils/
    ├── makeWavelengthArray.m           % Wavelength array generation
    ├── skewedGaussianModel.m           % Skewed Gaussian model
    ├── legendreModel.m                 % Legendre polynomial model
    ├── chebyshevModel.m                % Chebyshev polynomial model
    ├── linearFieldCorrection.m         % Linear field correction model
    ├── evaluateChebyshevPolynomial.m   % Chebyshev polynomial evaluation
    ├── rescaleInputData.m              % Data rescaling utilities
    ├── airmassFromSMARTS.m             % Airmass calculation (SMARTS)
    └── sigmaClip.m                     % Sigma clipping for outliers
```


## Advanced Features

### 🎯 Automatic Wavelength Array Extraction
All functions now support automatic wavelength array extraction from cached memory:
```matlab
% Functions automatically use Config.WavelengthArray when Lam=[] or not provided
Total = transmissionFast.totalTransmission();                  % Uses cached wavelength
Atm = transmissionFast.atmospheric.atmosphericTransmission([], Config);
OTA = transmissionFast.instrumental.otaTransmission([], Config);
```

### ⚡ Persistent Function Caching  
Functions with expensive calculations cache results persistently:
- **mirrorReflectance**: Caches results for identical method/datafile/wavelength combinations
- **correctorTransmission**: Caches results for identical parameters
- Cache automatically invalidated when parameters change

### 📊 Function Interface Patterns
All functions support flexible parameter passing:
```matlab
% Pattern 1: Automatic wavelength extraction (fastest for repeated calls)
result = functionName();                    % Default config + cached wavelength  
result = functionName([], Config);          % Custom config + cached wavelength

% Pattern 2: Explicit parameters (backward compatibility)
result = functionName(Lam, Config);         % Explicit wavelength + config
result = functionName(Lam, Config, 'Key', Value);  % With additional arguments
```

### ✅ Physically Realistic Results
- All transmission values bounded to [0, 1]  
- Proper normalization of quantum efficiency
- Validated against reference data

### ✅ Comprehensive Atmospheric Modeling
- Rayleigh scattering (SMARTS model)
- Aerosol extinction with Ångström exponent
- Ozone absorption (UV and visible bands)
- Water vapor absorption (near-IR bands)  
- Uniformly Mixed Gases (O₂, CO₂, CH₄, etc.)
- Multiple atmospheric scenarios

### ✅ Accurate Instrumental Modeling
- CCD quantum efficiency (Skewed Gaussian × Legendre polynomials)
- Mirror reflectance (from instrumental data with persistent caching)
- Corrector transmission (from instrumental data with persistent caching)
- Field-dependent corrections (Chebyshev polynomials)

### ✅ Flexible Configuration System
- Predefined scenarios: `default`, `photometric_night`, `humid_conditions`, `high_altitude`, etc.
- Centralized parameter management with automatic caching
- Easy customization
- Optimization bounds management

### ✅ Calibrator Processing Pipeline
- Cross-matching LAST catalog sources with Gaia DR3 spectra
- Automatic magnitude filtering and duplicate removal
- Transmission application to Gaia spectra (336-1020 nm → 300-1100 nm)
- Total flux calculation in photons following Garrappa et al. 2025 methodology
- AB magnitude calculation with field-dependent corrections
- All functions leverage cached wavelength arrays for performance

### ✅ Advanced Optimization Capabilities
- **TransmissionOptimizer**: Standard 5-stage optimization workflow
- **TransmissionOptimizerAdvanced**: Mixed algorithm optimization (10-100× faster)
- **Linear solver** for field corrections with exact solutions
- **Sigma clipping** for robust outlier rejection
- **Cost function optimization** with cached transmission calculations
- **Full compatibility** with transmission package optimization workflows

## Optimization Workflow

The transmissionFast package includes the same powerful optimization capabilities as the transmission package, but with enhanced performance through caching:

### Standard Optimization (TransmissionOptimizer)
5-stage nonlinear optimization sequence with cached calculations:
```matlab
Config = transmissionFast.inputConfig();
optimizer = transmissionFast.TransmissionOptimizer(Config);

% Stage 1: Norm_ - Initial normalization with sigma clipping
% Stage 2: Norm_, Center - QE parameters optimization  
% Stage 3: Field corrections - Chebyshev coefficients (nonlinear)
% Stage 4: Norm_ - Refinement after field corrections
% Stage 5: Pwv_cm, Tau_aod500 - Atmospheric parameters

finalParams = optimizer.runFullSequence();
```

### Advanced Optimization (TransmissionOptimizerAdvanced)
Mixed algorithm approach with superior performance and caching benefits:
```matlab
Config = transmissionFast.inputConfig();
optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config);

% Stage 1: Norm_ - Initial normalization (nonlinear, sigma clipping)
% Stage 2: Norm_, Center - QE parameters (nonlinear)
% Stage 3: Field corrections - Chebyshev coefficients (LINEAR SOLVER)
% Stage 4: Norm_ - Refinement (nonlinear)
% Stage 5: Pwv_cm, Tau_aod500 - Atmospheric parameters (nonlinear)

finalParams = optimizer.runFullSequence();
```

**Performance advantages with transmissionFast:**
- **Cached transmission calculations**: No repeated file I/O during optimization
- **Wavelength array caching**: Automatic extraction from Config
- **10-100× faster** field correction optimization using linear solver
- **Persistent instrumental caching**: Mirror and corrector values cached
- **Pre-loaded absorption data**: Eliminates file reads in optimization loops

## Configuration Scenarios

| Scenario | Description | Key Parameters |
|----------|-------------|----------------|
| `default` | Standard observing conditions | PWV: 1.0 cm, AOD: 0.1 |
| `photometric_night` | Excellent conditions | PWV: 0.5 cm, AOD: 0.05 |
| `humid_conditions` | High humidity | PWV: 3.0 cm |
| `high_altitude` | High altitude site | Pressure: 610 mbar, PWV: 0.2 cm |
| `sea_level` | Sea level site | Pressure: 1013 mbar |
| `dusty_conditions` | High aerosol loading | AOD: 0.3 |

## Performance Benchmarks

### Caching Performance Gains
- **mirrorReflectance**: 124× faster on cached calls (0.8ms → 0.006ms)
- **correctorTransmission**: 18× faster on cached calls (0.9ms → 0.05ms)
- **Wavelength arrays**: Instant retrieval from `Config.WavelengthArray` 
- **Absorption data**: Single load per session (eliminates 336+ CSV reads)

### Calculation Performance
- **Calculation speed**: ~250 wavelength points/ms (typical hardware)
- **Memory efficient**: Vectorized operations throughout
- **Scalable**: Handles 401-10000+ wavelength points efficiently
- **Optimization ready**: Pre-loaded data eliminates I/O bottlenecks in loops

### Memory Usage Optimization
```matlab
% Efficient pattern for optimization loops
Config = transmissionFast.inputConfig('default');  % Loads and caches all data once
AbsData = transmissionFast.data.loadAbsorptionData([], {}, false);  % Pre-load once

for i = 1:1000  % Fast optimization loop
    Config.Atmospheric.Components.Aerosol.Tau_aod500 = tau_values(i);
    Total = transmissionFast.totalTransmission([], Config, 'AbsorptionData', AbsData);
    % No file I/O, no wavelength recalculation, uses all cached data
end
```

## Example Usage & Results

### Quick Performance Test
```matlab
% Test the new caching system
run('+transmissionFast/examples/totalTransmissionDemo.m');

% Test interface compatibility  
run('test_restored_interfaces.m');

% Test automatic wavelength array extraction
run('test_cached_wavelength_usage.m');
```

### Typical Results

**Default conditions (300-1100 nm, 401 points):**
- Peak transmission: ~53.2% at 518 nm
- Mean transmission: ~19.8% 
- Effective range: 336-1016 nm (>1% of peak)
- Calculation time: ~1.6ms (first call), ~0.1ms (cached calls)

**Instrumental only (no atmosphere):**
- Peak transmission: ~79.5% at 477 nm
- Mean transmission: ~31.8%
- Demonstrates ~38% atmospheric loss on average

**Performance with caching:**
- First call: Full calculation (~1.6ms)
- Cached calls: >100× faster (~0.01ms)
- Optimization loops: No I/O delays, uses pre-loaded data

## References

1. Garrappa et al. 2025, A&A 699, A50 - Transmission modeling methodology
2. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - CCD quantum efficiency parameters
3. Gueymard, C. A. (2019). Solar Energy, 187, 233-253 - SMARTS atmosphere model
4. Ofek et al. AstroPack: https://www.mathworks.com/matlabcentral/fileexchange/128984-astropack-maatv2

## Dependencies

- **MATLAB R2019b or later** (for arguments blocks)  
- **AstroPack** (for astronomical utilities and constants)
- **Statistics and Machine Learning Toolbox** (for polynomial fitting functions)

## Data Files

The package includes atmospheric absorption data and instrumental response data:
- Ozone absorption coefficients (UV and visible bands)
- Water vapor line data (near-IR absorption)
- Uniformly Mixed Gases (UMG) absorption data
- Mirror reflectance measurements (cached persistently)
- Corrector transmission data (cached persistently)

## Version History

- **v2.0** - Added 5-layer caching system and automatic wavelength array extraction
  - Persistent function-level caching for expensive calculations  
  - Automatic wavelength array extraction from `Config.WavelengthArray`
  - 124× performance improvement for mirror reflectance calculations
  - 18× performance improvement for corrector transmission calculations  
  - Eliminated redundant file I/O in optimization loops
  - Full backward compatibility maintained
  
- **v1.0** - Initial release with complete atmospheric and instrumental modeling

## Contact

For questions or issues, please contact D. Kovaleva or refer to the Garrappa et al. 2025 paper.

---

*For detailed examples and advanced usage, see the `examples/` directory and test files: `test_restored_interfaces.m` and `test_cached_wavelength_usage.m`*


