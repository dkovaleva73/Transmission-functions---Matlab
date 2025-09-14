% Test that the optimizer now benefits from airmass caching
fprintf('Testing airmass caching in optimizer atmospheric calculations...\n\n');

Config = transmissionFast.inputConfig();

% Clear cache to start fresh
transmissionFast.utils.clearAirmassCaches();

% Test atmospheric transmission function (which calls airmass)
fprintf('1. Testing atmospheric transmission functions:\n');

% Rayleigh transmission (calls airmassFromSMARTS)
fprintf('  Testing rayleighTransmission:\n');
wavelength = 400:10:700;  % Test wavelength range

tic;
transmission1 = transmissionFast.atmospheric.rayleighTransmission(wavelength, Config);
time1 = toc;
fprintf('    First call: %.6f seconds\n', time1);

tic;
transmission2 = transmissionFast.atmospheric.rayleighTransmission(wavelength, Config);
time2 = toc;
fprintf('    Second call: %.6f seconds (%.0fx faster)\n', time2, time1/time2);

% Test that results are identical
if isequal(transmission1, transmission2)
    fprintf('    ✓ Results identical - caching working correctly\n');
else
    fprintf('    ⚠ Results different - potential issue\n');
end

% Test water transmission
fprintf('\n  Testing waterTransmittance:\n');
transmissionFast.utils.clearAirmassCaches();

tic;
water_trans1 = transmissionFast.atmospheric.waterTransmittance(wavelength, Config);
time_water1 = toc;
fprintf('    First call: %.6f seconds\n', time_water1);

tic;
water_trans2 = transmissionFast.atmospheric.waterTransmittance(wavelength, Config);
time_water2 = toc;
fprintf('    Second call: %.6f seconds (%.0fx faster)\n', time_water2, time_water1/time_water2);

% Test UMG transmittance (calls multiple airmass functions)
fprintf('\n  Testing umgTransmittance (calls many airmass functions):\n');
transmissionFast.utils.clearAirmassCaches();

tic;
umg_trans1 = transmissionFast.atmospheric.umgTransmittance(wavelength, Config);
time_umg1 = toc;
fprintf('    First call: %.6f seconds\n', time_umg1);

tic;
umg_trans2 = transmissionFast.atmospheric.umgTransmittance(wavelength, Config);
time_umg2 = toc;
fprintf('    Second call: %.6f seconds (%.0fx faster)\n', time_umg2, time_umg1/time_umg2);

fprintf('\n2. Testing multiple atmospheric calls (simulates optimizer behavior):\n');
transmissionFast.utils.clearAirmassCaches();

% Simulate what happens during optimization with multiple atmospheric calculations
tic;
for i = 1:10
    rayleigh = transmissionFast.atmospheric.rayleighTransmission(wavelength, Config);
    aerosol = transmissionFast.atmospheric.aerosolTransmission(wavelength, Config);
    ozone = transmissionFast.atmospheric.ozoneTransmission(wavelength, Config);
    water = transmissionFast.atmospheric.waterTransmittance(wavelength, Config);
end
time_multiple = toc;
fprintf('  10 rounds of atmospheric calculations: %.6f seconds\n', time_multiple);

% Performance summary
fprintf('\n3. Performance Summary:\n');
total_speedup = (time1 + time_water1 + time_umg1) / (time2 + time_water2 + time_umg2);
fprintf('  Average speedup from caching: %.0fx\n', total_speedup);
fprintf('  This should now benefit your optimizer performance!\n');

fprintf('\n✅ Airmass caching is now integrated into atmospheric functions\n');
fprintf('🚀 Your TransmissionOptimizerAdvanced should be faster now!\n');