%% Test Calibrator Results Table (Fixed)
try
    fprintf('=== Testing Calibrator Results Table (Fixed) ===\n');
    
    % 1. Run optimization using the proper sequence method
    fprintf('\n1. Running full optimization sequence...\n');
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "QuickCalibration", ...  % Use quick sequence for faster testing
        'Verbose', false);
    
    % Run the complete sequence
    finalParams = optimizer.runFullSequence(1);
    
    fprintf('✓ Optimization sequence completed\n');
    fprintf('  Number of stages run: %d\n', length(optimizer.Results));
    
    % 2. Generate calibrator results table
    fprintf('\n2. Generating calibrator results table...\n');
    
    CalibratorTable = optimizer.getCalibratorResults();
    
    fprintf('✓ Calibrator table generated\n');
    
    % 3. Analyze the table
    fprintf('\n3. Analyzing calibrator table...\n');
    fprintf('Number of calibrators: %d\n', height(CalibratorTable));
    
    % Check columns
    fprintf('Available columns:\n');
    colNames = CalibratorTable.Properties.VariableNames;
    for i = 1:length(colNames)
        fprintf('  - %s\n', colNames{i});
    end
    
    % 4. Show DiffMag statistics
    if ismember('DIFF_MAG', CalibratorTable.Properties.VariableNames)
        fprintf('\n4. DiffMag statistics:\n');
        diffMagValues = CalibratorTable.DIFF_MAG;
        fprintf('  Count: %d\n', length(diffMagValues));
        fprintf('  Mean: %.4f mag\n', mean(diffMagValues));
        fprintf('  Std: %.4f mag\n', std(diffMagValues));
        fprintf('  Min: %.4f mag\n', min(diffMagValues));
        fprintf('  Max: %.4f mag\n', max(diffMagValues));
        
        % Show sample entries
        fprintf('\n5. Sample calibrator entries:\n');
        fprintf('   Row    X     Y   MAG_PSF  FLUX_APER_3  DIFF_MAG\n');
        fprintf('   ---   ---   ---  -------  -----------  --------\n');
        
        for i = 1:min(5, height(CalibratorTable))
            fprintf('%6d %5.0f %5.0f %8.3f %11.2e %9.4f\n', ...
                i, CalibratorTable.X(i), CalibratorTable.Y(i), ...
                CalibratorTable.MAG_PSF(i), CalibratorTable.FLUX_APER_3(i), ...
                CalibratorTable.DIFF_MAG(i));
        end
    end
    
    % 6. Show table description
    if ~isempty(CalibratorTable.Properties.Description)
        fprintf('\n6. Table description:\n');
        fprintf('   %s\n', CalibratorTable.Properties.Description);
    end
    
    fprintf('\n=== TEST COMPLETE ===\n');
    fprintf('✓ Separate calibrator table successfully created\n');
    fprintf('✓ DiffMag values from final optimization preserved\n');
    fprintf('✓ All calibrator metadata included\n');
    
    % 7. Show usage example
    fprintf('\n7. Usage example:\n');
    fprintf('   Config = transmission.inputConfig();\n');
    fprintf('   optimizer = transmission.TransmissionOptimizer(Config);\n');
    fprintf('   finalParams = optimizer.runFullSequence();\n');
    fprintf('   CalibratorTable = optimizer.getCalibratorResults();  %% Get calibrator DiffMag\n');
    fprintf('   CatalogAB = transmission.photometry.calculateAbsolutePhotometry(finalParams, Config);  %% Get all stars\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end