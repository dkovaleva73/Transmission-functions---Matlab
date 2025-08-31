%% Debug if Config.FieldCorrection is preserved
try
    fprintf('=== Debug Config.FieldCorrection Preservation ===\n');
    
    % Create Config with field correction
    Config = transmission.inputConfig('python_field_correction');
    Config.FieldCorrection.Python.kx0 = 0.15;
    Config.FieldCorrection.Python.kx = 0.05;
    
    fprintf('Initial Config.FieldCorrection:\n');
    fprintf('  Enable: %s\n', string(Config.FieldCorrection.Enable));
    fprintf('  Mode: %s\n', Config.FieldCorrection.Mode);
    fprintf('  kx0: %.3f\n', Config.FieldCorrection.Python.kx0);
    fprintf('  kx: %.3f\n', Config.FieldCorrection.Python.kx);
    
    % Call calculateAbsolutePhotometry with temporary modifications
    OptimizedParams = struct();
    OptimizedParams.Norm_ = 0.8;
    
    % Temporarily modify calculateAbsolutePhotometry to output ConfigOptimized
    % We'll do this by checking the result
    CatalogAB = transmission.photometry.calculateAbsolutePhotometry(OptimizedParams, Config, 'Verbose', false);
    
    % Check if field correction was applied
    fc_vals = CatalogAB.FIELD_CORRECTION_MAG;
    fprintf('\nField correction results:\n');
    fprintf('  Unique values: %d\n', length(unique(fc_vals)));
    fprintf('  Mean: %.6f\n', mean(fc_vals));
    fprintf('  Min: %.6f\n', min(fc_vals));
    fprintf('  Max: %.6f\n', max(fc_vals));
    
    % Try with field params in OptimizedParams for comparison
    fprintf('\n--- With OptimizedParams field correction ---\n');
    OptimizedParams2 = struct();
    OptimizedParams2.Norm_ = 0.8;
    OptimizedParams2.kx0 = 0.15;
    OptimizedParams2.kx = 0.05;
    
    CatalogAB2 = transmission.photometry.calculateAbsolutePhotometry(OptimizedParams2, Config, 'Verbose', false);
    
    fc_vals2 = CatalogAB2.FIELD_CORRECTION_MAG;
    fprintf('Field correction results:\n');
    fprintf('  Unique values: %d\n', length(unique(fc_vals2)));
    fprintf('  Mean: %.6f\n', mean(fc_vals2));
    fprintf('  Min: %.6f\n', min(fc_vals2));
    fprintf('  Max: %.6f\n', max(fc_vals2));
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end