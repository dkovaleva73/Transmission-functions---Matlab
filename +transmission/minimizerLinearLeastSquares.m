function [OptimalParams, Fval, ExitFlag, Output, ResultData] = minimizerLinearLeastSquares(Config, Args)
    % Linear least squares minimizer for field correction parameters
    % Optimized for Chebyshev coefficients using closed-form solution
    % 
    % Input:  - Config - Configuration structure from transmission.inputConfig()
    %         - Args - Optional arguments:
    %           'FreeParams' - Cell array of parameter names to optimize (must be field correction params)
    %           'FixedParams' - Structure with fixed parameter values (overrides Config)
    %           'InitialValues' - Structure with initial values (ignored for linear solver)
    %           'SigmaClipping' - Enable sigma clipping (default: false)
    %           'SigmaThreshold' - Threshold for sigma clipping (default: 3.0)
    %           'SigmaIterations' - Number of sigma clipping iterations (default: 3)
    %           'InputData' - Pre-loaded calibrator data (optional)
    %           'Verbose' - Enable verbose output (default: false)
    %           'Regularization' - L2 regularization parameter (default: 0)
    %
    % Output: - OptimalParams - Structure with optimal parameter values
    %         - Fval - Final value of cost function (sum of squared residuals)
    %         - ExitFlag - Exit condition (1=success, 0=failed)
    %         - Output - Solution details
    %         - ResultData - Structure with calibrator data and residuals
    %
    % Author: D. Kovaleva (Aug 2025)
    % Example:
    %   Config = transmission.inputConfig();
    %   [OptimalParams, Fval] = transmission.minimizerLinearLeastSquares(Config, ...
    %       'FreeParams', ["kx0", "kx", "ky", "kx2", "ky2"]);
    
    arguments
        Config = transmission.inputConfig()
        Args.FreeParams string = ["kx0", "kx", "ky"]  % Default: basic field correction
        Args.FixedParams struct = struct()
        Args.InitialValues struct = struct()  % Ignored for linear solver
        Args.SigmaClipping logical = false
        Args.SigmaThreshold double = 3.0
        Args.SigmaIterations double = 3
        Args.UsePythonFieldModel logical = true  % Always use Python field model for field corrections
        Args.UseChebyshev logical = false  % Not used in linear solver
        Args.ChebyshevOrder double = 4  % Not used in linear solver
        Args.InputData = []
        Args.Verbose logical = false
        Args.Regularization double = 0  % L2 regularization parameter
    end
    
    % Validate that all free parameters are field correction parameters
    validFieldParams = ["kx0", "ky0", "kx", "ky", "kx2", "ky2", "kx3", "ky3", "kx4", "ky4", "kxy"];
    for i = 1:length(Args.FreeParams)
        if ~ismember(Args.FreeParams(i), validFieldParams)
            error('Linear least squares solver only supports field correction parameters. Invalid: %s', Args.FreeParams(i));
        end
    end
    
    if Args.Verbose
        fprintf('=== LINEAR LEAST SQUARES FIELD CORRECTION MINIMIZER ===\n');
        fprintf('Free parameters: %s\n', strjoin(Args.FreeParams, ', '));
        fprintf('Fixed parameters: %d\n', numel(fieldnames(Args.FixedParams)));
        if Args.SigmaClipping
            fprintf('Sigma clipping: Enabled (threshold=%.1f, iterations=%d)\n', ...
                    Args.SigmaThreshold, Args.SigmaIterations);
        end
        if Args.Regularization > 0
            fprintf('L2 regularization: λ = %.2e\n', Args.Regularization);
        end
        fprintf('Note: Linear solver always uses Python field model for field corrections\n');
        fprintf('\n');
    end
    
    % Load or prepare calibrator data
    if ~isempty(Args.InputData)
        CalibData = Args.InputData;
        if Args.Verbose
            fprintf('Using provided calibrator data\n');
        end
    else
        if Args.Verbose
            fprintf('Loading calibrator data...\n');
        end
        CalibData = loadCalibratorData(Config);
    end
    
    % Validate we have data
    if isempty(CalibData.Spec)
        error('No calibrators found. Check catalog file and search parameters.');
    end
    
    if Args.Verbose
        fprintf('Found %d calibrators\n', length(CalibData.Spec));
    end
    
    % Get absorption data from Config (already cached in memory)
    AbsorptionData = Config.AbsorptionData;
    
    % Store original calibrator data for sigma clipping
    OriginalCalibData = CalibData;
    
    % Initialize results
    ExitFlag = 1; % Success
    Output = struct();
    Output.message = 'Linear least squares solution';
    Output.iterations = 1;
    Output.funcCount = 1;
    
    % Sigma clipping outer loop
    if Args.SigmaClipping
        maxSigmaIterations = Args.SigmaIterations;
        if Args.Verbose
            fprintf('Using iterative sigma clipping: %d cycles\n', maxSigmaIterations);
        end
        
        for sigmaIter = 1:maxSigmaIterations
            if Args.Verbose
                fprintf('\n=== SIGMA CLIPPING CYCLE %d/%d ===\n', sigmaIter, maxSigmaIterations);
                fprintf('Current calibrators: %d\n', length(CalibData.Spec));
            end
            
            % Solve linear least squares
            [OptimalParams, Fval, SolverOutput] = solveLinearLeastSquares(CalibData, Config, ...
                                                                          Args.FreeParams, Args.FixedParams, ...
                                                                          AbsorptionData, Args.Regularization, Args.Verbose);
            
            % Update Output with solver results
            Output = SolverOutput;
            
            if Args.Verbose
                fprintf('Linear solution cycle %d completed. Cost: %.4e\n', sigmaIter, Fval);
            end
            
            % Calculate residuals for sigma clipping
            ConfigOptimal = updateConfigWithParams(Config, OptimalParams, Args.FixedParams);
            [~, Residuals, ~] = calculateFieldCorrectionCost(CalibData, ConfigOptimal, AbsorptionData);
            
            % Apply sigma clipping
            [ClippedData, outlierMask] = transmission.utils.sigmaClip(CalibData, ...
                                                                    Residuals, Args.SigmaThreshold);
            
            numOutliers = sum(outlierMask);
            if Args.Verbose
                fprintf('Sigma clipping: removed %d outliers (%.1f%%)\n', ...
                        numOutliers, 100*numOutliers/length(Residuals));
            end
            
            % Check if any outliers were removed
            if numOutliers == 0
                if Args.Verbose
                    fprintf('No outliers found. Sigma clipping converged.\n');
                end
                break;
            end
            
            % Update calibrator data for next iteration
            CalibData = ClippedData;
            
            if Args.Verbose
                fprintf('Remaining calibrators: %d\n', length(CalibData.Spec));
            end
        end
    else
        % Single linear least squares solution without sigma clipping
        [OptimalParams, Fval, SolverOutput] = solveLinearLeastSquares(CalibData, Config, ...
                                                                      Args.FreeParams, Args.FixedParams, ...
                                                                      AbsorptionData, Args.Regularization, Args.Verbose);
        Output = SolverOutput;
    end
    
    % Calculate final residuals and statistics
    ConfigFinal = updateConfigWithParams(Config, OptimalParams, Args.FixedParams);
    [~, FinalResiduals, DiffMag] = calculateFieldCorrectionCost(CalibData, ConfigFinal, AbsorptionData);
    
    % Prepare result data
    ResultData = struct();
    ResultData.CalibData = CalibData;
    ResultData.Residuals = FinalResiduals;
    ResultData.DiffMag = DiffMag;
    ResultData.NumCalibrators = length(CalibData.Spec);
    ResultData.RmsError = sqrt(Fval / ResultData.NumCalibrators);
    
    % Display results
    if Args.Verbose
        fprintf('\n=== LINEAR OPTIMIZATION COMPLETE ===\n');
        fprintf('Optimal parameters:\n');
        paramNames = fieldnames(OptimalParams);
        for i = 1:length(paramNames)
            fprintf('  %s: %.6f\n', paramNames{i}, OptimalParams.(paramNames{i}));
        end
        fprintf('Final cost: %.4e\n', Fval);
        fprintf('RMS error (magnitudes): %.4e\n', ResultData.RmsError);
        if isfield(Output, 'conditionNumber')
            fprintf('Condition number: %.2e\n', Output.conditionNumber);
        end
        fprintf('Status: %s\n', Output.message);
    end
end

%% Helper Functions

function [OptimalParams, Fval, Output] = solveLinearLeastSquares(CalibData, Config, FreeParams, FixedParams, AbsorptionData, regularization, verbose)
    % Solve linear least squares problem for field correction parameters
    
    % Apply transmission to calibrators (without field correction)
    ConfigNoField = Config;
    ConfigNoField.FieldCorrection = struct('kx0', 0, 'ky0', 0, 'kx', 0, 'ky', 0, 'kx2', 0, 'ky2', 0, 'kx3', 0, 'ky3', 0, 'kx4', 0, 'ky4', 0, 'kxy', 0);
    
    [SpecTrans, Wavelength, ~] = transmission.calibrators.applyTransmissionToCalibrators(...
        CalibData.Spec, CalibData.Metadata, ConfigNoField, 'AbsorptionData', AbsorptionData);
    
    % Convert to flux array
    if iscell(SpecTrans)
        TransmittedFluxArray = cell2mat(cellfun(@(x) x(:)', SpecTrans(:,1), 'UniformOutput', false));
    else
        TransmittedFluxArray = SpecTrans;
    end
    
    % Calculate total flux (without field correction)
    TotalFluxBase = transmission.calibrators.calculateTotalFluxCalibrators(...
        Wavelength, TransmittedFluxArray, CalibData.Metadata, ...
        'Norm_', Config.General.Norm_);
    
    % Calculate base magnitude differences (without field correction)
    BaseDiffMag = 2.5 * log10(TotalFluxBase ./ CalibData.LASTData.FLUX_APER_3);
    
    % Build design matrix for field correction parameters
    A = buildDesignMatrix(CalibData.LASTData.X, CalibData.LASTData.Y, FreeParams, Config);
    
    % Target vector: we want to minimize BaseDiffMag + A*coeffs
    % So we solve: A*coeffs = -BaseDiffMag
    b = -BaseDiffMag;
    
    % Add regularization if requested
    if regularization > 0
        nParams = size(A, 2);
        A_reg = [A; sqrt(regularization) * eye(nParams)];
        b_reg = [b; zeros(nParams, 1)];
    else
        A_reg = A;
        b_reg = b;
    end
    
    % Solve linear least squares: coeffs = (A'A + λI)^(-1) A'b
    try
        if verbose
            fprintf('Solving linear system: %d calibrators, %d parameters\n', size(A,1), size(A,2));
        end
        
        % Use MATLAB's backslash operator for robust solution
        coeffs = A_reg \ b_reg;
        
        % Calculate condition number for diagnostics
        condNum = cond(A_reg' * A_reg);
        
        if verbose
            fprintf('Solution found. Condition number: %.2e\n', condNum);
        end
        
        % Convert coefficients back to parameter structure
        OptimalParams = struct();
        for i = 1:length(FreeParams)
            OptimalParams.(FreeParams(i)) = coeffs(i);
        end
        
        % Add fixed parameters
        fixedFields = fieldnames(FixedParams);
        for i = 1:length(fixedFields)
            OptimalParams.(fixedFields{i}) = FixedParams.(fixedFields{i});
        end
        
        % Calculate final cost
        residuals = A * coeffs + BaseDiffMag;
        Fval = sum(residuals.^2);
        
        Output = struct();
        Output.message = 'Linear least squares converged';
        Output.conditionNumber = condNum;
        Output.rank = rank(A_reg);
        Output.iterations = 1;
        Output.funcCount = 1;
        
    catch ME
        if verbose
            fprintf('Linear solver failed: %s\n', ME.message);
        end
        
        % Return default values on failure
        OptimalParams = struct();
        for i = 1:length(FreeParams)
            OptimalParams.(FreeParams(i)) = 0;
        end
        Fval = inf;
        
        Output = struct();
        Output.message = sprintf('Linear solver failed: %s', ME.message);
        Output.conditionNumber = inf;
        Output.rank = 0;
        Output.iterations = 0;
        Output.funcCount = 0;
    end
end

function A = buildDesignMatrix(X, Y, FreeParams, Config)
    % Build design matrix for field correction parameters
    
    nCalib = length(X);
    nParams = length(FreeParams);
    A = zeros(nCalib, nParams);
    
    % Normalize coordinates to [-1, 1] range
    min_coor = Config.Instrumental.Detector.Min_coordinate;
    max_coor = Config.Instrumental.Detector.Max_coordinate;
    lower_bound = Config.Utils.RescaleInputData.Target_min;
    upper_bound = Config.Utils.RescaleInputData.Target_max;
    
    X_norm = transmission.utils.rescaleInputData(X, min_coor, max_coor, lower_bound, upper_bound);
    Y_norm = transmission.utils.rescaleInputData(Y, min_coor, max_coor, lower_bound, upper_bound);
    
    % Build columns for each free parameter
    for i = 1:nParams
        param = FreeParams(i);
        
        switch char(param)
            case 'kx0'
                A(:, i) = ones(nCalib, 1);  % Constant term
            case 'ky0'
                A(:, i) = ones(nCalib, 1);  % Constant term
            case 'kx'
                A(:, i) = X_norm;  % Linear X term
            case 'ky'
                A(:, i) = Y_norm;  % Linear Y term
            case 'kx2'
                A(:, i) = 2*X_norm.^2 - 1;  % Chebyshev T2(x)
            case 'ky2'
                A(:, i) = 2*Y_norm.^2 - 1;  % Chebyshev T2(y)
            case 'kx3'
                A(:, i) = 4*X_norm.^3 - 3*X_norm;  % Chebyshev T3(x)
            case 'ky3'
                A(:, i) = 4*Y_norm.^3 - 3*Y_norm;  % Chebyshev T3(y)
            case 'kx4'
                A(:, i) = 8*X_norm.^4 - 8*X_norm.^2 + 1;  % Chebyshev T4(x)
            case 'ky4'
                A(:, i) = 8*Y_norm.^4 - 8*Y_norm.^2 + 1;  % Chebyshev T4(y)
            case 'kxy'
                A(:, i) = X_norm .* Y_norm;  % Cross term
            otherwise
                error('Unknown field parameter: %s', param);
        end
    end
end

function CalibData = loadCalibratorData(Config)
    % Load calibrator data from catalog
    
    CatalogFile = Config.Data.LAST_catalog_file;
    SearchRadius = Config.Data.Search_radius_arcsec;
    
    [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoords(...
        CatalogFile, SearchRadius);

    CalibData = struct();
    CalibData.Spec = Spec;
    CalibData.Mag = Mag;
    CalibData.Coords = Coords;
    CalibData.LASTData = LASTData;
    CalibData.Metadata = Metadata;
end

function [Cost, Residuals, DiffMag] = calculateFieldCorrectionCost(CalibData, Config, AbsorptionData)
    % Calculate cost function with field corrections applied
    
    % Apply transmission to calibrators
    [SpecTrans, Wavelength, ~] = transmission.calibrators.applyTransmissionToCalibrators(...
        CalibData.Spec, CalibData.Metadata, Config, 'AbsorptionData', AbsorptionData);
    
    % Convert to flux array
    if iscell(SpecTrans)
        TransmittedFluxArray = cell2mat(cellfun(@(x) x(:)', SpecTrans(:,1), 'UniformOutput', false));
    else
        TransmittedFluxArray = SpecTrans;
    end
    
    % Calculate total flux
    TotalFlux = transmission.calibrators.calculateTotalFluxCalibrators(...
        Wavelength, TransmittedFluxArray, CalibData.Metadata, ...
        'Norm_', Config.General.Norm_);
    
    % Apply field correction using fieldCorrection function
    FieldCorrectionMag = transmission.instrumental.fieldCorrection(...
        CalibData.LASTData.X, CalibData.LASTData.Y, Config);
    
    % Calculate magnitude differences with field correction
    DiffMag = 2.5 * log10(TotalFlux ./ CalibData.LASTData.FLUX_APER_3) + FieldCorrectionMag;
    
    % Calculate residuals and cost
    Residuals = DiffMag;
    Cost = sum(DiffMag.^2);
end

function ConfigUpdated = updateConfigWithParams(Config, OptimalParams, FixedParams)
    % Update Config structure with optimized and fixed parameters
    
    ConfigUpdated = Config;
    
    % Apply fixed parameters first
    fixedFields = fieldnames(FixedParams);
    for i = 1:length(fixedFields)
        ConfigUpdated.FieldCorrection.(fixedFields{i}) = FixedParams.(fixedFields{i});
    end
    
    % Apply optimized parameters
    optimalFields = fieldnames(OptimalParams);
    for i = 1:length(optimalFields)
        ConfigUpdated.FieldCorrection.(optimalFields{i}) = OptimalParams.(optimalFields{i});
    end
end