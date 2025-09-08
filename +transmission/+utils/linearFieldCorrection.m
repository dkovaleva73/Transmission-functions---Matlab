function [OptimalParams, Fval, Output] = linearFieldCorrection(CalibData, Config, FreeParams, FixedParams, Args)
    % Linear least squares solver for field correction parameters
    % Core mathematical algorithm for optimizing Python-like Chebyshev coefficients
    %
    % Input:  - CalibData - Structure with calibrator data
    %         - Config - Configuration structure  
    %         - FreeParams - Array of parameter names to optimize
    %         - FixedParams - Structure with fixed parameter values
    %         - Args - Optional arguments:
    %           'AbsorptionData' - Pre-loaded absorption data
    %           'Regularization' - L2 regularization parameter (default: 0)
    %           'Verbose' - Enable verbose output (default: false)
    %
    % Output: - OptimalParams - Structure with optimal parameter values
    %         - Fval - Final cost function value (sum of squared residuals)
    %         - Output - Solution details (condition number, rank, etc.)
    %
    % Author: D. Kovaleva (Sep 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50
    
    arguments
        CalibData struct
        Config struct
        FreeParams string
        FixedParams struct = struct()
        Args.AbsorptionData = Config.AbsorptionData
        Args.Regularization double = 0
        Args.Verbose logical = false
    end
    
    % Extract arguments
    AbsorptionData = Args.AbsorptionData;
    regularization = Args.Regularization;
    verbose = Args.Verbose;
    
    % Calculate base magnitude differences (without field correction) using shared function
    ConfigNoField = Config;
    ConfigNoField.FieldCorrection = struct('kx0', 0, 'ky0', 0, 'kx', 0, 'ky', 0, 'kx2', 0, 'ky2', 0, 'kx3', 0, 'ky3', 0, 'kx4', 0, 'ky4', 0, 'kxy', 0);
    
    [~, ~, BaseDiffMag] = transmission.calculateCostFunction(CalibData, ConfigNoField, ...
        'AbsorptionData', AbsorptionData, ...
        'UsePythonFieldModel', true);
    
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

%% Helper Functions

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
                A(:, i) = ones(nCalib, 1);
            case 'ky0'
                A(:, i) = ones(nCalib, 1);
            case 'kx'
                A(:, i) = X_norm;
            case 'ky'
                A(:, i) = Y_norm;
            case 'kx2'
                A(:, i) = evaluateChebyshev(X_norm, 2);
            case 'ky2'
                A(:, i) = evaluateChebyshev(Y_norm, 2);
            case 'kx3'
                A(:, i) = evaluateChebyshev(X_norm, 3);
            case 'ky3'
                A(:, i) = evaluateChebyshev(Y_norm, 3);
            case 'kx4'
                A(:, i) = evaluateChebyshev(X_norm, 4);
            case 'ky4'
                A(:, i) = evaluateChebyshev(Y_norm, 4);
            case 'kxy'
                A(:, i) = X_norm .* Y_norm;
            otherwise
                error('Unknown field correction parameter: %s', param);
        end
    end
end

function T = evaluateChebyshev(x, n)
    % Evaluate Chebyshev polynomial of order n
    % T_0(x) = 1, T_1(x) = x, T_2(x) = 2x^2-1, T_3(x) = 4x^3-3x, T_4(x) = 8x^4-8x^2+1
    
    switch n
        case 0
            T = ones(size(x));
        case 1
            T = x;
        case 2
            T = 2*x.^2 - 1;
        case 3
            T = 4*x.^3 - 3*x;
        case 4
            T = 8*x.^4 - 8*x.^2 + 1;
        otherwise
            error('Chebyshev polynomial order %d not implemented', n);
    end
end

