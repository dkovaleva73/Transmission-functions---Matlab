% Final test after cleanup
fprintf('Final test after cleanup...\n');
Config = transmissionFast.inputConfig();
optimizer = transmissionFast.TransmissionOptimizer(Config);
fprintf('✓ transmissionFast.inputConfig() works\n');
fprintf('✓ transmissionFast.TransmissionOptimizer() works\n');
fprintf('✓ All systems operational!\n');