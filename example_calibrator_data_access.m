% Example: Accessing calibrator data from processLAST_LC_Workflow results
% Shows how to work with the CalibratorResults field added to the workflow

fprintf('=== ACCESSING CALIBRATOR DATA FROM WORKFLOW RESULTS ===\n\n');

%% Check if Results exists
if ~exist('Results', 'var')
    fprintf('Results not found. Please run:\n');
    fprintf('  Results = transmissionFast.processLAST_LC_Workflow();\n');
    return;
end

%% Check if CalibratorResults field exists
if ~isfield(Results, 'CalibratorResults')
    fprintf('❌ CalibratorResults field not found in Results structure.\n');
    fprintf('Please re-run the workflow with updated processLAST_LC_Workflow function.\n');
    return;
end

%% Examine calibrator data structure
fprintf('1. CALIBRATOR DATA OVERVIEW:\n');
fprintf('   Number of processed files: %d\n', length(Results.CalibratorResults));

validCalibratorFiles = 0;
totalCalibratorFields = 0;
totalCalibrators = 0;

for fileIdx = 1:length(Results.CalibratorResults)
    if ~isempty(Results.CalibratorResults{fileIdx})
        validCalibratorFiles = validCalibratorFiles + 1;
        
        calibratorData = Results.CalibratorResults{fileIdx};
        if iscell(calibratorData)
            fieldsWithCalibrators = sum(~cellfun(@isempty, calibratorData));
            totalCalibratorFields = totalCalibratorFields + fieldsWithCalibrators;
            
            % Count total calibrators for this file
            fileCalibrators = 0;
            for fieldIdx = 1:length(calibratorData)
                if ~isempty(calibratorData{fieldIdx}) && istable(calibratorData{fieldIdx})
                    fileCalibrators = fileCalibrators + height(calibratorData{fieldIdx});
                end
            end
            totalCalibrators = totalCalibrators + fileCalibrators;
            
            fprintf('   File %d: %d/24 fields with calibrators, %d total calibrators\n', ...
                    fileIdx, fieldsWithCalibrators, fileCalibrators);
        end
    else
        fprintf('   File %d: No calibrator data\n', fileIdx);
    end
end

fprintf('\n   SUMMARY:\n');
fprintf('   Files with calibrator data: %d/%d\n', validCalibratorFiles, length(Results.CalibratorResults));
fprintf('   Total fields with calibrators: %d\n', totalCalibratorFields);
fprintf('   Total calibrators across all: %d\n', totalCalibrators);

%% Examine structure of calibrator data
if validCalibratorFiles > 0
    fprintf('\n2. CALIBRATOR DATA STRUCTURE:\n');
    
    % Find first file with calibrator data
    firstValidFile = find(~cellfun(@isempty, Results.CalibratorResults), 1);
    
    if ~isempty(firstValidFile)
        fprintf('   Examining file %d:\n', firstValidFile);
        calibratorData = Results.CalibratorResults{firstValidFile};
        
        % Find first field with calibrator data
        firstValidField = find(~cellfun(@isempty, calibratorData), 1);
        
        if ~isempty(firstValidField)
            fieldCalibs = calibratorData{firstValidField};
            
            fprintf('   Field %d calibrator table:\n', firstValidField);
            fprintf('     Rows (calibrators): %d\n', height(fieldCalibs));
            fprintf('     Columns: %d\n', width(fieldCalibs));
            fprintf('     Column names: ');
            colNames = fieldCalibs.Properties.VariableNames;
            for i = 1:min(5, length(colNames))
                fprintf('%s ', colNames{i});
            end
            if length(colNames) > 5
                fprintf('... (+%d more)', length(colNames) - 5);
            end
            fprintf('\n');
            
            % Show sample data
            if height(fieldCalibs) > 0
                fprintf('\n   Sample calibrator data (first 3 rows):\n');
                disp(fieldCalibs(1:min(3, height(fieldCalibs)), 1:min(5, width(fieldCalibs))));
            end
        end
    end
end

%% Compare calibrators across files/epochs
if validCalibratorFiles >= 2
    fprintf('\n3. CALIBRATOR COMPARISON ACROSS EPOCHS:\n');
    
    % Get first two files with calibrator data
    validFiles = find(~cellfun(@isempty, Results.CalibratorResults));
    file1 = validFiles(1);
    file2 = validFiles(min(2, length(validFiles)));
    
    fprintf('   Comparing File %d vs File %d:\n', file1, file2);
    
    for fieldNum = 1:24
        calib1 = Results.CalibratorResults{file1}{fieldNum};
        calib2 = Results.CalibratorResults{file2}{fieldNum};
        
        count1 = 0;
        count2 = 0;
        if ~isempty(calib1) && istable(calib1)
            count1 = height(calib1);
        end
        if ~isempty(calib2) && istable(calib2)
            count2 = height(calib2);
        end
        
        if count1 > 0 || count2 > 0
            fprintf('   Field %2d: %3d vs %3d calibrators', fieldNum, count1, count2);
            if count1 > 0 && count2 > 0
                fprintf(' ✅');
            elseif count1 > 0 || count2 > 0
                fprintf(' ⚠️');
            end
            fprintf('\n');
        end
    end
end

%% Example analysis: Calibrator magnitude stability
if validCalibratorFiles >= 2 && exist('fieldCalibs', 'var')
    fprintf('\n4. CALIBRATOR ANALYSIS EXAMPLE:\n');
    
    % Check if magnitude columns exist
    magCols = {};
    if ismember('MAG_PSF', fieldCalibs.Properties.VariableNames)
        magCols{end+1} = 'MAG_PSF';
    end
    if ismember('MAG_AUTO', fieldCalibs.Properties.VariableNames)
        magCols{end+1} = 'MAG_AUTO';
    end
    
    if ~isempty(magCols)
        fprintf('   Available magnitude columns: ');
        fprintf('%s ', magCols{:});
        fprintf('\n');
        
        % Show magnitude statistics for first valid field
        magCol = magCols{1};
        mags = fieldCalibs.(magCol);
        validMags = mags(~isnan(mags));
        
        if ~isempty(validMags)
            fprintf('   %s statistics (Field %d, File %d):\n', magCol, firstValidField, firstValidFile);
            fprintf('     Range: %.2f - %.2f mag\n', min(validMags), max(validMags));
            fprintf('     Mean: %.2f ± %.3f mag\n', mean(validMags), std(validMags));
            fprintf('     Median: %.2f mag\n', median(validMags));
        end
    end
end

%% Usage examples
fprintf('\n5. USAGE EXAMPLES:\n');
fprintf('   %% Access calibrators for specific file and field:\n');
fprintf('   fileIdx = 1; fieldIdx = 5;\n');
fprintf('   calibrators = Results.CalibratorResults{fileIdx}{fieldIdx};\n\n');

fprintf('   %% Count calibrators per field for a file:\n');
fprintf('   calibCounts = cellfun(@(x) height(x), Results.CalibratorResults{1}, ''UniformOutput'', false);\n');
fprintf('   calibCounts = cell2mat(calibCounts(~cellfun(@isempty, calibCounts)));\n\n');

fprintf('   %% Find fields with calibrators across all files:\n');
fprintf('   for fileIdx = 1:length(Results.CalibratorResults)\n');
fprintf('       hasCalibrators = ~cellfun(@isempty, Results.CalibratorResults{fileIdx});\n');
fprintf('       fprintf(''File %%d: Fields with calibrators: %%s\\n'', fileIdx, mat2str(find(hasCalibrators)));\n');
fprintf('   end\n');

%% Data structure summary
fprintf('\n=== CALIBRATOR DATA STRUCTURE ===\n');
fprintf('Results.CalibratorResults{fileIdx}{fieldIdx} contains:\n');
fprintf('  - Table with calibrator sources for that specific field\n');
fprintf('  - Columns typically include: RA, Dec, MAG_PSF, MAG_AUTO, etc.\n');
fprintf('  - Same structure as returned by optimizeAllFieldsAI\n');
fprintf('  - Empty cells for fields without successful calibrator matching\n');

fprintf('\n💡 ANALYSIS POSSIBILITIES:\n');
fprintf('  • Study calibrator magnitude stability across epochs\n');
fprintf('  • Analyze field-to-field calibrator variations\n');
fprintf('  • Identify systematic trends in calibrator properties\n');
fprintf('  • Cross-match calibrators with external catalogs\n');
fprintf('  • Monitor calibrator availability across the field\n');

fprintf('\n🎯 Calibrator data is now fully accessible in workflow results!\n');