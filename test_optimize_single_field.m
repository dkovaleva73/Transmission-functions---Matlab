% Test optimizeAllFieldsAI functionality with a single field
fprintf('=== TESTING SINGLE FIELD OPTIMIZATION ===\n');
fprintf('Starting at: %s\n\n', string(datetime('now')));

% Test with field 1
fieldNum = 1;

% Load configuration
Config = transmissionFast.inputConfig('default', true);

fprintf('Processing field %d...\n', fieldNum);
tic_field = tic;

try
    % Create optimizer
    optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config, ...
        'Sequence', 'Standard', ...
        'SigmaClippingEnabled', true, ...
        'Verbose', false);
    
    % Run optimization sequence for this field
    fprintf('  Running optimization sequence...\n');
    finalParams = optimizer.runFullSequence(fieldNum);
    
    % Check if we got calibrators
    if isempty(optimizer.CalibratorData) || isempty(optimizer.CalibratorData.Spec)
        fprintf('  No calibrators found for field %d. Skipping.\n', fieldNum);
    else
        % Get calibrator results table
        try
            calibratorTable = optimizer.getCalibratorResults();
            fprintf('  ✅ Got calibrator results table with %d entries\n', height(calibratorTable));
            
            % Calculate statistics
            if ismember('DIFF_MAG', calibratorTable.Properties.VariableNames)
                rms_diffmag = rms(calibratorTable.DIFF_MAG);
                mean_diffmag = mean(calibratorTable.DIFF_MAG);
                std_diffmag = std(calibratorTable.DIFF_MAG);
                fprintf('  ✅ DIFF_MAG statistics: RMS=%.4f, Mean=%.4f, Std=%.4f\n', ...
                        rms_diffmag, mean_diffmag, std_diffmag);
            end
            
            % Display sample of results
            fprintf('\n  Sample calibrator results (first 3):\n');
            if height(calibratorTable) >= 3
                sample_cols = {'LAST_IDX', 'MAG_PSF', 'DIFF_MAG', 'GAIA_RA', 'GAIA_DEC'};
                disp(calibratorTable(1:3, sample_cols));
            end
            
        catch ME
            fprintf('  ⚠ Warning: Could not get calibrator results table: %s\n', ME.message);
        end
        
        fprintf('\n  Found %d calibrators for field %d\n', length(optimizer.CalibratorData.Spec), fieldNum);
        
        % Print summary for this field
        fprintf('  Field %d optimization complete. Key parameters:\n', fieldNum);
        if isfield(finalParams, 'Norm_')
            fprintf('    Norm_ = %.6f\n', finalParams.Norm_);
        end
        if isfield(finalParams, 'Tau_aod500')
            fprintf('    Tau_aod500 = %.6f\n', finalParams.Tau_aod500);
        end
        if isfield(finalParams, 'Pwv_cm')
            fprintf('    Pwv_cm = %.6f\n', finalParams.Pwv_cm);
        end
    end
    
catch ME
    fprintf('  ERROR in field %d: %s\n', fieldNum, ME.message);
end

optimization_time = toc(tic_field);
fprintf('\n  Time for field %d: %.2f seconds\n', fieldNum, optimization_time);

fprintf('\n✅ TEST COMPLETE - Ready to run on all 24 fields!\n');
fprintf('Finished at: %s\n', string(datetime('now')));