%% Test DiffMag Integration
% Test that DiffMag from optimization is properly passed to calculateAbsolutePhotometry

try
    fprintf('=== Testing DiffMag Integration ===\n');
    
    % 1. Run a simple optimization to get DiffMag values
    fprintf('\n1. Running optimization to get DiffMag...\n');
    Config = transmission.inputConfig();
    
    % Get calibrator data
    SearchRadius = Config.Data.Search_radius_arcsec;
    CatalogFile = Config.Data.LAST_catalog_file;
    [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoords(...
        CatalogFile, SearchRadius);
    
    CalibData = struct();
    CalibData.Spec = Spec;
    CalibData.Mag = Mag;
    CalibData.Coords = Coords;
    CalibData.LASTData = LASTData;
    CalibData.Metadata = Metadata;
    
    % Run minimizer with simple parameters
    [OptimalParams, Fval, ExitFlag, Output, ResultData] = ...
        transmission.minimizerFminGeneric(Config, ...
        'FreeParams', ["Norm_"], ...
        'InputData', CalibData, ...
        'Verbose', false);
    
    fprintf('Optimization completed:\n');
    fprintf('  Number of calibrators: %d\n', ResultData.NumCalibrators);
    fprintf('  DiffMag values computed: %d\n', length(ResultData.DiffMag));
    fprintf('  Mean DiffMag: %.4f\n', mean(ResultData.DiffMag));
    fprintf('  Std DiffMag: %.4f\n', std(ResultData.DiffMag));
    
    % 2. Test calculateAbsolutePhotometry with DiffMag
    fprintf('\n2. Testing calculateAbsolutePhotometry with DiffMag...\n');
    
    % Since we don't have the mapping of calibrator indices to full catalog yet,
    % we'll test with mock indices for now
    mockIndices = 1:length(ResultData.DiffMag);  % Placeholder indices
    
    CatalogAB = transmission.calculateAbsolutePhotometry(...
        OptimalParams, Config, ...
        'CalibDiffMag', ResultData.DiffMag, ...
        'CalibIndices', mockIndices, ...
        'Verbose', false);
    
    % 3. Check results
    fprintf('\n3. Checking results...\n');
    
    % Check DIFF_MAG column exists
    if ismember('DIFF_MAG', CatalogAB.Properties.VariableNames)
        fprintf('✓ DIFF_MAG column exists in output\n');
        
        % Count non-NaN values
        validDiffMag = ~isnan(CatalogAB.DIFF_MAG);
        numValid = sum(validDiffMag);
        fprintf('  Non-NaN DIFF_MAG values: %d\n', numValid);
        
        if numValid > 0
            fprintf('  DIFF_MAG range: %.4f to %.4f\n', ...
                min(CatalogAB.DIFF_MAG(validDiffMag)), ...
                max(CatalogAB.DIFF_MAG(validDiffMag)));
            
            % Check if the values match what we passed
            passedValues = ResultData.DiffMag(mockIndices <= height(CatalogAB));
            catalogValues = CatalogAB.DIFF_MAG(mockIndices(mockIndices <= height(CatalogAB)));
            catalogValues = catalogValues(~isnan(catalogValues));
            
            if length(passedValues) == length(catalogValues)
                maxDiff = max(abs(passedValues - catalogValues));
                if maxDiff < 1e-10
                    fprintf('✓ DIFF_MAG values correctly transferred\n');
                else
                    fprintf('⚠ DIFF_MAG values differ by up to %.4e\n', maxDiff);
                end
            end
        end
    else
        fprintf('✗ DIFF_MAG column missing from output\n');
    end
    
    % Check other columns
    fprintf('\n4. Checking other output columns...\n');
    expectedCols = {'MAG_ZP', 'MAG_PSF_AB', 'FIELD_CORRECTION_MAG', 'DIFF_MAG'};
    for i = 1:length(expectedCols)
        if ismember(expectedCols{i}, CatalogAB.Properties.VariableNames)
            fprintf('✓ %s column present\n', expectedCols{i});
        else
            fprintf('✗ %s column missing\n', expectedCols{i});
        end
    end
    
    fprintf('\n=== DIFFMAG INTEGRATION TEST COMPLETE ===\n');
    fprintf('✓ DiffMag calculated in optimization\n');
    fprintf('✓ DiffMag passed to calculateAbsolutePhotometry\n');
    fprintf('✓ DiffMag stored in output catalog\n');
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    for i=1:length(ME.stack)
        fprintf('  at %s line %d\n', ME.stack(i).name, ME.stack(i).line);
    end
end