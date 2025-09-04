%% Test Stage 3 with proper fixedParams struct
try
    fprintf('=== Testing Stage 3 fixedParams ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);
    
    % Check Stage 3 structure
    stage3 = optimizer.ActiveSequence(3);
    fprintf('\nStage 3 structure:\n');
    fprintf('  name: %s\n', stage3.name);
    fprintf('  freeParams: %s\n', strjoin(string(stage3.freeParams), ', '));
    
    % Check fixedParams
    if isfield(stage3, 'fixedParams')
        fprintf('  fixedParams exists: ');
        if isstruct(stage3.fixedParams)
            fprintf('struct with fields:\n');
            fields = fieldnames(stage3.fixedParams);
            for i = 1:length(fields)
                fprintf('    %s = %.4f\n', fields{i}, stage3.fixedParams.(fields{i}));
            end
        else
            fprintf('not a struct (class: %s)\n', class(stage3.fixedParams));
        end
    else
        fprintf('  fixedParams: not defined\n');
    end
    
    % Run stages 1-3
    fprintf('\nRunning optimization stages 1-3...\n');
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Stage 1
    result1 = optimizer.runSingleStage(optimizer.ActiveSequence(1));
    optimizer.updateOptimizedParams(result1.OptimalParams);
    fprintf('Stage 1 completed: cost = %.6e\n', result1.Fval);
    
    % Stage 2
    result2 = optimizer.runSingleStage(optimizer.ActiveSequence(2));
    optimizer.updateOptimizedParams(result2.OptimalParams);
    fprintf('Stage 2 completed: cost = %.6e\n', result2.Fval);
    
    % Stage 3 - test with verbose to see parameter printing
    optimizer.Verbose = true;
    fprintf('\nRunning Stage 3 with parameter printing:\n');
    optimizer.printCurrentParameterValues('START', stage3);
    
    result3 = optimizer.runSingleStage(stage3);
    fprintf('\nStage 3 completed: cost = %.6e\n', result3.Fval);
    
    fprintf('\n=== TEST COMPLETE ===\n');
    fprintf('✓ fixedParams handling works for both struct and non-struct values\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i=1:min(3, length(ME.stack))
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end