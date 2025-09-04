%% Test DIFF_MAG Output
try
    fprintf('=== Testing DIFF_MAG Output ===\n');
    
    % Create test parameters
    OptimizedParams = struct();
    OptimizedParams.Norm_ = 0.8;
    OptimizedParams.Center = 570;
    OptimizedParams.kx0 = 0.01;
    
    Config = transmission.inputConfig();
    
    % Calculate absolute photometry
    CatalogAB = transmission.calculateAbsolutePhotometry(OptimizedParams, Config, 'Verbose', false);
    
    % Check if DIFF_MAG column exists
    if ismember('DIFF_MAG', CatalogAB.Properties.VariableNames)
        fprintf('✓ DIFF_MAG column added to catalog\n');
        
        % Analyze DIFF_MAG values
        valid_diffmag = ~isnan(CatalogAB.DIFF_MAG);
        num_valid = sum(valid_diffmag);
        
        fprintf('\nDIFF_MAG statistics:\n');
        fprintf('  Valid values: %d/%d\n', num_valid, height(CatalogAB));
        
        if num_valid > 0
            fprintf('  Mean: %.4f mag\n', mean(CatalogAB.DIFF_MAG(valid_diffmag)));
            fprintf('  Std: %.4f mag\n', std(CatalogAB.DIFF_MAG(valid_diffmag)));
            fprintf('  Min: %.4f mag\n', min(CatalogAB.DIFF_MAG(valid_diffmag)));
            fprintf('  Max: %.4f mag\n', max(CatalogAB.DIFF_MAG(valid_diffmag)));
            
            % Check if we have FLUX_APER_3
            if ismember('FLUX_APER_3', CatalogAB.Properties.VariableNames)
                valid_flux = ~isnan(CatalogAB.FLUX_APER_3) & CatalogAB.FLUX_APER_3 > 0;
                fprintf('  Stars with FLUX_APER_3: %d\n', sum(valid_flux));
            else
                fprintf('  WARNING: FLUX_APER_3 column not found\n');
            end
            
            % Show sample values
            fprintf('\nSample DIFF_MAG values:\n');
            sampleIdx = find(valid_diffmag, 5);
            for i = 1:length(sampleIdx)
                idx = sampleIdx(i);
                fprintf('  Star %d: DIFF_MAG=%.4f, MAG_PSF_AB=%.2f\n', ...
                    idx, CatalogAB.DIFF_MAG(idx), CatalogAB.MAG_PSF_AB(idx));
            end
        else
            fprintf('  No valid DIFF_MAG values found\n');
        end
    else
        fprintf('✗ DIFF_MAG column missing from catalog\n');
        fprintf('Available columns: %s\n', strjoin(CatalogAB.Properties.VariableNames, ', '));
    end
    
    fprintf('\n✓ DIFF_MAG test complete\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end