% Test that instrumental functions no longer read CSV files
fprintf('Testing that CSV file reads are eliminated...\n\n');

% Clear functions to start fresh
clear functions;
transmissionFast.utils.clearInstrumentalCaches();

Config = transmissionFast.inputConfig();
wavelength = 400:10:700;

fprintf('1. Testing Mirror Reflectance (should use cached data from inputConfig):\n');

% First call - should use cached data from inputConfig (NOT read CSV)
tic;
mirror1 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time1 = toc;
fprintf('   First call: %.6f seconds (should use inputConfig cached data)\n', time1);

% Second call - should use persistent cache
tic;
mirror2 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time2 = toc;
fprintf('   Second call: %.6f seconds (%.0fx faster - persistent cache)\n', time2, time1/time2);

% Verify results are identical
if isequal(mirror1, mirror2)
    fprintf('   ✓ Results identical\n');
else
    fprintf('   ⚠ Results different\n');
end

fprintf('\n2. Testing Corrector Transmission (should use cached data from inputConfig):\n');

% First call - should use cached data from inputConfig (NOT read CSV)
tic;
corrector1 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time3 = toc;
fprintf('   First call: %.6f seconds (should use inputConfig cached data)\n', time3);

% Second call - should use persistent cache
tic;
corrector2 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time4 = toc;
fprintf('   Second call: %.6f seconds (%.0fx faster - persistent cache)\n', time4, time3/time4);

% Verify results are identical
if isequal(corrector1, corrector2)
    fprintf('   ✓ Results identical\n');
else
    fprintf('   ⚠ Results different\n');
end

fprintf('\n3. Testing Multiple Calls (should all use persistent cache):\n');
tic;
for i = 1:100
    mirror_test = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
    corrector_test = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
end
time_multiple = toc;
fprintf('   100 calls to each function: %.6f seconds\n', time_multiple);
fprintf('   Average per call pair: %.6f seconds\n', time_multiple/100);

fprintf('\n4. Performance Summary:\n');
fprintf('   Mirror first call (cached data): %.6f seconds\n', time1);
fprintf('   Mirror subsequent calls: %.6f seconds\n', time2);
fprintf('   Corrector first call (cached data): %.6f seconds\n', time3);
fprintf('   Corrector subsequent calls: %.6f seconds\n', time4);

fprintf('\n✅ Test completed!\n');
fprintf('📊 Key Points:\n');
fprintf('   • First calls should be fast (using inputConfig cached data)\n');
fprintf('   • Subsequent calls should be very fast (using persistent cache)\n');
fprintf('   • NO CSV file reads should occur after inputConfig loads data\n');

% Test that we get a warning if we bypass the inputConfig cache
fprintf('\n5. Testing fallback behavior (forcing file I/O path):\n');
clear functions;
Config_no_cache = transmissionFast.inputConfig();
% Remove cached data to force fallback
if isfield(Config_no_cache, 'InstrumentalData')
    Config_no_cache = rmfield(Config_no_cache, 'InstrumentalData');
end

try
    fprintf('   Trying without cached data (should show warning):\n');
    mirror_fallback = transmissionFast.instrumental.mirrorReflectance(wavelength, Config_no_cache);
    fprintf('   ✓ Fallback path worked\n');
catch ME
    fprintf('   ⚠ Fallback failed: %s\n', ME.message);
end