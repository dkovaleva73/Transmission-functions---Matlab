function [figHandle, statsTable] = plotLightcurves(LightcurveTable, Args)
    % Plot lightcurves for selected sources from cross-matched catalogs
    %
    % Input:
    %   LightcurveTable - Output from crossMatchLightcurves containing JD and magnitudes
    %   Args - Optional arguments:
    %     'SourceID' - Array of source IDs to plot (default: first 9 sources)
    %     'MaxSources' - Maximum number of sources to plot (default: 9)
    %     'SubplotRows' - Number of subplot rows (default: 3)
    %     'SubplotCols' - Number of subplot columns (default: 3)
    %     'MarkerSize' - Size of data points (default: 6)
    %     'LineWidth' - Width of connecting lines (default: 1.5)
    %     'ShowErrors' - Plot error bars if available (default: false)
    %     'InvertYAxis' - Invert Y-axis (brighter up) (default: true)
    %     'ShowStats' - Display variability statistics (default: true)
    %     'ShowBothMagnitudes' - Plot both calibrated (MAG_APER3_AB) and non-calibrated (MAG_APER3) (default: false)
    %     'PlotFigures' - Create plots (default: true). Set to false to only get statistics table
    %     'Title' - Figure title (default: 'Source Lightcurves')
    %     'SavePlot' - Save plot to file (default: false)
    %     'OutputFile' - Output filename (default: 'lightcurves.png')
    %
    % Output:
    %   figHandle - Handle to created figure
    %   statsTable - MATLAB table containing statistics for each source:
    %       SourceID - Source identifier
    %       RA - Mean right ascension
    %       Dec - Mean declination
    %       MAG_APER3_mean - Mean of raw magnitudes
    %       MAG_APER3_SEM - Standard error of mean for raw magnitudes
    %       MAG_APER3_AB_mean - Mean of calibrated magnitudes
    %       MAG_APER3_AB_SEM - Standard error of mean for calibrated magnitudes
    %
    % Author: D. Kovaleva (Sep 2025)
    % Example:
    %   [sources, lightcurves] = transmissionFast.crossMatchLightcurves(Results);
    %   fig = transmissionFast.plotLightcurves(lightcurves);
    %   [fig, stats] = transmissionFast.plotLightcurves(lightcurves, 'SourceID', [1,5,10], 'ShowStats', true);
    %   [fig, stats] = transmissionFast.plotLightcurves(lightcurves, 'ShowBothMagnitudes', true);  % Plot both calibrated and non-calibrated
    %   [~, statsAll] = transmissionFast.plotLightcurves(lightcurves, 'PlotFigures', false);  % Get stats for ALL sources without plotting
    
    arguments
        LightcurveTable table
        Args.SourceID double = []
        Args.MaxSources double = 9
        Args.SubplotRows double = 3
        Args.SubplotCols double = 3
        Args.MarkerSize double = 6
        Args.LineWidth double = 1.5
        Args.ShowErrors logical = false
        Args.InvertYAxis logical = true
        Args.ShowStats logical = true
        Args.ShowBothMagnitudes logical = true
        Args.PlotFigures logical = true
        Args.Title string = "Source Lightcurves"
        Args.SavePlot logical = false
        Args.OutputFile string = "lightcurves.png"
    end
    
    if isempty(LightcurveTable) || height(LightcurveTable) == 0
        error('LightcurveTable is empty');
    end
    
    % Get unique source IDs
    allSourceIDs = unique(LightcurveTable.SourceID);

    % Determine which sources to process
    if ~Args.PlotFigures
        % If not plotting, process ALL unique sources
        Args.SourceID = allSourceIDs;
        numSources = length(Args.SourceID);
        fprintf('Processing statistics for %d unique sources (no plots)\n', numSources);
    else
        % If plotting, use the specified sources or first MaxSources
        if isempty(Args.SourceID)
            % Select first MaxSources sources
            Args.SourceID = allSourceIDs(1:min(Args.MaxSources, length(allSourceIDs)));
        end

        % Limit to available sources
        Args.SourceID = intersect(Args.SourceID, allSourceIDs);
        numSources = length(Args.SourceID);

        if numSources == 0
            error('No valid source IDs found');
        end

        fprintf('Plotting lightcurves for %d sources\n', numSources);
    end
    
    % Initialize figure handle
    figHandle = [];

    % Only create plots if requested
    if Args.PlotFigures
        % Adjust subplot layout if needed
        totalSubplots = Args.SubplotRows * Args.SubplotCols;
        if numSources > totalSubplots
            fprintf('Warning: %d sources requested but only %d subplots available\n', ...
                    numSources, totalSubplots);
            numSourcesToPlot = totalSubplots;
        else
            numSourcesToPlot = numSources;
        end

        % Create figure
        figHandle = figure('Position', [100, 100, 1200, 800]);
        sgtitle(Args.Title, 'FontSize', 14, 'FontWeight', 'bold');

        % Color map for different sources
        colors = lines(numSourcesToPlot);

        % Plot only the sources that fit in the subplots
        for i = 1:numSourcesToPlot
            sourceID = Args.SourceID(i);

            % Get data for this source
            sourceData = LightcurveTable(LightcurveTable.SourceID == sourceID, :);

            if height(sourceData) < 2
                continue;  % Skip sources with insufficient data
            end

            % Sort by Julian Date
            [~, sortIdx] = sort(sourceData.JD);
            sourceData = sourceData(sortIdx, :);

            % Create subplot
            subplot(Args.SubplotRows, Args.SubplotCols, i);
            hold on;
        
        % Plot data points
        if Args.ShowBothMagnitudes && ismember('MAG_APER3', sourceData.Properties.VariableNames)
            % Plot both calibrated and non-calibrated magnitudes
            if Args.ShowErrors && ismember('MAG_APER3_AB_ERR', sourceData.Properties.VariableNames)
                % Plot calibrated with error bars
                errorbar(sourceData.JD, sourceData.MAG_APER3_AB, sourceData.MAG_APER3_AB_ERR, ...
                         'o-', 'Color', colors(i,:), 'MarkerSize', Args.MarkerSize, ...
                         'LineWidth', Args.LineWidth, 'MarkerFaceColor', colors(i,:), ...
                         'DisplayName', 'MAG\_APER3\_AB (calibrated)');
                % Plot non-calibrated without error bars (usually not available for MAG_APER3)
                plot(sourceData.JD, sourceData.MAG_APER3, 's--', ...
                     'Color', colors(i,:)*0.7, 'MarkerSize', Args.MarkerSize-1, ...
                     'LineWidth', Args.LineWidth-0.5, 'MarkerFaceColor', colors(i,:)*0.7, ...
                     'DisplayName', 'MAG\_APER3 (non-calibrated)');
            else
                % Plot both without error bars
                plot(sourceData.JD, sourceData.MAG_APER3_AB, 'o-', ...
                     'Color', colors(i,:), 'MarkerSize', Args.MarkerSize, ...
                     'LineWidth', Args.LineWidth, 'MarkerFaceColor', colors(i,:), ...
                     'DisplayName', 'MAG\_APER3\_AB (calibrated)');
                plot(sourceData.JD, sourceData.MAG_APER3, 's--', ...
                     'Color', colors(i,:)*0.7, 'MarkerSize', Args.MarkerSize-1, ...
                     'LineWidth', Args.LineWidth-0.5, 'MarkerFaceColor', colors(i,:)*0.7, ...
                     'DisplayName', 'MAG\_APER3 (non-calibrated)');
            end
            % Add legend for dual plots
            legend('Location', 'best', 'FontSize', 8);
        else
            % Original behavior - plot only calibrated magnitudes
            if Args.ShowErrors && ismember('MAG_APER3_AB_ERR', sourceData.Properties.VariableNames)
                errorbar(sourceData.JD, sourceData.MAG_APER3_AB, sourceData.MAG_APER3_AB_ERR, ...
                         'o-', 'Color', colors(i,:), 'MarkerSize', Args.MarkerSize, ...
                         'LineWidth', Args.LineWidth, 'MarkerFaceColor', colors(i,:));
            else
                plot(sourceData.JD, sourceData.MAG_APER3_AB, 'o-', ...
                     'Color', colors(i,:), 'MarkerSize', Args.MarkerSize, ...
                     'LineWidth', Args.LineWidth, 'MarkerFaceColor', colors(i,:));
            end
        end
        
        % Customize plot
        xlabel('Julian Date');
        if Args.ShowBothMagnitudes && ismember('MAG_APER3', sourceData.Properties.VariableNames)
            ylabel('Magnitude');
        else
            ylabel('AB Magnitude');
        end
        title(sprintf('Source %d', sourceID), 'FontWeight', 'bold');
        grid on;
        
        if Args.InvertYAxis
            set(gca, 'YDir', 'reverse');  % Brighter magnitudes at top
        end
        
        % Calculate and display statistics
        if Args.ShowStats
            numPoints = height(sourceData);

            if Args.ShowBothMagnitudes && ismember('MAG_APER3', sourceData.Properties.VariableNames)
                % Statistics for both magnitude types
                validAB = ~isnan(sourceData.MAG_APER3_AB);
                validAPER3 = ~isnan(sourceData.MAG_APER3);

                nAB = sum(validAB);
                nAPER3 = sum(validAPER3);

                meanMagAB = mean(sourceData.MAG_APER3_AB, 'omitnan');
                stdMagAB = std(sourceData.MAG_APER3_AB, 'omitnan');
                semAB = stdMagAB / sqrt(max(nAB-1, 1));  % Standard error of mean
                rangeMagAB = range(sourceData.MAG_APER3_AB);

                meanMagAPER3 = mean(sourceData.MAG_APER3, 'omitnan');
                stdMagAPER3 = std(sourceData.MAG_APER3, 'omitnan');
                semAPER3 = stdMagAPER3 / sqrt(max(nAPER3-1, 1));  % Standard error of mean
                rangeMagAPER3 = range(sourceData.MAG_APER3);

                % Add text box with statistics for both (including SEM)
                statsText = sprintf('N=%d\\nAB: %.2f±%.3f (SEM:%.3f)\\nAPER3: %.2f±%.3f (SEM:%.3f)', ...
                                  numPoints, meanMagAB, stdMagAB, semAB, meanMagAPER3, stdMagAPER3, semAPER3);
            else
                % Original statistics for AB magnitude only
                validAB = ~isnan(sourceData.MAG_APER3_AB);
                nAB = sum(validAB);

                meanMag = mean(sourceData.MAG_APER3_AB, 'omitnan');
                stdMag = std(sourceData.MAG_APER3_AB, 'omitnan');
                semMag = stdMag / sqrt(max(nAB-1, 1));  % Standard error of mean
                rangeMag = range(sourceData.MAG_APER3_AB);

                % Add text box with statistics (including SEM)
                statsText = sprintf('N=%d\\nMean=%.2f\\nStd=%.3f\\nSEM=%.3f', ...
                                  numPoints, meanMag, stdMag, semMag);
            end
            
            % Position text box
            xlim_vals = xlim;
            ylim_vals = ylim;
            
            if Args.InvertYAxis
                text_y = ylim_vals(2) + 0.05 * diff(ylim_vals);  % Top for inverted axis
            else
                text_y = ylim_vals(1) + 0.95 * diff(ylim_vals);  % Top for normal axis
            end
            
            text(xlim_vals(1) + 0.05 * diff(xlim_vals), text_y, statsText, ...
                 'FontSize', 8, 'BackgroundColor', 'white', 'EdgeColor', 'black', ...
                 'VerticalAlignment', 'top');
        end
        
        % Mean coordinates for title
        meanRA = mean(sourceData.RA);
        meanDec = mean(sourceData.Dec);
        
        % Add coordinates to title
        title(sprintf('Source %d\\nRA=%.4f°, Dec=%.4f°', sourceID, meanRA, meanDec), ...
              'FontSize', 10);
        
            hold off;
        end

        % Adjust subplot spacing
        tightfig();  % This function may not exist - will handle gracefully
    end  % End of if Args.PlotFigures
    
    % Overall statistics (only print to console if plotting)
    if Args.ShowStats && Args.PlotFigures
        % Check if we need statistics for both magnitude types
        hasBothMags = Args.ShowBothMagnitudes && ismember('MAG_APER3', LightcurveTable.Properties.VariableNames);

        % Calculate overall variability statistics
        % Ensure Args.SourceID is properly sized
        sourceIDs = Args.SourceID(:);  % Make column vector
        if length(sourceIDs) ~= numSources
            error('Mismatch between numSources (%d) and length of SourceID (%d)', ...
                  numSources, length(sourceIDs));
        end

        % Initialize table with proper dimensions
        sourceStats = table(sourceIDs, zeros(numSources, 1), zeros(numSources, 1), ...
                           zeros(numSources, 1), zeros(numSources, 1), zeros(numSources, 1), ...
                           'VariableNames', {'SourceID', 'NumPoints', 'MeanMag', 'StdMag', 'SEMMag', 'RangeMag'});

        if hasBothMags
            sourceStats.MeanMagAPER3 = zeros(numSources, 1);
            sourceStats.StdMagAPER3 = zeros(numSources, 1);
            sourceStats.SEMAPER3 = zeros(numSources, 1);
            sourceStats.RangeMagAPER3 = zeros(numSources, 1);
        end

        for i = 1:numSources
            sourceID = Args.SourceID(i);
            sourceData = LightcurveTable(LightcurveTable.SourceID == sourceID, :);

            % Calculate statistics for calibrated magnitudes
            validAB = ~isnan(sourceData.MAG_APER3_AB);
            nAB = sum(validAB);

            sourceStats.NumPoints(i) = height(sourceData);
            sourceStats.MeanMag(i) = mean(sourceData.MAG_APER3_AB, 'omitnan');
            sourceStats.StdMag(i) = std(sourceData.MAG_APER3_AB, 'omitnan');
            sourceStats.SEMMag(i) = sourceStats.StdMag(i) / sqrt(max(nAB-1, 1));
            sourceStats.RangeMag(i) = range(sourceData.MAG_APER3_AB);

            if hasBothMags
                % Calculate statistics for non-calibrated magnitudes
                validAPER3 = ~isnan(sourceData.MAG_APER3);
                nAPER3 = sum(validAPER3);

                sourceStats.MeanMagAPER3(i) = mean(sourceData.MAG_APER3, 'omitnan');
                sourceStats.StdMagAPER3(i) = std(sourceData.MAG_APER3, 'omitnan');
                sourceStats.SEMAPER3(i) = sourceStats.StdMagAPER3(i) / sqrt(max(nAPER3-1, 1));
                sourceStats.RangeMagAPER3(i) = range(sourceData.MAG_APER3);
            end
        end

        if hasBothMags
            fprintf('\nLightcurve Statistics (Both Magnitude Types):\n');
            fprintf('Source ID | Points | AB Mean  | AB Std  | AB SEM  | APER3 Mean | APER3 Std | APER3 SEM | Variability\n');
            fprintf('----------|--------|----------|---------|---------|----------|---------|-----------|-------------\n');

            for i = 1:numSources
                variability = max(sourceStats.StdMag(i), sourceStats.StdMagAPER3(i)) > 0.05;
                if variability
                    varStr = 'Variable';
                else
                    varStr = 'Stable';
                end

                fprintf('    %2d    |   %2d   |  %6.2f  | %7.3f | %7.3f |  %6.2f  | %7.3f | %9.3f | %s\n', ...
                        sourceStats.SourceID(i), sourceStats.NumPoints(i), ...
                        sourceStats.MeanMag(i), sourceStats.StdMag(i), sourceStats.SEMMag(i), ...
                        sourceStats.MeanMagAPER3(i), sourceStats.StdMagAPER3(i), sourceStats.SEMAPER3(i), varStr);
            end
        else
            fprintf('\nLightcurve Statistics:\n');
            fprintf('Source ID | Points | Mean Mag | Std Mag | SEM Mag | Range | Variability\n');
            fprintf('----------|--------|----------|---------|---------|-------|-------------\n');

            for i = 1:numSources
                variability = sourceStats.StdMag(i) > 0.05;  % Threshold for variability
                if variability
                    varStr = 'Variable';
                else
                    varStr = 'Stable';
                end

                fprintf('    %2d    |   %2d   |  %6.2f  | %7.3f | %7.3f | %5.3f | %s\n', ...
                        sourceStats.SourceID(i), sourceStats.NumPoints(i), ...
                        sourceStats.MeanMag(i), sourceStats.StdMag(i), sourceStats.SEMMag(i), ...
                        sourceStats.RangeMag(i), varStr);
            end
        end

        % Summary statistics
        fprintf('\nSummary:\n');
        if hasBothMags
            [~, maxVarIdx] = max(max(sourceStats.StdMag, sourceStats.StdMagAPER3));
            fprintf('  Most variable: Source %d (AB std=%.3f, APER3 std=%.3f mag)\n', ...
                    sourceStats.SourceID(maxVarIdx), ...
                    sourceStats.StdMag(maxVarIdx), sourceStats.StdMagAPER3(maxVarIdx));
            fprintf('  Brightest (AB): Source %d (%.2f mag)\n', ...
                    sourceStats.SourceID(sourceStats.MeanMag == min(sourceStats.MeanMag)), ...
                    min(sourceStats.MeanMag));
            fprintf('  Brightest (APER3): Source %d (%.2f mag)\n', ...
                    sourceStats.SourceID(sourceStats.MeanMagAPER3 == min(sourceStats.MeanMagAPER3)), ...
                    min(sourceStats.MeanMagAPER3));
        else
            fprintf('  Most variable: Source %d (std=%.3f mag)\n', ...
                    sourceStats.SourceID(sourceStats.StdMag == max(sourceStats.StdMag)), ...
                    max(sourceStats.StdMag));
            fprintf('  Brightest: Source %d (%.2f mag)\n', ...
                    sourceStats.SourceID(sourceStats.MeanMag == min(sourceStats.MeanMag)), ...
                    min(sourceStats.MeanMag));
            fprintf('  Faintest: Source %d (%.2f mag)\n', ...
                    sourceStats.SourceID(sourceStats.MeanMag == max(sourceStats.MeanMag)), ...
                    max(sourceStats.MeanMag));
        end
    end
    
    % Save plot if requested (and if plot was created)
    if Args.SavePlot && Args.PlotFigures && ~isempty(figHandle)
        fprintf('Saving plot to: %s\n', Args.OutputFile);
        
        % Determine format from extension
        [~, ~, ext] = fileparts(Args.OutputFile);
        
        switch lower(ext)
            case '.png'
                print(figHandle, Args.OutputFile, '-dpng', '-r300');
            case '.pdf'
                print(figHandle, Args.OutputFile, '-dpdf', '-r300');
            case '.eps'
                print(figHandle, Args.OutputFile, '-depsc', '-r300');
            case '.jpg'
                print(figHandle, Args.OutputFile, '-djpeg', '-r300');
            otherwise
                print(figHandle, Args.OutputFile, '-dpng', '-r300');
        end
    end
    
    % Create output statistics table
    statsTable = table();
    statsTable.SourceID = Args.SourceID(:);

    % Initialize columns
    statsTable.RA = zeros(numSources, 1);
    statsTable.Dec = zeros(numSources, 1);
    statsTable.MAG_APER3_mean = NaN(numSources, 1);
    statsTable.MAG_APER3_SEM = NaN(numSources, 1);
    statsTable.MAG_APER3_AB_mean = zeros(numSources, 1);
    statsTable.MAG_APER3_AB_SEM = zeros(numSources, 1);

    % Fill in statistics for each source
    for i = 1:numSources
        sourceID = Args.SourceID(i);
        sourceData = LightcurveTable(LightcurveTable.SourceID == sourceID, :);

        if height(sourceData) > 0
            % Get mean coordinates
            statsTable.RA(i) = mean(sourceData.RA, 'omitnan');
            statsTable.Dec(i) = mean(sourceData.Dec, 'omitnan');

            % Calculate statistics for calibrated magnitudes (MAG_APER3_AB)
            validAB = ~isnan(sourceData.MAG_APER3_AB);
            nAB = sum(validAB);
            if nAB > 0
                statsTable.MAG_APER3_AB_mean(i) = mean(sourceData.MAG_APER3_AB, 'omitnan');
                stdAB = std(sourceData.MAG_APER3_AB, 'omitnan');
                statsTable.MAG_APER3_AB_SEM(i) = stdAB / sqrt(max(nAB-1, 1));
            end

            % Calculate statistics for raw magnitudes (MAG_APER3) if available
            if ismember('MAG_APER3', sourceData.Properties.VariableNames)
                validAPER3 = ~isnan(sourceData.MAG_APER3);
                nAPER3 = sum(validAPER3);
                if nAPER3 > 0
                    statsTable.MAG_APER3_mean(i) = mean(sourceData.MAG_APER3, 'omitnan');
                    stdAPER3 = std(sourceData.MAG_APER3, 'omitnan');
                    statsTable.MAG_APER3_SEM(i) = stdAPER3 / sqrt(max(nAPER3-1, 1));
                end
            end
        end
    end

    % Display the statistics table
    fprintf('\n=== Statistics Summary Table ===\n');
    if Args.PlotFigures
        fprintf('Statistics for %d plotted sources:\n', min(numSources, Args.SubplotRows * Args.SubplotCols));
    else
        fprintf('Statistics for ALL %d unique sources:\n', numSources);
    end
    disp(statsTable);

    if Args.PlotFigures
        fprintf('\n🎯 Lightcurve plotting and statistics complete!\n');
    else
        fprintf('\n🎯 Statistics calculation complete (no plots created)!\n');
    end
end

% Helper function for tight subplot layout (optional)
function tightfig()
    % Attempt to use tightfig if available, otherwise use manual adjustment
    try
        % If tightfig function exists, use it
        if exist('tight_subplot', 'file') == 2
            % Alternative tight subplot function
            return;
        end
    catch
        % Manual adjustment
        subplots = findall(gcf, 'Type', 'axes');
        if ~isempty(subplots)
            % Reduce spacing between subplots
            for i = 1:length(subplots)
                pos = get(subplots(i), 'Position');
                set(subplots(i), 'Position', [pos(1), pos(2), pos(3)*1.1, pos(4)*1.1]);
            end
        end
    end
end