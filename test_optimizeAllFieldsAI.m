% Test the optimizeAllFieldsAI function with just 1 field
fprintf('=== TESTING optimizeAllFieldsAI WITH SINGLE FIELD ===\n\n');

% Load configuration
Config = transmissionFast.inputConfig('default', true);

% Test with field 1 only
fieldNum = 1;
fprintf('Testing field %d...\n', fieldNum);

try
    % Create optimizer
    optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config, ...
        'Sequence', 'Standard', ...
        'SigmaClippingEnabled', true, ...
        'Verbose', false);
    
    % Run optimization sequence
    fprintf('Running optimization sequence...\n');
    tic;
    finalParams = optimizer.runFullSequence(fieldNum);
    time_opt = toc;
    
    fprintf('Optimization completed in %.2f seconds\n', time_opt);
    
    % Check if we got calibrators
    if isempty(optimizer.CalibratorData) || isempty(optimizer.CalibratorData.Spec)
        fprintf('No calibrators found for field %d.\n', fieldNum);
    else
        fprintf('Found %d calibrators\n', length(optimizer.CalibratorData.Spec));
        
        % Get calibrator results table
        try
            calibratorTable = optimizer.getCalibratorResults();
            fprintf('✅ Got calibrator results table with %d entries\n', height(calibratorTable));
            
            % Display first few rows
            fprintf('\nFirst 5 calibrators:\n');
            fprintf('Available columns: %s\n', strjoin(calibratorTable.Properties.VariableNames, ', '));
            
            % Try to display relevant columns
            cols_to_show = {};
            if ismember('LAST_IDX', calibratorTable.Properties.VariableNames)
                cols_to_show{end+1} = 'LAST_IDX';
            elseif ismember('IDX', calibratorTable.Properties.VariableNames)
                cols_to_show{end+1} = 'IDX';
            end
            if ismember('MAG_LAST', calibratorTable.Properties.VariableNames)
                cols_to_show{end+1} = 'MAG_LAST';
            elseif ismember('Mag_LAST', calibratorTable.Properties.VariableNames)
                cols_to_show{end+1} = 'Mag_LAST';
            end
            if ismember('DIFF_MAG', calibratorTable.Properties.VariableNames)
                cols_to_show{end+1} = 'DIFF_MAG';
            end
            
            if ~isempty(cols_to_show)
                if height(calibratorTable) >= 5
                    disp(calibratorTable(1:5, cols_to_show));
                else
                    disp(calibratorTable(:, cols_to_show));
                end
            end
            
            % Calculate RMS
            if ismember('DIFF_MAG', calibratorTable.Properties.VariableNames)
                rms_diffmag = rms(calibratorTable.DIFF_MAG);
                fprintf('\nRMS(DIFF_MAG) = %.4f\n', rms_diffmag);
            end
            
        catch ME
            fprintf('❌ Could not get calibrator results: %s\n', ME.message);
        end
        
        % Display optimized parameters
        fprintf('\nOptimized parameters:\n');
        if isfield(finalParams, 'Norm_')
            fprintf('  Norm_ = %.6f\n', finalParams.Norm_);
        end
        if isfield(finalParams, 'Tau_aod500')
            fprintf('  Tau_aod500 = %.6f\n', finalParams.Tau_aod500);
        end
        if isfield(finalParams, 'Pwv_cm')
            fprintf('  Pwv_cm = %.6f\n', finalParams.Pwv_cm);
        end
    end
    
    fprintf('\n✅ TEST SUCCESSFUL - optimizeAllFieldsAI should work correctly!\n');
    
catch ME
    fprintf('\n❌ TEST FAILED: %s\n', ME.message);
    fprintf('Error in: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
end

fprintf('\n=== TEST COMPLETE ===\n');