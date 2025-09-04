%% Test that cost jump is eliminated
try
    fprintf('=== Testing Cost Continuity with Python Field Model ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);
    
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Run stages 1-3 and check costs
    costs = zeros(3, 1);
    
    % Stage 1
    fprintf('\nStage 1: %s\n', optimizer.ActiveSequence(1).name);
    fprintf('  UsePythonFieldModel: %d\n', optimizer.ActiveSequence(1).usePythonFieldModel);
    result1 = optimizer.runSingleStage(optimizer.ActiveSequence(1));
    optimizer.updateOptimizedParams(result1.OptimalParams);
    costs(1) = result1.Fval;
    fprintf('  Final cost: %.6f\n', costs(1));
    
    % Stage 2
    fprintf('\nStage 2: %s\n', optimizer.ActiveSequence(2).name);
    fprintf('  UsePythonFieldModel: %d\n', optimizer.ActiveSequence(2).usePythonFieldModel);
    result2 = optimizer.runSingleStage(optimizer.ActiveSequence(2));
    optimizer.updateOptimizedParams(result2.OptimalParams);
    costs(2) = result2.Fval;
    fprintf('  Final cost: %.6f\n', costs(2));
    
    % Stage 3 - print parameter values before starting
    fprintf('\nStage 3: %s\n', optimizer.ActiveSequence(3).name);
    fprintf('  UsePythonFieldModel: %d\n', optimizer.ActiveSequence(3).usePythonFieldModel);
    
    stage3 = optimizer.ActiveSequence(3);
    fprintf('\nParameters at Stage 3 start:\n');
    optimizer.printCurrentParameterValues('START', stage3);
    
    result3 = optimizer.runSingleStage(stage3);
    costs(3) = result3.Fval;
    fprintf('\nStage 3 final cost: %.6f\n', costs(3));
    
    fprintf('\n=== COST SUMMARY ===\n');
    fprintf('Stage 1: %.6f\n', costs(1));
    fprintf('Stage 2: %.6f\n', costs(2));
    fprintf('Stage 3: %.6f\n', costs(3));
    
    fprintf('\n=== COST TRANSITIONS ===\n');
    fprintf('Stage 1 → 2: %.6f → %.6f (change: %.6f)\n', costs(1), costs(2), costs(2) - costs(1));
    fprintf('Stage 2 → 3: %.6f → %.6f (change: %.6f)\n', costs(2), costs(3), costs(3) - costs(2));
    
    % The key test: Stage 3 should start from Stage 2's final cost
    fprintf('\n=== CONTINUITY CHECK ===\n');
    fprintf('If the Python field model is consistently applied with zero coefficients,\n');
    fprintf('Stage 3 should start optimization from Stage 2 final cost value.\n');
    fprintf('There should be NO jump in cost at the start of Stage 3.\n');
    
    fprintf('\n=== TEST COMPLETE ===\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:min(3, length(ME.stack))
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end