%% Test Field Correction Column Output
try
    fprintf('=== Testing Field Correction Column Output ===\n');
    
    % Create test parameters with Python field correction
    OptimizedParams = struct();
    OptimizedParams.Norm_ = 0.8;
    OptimizedParams.Center = 570;
    OptimizedParams.kx0 = 0.05;    % Constant offset
    OptimizedParams.kx = -0.03;    % Linear X
    OptimizedParams.ky = 0.02;     % Linear Y
    OptimizedParams.kx2 = 0.01;    % Quadratic X
    OptimizedParams.ky2 = -0.008;  % Quadratic Y
    OptimizedParams.kxy = 0.015;   % Cross term
    
    Config = transmission.inputConfig();
    
    % Test calculateAbsolutePhotometry 
    CatalogAB = transmission.calculateAbsolutePhotometry(OptimizedParams, Config, 'Verbose', false);
    
    % Check that FIELD_CORRECTION_MAG column exists
    if ismember('FIELD_CORRECTION_MAG', CatalogAB.Properties.VariableNames)
        fprintf('✓ FIELD_CORRECTION_MAG column added to catalog\n');
        
        % Analyze field correction values
        fc_range = max(CatalogAB.FIELD_CORRECTION_MAG) - min(CatalogAB.FIELD_CORRECTION_MAG);
        fc_mean = mean(CatalogAB.FIELD_CORRECTION_MAG);
        fc_std = std(CatalogAB.FIELD_CORRECTION_MAG);
        
        fprintf('Field correction statistics:\n');
        fprintf('  Range: %.4f mag\n', fc_range);
        fprintf('  Mean: %.4f mag\n', fc_mean);
        fprintf('  Std: %.4f mag\n', fc_std);
        
        % Show some sample values
        fprintf('\nSample field corrections:\n');
        sampleIdx = round(linspace(1, height(CatalogAB), 5));
        for i = 1:length(sampleIdx)
            idx = sampleIdx(i);
            fprintf('  Star %d (X=%.1f, Y=%.1f): Field_Corr=%.4f mag, MAG_ZP=%.4f\n', ...
                idx, CatalogAB.X(idx), CatalogAB.Y(idx), ...
                CatalogAB.FIELD_CORRECTION_MAG(idx), CatalogAB.MAG_ZP(idx));
        end
        
        % Verify that MAG_ZP = base_ZP + FIELD_CORRECTION_MAG
        base_zp = CatalogAB.MAG_ZP - CatalogAB.FIELD_CORRECTION_MAG;
        if std(base_zp) < 0.0001  % Should be constant
            fprintf('✓ MAG_ZP = base_ZP + FIELD_CORRECTION_MAG verified\n');
            fprintf('  Base zero-point: %.4f mag\n', mean(base_zp));
        else
            fprintf('✗ MAG_ZP calculation inconsistent\n');
        end
        
        if fc_range > 0.01
            fprintf('✓ Field correction shows spatial variation\n');
        else
            fprintf('⚠ Field correction variation minimal\n');
        end
        
    else
        fprintf('✗ FIELD_CORRECTION_MAG column missing from catalog\n');
        fprintf('Available columns: %s\n', strjoin(CatalogAB.Properties.VariableNames, ', '));
    end
    
    fprintf('\n✓ Field correction column test complete\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end