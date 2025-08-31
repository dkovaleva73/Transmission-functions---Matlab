%% Test Simple Field Correction Case
try
    fprintf('=== Testing Simple Field Correction ===\n');
    
    % Test case: Just kx0 constant offset should produce uniform field correction
    Config = transmission.inputConfig('python_field_correction');
    Config.FieldCorrection.Python.kx0 = 0.1;  % Just constant offset - should be same everywhere
    
    fprintf('Config settings:\n');
    fprintf('  Mode: %s\n', Config.FieldCorrection.Mode);
    fprintf('  kx0: %.3f\n', Config.FieldCorrection.Python.kx0);
    
    % No field params in OptimizedParams
    OptimizedParams = struct();
    OptimizedParams.Norm_ = 0.8;
    
    CatalogAB = transmission.photometry.calculateAbsolutePhotometry(OptimizedParams, Config, 'Verbose', false);
    
    % With just kx0, all stars should have the same field correction
    fc_mean = mean(CatalogAB.FIELD_CORRECTION_MAG);
    fc_std = std(CatalogAB.FIELD_CORRECTION_MAG);
    
    fprintf('\nField correction statistics:\n');
    fprintf('  Mean: %.4f mag\n', fc_mean);
    fprintf('  Std: %.6f mag (should be ~0 for constant offset)\n', fc_std);
    
    if abs(fc_mean - 0.1) < 0.001 && fc_std < 0.0001
        fprintf('✓ Config-based constant field correction working correctly\n');
    else
        fprintf('✗ Config-based field correction not working\n');
        fprintf('  Expected mean ~0.1, got %.4f\n', fc_mean);
    end
    
    % Now test with spatially varying correction
    fprintf('\n--- Testing spatially varying correction ---\n');
    Config2 = transmission.inputConfig('python_field_correction');
    Config2.FieldCorrection.Python.kx = 0.05;  % Linear gradient in X
    
    OptimizedParams2 = struct();
    OptimizedParams2.Norm_ = 0.8;
    
    CatalogAB2 = transmission.photometry.calculateAbsolutePhotometry(OptimizedParams2, Config2, 'Verbose', false);
    
    fc_range2 = max(CatalogAB2.FIELD_CORRECTION_MAG) - min(CatalogAB2.FIELD_CORRECTION_MAG);
    fprintf('Field correction range with kx=0.05: %.4f mag\n', fc_range2);
    
    if fc_range2 > 0.01
        fprintf('✓ Config-based spatially varying correction working\n');
    else
        fprintf('✗ Config-based spatially varying correction not working\n');
    end
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end