% Test that optimizers work correctly with cached config
fprintf('Testing optimizer performance with ConfigManager...\n\n');

% Clear any existing cache
transmissionFast.ConfigManager.reset();

% Test multiple optimizer creations
fprintf('Creating 10 optimizers to test caching benefit:\n');
times = zeros(10, 1);

for i = 1:10
    tic;
    optimizer = transmissionFast.TransmissionOptimizer();
    times(i) = toc;
    fprintf('  Optimizer %2d: %.4f seconds\n', i, times(i));
end

fprintf('\nStatistics:\n');
fprintf('  First creation (includes config load): %.4f seconds\n', times(1));
fprintf('  Average of subsequent creations: %.4f seconds\n', mean(times(2:end)));
fprintf('  Total time saved by caching: %.4f seconds\n', (times(1) - mean(times(2:end))) * 9);

% Now test with TransmissionOptimizerAdvanced
fprintf('\n\nTesting TransmissionOptimizerAdvanced:\n');
transmissionFast.ConfigManager.reset();

times_adv = zeros(5, 1);
for i = 1:5
    tic;
    optimizer_adv = transmissionFast.TransmissionOptimizerAdvanced();
    times_adv(i) = toc;
    fprintf('  Advanced Optimizer %d: %.4f seconds\n', i, times_adv(i));
end

fprintf('\nAdvanced Statistics:\n');
fprintf('  First creation (includes config load): %.4f seconds\n', times_adv(1));
fprintf('  Average of subsequent creations: %.4f seconds\n', mean(times_adv(2:end)));

% Estimate total savings for 624 calls
fprintf('\n\nProjected savings for 624 inputConfig calls:\n');
single_load_time = times(1) - mean(times(2:end));
fprintf('  Time per inputConfig call: ~%.4f seconds\n', single_load_time);
fprintf('  Total time with old approach (624 calls): ~%.2f seconds\n', single_load_time * 624);
fprintf('  Total time with caching (1 call): ~%.2f seconds\n', single_load_time);
fprintf('  Time saved: ~%.2f seconds (%.1f minutes)\n', single_load_time * 623, single_load_time * 623 / 60);