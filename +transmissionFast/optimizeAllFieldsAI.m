function [finalParams_all, calibratorResults_all, finalParams_table] = optimizeAllFieldsAI(Args)
    % Optimize transmission parameters for all 24 fields in AstroImage
    % Uses cached data from field 1 for fields 2-24 to improve performance
    % Input (optional):
    %   'Nfields' - Number of fields to process (default: 24)
    %   'Sequence' - Optimization sequence name (default: 'Advanced')
    %   'Verbose' - Show detailed output (default: false)
    %   'SaveResults' - Save results to files (default: true)
    % Output:
    %   finalParams_all - Cell array of optimized parameters for each field
    %   calibratorResults_all - Cell array of calibrator tables for each field
    %   finalParams_table - Summary table with all fields and parameters
    %
    % Example:
    %   [params, calibs, table] = transmissionFast.optimizeAllFieldsAI();
    %   [params, ~, table] = transmissionFast.optimizeAllFieldsAI('Nfields', 5, 'Verbose', true);
    %
    % Author: D. Kovaleva (Sep 2025)
    
    arguments
        Args.Nfields (1,1) double {mustBePositive, mustBeInteger} = 24
        Args.Sequence string = "Advanced"
        Args.Verbose (1,1) logical = false
        Args.SaveResults (1,1) logical = true
    end
    
    % Initialize
    fprintf('=== OPTIMIZING %d FIELDS ===\n', Args.Nfields);
    startTime = datetime('now');
    
    % Load configuration once
    Config = transmissionFast.inputConfig('default', true);
    
    % Initialize storage
    finalParams_all = cell(Args.Nfields, 1);
    calibratorResults_all = cell(Args.Nfields, 1);
    optimization_success = false(Args.Nfields, 1);
    optimization_times = zeros(Args.Nfields, 1);
    num_calibrators = zeros(Args.Nfields, 1);
    
    % Process field 1 first (creates caches)
    fprintf('\nField 1/%d: ', Args.Nfields);
    tic_field = tic;
    
    try
        % Create optimizer for field 1
        optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config, ...
            'Sequence', Args.Sequence, ...
            'SigmaClippingEnabled', true, ...
            'Verbose', Args.Verbose);
        
        % Run field 1 - this caches AbsorptionData, mirrorReflectance, correctorTransmission
        finalParams = optimizer.runFullSequence(1);
        
        if ~isempty(optimizer.CalibratorData) && ~isempty(optimizer.CalibratorData.Spec)
            finalParams_all{1} = finalParams;
            optimization_success(1) = true;
            num_calibrators(1) = length(optimizer.CalibratorData.Spec);
            
            % Get calibrator results if available
            try
                calibratorResults_all{1} = optimizer.getCalibratorResults();
            catch
                % Silent fail - calibrator results optional
            end
            
            fprintf('%d calibrators, %.1fs\n', num_calibrators(1), toc(tic_field));
        else
            fprintf('No calibrators\n');
        end
    catch ME
        fprintf('ERROR: %s\n', ME.message);
    end
    
    optimization_times(1) = toc(tic_field);
    
    % Process fields 2-24 (using cached data from field 1)
    for fieldNum = 2:Args.Nfields
        fprintf('Field %d/%d: ', fieldNum, Args.Nfields);
        tic_field = tic;
        
        try
            % Create new optimizer (reuses cached instrumental data)
            optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config, ...
                'Sequence', Args.Sequence, ...
                'SigmaClippingEnabled', true, ...
                'Verbose', false);  % Always minimal output for fields 2+
            
            % Run optimization for this field
            finalParams = optimizer.runFullSequence(fieldNum);
            
            if ~isempty(optimizer.CalibratorData) && ~isempty(optimizer.CalibratorData.Spec)
                finalParams_all{fieldNum} = finalParams;
                optimization_success(fieldNum) = true;
                num_calibrators(fieldNum) = length(optimizer.CalibratorData.Spec);
                
                % Get calibrator results if available
                try
                    calibratorResults_all{fieldNum} = optimizer.getCalibratorResults();
                catch
                    % Silent fail
                end
                
                fprintf('%d calibrators, %.1fs\n', num_calibrators(fieldNum), toc(tic_field));
            else
                fprintf('No calibrators\n');
            end
        catch ME
            fprintf('ERROR: %s\n', ME.message);
        end
        
        optimization_times(fieldNum) = toc(tic_field);
    end
    
    % Create results table
    Field_Number = (1:Args.Nfields)';
    Success = optimization_success;
    Num_Calibrators = num_calibrators;
    Time_Seconds = optimization_times;
    
    finalParams_table = table(Field_Number, Success, Num_Calibrators, Time_Seconds);
    
    % Add key parameter columns if they exist
    key_params = {'Norm_', 'Tau_aod500', 'Pwv_cm', 'Alpha', 'Dobson_units'};
    for param_name = key_params
        param_values = NaN(Args.Nfields, 1);
        for fieldNum = 1:Args.Nfields
            if optimization_success(fieldNum) && ~isempty(finalParams_all{fieldNum})
                if isfield(finalParams_all{fieldNum}, param_name{1})
                    param_values(fieldNum) = finalParams_all{fieldNum}.(param_name{1});
                end
            end
        end
        finalParams_table.(param_name{1}) = param_values;
    end
    
    % Save results if requested
    if Args.SaveResults
        timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        mat_filename = sprintf('optimization_all_fields_%s.mat', timestamp);
        csv_filename = sprintf('optimization_all_fields_%s.csv', timestamp);
        
        save(mat_filename, 'finalParams_all', 'calibratorResults_all', 'finalParams_table', ...
             'optimization_success', 'optimization_times', 'num_calibrators');
        writetable(finalParams_table, csv_filename);
        
        % Save individual calibrator tables
        if any(~cellfun(@isempty, calibratorResults_all))
            calibrator_results_dir = sprintf('calibrator_results_%s', timestamp);
            if ~exist(calibrator_results_dir, 'dir')
                mkdir(calibrator_results_dir);
            end
            
            for fieldNum = 1:Args.Nfields
                if optimization_success(fieldNum) && ~isempty(calibratorResults_all{fieldNum})
                    calib_filename = fullfile(calibrator_results_dir, ...
                        sprintf('field_%02d_calibrators.csv', fieldNum));
                    writetable(calibratorResults_all{fieldNum}, calib_filename);
                end
            end
            fprintf('\nResults saved: %s\n', mat_filename);
        end
    end
    
    % Summary
    fprintf('\n=== SUMMARY ===\n');
    fprintf('Success: %d/%d fields\n', sum(optimization_success), Args.Nfields);
    fprintf('Total time: %.1f min\n', sum(optimization_times)/60);
    fprintf('Avg time/field: %.1f s\n', mean(optimization_times(optimization_success)));
    
    % Display RMS statistics if available
    if any(~cellfun(@isempty, calibratorResults_all))
        rms_values = [];
        for fieldNum = 1:Args.Nfields
            if optimization_success(fieldNum) && ~isempty(calibratorResults_all{fieldNum})
                calibTable = calibratorResults_all{fieldNum};
                if ismember('DIFF_MAG', calibTable.Properties.VariableNames)
                    rms_values(end+1) = rms(calibTable.DIFF_MAG);
                end
            end
        end
        if ~isempty(rms_values)
            fprintf('Avg RMS(DIFF_MAG): %.4f\n', mean(rms_values));
        end
    end
    
    fprintf('Completed: %s\n', string(datetime('now')));
end