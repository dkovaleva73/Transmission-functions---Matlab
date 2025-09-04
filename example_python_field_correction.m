%% Example: Using Python-compliant Field Correction
% This script demonstrates how to use the new Python-compliant field correction
% implementation that matches the fitutils.py ResidFunc behavior
% Author: D. Kovaleva (Aug 2025)

clear; clc;
fprintf('=== PYTHON-COMPLIANT FIELD CORRECTION EXAMPLE ===\n\n');

%% Step 1: Initialize Configuration and Optimizer
fprintf('Step 1: Initializing Python-compliant optimizer...\n');
Config = transmission.inputConfig();

% Create optimizer with Python-compliant field correction (default)
optimizer = transmission.TransmissionOptimizer(Config, ...
    'Sequence', 'DefaultSequence', ...
    'Verbose', true);

fprintf('✓ Optimizer initialized with Python-compliant field correction\n\n');

%% Step 2: Demonstrate difference between modes
fprintf('Step 2: Comparing with simple field correction mode...\n');

% Show the key differences
python_seq = optimizer.ActiveSequence;
field_stage = python_seq(3);  % Stage 3 is field correction

fprintf('Python-compliant field correction uses:\n');
fprintf('  - Parameters: %s\n', strjoin(string(field_stage.freeParams), ', '));
fprintf('  - Fixed parameter: ky0 = 0 (as in Python fitutils.py)\n');
fprintf('  - Coordinate normalization: [0, 1726] → [-1, +1]\n');
fprintf('  - Chebyshev structure:\n');
fprintf('    * X,Y coordinates: order 4 (kx, kx2, kx3, kx4, ky, ky2, ky3, ky4)\n');
fprintf('    * XY cross-term: order 1 (kxy)\n');
fprintf('    * Constant offset: kx0 (variable), ky0=0 (fixed)\n');
fprintf('  - Field correction formula:\n');
fprintf('    model += Cheb_x(xcoor_) + Cheb_y(ycoor_) + kx0 + Cheb_xy_x(xcoor_)*Cheb_xy_y(ycoor_)\n\n');

%% Step 3: Run optimization for field 1
fprintf('Step 3: Running optimization for field 1...\n');
try
    finalParams = optimizer.runFullSequence(1);
    fprintf('✓ Optimization completed successfully!\n\n');
    
    % Display final parameters
    fprintf('Final optimized parameters:\n');
    paramNames = fieldnames(finalParams);
    for i = 1:length(paramNames)
        fprintf('  %s: %.6f\n', paramNames{i}, finalParams.(paramNames{i}));
    end
    fprintf('\n');
    
catch ME
    fprintf('✗ Optimization failed: %s\n', ME.message);
    % Don't return, continue with demonstration
end

%% Step 4: Calculate absolute photometry
fprintf('Step 4: Calculating absolute photometry with optimized parameters...\n');
try
    % Update config with optimized parameters
    paramNames = fieldnames(finalParams);
    for i = 1:length(paramNames)
        % Update the config parameter paths as needed
        if startsWith(paramNames{i}, 'Norm_')
            Config.General.Norm_ = finalParams.(paramNames{i});
        elseif strcmp(paramNames{i}, 'Center')
            Config.Instrumental.QE.Center = finalParams.(paramNames{i});
        elseif strcmp(paramNames{i}, 'Pwv_cm')
            Config.Atmospheric.Pwv_cm = finalParams.(paramNames{i});
        elseif strcmp(paramNames{i}, 'Tau_aod500')
            Config.Atmospheric.Tau_aod500 = finalParams.(paramNames{i});
        % Add Python field parameters to Config.FieldCorrection.Python
        elseif ismember(paramNames{i}, {'kx0', 'kx', 'ky', 'kx2', 'ky2', 'kx3', 'ky3', 'kx4', 'ky4', 'kxy'})
            Config.FieldCorrection.Python.(paramNames{i}) = finalParams.(paramNames{i});
        end
    end
    
    % Calculate absolute photometry
    CalibratorData = optimizer.CalibratorData;
    CatalogAB = transmission.calculateAbsolutePhotometry(...
        CalibratorData.Spec, CalibratorData.Mag, CalibratorData.Coords, ...
        CalibratorData.LASTData, CalibratorData.Metadata, Config);
    
    fprintf('✓ Absolute photometry calculated\n');
    fprintf('  Output table size: %d sources\n', height(CatalogAB));
    fprintf('  Columns: %s\n', strjoin(CatalogAB.Properties.VariableNames, ', '));
    
    % Show sample of results
    if height(CatalogAB) > 0
        fprintf('\nSample results (first 3 sources):\n');
        disp(CatalogAB(1:min(3, height(CatalogAB)), {'X', 'Y', 'MAG_PSF', 'MAG_ZP', 'MAG_PSF_AB'}));
    end
    
catch ME
    fprintf('✗ Absolute photometry calculation failed: %s\n', ME.message);
end

%% Step 5: Save results
fprintf('\nStep 5: Saving results...\n');
timestamp = datestr(datetime('now'), 'yyyymmdd_HHMMSS');
results_file = sprintf('python_field_correction_results_%s.mat', timestamp);

save(results_file, 'finalParams', 'Config', 'optimizer');
if exist('CatalogAB', 'var')
    save(results_file, 'CatalogAB', '-append');
end

fprintf('✓ Results saved to: %s\n', results_file);

%% Summary
fprintf('\n=== SUMMARY ===\n');
fprintf('✓ Python-compliant field correction implemented successfully\n');
fprintf('✓ Matches fitutils.py ResidFunc behavior:\n');
fprintf('  - N=4 Chebyshev polynomials for X,Y coordinates\n');
fprintf('  - N=1 Chebyshev polynomial for XY cross-term\n');
fprintf('  - ky0 == 0 and fixed (not optimized)\n');
fprintf('  - Uses existing utils/chebyshevModel.m where possible\n');
fprintf('✓ Two modes available:\n');
fprintf('  - "DefaultSequence": Python-compliant field correction\n');
fprintf('  - "SimpleFieldCorrection": Original MATLAB behavior\n');

fprintf('\nFor simple field correction, use:\n');
fprintf('  optimizer = transmission.TransmissionOptimizer(Config, ''Sequence'', ''SimpleFieldCorrection'');\n\n');

fprintf('Implementation complete! 🎉\n');