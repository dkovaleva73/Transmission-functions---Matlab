function [MatchedSources, LightcurveTable] = crossMatchLightcurves(Results, Args)
    % Cross-match sources across all CalibratedCatalogs and extract lightcurves
    % for sources present in all observations
    %
    % Input:
    %   Results - Output structure from processLAST_LC_Workflow containing:
    %     .CalibratedCatalogs - Cell array of photometry catalogs for each file
    %     .Timestamps - Timestamps for each observation
    %   Args - Optional arguments:
    %     'MatchRadius' - Cross-matching radius in arcsec (default: 0.05)
    %     'MinDetections' - Minimum detections required (default: all files)
    %     'RAColumn' - RA column name (default: 'RA')
    %     'DecColumn' - Dec column name (default: 'Dec')
    %     'MagColumn' - Magnitude column name (default: 'MAG_APER3_AB')
    %     'RawMagColumn' - Non-calibrated magnitude column (default: 'MAG_APER3')
    %     'Verbose' - Show progress (default: true)
    %
    % Output:
    %   MatchedSources - Table with cross-matched source information
    %   LightcurveTable - Table with lightcurve data (JD, MAG_APER3_AB, MAG_APER3, source_id)
    %
    % Author: D. Kovaleva (Sep 2025)
    % Example:
    %   Results = transmissionFast.processLAST_LC_Workflow();
    %   [sources, lightcurves] = transmissionFast.crossMatchLightcurves(Results);
    %   transmissionFast.plotLightcurves(lightcurves, 'SourceID', [1,2,3]);
    
    arguments
        Results struct
        Args.MatchRadius double = 0.05  % arcsec
        Args.MinDetections double = []   % Default: all files
        Args.RAColumn string = "RA"
        Args.DecColumn string = "Dec" 
        Args.MagColumn string = "MAG_APER3_AB"
        Args.RawMagColumn string = "MAG_APER_3"
        Args.Verbose logical = true
    end
    
    if Args.Verbose
        fprintf('=== CROSS-MATCHING SOURCES FOR LIGHTCURVES ===\n');
    end
    
    % Get successful catalogs only
    % Each CalibratedCatalogs{fileIdx} should be a cell array of 24 subimages
    validCatalogs = false(length(Results.CalibratedCatalogs), 1);
    for idx = 1:length(Results.CalibratedCatalogs)
        if ~isempty(Results.CalibratedCatalogs{idx}) && iscell(Results.CalibratedCatalogs{idx})
            % Check if any subimage has data
            validCatalogs(idx) = any(~cellfun(@isempty, Results.CalibratedCatalogs{idx}));
        end
    end
    numValidFiles = sum(validCatalogs);
    
    if numValidFiles < 2
        error('Need at least 2 valid catalogs for cross-matching');
    end
    
    % Set default minimum detections to all files
    if isempty(Args.MinDetections)
        Args.MinDetections = numValidFiles;
    end
    
    if Args.Verbose
        fprintf('Valid catalogs: %d/%d\n', numValidFiles, length(Results.CalibratedCatalogs));
        fprintf('Match radius: %.3f arcsec\n', Args.MatchRadius);
        fprintf('Minimum detections required: %d\n', Args.MinDetections);
    end
    
    % Combine all catalogs with file index
    AllSources = table();
    FileIndices = [];
    ObsJDs = [];
    
    fileCounter = 0;
    for fileIdx = 1:length(Results.CalibratedCatalogs)
        if ~validCatalogs(fileIdx)
            continue;
        end
        
        fileCounter = fileCounter + 1;
        
        % Combine all 24 subimages for this file
        fileCatalogs = Results.CalibratedCatalogs{fileIdx};
        validSubimages = ~cellfun(@isempty, fileCatalogs);
        
        if ~any(validSubimages)
            continue;
        end
        
        % Extract JD from timestamp (format: yyyymmddhhmmssms)
        timestamp_str = char(Results.Timestamps(fileIdx));
        if length(timestamp_str) >= 14
            year = str2double(timestamp_str(1:4));
            month = str2double(timestamp_str(5:6));
            day = str2double(timestamp_str(7:8));
            hour = str2double(timestamp_str(9:10));
            minute = str2double(timestamp_str(11:12));
            second = str2double(timestamp_str(13:14));
            
            % Convert to Julian Date
            obsJD = juliandate(datetime(year, month, day, hour, minute, second));
        else
            % Fallback: use file index as pseudo-JD
            obsJD = 2460000 + fileIdx;  % Arbitrary base JD
        end
        
        % Combine subimage catalogs
        for subIdx = 1:24
            if validSubimages(subIdx) && ~isempty(fileCatalogs{subIdx})
                catalog = fileCatalogs{subIdx};
                
                % Check required columns exist
                if ~ismember(Args.RAColumn, catalog.Properties.VariableNames) || ...
                   ~ismember(Args.DecColumn, catalog.Properties.VariableNames) || ...
                   ~ismember(Args.MagColumn, catalog.Properties.VariableNames) || ...
                   ~ismember(Args.RawMagColumn, catalog.Properties.VariableNames)
                    continue;
                end
                
                % Add metadata columns
                catalog.FileIndex = repmat(fileIdx, height(catalog), 1);
                catalog.SubimageIndex = repmat(subIdx, height(catalog), 1);
                catalog.ObsJD = repmat(obsJD, height(catalog), 1);
                catalog.ObsCounter = repmat(fileCounter, height(catalog), 1);
                
                % Append to combined table
                if isempty(AllSources)
                    AllSources = catalog;
                else
                    AllSources = [AllSources; catalog];
                end
            end
        end
    end
    
    if isempty(AllSources)
        error('No valid sources found in catalogs');
    end
    
    if Args.Verbose
        fprintf('Total sources to cross-match: %d\n', height(AllSources));
        fprintf('Unique observation epochs: %d\n', length(unique(AllSources.ObsJD)));
    end
    
    %% Cross-match sources across epochs
    if Args.Verbose
        fprintf('\nPerforming cross-matching...\n');
    end
    
    % Get coordinates
    RA = AllSources.(Args.RAColumn);
    Dec = AllSources.(Args.DecColumn);
    
    % Initialize source groups
    sourceGroups = {};
    usedIndices = false(height(AllSources), 1);
    
    matchRadius_deg = Args.MatchRadius / 3600;  % Convert arcsec to degrees
    
    % Progress tracking
    if Args.Verbose
        fprintf('Processing sources: ');
    end
    
    sourceGroupID = 0;
    
    for i = 1:height(AllSources)
        if usedIndices(i)
            continue;
        end
        
        if Args.Verbose && mod(i, 10000) == 0
            fprintf('%d ', i);
        end
        
        % Find all sources within match radius
        ra_ref = RA(i);
        dec_ref = Dec(i);
        
        % Angular separation calculation
        cosDec = cosd(Dec);
        deltaRA = (RA - ra_ref) .* cosDec;
        deltaDec = Dec - dec_ref;
        separation = sqrt(deltaRA.^2 + deltaDec.^2);
        
        matchedIndices = find(separation <= matchRadius_deg & ~usedIndices);
        
        if length(matchedIndices) >= Args.MinDetections
            % Check if source is detected in enough different epochs
            obsCounters = AllSources.ObsCounter(matchedIndices);
            uniqueEpochs = unique(obsCounters);
            
            if length(uniqueEpochs) >= Args.MinDetections
                sourceGroupID = sourceGroupID + 1;
                sourceGroups{sourceGroupID} = matchedIndices;
                usedIndices(matchedIndices) = true;
            end
        end
    end
    
    if Args.Verbose
        fprintf('\nFound %d sources present in >=%d epochs\n', ...
                length(sourceGroups), Args.MinDetections);
    end
    
    %% Create output tables
    if isempty(sourceGroups)
        MatchedSources = table();
        LightcurveTable = table();
        return;
    end
    
    % Create MatchedSources table
    numSources = length(sourceGroups);
    MatchedSources = table();
    MatchedSources.SourceID = (1:numSources)';
    MatchedSources.MeanRA = zeros(numSources, 1);
    MatchedSources.MeanDec = zeros(numSources, 1);
    MatchedSources.NumDetections = zeros(numSources, 1);
    MatchedSources.NumEpochs = zeros(numSources, 1);
    MatchedSources.MeanMag = zeros(numSources, 1);
    MatchedSources.StdMag = zeros(numSources, 1);
    MatchedSources.MagRange = zeros(numSources, 1);
    
    % Create LightcurveTable
    totalPoints = sum(cellfun(@length, sourceGroups));
    LightcurveTable = table();
    LightcurveTable.SourceID = zeros(totalPoints, 1);
    LightcurveTable.JD = zeros(totalPoints, 1);
    LightcurveTable.MAG_APER3_AB = zeros(totalPoints, 1);
    LightcurveTable.MAG_APER3 = zeros(totalPoints, 1);  % Non-calibrated magnitude
    LightcurveTable.RA = zeros(totalPoints, 1);
    LightcurveTable.Dec = zeros(totalPoints, 1);
    LightcurveTable.FileIndex = zeros(totalPoints, 1);
    LightcurveTable.SubimageIndex = zeros(totalPoints, 1);
    
    if Args.Verbose
        fprintf('Creating lightcurve table...\n');
    end
    
    lightcurveIdx = 1;
    
    for srcIdx = 1:numSources
        indices = sourceGroups{srcIdx};
        
        % Source statistics
        sourceRA = AllSources.(Args.RAColumn)(indices);
        sourceDec = AllSources.(Args.DecColumn)(indices);
        sourceMag = AllSources.(Args.MagColumn)(indices);
        sourceRawMag = AllSources.(Args.RawMagColumn)(indices);
        sourceJD = AllSources.ObsJD(indices);
        
        % Remove NaN magnitudes
        validMags = ~isnan(sourceMag);
        if sum(validMags) == 0
            continue;
        end
        
        MatchedSources.MeanRA(srcIdx) = mean(sourceRA);
        MatchedSources.MeanDec(srcIdx) = mean(sourceDec);
        MatchedSources.NumDetections(srcIdx) = length(indices);
        MatchedSources.NumEpochs(srcIdx) = length(unique(AllSources.ObsCounter(indices)));
        MatchedSources.MeanMag(srcIdx) = mean(sourceMag(validMags));
        MatchedSources.StdMag(srcIdx) = std(sourceMag(validMags));
        MatchedSources.MagRange(srcIdx) = range(sourceMag(validMags));
        
        % Add to lightcurve table
        numPoints = length(indices);
        endIdx = lightcurveIdx + numPoints - 1;
        
        LightcurveTable.SourceID(lightcurveIdx:endIdx) = srcIdx;
        LightcurveTable.JD(lightcurveIdx:endIdx) = sourceJD;
        LightcurveTable.MAG_APER3_AB(lightcurveIdx:endIdx) = sourceMag;
        LightcurveTable.MAG_APER3(lightcurveIdx:endIdx) = sourceRawMag;
        LightcurveTable.RA(lightcurveIdx:endIdx) = sourceRA;
        LightcurveTable.Dec(lightcurveIdx:endIdx) = sourceDec;
        LightcurveTable.FileIndex(lightcurveIdx:endIdx) = AllSources.FileIndex(indices);
        LightcurveTable.SubimageIndex(lightcurveIdx:endIdx) = AllSources.SubimageIndex(indices);
        
        lightcurveIdx = endIdx + 1;
    end
    
    % Trim unused rows
    LightcurveTable = LightcurveTable(1:lightcurveIdx-1, :);
    
    %% Summary
    if Args.Verbose
        fprintf('\n=== CROSS-MATCHING SUMMARY ===\n');
        fprintf('Total matched sources: %d\n', numSources);
        fprintf('Total lightcurve points: %d\n', height(LightcurveTable));
        fprintf('Average detections per source: %.1f\n', height(LightcurveTable)/numSources);
        
        if numSources > 0
            fprintf('Magnitude statistics:\n');
            fprintf('  Mean magnitude range: %.3f ± %.3f mag\n', ...
                    mean(MatchedSources.MeanMag), std(MatchedSources.MeanMag));
            fprintf('  Brightest source: %.2f mag\n', min(MatchedSources.MeanMag));
            fprintf('  Faintest source: %.2f mag\n', max(MatchedSources.MeanMag));
            fprintf('  Largest variability: %.3f mag (Source %d)\n', ...
                    max(MatchedSources.MagRange), find(MatchedSources.MagRange == max(MatchedSources.MagRange), 1));
        end
        
        fprintf('\n🎯 CROSS-MATCHING COMPLETE!\n');
        fprintf('Use plotLightcurves() to visualize individual lightcurves\n');
    end
end