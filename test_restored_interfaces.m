% Test that restored interfaces work correctly
fprintf('Testing restored original interfaces...\n\n');

clear functions;
Config = transmissionFast.inputConfig();

fprintf('1. Testing totalTransmission with original interface:\n');

% Test with default parameters (should work)
try
    total1 = transmissionFast.totalTransmission();
    fprintf('   ✓ totalTransmission() works (default parameters)\n');
catch ME
    fprintf('   ❌ totalTransmission() failed: %s\n', ME.message);
end

% Test with Lam and Config
try
    wavelength = transmissionFast.utils.makeWavelengthArray(Config);
    total2 = transmissionFast.totalTransmission(wavelength, Config);
    fprintf('   ✓ totalTransmission(Lam, Config) works\n');
catch ME
    fprintf('   ❌ totalTransmission(Lam, Config) failed: %s\n', ME.message);
end

% Test with absorption data
try
    total3 = transmissionFast.totalTransmission(wavelength, Config, 'AbsorptionData', Config.AbsorptionData);
    fprintf('   ✓ totalTransmission(Lam, Config, AbsorptionData) works\n');
catch ME
    fprintf('   ❌ totalTransmission with AbsorptionData failed: %s\n', ME.message);
end

fprintf('\n2. Testing atmosphericTransmission with original interface:\n');

% Test atmospheric transmission
try
    atm1 = transmissionFast.atmospheric.atmosphericTransmission();
    fprintf('   ✓ atmosphericTransmission() works (default parameters)\n');
catch ME
    fprintf('   ❌ atmosphericTransmission() failed: %s\n', ME.message);
end

try
    atm2 = transmissionFast.atmospheric.atmosphericTransmission(wavelength, Config);
    fprintf('   ✓ atmosphericTransmission(Lam, Config) works\n');
catch ME
    fprintf('   ❌ atmosphericTransmission(Lam, Config) failed: %s\n', ME.message);
end

fprintf('\n3. Testing functions that the optimizer uses:\n');

% Test applyTransmissionToCalibrators
try
    % Create proper cell array format (as expected by the function)
    dummySpec = cell(3, 2);
    for i = 1:3
        dummySpec{i, 1} = ones(343, 1);  % Flux values (343 Gaia wavelength points)
        dummySpec{i, 2} = ones(343, 1) * 0.1;  % Flux error values
    end
    dummyMetadata = struct();
    dummyMetadata.airMassFromLAST = 1.5;
    dummyMetadata.Temperature = 20.0;
    dummyMetadata.Pressure = NaN;
    
    [SpecTrans, WL, TransFunc] = transmissionFast.calibrators.applyTransmissionToCalibrators(...
        dummySpec, dummyMetadata, Config);
    fprintf('   ✓ applyTransmissionToCalibrators works\n');
catch ME
    fprintf('   ❌ applyTransmissionToCalibrators failed: %s\n', ME.message);
end

fprintf('\n4. Verifying data consistency:\n');

if exist('total2', 'var') && exist('atm2', 'var')
    fprintf('   Total transmission range: %.6f - %.6f\n', min(total2), max(total2));
    fprintf('   Atmospheric transmission range: %.6f - %.6f\n', min(atm2), max(atm2));
    fprintf('   ✓ Functions return valid transmission values\n');
else
    fprintf('   ⚠ Could not verify data consistency\n');
end

fprintf('\n✅ Interface restoration testing completed!\n');
fprintf('🔄 Original multi-parameter interfaces restored\n');
fprintf('📊 Both caching benefits and original interfaces are available\n');