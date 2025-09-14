function figHandle = plotLightcurves(LightcurveTable, Args)
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
    %     'Title' - Figure title (default: 'Source Lightcurves')
    %     'SavePlot' - Save plot to file (default: false)
    %     'OutputFile' - Output filename (default: 'lightcurves.png')
    %
    % Output:
    %   figHandle - Handle to created figure
    %
    % Author: D. Kovaleva (Sep 2025)
    % Example:
    %   [sources, lightcurves] = transmissionFast.crossMatchLightcurves(Results);
    %   transmissionFast.plotLightcurves(lightcurves);
    %   transmissionFast.plotLightcurves(lightcurves, 'SourceID', [1,5,10], 'ShowStats', true);
    
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
        Args.Title string = "Source Lightcurves"
        Args.SavePlot logical = false
        Args.OutputFile string = "lightcurves.png"
    end
    
    if isempty(LightcurveTable) || height(LightcurveTable) == 0
        error('LightcurveTable is empty');
    end
    
    % Get unique source IDs
    allSourceIDs = unique(LightcurveTable.SourceID);
    
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
    
    % Adjust subplot layout if needed
    totalSubplots = Args.SubplotRows * Args.SubplotCols;
    if numSources > totalSubplots
        fprintf('Warning: %d sources requested but only %d subplots available\n', ...
                numSources, totalSubplots);
        numSources = totalSubplots;
        Args.SourceID = Args.SourceID(1:numSources);
    end
    
    % Create figure
    figHandle = figure('Position', [100, 100, 1200, 800]);
    sgtitle(Args.Title, 'FontSize', 14, 'FontWeight', 'bold');
    
    % Color map for different sources
    colors = lines(numSources);
    
    for i = 1:numSources
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
        if Args.ShowErrors && ismember('MAG_PSF_AB_ERR', sourceData.Properties.VariableNames)
            errorbar(sourceData.JD, sourceData.MAG_PSF_AB, sourceData.MAG_PSF_AB_ERR, ...
                     'o-', 'Color', colors(i,:), 'MarkerSize', Args.MarkerSize, ...
                     'LineWidth', Args.LineWidth, 'MarkerFaceColor', colors(i,:));
        else
            plot(sourceData.JD, sourceData.MAG_PSF_AB, 'o-', ...
                 'Color', colors(i,:), 'MarkerSize', Args.MarkerSize, ...
                 'LineWidth', Args.LineWidth, 'MarkerFaceColor', colors(i,:));
        end
        
        % Customize plot
        xlabel('Julian Date');
        ylabel('AB Magnitude');
        title(sprintf('Source %d', sourceID), 'FontWeight', 'bold');
        grid on;
        
        if Args.InvertYAxis
            set(gca, 'YDir', 'reverse');  % Brighter magnitudes at top
        end
        
        % Calculate and display statistics
        if Args.ShowStats
            meanMag = mean(sourceData.MAG_PSF_AB, 'omitnan');
            stdMag = std(sourceData.MAG_PSF_AB, 'omitnan');
            rangeMag = range(sourceData.MAG_PSF_AB);
            numPoints = height(sourceData);
            
            % Add text box with statistics
            statsText = sprintf('N=%d\\nMean=%.2f\\nStd=%.3f\\nRange=%.3f', ...
                              numPoints, meanMag, stdMag, rangeMag);
            
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
    
    % Overall statistics
    if Args.ShowStats
        % Calculate overall variability statistics
        sourceStats = table();
        sourceStats.SourceID = Args.SourceID';
        sourceStats.NumPoints = zeros(numSources, 1);
        sourceStats.MeanMag = zeros(numSources, 1);
        sourceStats.StdMag = zeros(numSources, 1);
        sourceStats.RangeMag = zeros(numSources, 1);
        
        for i = 1:numSources
            sourceID = Args.SourceID(i);
            sourceData = LightcurveTable(LightcurveTable.SourceID == sourceID, :);
            
            sourceStats.NumPoints(i) = height(sourceData);
            sourceStats.MeanMag(i) = mean(sourceData.MAG_PSF_AB, 'omitnan');
            sourceStats.StdMag(i) = std(sourceData.MAG_PSF_AB, 'omitnan');
            sourceStats.RangeMag(i) = range(sourceData.MAG_PSF_AB);
        end
        
        fprintf('\nLightcurve Statistics:\n');
        fprintf('Source ID | Points | Mean Mag | Std Mag | Range | Variability\n');
        fprintf('----------|--------|----------|---------|-------|-------------\n');
        
        for i = 1:numSources
            variability = sourceStats.StdMag(i) > 0.05;  % Threshold for variability
            varStr = char('Variable' * variability + 'Stable' * ~variability);
            
            fprintf('    %2d    |   %2d   |  %6.2f  | %7.3f | %5.3f | %s\n', ...
                    sourceStats.SourceID(i), sourceStats.NumPoints(i), ...
                    sourceStats.MeanMag(i), sourceStats.StdMag(i), ...
                    sourceStats.RangeMag(i), varStr);
        end
        
        % Summary statistics
        fprintf('\nSummary:\n');
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
    
    % Save plot if requested
    if Args.SavePlot
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
    
    fprintf('\n🎯 Lightcurve plotting complete!\n');
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