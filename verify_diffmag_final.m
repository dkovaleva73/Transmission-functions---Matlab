%% Verify Final DiffMag Results
try
    fprintf('=== Final DiffMag Verification ===\n');
    
    % Run complete test
    Config = transmission.inputConfig();
    optimizer = transmission.TransmissionOptimizer(Config, 'Verbose', false);
    optimizer.loadCalibratorData(1);
    
    % Simple optimization stage
    stage = struct();
    stage.name = "NormOnly";
    stage.description = "Normalize only";
    stage.freeParams = ["Norm_"];
    stage.sigmaClipping = false;
    
    stageResult = optimizer.runSingleStage(stage);
    
    % Calculate photometry with DiffMag
    CatalogAB = transmission.calculateAbsolutePhotometry(...
        stageResult.OptimalParams, Config, ...
        'CalibDiffMag', stageResult.ResultData.DiffMag, ...
        'CalibIndices', stageResult.ResultData.CalibIndices, ...
        'Verbose', false);
    
    % Check results
    fprintf('Catalog size: %d stars\n', height(CatalogAB));
    
    if ismember('DIFF_MAG', CatalogAB.Properties.VariableNames)
        validDiffMag = ~isnan(CatalogAB.DIFF_MAG);
        fprintf('Stars with valid DIFF_MAG: %d\n', sum(validDiffMag));
        
        if sum(validDiffMag) > 0
            fprintf('✓ DIFF_MAG working! Statistics:\n');
            fprintf('  Mean: %.4f\n', mean(CatalogAB.DIFF_MAG(validDiffMag)));
            fprintf('  Std: %.4f\n', std(CatalogAB.DIFF_MAG(validDiffMag)));
            fprintf('  Range: %.4f to %.4f\n', min(CatalogAB.DIFF_MAG(validDiffMag)), ...
                max(CatalogAB.DIFF_MAG(validDiffMag)));
        else
            fprintf('✗ All DIFF_MAG values are NaN\n');
            
            % Debug: Check what we passed
            fprintf('Debug info:\n');
            fprintf('  CalibDiffMag length: %d\n', length(stageResult.ResultData.DiffMag));
            fprintf('  CalibIndices length: %d\n', length(stageResult.ResultData.CalibIndices));
            fprintf('  CalibIndices sample: %s\n', mat2str(stageResult.ResultData.CalibIndices(1:5)));
        end
    else
        fprintf('✗ DIFF_MAG column missing\n');
    end
    
catch ME
    fprintf('✗ Error: %s\n', ME.message);
end