%% Test why cost jumps at Stage 3
try
    fprintf('=== Testing Cost Jump at Stage 3 ===\n');
    
    % 1. Run full sequence with verbose output to see costs
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', true);
    
    % Run the first 3 stages only
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Stage 1
    fprintf('\n=== STAGE 1 ===\n');
    stage1 = optimizer.ActiveSequence(1);
    result1 = optimizer.runSingleStage(stage1);
    optimizer.updateOptimizedParams(result1.OptimalParams);
    fprintf('Stage 1 final cost: %.4e\n', result1.Fval);
    
    % Check cost with Stage 1 params only
    fprintf('\nEvaluating cost with Stage 1 params (Norm_ only):\n');
    cost1 = evaluateCostWithParams(Config, optimizer.CalibratorData, optimizer.OptimizedParams);
    fprintf('Cost = %.4e\n', cost1);
    
    % Stage 2
    fprintf('\n=== STAGE 2 ===\n');
    stage2 = optimizer.ActiveSequence(2);
    result2 = optimizer.runSingleStage(stage2);
    optimizer.updateOptimizedParams(result2.OptimalParams);
    fprintf('Stage 2 final cost: %.4e\n', result2.Fval);
    
    % Check cost with Stage 2 params
    fprintf('\nEvaluating cost with Stage 2 params (Norm_ + Center):\n');
    cost2 = evaluateCostWithParams(Config, optimizer.CalibratorData, optimizer.OptimizedParams);
    fprintf('Cost = %.4e\n', cost2);
    
    % Before Stage 3 - evaluate with zero field corrections
    fprintf('\n=== BEFORE STAGE 3 ===\n');
    fprintf('Current optimized params:\n');
    fields = fieldnames(optimizer.OptimizedParams);
    for i = 1:length(fields)
        fprintf('  %s: %.6f\n', fields{i}, optimizer.OptimizedParams.(fields{i}));
    end
    
    % Add zero field corrections to test
    testParams = optimizer.OptimizedParams;
    testParams.kx0 = 0;
    testParams.kx = 0;
    testParams.ky = 0;
    testParams.kx2 = 0;
    testParams.ky2 = 0;
    testParams.kx3 = 0;
    testParams.ky3 = 0;
    testParams.kx4 = 0;
    testParams.ky4 = 0;
    testParams.kxy = 0;
    
    fprintf('\nEvaluating cost WITH zero field corrections explicitly:\n');
    cost_with_zero_field = evaluateCostWithParams(Config, optimizer.CalibratorData, testParams);
    fprintf('Cost = %.4e\n', cost_with_zero_field);
    
    % Stage 3
    fprintf('\n=== STAGE 3 ===\n');
    stage3 = optimizer.ActiveSequence(3);
    
    % Run Stage 3 with detailed output
    fprintf('Starting Stage 3 optimization...\n');
    result3 = optimizer.runSingleStage(stage3);
    fprintf('Stage 3 final cost: %.4e\n', result3.Fval);
    
    % Show optimized field correction values
    fprintf('\nOptimized field correction parameters:\n');
    fieldParams = {'kx0', 'kx', 'ky', 'kx2', 'ky2', 'kx3', 'ky3', 'kx4', 'ky4', 'kxy'};
    for i = 1:length(fieldParams)
        if isfield(result3.OptimalParams, fieldParams{i})
            fprintf('  %s: %.6f\n', fieldParams{i}, result3.OptimalParams.(fieldParams{i}));
        end
    end
    
    fprintf('\n=== COST SUMMARY ===\n');
    fprintf('Stage 1 (Norm only): %.4e\n', result1.Fval);
    fprintf('Stage 2 (Norm + Center): %.4e\n', result2.Fval);
    fprintf('Cost before Stage 3 with zero field: %.4e\n', cost_with_zero_field);
    fprintf('Stage 3 (with field corrections): %.4e\n', result3.Fval);
    fprintf('Cost reduction from field corrections: %.4e\n', cost_with_zero_field - result3.Fval);
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end

function cost = evaluateCostWithParams(Config, CalibData, Params)
    % Evaluate cost function with given parameters
    
    % Calculate transmission
    [~, ~, TransmissionSpec] = transmission.atmospheric.calculateTransmission(...
        CalibData.Spec, ...
        'Normalization', Params.Norm_, ...
        'AirMass', CalibData.Metadata.airMassFromLAST, ...
        'Config', Config);
    
    % Apply instrumental if Center is present
    if isfield(Params, 'Center')
        InstrumentalResponse = transmission.instrumental.calculateInstrumentalResponse(...
            CalibData.Spec, 'Center', Params.Center, 'Config', Config);
        TransmissionSpec = TransmissionSpec .* InstrumentalResponse;
    end
    
    % Apply field corrections if present
    if isfield(Params, 'kx0')
        % Python field model
        FieldCorrection = calculatePythonFieldCorrection(CalibData, Params, Config);
        TransmissionSpec = TransmissionSpec .* FieldCorrection;
    end
    
    % Apply calibrators
    TotalFlux = transmission.calibrators.calculateTotalFluxCalibrators(...
        CalibData.Spec, CalibData.Mag, TransmissionSpec, Config);
    
    % Calculate cost
    DiffMag = 2.5 * log10(TotalFlux ./ CalibData.LASTData.FLUX_APER_3);
    cost = sum(DiffMag.^2);
end

function FieldCorrection = calculatePythonFieldCorrection(CalibData, Params, Config)
    % Calculate Python-style field correction
    
    X = CalibData.LASTData.X;
    Y = CalibData.LASTData.Y;
    
    % Normalize coordinates
    min_coor = Config.Instrumental.Detector.Min_coordinate;
    max_coor = Config.Instrumental.Detector.Max_coordinate;
    
    xcoor_ = transmission.utils.rescaleInputData(X, min_coor, max_coor, [], [], Config);
    ycoor_ = transmission.utils.rescaleInputData(Y, min_coor, max_coor, [], [], Config);
    
    % Build Chebyshev basis
    Tx = zeros(length(X), 5);
    Tx(:, 1) = 1;
    Tx(:, 2) = xcoor_;
    Tx(:, 3) = 2*xcoor_.^2 - 1;
    Tx(:, 4) = 4*xcoor_.^3 - 3*xcoor_;
    Tx(:, 5) = 8*xcoor_.^4 - 8*xcoor_.^2 + 1;
    
    Ty = zeros(length(Y), 5);
    Ty(:, 1) = 1;
    Ty(:, 2) = ycoor_;
    Ty(:, 3) = 2*ycoor_.^2 - 1;
    Ty(:, 4) = 4*ycoor_.^3 - 3*ycoor_;
    Ty(:, 5) = 8*ycoor_.^4 - 8*ycoor_.^2 + 1;
    
    % Get parameters (default to 0 if not present)
    kx0 = getFieldOrDefault(Params, 'kx0', 0);
    kx = getFieldOrDefault(Params, 'kx', 0);
    kx2 = getFieldOrDefault(Params, 'kx2', 0);
    kx3 = getFieldOrDefault(Params, 'kx3', 0);
    kx4 = getFieldOrDefault(Params, 'kx4', 0);
    
    ky0 = getFieldOrDefault(Params, 'ky0', 0);
    ky = getFieldOrDefault(Params, 'ky', 0);
    ky2 = getFieldOrDefault(Params, 'ky2', 0);
    ky3 = getFieldOrDefault(Params, 'ky3', 0);
    ky4 = getFieldOrDefault(Params, 'ky4', 0);
    
    kxy = getFieldOrDefault(Params, 'kxy', 0);
    
    % Calculate corrections
    cx = [kx0, kx, kx2, kx3, kx4];
    cy = [ky0, ky, ky2, ky3, ky4];
    
    CorrectionX = Tx * cx';
    CorrectionY = Ty * cy';
    CorrectionXY = kxy * xcoor_ .* ycoor_;
    
    % Convert to magnitude space (additive)
    TotalCorrectionMag = CorrectionX + CorrectionY + CorrectionXY;
    
    % Convert to flux multiplier
    FieldCorrection = 10.^(-0.4 * TotalCorrectionMag);
end

function value = getFieldOrDefault(struct, field, default)
    if isfield(struct, field)
        value = struct.(field);
    else
        value = default;
    end
end