%% Test cost continuity between stages
try
    fprintf('=== Testing Cost Continuity Between Stages ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);
    
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Stage 1
    fprintf('\nStage 1: NormOnly_Initial\n');
    stage1 = optimizer.ActiveSequence(1);
    fprintf('  UsePythonFieldModel: %d\n', isfield(stage1, 'usePythonFieldModel') && stage1.usePythonFieldModel);
    
    result1 = optimizer.runSingleStage(stage1);
    optimizer.updateOptimizedParams(result1.OptimalParams);
    fprintf('  Final cost: %.6f\n', result1.Fval);
    
    % Check what field parameters are in OptimizedParams after Stage 1
    fprintf('  Field params in OptimizedParams after Stage 1:\n');
    fieldParams = {'kx0', 'kx', 'ky', 'kx2', 'ky2', 'kx3', 'ky3', 'kx4', 'ky4', 'kxy', 'ky0'};
    for i = 1:length(fieldParams)
        if isfield(optimizer.OptimizedParams, fieldParams{i})
            fprintf('    %s: %.6f\n', fieldParams{i}, optimizer.OptimizedParams.(fieldParams{i}));
        end
    end
    
    % Stage 2
    fprintf('\nStage 2: NormAndCenter\n');
    stage2 = optimizer.ActiveSequence(2);
    fprintf('  UsePythonFieldModel: %d\n', isfield(stage2, 'usePythonFieldModel') && stage2.usePythonFieldModel);
    
    result2 = optimizer.runSingleStage(stage2);
    optimizer.updateOptimizedParams(result2.OptimalParams);
    fprintf('  Final cost: %.6f\n', result2.Fval);
    
    % Check field parameters after Stage 2
    fprintf('  Field params in OptimizedParams after Stage 2:\n');
    for i = 1:length(fieldParams)
        if isfield(optimizer.OptimizedParams, fieldParams{i})
            fprintf('    %s: %.6f\n', fieldParams{i}, optimizer.OptimizedParams.(fieldParams{i}));
        end
    end
    
    % Stage 3 - check initial cost
    fprintf('\nStage 3: FieldCorrection_Python\n');
    stage3 = optimizer.ActiveSequence(3);
    fprintf('  UsePythonFieldModel: %d\n', isfield(stage3, 'usePythonFieldModel') && stage3.usePythonFieldModel);
    
    % Manually calculate initial cost with zero field corrections
    fprintf('\n  Calculating initial cost at Stage 3 start (all field params = 0):\n');
    
    % Create test config with current optimized params + zero field corrections
    TestConfig = Config;
    TestConfig.General.Norm_ = optimizer.OptimizedParams.Norm_;
    TestConfig.Utils.SkewedGaussianModel.Default_center = optimizer.OptimizedParams.Center;
    
    % Explicitly set all field correction parameters to 0
    TestConfig.FieldCorrection.Python.kx0 = 0;
    TestConfig.FieldCorrection.Python.ky0 = 0;
    TestConfig.FieldCorrection.Python.kx = 0;
    TestConfig.FieldCorrection.Python.ky = 0;
    TestConfig.FieldCorrection.Python.kx2 = 0;
    TestConfig.FieldCorrection.Python.ky2 = 0;
    TestConfig.FieldCorrection.Python.kx3 = 0;
    TestConfig.FieldCorrection.Python.ky3 = 0;
    TestConfig.FieldCorrection.Python.kx4 = 0;
    TestConfig.FieldCorrection.Python.ky4 = 0;
    TestConfig.FieldCorrection.Python.kxy = 0;
    
    % Run Stage 3
    result3 = optimizer.runSingleStage(stage3);
    fprintf('  Final cost: %.6f\n', result3.Fval);
    
    % Check initial iteration cost from result3
    if isfield(result3, 'ResultData') && isfield(result3.ResultData, 'InitialCost')
        fprintf('  Initial cost at Stage 3: %.6f\n', result3.ResultData.InitialCost);
    end
    
    fprintf('\n=== COST SUMMARY ===\n');
    fprintf('Stage 1 final: %.6f\n', result1.Fval);
    fprintf('Stage 2 final: %.6f\n', result2.Fval);
    fprintf('Stage 3 final: %.6f\n', result3.Fval);
    
    % Check for cost jump
    costJump = abs(result2.Fval - 0.578386);  % The observed jump value
    if costJump < 0.01
        fprintf('\n⚠️ Cost jump detected between Stage 2 and Stage 3!\n');
        fprintf('  Stage 2 final: %.6f\n', result2.Fval);
        fprintf('  Stage 3 initial: ~0.578386 (from your observation)\n');
        fprintf('  Jump magnitude: ~%.6f\n', 0.578386 - result2.Fval);
    else
        fprintf('\n✓ No significant cost jump between stages\n');
    end
    
    fprintf('\n=== TEST COMPLETE ===\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:min(3, length(ME.stack))
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end