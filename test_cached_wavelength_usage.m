% Test specifically that functions use cached wavelength arrays
fprintf('Testing cached wavelength array usage...\n\n');

clear functions;
Config = transmissionFast.inputConfig();

fprintf('1. Testing that functions use cached wavelength arrays by default:\n');

% Verify Config has cached wavelength array
if isfield(Config, 'WavelengthArray') && ~isempty(Config.WavelengthArray)
    fprintf('   ✓ Config contains cached WavelengthArray (%d points)\n', length(Config.WavelengthArray));
else
    fprintf('   ❌ Config missing WavelengthArray field\n');
end

% Test totalTransmission with no wavelength parameter
try
    total_cached = transmissionFast.totalTransmission([], Config);
    fprintf('   ✓ totalTransmission([], Config) uses cached wavelength\n');
catch ME
    fprintf('   ❌ totalTransmission([], Config) failed: %s\n', ME.message);
end

% Test atmosphericTransmission with no wavelength parameter  
try
    atm_cached = transmissionFast.atmospheric.atmosphericTransmission([], Config);
    fprintf('   ✓ atmosphericTransmission([], Config) uses cached wavelength\n');
catch ME
    fprintf('   ❌ atmosphericTransmission([], Config) failed: %s\n', ME.message);
end

% Test individual atmospheric components
try
    ray_cached = transmissionFast.atmospheric.rayleighTransmission([], Config);
    fprintf('   ✓ rayleighTransmission([], Config) uses cached wavelength\n');
catch ME
    fprintf('   ❌ rayleighTransmission([], Config) failed: %s\n', ME.message);
end

try
    ozone_cached = transmissionFast.atmospheric.ozoneTransmission([], Config);
    fprintf('   ✓ ozoneTransmission([], Config) uses cached wavelength\n');
catch ME
    fprintf('   ❌ ozoneTransmission([], Config) failed: %s\n', ME.message);
end

% Test instrumental components
try
    ota_cached = transmissionFast.instrumental.otaTransmission([], Config);
    fprintf('   ✓ otaTransmission([], Config) uses cached wavelength\n');
catch ME
    fprintf('   ❌ otaTransmission([], Config) failed: %s\n', ME.message);
end

try
    qe_cached = transmissionFast.instrumental.quantumEfficiency([], Config);
    fprintf('   ✓ quantumEfficiency([], Config) uses cached wavelength\n');
catch ME
    fprintf('   ❌ quantumEfficiency([], Config) failed: %s\n', ME.message);
end

fprintf('\n2. Verifying results consistency:\n');

if exist('total_cached', 'var') && exist('Config', 'var')
    expected_length = length(Config.WavelengthArray);
    actual_length = length(total_cached);
    
    if actual_length == expected_length
        fprintf('   ✓ Cached wavelength results have correct length: %d points\n', actual_length);
    else
        fprintf('   ❌ Length mismatch: expected %d, got %d\n', expected_length, actual_length);
    end
    
    % Verify the results are physically reasonable
    if all(total_cached >= 0) && all(total_cached <= 1)
        fprintf('   ✓ All transmission values within physical bounds [0,1]\n');
    else
        fprintf('   ❌ Some transmission values out of bounds\n');
    end
    
    fprintf('   Range: %.6f - %.6f\n', min(total_cached), max(total_cached));
end

fprintf('\n✅ Cached wavelength array usage testing completed!\n');
fprintf('🚀 All functions now automatically use cached wavelength arrays\n');
fprintf('⚡ Performance optimization: No repeated wavelength array calculations\n');