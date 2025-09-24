function [OptimalParams, Fval, ExitFlag, Output, ResultData] = minimizerLinearLeastSquares_alt(Config, Args)
    % Linear least squares minimizer for field correction parameters
    % Optimized for Chebyshev coefficients using closed-form solution
    %
    % Improvements:
    %  - Removed duplicate "kx" from FreeParams
    %  - Separated residual RMS vs penalized RMS
    %  - Refined ExitFlag reporting
    
    arguments
        Config = transmissionFast.inputConfig()
        Args.FreeParams string = ["kx0", "ky0", "kx", "ky", ...
                                  "kx2", "ky2", "kx3", "ky3", ...
                                  "kx4", "ky4", "kxy"]  % Default: basic field correction
        Args.FixedParams struct = struct()
        Args.InitialValues struct = struct()  % Ignored for linear solver
        Args.SigmaClipping logical = false
        Args.SigmaThreshold double = 2.0
        Args.SigmaIterations double = 3
        Args.UsePythonFieldModel logical = true
        Args.UseChebyshev logical = false
        Args.ChebyshevOrder double = 4
        Args.InputData = []
        Args.Verbose logical = false
        Args.Regularization double = 0
    end
    
    % Validate free parameters
    validFieldParams = ["kx0", "kx", "ky", "kx2", "ky2", ...
                        "kx3", "ky3", "kx4", "ky4", "kxy"];
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
        fprintf('Note: Linear solver always uses Python-like Chebyshev field model for field corrections\n\n');
    end
    
    % Load calibrator data
    if ~isempty(Args.InputData)
        CalibData = Args.InputData;
        if Args.Verbose
            fprintf('Using provided calibrator data\n');
        end
    else
        error('No calibrator data provided. Use InputData parameter to pass pre-loaded calibrator data.');
    end
    
    if isempty(CalibData.Spec)
        error('No calibrators found. Check catalog file and search parameters.');
    end
    
    if Args.Verbose
        fprintf('Found %d calibrators\n', length(CalibData.Spec));
    end
    
    % Initialize results
    ExitFlag = 1; % 1 = success, 2 = sigma clipping removed outliers, 0 = failure
    Output = struct();
    Output.message = 'Linear least squares solution';
    Output.iterations = 1;
    Output.funcCount = 1;
    
    % Sigma clipping outer loop
    if Args.SigmaClipping
        % Initialize current configuration
        ConfigCurrent = Config;

        maxSigmaIterations = Args.SigmaIterations;
        if Args.Verbose
            fprintf('Using iterative sigma clipping: %d cycles\n', maxSigmaIterations);
        end

        for sigmaIter = 1:maxSigmaIterations
            if Args.Verbose
                fprintf('\n=== SIGMA CLIPPING CYCLE %d/%d ===\n', sigmaIter, maxSigmaIterations);
                fprintf('Current calibrators: %d\n', length(CalibData.Spec));
            end

            % Solve linear least squares with current configuration
            [OptimalParams, Fval, SolverOutput] = transmissionFast.utils.linearFieldCorrection_alt(CalibData, ConfigCurrent, ...
                Args.FreeParams, Args.FixedParams, ...
                'Regularization', Args.Regularization, ...
                'Verbose', Args.Verbose);
            
            Output = SolverOutput;
            
            if Args.Verbose
                fprintf('Linear solution cycle %d completed. Cost: %.4e\n', sigmaIter, Fval);
            end
            
            % Compute residuals
            ConfigOptimal = updateConfigWithParams(ConfigCurrent, OptimalParams, Args.FixedParams);
            ConfigCurrent = ConfigOptimal;  % Update configuration for next iteration
            [~, Residuals, ~] = transmissionFast.calculateCostFunction(CalibData, ConfigOptimal, ...
                'UsePythonFieldModel', true);
            
            % Apply sigma clipping
            [ClippedData, outlierMask] = transmissionFast.utils.sigmaClip(CalibData, ...
                                                        Residuals, Args.SigmaThreshold);
            numOutliers = sum(outlierMask);
            if Args.Verbose
                fprintf('Sigma clipping: removed %d outliers (%.1f%%)\n', ...
                        numOutliers, 100*numOutliers/length(Residuals));
            end
            
            if numOutliers == 0
                if Args.Verbose
                    fprintf('No outliers found. Sigma clipping converged.\n');
                end
                break;
            else
                ExitFlag = 2; % success, but with outlier removal
            end
            
            CalibData = ClippedData;
            if Args.Verbose
                fprintf('Remaining calibrators: %d\n', length(CalibData.Spec));
            end
        end
    else
        % Single solution without sigma clipping
        [OptimalParams, Fval, SolverOutput] = transmissionFast.utils.linearFieldCorrection_alt(CalibData, Config, ...
            Args.FreeParams, Args.FixedParams, ...
            'Regularization', Args.Regularization, ...
            'Verbose', Args.Verbose);
        Output = SolverOutput;
    end
    
    % Final residuals and statistics
    ConfigFinal = updateConfigWithParams(Config, OptimalParams, Args.FixedParams);
    [~, FinalResiduals, DiffMag] = transmissionFast.calculateCostFunction(CalibData, ConfigFinal, ...
        'UsePythonFieldModel', true);
    
    ResultData = struct();
    ResultData.CalibData = CalibData;
    ResultData.Residuals = FinalResiduals;
    ResultData.DiffMag = DiffMag;
    ResultData.NumCalibrators = length(CalibData.Spec);
    ResultData.RmsResidual = sqrt(sum(FinalResiduals.^2) / ResultData.NumCalibrators); % fit only
    ResultData.RmsError = sqrt(Fval / ResultData.NumCalibrators); % fit + penalty
    
    % Display results
    if Args.Verbose
        fprintf('\n=== LINEAR OPTIMIZATION COMPLETE ===\n');
        fprintf('Optimal parameters:\n');
        paramNames = fieldnames(OptimalParams);
        for i = 1:length(paramNames)
            fprintf('  %s: %.6f\n', paramNames{i}, OptimalParams.(paramNames{i}));
        end
        fprintf('Final cost (with penalty): %.4e\n', Fval);
        fprintf('RMS residual (magnitudes): %.4e\n', ResultData.RmsResidual);
        if Args.Regularization > 0
            fprintf('RMS error (with penalty): %.4e\n', ResultData.RmsError);
        end
        if isfield(Output, 'conditionNumber')
            fprintf('Condition number: %.2e\n', Output.conditionNumber);
        end
        fprintf('Status: %s (ExitFlag=%d)\n', Output.message, ExitFlag);
    end
end

%% Helper Functions

function ConfigUpdated = updateConfigWithParams(Config, OptimalParams, FixedParams)
    % Update Config structure with optimized and fixed parameters
    ConfigUpdated = Config;
    
    fixedFields = fieldnames(FixedParams);
    for i = 1:length(fixedFields)
        ConfigUpdated.FieldCorrection.(fixedFields{i}) = FixedParams.(fixedFields{i});
    end
    
    optimalFields = fieldnames(OptimalParams);
    for i = 1:length(optimalFields)
        ConfigUpdated.FieldCorrection.(optimalFields{i}) = OptimalParams.(optimalFields{i});
    end
end
