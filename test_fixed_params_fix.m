%% Test fix for fixedParams error
try
    fprintf('=== Testing fixedParams Fix ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', true);
    
    % Run just the first stage to verify the fix
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    stage1 = optimizer.ActiveSequence(1);
    fprintf('\nStage 1 structure:\n');
    fprintf('  name: %s\n', stage1.name);
    fprintf('  freeParams: %s\n', strjoin(string(stage1.freeParams), ', '));
    
    % Check if fixedParams exists and its type
    if isfield(stage1, 'fixedParams')
        fprintf('  fixedParams exists: ');
        if isstruct(stage1.fixedParams)
            fprintf('struct with fields: %s\n', strjoin(string(fieldnames(stage1.fixedParams)), ', '));
        else
            fprintf('not a struct (class: %s)\n', class(stage1.fixedParams));
        end
    else
        fprintf('  fixedParams: not defined\n');
    end
    
    fprintf('\nRunning Stage 1...\n');
    result1 = optimizer.runSingleStage(stage1);
    
    fprintf('\n✓ Stage 1 completed successfully\n');
    fprintf('  Final cost: %.6e\n', result1.Fval);
    
    fprintf('\n=== TEST COMPLETE ===\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i=1:min(3, length(ME.stack))
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end