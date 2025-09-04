%% Test full parameter evolution across stages
try
    fprintf('=== Testing Full Parameter Evolution ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', true);
    
    % Run just the first 3 stages to see parameter evolution
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Stage 1
    stage1 = optimizer.ActiveSequence(1);
    result1 = optimizer.runSingleStage(stage1);
    optimizer.updateOptimizedParams(result1.OptimalParams);
    
    % Stage 2  
    stage2 = optimizer.ActiveSequence(2);
    result2 = optimizer.runSingleStage(stage2);
    optimizer.updateOptimizedParams(result2.OptimalParams);
    
    % Stage 3 (this is where we want to see the field correction parameters)
    stage3 = optimizer.ActiveSequence(3);
    
    % Print parameter status before Stage 3
    fprintf('\n=== BEFORE STAGE 3 ===\n');
    optimizer.printCurrentParameterValues('BEFORE', stage3);
    
    fprintf('\n=== Running Stage 3 ===\n');
    result3 = optimizer.runSingleStage(stage3);
    
    fprintf('\n=== AFTER STAGE 3 ===\n');
    optimizer.updateOptimizedParams(result3.OptimalParams);
    optimizer.printCurrentParameterValues('AFTER', stage3);
    
    fprintf('\n=== COST EVOLUTION ===\n');
    fprintf('Stage 1 cost: %.6e\n', result1.Fval);
    fprintf('Stage 2 cost: %.6e\n', result2.Fval);
    fprintf('Stage 3 cost: %.6e\n', result3.Fval);
    
    fprintf('\n=== TEST COMPLETE ===\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:min(3, length(ME.stack))
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end