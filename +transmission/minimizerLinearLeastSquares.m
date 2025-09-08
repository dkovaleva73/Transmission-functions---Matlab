function [OptimalParams, Fval, ExitFlag, Output, ResultData] = minimizerLinearLeastSquares(Config, Args)
    % Linear least squares minimizer for field correction parameters
    % Optimized for Chebyshev coefficients using closed-form solution
    % Input :  - Config - Configuration structure from transmission.inputConfig()
    %          - Args - Optional arguments:
    %           'FreeParams' - Cell array of parameter names to optimize (must be field correction params)
    %           'FixedParams' - Structure with fixed parameter values (overrides Config)
    %           'InitialValues' - Structure with initial values (ignored for linear solver)
    %           'SigmaClipping' - Enable sigma clipping (default: false)
    %           'SigmaThreshold' - Threshold for sigma clipping (default: 3.0)
    %           'SigmaIterations' - Number of sigma clipping iterations (default: 3)
    %           'InputData' - Pre-loaded calibrator data (optional)
    %           'Verbose' - Enable verbose output (default: false)
    %           'Regularization' - L2 regularization parameter (default: 0)
    % Output : - OptimalParams - Structure with optimal parameter values
    %          - Fval - Final value of cost function (sum of squared residuals)
    %          - ExitFlag - Exit condition (1=success, 0=failed)
    %          - Output - Solution details
    %          - ResultData - Structure with calibrator data and residuals
    % Author: D. Kovaleva (Aug 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50
    % Example:   Config = transmission.inputConfig();
    %            [OptimalParams, Fval] = transmission.minimizerLinearLeastSquares(Config, ...
    %               'FreeParams', ["kx0", "kx", "ky", "kx2", "ky2"]);
    
    arguments
        Config = transmission.inputConfig()
        Args.FreeParams string = ["kx0", "kx", "ky"]  % Default: basic field correction
        Args.FixedParams struct = struct()
        Args.InitialValues struct = struct()  % Ignored for linear solver
        Args.SigmaClipping logical = false
        Args.SigmaThreshold double = 3.0
        Args.SigmaIterations double = 3
        Args.UsePythonFieldModel logical = true  % Always use Python-like Chebyshev field model for field corrections
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
        fprintf('Note: Linear solver always uses Python-like Chebyshev field model for field corrections\n');
        fprintf('\n');
    end
    
    % Use provided calibrator data
    if ~isempty(Args.InputData)
        CalibData = Args.InputData;
        if Args.Verbose
            fprintf('Using provided calibrator data\n');
        end
    else
        error('No calibrator data provided. Use InputData parameter to pass pre-loaded calibrator data.');
    end
    
    % Validate we have data
    if isempty(CalibData.Spec)
        error('No calibrators found. Check catalog file and search parameters.');
    end
    
    if Args.Verbose
        fprintf('Found %d calibrators\n', length(CalibData.Spec));
    end
    
    % Absorption data is available in Config.AbsorptionData (cached during inputConfig)
    
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
            
            % Solve linear least squares using utility function
            [OptimalParams, Fval, SolverOutput] = transmission.utils.linearFieldCorrection(CalibData, Config, ...
                Args.FreeParams, Args.FixedParams, ...
                'Regularization', Args.Regularization, ...
                'Verbose', Args.Verbose);
            
            % Update Output with solver results
            Output = SolverOutput;
            
            if Args.Verbose
                fprintf('Linear solution cycle %d completed. Cost: %.4e\n', sigmaIter, Fval);
            end
            
            % Calculate residuals for sigma clipping
            ConfigOptimal = updateConfigWithParams(Config, OptimalParams, Args.FixedParams);
            [~, Residuals, ~] = transmission.calculateCostFunction(CalibData, ConfigOptimal, ...
                'UsePythonFieldModel', true);
            
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
        % Single linear least squares solution without sigma clipping using utility function
        [OptimalParams, Fval, SolverOutput] = transmission.utils.linearFieldCorrection(CalibData, Config, ...
            Args.FreeParams, Args.FixedParams, ...
            'Regularization', Args.Regularization, ...
            'Verbose', Args.Verbose);
        Output = SolverOutput;
    end
    
    % Calculate final residuals and statistics
    ConfigFinal = updateConfigWithParams(Config, OptimalParams, Args.FixedParams);
    [~, FinalResiduals, DiffMag] = transmission.calculateCostFunction(CalibData, ConfigFinal, ...
        'UsePythonFieldModel', true);
    
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