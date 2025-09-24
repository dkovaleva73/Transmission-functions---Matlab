% Diagnostic script to check Results structure from processLAST_LC_Workflow
fprintf('=== DIAGNOSING RESULTS STRUCTURE ===\n\n');

% Check if Results exists in workspace
if ~exist('Results', 'var')
    fprintf('❌ Results variable not found in workspace\n');
    fprintf('Please run: Results = transmissionFast.processLAST_LC_Workflow();\n');
    return;
end

%% 1. Basic structure check
fprintf('1. BASIC STRUCTURE:\n');
fprintf('   Results fields: ');
fprintf('%s ', fieldnames(Results)');
fprintf('\n');

if isfield(Results, 'FileList')
    fprintf('   Number of files: %d\n', length(Results.FileList));
    fprintf('   Files:\n');
    for i = 1:min(5, length(Results.FileList))
        fprintf('     %d. %s\n', i, Results.FileList{i});
    end
end

if isfield(Results, 'Success')
    fprintf('   Successful files: %d/%d\n', sum(Results.Success), length(Results.Success));
    fprintf('   Success indices: ');
    fprintf('%d ', find(Results.Success));
    fprintf('\n');
end

%% 2. Check CalibratedCatalogs structure
fprintf('\n2. CALIBRATED CATALOGS STRUCTURE:\n');

if ~isfield(Results, 'CalibratedCatalogs')
    fprintf('❌ CalibratedCatalogs field not found!\n');
    return;
end

fprintf('   CalibratedCatalogs size: %s\n', mat2str(size(Results.CalibratedCatalogs)));
fprintf('   Type: %s\n', class(Results.CalibratedCatalogs));

% Check each file's catalogs
validFiles = 0;
totalSubimages = 0;
totalStars = 0;

for fileIdx = 1:length(Results.CalibratedCatalogs)
    fileCatalog = Results.CalibratedCatalogs{fileIdx};
    
    if isempty(fileCatalog)
        fprintf('   File %d: EMPTY (no catalogs)\n', fileIdx);
        continue;
    end
    
    % Check if it's a cell array of 24 subimages
    if iscell(fileCatalog)
        validSubimages = sum(~cellfun(@isempty, fileCatalog));
        if validSubimages > 0
            validFiles = validFiles + 1;
            totalSubimages = totalSubimages + validSubimages;
            
            % Count stars
            fileStars = 0;
            for subIdx = 1:length(fileCatalog)
                if ~isempty(fileCatalog{subIdx}) && istable(fileCatalog{subIdx})
                    fileStars = fileStars + height(fileCatalog{subIdx});
                end
            end
            totalStars = totalStars + fileStars;
            
            fprintf('   File %d: %d/%d valid subimages, %d total stars\n', ...
                    fileIdx, validSubimages, length(fileCatalog), fileStars);
        else
            fprintf('   File %d: Cell array but all subimages empty\n', fileIdx);
        end
    else
        fprintf('   File %d: Not a cell array (type: %s)\n', fileIdx, class(fileCatalog));
    end
end

fprintf('\n   SUMMARY:\n');
fprintf('   Valid files (with data): %d/%d\n', validFiles, length(Results.CalibratedCatalogs));
fprintf('   Total valid subimages: %d\n', totalSubimages);
fprintf('   Total stars across all: %d\n', totalStars);

%% 3. Check OptimizedParams structure
fprintf('\n3. OPTIMIZED PARAMETERS:\n');

if isfield(Results, 'OptimizedParams')
    validParams = 0;
    for fileIdx = 1:length(Results.OptimizedParams)
        paramSet = Results.OptimizedParams{fileIdx};
        if ~isempty(paramSet)
            if iscell(paramSet)
                validFieldParams = sum(~cellfun(@isempty, paramSet));
                if validFieldParams > 0
                    validParams = validParams + 1;
                    fprintf('   File %d: %d/24 fields with parameters\n', fileIdx, validFieldParams);
                end
            else
                fprintf('   File %d: Not a cell array (type: %s)\n', fileIdx, class(paramSet));
            end
        else
            fprintf('   File %d: EMPTY\n', fileIdx);
        end
    end
    fprintf('   Files with valid parameters: %d/%d\n', validParams, length(Results.OptimizedParams));
else
    fprintf('❌ OptimizedParams field not found\n');
end

%% 4. Diagnose the problem
fprintf('\n4. DIAGNOSIS:\n');

if validFiles < 2
    fprintf('❌ PROBLEM IDENTIFIED: Only %d file(s) have valid catalog data\n', validFiles);
    fprintf('   Cross-matching requires at least 2 files with valid data.\n');
    
    fprintf('\nPossible causes:\n');
    fprintf('   1. Optimization failed for most files\n');
    fprintf('   2. AbsolutePhotometryAstroImage didn\'t produce catalogs\n');
    fprintf('   3. Input AstroImage files might be corrupted or incompatible\n');
    
    fprintf('\nRecommended actions:\n');
    fprintf('   1. Check the LAST_LC folder for valid .mat files\n');
    fprintf('   2. Try running with Verbose=true to see detailed errors\n');
    fprintf('   3. Process files individually to identify which ones fail\n');
else
    fprintf('✅ Found %d valid files with catalog data\n', validFiles);
    fprintf('   This should be sufficient for cross-matching.\n');
    fprintf('   The error might be in how crossMatchLightcurves checks validity.\n');
end

%% 5. Create test structure if needed
fprintf('\n5. TESTING CROSS-MATCH COMPATIBILITY:\n');

% Count how many "files" have non-empty catalog data
testValidCount = 0;
for fileIdx = 1:length(Results.CalibratedCatalogs)
    if ~isempty(Results.CalibratedCatalogs{fileIdx})
        if iscell(Results.CalibratedCatalogs{fileIdx})
            if any(~cellfun(@isempty, Results.CalibratedCatalogs{fileIdx}))
                testValidCount = testValidCount + 1;
            end
        end
    end
end

fprintf('   Files with non-empty catalogs: %d\n', testValidCount);

if testValidCount < 2
    fprintf('   ⚠️ Insufficient data for cross-matching\n');
    
    % Try to create simulated data for testing
    fprintf('\n   Creating simulated data for testing cross-match function...\n');
    
    % Backup original
    Results_original = Results;
    
    % Add simulated catalogs
    for fileIdx = 1:min(3, length(Results.CalibratedCatalogs))
        if isempty(Results.CalibratedCatalogs{fileIdx})
            Results.CalibratedCatalogs{fileIdx} = cell(24, 1);
        end
        
        % Add simulated data to first subimage
        simCatalog = table();
        simCatalog.RA = 180 + randn(50, 1) * 0.01;
        simCatalog.Dec = 30 + randn(50, 1) * 0.01;
        simCatalog.MAG_PSF_AB = 15 + randn(50, 1) * 2;
        
        Results.CalibratedCatalogs{fileIdx}{1} = simCatalog;
    end
    
    fprintf('   Added simulated data to Results for testing\n');
    fprintf('   Original Results saved as Results_original\n');
end

%% 6. Test cross-matching with current structure
fprintf('\n6. ATTEMPTING CROSS-MATCH:\n');
try
    [sources, lightcurves] = transmissionFast.crossMatchLightcurves(Results, ...
        'MinDetections', 2, 'Verbose', false);
    fprintf('✅ Cross-matching succeeded!\n');
    fprintf('   Matched sources: %d\n', height(sources));
    fprintf('   Lightcurve points: %d\n', height(lightcurves));
catch ME
    fprintf('❌ Cross-matching failed: %s\n', ME.message);
    
    % More detailed error info
    if contains(ME.message, 'at least 2 valid catalogs')
        fprintf('\n   The crossMatchLightcurves function is not finding valid catalogs.\n');
        fprintf('   This suggests the CalibratedCatalogs structure is not in expected format.\n');
    end
end

fprintf('\n=== DIAGNOSIS COMPLETE ===\n');
fprintf('Run this script after processLAST_LC_Workflow to diagnose issues.\n');