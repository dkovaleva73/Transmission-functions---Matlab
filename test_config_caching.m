% Test ConfigManager caching
fprintf('Testing ConfigManager caching...\n\n');

% First call - should load
fprintf('1. First call to getConfig():\n');
tic;
Config1 = transmissionFast.getConfig();
time1 = toc;
fprintf('   Time: %.3f seconds\n', time1);

% Second call - should use cache
fprintf('\n2. Second call to getConfig():\n');
tic;
Config2 = transmissionFast.getConfig();
time2 = toc;
fprintf('   Time: %.3f seconds\n', time2);

% Third call - should use cache
fprintf('\n3. Third call to getConfig():\n');
tic;
Config3 = transmissionFast.getConfig();
time3 = toc;
fprintf('   Time: %.3f seconds\n', time3);

% Check they are the same
fprintf('\n4. Verification:\n');
fprintf('   Configs identical: %s\n', string(isequal(Config1, Config2) && isequal(Config2, Config3)));
fprintf('   Speedup factor: %.1fx\n', time1/time3);

% Get cache info
info = transmissionFast.ConfigManager.getInfo();
fprintf('\n5. Cache info:\n');
fprintf('   Is cached: %s\n', string(info.IsCached));
fprintf('   Scenario: %s\n', info.Scenario);

% Test creating optimizer (should not reload config)
fprintf('\n6. Creating TransmissionOptimizer:\n');
tic;
optimizer = transmissionFast.TransmissionOptimizer();
time4 = toc;
fprintf('   Time: %.3f seconds\n', time4);
fprintf('   Optimizer created successfully\n');

fprintf('\n7. Summary:\n');
fprintf('   Initial load time: %.3f seconds\n', time1);
fprintf('   Cached access time: %.3f seconds\n', time3);
fprintf('   Performance improvement: %.0f%%\n', (1 - time3/time1) * 100);