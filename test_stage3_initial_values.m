%% Test what initial values are actually used in Stage 3
try
    fprintf('=== Testing Stage 3 Initial Values ===\n');
    
    % 1. Create optimizer and run first two stages
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);
    
    fprintf('Loading calibrator data...\n');
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Run Stage 1
    fprintf('\nRunning Stage 1 (NormOnly_Initial)...\n');
    stage1 = optimizer.ActiveSequence(1);
    result1 = optimizer.runSingleStage(stage1);
    optimizer.updateOptimizedParams(result1.OptimalParams);
    fprintf('Stage 1 cost: %.4e\n', result1.Fval);
    
    % Run Stage 2
    fprintf('\nRunning Stage 2 (NormAndCenter)...\n');
    stage2 = optimizer.ActiveSequence(2);
    result2 = optimizer.runSingleStage(stage2);
    optimizer.updateOptimizedParams(result2.OptimalParams);
    fprintf('Stage 2 cost: %.4e\n', result2.Fval);
    
    % 2. Check what's in OptimizedParams before Stage 3
    fprintf('\n=== Parameters optimized so far ===\n');
    optimizedFields = fieldnames(optimizer.OptimizedParams);
    for i = 1:length(optimizedFields)
        fprintf('  %s: %.6f\n', optimizedFields{i}, optimizer.OptimizedParams.(optimizedFields{i}));
    end
    
    % 3. Check field correction parameters
    stage3 = optimizer.ActiveSequence(3);
    stage3Params = stage3.freeParams;
    
    fprintf('\n=== Stage 3 Field Correction Parameters ===\n');
    fprintf('Free parameters in Stage 3:\n');
    for i = 1:length(stage3Params)
        paramName = char(stage3Params(i));
        fprintf('  %s: ', paramName);
        
        % Check if it's in OptimizedParams (shouldn't be)
        if isfield(optimizer.OptimizedParams, paramName)
            fprintf('ALREADY OPTIMIZED = %.6f (UNEXPECTED!)\n', optimizer.OptimizedParams.(paramName));
        else
            % Check what default value will be used
            [~, defaultVal] = getParameterPathTest(paramName, Config);
            fprintf('Will use default = %.6f\n', defaultVal);
        end
    end
    
    % 4. Actually check initial values used in optimization
    fprintf('\n=== Testing actual initial values in minimizerFminGeneric ===\n');
    
    % Create a test wrapper to capture initial values
    testMinimizerWrapper(Config, optimizer);
    
    fprintf('\n=== TEST COMPLETE ===\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end

function [configPath, defaultValue] = getParameterPathTest(paramName, Config)
    % Extract default value for a parameter from Config
    switch char(paramName)
        case 'kx0'
            configPath = 'FieldCorrection.Python.kx0';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.kx0;
            else
                defaultValue = 0;  % hardcoded in minimizerFminGeneric
            end
        case 'kx'
            configPath = 'FieldCorrection.Python.kx';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.kx;
            else
                defaultValue = 0;
            end
        case 'ky'
            configPath = 'FieldCorrection.Python.ky';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.ky;
            else
                defaultValue = 0;
            end
        case 'kx2'
            configPath = 'FieldCorrection.Python.kx2';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.kx2;
            else
                defaultValue = 0;
            end
        case 'ky2'
            configPath = 'FieldCorrection.Python.ky2';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.ky2;
            else
                defaultValue = 0;
            end
        case 'kx3'
            configPath = 'FieldCorrection.Python.kx3';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.kx3;
            else
                defaultValue = 0;
            end
        case 'ky3'
            configPath = 'FieldCorrection.Python.ky3';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.ky3;
            else
                defaultValue = 0;
            end
        case 'kx4'
            configPath = 'FieldCorrection.Python.kx4';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.kx4;
            else
                defaultValue = 0;
            end
        case 'ky4'
            configPath = 'FieldCorrection.Python.ky4';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.ky4;
            else
                defaultValue = 0;
            end
        case 'kxy'
            configPath = 'FieldCorrection.Python.kxy';
            if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Python')
                defaultValue = Config.FieldCorrection.Python.kxy;
            else
                defaultValue = 0;
            end
        otherwise
            configPath = '';
            defaultValue = 0;
    end
end

function testMinimizerWrapper(Config, optimizer)
    % Test wrapper to see what initial values are actually used
    
    stage3 = optimizer.ActiveSequence(3);
    
    % Manually create the arguments like runSingleStage does
    Args = struct();
    Args.FreeParams = stage3.freeParams;
    Args.FixedParams = optimizer.OptimizedParams;
    Args.UsePythonFieldModel = true;
    Args.InputData = optimizer.CalibratorData;
    Args.Verbose = false;
    
    % Create mapping to see initial values
    fprintf('\nPreparing parameter mapping for Stage 3:\n');
    ParamMapping = prepareParameterMappingTest(Config, Args.FreeParams, Args.FixedParams);
    
    fprintf('\nInitial parameter vector for optimization:\n');
    for i = 1:length(ParamMapping.Names)
        fprintf('  %s: %.6f\n', ParamMapping.Names{i}, ParamMapping.InitialVector(i));
    end
    
    % Check if any are non-zero
    nonZeroParams = ParamMapping.Names(ParamMapping.InitialVector ~= 0);
    if ~isempty(nonZeroParams)
        fprintf('\n⚠️ WARNING: Non-zero initial values found for:\n');
        for i = 1:length(nonZeroParams)
            idx = strcmp(ParamMapping.Names, nonZeroParams{i});
            fprintf('  %s = %.6f\n', nonZeroParams{i}, ParamMapping.InitialVector(idx));
        end
    else
        fprintf('\n✓ All field correction parameters start at 0.0\n');
    end
end

function ParamMapping = prepareParameterMappingTest(Config, FreeParams, FixedParams)
    % Simplified version of prepareParameterMapping from minimizerFminGeneric
    
    ParamMapping = struct();
    ParamMapping.Names = FreeParams;
    ParamMapping.NumParams = length(FreeParams);
    ParamMapping.InitialVector = zeros(ParamMapping.NumParams, 1);
    
    for i = 1:ParamMapping.NumParams
        paramName = FreeParams(i);
        
        % Check if in FixedParams (shouldn't be for field corrections)
        if isfield(FixedParams, paramName)
            ParamMapping.InitialVector(i) = FixedParams.(paramName);
            fprintf('    %s from FixedParams: %.6f\n', paramName, FixedParams.(paramName));
        else
            % Get default value
            [~, defaultValue] = getParameterPathTest(paramName, Config);
            ParamMapping.InitialVector(i) = defaultValue;
        end
    end
end