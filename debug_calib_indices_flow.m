%% Debug Calibrator Indices Flow
try
    fprintf('=== Debug Calibrator Indices Flow ===\n');
    
    % 1. Test TransmissionOptimizer calibrator data loading
    fprintf('\n1. Testing TransmissionOptimizer...\n');
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, 'Verbose', false);
    optimizer.loadCalibratorData(1);
    
    % Check if CatalogIndices exist
    if isfield(optimizer.CalibratorData, 'CatalogIndices')
        fprintf('✓ CatalogIndices found in optimizer.CalibratorData\n');
        fprintf('  Number of indices: %d\n', length(optimizer.CalibratorData.CatalogIndices));
        fprintf('  Index range: %d to %d\n', min(optimizer.CalibratorData.CatalogIndices), ...
            max(optimizer.CalibratorData.CatalogIndices));
    else
        fprintf('✗ CatalogIndices missing from optimizer.CalibratorData\n');
    end
    
    % 2. Test minimizerFminGeneric with the calibrator data
    fprintf('\n2. Testing minimizerFminGeneric...\n');
    [OptimalParams, Fval, ExitFlag, Output, ResultData] = ...
        transmission.minimizerFminGeneric(Config, ...
        'FreeParams', ["Norm_"], ...
        'InputData', optimizer.CalibratorData, ...
        'Verbose', false);
    
    % Check if indices made it through
    if isfield(ResultData, 'CalibIndices')
        fprintf('✓ CalibIndices found in ResultData\n');
        fprintf('  Number of indices: %d\n', length(ResultData.CalibIndices));
        if ~isempty(ResultData.CalibIndices)
            fprintf('  Index range: %d to %d\n', min(ResultData.CalibIndices), ...
                max(ResultData.CalibIndices));
        end
    else
        fprintf('✗ CalibIndices missing from ResultData\n');
    end
    
    % Check DiffMag
    if isfield(ResultData, 'DiffMag')
        fprintf('✓ DiffMag found in ResultData\n');
        fprintf('  Number of DiffMag values: %d\n', length(ResultData.DiffMag));
    else
        fprintf('✗ DiffMag missing from ResultData\n');
    end
    
    % 3. Test calculateAbsolutePhotometry with explicit parameters
    fprintf('\n3. Testing calculateAbsolutePhotometry...\n');
    
    if exist('ResultData', 'var') && isfield(ResultData, 'DiffMag') && isfield(ResultData, 'CalibIndices')
        fprintf('Calling calculateAbsolutePhotometry with:\n');
        fprintf('  CalibDiffMag: %d values\n', length(ResultData.DiffMag));
        fprintf('  CalibIndices: %d values\n', length(ResultData.CalibIndices));
        
        CatalogAB = transmission.photometry.calculateAbsolutePhotometry(...
            OptimalParams, Config, ...
            'CalibDiffMag', ResultData.DiffMag, ...
            'CalibIndices', ResultData.CalibIndices, ...
            'Verbose', true);  % Enable verbose to see if mapping happens
    end
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end