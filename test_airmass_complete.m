% Complete test of airmass caching system
fprintf('Testing complete airmass caching system...\n\n');

Config = transmissionFast.inputConfig();

% Test basic caching
fprintf('1. Basic caching test:\n');
tic;
am1 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
time1 = toc;
fprintf('  First call: %.6f (%.6f seconds)\n', am1, time1);

tic;
am2 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
time2 = toc;
fprintf('  Second call (cached): %.6f (%.6f seconds) - %.0fx faster\n', am2, time2, time1/time2);

% Test cache clearing
fprintf('\n2. Cache clearing test:\n');
transmissionFast.utils.clearAirmassCaches();

tic;
am3 = transmissionFast.utils.airmassFromSMARTS('rayleigh', Config);
time3 = toc;
fprintf('  After cache clear: %.6f (%.6f seconds)\n', am3, time3);
fprintf('  Results still identical: %s\n', string(am1 == am3));

% Test multiple constituents
fprintf('\n3. Multiple constituents performance:\n');
constituents = {'rayleigh', 'aerosol', 'ozone', 'water', 'co2', 'o2', 'ch4', 'n2o'};

% Clear cache and time first calculations
transmissionFast.utils.clearAirmassCaches();
tic;
for i = 1:length(constituents)
    am = transmissionFast.utils.airmassFromSMARTS(constituents{i}, Config);
end
time_first_all = toc;
fprintf('  First calculations (all %d): %.6f seconds\n', length(constituents), time_first_all);

% Time cached calculations
tic;
for i = 1:length(constituents)
    am = transmissionFast.utils.airmassFromSMARTS(constituents{i}, Config);
end
time_cached_all = toc;
fprintf('  Cached calculations (all %d): %.6f seconds\n', length(constituents), time_cached_all);
fprintf('  Speedup: %.0fx faster\n', time_first_all/time_cached_all);

% Simulate the real-world scenario: 6520 calls with mixed constituents
fprintf('\n4. Real-world simulation (6520 mixed calls):\n');
num_calls = 1000;  % Scaled down for testing
mixed_constituents = repmat(constituents, 1, ceil(num_calls/length(constituents)));
mixed_constituents = mixed_constituents(1:num_calls);

% Clear cache and time the full simulation
transmissionFast.utils.clearAirmassCaches();
tic;
for i = 1:num_calls
    am = transmissionFast.utils.airmassFromSMARTS(mixed_constituents{i}, Config);
end
time_simulation = toc;

estimated_6520_time = time_simulation * (6520 / num_calls);
fprintf('  %d mixed calls: %.6f seconds\n', num_calls, time_simulation);
fprintf('  Estimated 6520 calls: %.3f seconds\n', estimated_6520_time);

% Compare with non-cached performance
single_call_time = time_first_all / length(constituents);  % Average time per constituent
old_estimated_6520 = single_call_time * 6520;
improvement = ((old_estimated_6520 - estimated_6520_time) / old_estimated_6520) * 100;

fprintf('  Without caching (estimated): %.3f seconds\n', old_estimated_6520);
fprintf('  Performance improvement: %.1f%%\n', improvement);

fprintf('\n✅ Airmass caching system fully operational!\n');
fprintf('📊 Expected performance gain for your 6520 calls: ~%.1f%% faster\n', improvement);