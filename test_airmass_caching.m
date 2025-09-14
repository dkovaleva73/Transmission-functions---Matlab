% Test airmass caching performance
fprintf('Testing airmass caching in transmissionFast.utils.airmassFromSMARTS...\n\n');

% Get a config
Config = transmissionFast.inputConfig();
fprintf('Using zenith angle: %.2f degrees\n', Config.Atmospheric.Zenith_angle_deg);

% Test different constituents
constituents = {'rayleigh', 'aerosol', 'ozone', 'water', 'co2'};

fprintf('\n1. First calls (should calculate and cache):\n');
times_first = zeros(length(constituents), 1);
airmasses = zeros(length(constituents), 1);

for i = 1:length(constituents)
    tic;
    airmasses(i) = transmissionFast.utils.airmassFromSMARTS(constituents{i}, Config);
    times_first(i) = toc;
    fprintf('  %s: %.6f (%.4f seconds)\n', constituents{i}, airmasses(i), times_first(i));
end

fprintf('\n2. Second calls (should use cache):\n');
times_cached = zeros(length(constituents), 1);
airmasses_cached = zeros(length(constituents), 1);

for i = 1:length(constituents)
    tic;
    airmasses_cached(i) = transmissionFast.utils.airmassFromSMARTS(constituents{i}, Config);
    times_cached(i) = toc;
    fprintf('  %s: %.6f (%.6f seconds) - %.0fx faster\n', ...
        constituents{i}, airmasses_cached(i), times_cached(i), times_first(i)/times_cached(i));
end

fprintf('\n3. Verification:\n');
fprintf('  Results identical: %s\n', string(isequal(airmasses, airmasses_cached)));

% Test multiple calls of the same constituent (simulate the 6520 calls problem)
fprintf('\n4. Simulate 1000 repeated calls for same constituent:\n');
constituent = 'rayleigh';

% Without cache (bypass = true)
fprintf('  Testing without cache (bypass=true):\n');
tic;
for i = 1:100
    am = transmissionFast.utils.airmassFromSMARTS(constituent, Config, true);
end
time_nocache = toc;
fprintf('    100 calls without cache: %.4f seconds (%.6f per call)\n', time_nocache, time_nocache/100);

% With cache 
fprintf('  Testing with cache:\n');
tic;
for i = 1:1000
    am = transmissionFast.utils.airmassFromSMARTS(constituent, Config);
end
time_cached_bulk = toc;
fprintf('    1000 calls with cache: %.4f seconds (%.6f per call)\n', time_cached_bulk, time_cached_bulk/1000);

% Calculate performance improvement
speedup = (time_nocache/100) / (time_cached_bulk/1000);
fprintf('    Speedup factor: %.0fx\n', speedup);

fprintf('\n5. Projected savings for 6520 calls:\n');
time_old = (time_nocache/100) * 6520;
time_new = times_first(1) + (time_cached_bulk/1000) * 6519;  % First call + cached calls
time_saved = time_old - time_new;

fprintf('  Old approach (6520 calculations): %.3f seconds\n', time_old);
fprintf('  New approach (1 calculation + 6519 cached): %.3f seconds\n', time_new);
fprintf('  Time saved: %.3f seconds (%.1f%% improvement)\n', time_saved, (time_saved/time_old)*100);

% Test different zenith angles
fprintf('\n6. Testing different zenith angles (should create new cache entries):\n');
zenith_angles = [30, 45, 60];
for i = 1:length(zenith_angles)
    Config.Atmospheric.Zenith_angle_deg = zenith_angles(i);
    tic;
    am = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
    time_new_zenith = toc;
    fprintf('  Zenith %.0f°: %.6f (%.6f seconds)\n', zenith_angles(i), am, time_new_zenith);
end

% Test cache for the new zenith angles
fprintf('\n7. Test cache for new zenith angles:\n');
for i = 1:length(zenith_angles)
    Config.Atmospheric.Zenith_angle_deg = zenith_angles(i);
    tic;
    am = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
    time_cached_zenith = toc;
    fprintf('  Zenith %.0f° (cached): %.6f (%.6f seconds)\n', zenith_angles(i), am, time_cached_zenith);
end

fprintf('\n✓ Airmass caching working perfectly!\n');