% Test performance of new _am atmospheric transmission modules
fprintf('=== TESTING _AM MODULES PERFORMANCE ===\n\n');

% Setup
Config = transmissionFast.inputConfig();
Lam = transmissionFast.utils.makeWavelengthArray(Config);
zenithAngle = 55.18;
N_tests = 100;

fprintf('Testing with %d wavelength points, %d iterations...\n\n', length(Lam), N_tests);

%% Test Rayleigh Transmission
fprintf('1. RAYLEIGH TRANSMISSION:\n');

% Original version (with caching)
transmissionFast.utils.airmassFromSMARTS('clearcache');
tic;
for i = 1:N_tests
    Trans_orig = transmissionFast.atmospheric.rayleighTransmission(Lam, Config);
end
time_rayleigh_orig = toc;

% New _am version (direct calculation)
tic;
for i = 1:N_tests
    Trans_am = transmissionFast.atmospheric.rayleighTransmission_am(Lam, zenithAngle, ...
                Config.Atmospheric.Pressure_mbar, Config.Data.Wave_units);
end
time_rayleigh_am = toc;

% Accuracy check
accuracy_rayleigh = max(abs(Trans_orig - Trans_am));
speedup_rayleigh = time_rayleigh_orig / time_rayleigh_am;

fprintf('  Original: %.1f ms, _am: %.1f ms\n', time_rayleigh_orig*1000, time_rayleigh_am*1000);
fprintf('  Speedup: %.1fx, Max difference: %.2e\n', speedup_rayleigh, accuracy_rayleigh);

%% Test Aerosol Transmission  
fprintf('\n2. AEROSOL TRANSMISSION:\n');

% Original version
transmissionFast.utils.airmassFromSMARTS('clearcache');
tic;
for i = 1:N_tests
    Trans_orig = transmissionFast.atmospheric.aerosolTransmission(Lam, Config);
end
time_aerosol_orig = toc;

% New _am version
tic;
for i = 1:N_tests
    Trans_am = transmissionFast.atmospheric.aerosolTransmission_am(Lam, zenithAngle, ...
                Config.Atmospheric.Components.Aerosol.Tau_aod500, Config.Atmospheric.Components.Aerosol.Angstrom_exponent, Config.Data.Wave_units);
end
time_aerosol_am = toc;

accuracy_aerosol = max(abs(Trans_orig - Trans_am));
speedup_aerosol = time_aerosol_orig / time_aerosol_am;

fprintf('  Original: %.1f ms, _am: %.1f ms\n', time_aerosol_orig*1000, time_aerosol_am*1000);
fprintf('  Speedup: %.1fx, Max difference: %.2e\n', speedup_aerosol, accuracy_aerosol);

%% Test Ozone Transmission
fprintf('\n3. OZONE TRANSMISSION:\n');

% Original version  
transmissionFast.utils.airmassFromSMARTS('clearcache');
tic;
for i = 1:N_tests
    Trans_orig = transmissionFast.atmospheric.ozoneTransmission(Lam, Config);
end
time_ozone_orig = toc;

% New _am version
tic;
for i = 1:N_tests
    Trans_am = transmissionFast.atmospheric.ozoneTransmission_am(Lam, zenithAngle, ...
                Config.Atmospheric.Components.Ozone.Dobson_units, Config.Data.Wave_units);
end
time_ozone_am = toc;

accuracy_ozone = max(abs(Trans_orig - Trans_am));
speedup_ozone = time_ozone_orig / time_ozone_am;

fprintf('  Original: %.1f ms, _am: %.1f ms\n', time_ozone_orig*1000, time_ozone_am*1000);
fprintf('  Speedup: %.1fx, Max difference: %.2e\n', speedup_ozone, accuracy_ozone);

%% Test Water Transmission
fprintf('\n4. WATER TRANSMISSION:\n');

% Original version
transmissionFast.utils.airmassFromSMARTS('clearcache'); 
tic;
for i = 1:N_tests
    Trans_orig = transmissionFast.atmospheric.waterTransmittance(Lam, Config);
end
time_water_orig = toc;

% New _am version
tic;
for i = 1:N_tests
    Trans_am = transmissionFast.atmospheric.waterTransmittance_am(Lam, zenithAngle, ...
                Config.Atmospheric.Components.Water.Pwv_cm, Config.Data.Wave_units);
end
time_water_am = toc;

accuracy_water = max(abs(Trans_orig - Trans_am));
speedup_water = time_water_orig / time_water_am;

fprintf('  Original: %.1f ms, _am: %.1f ms\n', time_water_orig*1000, time_water_am*1000);
fprintf('  Speedup: %.1fx, Max difference: %.2e\n', speedup_water, accuracy_water);

%% Overall Summary
fprintf('\n=== PERFORMANCE SUMMARY ===\n');
speedups = [speedup_rayleigh, speedup_aerosol, speedup_ozone, speedup_water];
accuracies = [accuracy_rayleigh, accuracy_aerosol, accuracy_ozone, accuracy_water];
modules = {'Rayleigh', 'Aerosol', 'Ozone', 'Water'};

fprintf('Module      | Speedup | Max Error\n');
fprintf('------------|---------|----------\n');
for i = 1:length(modules)
    fprintf('%-11s | %5.1fx   | %.2e\n', modules{i}, speedups(i), accuracies(i));
end
fprintf('------------|---------|----------\n');
fprintf('%-11s | %5.1fx   | %.2e\n', 'AVERAGE', mean(speedups), max(accuracies));

%% Real-world Impact
fprintf('\n=== REAL-WORLD IMPACT ===\n');
total_time_orig = time_rayleigh_orig + time_aerosol_orig + time_ozone_orig + time_water_orig;
total_time_am = time_rayleigh_am + time_aerosol_am + time_ozone_am + time_water_am;
total_speedup = total_time_orig / total_time_am;
time_saved_per_field = (total_time_orig - total_time_am) * 1000; % ms

fprintf('Total time per field optimization:\n');
fprintf('  Original modules: %.1f ms\n', total_time_orig * 1000);
fprintf('  _am modules: %.1f ms\n', total_time_am * 1000);
fprintf('  Time saved per field: %.1f ms\n', time_saved_per_field);
fprintf('  Total speedup: %.1fx\n', total_speedup);

fields = 24;
total_time_saved = time_saved_per_field * fields;
fprintf('\nFor 24-field optimization:\n');
fprintf('  Total time saved: %.1f ms (%.1f seconds)\n', total_time_saved, total_time_saved/1000);

if total_speedup > 2.0
    fprintf('✅ EXCELLENT SPEEDUP: %.1fx faster!\n', total_speedup);
elseif total_speedup > 1.5
    fprintf('✅ GOOD SPEEDUP: %.1fx faster\n', total_speedup);
else
    fprintf('ℹ️  MODERATE SPEEDUP: %.1fx faster\n', total_speedup);
end

if max(accuracies) < 1e-12
    fprintf('✅ PERFECT ACCURACY: All modules match original\n');
else
    fprintf('⚠️  ACCURACY CHECK: Max error %.2e\n', max(accuracies));
end

fprintf('\n=== TEST COMPLETE ===\n');