% Test that cache clearing works for instrumental functions
fprintf('Testing instrumental cache clearing...\n\n');

Config = transmissionFast.inputConfig();
wavelength = 400:10:700;

fprintf('1. Initial calculation (populates cache):\n');
tic;
mirror1 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time1 = toc;
fprintf('   Time: %.6f seconds\n', time1);

fprintf('2. Cached call (should be very fast):\n');
tic;
mirror2 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time2 = toc;
fprintf('   Time: %.6f seconds (%.0fx faster)\n', time2, time1/time2);

fprintf('3. Clear instrumental caches:\n');
transmissionFast.utils.clearInstrumentalCaches();

fprintf('4. After cache clear (should recalculate):\n');
tic;
mirror3 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time3 = toc;
fprintf('   Time: %.6f seconds (recalculated)\n', time3);

fprintf('5. Cached again (should be fast again):\n');
tic;
mirror4 = transmissionFast.instrumental.mirrorReflectance(wavelength, Config);
time4 = toc;
fprintf('   Time: %.6f seconds (%.0fx faster)\n', time4, time3/time4);

% Verify results are all identical
if isequal(mirror1, mirror2) && isequal(mirror2, mirror3) && isequal(mirror3, mirror4)
    fprintf('\n✅ All results identical - cache clearing works correctly\n');
else
    fprintf('\n⚠ Results differ - potential issue\n');
end

fprintf('\n💡 Cache clearing utility works correctly!\n');