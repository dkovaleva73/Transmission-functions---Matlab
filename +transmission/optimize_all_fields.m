% Script to optimize transmission parameters for all 24 fields in AstroImage
% and save results to a table
% Author: Assistant
% Date: Aug 2025

%% Initialize
clear; close all;
fprintf('=== OPTIMIZING ALL 24 FIELDS ===\n');
fprintf('Starting at: %s\n\n', string(datetime('now')));

% Load configuration
Config = transmission.inputConfig();

% Initialize storage for results
Nfields = 24;
finalParams_all = cell(Nfields, 1);
optimization_success = false(Nfields, 1);
optimization_times = zeros(Nfields, 1);
num_calibrators = zeros(Nfields, 1);

% Get list of all possible parameter names (we'll fill in what we find)
all_param_names = {'Norm_', 'Tau_aod500', 'Alpha', 'Pwv_cm', 'Dobson_units', ...
                   'Temperature_C', 'Pressure', 'Center', 'Amplitude', 'Sigma', 'Gamma', ...
                   'cx0', 'cx1', 'cx2', 'cx3', 'cx4', 'cy0', 'cy1', 'cy2', 'cy3', 'cy4'};

%% Process each field
for fieldNum = 1:Nfields
    fprintf('\n--- PROCESSING FIELD %d/%d ---\n', fieldNum, Nfields);
    tic_field = tic;
    
    try
        % Create optimizer
        optimizer = transmission.TransmissionOptimizer(Config, ...
            'Sequence', 'DefaultSequence', ...
            'SigmaClippingEnabled', true, ...
            'Verbose', false);  % Set to false to reduce output clutter
        
        % Run optimization sequence for this field
        fprintf('  Running optimization sequence...\n');
        finalParams = optimizer.runFullSequence(fieldNum);
        
        % Check if we got calibrators
        if isempty(optimizer.CalibratorData) || isempty(optimizer.CalibratorData.Spec)
            fprintf('  No calibrators found for field %d. Skipping.\n', fieldNum);
            optimization_success(fieldNum) = false;
            continue;
        end
        
        fprintf('  Found %d calibrators for field %d\n', length(optimizer.CalibratorData.Spec), fieldNum);
        num_calibrators(fieldNum) = length(optimizer.CalibratorData.Spec);
        finalParams_all{fieldNum} = finalParams;
        optimization_success(fieldNum) = true;
        
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
        
    catch ME
        fprintf('  ERROR in field %d: %s\n', fieldNum, ME.message);
        optimization_success(fieldNum) = false;
    end
    
    optimization_times(fieldNum) = toc(tic_field);
    fprintf('  Time for field %d: %.2f seconds\n', fieldNum, optimization_times(fieldNum));
end

%% Create results table
fprintf('\n=== CREATING RESULTS TABLE ===\n');

% Initialize table with field numbers
Field_Number = (1:Nfields)';
Success = optimization_success;
Num_Calibrators = num_calibrators;
Time_Seconds = optimization_times;

% Create initial table
finalParams_table = table(Field_Number, Success, Num_Calibrators, Time_Seconds);

% Add columns for each parameter
for i = 1:length(all_param_names)
    param_name = all_param_names{i};
    param_values = NaN(Nfields, 1);
    
    for fieldNum = 1:Nfields
        if optimization_success(fieldNum) && ~isempty(finalParams_all{fieldNum})
            if isfield(finalParams_all{fieldNum}, param_name)
                param_values(fieldNum) = finalParams_all{fieldNum}.(param_name);
            end
        end
    end
    
    % Add to table
    finalParams_table.(param_name) = param_values;
end

%% Save results
timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
mat_filename = sprintf('optimization_all_fields_%s.mat', timestamp);
csv_filename = sprintf('optimization_all_fields_%s.csv', timestamp);

% Save MAT file with all data
save(mat_filename, 'finalParams_all', 'finalParams_table', 'optimization_success', ...
     'optimization_times', 'num_calibrators');

% Save CSV table for easy viewing
writetable(finalParams_table, csv_filename);

fprintf('\nResults saved to:\n');
fprintf('  MAT file: %s\n', mat_filename);
fprintf('  CSV file: %s\n', csv_filename);

%% Print summary
fprintf('\n=== OPTIMIZATION SUMMARY ===\n');
fprintf('Fields successfully optimized: %d/%d\n', sum(optimization_success), Nfields);
fprintf('Total time: %.2f minutes\n', sum(optimization_times)/60);
fprintf('Average time per field: %.2f seconds\n', mean(optimization_times(optimization_success)));

% Display table summary
successful_fields = finalParams_table(finalParams_table.Success == true, :);
if height(successful_fields) > 0
    fprintf('\nSuccessful optimizations:\n');
    disp(successful_fields(:, {'Field_Number', 'Num_Calibrators', 'Norm_', 'Tau_aod500', 'Pwv_cm'}));
end

fprintf('\n=== OPTIMIZATION COMPLETE ===\n');
fprintf('Finished at: %s\n', string(datetime('now')));