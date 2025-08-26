function [OptimalParams, Fval, ExitFlag, Output, ResultData] = minimizerFminGeneric(Config, Args)
    % Generic minimizer using fminsearch (simplex method) with configurable parameters
    % This is a generative version that can optimize any subset of transmission parameters
    % 
    % Input:  - Config - Configuration structure from transmission.inputConfig()
    %         - Args - Optional arguments:
    %           'FreeParams' - Cell array of parameter names to optimize
    %           'FixedParams' - Structure with fixed parameter values (overrides Config)
    %           'InitialValues' - Structure with initial values for free parameters
    %           'Bounds' - Structure with .Lower and .Upper bounds for parameters
    %           'SigmaClipping' - Enable sigma clipping (default: false)
    %           'SigmaThreshold' - Threshold for sigma clipping (default: 3.0)
    %           'SigmaIterations' - Number of sigma clipping iterations (default: 3)
    %           'UseChebyshev' - Enable Chebyshev field corrections (default: false)
    %           'ChebyshevOrder' - Order of Chebyshev polynomials (default: 4)
    %           'InputData' - Pre-loaded calibrator data (optional)
    %           'Verbose' - Enable verbose output (default: false)
    %           'PlotResults' - Plot optimization progress (default: false)
    %           'SaveResults' - Save optimization results (default: false)
    %
    % Output: - OptimalParams - Structure with optimal parameter values
    %         - Fval - Final value of cost function
    %         - ExitFlag - Exit condition from fminsearch
    %         - Output - Optimization details from fminsearch
    %         - ResultData - Structure with calibrator data and residuals
    %
    % Author: D. Kovaleva (Aug 2025)
    % Example:
    %   Config = transmission.inputConfig();
    %   [OptimalParams, Fval] = transmission.minimizerFminGeneric(Config, ...
    %       'FreeParams', ["Norm_", "Tau_aod500"], ...
    %       'FixedParams', struct('Pwv_cm', 2.0));
    
    arguments
        Config = transmission.inputConfig()
        Args.FreeParams string = ["Norm_"]  % Default: optimize normalization only
        Args.FixedParams struct = struct()
        Args.InitialValues struct = struct()
        Args.Bounds struct = struct()
        Args.SigmaClipping logical = false
        Args.SigmaThreshold double = 3.0
        Args.SigmaIterations double = 3
        Args.UseChebyshev logical = false
        Args.ChebyshevOrder double = 4
        Args.InputData = []  % Optional pre-loaded data
        Args.Verbose logical = false
        Args.PlotResults logical = false
        Args.SaveResults logical = false
    end
    
    % Extract arguments
    FreeParams = Args.FreeParams;
    FixedParams = Args.FixedParams;
    InitialValues = Args.InitialValues;
    Verbose = Args.Verbose;
    PlotResults = Args.PlotResults;
    SaveResults = Args.SaveResults;
    
    if Verbose
        fprintf('=== GENERIC TRANSMISSION MINIMIZER (fminsearch) ===\n');
        fprintf('Free parameters: %s\n', strjoin(FreeParams, ', '));
        fprintf('Fixed parameters: %d\n', numel(fieldnames(FixedParams)));
        if Args.SigmaClipping
            fprintf('Sigma clipping: Enabled (threshold=%.1f, iterations=%d)\n', ...
                    Args.SigmaThreshold, Args.SigmaIterations);
        end
        if Args.UseChebyshev
            fprintf('Chebyshev field corrections: Enabled (order=%d)\n', Args.ChebyshevOrder);
        end
        fprintf('\n');
    end
    
    % Store iteration history for plotting
    IterationHistory = struct('ParamValues', [], 'CostValues', []);
    IterCount = 0;
    
    % Prepare parameter mapping
    ParamMapping = prepareParameterMapping(Config, FreeParams, FixedParams, InitialValues, Args.Bounds);
    
    % Load or prepare calibrator data
    if ~isempty(Args.InputData)
        CalibData = Args.InputData;
        if Verbose
            fprintf('Using provided calibrator data\n');
        end
    else
        if Verbose
            fprintf('Loading calibrator data...\n');
        end
        CalibData = loadCalibratorData(Config);
    end
    
    % Validate we have data
    if isempty(CalibData.Spec)
        error('No calibrators found. Check catalog file and search parameters.');
    end
    
    if Verbose
        fprintf('Found %d calibrators\n', length(CalibData.Spec));
    end
    
    % Preload absorption data for efficiency
    if Verbose
        fprintf('Preloading absorption data...\n');
    end
    AllSpecies = {'H2O', 'O3UV', 'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4', ...
                  'NH3', 'NO', 'NO2', 'SO2U', 'SO2I', 'HNO3', 'NO3', 'HNO2', ...
                  'CH2O', 'BrO', 'ClNO'};
    AbsorptionData = transmission.data.loadAbsorptionData([], AllSpecies, false);
    
    % Setup Chebyshev model if requested (will be updated during sigma clipping)
    if Args.UseChebyshev
        ChebyshevModel = setupChebyshevModel(CalibData, Args.ChebyshevOrder);
    else
        ChebyshevModel = [];
    end
    
    % Store original calibrator data for sigma clipping
    OriginalCalibData = CalibData;
    
    % Define the simple objective function (no sigma clipping inside)
    function Cost = objective(ParamVector)
        IterCount = IterCount + 1;
        
        % Convert parameter vector to Config structure
        ConfigLocal = updateConfigFromVector(Config, ParamVector, ParamMapping);
        
        try
            % Calculate cost with current calibrator data
            [Cost, Residuals, ~] = calculateCostFunction(CalibData, ConfigLocal, ...
                                                      AbsorptionData, ChebyshevModel);
            
            % Store iteration history
            IterationHistory.ParamValues(end+1, :) = ParamVector;
            IterationHistory.CostValues(end+1) = Cost;
            
            if Verbose && mod(IterCount, 10) == 1
                fprintf('  Iter %3d: Cost = %.4e, RMS = %.4e, Calibs = %d\n', ...
                        IterCount, Cost, sqrt(Cost/length(Residuals)), length(CalibData.Spec));
            end
            
        catch ME
            if Verbose
                fprintf('  ERROR in iteration %d: %s\n', IterCount, ME.message);
            end
            Cost = 1e20;  % Return large cost if error occurs
        end
    end
    
    % Set optimization options
    Options = optimset('Display', 'iter', ...
                      'TolX', 1e-4, ...
                      'TolFun', 1e-6, ...
                      'MaxIter', 200, ...
                      'MaxFunEvals', 500);
    
    if ~Verbose
        Options = optimset(Options, 'Display', 'off');
    end
    
    if Verbose
        fprintf('\nStarting optimization...\n');
    end
    
    tic;
    InitialVector = ParamMapping.InitialVector;
    
    % Sigma clipping outer loop: optimize → sigma clip → repeat (up to 3 times)
    if Args.SigmaClipping
        maxSigmaIterations = Args.SigmaIterations;
        if Verbose
            fprintf('Using iterative sigma clipping: %d cycles\n', maxSigmaIterations);
        end
        
        for sigmaIter = 1:maxSigmaIterations
            if Verbose
                fprintf('\n=== SIGMA CLIPPING CYCLE %d/%d ===\n', sigmaIter, maxSigmaIterations);
                fprintf('Current calibrators: %d\n', length(CalibData.Spec));
            end
            
            % Run complete optimization cycle
            if ~isempty(fieldnames(Args.Bounds))
                objectiveBounded = @(x) objective(applyBounds(x, ParamMapping));
                [OptimalVector, Fval, ExitFlag, Output] = fminsearch(objectiveBounded, ...
                                                                     transformToBounded(InitialVector, ParamMapping), ...
                                                                     Options);
                OptimalVector = applyBounds(OptimalVector, ParamMapping);
            else
                [OptimalVector, Fval, ExitFlag, Output] = fminsearch(@objective, InitialVector, Options);
            end
            
            if Verbose
                fprintf('Optimization cycle %d completed. Cost: %.4e\n', sigmaIter, Fval);
            end
            
            % Calculate residuals with optimal parameters
            ConfigOptimal = updateConfigFromVector(Config, OptimalVector, ParamMapping);
            [~, Residuals, ~] = calculateCostFunction(CalibData, ConfigOptimal, ...
                                                      AbsorptionData, ChebyshevModel);
            
            % Apply sigma clipping
            [ClippedData, outlierMask] = transmission.utils.sigmaClip(CalibData, ...
                                                                    Residuals, Args.SigmaThreshold);
            
            numOutliers = sum(outlierMask);
            if Verbose
                fprintf('Sigma clipping: removed %d outliers (%.1f%%)\n', ...
                        numOutliers, 100*numOutliers/length(Residuals));
            end
            
            % Check if any outliers were removed
            if numOutliers == 0
                if Verbose
                    fprintf('No outliers found. Sigma clipping converged.\n');
                end
                break;
            end
            
            % Update calibrator data for next iteration
            CalibData = ClippedData;
            
            % Update Chebyshev model if using field corrections
            if Args.UseChebyshev
                ChebyshevModel = setupChebyshevModel(CalibData, Args.ChebyshevOrder);
            end
            
            % Use current optimal parameters as starting point for next cycle
            InitialVector = OptimalVector;
            
            if Verbose
                fprintf('Remaining calibrators: %d\n', length(CalibData.Spec));
            end
        end
    else
        % Single optimization without sigma clipping
        if ~isempty(fieldnames(Args.Bounds))
            objectiveBounded = @(x) objective(applyBounds(x, ParamMapping));
            [OptimalVector, Fval, ExitFlag, Output] = fminsearch(objectiveBounded, ...
                                                                 transformToBounded(InitialVector, ParamMapping), ...
                                                                 Options);
            OptimalVector = applyBounds(OptimalVector, ParamMapping);
        else
            [OptimalVector, Fval, ExitFlag, Output] = fminsearch(@objective, InitialVector, Options);
        end
    end
    
    OptimizationTime = toc;
    
    % Convert optimal vector back to parameter structure
    OptimalParams = vectorToParamStruct(OptimalVector, ParamMapping);
    
    % Calculate final residuals and statistics
    ConfigFinal = updateConfigFromVector(Config, OptimalVector, ParamMapping);
    [~, FinalResiduals, DiffMag] = calculateCostFunction(CalibData, ConfigFinal, ...
                                                         AbsorptionData, ChebyshevModel);
    
    % Prepare result data
    ResultData = struct();
    ResultData.CalibData = CalibData;
    ResultData.Residuals = FinalResiduals;
    ResultData.DiffMag = DiffMag;
    ResultData.NumCalibrators = length(CalibData.Spec);
    ResultData.RmsError = sqrt(Fval / ResultData.NumCalibrators);
    
    % Display results
    if Verbose
        fprintf('\n=== OPTIMIZATION COMPLETE ===\n');
        fprintf('Optimal parameters:\n');
        paramNames = fieldnames(OptimalParams);
        for i = 1:length(paramNames)
            fprintf('  %s: %.6f\n', paramNames{i}, OptimalParams.(paramNames{i}));
        end
        fprintf('Final cost: %.4e\n', Fval);
        fprintf('RMS error (magnitudes): %.4e\n', ResultData.RmsError);
        fprintf('Exit flag: %d\n', ExitFlag);
        fprintf('Iterations: %d\n', Output.iterations);
        fprintf('Function evaluations: %d\n', Output.funcCount);
        fprintf('Time elapsed: %.2f seconds\n', OptimizationTime);
        
        if ExitFlag == 1
            fprintf('Status: Converged successfully\n');
        elseif ExitFlag == 0
            fprintf('Status: Maximum iterations reached\n');
        else
            fprintf('Status: Did not converge\n');
        end
    end
    
    % Plot results if requested
    if PlotResults && ~isempty(IterationHistory.CostValues)
        plotOptimizationProgress(IterationHistory, ParamMapping, OptimalVector);
    end
    
    % Save results if requested
    if SaveResults
        saveOptimizationResults(OptimalParams, Fval, ExitFlag, Output, ...
                               ResultData, IterationHistory, Config, OptimizationTime);
    end
end

%% Helper Functions

function ParamMapping = prepareParameterMapping(Config, FreeParams, FixedParams, InitialValues, Bounds)
    % Create mapping between parameter vector and Config structure
    
    ParamMapping = struct();
    ParamMapping.Names = FreeParams;
    ParamMapping.NumParams = length(FreeParams);
    ParamMapping.InitialVector = zeros(ParamMapping.NumParams, 1);
    ParamMapping.ConfigPaths = cell(ParamMapping.NumParams, 1);
    ParamMapping.FixedParams = FixedParams;
    
    % Map each free parameter to its Config path
    for i = 1:ParamMapping.NumParams
        paramName = FreeParams(i);
        [configPath, defaultValue] = getParameterPath(paramName, Config);
        ParamMapping.ConfigPaths{i} = configPath;
        
        % Set initial value
        if isfield(InitialValues, paramName)
            ParamMapping.InitialVector(i) = InitialValues.(paramName);
        elseif isfield(FixedParams, paramName)
            ParamMapping.InitialVector(i) = FixedParams.(paramName);
        else
            ParamMapping.InitialVector(i) = defaultValue;
        end
    end
    
    % Store bounds if provided
    if ~isempty(fieldnames(Bounds))
        ParamMapping.LowerBounds = zeros(ParamMapping.NumParams, 1);
        ParamMapping.UpperBounds = ones(ParamMapping.NumParams, 1);
        
        for i = 1:ParamMapping.NumParams
            paramName = FreeParams(i);
            if isfield(Bounds.Lower, paramName)
                ParamMapping.LowerBounds(i) = Bounds.Lower.(paramName);
            else
                ParamMapping.LowerBounds(i) = -Inf;
            end
            if isfield(Bounds.Upper, paramName)
                ParamMapping.UpperBounds(i) = Bounds.Upper.(paramName);
            else
                ParamMapping.UpperBounds(i) = Inf;
            end
        end
    end
end

function [configPath, defaultValue] = getParameterPath(paramName, Config)
    % Map parameter names to Config structure paths
    
    switch char(paramName)
        case 'Norm_'
            configPath = 'General.Norm_';
            defaultValue = Config.General.Norm_;
        case 'Tau_aod500'
            configPath = 'Atmospheric.Components.Aerosol.Tau_aod500';
            defaultValue = Config.Atmospheric.Components.Aerosol.Tau_aod500;
        case 'Alpha'
            configPath = 'Atmospheric.Components.Aerosol.Angstrom_exponent';
            defaultValue = Config.Atmospheric.Components.Aerosol.Angstrom_exponent;
        case 'Pwv_cm'
            configPath = 'Atmospheric.Components.Water.Pwv_cm';
            defaultValue = Config.Atmospheric.Components.Water.Pwv_cm;
        case 'Dobson_units'
            configPath = 'Atmospheric.Components.Ozone.Dobson_units';
            defaultValue = Config.Atmospheric.Components.Ozone.Dobson_units;
        case 'Temperature_C'
            configPath = 'Atmospheric.Temperature_C';
            defaultValue = Config.Atmospheric.Temperature_C;
        case 'Pressure'
            configPath = 'Atmospheric.Pressure';
            defaultValue = Config.Atmospheric.Pressure;
        case 'Center'
            configPath = 'Utils.SkewedGaussianModel.Default_center';
            defaultValue = Config.Utils.SkewedGaussianModel.Default_center;
        case 'Amplitude'
            configPath = 'Utils.SkewedGaussianModel.Default_amplitude';
            defaultValue = Config.Utils.SkewedGaussianModel.Default_amplitude;
        case 'Sigma'
            configPath = 'Utils.SkewedGaussianModel.Default_sigma';
            defaultValue = Config.Utils.SkewedGaussianModel.Default_sigma;
        case 'Gamma'
            configPath = 'Utils.SkewedGaussianModel.Default_gamma';
            defaultValue = Config.Utils.SkewedGaussianModel.Default_gamma;
        % Chebyshev coefficients for field corrections
        case 'cx0'
            configPath = 'FieldCorrection.Chebyshev.X.c0';
            defaultValue = 0;
        case 'cx1'
            configPath = 'FieldCorrection.Chebyshev.X.c1';
            defaultValue = 0;
        case 'cx2'
            configPath = 'FieldCorrection.Chebyshev.X.c2';
            defaultValue = 0;
        case 'cx3'
            configPath = 'FieldCorrection.Chebyshev.X.c3';
            defaultValue = 0;
        case 'cx4'
            configPath = 'FieldCorrection.Chebyshev.X.c4';
            defaultValue = 0;
        case 'cy0'
            configPath = 'FieldCorrection.Chebyshev.Y.c0';
            defaultValue = 0;
        case 'cy1'
            configPath = 'FieldCorrection.Chebyshev.Y.c1';
            defaultValue = 0;
        case 'cy2'
            configPath = 'FieldCorrection.Chebyshev.Y.c2';
            defaultValue = 0;
        case 'cy3'
            configPath = 'FieldCorrection.Chebyshev.Y.c3';
            defaultValue = 0;
        case 'cy4'
            configPath = 'FieldCorrection.Chebyshev.Y.c4';
            defaultValue = 0;
        otherwise
            error('Unknown parameter: %s', paramName);
    end
end

function ConfigLocal = updateConfigFromVector(Config, ParamVector, ParamMapping)
    % Update Config structure with values from parameter vector
    
    ConfigLocal = Config;
    
    % Apply fixed parameters first
    fixedFields = fieldnames(ParamMapping.FixedParams);
    for i = 1:length(fixedFields)
        [configPath, ~] = getParameterPath(fixedFields{i}, Config);
        pathParts = strsplit(configPath, '.');
        ConfigLocal = setfield(ConfigLocal, pathParts{:}, ...
                              ParamMapping.FixedParams.(fixedFields{i}));
    end
    
    % Apply free parameters from vector
    for i = 1:ParamMapping.NumParams
        pathParts = strsplit(ParamMapping.ConfigPaths{i}, '.');
        ConfigLocal = setfield(ConfigLocal, pathParts{:}, ParamVector(i));
    end
end

function params = vectorToParamStruct(ParamVector, ParamMapping)
    % Convert parameter vector to structure
    
    params = struct();
    for i = 1:ParamMapping.NumParams
        params.(ParamMapping.Names{i}) = ParamVector(i);
    end
    
    % Add fixed parameters
    fixedFields = fieldnames(ParamMapping.FixedParams);
    for i = 1:length(fixedFields)
        params.(fixedFields{i}) = ParamMapping.FixedParams.(fixedFields{i});
    end
end

function CalibData = loadCalibratorData(Config)
    % Load calibrator data from catalog
    
    CatalogFile = Config.Data.LAST_AstroImage_file;
    SearchRadius = Config.Data.Search_radius_arcsec;
    
    [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsForAstroImage(...
        CatalogFile, SearchRadius);
    
    CalibData = struct();
    CalibData.Spec = Spec;
    CalibData.Mag = Mag;
    CalibData.Coords = Coords;
    CalibData.LASTData = LASTData;
    CalibData.Metadata = Metadata;
end

function [Cost, Residuals, DiffMag] = calculateCostFunction(CalibData, Config, AbsorptionData, ChebyshevModel)
    % Calculate cost function for current parameters
    
    % Apply transmission to calibrators
    [SpecTrans, Wavelength, ~] = transmission.calibrators.applyTransmissionToCalibrators(...
        CalibData.Spec, CalibData.Metadata, Config, 'AbsorptionData', AbsorptionData);
    
    % Convert to flux array
    if iscell(SpecTrans)
        TransmittedFluxArray = cell2mat(cellfun(@(x) x(:)', SpecTrans(:,1), 'UniformOutput', false));
    else
        TransmittedFluxArray = SpecTrans;
    end
    
    % Calculate total flux - use correct named parameter syntax  
    TotalFlux = transmission.calibrators.calculateTotalFluxCalibrators(...
        Wavelength, TransmittedFluxArray, CalibData.Metadata, ...
        'Norm_', Config.General.Norm_);
    
    % Apply Chebyshev field corrections if provided
    if ~isempty(ChebyshevModel)
        FieldCorrection = evaluateChebyshev(ChebyshevModel, CalibData.LASTData, Config);
        TotalFlux = TotalFlux .* FieldCorrection;
    end
    
    % Calculate magnitude differences
    DiffMag = 2.5 * log10(TotalFlux ./ CalibData.LASTData.FLUX_APER_3);
    
    % Calculate residuals and cost
    Residuals = DiffMag;
    Cost = sum(DiffMag.^2);
end

function ChebyshevModel = setupChebyshevModel(CalibData, order)
    % Setup Chebyshev polynomial model for field corrections
    
    ChebyshevModel = struct();
    ChebyshevModel.Order = order;
    ChebyshevModel.XCoords = CalibData.LASTData.X;
    ChebyshevModel.YCoords = CalibData.LASTData.Y;
    
    % Normalize coordinates to [-1, 1]
    ChebyshevModel.XNorm = 2 * (ChebyshevModel.XCoords - min(ChebyshevModel.XCoords)) / ...
                           (max(ChebyshevModel.XCoords) - min(ChebyshevModel.XCoords)) - 1;
    ChebyshevModel.YNorm = 2 * (ChebyshevModel.YCoords - min(ChebyshevModel.YCoords)) / ...
                           (max(ChebyshevModel.YCoords) - min(ChebyshevModel.YCoords)) - 1;
end

function FieldCorrection = evaluateChebyshev(ChebyshevModel, LASTData, Config)
    % Evaluate Chebyshev field corrections using utils/chebyshevModel
    
    % Extract Chebyshev coefficients from Config if they exist
    if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Chebyshev')
        % Get coefficients for X
        cx = zeros(5, 1);
        if isfield(Config.FieldCorrection.Chebyshev, 'X')
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c0'), cx(1) = Config.FieldCorrection.Chebyshev.X.c0; end
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c1'), cx(2) = Config.FieldCorrection.Chebyshev.X.c1; end
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c2'), cx(3) = Config.FieldCorrection.Chebyshev.X.c2; end
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c3'), cx(4) = Config.FieldCorrection.Chebyshev.X.c3; end
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c4'), cx(5) = Config.FieldCorrection.Chebyshev.X.c4; end
        end
        
        % Get coefficients for Y
        cy = zeros(5, 1);
        if isfield(Config.FieldCorrection.Chebyshev, 'Y')
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c0'), cy(1) = Config.FieldCorrection.Chebyshev.Y.c0; end
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c1'), cy(2) = Config.FieldCorrection.Chebyshev.Y.c1; end
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c2'), cy(3) = Config.FieldCorrection.Chebyshev.Y.c2; end
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c3'), cy(4) = Config.FieldCorrection.Chebyshev.Y.c3; end
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c4'), cy(5) = Config.FieldCorrection.Chebyshev.Y.c4; end
        end
        
        % Call utils/chebyshevModel to evaluate
        if exist('utils.chebyshevModel', 'class') || exist('+utils/chebyshevModel.m', 'file')
            % Use the actual chebyshevModel
            chebModel = utils.chebyshevModel('CoefficientsX', cx, 'CoefficientsY', cy);
            FieldCorrection = chebModel.evaluate(ChebyshevModel.XNorm, ChebyshevModel.YNorm);
        else
            % Fallback: Evaluate Chebyshev polynomials directly
            % T0 = 1, T1 = x, T2 = 2x^2 - 1, T3 = 4x^3 - 3x, T4 = 8x^4 - 8x^2 + 1
            X = ChebyshevModel.XNorm;
            Y = ChebyshevModel.YNorm;
            
            % Chebyshev polynomials for X
            Tx = zeros(length(X), 5);
            Tx(:, 1) = 1;
            Tx(:, 2) = X;
            Tx(:, 3) = 2*X.^2 - 1;
            Tx(:, 4) = 4*X.^3 - 3*X;
            Tx(:, 5) = 8*X.^4 - 8*X.^2 + 1;
            
            % Chebyshev polynomials for Y
            Ty = zeros(length(Y), 5);
            Ty(:, 1) = 1;
            Ty(:, 2) = Y;
            Ty(:, 3) = 2*Y.^2 - 1;
            Ty(:, 4) = 4*Y.^3 - 3*Y;
            Ty(:, 5) = 8*Y.^4 - 8*Y.^2 + 1;
            
            % Combine corrections: multiplicative model
            CorrectionX = Tx * cx;
            CorrectionY = Ty * cy;
            
            % Field correction as exponential of polynomial sum (ensures positive)
            FieldCorrection = exp(CorrectionX + CorrectionY);
        end
    else
        % No field correction coefficients defined
        FieldCorrection = ones(height(LASTData), 1);
    end
end


function plotOptimizationProgress(IterationHistory, ParamMapping, OptimalVector)
    % Plot optimization progress
    
    figure('Name', 'Optimization Progress', 'Position', [100, 100, 1200, 600]);
    
    % Plot cost function
    subplot(1, 2, 1);
    semilogy(IterationHistory.CostValues, 'o-', 'LineWidth', 2);
    xlabel('Iteration');
    ylabel('Cost Function');
    title('Cost Function vs Iteration');
    grid on;
    
    % Mark optimal point
    hold on;
    [MinCost, MinIdx] = min(IterationHistory.CostValues);
    plot(MinIdx, MinCost, 'r*', 'MarkerSize', 15, 'LineWidth', 2);
    hold off;
    
    % Plot parameter evolution
    subplot(1, 2, 2);
    hold on;
    colors = lines(ParamMapping.NumParams);
    for i = 1:ParamMapping.NumParams
        plot(IterationHistory.ParamValues(:, i), 'o-', ...
             'Color', colors(i, :), 'LineWidth', 2, ...
             'DisplayName', char(ParamMapping.Names{i}));
    end
    xlabel('Iteration');
    ylabel('Parameter Value');
    title('Parameter Evolution');
    legend('Location', 'best');
    grid on;
    hold off;
end

function saveOptimizationResults(OptimalParams, Fval, ExitFlag, Output, ...
                                ResultData, IterationHistory, Config, OptimizationTime)
    % Save optimization results to file
    
    Results = struct();
    Results.OptimalParams = OptimalParams;
    Results.FinalCost = Fval;
    Results.ExitFlag = ExitFlag;
    Results.Output = Output;
    Results.ResultData = ResultData;
    Results.IterationHistory = IterationHistory;
    Results.ConfigUsed = Config;
    Results.Timestamp = datetime('now');
    Results.OptimizationTimeSeconds = OptimizationTime;
    
    Filename = sprintf('minimizerFminGeneric_results_%s.mat', ...
                      datestr(datetime('now'), 'yyyymmdd_HHMMSS'));
    save(Filename, 'Results');
    
    fprintf('\nResults saved to: %s\n', Filename);
end

function xBounded = applyBounds(x, ParamMapping)
    % Apply parameter bounds using transformation
    
    if ~isfield(ParamMapping, 'LowerBounds')
        xBounded = x;
        return;
    end
    
    xBounded = x;
    for i = 1:length(x)
        if isfinite(ParamMapping.LowerBounds(i)) && isfinite(ParamMapping.UpperBounds(i))
            % Both bounds finite - use sigmoid transformation
            range = ParamMapping.UpperBounds(i) - ParamMapping.LowerBounds(i);
            xBounded(i) = ParamMapping.LowerBounds(i) + range / (1 + exp(-x(i)));
        elseif isfinite(ParamMapping.LowerBounds(i))
            % Only lower bound - use exponential
            xBounded(i) = ParamMapping.LowerBounds(i) + exp(x(i));
        elseif isfinite(ParamMapping.UpperBounds(i))
            % Only upper bound - use negative exponential
            xBounded(i) = ParamMapping.UpperBounds(i) - exp(-x(i));
        end
    end
end

function xTransformed = transformToBounded(x, ParamMapping)
    % Transform from bounded to unbounded space
    
    if ~isfield(ParamMapping, 'LowerBounds')
        xTransformed = x;
        return;
    end
    
    xTransformed = x;
    for i = 1:length(x)
        if isfinite(ParamMapping.LowerBounds(i)) && isfinite(ParamMapping.UpperBounds(i))
            % Both bounds finite - inverse sigmoid
            range = ParamMapping.UpperBounds(i) - ParamMapping.LowerBounds(i);
            p = (x(i) - ParamMapping.LowerBounds(i)) / range;
            p = max(min(p, 0.999), 0.001); % Avoid infinities
            xTransformed(i) = log(p / (1 - p));
        elseif isfinite(ParamMapping.LowerBounds(i))
            % Only lower bound - inverse exponential
            xTransformed(i) = log(x(i) - ParamMapping.LowerBounds(i) + eps);
        elseif isfinite(ParamMapping.UpperBounds(i))
            % Only upper bound - inverse negative exponential
            xTransformed(i) = -log(ParamMapping.UpperBounds(i) - x(i) + eps);
        end
    end
end