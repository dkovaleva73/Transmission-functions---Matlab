function [OptimalParams, Fval, Output] = linearFieldCorrection_alt(CalibData, Config, FreeParams, FixedParams, Args)
    % Linear least squares solver for field correction parameters
    % (optimizing Python-like Chebyshev coefficients)
    %
    % Improvements:
    %  - Avoid duplicate constant terms (kx0/ky0 merged to 'kx0')
    %  - Use lsqminnorm for robust least squares (handles rank-deficiency)
    %  - Condition number computed on A, not normal equations
    %  - Cost Fval includes regularization penalty

    arguments
        CalibData struct
        Config struct
        FreeParams string
        FixedParams struct = struct()
        Args.Regularization double = 0
        Args.Verbose logical = false
    end

    % Extract arguments
    lambda = Args.Regularization;
    verbose = Args.Verbose;

    % Calculate base magnitude differences (no field correction)
    ConfigNoField = Config;
    ConfigNoField.FieldCorrection = struct('kx0',0,'kx',0,'ky',0,'kx2',0,'ky2',0,'kx3',0,'ky3',0,'kx4',0,'ky4',0,'kxy',0);

    [~, ~, BaseDiffMag] = transmissionFast.calculateCostFunction(CalibData, ConfigNoField, ...
        'UsePythonFieldModel', true);

    % Build design matrix for field correction parameters
    A = buildDesignMatrix(CalibData.LASTData.X, CalibData.LASTData.Y, FreeParams, Config);

    % Target vector: A*coeffs ≈ -BaseDiffMag
    b = -BaseDiffMag;

    try
        if verbose
            fprintf('Solving linear system: %d calibrators, %d parameters\n', size(A,1), size(A,2));
        end

        % Solve with Tikhonov regularization
        if lambda > 0
            % Equivalent to (A'*A + λI) c = A'*b
            coeffs = (A' * A + lambda * eye(size(A,2))) \ (A' * b);
        else
            % Rank-deficient safe solver
            coeffs = lsqminnorm(A, b);
        end

        % Condition number (diagnostic)
        condNum = cond(A);

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

        % Calculate final cost (include penalty if lambda>0)
        residuals = A * coeffs;
        residuals = residuals + BaseDiffMag;
        Fval = sum(residuals.^2) + lambda * sum(coeffs.^2);

        Output = struct();
        Output.message = 'Linear least squares converged';
        Output.conditionNumber = condNum;
        Output.rank = rank(A);
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

%% Helper function

function A = buildDesignMatrix(X, Y, FreeParams, Config)
    % Build design matrix for field correction parameters
    nCalib = length(X);
    nParams = length(FreeParams);
    A = zeros(nCalib, nParams);

    % Normalize coordinates to [-1, 1]
    min_coor = Config.Instrumental.Detector.Min_coordinate;
    max_coor = Config.Instrumental.Detector.Max_coordinate;
    lower_bound = Config.Utils.RescaleInputData.Target_min;
    upper_bound = Config.Utils.RescaleInputData.Target_max;

    X_norm = transmissionFast.utils.rescaleInputData(X, min_coor, max_coor, lower_bound, upper_bound);
    Y_norm = transmissionFast.utils.rescaleInputData(Y, min_coor, max_coor, lower_bound, upper_bound);

    % Build columns for each free parameter
    for i = 1 : nParams
        param = FreeParams(i);
        switch char(param)
            case 'kx0'
                A(:, i) = ones(nCalib, 1);
            case 'kx'
                A(:, i) = X_norm;
            case 'ky'
                A(:, i) = Y_norm;
            case 'kx2'
                A(:, i) = transmissionFast.utils.evaluateChebyshevPolynomial(X_norm, 2);
            case 'ky2'
                A(:, i) = transmissionFast.utils.evaluateChebyshevPolynomial(Y_norm, 2);
            case 'kx3'
                A(:, i) = transmissionFast.utils.evaluateChebyshevPolynomial(X_norm, 3);
            case 'ky3'
                A(:, i) = transmissionFast.utils.evaluateChebyshevPolynomial(Y_norm, 3);
            case 'kx4'
                A(:, i) = transmissionFast.utils.evaluateChebyshevPolynomial(X_norm, 4);
            case 'ky4'
                A(:, i) = transmissionFast.utils.evaluateChebyshevPolynomial(Y_norm, 4);
            case 'kxy'
                A(:, i) = X_norm .* Y_norm;
            otherwise
                error('Unknown field correction parameter: %s', param);
        end
    end
end
