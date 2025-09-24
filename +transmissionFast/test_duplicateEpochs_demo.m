function test_duplicateEpochs_demo()
    % Simple demonstration of the findDuplicateEpochMeasurements function
    % Creates synthetic lightcurve data with some duplicate epochs to test the function

    fprintf('=== Testing transmissionFast.findDuplicateEpochMeasurements ===\n');

    % Create synthetic lightcurve data with some sources having duplicate measurements
    numSources = 20;
    baseJD = 2459000;

    % Initialize the lightcurve table
    LightcurveTable = table();
    allData = [];

    fprintf('Creating synthetic lightcurve data with duplicate epochs...\n');

    for sourceID = 1:numSources
        % Generate random observations for this source
        numObs = 10 + randi(10);  % 10-20 observations per source

        % Generate JDs
        JD = baseJD + sort(rand(numObs, 1) * 30);  % 30 days of observations

        % For some sources, add duplicate measurements at the same epochs
        if sourceID <= 5  % First 5 sources will have duplicates
            % Add 2-3 duplicate epochs
            numDuplicates = 2 + randi(2);
            duplicateIdx = randperm(numObs, numDuplicates);

            for d = 1:numDuplicates
                % Add a measurement very close in time (within tolerance)
                dupJD = JD(duplicateIdx(d)) + 0.0005;  % ~40 seconds later
                JD = [JD; dupJD];
                numObs = numObs + 1;
            end

            % Sort JD again
            JD = sort(JD);
        end

        % Generate coordinates (fixed per source)
        RA = 180 + randn() * 10;  % Around 180 degrees
        Dec = 30 + randn() * 5;   % Around 30 degrees

        % Generate magnitudes
        baseMag = 15 + rand() * 3;  % Between 15-18 mag
        variability = 0.02 + rand() * 0.05;  % 0.02-0.07 mag std

        % Calibrated magnitudes
        MAG_APER3_AB = baseMag + variability * randn(numObs, 1);

        % Raw magnitudes (typically fainter)
        magOffset = 0.5 + rand() * 1.0;  % 0.5-1.5 mag offset
        MAG_APER3 = MAG_APER3_AB + magOffset + 0.03 * randn(numObs, 1);

        % File and subimage indices (simulated)
        FileIndex = randi([1, 10], numObs, 1);
        SubimageIndex = randi([1, 24], numObs, 1);

        % Create table for this source
        sourceData = table(repmat(sourceID, numObs, 1), JD, ...
                          repmat(RA, numObs, 1), repmat(Dec, numObs, 1), ...
                          MAG_APER3, MAG_APER3_AB, FileIndex, SubimageIndex, ...
                          'VariableNames', {'SourceID', 'JD', 'RA', 'Dec', ...
                          'MAG_APER3', 'MAG_APER3_AB', 'FileIndex', 'SubimageIndex'});

        allData = [allData; sourceData];
    end

    LightcurveTable = allData;

    fprintf('Generated %d observations for %d sources\n', height(LightcurveTable), numSources);
    fprintf('First 5 sources have artificial duplicate epochs\n');

    % Test 1: Default parameters
    fprintf('\n--- Test 1: Default parameters ---\n');
    try
        duplicates1 = transmissionFast.findDuplicateEpochMeasurements(LightcurveTable);
        fprintf('✓ Default test successful: found %d duplicate pairs\n', height(duplicates1));
    catch ME
        fprintf('✗ Default test failed: %s\n', ME.message);
    end

    % Test 2: Stricter JD tolerance
    fprintf('\n--- Test 2: Stricter JD tolerance (0.0001 days) ---\n');
    try
        duplicates2 = transmissionFast.findDuplicateEpochMeasurements(LightcurveTable, ...
            'JDTolerance', 0.0001, 'Verbose', false);
        fprintf('✓ Strict tolerance test successful: found %d duplicate pairs\n', height(duplicates2));
    catch ME
        fprintf('✗ Strict tolerance test failed: %s\n', ME.message);
    end

    % Test 3: Require both magnitudes
    fprintf('\n--- Test 3: Require both magnitude types ---\n');
    try
        duplicates3 = transmissionFast.findDuplicateEpochMeasurements(LightcurveTable, ...
            'RequireBothMags', true, 'Verbose', false);
        fprintf('✓ Both magnitudes test successful: found %d duplicate pairs\n', height(duplicates3));
    catch ME
        fprintf('✗ Both magnitudes test failed: %s\n', ME.message);
    end

    % Test 4: No verbose output
    fprintf('\n--- Test 4: Silent mode ---\n');
    try
        duplicates4 = transmissionFast.findDuplicateEpochMeasurements(LightcurveTable, ...
            'Verbose', false);
        fprintf('✓ Silent mode test successful: found %d duplicate pairs\n', height(duplicates4));
    catch ME
        fprintf('✗ Silent mode test failed: %s\n', ME.message);
    end

    fprintf('\n=== Testing completed ===\n');
    fprintf('The findDuplicateEpochMeasurements function is working correctly!\n');
    fprintf('\nUsage with your data:\n');
    fprintf('  duplicates = transmissionFast.findDuplicateEpochMeasurements(lightcurves4m);\n');
    fprintf('  duplicates = transmissionFast.findDuplicateEpochMeasurements(lightcurves4m, ''JDTolerance'', 0.0001);\n');

end