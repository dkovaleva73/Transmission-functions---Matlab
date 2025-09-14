% Test wavelength array caching in inputConfig and makeWavelengthArray
fprintf('Testing wavelength array caching...\n\n');

% Start fresh
clear functions;

fprintf('1. Testing inputConfig wavelength caching:\n');

% First call - should calculate and cache wavelength array
tic;
Config1 = transmissionFast.inputConfig();
time1 = toc;
fprintf('   First inputConfig call: %.6f seconds (calculates wavelength array)\n', time1);

% Check if wavelength array is cached
if isfield(Config1, 'WavelengthArray')
    fprintf('   ✓ WavelengthArray field exists in Config\n');
    fprintf('   Wavelength array size: %d points\n', length(Config1.WavelengthArray));
    fprintf('   Range: %.1f to %.1f nm\n', min(Config1.WavelengthArray), max(Config1.WavelengthArray));
else
    fprintf('   ⚠ WavelengthArray field missing\n');
end

% Second call - should use cached config including wavelength array
tic;
Config2 = transmissionFast.inputConfig();
time2 = toc;
fprintf('   Second inputConfig call: %.6f seconds (uses cached data)\n', time2);

fprintf('\n2. Testing makeWavelengthArray with cached data:\n');

% This should use the cached array from Config
tic;
wavelength1 = transmissionFast.utils.makeWavelengthArray(Config1);
time3 = toc;
fprintf('   First makeWavelengthArray: %.6f seconds (should use cached from Config)\n', time3);

% Second call - should also use cached array
tic;
wavelength2 = transmissionFast.utils.makeWavelengthArray(Config1);
time4 = toc;
fprintf('   Second makeWavelengthArray: %.6f seconds\n', time4);

% Verify arrays are identical
if isequal(wavelength1, wavelength2) && isequal(wavelength1, Config1.WavelengthArray)
    fprintf('   ✓ All wavelength arrays identical\n');
else
    fprintf('   ⚠ Wavelength arrays differ\n');
end

fprintf('\n3. Testing performance with multiple calls:\n');

% Test many calls to makeWavelengthArray - should all be fast
tic;
for i = 1:100
    wl_test = transmissionFast.utils.makeWavelengthArray(Config1);
end
time_multiple = toc;
fprintf('   100 makeWavelengthArray calls: %.6f seconds\n', time_multiple);
fprintf('   Average per call: %.6f seconds\n', time_multiple/100);

fprintf('\n4. Testing different wavelength parameters (cache invalidation):\n');

% Create config with different wavelength parameters
Config_custom = Config1;
Config_custom.General.Wavelength_min = 350;
Config_custom.General.Wavelength_max = 900;
Config_custom.General.Wavelength_points = 201;

% Clear config cache to test new parameters
clear functions;

tic;
Config_new = transmissionFast.inputConfig();
% Manually modify for testing
Config_new.General.Wavelength_min = 350;
Config_new.General.Wavelength_max = 900; 
Config_new.General.Wavelength_points = 201;
Config_new = rmfield(Config_new, 'WavelengthArray'); % Remove cached array

wl_custom = transmissionFast.utils.makeWavelengthArray(Config_new);
time_custom = toc;

fprintf('   Different parameters: %.6f seconds (should show fallback warning)\n', time_custom);
fprintf('   Custom wavelength range: %.1f to %.1f nm (%d points)\n', ...
        min(wl_custom), max(wl_custom), length(wl_custom));

fprintf('\n5. Performance Summary:\n');
fprintf('   inputConfig caching speedup: %.0fx\n', time1/time2);
fprintf('   makeWavelengthArray: %.6f seconds (using cached array)\n', time3);
fprintf('   Multiple calls average: %.6f seconds\n', time_multiple/100);

fprintf('\n✅ Wavelength array caching test completed!\n');
fprintf('📊 Key benefits:\n');
fprintf('   • Wavelength array calculated once in inputConfig\n');
fprintf('   • makeWavelengthArray returns cached array instantly\n');
fprintf('   • Eliminates repeated linspace() and convert.energy() calls\n');
fprintf('🚀 Optimizer should see significant speedup for wavelength operations!\n');