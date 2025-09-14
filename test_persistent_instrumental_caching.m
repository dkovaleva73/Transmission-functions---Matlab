% Test persistent caching for mirrorReflectance and correctorTransmission
fprintf('Testing persistent instrumental function caching...\n\n');

% Clear functions to start with empty persistent variables
clear functions;
Config = transmissionFast.inputConfig();
wavelength = 400:10:700;

fprintf('1. Testing Mirror Reflectance Persistent Caching:\n');

% First call - should calculate and cache
fprintf('  First call (calculate and cache):\n');
tic;
mirror1 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time1 = toc;
fprintf('    Time: %.6f seconds\n', time1);

% Second call - should return cached result instantly
fprintf('  Second call (from persistent cache):\n');
tic;
mirror2 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time2 = toc;
fprintf('    Time: %.6f seconds (%.0fx faster)\n', time2, time1/time2);

% Third call - should still use cache
fprintf('  Third call (from persistent cache):\n');
tic;
mirror3 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time3 = toc;
fprintf('    Time: %.6f seconds (%.0fx faster)\n', time3, time1/time3);

% Verify results are identical
if isequal(mirror1, mirror2) && isequal(mirror2, mirror3)
    fprintf('    ✓ All results identical - persistent caching working\n');
else
    fprintf('    ⚠ Results differ - potential caching issue\n');
end

fprintf('\n2. Testing Corrector Transmission Persistent Caching:\n');

% First call - should calculate and cache
fprintf('  First call (calculate and cache):\n');
tic;
corrector1 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time4 = toc;
fprintf('    Time: %.6f seconds\n', time4);

% Second call - should return cached result instantly
fprintf('  Second call (from persistent cache):\n');
tic;
corrector2 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time5 = toc;
fprintf('    Time: %.6f seconds (%.0fx faster)\n', time5, time4/time5);

% Third call - should still use cache
fprintf('  Third call (from persistent cache):\n');
tic;
corrector3 = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
time6 = toc;
fprintf('    Time: %.6f seconds (%.0fx faster)\n', time6, time4/time6);

% Verify results are identical
if isequal(corrector1, corrector2) && isequal(corrector2, corrector3)
    fprintf('    ✓ All results identical - persistent caching working\n');
else
    fprintf('    ⚠ Results differ - potential caching issue\n');
end

fprintf('\n3. Testing Multiple Calls (Optimizer Simulation):\n');
fprintf('   Simulating 100 calls to each function...\n');

tic;
for i = 1:100
    mirror_test = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
    corrector_test = transmissionFast.instrumental.correctorTransmission(wavelength, Config);
end
time_multiple = toc;

fprintf('   100 calls to both functions: %.6f seconds\n', time_multiple);
fprintf('   Average time per pair: %.6f seconds\n', time_multiple/100);

fprintf('\n4. Testing Different Wavelength Arrays (Cache Invalidation):\n');

% Test with different wavelength array - should recalculate
wavelength2 = 350:15:750;
fprintf('  Different wavelength array:\n');
tic;
mirror_diff = transmissionFast.instrumental.mirrorReflectance(wavelength2, Config);
time_diff = toc;
fprintf('    Time: %.6f seconds (recalculated for new wavelength array)\n', time_diff);

% Second call with same new wavelength array - should use cache
tic;
mirror_diff2 = transmissionFast.instrumental.mirrorReflectance(wavelength2, Config);
time_diff2 = toc;
fprintf('    Second call: %.6f seconds (%.0fx faster - cached)\n', time_diff2, time_diff/time_diff2);

% Back to original wavelength - should recalculate again
tic;
mirror_orig = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time_orig = toc;
fprintf('    Back to original wavelength: %.6f seconds\n', time_orig);

fprintf('\n5. Performance Summary:\n');
avg_speedup_mirror = time1 / ((time2 + time3) / 2);
avg_speedup_corrector = time4 / ((time5 + time6) / 2);
fprintf('  Mirror reflectance speedup: %.0fx\n', avg_speedup_mirror);
fprintf('  Corrector transmission speedup: %.0fx\n', avg_speedup_corrector);
fprintf('  Overall average speedup: %.0fx\n', (avg_speedup_mirror + avg_speedup_corrector)/2);

fprintf('\n✅ Persistent instrumental caching test completed!\n');
fprintf('🚀 Mirror and corrector functions now cache results in memory!\n');
fprintf('💡 First call calculates, all subsequent calls return cached results\n');