function Results = processLAST_LC_Workflow(Args)
    % Process multiple AstroImages from LAST_LC folder in chronological order
    % Runs complete pipeline: optimization + absolute photometry for each AstroImage
    %
    % Input (optional arguments):
    %   'InputDir' - Directory containing AstroImage files (default: '/home/dana/matlab/data/transmission_fitter/LAST_LC')
    %   'OutputDir' - Directory for saving results (default: 'LAST_LC_results_[timestamp]')
    %   'FilePattern' - Pattern to match AstroImage files (default: 'LAST.*.mat')
    %   'MaxFiles' - Maximum number of files to process (default: Inf for all)
    %   'Sequence' - Optimization sequence (default: 'Advanced')
    %   'Verbose' - Show detailed progress (default: true)
    %   'SaveIntermediateResults' - Save after each file (default: true)
    %
    % Output:
    %   Results - Structure containing:
    %     .FileList - List of processed files in chronological order
    %     .Timestamps - Extracted timestamps from filenames
    %     .OptimizedParams - Cell array of optimization results for each file
    %     .CalibratedCatalogs - Cell array of photometry catalogs for each file
    %     .CalibratorResults - Cell array of calibrator data for each file
    %     .ProcessingTimes - Time taken for each file
    %     .Success - Boolean array indicating success for each file
    %
    % Author: D. Kovaleva (Sep 2025)
    % Example:
    %   Results = transmissionFast.processLAST_LC_Workflow();
    %   Results = transmissionFast.processLAST_LC_Workflow('MaxFiles', 5, 'Verbose', true);
    
    arguments
        Args.InputDir string = "/home/dana/matlab/data/transmission_fitter/LAST_LC"
        Args.OutputDir string = ""
        Args.FilePattern string = "LAST.*.mat"
        Args.MaxFiles double = Inf
        Args.Sequence string = "Advanced" %"AtmosphericOnly"  "Standard" 
        Args.Verbose logical = true
        Args.SaveIntermediateResults logical = true
    end
    
    %% Step 1: Find and sort AstroImage files
    if Args.Verbose
        fprintf('=== LAST_LC WORKFLOW: PROCESSING MULTIPLE ASTROIMAGE FILES ===\n\n');
        fprintf('Step 1: Finding AstroImage files in %s\n', Args.InputDir);
    end
    
    % Find all matching files
    filePattern = fullfile(Args.InputDir, Args.FilePattern);
    fileList = dir(filePattern);
    
    if isempty(fileList)
        error('No files found matching pattern: %s', filePattern);
    end
    
    % Extract timestamps and sort chronologically
    timestamps = strings(length(fileList), 1);
    for i = 1:length(fileList)
        filename = fileList(i).name;
        % Extract timestamp from filename: LAST.**.**.**_yyyymmdd.hhmmss.ms
        tokens = regexp(filename, 'LAST\.[^_]+_(\d{8})\.(\d{6})\.(\d+)', 'tokens');
        if ~isempty(tokens)
            date_str = tokens{1}{1};  % yyyymmdd
            time_str = tokens{1}{2};  % hhmmss
            ms_str = tokens{1}{3};    % milliseconds
            % Combine into sortable timestamp
            timestamps(i) = sprintf('%s%s%s', date_str, time_str, ms_str);
        else
            timestamps(i) = filename;  % Fallback to filename if pattern doesn't match
        end
    end
    
    % Sort by timestamp
    [sortedTimestamps, sortIdx] = sort(timestamps);
    fileList = fileList(sortIdx);
    
    % Limit number of files if requested
    numFiles = min(length(fileList), Args.MaxFiles);
    fileList = fileList(1:numFiles);
    sortedTimestamps = sortedTimestamps(1:numFiles);
    
    if Args.Verbose
        fprintf('Found %d files, processing %d in chronological order\n', length(fileList), numFiles);
        fprintf('\nFiles to process:\n');
        for i = 1:min(5, numFiles)
            fprintf('  %d. %s\n', i, fileList(i).name);
        end
        if numFiles > 5
            fprintf('  ... and %d more\n', numFiles - 5);
        end
    end
    
    %% Step 2: Setup output directory
    if Args.OutputDir == ""
        Args.OutputDir = sprintf('LAST_LC_results_%s', datestr(now, 'yyyymmdd_HHMMSS'));
    end
    
    if ~exist(Args.OutputDir, 'dir')
        mkdir(Args.OutputDir);
    end
    
    if Args.Verbose
        fprintf('\nOutput directory: %s\n', Args.OutputDir);
    end
    
    %% Step 3: Initialize results storage
    Results = struct();
    Results.FileList = {fileList.name}';
    Results.Timestamps = sortedTimestamps;
    Results.OptimizedParams = cell(numFiles, 1);
    Results.CalibratedCatalogs = cell(numFiles, 1);
    Results.CalibratorResults = cell(numFiles, 1);  % Store calibrator data for each file
    Results.ProcessingTimes = zeros(numFiles, 1);
    Results.Success = false(numFiles, 1);
    Results.NumStarsPerField = zeros(numFiles, 24);  % 24 fields per AstroImage
    
    %% Step 4: Process each AstroImage file
    if Args.Verbose
        fprintf('\n=== PROCESSING ASTROIMAGE FILES ===\n');
    end
    
    totalStartTime = tic;
    
    for fileIdx = 1:numFiles
        currentFile = fullfile(fileList(fileIdx).folder, fileList(fileIdx).name);
        
        if Args.Verbose
            fprintf('\n--- Processing file %d/%d: %s ---\n', fileIdx, numFiles, fileList(fileIdx).name);
        end
        
        fileStartTime = tic;
        
        try
            %% Step 4a: Create custom Config with current AstroImage file
            if Args.Verbose
                fprintf('  Loading configuration...\n');
            end
            
            % Load base configuration
            Config = transmissionFast.inputConfig();
            
            % CRITICAL MODIFICATION: Update the AstroImage file path
            Config.Data.LAST_AstroImage_file = currentFile;
            
            %% Step 4b: Run optimization for all 24 fields
            if Args.Verbose
                fprintf('  Running optimization for all 24 fields...\n');
            end
            
            % Create optimizer
            optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config, ...   %!!!
                'Sequence', Args.Sequence, ...
                'SigmaClippingEnabled', true, ...
                'Verbose', false);  % Suppress individual optimizer output
            
            % Run optimization for all fields with updated Config
            [finalParams_all, calibratorResults_all, ~] = transmissionFast.optimizeAllFieldsAI(...
                'Config', Config, ...
                'Nfields', 24, ...
                'Sequence', Args.Sequence, ...
                'Verbose', false, ...
                'SaveResults', false);
            
            % Store optimization results
            Results.OptimizedParams{fileIdx} = finalParams_all;
            Results.CalibratorResults{fileIdx} = calibratorResults_all;
            
            % Count successful optimizations
            successfulFields = sum(~cellfun(@isempty, finalParams_all));
            
            if Args.Verbose
                fprintf('    ✅ Optimization complete: %d/24 fields successful\n', successfulFields);
            end
            
            %% Step 4c: Calculate absolute photometry
            if successfulFields > 0
                if Args.Verbose
                    fprintf('  Calculating absolute photometry for all subimages...\n');
                end
                
                % Run absolute photometry with field-specific parameters
                CatalogAB_all = transmissionFast.absolutePhotometryForAstroImage(...
                    finalParams_all, Config, ...
                    'Verbose', false, ...
                    'SaveResults', false);
                
                % Store photometry results
                Results.CalibratedCatalogs{fileIdx} = CatalogAB_all;
                
                % Count stars per field
                for fieldNum = 1:24
                    if ~isempty(CatalogAB_all{fieldNum})
                        Results.NumStarsPerField(fileIdx, fieldNum) = height(CatalogAB_all{fieldNum});
                    end
                end
                
                totalStars = sum(Results.NumStarsPerField(fileIdx, :));
                
                if Args.Verbose
                    fprintf('    ✅ Photometry complete: %d total stars processed\n', totalStars);
                end
                
                Results.Success(fileIdx) = true;
            else
                if Args.Verbose
                    fprintf('    ⚠️  No successful optimizations, skipping photometry\n');
                end
                Results.Success(fileIdx) = false;
            end
            
            %% Step 4d: Save intermediate results if requested
            if Args.SaveIntermediateResults
                % Save individual file results
                fileResults = struct();
                fileResults.Filename = fileList(fileIdx).name;
                fileResults.Timestamp = sortedTimestamps(fileIdx);
                fileResults.OptimizedParams = finalParams_all;
                fileResults.CalibratedCatalogs = CatalogAB_all;
                fileResults.CalibratorsResults = calibratorResults_all;
                
                outputFile = fullfile(Args.OutputDir, sprintf('results_%03d_%s.mat', ...
                    fileIdx, datestr(now, 'yyyymmdd_HHMMSS')));
                save(outputFile, 'fileResults', '-v7.3');
                
                if Args.Verbose
                    fprintf('    Saved: %s\n', outputFile);
                end
            end
            
        catch ME
            if Args.Verbose
                fprintf('    ❌ ERROR: %s\n', ME.message);
            end
            Results.Success(fileIdx) = false;
        end
        
        Results.ProcessingTimes(fileIdx) = toc(fileStartTime);
        
        if Args.Verbose
            fprintf('  Processing time: %.1f minutes\n', Results.ProcessingTimes(fileIdx)/60);
        end
    end
    
    %% Step 5: Generate summary
    totalTime = toc(totalStartTime);
    
    if Args.Verbose
        fprintf('\n=== WORKFLOW SUMMARY ===\n');
        fprintf('Files processed: %d\n', numFiles);
        fprintf('Successful: %d (%.1f%%)\n', sum(Results.Success), sum(Results.Success)/numFiles*100);
        fprintf('Total processing time: %.1f minutes\n', totalTime/60);
        fprintf('Average time per file: %.1f minutes\n', mean(Results.ProcessingTimes)/60);
        
        totalStarsProcessed = sum(Results.NumStarsPerField(:));
        fprintf('Total stars processed: %d\n', totalStarsProcessed);
        
        if sum(Results.Success) > 0
            avgStarsPerFile = totalStarsProcessed / sum(Results.Success);
            fprintf('Average stars per file: %.0f\n', avgStarsPerFile);
        end
    end
    
    %% Step 6: Save final results
    finalOutputFile = fullfile(Args.OutputDir, 'workflow_results_final.mat');
    save(finalOutputFile, 'Results', '-v7.3');
    
    % Create summary table
    summaryTable = table();
    summaryTable.FileIndex = (1:numFiles)';
    summaryTable.Filename = Results.FileList;
    summaryTable.Timestamp = Results.Timestamps;
    summaryTable.Success = Results.Success;
    summaryTable.TotalStars = sum(Results.NumStarsPerField, 2);
    summaryTable.ProcessingTime_min = Results.ProcessingTimes / 60;
    
    summaryCSV = fullfile(Args.OutputDir, 'workflow_summary.csv');
    writetable(summaryTable, summaryCSV);
    
    if Args.Verbose
        fprintf('\nFinal results saved to:\n');
        fprintf('  MAT file: %s\n', finalOutputFile);
        fprintf('  Summary CSV: %s\n', summaryCSV);
        
        fprintf('\n🎯 WORKFLOW COMPLETE!\n');
        fprintf('Processed %d AstroImage files in chronological order\n', numFiles);
        fprintf('Results available in: %s\n', Args.OutputDir);
    end
end