Config = transmission.inputConfig();
optimizer = transmission.TransmissionOptimizer(Config, 'Sequence', 'DefaultSequence', 'Verbose', false);
optimizer.loadCalibratorData(1);
optimizer.loadAbsorptionData();

% Run first two stages quickly
stage1 = optimizer.ActiveSequence(1);
result1 = optimizer.runSingleStage(stage1);
optimizer.updateOptimizedParams(result1.OptimalParams);

stage2 = optimizer.ActiveSequence(2);
result2 = optimizer.runSingleStage(stage2);
optimizer.updateOptimizedParams(result2.OptimalParams);

% Check Stage 3 InitialValues
stage3 = optimizer.ActiveSequence(3);
fprintf('\nStage 3 Free Parameters:\n');
for i = 1:length(stage3.freeParams)
    paramName = char(stage3.freeParams(i));
    fprintf('  %s', paramName);
    if isfield(Config.Optimization.InitialGuess, paramName)
        fprintf(' -> InitialGuess: %.4f', Config.Optimization.InitialGuess.(paramName));
    else
        fprintf(' -> No InitialGuess');
    end
    if isfield(optimizer.OptimizedParams, paramName)
        fprintf(' (already optimized: %.4f)', optimizer.OptimizedParams.(paramName));
    else
        fprintf(' (will use InitialGuess)');
    end
    fprintf('\n');
end