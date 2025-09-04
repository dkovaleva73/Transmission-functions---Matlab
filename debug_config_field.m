%% Debug Config Field Correction
try
    fprintf('=== Debug Config Field Correction ===\n');
    
    % Setup Config with Python field correction
    Config = transmission.inputConfig('python_field_correction');
    Config.FieldCorrection.Python.kx0 = 0.05;
    Config.FieldCorrection.Python.kx = -0.03;
    Config.FieldCorrection.Python.ky = 0.02;
    Config.FieldCorrection.Python.kx2 = 0.01;
    
    fprintf('Config before calculateAbsolutePhotometry:\n');
    fprintf('  Mode: %s\n', Config.FieldCorrection.Mode);
    fprintf('  kx0: %.3f\n', Config.FieldCorrection.Python.kx0);
    fprintf('  kx: %.3f\n', Config.FieldCorrection.Python.kx);
    fprintf('  ky: %.3f\n', Config.FieldCorrection.Python.ky);
    
    % No field correction params in OptimizedParams
    OptimizedParams = struct();
    OptimizedParams.Norm_ = 0.8;
    
    % Add verbose output temporarily
    CatalogAB = transmission.calculateAbsolutePhotometry(OptimizedParams, Config, 'Verbose', true);
    
    fc_range = max(CatalogAB.FIELD_CORRECTION_MAG) - min(CatalogAB.FIELD_CORRECTION_MAG);
    fprintf('\nField correction range: %.4f mag\n', fc_range);
    
    % Check a few sample values
    fprintf('\nSample field corrections:\n');
    for i = 1:5:20
        fprintf('  Star %d: FC=%.4f mag\n', i, CatalogAB.FIELD_CORRECTION_MAG(i));
    end
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end