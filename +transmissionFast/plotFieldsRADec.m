function figHandle = plotFieldsRADec(CalibratedCatalogs, Args)
    % Plot RA/Dec positions for 24 subimages as crops covering the full field
    % Shows the complete LAST field of view with 24 crops positioned side-by-side
    % to represent their actual spatial arrangement on the detector
    %
    % Input:
    %   CalibratedCatalogs - Either:
    %     1) Cell array {24x1} from Results.CalibratedCatalogs{fileIdx}
    %     2) Results structure with CalibratedCatalogs field
    %   Args - Optional arguments:
    %     'FileIndex' - If Results struct provided, which file to plot (default: 1)
    %     'ColorField' - Field to use for color coding (default: 'MAG_ZP')
    %     'MarkerSize' - Size of points (default: 8)
    %     'ColorMap' - Colormap to use (default: 'jet')
    %     'ColorLimits' - [min max] for color scale (default: auto)
    %     'ShowColorbar' - Show colorbar (default: true)
    %     'ShowFieldBoundaries' - Draw boundaries between crops (default: true)
    %     'PlotStyle' - 'scatter' for colored dots, 'contour' for equilinear lines and colored background (default: 'scatter')
    %     'CoordinateSystem' - 'radec' for RA/Dec, 'xy' for X/Y pixel coordinates (default: 'radec')
    %     'SubimageSize' - Size of each subimage in pixels for X/Y coordinates (default: 1756)
    %     'Title' - Main title for figure (default: auto-generated)
    %     'SavePlot' - Save plot to file (default: false)
    %     'OutputFile' - Output filename (default: 'field_crops.png')
    %     'FigureSize' - Figure size [width height] (default: [1400 800])
    %
    % Output:
    %   figHandle - Handle to created figure
    %
    % Author: D. Kovaleva (Sep 2025)
    % Example:
    %   Results = transmissionFast.processLAST_LC_Workflow();
    %   transmissionFast.plotFieldsRADec(Results.CalibratedCatalogs{1});
    %   transmissionFast.plotFieldsRADec(Results, 'FileIndex', 2, 'ColorField', 'MAG_PSF_AB');
    %   transmissionFast.plotFieldsRADec(Results, 'PlotStyle', 'contour', 'ColorField', 'DIFF_MAG');
    %   transmissionFast.plotFieldsRADec(Results, 'CoordinateSystem', 'xy', 'PlotStyle', 'contour');
    
    arguments
        CalibratedCatalogs
        Args.FileIndex double = 1
        Args.ColorField string = "MAG_ZP"
        Args.MarkerSize double = 8
        Args.ColorMap = 'jet'
        Args.ColorLimits double = []
        Args.ShowColorbar logical = true
        Args.ShowFieldBoundaries logical = true
        Args.PlotStyle string = "scatter"
        Args.CoordinateSystem string = "radec"
        Args.SubimageSize double = 1756
        Args.Title string = ""
        Args.SavePlot logical = false
        Args.OutputFile string = "field_crops.png"
        Args.FigureSize double = [1400 800]
    end
    
    % Handle different input types
    if isstruct(CalibratedCatalogs) && isfield(CalibratedCatalogs, 'CalibratedCatalogs')
        % Results structure provided
        Results = CalibratedCatalogs;
        if Args.FileIndex > length(Results.CalibratedCatalogs)
            error('FileIndex %d exceeds number of files (%d)', ...
                  Args.FileIndex, length(Results.CalibratedCatalogs));
        end
        catalogs = Results.CalibratedCatalogs{Args.FileIndex};
        
        % Generate title with file info
        if Args.Title == ""
            if isfield(Results, 'FileList')
                Args.Title = sprintf('Fields RA/Dec - File %d: %s', ...
                                   Args.FileIndex, Results.FileList{Args.FileIndex});
            else
                Args.Title = sprintf('Fields RA/Dec - File %d', Args.FileIndex);
            end
        end
    elseif iscell(CalibratedCatalogs)
        % Direct cell array provided
        catalogs = CalibratedCatalogs;
        if Args.Title == ""
            Args.Title = 'Fields RA/Dec Distribution';
        end
    else
        error('Input must be either a cell array of catalogs or Results structure');
    end

    % Validate input parameters
    if ~ismember(Args.PlotStyle, ["scatter", "contour"])
        error('PlotStyle must be either "scatter" or "contour"');
    end

    if ~ismember(Args.CoordinateSystem, ["radec", "xy"])
        error('CoordinateSystem must be either "radec" or "xy"');
    end

    % Verify we have 24 elements
    if length(catalogs) ~= 24
        warning('Expected 24 subimages, got %d', length(catalogs));
    end
    
    % Create figure with specified size
    figHandle = figure('Position', [100, 100, Args.FigureSize]);
    hold on;
    
    % Collect all data and determine color limits
    if isempty(Args.ColorLimits)
        allColorData = [];
        for fieldNum = 1:24
            if ~isempty(catalogs{fieldNum}) && istable(catalogs{fieldNum})
                if ismember(Args.ColorField, catalogs{fieldNum}.Properties.VariableNames)
                    colorData = catalogs{fieldNum}.(Args.ColorField);
                    allColorData = [allColorData; colorData(~isnan(colorData))];
                end
            end
        end
        
        if ~isempty(allColorData)
            % Use percentiles to avoid outliers affecting scale
            Args.ColorLimits = [prctile(allColorData, 2), prctile(allColorData, 98)];
        else
            Args.ColorLimits = [0 1];  % Default if no data
        end
    end
    
    % Collect all coordinates to determine field boundaries
    allX = [];
    allY = [];
    coordName1 = '';
    coordName2 = '';

    if Args.CoordinateSystem == "radec"
        coordName1 = 'RA';
        coordName2 = 'Dec';
    else  % xy
        coordName1 = 'X';
        coordName2 = 'Y';
    end

    for fieldNum = 1:24
        if ~isempty(catalogs{fieldNum}) && istable(catalogs{fieldNum})
            catalog = catalogs{fieldNum};

            if Args.CoordinateSystem == "radec"
                if ismember('RA', catalog.Properties.VariableNames) && ...
                   ismember('Dec', catalog.Properties.VariableNames)
                    allX = [allX; catalog.RA];
                    allY = [allY; catalog.Dec];
                end
            else  % xy
                if ismember('X', catalog.Properties.VariableNames) && ...
                   ismember('Y', catalog.Properties.VariableNames)
                    % Apply X,Y rescaling for joint figure
                    % Subimage numbering: bottom-left is 1, increasing left-to-right, bottom-to-top
                    % Calculate subimage position in 4x6 grid (4 rows, 6 columns)
                    row = ceil(fieldNum / 6);  % 1-4 from bottom to top
                    col = mod(fieldNum - 1, 6) + 1;  % 1-6 from left to right

                    % Rescale coordinates
                    rescaledX = catalog.X + (col - 1) * Args.SubimageSize;
                    rescaledY = catalog.Y + (row - 1) * Args.SubimageSize;

                    allX = [allX; rescaledX];
                    allY = [allY; rescaledY];
                end
            end
        end
    end

    if isempty(allX)
        error('No valid %s/%s data found in any catalog', coordName1, coordName2);
    end

    % Calculate overall field boundaries
    xRange = [min(allX), max(allX)];
    yRange = [min(allY), max(allY)];
    
    % Calculate crop boundaries for 4x6 grid layout
    % LAST camera: 4 rows × 6 columns
    numRows = 4;
    numCols = 6;

    if Args.CoordinateSystem == "xy"
        % For X/Y coordinates, boundaries are based on subimage size
        xBoundaries = (0:numCols) * Args.SubimageSize;
        yBoundaries = (0:numRows) * Args.SubimageSize;
    else
        % For RA/Dec, divide the field into 24 rectangular crops
        xStep = (xRange(2) - xRange(1)) / numCols;
        yStep = (yRange(2) - yRange(1)) / numRows;

        % Create coordinate boundaries for each crop
        xBoundaries = xRange(1) + (0:numCols) * xStep;
        yBoundaries = yRange(1) + (0:numRows) * yStep;
    end
    
    % Prepare data collection for plotting
    allPlotX = [];
    allPlotY = [];
    allColorData = [];
    validFields = 0;
    totalSources = 0;

    % Store field statistics
    fieldStats = struct('FieldNum', [], 'NumSources', [], 'MeanX', [], 'MeanY', []);

    % Collect all data first
    for fieldNum = 1:min(24, length(catalogs))
        if isempty(catalogs{fieldNum}) || ~istable(catalogs{fieldNum})
            continue;
        end

        catalog = catalogs{fieldNum};

        % Get coordinates based on coordinate system
        if Args.CoordinateSystem == "radec"
            if ~ismember('RA', catalog.Properties.VariableNames) || ...
               ~ismember('Dec', catalog.Properties.VariableNames)
                continue;
            end
            x = catalog.RA;
            y = catalog.Dec;
        else  % xy
            if ~ismember('X', catalog.Properties.VariableNames) || ...
               ~ismember('Y', catalog.Properties.VariableNames)
                continue;
            end
            % Apply X,Y rescaling for joint figure
            row = ceil(fieldNum / 6);  % 1-4 from bottom to top
            col = mod(fieldNum - 1, 6) + 1;  % 1-6 from left to right

            x = catalog.X + (col - 1) * Args.SubimageSize;
            y = catalog.Y + (row - 1) * Args.SubimageSize;
        end

        % Get color data
        if ismember(Args.ColorField, catalog.Properties.VariableNames)
            colorData = catalog.(Args.ColorField);
        else
            colorData = ones(size(x));
            warning('Field %s not found in catalog %d, using uniform color', ...
                    Args.ColorField, fieldNum);
        end

        % Remove NaN values
        validIdx = ~isnan(x) & ~isnan(y) & ~isnan(colorData);
        x = x(validIdx);
        y = y(validIdx);
        colorData = colorData(validIdx);

        if ~isempty(x)
            % Collect data for plotting
            allPlotX = [allPlotX; x];
            allPlotY = [allPlotY; y];
            allColorData = [allColorData; colorData];

            validFields = validFields + 1;
            totalSources = totalSources + length(x);

            % Store field statistics
            fieldStats(end+1).FieldNum = fieldNum;
            fieldStats(end).NumSources = length(x);
            fieldStats(end).MeanX = mean(x);
            fieldStats(end).MeanY = mean(y);
        end
    end

    % Plot based on selected style
    if Args.PlotStyle == "scatter"
        % Original scatter plot
        scatter(allPlotX, allPlotY, Args.MarkerSize, allColorData, 'filled');

    else  % contour
        % Create grid for interpolation
        gridResolution = 100;  % Adjust for desired resolution

        if ~isempty(allPlotX)
            % Create regular grid
            [Xi, Yi] = meshgrid(linspace(min(allPlotX), max(allPlotX), gridResolution), ...
                               linspace(min(allPlotY), max(allPlotY), gridResolution));

            % Interpolate color data onto grid
            try
                % Use scatteredInterpolant for robust interpolation
                F = scatteredInterpolant(allPlotX, allPlotY, allColorData, 'linear', 'nearest');
                Zi = F(Xi, Yi);

                % Create filled contour plot
                [C, h] = contourf(Xi, Yi, Zi, 20);  % 20 contour levels

                % Overlay contour lines
                hold on;
                contour(Xi, Yi, Zi, 10, 'k-', 'LineWidth', 0.5);  % 10 black contour lines

            catch ME
                warning('Contour interpolation failed: %s. Falling back to scatter plot.', ME.message);
                scatter(allPlotX, allPlotY, Args.MarkerSize, allColorData, 'filled');
            end
        end
    end
    
    % Set axis properties
    if Args.CoordinateSystem == "radec"
        xlabel('RA (degrees)', 'FontSize', 12);
        ylabel('Dec (degrees)', 'FontSize', 12);
    else
        xlabel('X (pixels)', 'FontSize', 12);
        ylabel('Y (pixels)', 'FontSize', 12);
    end
    title(Args.Title, 'FontSize', 14, 'FontWeight', 'bold');
    
    % Apply color settings
    colormap(Args.ColorMap);
    caxis(Args.ColorLimits);
    
    % Add colorbar
    if Args.ShowColorbar
        c = colorbar;
        c.Label.String = sprintf('%s', Args.ColorField);
        c.Label.FontSize = 12;
    end
    
    % Draw field boundaries if requested
    if Args.ShowFieldBoundaries
        % Draw grid lines to show crop boundaries
        for i = 1:length(xBoundaries)
            line([xBoundaries(i), xBoundaries(i)], [yRange(1), yRange(2)], ...
                 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'LineStyle', '--');
        end
        for j = 1:length(yBoundaries)
            line([xRange(1), xRange(2)], [yBoundaries(j), yBoundaries(j)], ...
                 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, 'LineStyle', '--');
        end

        % Add field numbers at the center of each crop
        fieldCounter = 1;
        for row = 1:numRows
            for col = 1:numCols
                if fieldCounter <= 24
                    % Calculate center position of crop
                    if Args.CoordinateSystem == "xy"
                        xCenter = xBoundaries(col) + Args.SubimageSize/2;
                        yCenter = yBoundaries(row) + Args.SubimageSize/2;
                    else
                        xStep = (xRange(2) - xRange(1)) / numCols;
                        yStep = (yRange(2) - yRange(1)) / numRows;
                        xCenter = xBoundaries(col) + xStep/2;
                        yCenter = yBoundaries(numRows - row + 1) + yStep/2;
                    end

                    % Find if this field has data
                    fieldHasData = any([fieldStats.FieldNum] == fieldCounter);

                    if fieldHasData
                        % Find field statistics
                        idx = find([fieldStats.FieldNum] == fieldCounter, 1);
                        numSources = fieldStats(idx).NumSources;
                        textColor = [0.2 0.2 0.2];
                        bgColor = [1 1 1 0.8];  % Semi-transparent white
                    else
                        numSources = 0;
                        textColor = [0.5 0.5 0.5];
                        bgColor = [0.9 0.9 0.9 0.8];  % Semi-transparent gray
                    end

                    % Add field label
                    text(xCenter, yCenter, sprintf('%d\n(%d)', fieldCounter, numSources), ...
                         'HorizontalAlignment', 'center', ...
                         'VerticalAlignment', 'middle', ...
                         'FontSize', 8, 'FontWeight', 'bold', ...
                         'Color', textColor, ...
                         'BackgroundColor', bgColor, ...
                         'EdgeColor', 'none');
                end
                fieldCounter = fieldCounter + 1;
            end
        end
    end
    
    % Set axis limits with small padding
    xPadding = 0.01 * (xRange(2) - xRange(1));
    yPadding = 0.01 * (yRange(2) - yRange(1));
    xlim([xRange(1) - xPadding, xRange(2) + xPadding]);
    ylim([yRange(1) - yPadding, yRange(2) + yPadding]);
    
    % Add grid
    grid on;
    
    % Add summary statistics
    summaryText = sprintf('Total: %d fields, %d sources\nColor range: %.2f - %.2f %s', ...
                         validFields, totalSources, ...
                         Args.ColorLimits(1), Args.ColorLimits(2), Args.ColorField);
    
    text(0.02, 0.98, summaryText, ...
         'Units', 'normalized', 'VerticalAlignment', 'top', ...
         'FontSize', 10, 'BackgroundColor', [1 1 1 0.8], ...
         'EdgeColor', 'black');
    
    % Save plot if requested
    if Args.SavePlot
        fprintf('Saving plot to: %s\n', Args.OutputFile);
        
        % Determine format from extension
        [~, ~, ext] = fileparts(Args.OutputFile);
        
        switch lower(ext)
            case '.png'
                print(figHandle, Args.OutputFile, '-dpng', '-r150');
            case '.pdf'
                print(figHandle, Args.OutputFile, '-dpdf', '-r150');
            case '.eps'
                print(figHandle, Args.OutputFile, '-depsc', '-r150');
            case '.jpg'
                print(figHandle, Args.OutputFile, '-djpeg', '-r150');
            otherwise
                print(figHandle, Args.OutputFile, '-dpng', '-r150');
        end
    end
    
    fprintf('🎯 Field plot complete: %d fields, %d total sources\n', validFields, totalSources);
end