function duplicatesTable = findDuplicateEpochMeasurements(LightcurveTable, Args)
    % Find sources with duplicate measurements at the same epoch and calculate magnitude differences
    % This function identifies sources observed multiple times at the same JD (e.g., in overlapping fields)
    %
    % Input:
    %   LightcurveTable - Output from crossMatchLightcurves containing JD and magnitudes
    %   Args - Optional arguments:
    %     'JDTolerance' - Tolerance for considering JDs as the same epoch (default: 0.001 days = ~1.4 minutes)
    %     'RequireBothMags' - Require both MAG_APER3 and MAG_APER3_AB to be present (default: false)
    %     'MinDuplicates' - Minimum number of duplicate measurements required (default: 2)
    %     'Verbose' - Display progress information (default: true)
    %
    % Output:
    %   duplicatesTable - MATLAB table containing:
    %       SourceID - Source identifier
    %       JD - Julian date of the observations
    %       FileIndex1, FileIndex2 - File indices of the duplicate measurements
    %       SubimageIndex1, SubimageIndex2 - Subimage indices of the duplicate measurements
    %       RA_mean - Mean RA of the duplicate measurements
    %       Dec_mean - Mean Dec of the duplicate measurements
    %       delta_MAG_APER3 - Difference in raw magnitudes (MAG2 - MAG1)
    %       delta_MAG_APER3_AB - Difference in calibrated magnitudes (MAG2 - MAG1)
    %       MAG_APER3_1, MAG_APER3_2 - Individual raw magnitude values
    %       MAG_APER3_AB_1, MAG_APER3_AB_2 - Individual calibrated magnitude values
    %
    % Author: D. Kovaleva (Nov 2024)
    % Example:
    %   duplicates = transmissionFast.findDuplicateEpochMeasurements(lightcurves4m);
    %   duplicates = transmissionFast.findDuplicateEpochMeasurements(lightcurves4m, 'JDTolerance', 0.0001);

    arguments
        LightcurveTable table
        Args.JDTolerance double = 0.001  % ~1.4 minutes
        Args.RequireBothMags logical = false
        Args.MinDuplicates double = 2
        Args.Verbose logical = true
    end

    if isempty(LightcurveTable) || height(LightcurveTable) == 0
        error('LightcurveTable is empty');
    end

    % Check required columns
    requiredCols = {'SourceID', 'JD', 'RA', 'Dec', 'MAG_APER3_AB'};
    missingCols = setdiff(requiredCols, LightcurveTable.Properties.VariableNames);
    if ~isempty(missingCols)
        error('Missing required columns: %s', strjoin(missingCols, ', '));
    end

    % Check for optional columns
    hasMAG_APER3 = ismember('MAG_APER3', LightcurveTable.Properties.VariableNames);
    hasFileIndex = ismember('FileIndex', LightcurveTable.Properties.VariableNames);
    hasSubimageIndex = ismember('SubimageIndex', LightcurveTable.Properties.VariableNames);

    if Args.RequireBothMags && ~hasMAG_APER3
        error('MAG_APER3 column not found but RequireBothMags=true');
    end

    if Args.Verbose
        fprintf('=== Finding Duplicate Epoch Measurements ===\n');
        fprintf('JD tolerance: %.5f days (%.1f minutes)\n', Args.JDTolerance, Args.JDTolerance*24*60);
        fprintf('Processing %d measurements...\n', height(LightcurveTable));
    end

    % Get unique source IDs
    uniqueSourceIDs = unique(LightcurveTable.SourceID);
    numSources = length(uniqueSourceIDs);

    % Initialize output arrays
    allDuplicates = [];
    duplicateCount = 0;

    % Process each source
    for i = 1:numSources
        sourceID = uniqueSourceIDs(i);

        % Get all measurements for this source
        sourceData = LightcurveTable(LightcurveTable.SourceID == sourceID, :);
        numMeasurements = height(sourceData);

        if numMeasurements < Args.MinDuplicates
            continue;  % Skip sources with insufficient measurements
        end

        % Sort by JD for easier duplicate detection
        [sortedJD, sortIdx] = sort(sourceData.JD);
        sourceData = sourceData(sortIdx, :);

        % Find groups of measurements with the same JD (within tolerance)
        epochGroups = {};
        currentGroup = [1];  % Start with first measurement

        for j = 2:numMeasurements
            if abs(sourceData.JD(j) - sourceData.JD(j-1)) <= Args.JDTolerance
                % Same epoch as previous measurement
                currentGroup = [currentGroup, j];
            else
                % New epoch
                if length(currentGroup) >= Args.MinDuplicates
                    epochGroups{end+1} = currentGroup;
                end
                currentGroup = [j];
            end
        end

        % Don't forget the last group
        if length(currentGroup) >= Args.MinDuplicates
            epochGroups{end+1} = currentGroup;
        end

        % Process each epoch group with duplicates
        for g = 1:length(epochGroups)
            groupIdx = epochGroups{g};
            groupData = sourceData(groupIdx, :);

            % For now, handle pairs of duplicates
            % If more than 2 measurements, create pairs
            numInGroup = length(groupIdx);

            for p1 = 1:numInGroup-1
                for p2 = p1+1:numInGroup
                    % Create a duplicate record
                    dupRecord = struct();
                    dupRecord.SourceID = sourceID;
                    dupRecord.JD = mean([groupData.JD(p1), groupData.JD(p2)]);

                    % File and subimage indices if available
                    if hasFileIndex
                        dupRecord.FileIndex1 = groupData.FileIndex(p1);
                        dupRecord.FileIndex2 = groupData.FileIndex(p2);
                    else
                        dupRecord.FileIndex1 = NaN;
                        dupRecord.FileIndex2 = NaN;
                    end

                    if hasSubimageIndex
                        dupRecord.SubimageIndex1 = groupData.SubimageIndex(p1);
                        dupRecord.SubimageIndex2 = groupData.SubimageIndex(p2);
                    else
                        dupRecord.SubimageIndex1 = NaN;
                        dupRecord.SubimageIndex2 = NaN;
                    end

                    % Coordinates
                    dupRecord.RA_mean = mean([groupData.RA(p1), groupData.RA(p2)], 'omitnan');
                    dupRecord.Dec_mean = mean([groupData.Dec(p1), groupData.Dec(p2)], 'omitnan');

                    % Individual magnitude values
                    dupRecord.MAG_APER3_AB_1 = groupData.MAG_APER3_AB(p1);
                    dupRecord.MAG_APER3_AB_2 = groupData.MAG_APER3_AB(p2);

                    % Magnitude differences (MAG2 - MAG1)
                    dupRecord.delta_MAG_APER3_AB = groupData.MAG_APER3_AB(p2) - groupData.MAG_APER3_AB(p1);

                    if hasMAG_APER3
                        dupRecord.MAG_APER3_1 = groupData.MAG_APER3(p1);
                        dupRecord.MAG_APER3_2 = groupData.MAG_APER3(p2);
                        dupRecord.delta_MAG_APER3 = groupData.MAG_APER3(p2) - groupData.MAG_APER3(p1);
                    else
                        dupRecord.MAG_APER3_1 = NaN;
                        dupRecord.MAG_APER3_2 = NaN;
                        dupRecord.delta_MAG_APER3 = NaN;
                    end

                    % Skip if both magnitudes required but one is missing
                    if Args.RequireBothMags && (isnan(dupRecord.delta_MAG_APER3) || isnan(dupRecord.delta_MAG_APER3_AB))
                        continue;
                    end

                    % Add to collection
                    if isempty(allDuplicates)
                        allDuplicates = dupRecord;
                    else
                        allDuplicates(end+1) = dupRecord;
                    end
                    duplicateCount = duplicateCount + 1;
                end
            end
        end

        % Progress update
        if Args.Verbose && mod(i, 100) == 0
            fprintf('  Processed %d/%d sources, found %d duplicate pairs so far...\n', ...
                    i, numSources, duplicateCount);
        end
    end

    % Convert to table
    if ~isempty(allDuplicates)
        duplicatesTable = struct2table(allDuplicates);

        % Reorder columns for better readability
        columnOrder = {'SourceID', 'JD', 'FileIndex1', 'FileIndex2', ...
                      'SubimageIndex1', 'SubimageIndex2', ...
                      'RA_mean', 'Dec_mean', ...
                      'delta_MAG_APER3', 'delta_MAG_APER3_AB', ...
                      'MAG_APER3_1', 'MAG_APER3_2', ...
                      'MAG_APER3_AB_1', 'MAG_APER3_AB_2'};

        % Only include columns that exist
        existingCols = intersect(columnOrder, duplicatesTable.Properties.VariableNames, 'stable');
        duplicatesTable = duplicatesTable(:, existingCols);

        % Sort by SourceID and JD
        duplicatesTable = sortrows(duplicatesTable, {'SourceID', 'JD'});
    else
        % Create empty table with proper structure
        duplicatesTable = table();
        duplicatesTable.SourceID = [];
        duplicatesTable.JD = [];
        duplicatesTable.FileIndex1 = [];
        duplicatesTable.FileIndex2 = [];
        duplicatesTable.SubimageIndex1 = [];
        duplicatesTable.SubimageIndex2 = [];
        duplicatesTable.RA_mean = [];
        duplicatesTable.Dec_mean = [];
        duplicatesTable.delta_MAG_APER3 = [];
        duplicatesTable.delta_MAG_APER3_AB = [];
    end

    if Args.Verbose
        fprintf('\n=== Summary ===\n');
        fprintf('Total sources examined: %d\n', numSources);
        fprintf('Sources with duplicate epochs: %d\n', length(unique(duplicatesTable.SourceID)));
        fprintf('Total duplicate pairs found: %d\n', height(duplicatesTable));

        if height(duplicatesTable) > 0
            % Statistics on magnitude differences
            fprintf('\nMagnitude Difference Statistics:\n');
            if ~all(isnan(duplicatesTable.delta_MAG_APER3_AB))
                fprintf('  delta_MAG_APER3_AB: mean=%.4f, std=%.4f, median=%.4f\n', ...
                        mean(duplicatesTable.delta_MAG_APER3_AB, 'omitnan'), ...
                        std(duplicatesTable.delta_MAG_APER3_AB, 'omitnan'), ...
                        median(duplicatesTable.delta_MAG_APER3_AB, 'omitnan'));
            end

            if hasMAG_APER3 && ~all(isnan(duplicatesTable.delta_MAG_APER3))
                fprintf('  delta_MAG_APER3: mean=%.4f, std=%.4f, median=%.4f\n', ...
                        mean(duplicatesTable.delta_MAG_APER3, 'omitnan'), ...
                        std(duplicatesTable.delta_MAG_APER3, 'omitnan'), ...
                        median(duplicatesTable.delta_MAG_APER3, 'omitnan'));
            end

            % Show first few examples
            fprintf('\nFirst 5 duplicate pairs:\n');
            disp(head(duplicatesTable, 5));
        end
    end

    fprintf('\n🎯 Duplicate epoch analysis complete!\n');
end