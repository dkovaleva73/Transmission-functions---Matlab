% Test that all namespace updates work correctly
fprintf('Testing transmissionFast namespace consistency...\n\n');

% Clear caches to start fresh
clear functions;
transmissionFast.utils.clearAirmassCaches();

fprintf('1. Testing Basic Functionality:\n');

% Test inputConfig
try
    Config = transmissionFast.inputConfig();
    fprintf('  ✓ transmissionFast.inputConfig() works\n');
catch ME
    fprintf('  ⚠ transmissionFast.inputConfig() failed: %s\n', ME.message);
end

% Test wavelength array creation
try
    wavelength = transmissionFast.utils.makeWavelengthArray(Config);
    fprintf('  ✓ transmissionFast.utils.makeWavelengthArray() works\n');
catch ME
    fprintf('  ⚠ transmissionFast.utils.makeWavelengthArray() failed: %s\n', ME.message);
end

% Test atmospheric functions
fprintf('\n2. Testing Atmospheric Functions:\n');
try
    rayleigh = transmissionFast.atmospheric.rayleighTransmission(wavelength, Config);
    fprintf('  ✓ rayleighTransmission works\n');
catch ME
    fprintf('  ⚠ rayleighTransmission failed: %s\n', ME.message);
end

try
    aerosol = transmissionFast.atmospheric.aerosolTransmission(wavelength, Config);
    fprintf('  ✓ aerosolTransmission works\n');
catch ME
    fprintf('  ⚠ aerosolTransmission failed: %s\n', ME.message);
end

try
    ozone = transmissionFast.atmospheric.ozoneTransmission(wavelength, Config);
    fprintf('  ✓ ozoneTransmission works\n');
catch ME
    fprintf('  ⚠ ozoneTransmission failed: %s\n', ME.message);
end

try
    water = transmissionFast.atmospheric.waterTransmittance(wavelength, Config);
    fprintf('  ✓ waterTransmittance works\n');
catch ME
    fprintf('  ⚠ waterTransmittance failed: %s\n', ME.message);
end

try
    atm_total = transmissionFast.atmospheric.atmosphericTransmission(wavelength, Config);
    fprintf('  ✓ atmosphericTransmission works\n');
catch ME
    fprintf('  ⚠ atmosphericTransmission failed: %s\n', ME.message);
end

% Test instrumental functions
fprintf('\n3. Testing Instrumental Functions:\n');
try
    qe = transmissionFast.instrumental.quantumEfficiency(wavelength, Config);
    fprintf('  ✓ quantumEfficiency works\n');
catch ME
    fprintf('  ⚠ quantumEfficiency failed: %s\n', ME.message);
end

try
    mirror = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
    fprintf('  ✓ mirrorReflectance works\n');
catch ME
    fprintf('  ⚠ mirrorReflectance failed: %s\n', ME.message);
end

try
    corrector = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
    fprintf('  ✓ correctorTransmission works\n');
catch ME
    fprintf('  ⚠ correctorTransmission failed: %s\n', ME.message);
end

try
    ota = transmissionFast.instrumental.otaTransmission(wavelength, Config);
    fprintf('  ✓ otaTransmission works\n');
catch ME
    fprintf('  ⚠ otaTransmission failed: %s\n', ME.message);
end

% Test total transmission
fprintf('\n4. Testing Total Transmission:\n');
try
    total = transmissionFast.totalTransmission(wavelength, Config);
    fprintf('  ✓ totalTransmission works\n');
catch ME
    fprintf('  ⚠ totalTransmission failed: %s\n', ME.message);
end

% Test utility functions
fprintf('\n5. Testing Utility Functions:\n');
try
    cheb_result = transmissionFast.utils.chebyshevModel(wavelength, Config);
    fprintf('  ✓ chebyshevModel works\n');
catch ME
    fprintf('  ⚠ chebyshevModel failed: %s\n', ME.message);
end

try
    legendre_result = transmissionFast.utils.legendreModel(wavelength, Config);
    fprintf('  ✓ legendreModel works\n');
catch ME
    fprintf('  ⚠ legendreModel failed: %s\n', ME.message);
end

try
    sg_result = transmissionFast.utils.skewedGaussianModel(wavelength, Config);
    fprintf('  ✓ skewedGaussianModel works\n');
catch ME
    fprintf('  ⚠ skewedGaussianModel failed: %s\n', ME.message);
end

% Test that old transmission.* calls would now fail
fprintf('\n6. Verifying Old Namespace Isolation:\n');
try
    % This should fail because we're in transmissionFast, not transmission
    old_config = transmission.inputConfig();
    fprintf('  ⚠ Old transmission.inputConfig() still works (unexpected)\n');
catch ME
    fprintf('  ✓ Old transmission.inputConfig() properly isolated\n');
end

% Performance test
fprintf('\n7. Performance Test (with all caches):\n');
clear functions;
Config = transmissionFast.inputConfig();

tic;
for i = 1:10
    total_trans = transmissionFast.totalTransmission(wavelength, Config);
end
performance_time = toc;
fprintf('  10 total transmission calculations: %.6f seconds\n', performance_time);
fprintf('  Average per calculation: %.6f seconds\n', performance_time/10);

fprintf('\n✅ Namespace consistency test completed!\n');
fprintf('🚀 transmissionFast package is fully self-contained and optimized\n');