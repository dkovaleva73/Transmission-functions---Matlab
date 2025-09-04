%% Simple test of cost jump at Stage 3
try
    fprintf('=== Testing Cost Jump at Stage 3 ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);
    
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Run Stage 1
    stage1 = optimizer.ActiveSequence(1);
    result1 = optimizer.runSingleStage(stage1);
    optimizer.updateOptimizedParams(result1.OptimalParams);
    fprintf('Stage 1 final cost: %.4e\n', result1.Fval);
    
    % Run Stage 2
    stage2 = optimizer.ActiveSequence(2);
    result2 = optimizer.runSingleStage(stage2);
    optimizer.updateOptimizedParams(result2.OptimalParams);
    fprintf('Stage 2 final cost: %.4e\n', result2.Fval);
    
    % Run Stage 3 and capture the initial cost
    fprintf('\nRunning Stage 3...\n');
    stage3 = optimizer.ActiveSequence(3);
    
    % Temporarily enable verbose to see first iteration
    result3 = transmission.minimizerFminGeneric(Config, ...
        'FreeParams', stage3.freeParams, ...
        'FixedParams', optimizer.OptimizedParams, ...
        'UsePythonFieldModel', true, ...
        'InputData', optimizer.CalibratorData, ...
        'SigmaClipping', true, ...
        'SigmaThreshold', 2.0, ...
        'SigmaIterations', 3, ...
        'Verbose', true);
    
    fprintf('\nStage 3 final cost: %.4e\n', result3);
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
end