% Example: Plot RA/Dec fields with MAG_ZP color coding
% Shows how to visualize the 24 LAST camera subimages

fprintf('=== PLOTTING LAST FIELDS RA/DEC DISTRIBUTION ===\n\n');

%% Check if Results exists
if ~exist('Results', 'var')
    fprintf('Results not found. Loading from saved file or running workflow...\n');
    
    % Try to load saved results
    resultFiles = dir('LAST_LC_results_*/workflow_results_final.mat');
    if ~isempty(resultFiles)
        load(fullfile(resultFiles(end).folder, resultFiles(end).name), 'Results');
        fprintf('Loaded Results from: %s\n', resultFiles(end).folder);
    else
        fprintf('No saved results found. Please run:\n');
        fprintf('  Results = transmissionFast.processLAST_LC_Workflow();\n');
        return;
    end
end

%% Plot fields for each processed file
numFiles = length(Results.CalibratedCatalogs);
fprintf('Found %d processed files\n\n', numFiles);

% Find files with valid data
validFileIndices = [];
for fileIdx = 1:numFiles
    if ~isempty(Results.CalibratedCatalogs{fileIdx}) && ...
       iscell(Results.CalibratedCatalogs{fileIdx}) && ...
       any(~cellfun(@isempty, Results.CalibratedCatalogs{fileIdx}))
        validFileIndices = [validFileIndices, fileIdx];
    end
end

fprintf('Files with valid catalog data: %d\n', length(validFileIndices));
if isempty(validFileIndices)
    fprintf('No valid catalog data found!\n');
    return;
end

%% Example 1: Plot first valid file with MAG_ZP color coding
fprintf('\nEXAMPLE 1: First file with MAG_ZP color coding\n');

fileIdx = validFileIndices(1);
figHandle1 = transmissionFast.plotFieldsRADec(Results.CalibratedCatalogs{fileIdx}, ...
    'ColorField', 'MAG_ZP', ...
    'Title', sprintf('File %d: %s - Zero Point Magnitude', fileIdx, Results.FileList{fileIdx}), ...
    'MarkerSize', 8, ...
    'ShowGlobalColorbar', true);

%% Example 2: Plot with MAG_PSF_AB color coding if available
fprintf('\nEXAMPLE 2: Same file with MAG_PSF_AB color coding\n');

% Check if MAG_PSF_AB exists
hasMAG_PSF_AB = false;
for subIdx = 1:24
    if ~isempty(Results.CalibratedCatalogs{fileIdx}{subIdx}) && ...
       istable(Results.CalibratedCatalogs{fileIdx}{subIdx}) && ...
       ismember('MAG_PSF_AB', Results.CalibratedCatalogs{fileIdx}{subIdx}.Properties.VariableNames)
        hasMAG_PSF_AB = true;
        break;
    end
end

if hasMAG_PSF_AB
    figHandle2 = transmissionFast.plotFieldsRADec(Results.CalibratedCatalogs{fileIdx}, ...
        'ColorField', 'MAG_PSF_AB', ...
        'Title', sprintf('File %d: %s - AB Magnitude', fileIdx, Results.FileList{fileIdx}), ...
        'MarkerSize', 8, ...
        'ColorMap', 'parula', ...
        'ShowGlobalColorbar', true);
else
    fprintf('MAG_PSF_AB not available in catalogs\n');
end

%% Example 3: Plot multiple files for comparison
if length(validFileIndices) >= 3
    fprintf('\nEXAMPLE 3: Comparing first 3 files\n');
    
    figure('Position', [50, 50, 1800, 600]);
    
    for i = 1:min(3, length(validFileIndices))
        fileIdx = validFileIndices(i);
        
        % Create subplot
        subplot(1, 3, i);
        
        % Combine all catalogs for this file to create overview
        allRA = [];
        allDec = [];
        allMAG_ZP = [];
        
        for subIdx = 1:24
            if ~isempty(Results.CalibratedCatalogs{fileIdx}{subIdx}) && ...
               istable(Results.CalibratedCatalogs{fileIdx}{subIdx})
                catalog = Results.CalibratedCatalogs{fileIdx}{subIdx};
                if ismember('RA', catalog.Properties.VariableNames) && ...
                   ismember('Dec', catalog.Properties.VariableNames) && ...
                   ismember('MAG_ZP', catalog.Properties.VariableNames)
                    allRA = [allRA; catalog.RA];
                    allDec = [allDec; catalog.Dec];
                    allMAG_ZP = [allMAG_ZP; catalog.MAG_ZP];
                end
            end
        end
        
        if ~isempty(allRA)
            scatter(allRA, allDec, 2, allMAG_ZP, 'filled');
            colormap('jet');
            colorbar;
            xlabel('RA (deg)');
            ylabel('Dec (deg)');
            title(sprintf('File %d: All Fields Combined', fileIdx), 'FontSize', 12);
            grid on;
            
            % Add statistics
            text(0.02, 0.98, sprintf('Sources: %d', length(allRA)), ...
                 'Units', 'normalized', 'VerticalAlignment', 'top', ...
                 'BackgroundColor', 'white', 'FontSize', 9);
        else
            title(sprintf('File %d: No Data', fileIdx));
        end
    end
    
    sgtitle('Comparison of Field Coverage Across Files', 'FontSize', 14, 'FontWeight', 'bold');
end

%% Example 4: Direct usage with Results structure
fprintf('\nEXAMPLE 4: Direct Results structure usage\n');

% Plot using Results structure directly - it will extract the appropriate file
figHandle4 = transmissionFast.plotFieldsRADec(Results, ...
    'FileIndex', validFileIndices(1), ...
    'ColorField', 'MAG_ZP', ...
    'MarkerSize', 6, ...
    'ShowGlobalColorbar', true);

%% Example 5: Save plots to files
fprintf('\nEXAMPLE 5: Saving plots\n');

outputDir = 'field_plots';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Save plots for all valid files
for i = 1:min(3, length(validFileIndices))
    fileIdx = validFileIndices(i);
    
    % Create and save MAG_ZP plot
    figHandle = transmissionFast.plotFieldsRADec(Results.CalibratedCatalogs{fileIdx}, ...
        'ColorField', 'MAG_ZP', ...
        'Title', sprintf('File %d - Zero Point', fileIdx), ...
        'SavePlot', true, ...
        'OutputFile', fullfile(outputDir, sprintf('fields_file%02d_magzp.png', fileIdx)));
    
    close(figHandle);  % Close to save memory
    
    fprintf('Saved: fields_file%02d_magzp.png\n', fileIdx);
end

%% Summary statistics
fprintf('\n=== FIELD STATISTICS ===\n');

for i = 1:length(validFileIndices)
    fileIdx = validFileIndices(i);
    
    % Count sources per field
    sourceCounts = zeros(24, 1);
    for subIdx = 1:24
        if ~isempty(Results.CalibratedCatalogs{fileIdx}{subIdx}) && ...
           istable(Results.CalibratedCatalogs{fileIdx}{subIdx})
            sourceCounts(subIdx) = height(Results.CalibratedCatalogs{fileIdx}{subIdx});
        end
    end
    
    fprintf('File %d: %s\n', fileIdx, Results.FileList{fileIdx});
    fprintf('  Fields with data: %d/24\n', sum(sourceCounts > 0));
    fprintf('  Total sources: %d\n', sum(sourceCounts));
    fprintf('  Mean sources per field: %.1f\n', mean(sourceCounts(sourceCounts > 0)));
    fprintf('  Source range: %d - %d\n', min(sourceCounts(sourceCounts > 0)), max(sourceCounts));
end

%% Usage instructions
fprintf('\n=== USAGE INSTRUCTIONS ===\n');
fprintf('Basic usage:\n');
fprintf('  transmissionFast.plotFieldsRADec(Results.CalibratedCatalogs{1})\n\n');

fprintf('With options:\n');
fprintf('  transmissionFast.plotFieldsRADec(Results, ...\n');
fprintf('      ''FileIndex'', 2, ...\n');
fprintf('      ''ColorField'', ''MAG_PSF_AB'', ...\n');
fprintf('      ''MarkerSize'', 10, ...\n');
fprintf('      ''ColorMap'', ''hot'', ...\n');
fprintf('      ''SavePlot'', true, ...\n');
fprintf('      ''OutputFile'', ''my_field_plot.png'')\n');

fprintf('\nAvailable color fields:\n');
fprintf('  MAG_ZP - Zero-point magnitude\n');
fprintf('  MAG_PSF_AB - AB absolute magnitude\n');
fprintf('  FIELD_CORRECTION_MAG - Field correction applied\n');

fprintf('\n🎯 Field plotting examples complete!\n');