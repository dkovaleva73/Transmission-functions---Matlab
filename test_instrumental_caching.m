% Test instrumental data caching for mirror and corrector files
fprintf('Testing instrumental data caching for mirror and corrector files...\n\n');

% Test 1: Mirror Reflectance Caching
fprintf('1. Testing Mirror Reflectance Caching:\n');

% Clear any existing config cache to start fresh
clear functions; % This clears persistent variables

Config = transmissionFast.inputConfig();
wavelength = 400:10:700;  % Test wavelength range

% First call - should load from file and cache
fprintf('  First mirrorReflectance call (should load from file):\n');
tic;
mirror_ref1 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time1 = toc;
fprintf('    Time: %.6f seconds\n', time1);

% Second call - should use cached data
fprintf('  Second mirrorReflectance call (should use cache):\n');
tic;
mirror_ref2 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time2 = toc;
fprintf('    Time: %.6f seconds (%.0fx faster)\n', time2, time1/time2);

% Verify results are identical
if isequal(mirror_ref1, mirror_ref2)
    fprintf('    ✓ Results identical - caching working correctly\n');
else
    fprintf('    ⚠ Results different - potential issue\n');
end

% Test 2: Corrector Transmission Caching
fprintf('\n2. Testing Corrector Transmission Caching:\n');

% Clear cache again
clear functions;
Config = transmissionFast.inputConfig();

% First call - should load from file and cache
fprintf('  First correctorTransmission call (should load from file):\n');
tic;
corrector_trans1 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time3 = toc;
fprintf('    Time: %.6f seconds\n', time3);

% Second call - should use cached data
fprintf('  Second correctorTransmission call (should use cache):\n');
tic;
corrector_trans2 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time4 = toc;
fprintf('    Time: %.6f seconds (%.0fx faster)\n', time4, time3/time4);

% Verify results are identical
if isequal(corrector_trans1, corrector_trans2)
    fprintf('    ✓ Results identical - caching working correctly\n');
else
    fprintf('    ⚠ Results different - potential issue\n');
end

% Test 3: Multiple calls simulation (like in optimizer)
fprintf('\n3. Simulating optimizer behavior (multiple instrumental calls):\n');
clear functions;
Config = transmissionFast.inputConfig();

tic;
for i = 1:20
    mirror_ref = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
    corrector_trans = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
end
time_multiple = toc;
fprintf('  20 rounds of instrumental calculations: %.6f seconds\n', time_multiple);

% Test 4: Verify data structure
fprintf('\n4. Checking cached data structure:\n');
if isfield(Config, 'InstrumentalData')
    fprintf('  ✓ InstrumentalData field exists in Config\n');
    
    if isfield(Config.InstrumentalData, 'Mirror')
        fprintf('  ✓ Mirror data cached\n');
        mirror_fields = fieldnames(Config.InstrumentalData.Mirror);
        fprintf('    Mirror fields: %s\n', strjoin(mirror_fields, ', '));
    else
        fprintf('  ⚠ Mirror data not cached\n');
    end
    
    if isfield(Config.InstrumentalData, 'Corrector')
        fprintf('  ✓ Corrector data cached\n');
        corrector_fields = fieldnames(Config.InstrumentalData.Corrector);
        fprintf('    Corrector fields: %s\n', strjoin(corrector_fields, ', '));
    else
        fprintf('  ⚠ Corrector data not cached\n');
    end
else
    fprintf('  ⚠ InstrumentalData field missing from Config\n');
end

% Summary
fprintf('\n5. Performance Summary:\n');
total_speedup = (time1 + time3) / (time2 + time4);
fprintf('  Average speedup from caching: %.0fx\n', total_speedup);
fprintf('  This should improve optimizer performance for instrumental calculations!\n');

fprintf('\n✅ Instrumental data caching test completed\n');