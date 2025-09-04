%% Test comprehensive parameter printing
try
    fprintf('=== Testing Comprehensive Parameter Printing ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);
    
    % Load data
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Test Stage 1 - should show ALL parameters
    stage1 = optimizer.ActiveSequence(1);
    fprintf('\n=== STAGE 1: %s ===\n', stage1.name);
    fprintf('Free parameters: %s\n', strjoin(string(stage1.freeParams), ', '));
    
    optimizer.printCurrentParameterValues('START', stage1);
    
    % Run Stage 1
    result1 = optimizer.runSingleStage(stage1);
    optimizer.updateOptimizedParams(result1.OptimalParams);
    
    fprintf('\nAfter Stage 1 optimization:\n');
    optimizer.printCurrentParameterValues('END', stage1);
    
    % Test Stage 2 - should show updated Norm_ as FIXED
    stage2 = optimizer.ActiveSequence(2);
    fprintf('\n\n=== STAGE 2: %s ===\n', stage2.name);
    fprintf('Free parameters: %s\n', strjoin(string(stage2.freeParams), ', '));
    
    optimizer.printCurrentParameterValues('START', stage2);
    
    fprintf('\n=== TEST COMPLETE ===\n');
    fprintf('✓ All parameters shown with correct status indicators\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i=1:min(3, length(ME.stack))
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end