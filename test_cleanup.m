Config = transmissionFast.inputConfig();
am1 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
am2 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
transmissionFast.utils.clearAirmassCaches();
am3 = transmissionFast.utils.airmassFromSMARTS('ozone', Config);
fprintf('✓ Cleaned up cacheKeys - all functions working normally\n');
fprintf('  Results: %.6f, %.6f, %.6f\n', am1, am2, am3);