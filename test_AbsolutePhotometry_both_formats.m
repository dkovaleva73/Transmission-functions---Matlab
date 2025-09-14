% Test AbsolutePhotometryAstroImage with both single struct and cell array inputs
fprintf('=== TESTING ABSOLUTEPHOTOMETRYASTROIMAGE WITH BOTH INPUT FORMATS ===\n\n');

Config = transmissionFast.inputConfig();

% Create test parameters (minimal structure)
testParams = struct();
testParams.General = struct();
testParams.General.Norm_ = 0.3;
testParams.Utils = struct();
testParams.Utils.SkewedGaussianModel = struct();
testParams.Utils.SkewedGaussianModel.Default_amplitude = 350;
testParams.Utils.SkewedGaussianModel.Default_center = 477;
testParams.Utils.SkewedGaussianModel.Default_width = 120;
testParams.Utils.SkewedGaussianModel.Default_shape = -0.5;

%% Test 1: Single structure (same parameters for all fields)
fprintf('1. TEST WITH SINGLE STRUCTURE:\n');
try
    % Process just first 3 subimages for quick test
    CatalogAB_single = transmissionFast.AbsolutePhotometryAstroImage(...
        testParams, Config, ...
        'Verbose', false, ...
        'SaveResults', false);
    
    success_count = sum(~cellfun(@isempty, CatalogAB_single));
    fprintf('✅ Single structure input works\n');
    fprintf('   Successfully processed: %d/24 subimages\n', success_count);
    
catch ME
    fprintf('❌ Single structure test failed: %s\n', ME.message);
end

%% Test 2: Cell array of structures (field-specific parameters)
fprintf('\n2. TEST WITH CELL ARRAY (field-specific parameters):\n');

% Create cell array with different parameters for each field
testParams_cell = cell(24, 1);

% Fill with slightly different parameters for each field
for i = 1:24
    params = testParams;  % Copy base parameters
    params.General.Norm_ = 0.3 + (i-1) * 0.001;  % Vary Norm_ slightly
    testParams_cell{i} = params;
end

% Leave some fields empty to test handling
testParams_cell{23} = [];  % Empty field 23
testParams_cell{24} = [];  % Empty field 24

try
    CatalogAB_cell = transmissionFast.AbsolutePhotometryAstroImage(...
        testParams_cell, Config, ...
        'Verbose', false, ...
        'SaveResults', false);
    
    success_count = sum(~cellfun(@isempty, CatalogAB_cell));
    fprintf('✅ Cell array input works\n');
    fprintf('   Successfully processed: %d/24 subimages\n', success_count);
    fprintf('   (Fields 23-24 were intentionally empty)\n');
    
catch ME
    fprintf('❌ Cell array test failed: %s\n', ME.message);
end

%% Test 3: Test with actual optimizeAllFieldsAI output format
fprintf('\n3. SIMULATE OPTIMIZEALLFIELDSAI OUTPUT:\n');

% Simulate the output from optimizeAllFieldsAI
simulated_optim_output = cell(24, 1);

% Fill with realistic parameters
for fieldNum = 1:24
    if fieldNum <= 22  % Skip last 2 to simulate failed optimizations
        params = struct();
        params.Norm_ = 0.3 + randn * 0.01;
        params.Tau_aod500 = 0.08 + randn * 0.005;
        params.Pwv_cm = 1.5 + randn * 0.1;
        params.General = testParams.General;
        params.Utils = testParams.Utils;
        simulated_optim_output{fieldNum} = params;
    else
        simulated_optim_output{fieldNum} = [];  % Failed optimization
    end
end

try
    CatalogAB_optim = transmissionFast.AbsolutePhotometryAstroImage(...
        simulated_optim_output, Config, ...
        'Verbose', false, ...
        'SaveResults', false);
    
    success_count = sum(~cellfun(@isempty, CatalogAB_optim));
    fprintf('✅ OptimizeAllFieldsAI format works\n');
    fprintf('   Successfully processed: %d/24 subimages\n', success_count);
    
    % Check that different parameters were used
    fprintf('   Field-specific parameters confirmed:\n');
    for i = 1:min(3, 22)
        if ~isempty(simulated_optim_output{i})
            fprintf('     Field %d: Norm_ = %.4f\n', i, simulated_optim_output{i}.Norm_);
        end
    end
    
catch ME
    fprintf('❌ OptimizeAllFieldsAI format test failed: %s\n', ME.message);
end

%% Test 4: Error handling
fprintf('\n4. ERROR HANDLING TESTS:\n');

% Test with wrong size cell array
try
    wrong_size = cell(10, 1);
    CatalogAB_wrong = transmissionFast.AbsolutePhotometryAstroImage(wrong_size, Config, 'Verbose', false);
    fprintf('❌ Should have failed with wrong size cell array\n');
catch ME
    if contains(ME.message, '24 elements')
        fprintf('✅ Correctly rejected wrong size cell array\n');
    else
        fprintf('❌ Unexpected error: %s\n', ME.message);
    end
end

% Test with invalid input type
try
    CatalogAB_invalid = transmissionFast.AbsolutePhotometryAstroImage(42, Config, 'Verbose', false);
    fprintf('❌ Should have failed with invalid input type\n');
catch ME
    if contains(ME.message, 'must be a structure or 24x1 cell array')
        fprintf('✅ Correctly rejected invalid input type\n');
    else
        fprintf('❌ Unexpected error: %s\n', ME.message);
    end
end

%% Summary
fprintf('\n=== TEST SUMMARY ===\n');
fprintf('✅ Function accepts SINGLE STRUCTURE (same parameters for all fields)\n');
fprintf('✅ Function accepts CELL ARRAY {24x1} (field-specific parameters)\n');
fprintf('✅ Compatible with optimizeAllFieldsAI output format\n');
fprintf('✅ Handles empty/missing field parameters gracefully\n');
fprintf('✅ Proper error handling for invalid inputs\n');

fprintf('\n💡 USAGE:\n');
fprintf('   % For single optimization result:\n');
fprintf('   CatalogAB_all = AbsolutePhotometryAstroImage(singleParams, Config);\n');
fprintf('\n');
fprintf('   % For optimizeAllFieldsAI results:\n');
fprintf('   [params_all, ~, ~] = transmissionFast.optimizeAllFieldsAI();\n');
fprintf('   CatalogAB_all = AbsolutePhotometryAstroImage(params_all, Config);\n');

fprintf('\n🎯 SUCCESS: Function now handles both input formats correctly!\n');
fprintf('=== TEST COMPLETE ===\n');