function [fitted_params, residuals, exitflag, output] = optimizerInterface(wavelength, observed_data, param_mapping, options)
    % Interface for fitting v2 transmission models using MATLAB optimizers
    %
    % Parameters:
    %   wavelength (double array): Wavelength array in nm
    %   observed_data (double array): Observed transmission data
    %   param_mapping (ParameterMapping): Parameter mapping object
    %   options (struct): Optimization options
    %
    % Returns:
    %   fitted_params (double array): Fitted parameter values
    %   residuals (double array): Final residuals
    %   exitflag (integer): Exit flag from optimizer
    %   output (struct): Optimization output information
    %
    % Options:
    %   algorithm (string): 'levenberg-marquardt', 'trust-region', 'genetic-algorithm', 'simulated-annealing'
    %   max_iterations (integer): Maximum number of iterations
    %   tolerance (double): Convergence tolerance
    %   weights (double array): Data weights for fitting
    %   verbose (logical): Print optimization progress
    %   component_options (struct): Component inclusion options
    %
    % Example:
    %   import transmission.v2.parameters.*
    %   atm_config = AtmosphericParams.getStandardConfig();
    %   inst_config = InstrumentalParams.getStandardConfig();
    %   field_config = FieldParams.getStandardConfig();
    %   param_mapping = transmission.v2.utils.createParameterMapping(atm_config, inst_config, field_config);
    %   
    %   options = struct();
    %   options.algorithm = 'levenberg-marquardt';
    %   options.max_iterations = 1000;
    %   options.tolerance = 1e-6;
    %   options.component_options = transmission.v2.utils.ComponentOptions.noField();
    %   
    %   [fitted_params, residuals, exitflag, output] = transmission.v2.utils.optimizerInterface(wavelength, data, param_mapping, options);
    
    arguments
        wavelength (:,1) double
        observed_data (:,1) double
        param_mapping (1,1) transmission.v2.utils.ParameterMapping
        options (1,1) struct = struct()
    end
    
    % Set default options
    if ~isfield(options, 'algorithm')
        options.algorithm = 'levenberg-marquardt';
    end
    if ~isfield(options, 'max_iterations')
        options.max_iterations = 1000;
    end
    if ~isfield(options, 'tolerance')
        options.tolerance = 1e-6;
    end
    if ~isfield(options, 'weights')
        options.weights = ones(size(observed_data));
    end
    if ~isfield(options, 'verbose')
        options.verbose = true;
    end
    if ~isfield(options, 'component_options')
        options.component_options = transmission.v2.utils.ComponentOptions.allComponents();
    end
    
    % Get initial parameter values and bounds
    initial_params = param_mapping.getFreeParameters();
    param_bounds = param_mapping.getParameterBounds();
    lower_bounds = param_bounds(:, 1);
    upper_bounds = param_bounds(:, 2);
    
    % Define objective function
    objective_function = @(params) calculateResiduals(params, wavelength, observed_data, param_mapping, options.weights, options.component_options);
    
    % Choose optimizer based on algorithm
    switch lower(options.algorithm)
        case 'levenberg-marquardt'
            % Use lsqnonlin for Levenberg-Marquardt
            lsq_options = optimoptions('lsqnonlin', ...
                'Algorithm', 'levenberg-marquardt', ...
                'MaxIterations', options.max_iterations, ...
                'FunctionTolerance', options.tolerance, ...
                'StepTolerance', options.tolerance, ...
                'Display', 'iter-detailed');
            
            [fitted_params, ~, residuals, exitflag, output] = lsqnonlin(objective_function, initial_params, lower_bounds, upper_bounds, lsq_options);
            
        case 'trust-region'
            % Use lsqnonlin with trust-region-reflective
            lsq_options = optimoptions('lsqnonlin', ...
                'Algorithm', 'trust-region-reflective', ...
                'MaxIterations', options.max_iterations, ...
                'FunctionTolerance', options.tolerance, ...
                'StepTolerance', options.tolerance, ...
                'Display', 'iter-detailed');
            
            [fitted_params, ~, residuals, exitflag, output] = lsqnonlin(objective_function, initial_params, lower_bounds, upper_bounds, lsq_options);
            
        case 'genetic-algorithm'
            % Use genetic algorithm for global optimization
            ga_options = optimoptions('ga', ...
                'MaxGenerations', options.max_iterations, ...
                'FunctionTolerance', options.tolerance, ...
                'Display', 'iter');
            
            % GA minimizes sum of squared residuals
            ga_objective = @(params) sum(calculateResiduals(params, wavelength, observed_data, param_mapping, options.weights, options.component_options).^2);
            
            [fitted_params, ~, exitflag, output] = ga(ga_objective, length(initial_params), [], [], [], [], lower_bounds, upper_bounds, [], ga_options);
            residuals = calculateResiduals(fitted_params, wavelength, observed_data, param_mapping, options.weights, options.component_options);
            
        case 'simulated-annealing'
            % Use simulated annealing
            sa_options = optimoptions('simulannealbnd', ...
                'MaxIterations', options.max_iterations, ...
                'FunctionTolerance', options.tolerance, ...
                'Display', 'iter');
            
            % SA minimizes sum of squared residuals
            sa_objective = @(params) sum(calculateResiduals(params, wavelength, observed_data, param_mapping, options.weights, options.component_options).^2);
            
            [fitted_params, ~, exitflag, output] = simulannealbnd(sa_objective, initial_params, lower_bounds, upper_bounds, sa_options);
            residuals = calculateResiduals(fitted_params, wavelength, observed_data, param_mapping, options.weights, options.component_options);
            
        otherwise
            error('Unknown optimization algorithm: %s', options.algorithm);
    end
    
    % Print summary if verbose
    if options.verbose
        fprintf('\nOptimization Summary:\n');
        fprintf('===================\n');
        fprintf('Algorithm: %s\n', options.algorithm);
        fprintf('Exit flag: %d\n', exitflag);
        fprintf('Final residual norm: %.6e\n', norm(residuals));
        fprintf('Final RMS error: %.6e\n', sqrt(mean(residuals.^2)));
        
        if isfield(output, 'iterations')
            fprintf('Iterations: %d\n', output.iterations);
        end
        if isfield(output, 'funcCount')
            fprintf('Function evaluations: %d\n', output.funcCount);
        end
        
        % Print parameter changes
        fprintf('\nParameter Changes:\n');
        param_names = param_mapping.getParameterNames();
        for i = 1:length(fitted_params)
            change = fitted_params(i) - initial_params(i);
            rel_change = abs(change) / (abs(initial_params(i)) + 1e-10) * 100;
            fprintf('  %-20s: %8.4f → %8.4f (Δ=%.4f, %.1f%%)\n', ...
                    param_names{i}, initial_params(i), fitted_params(i), change, rel_change);
        end
    end
end

function residuals = calculateResiduals(params, wavelength, observed_data, param_mapping, weights, component_options)
    % Calculate weighted residuals for optimization
    %
    % Parameters:
    %   params (double array): Current parameter values
    %   wavelength (double array): Wavelength array
    %   observed_data (double array): Observed transmission data
    %   param_mapping (ParameterMapping): Parameter mapping object
    %   weights (double array): Data weights
    %   component_options (struct): Component inclusion options
    %
    % Returns:
    %   residuals (double array): Weighted residuals
    
    try
        % Calculate model transmission
        model_trans = transmission.v2.totalTransmission(wavelength, params, ...
            param_mapping.atm_config, param_mapping.inst_config, param_mapping.field_config, component_options);
        
        % Calculate weighted residuals
        residuals = (observed_data - model_trans) .* sqrt(weights);
        
    catch ME
        % Return large residuals if calculation fails
        warning('Model calculation failed: %s', ME.message);
        residuals = ones(size(observed_data)) * 1e6;
    end
end