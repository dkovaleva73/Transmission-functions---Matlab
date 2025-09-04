%% Test that cost doesn't jump at Stage 3 with zero field corrections
try
    fprintf('=== Testing Cost Continuity at Stage 3 ===\n');
    
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);
    
    fprintf('Loading calibrator data...\n');
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Run Stage 1
    fprintf('\nStage 1 (NormOnly_Initial):\n');
    stage1 = optimizer.ActiveSequence(1);
    result1 = optimizer.runSingleStage(stage1);
    optimizer.updateOptimizedParams(result1.OptimalParams);
    fprintf('  Final cost: %.6e\n', result1.Fval);
    
    % Run Stage 2
    fprintf('\nStage 2 (NormAndCenter):\n');
    stage2 = optimizer.ActiveSequence(2);
    result2 = optimizer.runSingleStage(stage2);
    optimizer.updateOptimizedParams(result2.OptimalParams);
    fprintf('  Final cost: %.6e\n', result2.Fval);
    
    % Check initial cost at Stage 3 with all zero field corrections
    fprintf('\nStage 3 (FieldCorrection_Python):\n');
    stage3 = optimizer.ActiveSequence(3);
    
    % Manually evaluate cost with zero field corrections
    fprintf('  Evaluating initial cost (all field params = 0)...\n');
    
    % Create test Config with zero field corrections
    TestConfig = Config;
    TestConfig.General.Norm_ = optimizer.OptimizedParams.Norm_;
    TestConfig.Utils.SkewedGaussianModel.Default_center = optimizer.OptimizedParams.Center;
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
    
    % Calculate cost
    [Cost, ~, ~] = calculateTestCost(optimizer.CalibratorData, TestConfig, true);
    fprintf('  Initial cost with zero field corrections: %.6e\n', Cost);
    
    % Compare with Stage 2 final cost
    costDiff = abs(Cost - result2.Fval);
    fprintf('  Difference from Stage 2 final cost: %.6e\n', costDiff);
    
    if costDiff < 1e-10
        fprintf('  ✓ No cost jump - costs are identical\n');
    elseif costDiff < 1e-6
        fprintf('  ✓ Negligible cost difference (< 1e-6)\n');
    else
        fprintf('  ⚠️ Significant cost difference detected!\n');
    end
    
    % Now run actual Stage 3 optimization
    fprintf('\n  Running Stage 3 optimization...\n');
    result3 = optimizer.runSingleStage(stage3);
    fprintf('  Final cost after optimization: %.6e\n', result3.Fval);
    fprintf('  Cost reduction from field corrections: %.6e\n', Cost - result3.Fval);
    
    fprintf('\n=== TEST COMPLETE ===\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i=1:min(3, length(ME.stack))
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end

function [Cost, Residuals, DiffMag] = calculateTestCost(CalibData, Config, UsePythonModel)
    % Simple cost calculation for testing
    
    % Load absorption data
    AbsorptionData = transmission.data.loadAbsorptionData([], {}, false);
    
    % Calculate cost using the same function as minimizerFminGeneric
    [Cost, Residuals, DiffMag] = calculateCostFunction(CalibData, Config, ...
                                                        AbsorptionData, [], UsePythonModel);
end

function [Cost, Residuals, DiffMag] = calculateCostFunction(CalibData, Config, AbsorptionData, ChebyshevModel, UsePythonModel)
    % Simplified version of calculateCostFunction from minimizerFminGeneric
    
    if nargin < 5
        UsePythonModel = false;
    end
    
    % Apply transmission to calibrators
    [SpecTrans, ~, ~] = transmission.calibrators.applyTransmissionToCalibrators(...
        CalibData.Spec, CalibData.Metadata, Config, 'AbsorptionData', AbsorptionData);
    
    % Apply instrumental response (QE model)
    InstrumentalResponse = transmission.instrumental.calculateInstrumentalResponse(...
        CalibData.Spec, 'Config', Config);
    SpecTrans = SpecTrans .* InstrumentalResponse;
    
    % Calculate total flux
    TotalFlux = transmission.calibrators.calculateTotalFluxCalibrators(...
        CalibData.Spec, CalibData.Mag, SpecTrans, Config);
    
    % Apply field corrections if provided
    if UsePythonModel
        % This should now return ones(n,1) when all params are zero
        FieldCorrection = evaluatePythonFieldModel(CalibData.LASTData, Config);
        TotalFlux = TotalFlux .* FieldCorrection;
    end
    
    % Calculate magnitude differences
    DiffMag = 2.5 * log10(TotalFlux ./ CalibData.LASTData.FLUX_APER_3);
    Residuals = DiffMag;
    Cost = sum(DiffMag.^2);
end

function FieldCorrection = evaluatePythonFieldModel(LASTData, Config)
    % Call the actual function from minimizerFminGeneric
    FieldCorrection = transmission.minimizerFminGeneric.evaluatePythonFieldModel(LASTData, Config);
end