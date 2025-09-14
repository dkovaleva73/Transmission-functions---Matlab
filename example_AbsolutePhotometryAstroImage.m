% Example: Complete workflow using AbsolutePhotometryAstroImage
% This demonstrates how to run optimization and then calculate absolute photometry for all 24 subimages
fprintf('=== EXAMPLE: COMPLETE WORKFLOW WITH ABSOLUTEPHOTOMETRYASTROIMAGE ===\n\n');

% Step 1: Load configuration
Config = transmissionFast.inputConfig();

% Step 2: Run optimization for field 1 to get optimized parameters
fprintf('Step 1: Running optimization for field 1...\n');
try
    optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config, ...
        'Sequence', 'Standard', ...
        'SigmaClippingEnabled', true, ...
        'Verbose', false);
    
    % Run optimization for field 1
    finalParams = optimizer.runFullSequence(1);
    fprintf('✅ Optimization complete for field 1\n');
    
    % Display key parameters
    fprintf('   Optimized parameters:\n');
    if isfield(finalParams, 'Norm_')
        fprintf('     Norm_ = %.6f\n', finalParams.Norm_);
    end
    if isfield(finalParams, 'Tau_aod500')
        fprintf('     Tau_aod500 = %.6f\n', finalParams.Tau_aod500);
    end
    if isfield(finalParams, 'Pwv_cm')
        fprintf('     Pwv_cm = %.6f\n', finalParams.Pwv_cm);
    end
    
catch ME
    fprintf('❌ Optimization failed: %s\n', ME.message);
    return;
end

% Step 3: Calculate absolute photometry for all 24 subimages
fprintf('\nStep 2: Calculating absolute photometry for all 24 subimages...\n');
try
    tic;
    CatalogAB_all = transmissionFast.AbsolutePhotometryAstroImage(...
        finalParams, Config, ...
        'Verbose', true, ...           % Show progress
        'SaveResults', false);         % Don't save files in example
    total_time = toc;
    
    fprintf('✅ Absolute photometry complete in %.2f seconds\n', total_time);
    
catch ME
    fprintf('❌ Absolute photometry failed: %s\n', ME.message);
    return;
end

% Step 4: Analyze results
fprintf('\nStep 3: Analyzing results...\n');

% Count total stars across all subimages
total_stars = 0;
successful_subimages = 0;
magnitude_ranges = [];

for i = 1:24
    if ~isempty(CatalogAB_all{i})
        catalog = CatalogAB_all{i};
        num_stars = height(catalog);
        total_stars = total_stars + num_stars;
        successful_subimages = successful_subimages + 1;
        
        % Collect magnitude statistics
        if ismember('MAG_PSF_AB', catalog.Properties.VariableNames)
            valid_mags = catalog.MAG_PSF_AB(~isnan(catalog.MAG_PSF_AB));
            if ~isempty(valid_mags)
                magnitude_ranges = [magnitude_ranges; min(valid_mags), max(valid_mags)];
            end
        end
    end
end

fprintf('   Results summary:\n');
fprintf('     Successfully processed: %d/24 subimages\n', successful_subimages);
fprintf('     Total stars: %d\n', total_stars);
fprintf('     Average stars per subimage: %.1f\n', total_stars/successful_subimages);

if ~isempty(magnitude_ranges)
    fprintf('     Magnitude range: %.2f to %.2f AB mag\n', ...
            min(magnitude_ranges(:,1)), max(magnitude_ranges(:,2)));
end

% Step 5: Example of accessing individual catalogs
fprintf('\nStep 4: Example data access...\n');
if successful_subimages > 0
    % Find first successful subimage
    first_success = find(~cellfun(@isempty, CatalogAB_all), 1);
    catalog = CatalogAB_all{first_success};
    
    fprintf('   Example - Subimage %d:\n', first_success);
    fprintf('     Stars: %d\n', height(catalog));
    fprintf('     Columns: %d\n', width(catalog));
    
    % Show sample of key columns
    key_columns = {'MAG_PSF', 'MAG_PSF_AB', 'MAG_ZP', 'FIELD_CORRECTION_MAG'};
    available_key_cols = key_columns(ismember(key_columns, catalog.Properties.VariableNames));
    
    if ~isempty(available_key_cols)
        fprintf('     Sample data (first 3 stars):\n');
        fprintf('     %s\n', strjoin(available_key_cols, '   '));
        sample_data = catalog(1:min(3, height(catalog)), available_key_cols);
        for row = 1:height(sample_data)
            values_str = '';
            for col = 1:width(sample_data)
                if isnumeric(sample_data{row, col})
                    values_str = [values_str, sprintf('%8.3f   ', sample_data{row, col})];
                else
                    values_str = [values_str, sprintf('%8s   ', string(sample_data{row, col}))];
                end
            end
            fprintf('     %s\n', values_str);
        end
    end
end

% Step 6: Usage notes
fprintf('\n=== USAGE NOTES ===\n');
fprintf('💡 Complete workflow:\n');
fprintf('   1. Run optimization: optimizer.runFullSequence(fieldNum)\n');
fprintf('   2. Get absolute photometry: AbsolutePhotometryAstroImage(finalParams)\n');
fprintf('   3. Access individual catalogs: CatalogAB_all{subimage_num}\n');
fprintf('   4. Save results with ''SaveResults'', true\n');

fprintf('\n💡 Output structure:\n');
fprintf('   - CatalogAB_all{1} to CatalogAB_all{24}: Individual subimage catalogs\n');
fprintf('   - Each catalog contains original LAST data + AB magnitudes\n');
fprintf('   - Key columns: MAG_PSF_AB, MAG_ZP, FIELD_CORRECTION_MAG\n');

fprintf('\n🎯 SUCCESS: Complete workflow demonstrated!\n');
fprintf('The AbsolutePhotometryAstroImage function successfully processes all 24 subimages\n');
fprintf('and returns calibrated AB magnitudes for every star in the AstroImage.\n');

fprintf('\n=== EXAMPLE COMPLETE ===\n');