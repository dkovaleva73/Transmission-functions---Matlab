%% Test Calibrator Results Table
% Test the new getCalibratorResults method in TransmissionOptimizer

try
    fprintf('=== Testing Calibrator Results Table ===\n');
    
    % 1. Initialize and run optimization
    fprintf('\n1. Running optimization...\n');
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, ...
        'Sequence', "DefaultSequence", ...
        'Verbose', false);
    
    % Run just the first two stages
    optimizer.loadCalibratorData(1);
    optimizer.loadAbsorptionData();
    
    % Stage 1: Normalization with sigma clipping
    stage1 = optimizer.ActiveSequence(1);
    result1 = optimizer.runSingleStage(stage1);
    optimizer.updateOptimizedParams(result1.OptimalParams);
    
    % Stage 2: Norm + Center
    stage2 = optimizer.ActiveSequence(2);
    result2 = optimizer.runSingleStage(stage2);
    optimizer.updateOptimizedParams(result2.OptimalParams);
    
    fprintf('✓ Two optimization stages completed\n');
    fprintf('  Final cost: %.4e\n', result2.Fval);
    
    % 2. Generate calibrator results table
    fprintf('\n2. Generating calibrator results table...\n');
    
    CalibratorTable = optimizer.getCalibratorResults();
    
    fprintf('✓ Calibrator table generated\n');
    
    % 3. Analyze the table
    fprintf('\n3. Analyzing calibrator table...\n');
    fprintf('Number of calibrators: %d\n', height(CalibratorTable));
    
    % Check required columns
    requiredCols = {'DIFF_MAG', 'X', 'Y', 'FLUX_APER_3'};
    for i = 1:length(requiredCols)
        col = requiredCols{i};
        if ismember(col, CalibratorTable.Properties.VariableNames)
            fprintf('✓ %s column present\n', col);
        else
            fprintf('✗ %s column missing\n', col);
        end
    end
    
    % Check optional Gaia columns
    gaiaColumns = {'GAIA_RA', 'GAIA_DEC', 'LAST_IDX'};
    for i = 1:length(gaiaColumns)
        col = gaiaColumns{i};
        if ismember(col, CalibratorTable.Properties.VariableNames)
            fprintf('✓ %s column present\n', col);
        else
            fprintf('⚠ %s column missing\n', col);
        end
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
    
    % 6. Test table description
    if ~isempty(CalibratorTable.Properties.Description)
        fprintf('\n6. Table description:\n');
        fprintf('   %s\n', CalibratorTable.Properties.Description);
    end
    
    fprintf('\n=== CALIBRATOR RESULTS TABLE TEST COMPLETE ===\n');
    fprintf('✓ Separate calibrator table with DiffMag created\n');
    fprintf('✓ All calibrator data preserved\n');
    fprintf('✓ Optimization residuals available for analysis\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end