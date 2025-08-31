%% Debug DiffMag Mapping
try
    fprintf('=== Debug DiffMag Mapping ===\n');
    
    % Run a simple test to see what indices we're getting
    Config = transmission.inputConfig();
    
    % Get calibrator data
    [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoords(...
        Config.Data.LAST_catalog_file, Config.Data.Search_radius_arcsec);
    
    % Check the indices
    if ~isempty(Coords)
        lastIndices = [Coords.LAST_idx];
        fprintf('Number of calibrators: %d\n', length(Coords));
        fprintf('LAST indices range: %d to %d\n', min(lastIndices), max(lastIndices));
        fprintf('Sample indices: %s\n', mat2str(lastIndices(1:min(5, length(lastIndices)))));
    end
    
    % Load full catalog to check size
    AC = AstroCatalog(Config.Data.LAST_catalog_file);
    fullCatalogSize = height(AC.Table);
    fprintf('Full catalog size: %d\n', fullCatalogSize);
    
    % Check if indices are valid
    validIndices = lastIndices <= fullCatalogSize & lastIndices > 0;
    fprintf('Valid indices: %d/%d\n', sum(validIndices), length(lastIndices));
    
    % Test the mapping manually
    testDiffMag = randn(length(lastIndices), 1);  % Random test values
    testArray = NaN(fullCatalogSize, 1);
    
    % Manual mapping
    for i = 1:length(lastIndices)
        idx = lastIndices(i);
        if idx > 0 && idx <= fullCatalogSize
            testArray(idx) = testDiffMag(i);
        end
    end
    
    numMapped = sum(~isnan(testArray));
    fprintf('Successfully mapped: %d values\n', numMapped);
    
    if numMapped == length(lastIndices)
        fprintf('✓ Index mapping should work correctly\n');
    else
        fprintf('✗ Index mapping has issues\n');
    end
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
end