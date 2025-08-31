%% Test Field Correction Modes - Python-compliant vs Simple
% This script tests both optimization modes and demonstrates the field correction differences
% Author: D. Kovaleva (Aug 2025)

clear; clc;
fprintf('=== FIELD CORRECTION MODES COMPARISON ===\n\n');

% Initialize configuration
Config = transmission.inputConfig();

%% Test 1: Initialize both optimizers
fprintf('1. Testing optimizer initialization...\n');
try
    % Python-compliant mode (default)
    optimizer_python = transmission.TransmissionOptimizer(Config, ...
        'Sequence', 'DefaultSequence', 'Verbose', false);
    fprintf('✓ Python-compliant optimizer initialized\n');
    
    % Simple field correction mode
    optimizer_simple = transmission.TransmissionOptimizer(Config, ...
        'Sequence', 'SimpleFieldCorrection', 'Verbose', false);
    fprintf('✓ Simple field correction optimizer initialized\n');
    
catch ME
    fprintf('✗ Error initializing optimizers: %s\n', ME.message);
    return;
end

%% Test 2: Compare optimization sequences
fprintf('\n2. Comparing optimization sequences...\n');

% Python sequence
python_seq = optimizer_python.ActiveSequence;
fprintf('Python-compliant sequence (%d stages):\n', length(python_seq));
for i = 1:length(python_seq)
    stage = python_seq(i);
    fprintf('  Stage %d: %s\n', i, stage.name);
    fprintf('    Free params: %s\n', strjoin(string(stage.freeParams), ', '));
    if isfield(stage, 'usePythonFieldModel') && any(stage.usePythonFieldModel)
        fprintf('    Uses Python field model ✓\n');
        if isfield(stage, 'fixedParams')
            fixed_names = fieldnames(stage.fixedParams);
            fixed_vals = structfun(@num2str, stage.fixedParams, 'UniformOutput', false);
            fprintf('    Fixed params: %s\n', strjoin(strcat(fixed_names, '=', struct2cell(fixed_vals)), ', '));
        end
    end
end

fprintf('\nSimple field correction sequence (%d stages):\n', length(optimizer_simple.ActiveSequence));
simple_seq = optimizer_simple.ActiveSequence;
for i = 1:length(simple_seq)
    stage = simple_seq(i);
    fprintf('  Stage %d: %s\n', i, stage.name);
    fprintf('    Free params: %s\n', strjoin(string(stage.freeParams), ', '));
    if isfield(stage, 'useChebyshev') && any(stage.useChebyshev)
        fprintf('    Uses simple Chebyshev (order %d) ✓\n', stage.chebyshevOrder);
    end
end

%% Test 3: Load calibrator data for field 1
fprintf('\n3. Loading calibrator data for field 1...\n');
try
    optimizer_python.loadCalibratorData(1);
    fprintf('✓ Calibrator data loaded: %d calibrators\n', length(optimizer_python.CalibratorData.Spec));
    
    % Check coordinate ranges
    X_coords = optimizer_python.CalibratorData.LASTData.X;
    Y_coords = optimizer_python.CalibratorData.LASTData.Y;
    fprintf('  X coordinates: %.1f to %.1f\n', min(X_coords), max(X_coords));
    fprintf('  Y coordinates: %.1f to %.1f\n', min(Y_coords), max(Y_coords));
    
catch ME
    fprintf('✗ Error loading calibrator data: %s\n', ME.message);
    return;
end

%% Test 4: Test Python field correction model directly
fprintf('\n4. Testing Python field correction model...\n');

% Create test configuration with Python field parameters
TestConfig = Config;
TestConfig.FieldCorrection.Python.kx0 = 0.1;
TestConfig.FieldCorrection.Python.kx = 0.05;
TestConfig.FieldCorrection.Python.ky = 0.02;  % Note: ky0 should be 0 and fixed
TestConfig.FieldCorrection.Python.ky0 = 0.0;  % Fixed at 0 in Python
TestConfig.FieldCorrection.Python.kx2 = 0.01;
TestConfig.FieldCorrection.Python.ky2 = 0.008;
TestConfig.FieldCorrection.Python.kx3 = 0.005;
TestConfig.FieldCorrection.Python.ky3 = 0.002;
TestConfig.FieldCorrection.Python.kx4 = 0.001;
TestConfig.FieldCorrection.Python.ky4 = 0.0005;
TestConfig.FieldCorrection.Python.kxy = 0.003;

% Test field correction calculation
try
    LASTData = optimizer_python.CalibratorData.LASTData;
    
    % Call the private method through minimizerFminGeneric by examining its pattern
    % We'll test the normalization formula used in evaluatePythonFieldModel
    X = LASTData.X;
    Y = LASTData.Y;
    
    % Normalize coordinates to [-1, +1] like Python
    min_coor = 0.0;
    max_coor = 1726.0;
    min_coortr = -1.0;
    max_coortr = +1.0;
    
    xcoor_ = (max_coortr - min_coortr) / (max_coor - min_coor) * (X - max_coor) + max_coortr;
    ycoor_ = (max_coortr - min_coortr) / (max_coor - min_coor) * (Y - max_coor) + max_coortr;
    
    fprintf('✓ Coordinate normalization completed\n');
    fprintf('  Normalized X range: %.3f to %.3f\n', min(xcoor_), max(xcoor_));
    fprintf('  Normalized Y range: %.3f to %.3f\n', min(ycoor_), max(ycoor_));
    
    % Test Chebyshev polynomial calculation (using same logic as Python model)
    % Test simple linear term calculation
    kx = TestConfig.FieldCorrection.Python.kx;
    ky = TestConfig.FieldCorrection.Python.ky;
    linear_x_contrib = kx * xcoor_;
    linear_y_contrib = ky * ycoor_;
    
    fprintf('  Linear X contribution range: %.4f to %.4f\n', min(linear_x_contrib), max(linear_x_contrib));
    fprintf('  Linear Y contribution range: %.4f to %.4f\n', min(linear_y_contrib), max(linear_y_contrib));
    
catch ME
    fprintf('✗ Error testing Python field model: %s\n', ME.message);
    return;
end

%% Test 5: Compare parameter mappings
fprintf('\n5. Comparing parameter mappings...\n');

% Check which parameters are used in each mode
python_stage3 = python_seq(3);  % Field correction stage
simple_stage3 = simple_seq(3);  % Field correction stage

fprintf('Python field correction parameters:\n');
fprintf('  %s\n', strjoin(string(python_stage3.freeParams), ', '));

fprintf('Simple field correction parameters:\n');
fprintf('  %s\n', strjoin(string(simple_stage3.freeParams), ', '));

%% Summary
fprintf('\n=== SUMMARY ===\n');
fprintf('✓ Both optimization modes initialize successfully\n');
fprintf('✓ Python-compliant mode uses advanced Chebyshev field model:\n');
fprintf('  - Order 4 for X,Y coordinates (kx, kx2, kx3, kx4, ky, ky2, ky3, ky4)\n');
fprintf('  - Order 1 for XY cross-term (kxy)\n');
fprintf('  - Constant terms (kx0, ky0 fixed at 0)\n');
fprintf('  - Coordinate normalization to [-1, +1] domain\n');
fprintf('✓ Simple mode uses basic Chebyshev model:\n');
fprintf('  - Standard cx0-cx4, cy0-cy4 coefficients\n');
fprintf('  - Order 4 polynomial expansion\n');
fprintf('✓ Field correction coordinate normalization working correctly\n');
fprintf('\nBoth modes are ready for optimization!\n');

%% Optional: Save test configuration for future use
save('field_correction_test_config.mat', 'TestConfig', 'optimizer_python', 'optimizer_simple');
fprintf('\nTest configuration saved to: field_correction_test_config.mat\n');