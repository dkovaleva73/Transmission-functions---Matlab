% Test integrated caching in inputConfig
fprintf('Testing integrated caching in transmissionFast.inputConfig()...\n\n');

% First call - should load and cache
fprintf('1. First call to inputConfig():\n');
tic;
Config1 = transmissionFast.inputConfig();
time1 = toc;
fprintf('   Time: %.4f seconds\n', time1);

% Second call - should use cache
fprintf('\n2. Second call to inputConfig():\n');
tic;
Config2 = transmissionFast.inputConfig();
time2 = toc;
fprintf('   Time: %.4f seconds\n', time2);

% Third call - should use cache
fprintf('\n3. Third call to inputConfig():\n');
tic;
Config3 = transmissionFast.inputConfig();
time3 = toc;
fprintf('   Time: %.4f seconds\n', time3);

% Test force reload
fprintf('\n4. Force reload (should take longer):\n');
tic;
Config4 = transmissionFast.inputConfig('default', true);  % Force reload
time4 = toc;
fprintf('   Time: %.4f seconds\n', time4);

% Test different scenario
fprintf('\n5. Different scenario (should load new config):\n');
tic;
ConfigMinimal = transmissionFast.inputConfig('minimal');
time5 = toc;
fprintf('   Time: %.4f seconds\n', time5);

% Test back to default (should use cache)
fprintf('\n6. Back to default (should use cache):\n');
tic;
Config6 = transmissionFast.inputConfig('default');
time6 = toc;
fprintf('   Time: %.4f seconds\n', time6);

% Test optimizer creation
fprintf('\n7. Creating TransmissionOptimizer (should be fast):\n');
tic;
optimizer = transmissionFast.TransmissionOptimizer();
time7 = toc;
fprintf('   Time: %.4f seconds\n', time7);

% Summary
fprintf('\n8. Summary:\n');
fprintf('   Initial load: %.4f seconds\n', time1);
fprintf('   Cached access: %.4f seconds (%.0fx faster)\n', time2, time1/time2);
fprintf('   Force reload: %.4f seconds\n', time4);
fprintf('   Different scenario: %.4f seconds\n', time5);
fprintf('   Optimizer creation: %.4f seconds\n', time7);

fprintf('\n9. Performance improvement:\n');
speedup = time1 / time2;
fprintf('   Speedup factor: %.0fx\n', speedup);
fprintf('   Time saved per call: %.4f seconds\n', time1 - time2);

% Calculate projected savings
fprintf('\n10. Projected savings for 624 calls:\n');
oldTime = time1 * 624;
newTime = time1 + (time2 * 623);  % First call + cached calls
timeSaved = oldTime - newTime;
fprintf('   Old approach (624 loads): %.1f seconds (%.1f minutes)\n', oldTime, oldTime/60);
fprintf('   New approach (1 load + 623 cached): %.1f seconds\n', newTime);
fprintf('   Time saved: %.1f seconds (%.1f minutes)\n', timeSaved, timeSaved/60);

% Test that configs are functionally equivalent
fprintf('\n11. Verification:\n');
fprintf('   Same scenario configs have same fields: %s\n', ...
    string(isequal(fieldnames(Config1), fieldnames(Config2))));
fprintf('   Different scenario has different water vapor: %s\n', ...
    string(Config1.Atmospheric.Components.Water.Pwv_cm ~= ConfigMinimal.Atmospheric.Components.Water.Pwv_cm));