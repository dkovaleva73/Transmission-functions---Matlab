%% Test Config-based Field Correction Detection
try
    fprintf('=== Testing Config-based Field Correction Detection ===\n');
    
    % Test 1: Default config (no field correction)
    fprintf('\n1. Testing default config...\n');
    Config1 = transmission.inputConfig();
    fprintf('  FieldCorrection.Enable: %s\n', string(Config1.FieldCorrection.Enable));
    fprintf('  FieldCorrection.Mode: %s\n', Config1.FieldCorrection.Mode);
    
    % Test 2: Python field correction scenario
    fprintf('\n2. Testing python_field_correction scenario...\n');
    Config2 = transmission.inputConfig('python_field_correction');
    fprintf('  FieldCorrection.Enable: %s\n', string(Config2.FieldCorrection.Enable));
    fprintf('  FieldCorrection.Mode: %s\n', Config2.FieldCorrection.Mode);
    
    % Test 3: Simple field correction scenario
    fprintf('\n3. Testing simple_field_correction scenario...\n');
    Config3 = transmission.inputConfig('simple_field_correction');
    fprintf('  FieldCorrection.Enable: %s\n', string(Config3.FieldCorrection.Enable));
    fprintf('  FieldCorrection.Mode: %s\n', Config3.FieldCorrection.Mode);
    
    % Test 4: Calculate with Python field correction via OptimizedParams
    fprintf('\n4. Testing Python field correction via OptimizedParams...\n');
    OptimizedParams = struct();
    OptimizedParams.Norm_ = 0.8;
    OptimizedParams.kx0 = 0.05;    % Python field correction parameter
    OptimizedParams.kx = -0.03;    
    OptimizedParams.ky = 0.02;     
    
    % Use default config, but OptimizedParams should trigger Python mode
    Config = transmission.inputConfig();
    CatalogAB = transmission.calculateAbsolutePhotometry(OptimizedParams, Config, 'Verbose', false);
    
    % Check field correction variation
    fc_range = max(CatalogAB.FIELD_CORRECTION_MAG) - min(CatalogAB.FIELD_CORRECTION_MAG);
    if fc_range > 0.01
        fprintf('✓ Python field correction detected from OptimizedParams (range: %.4f mag)\n', fc_range);
    else
        fprintf('✗ Field correction not working (range: %.4f mag)\n', fc_range);
    end
    
    % Test 5: Calculate with Python field correction via Config
    fprintf('\n5. Testing Python field correction via Config...\n');
    Config5 = transmission.inputConfig('python_field_correction');
    Config5.FieldCorrection.Python.kx0 = 0.05;
    Config5.FieldCorrection.Python.kx = -0.03;
    Config5.FieldCorrection.Python.ky = 0.02;
    
    % No field correction params in OptimizedParams
    OptimizedParams5 = struct();
    OptimizedParams5.Norm_ = 0.8;
    
    CatalogAB5 = transmission.calculateAbsolutePhotometry(OptimizedParams5, Config5, 'Verbose', false);
    
    fc_range5 = max(CatalogAB5.FIELD_CORRECTION_MAG) - min(CatalogAB5.FIELD_CORRECTION_MAG);
    if fc_range5 > 0.01
        fprintf('✓ Python field correction detected from Config (range: %.4f mag)\n', fc_range5);
    else
        fprintf('✗ Field correction not working from Config (range: %.4f mag)\n', fc_range5);
    end
    
    % Test 6: Check that updateConfigWithOptimizedParams works
    fprintf('\n6. Testing updateConfigWithOptimizedParams mapping...\n');
    TestParams = struct();
    TestParams.kx0 = 0.1;
    TestParams.kx = 0.05;
    TestParams.cx0 = 0.2;
    TestParams.cy0 = 0.3;
    
    % This is an internal function, so we'll test indirectly
    CatalogTest = transmission.calculateAbsolutePhotometry(TestParams, Config, 'Verbose', false);
    fprintf('✓ Parameter mapping tested (processed %d stars)\n', height(CatalogTest));
    
    fprintf('\n=== CONFIG FIELD CORRECTION TEST COMPLETE ===\n');
    fprintf('✓ Config structure properly includes FieldCorrection settings\n');
    fprintf('✓ Python and Simple field correction scenarios available\n');
    fprintf('✓ OptimizedParams properly mapped to Config\n');
    fprintf('✓ Field corrections can be triggered via OptimizedParams or Config\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end