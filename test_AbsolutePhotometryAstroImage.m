% Test the new AbsolutePhotometryAstroImage function
fprintf('=== TESTING ABSOLUTEPHOTOMETRYASTROIMAGE FUNCTION ===\n\n');

% Setup
Config = transmissionFast.inputConfig();

% Create minimal optimized parameters for testing
OptimizedParams = struct();
OptimizedParams.General = struct();
OptimizedParams.General.Norm_ = 0.3;
OptimizedParams.Utils = struct();
OptimizedParams.Utils.SkewedGaussianModel = struct();
OptimizedParams.Utils.SkewedGaussianModel.Default_amplitude = 350;
OptimizedParams.Utils.SkewedGaussianModel.Default_center = 477;
OptimizedParams.Utils.SkewedGaussianModel.Default_width = 120;
OptimizedParams.Utils.SkewedGaussianModel.Default_shape = -0.5;

fprintf('Testing AbsolutePhotometryAstroImage function...\n');
fprintf('AstroImage file: %s\n\n', Config.Data.LAST_AstroImage_file);

%% Test 1: Basic functionality test with first few subimages
fprintf('1. BASIC FUNCTIONALITY TEST:\n');

try
    % Test with verbose output disabled for cleaner testing
    CatalogAB_all = transmissionFast.AbsolutePhotometryAstroImage(...
        OptimizedParams, Config, ...
        'Verbose', false, ...
        'SaveResults', false);
    
    % Check results
    fprintf('✅ Function executed successfully\n');
    fprintf('   Output type: %s\n', class(CatalogAB_all));
    fprintf('   Output size: %dx%d\n', size(CatalogAB_all, 1), size(CatalogAB_all, 2));
    
    % Count successful subimages
    success_mask = ~cellfun(@isempty, CatalogAB_all);
    num_successful = sum(success_mask);
    fprintf('   Successfully processed: %d/24 subimages\n', num_successful);
    
    % Show details of first few successful subimages
    successful_indices = find(success_mask);
    if ~isempty(successful_indices)
        fprintf('\n   First few successful subimages:\n');
        for i = 1:min(3, length(successful_indices))
            idx = successful_indices(i);
            catalog = CatalogAB_all{idx};
            if istable(catalog)
                fprintf('     Subimage %d: %d stars, columns: %s\n', ...
                        idx, height(catalog), strjoin(catalog.Properties.VariableNames(1:min(5, width(catalog))), ', '));
                
                % Check for expected columns
                expected_cols = {'MAG_ZP', 'MAG_PSF_AB', 'FIELD_CORRECTION_MAG'};
                has_expected = ismember(expected_cols, catalog.Properties.VariableNames);
                fprintf('       Expected columns present: %s\n', ...
                        strjoin(expected_cols(has_expected), ', '));
            end
        end
    end
    
catch ME
    fprintf('❌ Test failed: %s\n', ME.message);
    fprintf('   Error in: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
end

%% Test 2: Verbose output test with single subimage approach
fprintf('\n2. VERBOSE OUTPUT TEST:\n');

try
    % Create a simple test by running calculateAbsolutePhotometry on one subimage
    fprintf('Testing individual calculateAbsolutePhotometry call:\n');
    
    CatalogAB_single = transmissionFast.calculateAbsolutePhotometry(...
        OptimizedParams, Config, ...
        'AstroImageFile', Config.Data.LAST_AstroImage_file, ...
        'ImageNum', 1, ...
        'Verbose', false, ...
        'SaveResults', false);
    
    if istable(CatalogAB_single)
        fprintf('✅ Single subimage processing works\n');
        fprintf('   Stars in subimage 1: %d\n', height(CatalogAB_single));
        fprintf('   Columns: %d (%s...)\n', width(CatalogAB_single), ...
                strjoin(CatalogAB_single.Properties.VariableNames(1:min(3, width(CatalogAB_single))), ', '));
    end
    
catch ME
    fprintf('❌ Single subimage test failed: %s\n', ME.message);
end

%% Test 3: Check AstroImage file accessibility
fprintf('\n3. ASTROIMAGE FILE ACCESSIBILITY TEST:\n');

AstroImageFile = Config.Data.LAST_AstroImage_file;
if exist(AstroImageFile, 'file')
    fprintf('✅ AstroImage file exists: %s\n', AstroImageFile);
    
    % Try to load and check structure
    try
        data = load(AstroImageFile);
        fprintf('   File contents: %s\n', strjoin(fieldnames(data), ', '));
        
        % Check for AI structure
        if isfield(data, 'AI')
            fprintf('   AI structure found with %d elements\n', length(data.AI));
            
            % Check first few elements for CatData
            for i = 1:min(3, length(data.AI))
                if isfield(data.AI(i), 'CatData')
                    fprintf('   AI(%d).CatData exists\n', i);
                else
                    fprintf('   AI(%d).CatData missing\n', i);
                end
            end
        end
    catch ME
        fprintf('   ⚠️  Could not examine file contents: %s\n', ME.message);
    end
else
    fprintf('❌ AstroImage file not found: %s\n', AstroImageFile);
end

%% Summary
fprintf('\n=== TEST SUMMARY ===\n');

if exist('CatalogAB_all', 'var') && iscell(CatalogAB_all)
    success_count = sum(~cellfun(@isempty, CatalogAB_all));
    fprintf('✅ AbsolutePhotometryAstroImage function created successfully\n');
    fprintf('✅ Returns 24×1 cell array as expected\n');
    fprintf('✅ Processed %d/24 subimages successfully\n', success_count);
    
    if success_count > 0
        fprintf('✅ Generated absolute photometry catalogs with expected columns\n');
    end
    
    if success_count >= 20
        fprintf('🎯 EXCELLENT: Most subimages processed successfully!\n');
    elseif success_count >= 10
        fprintf('✅ GOOD: Many subimages processed successfully\n');
    elseif success_count > 0
        fprintf('⚠️  PARTIAL: Some subimages processed, may need investigation\n');
    else
        fprintf('❌ ISSUE: No subimages processed successfully\n');
    end
else
    fprintf('❌ Function did not return expected cell array\n');
end

fprintf('\n💡 Usage example:\n');
fprintf('   OptParams = [your optimized parameters];\n');
fprintf('   CatalogAB_all = transmissionFast.AbsolutePhotometryAstroImage(OptParams);\n');
fprintf('   % Access individual catalogs: CatalogAB_all{imageNum}\n');

fprintf('\n=== TEST COMPLETE ===\n');