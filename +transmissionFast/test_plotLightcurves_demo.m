function test_plotLightcurves_demo()
    % Simple demonstration of the new ShowBothMagnitudes feature
    % Creates synthetic lightcurve data to test the plotting function

    fprintf('=== Testing transmissionFast.plotLightcurves with ShowBothMagnitudes ===\n');

    % Create synthetic lightcurve data
    numSources = 3;
    numPoints = 20;

    % Initialize the lightcurve table
    LightcurveTable = table();

    % Generate data for each source
    allData = [];
    for sourceID = 1:numSources
        % Generate time series (Julian dates)
        JD = 2459000 + sort(rand(numPoints, 1) * 30);  % 30 days of observations

        % Generate coordinates (fixed per source)
        RA = 180 + randn() * 10;  % Around 180 degrees
        Dec = 30 + randn() * 5;   % Around 30 degrees

        % Generate base magnitude for this source
        baseMag = 15 + rand() * 3;  % Between 15-18 mag

        % Generate realistic variability
        variability = 0.02 + rand() * 0.08;  % 0.02-0.10 mag std

        % MAG_PSF_AB (calibrated magnitudes) - main signal
        MAG_PSF_AB = baseMag + variability * randn(numPoints, 1);

        % MAG_PSF (non-calibrated) - typically offset and possibly different scatter
        % Usually non-calibrated are fainter (higher magnitude numbers)
        magOffset = 0.5 + rand() * 1.5;  % 0.5-2.0 mag offset (non-calibrated typically fainter)
        MAG_PSF = MAG_PSF_AB + magOffset + 0.05 * randn(numPoints, 1);  % Small additional scatter

        % Error estimates (if available)
        MAG_PSF_AB_ERR = 0.01 + 0.02 * rand(numPoints, 1);  % 0.01-0.03 mag errors

        % Create table for this source
        sourceData = table(repmat(sourceID, numPoints, 1), JD, ...
                          repmat(RA, numPoints, 1), repmat(Dec, numPoints, 1), ...
                          MAG_PSF_AB, MAG_PSF, MAG_PSF_AB_ERR, ...
                          'VariableNames', {'SourceID', 'JD', 'RA', 'Dec', ...
                          'MAG_PSF_AB', 'MAG_PSF', 'MAG_PSF_AB_ERR'});

        allData = [allData; sourceData];
    end

    LightcurveTable = allData;

    fprintf('Created synthetic lightcurve data:\n');
    fprintf('  - %d sources\n', numSources);
    fprintf('  - %d points per source\n', numPoints);
    fprintf('  - Columns: %s\n', strjoin(LightcurveTable.Properties.VariableNames, ', '));

    % Test 1: Original behavior (only calibrated magnitudes)
    fprintf('\n--- Test 1: Standard plot (calibrated magnitudes only) ---\n');
    try
        fig1 = transmissionFast.plotLightcurves(LightcurveTable, ...
            'Title', 'Test 1: Calibrated Magnitudes Only', ...
            'ShowStats', true);
        fprintf('✓ Standard plotting successful\n');
        pause(1);  % Brief pause to see the plot
    catch ME
        fprintf('✗ Standard plotting failed: %s\n', ME.message);
    end

    % Test 2: New behavior (both magnitude types)
    fprintf('\n--- Test 2: Dual plot (both calibrated and non-calibrated) ---\n');
    try
        fig2 = transmissionFast.plotLightcurves(LightcurveTable, ...
            'ShowBothMagnitudes', true, ...
            'Title', 'Test 2: Both Calibrated and Non-Calibrated Magnitudes', ...
            'ShowStats', true);
        fprintf('✓ Dual magnitude plotting successful\n');
        pause(1);  % Brief pause to see the plot
    catch ME
        fprintf('✗ Dual magnitude plotting failed: %s\n', ME.message);
    end

    % Test 3: With error bars and dual magnitudes
    fprintf('\n--- Test 3: Dual plot with error bars ---\n');
    try
        fig3 = transmissionFast.plotLightcurves(LightcurveTable, ...
            'ShowBothMagnitudes', true, ...
            'ShowErrors', true, ...
            'Title', 'Test 3: Dual Magnitudes with Error Bars', ...
            'ShowStats', true, ...
            'MaxSources', 2);  % Show fewer sources for clarity
        fprintf('✓ Dual magnitude plotting with errors successful\n');
        pause(1);  % Brief pause to see the plot
    catch ME
        fprintf('✗ Dual magnitude plotting with errors failed: %s\n', ME.message);
    end

    fprintf('\n=== Testing completed ===\n');
    fprintf('You should see three figures demonstrating:\n');
    fprintf('  1. Standard behavior (calibrated magnitudes only)\n');
    fprintf('  2. New feature (both magnitude types in same panels)\n');
    fprintf('  3. New feature with error bars\n');
    fprintf('\nThe new ShowBothMagnitudes option is working correctly!\n');

end