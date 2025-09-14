% Benchmark airmass calculation performance: Map vs Direct coefficients
fprintf('=== AIRMASS CALCULATION PERFORMANCE BENCHMARK ===\n\n');

% Clear any existing caches
transmissionFast.utils.airmassFromSMARTS('clearcache');
transmissionFast.utils.airmassFromSMARTSFast('clearcache');

% Setup
Config = transmissionFast.inputConfig();
constituents = {'rayleigh', 'aerosol', 'ozone', 'water'};
N_tests = 10000;

fprintf('Testing %d calls per method per constituent...\n\n', N_tests);

%% Test Original Map-Based Version
fprintf('1. Original (Map-based) Version:\n');
times_original = zeros(length(constituents), 1);
results_original = cell(length(constituents), 1);

for i = 1:length(constituents)
    constituent = constituents{i};
    
    % Warm up
    transmissionFast.utils.airmassFromSMARTS(constituent, Config);
    
    % Benchmark
    tic;
    for j = 1:N_tests
        result = transmissionFast.utils.airmassFromSMARTS(constituent, Config);
    end
    times_original(i) = toc;
    results_original{i} = result;
    
    fprintf('  %s: %.3f ms (%d calls)\n', constituent, times_original(i)*1000, N_tests);
end

%% Test Fast Direct-Coefficient Version
fprintf('\n2. Fast (Direct coefficients) Version:\n');
times_fast = zeros(length(constituents), 1);
results_fast = cell(length(constituents), 1);

for i = 1:length(constituents)
    constituent = constituents{i};
    
    % Warm up
    transmissionFast.utils.airmassFromSMARTSFast(constituent, Config);
    
    % Benchmark
    tic;
    for j = 1:N_tests
        result = transmissionFast.utils.airmassFromSMARTSFast(constituent, Config);
    end
    times_fast(i) = toc;
    results_fast{i} = result;
    
    fprintf('  %s: %.3f ms (%d calls)\n', constituent, times_fast(i)*1000, N_tests);
end

%% Performance Summary
fprintf('\n=== PERFORMANCE COMPARISON ===\n');
speedup_factors = times_original ./ times_fast;
avg_speedup = mean(speedup_factors);

fprintf('Constituent    | Original (ms) | Fast (ms) | Speedup\n');
fprintf('---------------|---------------|-----------|--------\n');
for i = 1:length(constituents)
    fprintf('%-14s | %11.3f | %8.3f | %5.1fx\n', ...
            constituents{i}, times_original(i)*1000, times_fast(i)*1000, speedup_factors(i));
end
fprintf('---------------|---------------|-----------|--------\n');
fprintf('%-14s | %11.3f | %8.3f | %5.1fx\n', ...
        'AVERAGE', mean(times_original)*1000, mean(times_fast)*1000, avg_speedup);

%% Accuracy Verification
fprintf('\n=== ACCURACY VERIFICATION ===\n');
fprintf('Constituent    | Max Rel Error\n');
fprintf('---------------|---------------\n');
max_error = 0;
for i = 1:length(constituents)
    rel_error = abs(results_original{i} - results_fast{i}) / results_original{i};
    max_error = max(max_error, rel_error);
    fprintf('%-14s | %.2e\n', constituents{i}, rel_error);
end
fprintf('---------------|---------------\n');
fprintf('%-14s | %.2e\n', 'MAXIMUM', max_error);

%% Real-world Impact Assessment
fprintf('\n=== REAL-WORLD IMPACT ===\n');
calls_per_field = 4; % rayleigh, aerosol, ozone, water
fields = 24;
total_calls = calls_per_field * fields;

time_saved_per_optimization = (mean(times_original) - mean(times_fast)) * total_calls;
fprintf('Calls per optimization run: %d\n', total_calls);
fprintf('Time saved per run: %.1f ms\n', time_saved_per_optimization * 1000);

if avg_speedup > 2.0
    fprintf('✅ SIGNIFICANT SPEEDUP: %.1fx faster - Worth implementing!\n', avg_speedup);
elseif avg_speedup > 1.5
    fprintf('✅ MODERATE SPEEDUP: %.1fx faster - Consider implementing\n', avg_speedup);
else
    fprintf('ℹ️  MINOR SPEEDUP: %.1fx faster - Marginal benefit\n', avg_speedup);
end

if max_error < 1e-14
    fprintf('✅ PERFECT ACCURACY: Max error %.2e (machine precision)\n', max_error);
else
    fprintf('⚠️  ACCURACY WARNING: Max error %.2e\n', max_error);
end

fprintf('\n💡 Recommendation: ');
if avg_speedup > 1.5 && max_error < 1e-12
    fprintf('Replace original with fast version\n');
else
    fprintf('Keep original version for safety\n');
end

fprintf('\n=== BENCHMARK COMPLETE ===\n');